"""Every failure `record` reports by name.

Split by failure mode rather than by phase, because the two kinds want different
responses. An **expected** failure is something about the room: the camera is on the
wrong menu setting, the headset is off, the mic changed profile. You fix it and run
again, and the message says which one. An **unexpected** failure is the machine: a
helper binary that will not run, a child that will not spawn. Nothing you can do at the
camera changes it.

`main` gives the two different exit codes so a caller can tell them apart without
reading the message.
"""

from __future__ import annotations


class RecordError(Exception):
    """Base for every failure this command reports by name."""


class ExpectedError(RecordError):
    """Something about the setup is wrong, and the message says how to fix it."""


class CameraNotReadyError(ExpectedError):
    """No live-view feed, or not the geometry and rate the pipeline assumes."""


class AudioSourceError(ExpectedError):
    """A required source is absent, or the default sink is one nothing plays to."""


class UnexpectedError(RecordError):
    """The machine, not the room. Re-running without changing anything will not help."""


class ToolUnavailableError(UnexpectedError):
    """A helper binary would not run at all."""


class PipelineStartError(UnexpectedError):
    """A child process failed to spawn after preflight had already passed."""
