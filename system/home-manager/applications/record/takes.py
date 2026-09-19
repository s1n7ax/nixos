"""What a take is called, and how a crashed one gets named on the next run.

A take is written straight into the destination folder as `<timestamp> UNTITLED.mkv`
and renamed in place once Ctrl-C has stopped it and the description is typed. Same
filesystem, so the rename is atomic and no multi-GB copy happens; a take the machine
died on therefore leaves a named, playable orphan rather than something in /tmp.
"""

from __future__ import annotations

import datetime as dt
import re
from pathlib import Path

import config

_UNSAFE = re.compile(r"[/\\\x00-\x1f\x7f]")
_WHITESPACE = re.compile(r"\s+")


def timestamp(moment: dt.datetime | None = None) -> str:
    """`2026-09-19 14-30-05` — unique enough to be the whole filename stem."""
    return (moment or dt.datetime.now()).strftime(config.TIMESTAMP_FORMAT)


def clean_description(description: str) -> str:
    """A typed description reduced to something that is safe as a filename.

    Path separators and control characters become spaces rather than vanishing, so
    two words never run together, and a description that was only whitespace stays
    `UNTITLED` — the orphan sweep can then offer it again next run.
    """
    collapsed = _WHITESPACE.sub(" ", _UNSAFE.sub(" ", description)).strip()
    return collapsed or config.UNTITLED


def take_filename(stamp: str) -> str:
    """The name a take rolls under before anyone has described it."""
    return f"{stamp} {config.UNTITLED}.{config.CONTAINER}"


def renamed(path: Path, description: str) -> Path:
    """The same take under its description, keeping the timestamp it was opened at."""
    cleaned = clean_description(description)
    if cleaned == config.UNTITLED:
        return path
    stamp = path.stem[: -(len(config.UNTITLED) + 1)]
    return path.with_name(f"{stamp} {cleaned}{path.suffix}")


def unique(path: Path) -> Path:
    """`path`, or the first ` 2`, ` 3`… beside it that is free.

    The timestamp already makes collisions all but impossible, so this should never
    fire. It exists because `Path.rename` overwrites its destination without a word,
    and the thing it would overwrite is a take — the one file here worth protecting
    against a case nobody predicted.
    """
    if not path.exists():
        return path
    for counter in range(2, 1000):
        candidate = path.with_name(f"{path.stem} {counter}{path.suffix}")
        if not candidate.exists():
            return candidate
    raise FileExistsError(f"no free name beside {path}")


def find_orphans(directory: Path, exclude: Path | None = None) -> list[Path]:
    """Undescribed takes an earlier run left behind, oldest first.

    Swept at startup rather than by a daemon: it asks at the one moment the takes
    are still remembered, and there is no second command to forget to run.
    """
    if not directory.is_dir():
        return []
    pattern = f"* {config.UNTITLED}.{config.CONTAINER}"
    found = [path for path in directory.glob(pattern) if path != exclude]
    return sorted(found)
