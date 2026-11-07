"""State that survives restarts: quiet entries and timers, the alert log, media.

The small state lives in a Home Assistant `Store`. The alert log is SQLite
(a JSON store would be rewritten whole on every save), and images and audio
clips are files.
"""

from __future__ import annotations

import json
import logging
import sqlite3
import threading
import time
from collections.abc import Iterator
from contextlib import contextmanager
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Any

from homeassistant.core import HomeAssistant
from homeassistant.helpers.storage import Store

from .const import AUDIO, DATA_DIR, DB_FILE, MEDIA_DIR, STORAGE_KEY, STORAGE_VERSION

_LOGGER = logging.getLogger(__name__)

SAVE_DELAY_SECONDS = 1
# A media file with no row is only deleted once it is this old: its row may be
# being written right now. A temporary file this old is no longer being written.
ORPHAN_MEDIA_SECONDS = 3600
# Images are JPEG; a sound's audio clip is AAC in an MP4 file. Both are written
# to a temporary file first, then moved into place.
IMAGE_EXTENSION = ".jpg"
AUDIO_EXTENSION = ".m4a"
TMP_EXTENSION = ".tmp"


class StateStore:
    """Quiet entries, last review, last critical ring per type, shown tags, and the
    version of the cached review images."""

    def __init__(self, hass: HomeAssistant) -> None:
        self._store: Store[dict[str, Any]] = Store(hass, STORAGE_VERSION, STORAGE_KEY)
        self.quiet: list[dict[str, Any]] = []
        self.last_review: float | None = None
        self.last_rings: dict[str, float] = {}
        self.shown_tags: list[str] = []
        self.full_image_version: int | None = None

    async def async_load(self) -> None:
        data = await self._store.async_load() or {}
        self.quiet = list(data.get("quiet", []))
        self.last_review = data.get("last_review")
        self.last_rings = dict(data.get("last_rings", {}))
        self.shown_tags = list(data.get("shown_tags", []))
        self.full_image_version = data.get("full_image_version")

    def save(self) -> None:
        self._store.async_delay_save(self._data, SAVE_DELAY_SECONDS)

    def _data(self) -> dict[str, Any]:
        return {
            "quiet": self.quiet,
            "last_review": self.last_review,
            "last_rings": self.last_rings,
            "shown_tags": self.shown_tags,
            "full_image_version": self.full_image_version,
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
_SELECT = f"SELECT {', '.join(_COLUMNS)} FROM alerts"
_INSERT = f"INSERT INTO alerts ({', '.join(_COLUMNS)}) VALUES ({', '.join('?' * len(_COLUMNS))})"

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


class AlertLogError(Exception):
    """The alert log or its image directory could not be read or written."""


def _to_row(values: sqlite3.Row) -> AlertRow:
    data = dict(values)
    if data["snapshot_box"]:
        data["snapshot_box"] = tuple(json.loads(data["snapshot_box"]))
    return AlertRow(**data)


class AlertLog:
    """The SQLite alert log and the media directory.

    Every method blocks; call them through `hass.async_add_executor_job`.
    Every method raises AlertLogError when the database or a file fails.
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

    @contextmanager
    def _transaction(self) -> Iterator[sqlite3.Connection]:
        with self._lock:
            if self._db is None:
                raise AlertLogError("The alert log is not open")
            try:
                yield self._db
                self._db.commit()
            except sqlite3.Error as err:
                _LOGGER.error("Alert log failed: %s", err)
                raise AlertLogError(str(err)) from err

    def _execute(self, sql: str, params: tuple[Any, ...] = ()) -> list[sqlite3.Row]:
        with self._transaction() as db:
            return db.execute(sql, params).fetchall()

    def insert(self, row: AlertRow) -> float:
        """Write a row, stamped with the time of the insert; return that time.

        The stamp is taken under the log's lock, so a review window read at any
        moment already holds every row stamped before its end: no row can show
        up later with an older time and fall between two reviews.
        """
        with self._transaction() as db:
            row.time = time.time()
            data = asdict(row)
            if data["snapshot_box"] is not None:
                data["snapshot_box"] = json.dumps(list(data["snapshot_box"]))
            db.execute(_INSERT, tuple(data[c] for c in _COLUMNS))
        return row.time

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
        rows = self._execute(f"{_SELECT} WHERE id = ?", (alert_id,))
        return _to_row(rows[0]) if rows else None

    def by_event_id(self, event_id: str) -> AlertRow | None:
        rows = self._execute(
            f"{_SELECT} WHERE event_id = ? ORDER BY time DESC LIMIT 1", (event_id,)
        )
        return _to_row(rows[0]) if rows else None

    def window(
        self, start: float, end: float, limit: int, after: tuple[float, str] | None = None
    ) -> tuple[list[AlertRow], bool]:
        """One page of the alerts with start < time <= end, newest first.

        `after` is the (time, id) of the last row of the previous page. Returns
        the page and whether more rows follow it.
        """
        sql = f"{_SELECT} WHERE time > ? AND time <= ?"
        params: tuple[Any, ...] = (start, end)
        if after is not None:
            sql += " AND (time < ? OR (time = ? AND id < ?))"
            params += (after[0], after[0], after[1])
        rows = self._execute(f"{sql} ORDER BY time DESC, id DESC LIMIT ?", (*params, limit + 1))
        return [_to_row(r) for r in rows[:limit]], len(rows) > limit

    def fill_missing_clip_ends(self, before: float, length: float) -> None:
        """End every clip still open on an alert older than `before`, `length`
        seconds after the clip's start."""
        self._execute(
            "UPDATE alerts SET clip_end = clip_start + ? "
            "WHERE clip_start IS NOT NULL AND clip_end IS NULL AND time < ?",
            (length, before),
        )

    def media_path(self, alert_id: str, variant: str) -> Path:
        extension = AUDIO_EXTENSION if variant == AUDIO else IMAGE_EXTENSION
        return self.media / f"{alert_id}-{variant}{extension}"

    def media_tmp_path(self, alert_id: str, variant: str) -> Path:
        """Where a media file is written before it is moved into place."""
        return self.media_path(alert_id, variant).with_suffix(TMP_EXTENSION)

    def has_media(self, alert_id: str, variant: str) -> bool:
        try:
            return self.media_path(alert_id, variant).is_file()
        except OSError as err:
            _LOGGER.error("Could not read an alert file: %s", err)
            raise AlertLogError(str(err)) from err

    def read_media(self, alert_id: str, variant: str) -> bytes | None:
        try:
            return self.media_path(alert_id, variant).read_bytes()
        except FileNotFoundError:
            return None
        except OSError as err:
            _LOGGER.error("Could not read an alert image: %s", err)
            raise AlertLogError(str(err)) from err

    def write_media(self, alert_id: str, variant: str, data: bytes) -> None:
        tmp = self.media_tmp_path(alert_id, variant)
        try:
            tmp.write_bytes(data)
            tmp.replace(self.media_path(alert_id, variant))
        except OSError as err:
            _LOGGER.error("Could not save an alert image: %s", err)
            raise AlertLogError(str(err)) from err

    def keep_media_tmp(self, alert_id: str, variant: str) -> bool:
        """Move a media file written to its temporary path into place.

        Returns False, and keeps nothing, when that file is missing or empty.
        """
        tmp = self.media_tmp_path(alert_id, variant)
        try:
            if tmp.stat().st_size == 0:
                return False
            tmp.replace(self.media_path(alert_id, variant))
        except FileNotFoundError:
            return False
        except OSError as err:
            _LOGGER.error("Could not save an alert file: %s", err)
            raise AlertLogError(str(err)) from err
        return True

    def drop_media_tmp(self, alert_id: str, variant: str) -> None:
        """Delete a half-written or empty media file; failing to is only logged."""
        try:
            self.media_tmp_path(alert_id, variant).unlink(missing_ok=True)
        except OSError as err:
            _LOGGER.warning("Could not delete a temporary alert file: %s", err)

    def delete_media(self, alert_id: str, variant: str) -> None:
        try:
            self.media_path(alert_id, variant).unlink(missing_ok=True)
        except OSError as err:
            _LOGGER.error("Could not delete an alert image: %s", err)
            raise AlertLogError(str(err)) from err

    def delete_variant_media(self, variant: str) -> int:
        """Delete every alert's media file of one variant; return how many went."""
        deleted = 0
        try:
            for path in self.media.glob(self.media_path("*", variant).name):
                path.unlink(missing_ok=True)
                deleted += 1
        except OSError as err:
            _LOGGER.error("Could not delete alert images: %s", err)
            raise AlertLogError(str(err)) from err
        return deleted

    def prune(self, days: int) -> int:
        """Drop log rows older than `days` and their media; return the rows dropped.

        Images and audio clips go with their rows: any file whose row is gone is
        dropped, once it is old enough not to belong to an alert being written
        right now. A temporary file that old goes even when its row is kept: a
        write that never finished left it, such as ffmpeg killed by a restart.
        """
        now = time.time()
        cutoff = now - days * 86400
        dropped = self._execute("DELETE FROM alerts WHERE time < ? RETURNING id", (cutoff,))
        kept = {r["id"] for r in self._execute("SELECT id FROM alerts")}
        extensions = (IMAGE_EXTENSION, AUDIO_EXTENSION, TMP_EXTENSION)
        files = (p for ext in extensions for p in self.media.glob(f"*{ext}"))
        for path in files:
            if path.suffix != TMP_EXTENSION and path.name.split("-", 1)[0] in kept:
                continue
            try:
                if path.stat().st_mtime < now - ORPHAN_MEDIA_SECONDS:
                    path.unlink(missing_ok=True)
            except OSError as err:
                _LOGGER.warning("Could not prune %s: %s", path, err)
        return len(dropped)
