"""Resolving and gating everything a take depends on, before anything is spawned."""

from __future__ import annotations

import subprocess
from dataclasses import dataclass

import audio
import camera
import config
import pipeline


class PreflightError(Exception):
    """A named reason the take must not start."""


def _run(argv: list[str]) -> str:
    try:
        done = subprocess.run(argv, capture_output=True, text=True, timeout=10, check=False)
    except (OSError, subprocess.TimeoutExpired) as error:
        raise PreflightError(f"{argv[0]} would not run: {error}") from error
    return done.stdout


@dataclass(frozen=True)
class Preflight:
    """What the take will use, once it has been proved usable."""

    mic: str
    desktop: str
    probe: camera.Probe


def resolve_desktop() -> str:
    """Desktop audio: the monitor of whatever sink is default right now.

    Resolved here rather than left to ffmpeg's `@DEFAULT_MONITOR@`, so the name can be
    shown and tested before the take rolls. Not pinned: a pinned headset goes dead the
    day a different pair is used, and fails as a name that no longer exists.
    """
    sink = audio.parse_default_sink(_run(["pw-metadata", "-n", "default"]))
    if not sink:
        raise PreflightError("no default audio sink — is anything connected?")
    return audio.monitor_of(sink)


def check(camera_argv: list[str] | None = None) -> Preflight:
    """Everything that must hold before a frame is written. Raises on the first no."""
    desktop = resolve_desktop()
    if audio.is_blocked(desktop):
        raise PreflightError(
            f"desktop audio resolved to {desktop} — that is a GPU HDMI output nothing plays to.\n"
            "  Connect the headset (or pick a real sink) and run again."
        )

    dump = _run(["pw-dump"])
    if not audio.source_exists(dump, config.MIC_SOURCE):
        raise PreflightError(
            f"the mic is not there under its pinned name:\n    {config.MIC_SOURCE}\n"
            "  Most likely the card switched profile — put it back on input:analog-stereo."
        )
    if not audio.source_exists(dump, desktop):
        raise PreflightError(f"desktop source {desktop} is not in pw-dump")

    probe = camera.warm_up(camera_argv or pipeline.gphoto2_argv(frames=config.WARMUP_FRAMES))
    problems = camera.gate(probe)
    if problems:
        raise PreflightError("\n  ".join(["the camera feed is not what the pipeline assumes:", *problems]))

    return Preflight(mic=config.MIC_SOURCE, desktop=desktop, probe=probe)
