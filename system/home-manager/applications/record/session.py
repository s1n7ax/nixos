"""Resolving and gating everything a take depends on, before anything is spawned."""

from __future__ import annotations

import subprocess
from dataclasses import dataclass

import audio
import camera
import config
import errors
import pipeline


def _run(argv: list[str]) -> str:
    """Read a helper's stdout.

    Raises:
        ToolUnavailableError: the binary is absent, would not start, or hung.
    """
    try:
        done = subprocess.run(argv, capture_output=True, text=True, timeout=10, check=False)
    except (OSError, subprocess.TimeoutExpired) as error:
        raise errors.ToolUnavailableError(f"{argv[0]} would not run: {error}") from error
    return done.stdout


@dataclass(frozen=True)
class Preflight:
    """What the take will use, once it has been proved usable."""

    mic: str
    desktop: str
    probe: camera.Probe

    def summary(self) -> list[str]:
        """The three lines worth reading before a take: what each source turned out to be."""
        width, height = self.probe.geometry or (0, 0)
        return [
            f"camera   {width}x{height} @ {self.probe.fps:.2f} fps",
            f"mic      {self.mic}",
            f"desktop  {self.desktop}",
        ]


def resolve_desktop() -> str:
    """Desktop audio: the monitor of whatever sink is default right now.

    Resolved here rather than left to ffmpeg's `@DEFAULT_MONITOR@` so the name can be
    shown and tested before the take rolls, and not pinned — a pinned headset goes dead
    the day a different pair is used, and fails as a name that no longer exists.

    Raises:
        AudioSourceError: nothing is default, so there is no desktop audio to record.
        ToolUnavailableError: `pw-metadata` would not run.
    """
    sink = audio.parse_default_sink(_run(["pw-metadata", "-n", "default"]))
    if not sink:
        raise errors.AudioSourceError("no default audio sink — is anything connected?")
    return audio.monitor_of(sink)


def check(camera_argv: list[str] | None = None) -> Preflight:
    """Everything that must hold before a frame is written. Stops at the first no.

    Raises:
        AudioSourceError: the mic is gone, or the default sink is one nothing plays to.
        CameraNotReadyError: no feed, or not the geometry and rate the pipeline assumes.
        ToolUnavailableError: `pw-metadata`, `pw-dump` or `gphoto2` would not run.
    """
    desktop = resolve_desktop()
    if audio.is_blocked(desktop):
        raise errors.AudioSourceError(
            f"desktop audio resolved to {desktop} — that is a GPU HDMI output nothing plays to.\n"
            "  Connect the headset (or pick a real sink) and run again."
        )

    dump = _run(["pw-dump"])
    if not audio.source_exists(dump, config.MIC_SOURCE):
        raise errors.AudioSourceError(
            f"the mic is not there under its pinned name:\n    {config.MIC_SOURCE}\n"
            "  Most likely the card switched profile — put it back on input:analog-stereo."
        )
    if not audio.source_exists(dump, desktop):
        raise errors.AudioSourceError(f"desktop source {desktop} is not in pw-dump")

    probe = camera.warm_up(camera_argv or pipeline.gphoto2_argv(frames=config.WARMUP_FRAMES))
    problems = camera.gate(probe)
    if problems:
        raise errors.CameraNotReadyError(
            "\n  ".join(["the camera feed is not what the pipeline assumes:", *problems])
        )

    return Preflight(mic=config.MIC_SOURCE, desktop=desktop, probe=probe)
