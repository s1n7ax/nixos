"""State that survives restarts: quiet entries and timers, the alert log, images.

The small state lives in a Home Assistant `Store`. The alert log is SQLite
(a JSON store would be rewritten whole on every save), and images are files.
"""

from __future__ import annotations

import json
import logging
import sqlite3
import threading
import time
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Any

from homeassistant.core import HomeAssistant
from homeassistant.helpers.storage import Store

from .const import DATA_DIR, DB_FILE, MEDIA_DIR, STORAGE_KEY, STORAGE_VERSION

_LOGGER = logging.getLogger(__name__)

SAVE_DELAY_SECONDS = 1
WINDOW_LIMIT = 2000


class StateStore:
    """Quiet entries, last review, last critical ring per type, shown tags."""

    def __init__(self, hass: HomeAssistant) -> None:
        self._store: Store[dict[str, Any]] = Store(hass, STORAGE_VERSION, STORAGE_KEY)
        self.quiet: list[dict[str, Any]] = []
        self.last_review: float | None = None
        self.last_rings: dict[str, float] = {}
        self.shown_tags: list[str] = []

    async def async_load(self) -> None:
        data = await self._store.async_load() or {}
        self.quiet = list(data.get("quiet", []))
        self.last_review = data.get("last_review")
        self.last_rings = dict(data.get("last_rings", {}))
        self.shown_tags = list(data.get("shown_tags", []))

    def save(self) -> None:
        self._store.async_delay_save(self._data, SAVE_DELAY_SECONDS)

    def _data(self) -> dict[str, Any]:
        return {
            "quiet": self.quiet,
            "last_review": self.last_review,
            "last_rings": self.last_rings,
            "shown_tags": self.shown_tags,
        }


@dataclass
class AlertRow:
    """One alert in the log, as the review view lists it."""

    id: str
    time: float
    kind: str
    type: str
    source: str
    name: str
    delivery: str
    mode: str
    action: str | None = None
    event_id: str | None = None
    snapshot_time: float | None = None
    snapshot_box: tuple[float, float, float, float] | None = None
    clip_start: float | None = None
    clip_end: float | None = None


_COLUMNS = [
    "id",
    "time",
    "kind",
    "type",
    "source",
    "name",
    "delivery",
    "mode",
    "action",
    "event_id",
    "snapshot_time",
    "snapshot_box",
    "clip_start",
    "clip_end",
]

_SCHEMA = """
CREATE TABLE IF NOT EXISTS alerts (
    id TEXT PRIMARY KEY,
    time REAL NOT NULL,
    kind TEXT NOT NULL,
    type TEXT NOT NULL,
    source TEXT NOT NULL,
    name TEXT NOT NULL,
    delivery TEXT NOT NULL,
    mode TEXT NOT NULL,
    action TEXT,
    event_id TEXT,
    snapshot_time REAL,
    snapshot_box TEXT,
    clip_start REAL,
    clip_end REAL
);
CREATE INDEX IF NOT EXISTS alerts_time ON alerts (time);
CREATE INDEX IF NOT EXISTS alerts_event_id ON alerts (event_id);
"""


def _to_row(values: sqlite3.Row) -> AlertRow:
    data = dict(values)
    if data["snapshot_box"]:
        data["snapshot_box"] = tuple(json.loads(data["snapshot_box"]))
    return AlertRow(**data)


