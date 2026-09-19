"""Spawning the session's processes and stopping them without losing the take.

Ctrl-C reaches this process only: every child is started in its own session, so the
terminal's SIGINT does not scatter across gphoto2, wf-recorder and ffplay before ffmpeg
has finished its file. ffmpeg is then walked down a timed ladder, and the rest are
reaped unconditionally afterwards.
"""

from __future__ import annotations

import signal
import subprocess
from dataclasses import dataclass
from typing import Callable

import config


@dataclass(frozen=True)
class Rung:
    """One step of the shutdown ladder: a signal, and how long it is given."""

    number: int
    grace: float


LADDER = (
    Rung(signal.SIGINT, config.SIGINT_GRACE_SECONDS),
    Rung(signal.SIGTERM, config.SIGTERM_GRACE_SECONDS),
    Rung(signal.SIGKILL, 0.0),
)
"""SIGINT finalises every output of a multi-output ffmpeg, so the first rung is almost
always the last. The timeout is mandatory rather than prudent — a preview output set to
recover from a dead reader was measured hanging forever, ignoring SIGTERM. The SIGKILL
rung is only acceptable because mkv survives it: 3439 of 3442 frames came back."""


def stop(
    send: Callable[[int], None],
    wait: Callable[[float], int | None],
    ladder: tuple[Rung, ...] = LADDER,
) -> int | None:
    """Walk the ladder until the child is gone. Returns its exit code, or None."""
    for rung in ladder:
        send(rung.number)
        code = wait(rung.grace)
        if code is not None:
            return code
    return None


def elapsed(seconds: float) -> str:
    """`00:14:22` — the stamp a mid-take warning carries, so you know which minute."""
    whole = int(seconds)
    return f"{whole // 3600:02d}:{whole % 3600 // 60:02d}:{whole % 60:02d}"


TERMINATE_LADDER = (Rung(signal.SIGTERM, 5.0), Rung(signal.SIGKILL, 0.0))
"""For the children whose output nobody is waiting on: ask, then insist."""


def reap(process: subprocess.Popen | None, ladder: tuple[Rung, ...] = TERMINATE_LADDER) -> int | None:
    """Stop a child we do not need a clean file from, and collect it."""
    if process is None or process.poll() is not None:
        return None if process is None else process.returncode
    return stop(
        lambda number: process.send_signal(number),
        lambda grace: wait_for_exit(process, grace),
        ladder,
    )


def wait_for_exit(process: subprocess.Popen, grace: float) -> int | None:
    """The child's exit code, or None if it is still running when `grace` runs out.

    A grace of zero waits without a deadline, which is what the SIGKILL rung wants.
    """
    if grace <= 0:
        return process.wait()
    try:
        return process.wait(timeout=grace)
    except subprocess.TimeoutExpired:
        return None
