#!/usr/bin/env python3
"""record — one take of the screen, the camera and both audio sources.

Captures 3440x1440 plus the R5's live view over USB plus mic and desktop audio,
composites the camera as a circle in the bottom-right corner, previews the whole thing
in a window hidden under that circle, and writes one NVENC-encoded mkv into
~/Videos/Youtube/00 new, ready to trim in LosslessCut and upload.

Ctrl-C stops the take and asks what it was.
"""

from __future__ import annotations

import os
import shutil
import subprocess
import sys
import tempfile
import threading
import time
from pathlib import Path

import audio
import config
import errors
import mask
import meter
import pipeline
import session
import supervisor
import takes

MASK = Path(__file__).resolve().parent / mask.filename()

WATCH_INTERVAL = 3.0
PLACEMENT_TIMEOUT = 15.0


def say(message: str = "") -> None:
    print(message, file=sys.stderr, flush=True)


def complain(error: errors.RecordError) -> int:
    """Report a named failure and pick the exit code its kind deserves.

    1 is something you can fix at the camera or the headset and run again; 3 is the
    machine, where running again unchanged will fail the same way.
    """
    say(f"record: {error}")
    return 1 if isinstance(error, errors.ExpectedError) else 3


def name_orphans(directory: Path, exclude: Path | None = None) -> None:
    """Describe the takes an earlier run left undescribed.

    Asked at startup rather than by a daemon: this is the one moment they are still
    remembered, and there is no second command to forget to run.
    """
    orphans = takes.find_orphans(directory, exclude=exclude)
    if not orphans:
        return
    say(f"{len(orphans)} take(s) from an earlier run were never described.")
    for orphan in orphans:
        try:
            description = input(f"  {orphan.name}\n  what was it? (Enter to leave it) ")
        except (EOFError, KeyboardInterrupt):
            say()
            return
        destination = takes.renamed(orphan, description)
        if destination != orphan:
            orphan.rename(takes.unique(destination))
            say(f"  -> {destination.name}")


def place_preview(preview: subprocess.Popen | None) -> None:
    """Park the preview inside the circle, or close it.

    An unplaced preview is worse than none: `wf-recorder` grabs the monitor's composited
    image, so a window that never reached the circle is a window burned into the take.
    If it cannot be parked it is shut instead — losing the preview costs nothing the file
    keeps, and keeping it costs the file.
    """
    deadline = time.monotonic() + PLACEMENT_TIMEOUT
    while time.monotonic() < deadline:
        found = subprocess.run(
            ["hyprctl", "clients", "-j"], capture_output=True, text=True, check=False
        ).stdout
        if f'"{pipeline.PREVIEW_TITLE}"' in found:
            for dispatch in pipeline.placement_dispatches():
                subprocess.run(["hyprctl", "dispatch", dispatch], capture_output=True, check=False)
            return
        time.sleep(0.3)
    say("!! the preview window could not be parked under the circle — closing it so it")
    say("!! cannot end up in the recording. The take is unaffected.")
    supervisor.reap(preview)


def run_meter(source: str, desktop: str, stop: threading.Event) -> None:
    """Print a live mic bar until Enter is pressed."""
    try:
        process = subprocess.Popen(
            pipeline.meter_argv(source),
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
            text=True,
            start_new_session=True,
        )
    except OSError:
        return
    try:
        assert process.stdout is not None
        for line in process.stdout:
            if stop.is_set():
                break
            level = meter.parse_peak(line)
            if level is not None:
                sys.stderr.write(meter.line(level, desktop))
                sys.stderr.flush()
    finally:
        supervisor.reap(process)
        sys.stderr.write("\n")
        sys.stderr.flush()


def watch_sources(pid: int, started: float, stop: threading.Event) -> None:
    """Shout when PipeWire moves one of our captures to a different source.

    It never stops the take. Forty minutes of screen capture is not thrown away over
    one audio track, and the two untouched tracks mean a bad one is recoverable — the
    warning exists so you know which minute went bad without listening to the whole take.
    """
    def snapshot() -> dict[str, str | None]:
        dump = subprocess.run(["pw-dump"], capture_output=True, text=True, check=False).stdout
        return audio.capture_sources(dump, pid)

    previous = snapshot()
    while not stop.wait(WATCH_INTERVAL):
        current = snapshot()
        for stream, was, now in audio.moves(previous, current):
            say(audio.move_warning(supervisor.elapsed(time.monotonic() - started), stream, was, now))
        previous = {**previous, **current}


def open_preview_holder(fifo: Path) -> int:
    """Hold the preview fifo open ourselves, read-write.

    This removes the open-ordering race between ffplay and ffmpeg entirely: a plain
    write-open blocks until a reader arrives, and a reader that arrives second misses
    the stream header. Read-write never blocks, and nothing sees EOF while we hold it.
    """
    return os.open(fifo, os.O_RDWR | os.O_NONBLOCK)


def release_preview(holder: int, preview: subprocess.Popen | None) -> None:
    """Let go of the fifo, then reap the reader.

    Order matters: while the holder fd is open the reader can never see EOF, so waiting
    on ffplay first would hang.
    """
    os.close(holder)
    supervisor.reap(preview)


REQUIRED_TOOLS = ("ffmpeg", "ffplay", "wf-recorder", "gphoto2", "pw-dump", "pw-metadata")
OPTIONAL_TOOLS = ("hyprctl",)
"""Without hyprctl the preview simply does not get parked; the take is unaffected."""