class AlertLog:
    """The SQLite alert log and the image directory.

    Every method blocks; call them through `hass.async_add_executor_job`.
    """

    def __init__(self, config_dir: str) -> None:
        self.directory = Path(config_dir) / DATA_DIR
        self.media = self.directory / MEDIA_DIR
        self._lock = threading.Lock()
        self._db: sqlite3.Connection | None = None

    def open(self) -> None:
        self.media.mkdir(parents=True, exist_ok=True)
        db = sqlite3.connect(self.directory / DB_FILE, check_same_thread=False)
        db.row_factory = sqlite3.Row
        db.executescript(_SCHEMA)
        db.commit()
        self._db = db

    def close(self) -> None:
        with self._lock:
            if self._db is not None:
                self._db.close()
                self._db = None

    def _execute(self, sql: str, params: tuple[Any, ...] = ()) -> list[sqlite3.Row]:
        if self._db is None:
            raise RuntimeError("The alert log is not open")
        with self._lock:
            rows = self._db.execute(sql, params).fetchall()
            self._db.commit()
            return rows

    def insert(self, row: AlertRow) -> None:
        data = asdict(row)
        if data["snapshot_box"] is not None:
            data["snapshot_box"] = json.dumps(list(data["snapshot_box"]))
        placeholders = ", ".join("?" for _ in _COLUMNS)
        self._execute(
            f"INSERT INTO alerts ({', '.join(_COLUMNS)}) VALUES ({placeholders})",
            tuple(data[c] for c in _COLUMNS),
        )

    def update_snapshot(
        self, alert_id: str, frame_time: float, box: tuple[float, float, float, float]
    ) -> None:
        self._execute(
            "UPDATE alerts SET snapshot_time = ?, snapshot_box = ? WHERE id = ?",
            (frame_time, json.dumps(list(box)), alert_id),
        )

    def update_clip_end(self, alert_id: str, clip_end: float) -> None:
        self._execute("UPDATE alerts SET clip_end = ? WHERE id = ?", (clip_end, alert_id))

    def get(self, alert_id: str) -> AlertRow | None:
        rows = self._execute(f"SELECT {', '.join(_COLUMNS)} FROM alerts WHERE id = ?", (alert_id,))
        return _to_row(rows[0]) if rows else None

    def by_event_id(self, event_id: str) -> AlertRow | None:
        rows = self._execute(
            f"SELECT {', '.join(_COLUMNS)} FROM alerts WHERE event_id = ? "
            "ORDER BY time DESC LIMIT 1",
            (event_id,),
        )
        return _to_row(rows[0]) if rows else None

    def window(self, start: float, end: float) -> list[AlertRow]:
        """Alerts with start < time <= end, newest first."""
        rows = self._execute(
            f"SELECT {', '.join(_COLUMNS)} FROM alerts WHERE time > ? AND time <= ? "
            "ORDER BY time DESC LIMIT ?",
            (start, end, WINDOW_LIMIT),
        )
        return [_to_row(r) for r in rows]

    def missing_clip_ends(self, before: float) -> list[AlertRow]:
        """Alerts with a clip that never got an end and started before `before`."""
        rows = self._execute(
            f"SELECT {', '.join(_COLUMNS)} FROM alerts "
            "WHERE clip_start IS NOT NULL AND clip_end IS NULL AND time < ?",
            (before,),
        )
        return [_to_row(r) for r in rows]

    def media_path(self, alert_id: str, variant: str) -> Path:
        return self.media / f"{alert_id}-{variant}.jpg"

    def read_media(self, alert_id: str, variant: str) -> bytes | None:
        try:
            return self.media_path(alert_id, variant).read_bytes()
        except FileNotFoundError:
            return None

    def write_media(self, alert_id: str, variant: str, data: bytes) -> None:
        path = self.media_path(alert_id, variant)
        tmp = path.with_suffix(".tmp")
        tmp.write_bytes(data)
        tmp.replace(path)

    def delete_media(self, alert_id: str, variant: str) -> None:
        self.media_path(alert_id, variant).unlink(missing_ok=True)

    def prune(self, days: int) -> int:
        """Drop log rows and images older than `days`; return the rows dropped."""
        cutoff = time.time() - days * 86400
        dropped = len(self._execute("DELETE FROM alerts WHERE time < ? RETURNING id", (cutoff,)))
        for path in self.media.glob("*"):
            try:
                if path.stat().st_mtime < cutoff:
                    path.unlink(missing_ok=True)
            except OSError as err:
                _LOGGER.warning("Could not prune %s: %s", path, err)
        return dropped