def missing_tools(tools: tuple[str, ...] = REQUIRED_TOOLS) -> list[str]:
    """Which of these are not on PATH."""
    return [tool for tool in tools if not shutil.which(tool)]


def record() -> int:
    directory = config.output_dir()
    directory.mkdir(parents=True, exist_ok=True)
    name_orphans(directory)

    say("preflight…")
    preflight = session.check()
    for line in preflight.summary():
        say(f"  {line}")

    output = directory / takes.take_filename(takes.timestamp())
    runtime = Path(tempfile.mkdtemp(prefix="record-"))
    fifo = runtime / "preview.fifo"
    os.mkfifo(fifo)

    holder = open_preview_holder(fifo)
    screen_read, screen_write = os.pipe()
    camera_read, camera_write = os.pipe()
    preview = wf_recorder = gphoto2 = encoder = None
    stop_meter = threading.Event()
    stop_watch = threading.Event()

    try:
        preview = subprocess.Popen(
            pipeline.ffplay_argv(str(fifo)),
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            start_new_session=True,
        )
        wf_recorder = subprocess.Popen(
            pipeline.wf_recorder_argv(),
            stdout=screen_write,
            stderr=subprocess.DEVNULL,
            start_new_session=True,
        )
        gphoto2 = subprocess.Popen(
            pipeline.gphoto2_argv(),
            stdout=camera_write,
            stderr=subprocess.DEVNULL,
            start_new_session=True,
        )
        encoder = subprocess.Popen(
            pipeline.ffmpeg_argv(
                screen_fd=screen_read,
                camera_fd=camera_read,
                mask=str(MASK),
                mic=preflight.mic,
                desktop=preflight.desktop,
                output=str(output),
                preview=str(fifo),
            ),
            pass_fds=(screen_read, camera_read),
            stdin=subprocess.DEVNULL,
            start_new_session=True,
        )
    except OSError as error:
        for child in (gphoto2, wf_recorder, preview):
            supervisor.reap(child)
        release_preview(holder, None)
        shutil.rmtree(runtime, ignore_errors=True)
        raise errors.PipelineStartError(f"could not start the pipeline: {error}") from error
    finally:
        for descriptor in (screen_write, camera_write, screen_read, camera_read):
            os.close(descriptor)

    started = time.monotonic()
    say(f"\nrolling into {output.name}")
    threading.Thread(target=place_preview, args=(preview,), daemon=True).start()
    threading.Thread(target=watch_sources, args=(encoder.pid, started, stop_watch), daemon=True).start()

    interrupted = False
    try:
        say("check the mic, then press Enter to mark the start. Ctrl-C ends the take.")
        levels = threading.Thread(target=run_meter, args=(preflight.mic, preflight.desktop, stop_meter))
        levels.start()
        try:
            input()
        finally:
            stop_meter.set()
            levels.join(timeout=5)
        say(f"marked at {supervisor.elapsed(time.monotonic() - started)} — trim to here in LosslessCut.")
        while encoder.poll() is None:
            time.sleep(0.5)
        say("ffmpeg stopped on its own — ending the take.")
    except (KeyboardInterrupt, EOFError):
        interrupted = True
        say("\nstopping…")
    finally:
        stop_meter.set()
        stop_watch.set()
        code = supervisor.stop(
            lambda number: os.kill(encoder.pid, number),
            lambda grace: supervisor.wait_for_exit(encoder, grace),
        )
        for child in (gphoto2, wf_recorder):
            supervisor.reap(child)
        release_preview(holder, preview)
        shutil.rmtree(runtime, ignore_errors=True)

    if not output.exists():
        say("no file was written — check the ffmpeg output above.")
        return 1

    say(f"\n{supervisor.elapsed(time.monotonic() - started)} recorded to {output.name}")
    if code not in (0, None) and not interrupted:
        say(f"  (ffmpeg exited {code})")
    try:
        description = input("what was this take? ")
    except (EOFError, KeyboardInterrupt):
        description = ""
        say()
    destination = takes.renamed(output, description)
    if destination != output:
        destination = takes.unique(destination)
        output.rename(destination)
    say(f"saved {destination}")
    return 0


USAGE = """record — one take of the screen, the camera and both audio sources.

usage:
  record           preflight, then a take. Enter marks the start, Ctrl-C ends it.
  record --check   preflight only: is the camera on the right setting, and is the
                   right sink default? Writes nothing.
"""


def main(argv: list[str]) -> int:
    """Run a take, or answer for one. An unknown argument never starts a take."""
    if argv in ([], ["--check"]):
        pass
    elif argv in (["--help"], ["-h"]):
        say(USAGE)
        return 0
    else:
        say(USAGE)
        unknown = next((a for a in argv if a != "--check"), argv[0])
        say(f"record: unrecognised argument {unknown!r}")
        return 2

    absent = missing_tools()
    if absent:
        return complain(errors.ToolUnavailableError(f"missing {', '.join(absent)}"))
    for tool in missing_tools(OPTIONAL_TOOLS):
        say(f"record: {tool} is not on PATH — the preview window will not be parked under the circle")
    if argv == ["--check"]:
        try:
            for line in session.check().summary():
                say(line)
        except errors.RecordError as error:
            return complain(error)
        say("ready")
        return 0
    try:
        return record()
    except errors.RecordError as error:
        return complain(error)


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
