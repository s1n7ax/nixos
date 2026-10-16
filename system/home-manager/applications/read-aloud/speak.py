"""Read text from stdin aloud with a local voice.

Markdown is read as prose: fenced code blocks become the words "code block"
and markup symbols, link URLs and images are dropped. Only one read plays at
a time: a new read stops the one in progress, and `speak --stop` stops it.
"""

import argparse
import json
import os
import re
import signal
import subprocess
import sys

PIPELINE = json.loads('@pipeline@')

FENCE = re.compile(r"^ {0,3}(`{3,}|~{3,})")
BLOCKQUOTE = re.compile(r"^(\s*>)+\s?")
HEADING = re.compile(r"^(\s*)#{1,6}(\s+|$)")
HEADING_CLOSE = re.compile(r"\s+#+\s*$")
BULLET = re.compile(r"^(\s*)[-*+]\s+")
IMAGE = re.compile(r"!\[[^\]]*\]\([^)]*\)")
LINK = re.compile(r"\[([^\]]*)\]\([^)]*\)")
AUTOLINK = re.compile(r"<https?://[^>\s]*>")
URL = re.compile(r"https?://\S+")
UNDERSCORE = re.compile(r"(?<![^\W_])_+|_+(?![^\W_])")


def pid_file():
    """Return the file that holds the process group of the running read."""
    env = os.environ
    base = env.get("XDG_RUNTIME_DIR") or env.get("TMPDIR") or "/tmp"
    return os.path.join(base, "speak.pid")


def prose_line(line):
    """Return one markdown line, outside code blocks, as prose."""
    line = BLOCKQUOTE.sub("", line)
    if HEADING.match(line):
        line = HEADING_CLOSE.sub("", HEADING.sub(r"\1", line))
    line = BULLET.sub(r"\1", line)
    line = IMAGE.sub("", line)
    line = LINK.sub(r"\1", line)
    line = AUTOLINK.sub("", line)
    line = URL.sub("", line)
    line = line.replace("`", "").replace("*", "")
    return UNDERSCORE.sub("", line)


def closes(marker, fence):
    """Return whether the line `marker` closes the code block `fence`."""
    return marker == fence[0] * len(marker) and len(marker) >= len(fence)


def to_prose(text):
    """Return markdown text as prose; plain text passes through as is."""
    out = []
    fence = None
    for line in text.split("\n"):
        match = FENCE.match(line)
        if fence is None:
            if match:
                fence = match.group(1)
                out.append("code block.")
            else:
                out.append(prose_line(line))
        elif match and closes(line.strip(), fence):
            fence = None
    return "\n".join(out)


def read_pgid(path):
    """Return the process group recorded in `path`, or None."""
    try:
        with open(path) as f:
            return int(f.read().strip())
    except (OSError, ValueError):
        return None


def stop():
    """Stop the running read, if there is one."""
    path = pid_file()
    pgid = read_pgid(path)
    if pgid is None:
        return
    try:
        os.killpg(pgid, signal.SIGTERM)
    except (ProcessLookupError, PermissionError):
        pass
    try:
        os.remove(path)
    except FileNotFoundError:
        pass


def pipeline():
    """Return the commands that turn text on stdin into sound."""
    override = os.environ.get("SPEAK_PIPELINE")
    return json.loads(override) if override else PIPELINE


def speak(text):
    """Speak `text`, blocking until it ends or another read stops it.

    Returns the exit status: 0 when the read finished or was stopped.
    """
    path = pid_file()
    procs = []
    commands = pipeline()
    for index, argv in enumerate(commands):
        last = index == len(commands) - 1
        procs.append(
            subprocess.Popen(
                argv,
                stdin=procs[-1].stdout if procs else subprocess.PIPE,
                stdout=None if last else subprocess.PIPE,
                process_group=procs[0].pid if procs else 0,
            )
        )
        if index == 0:
            pgid = procs[0].pid
            with open(path, "w") as f:
                f.write(f"{pgid}\n")
        else:
            procs[-2].stdout.close()

    def on_signal(signum, _frame):
        """Stop this read's processes when speak itself is told to quit."""
        try:
            os.killpg(pgid, signal.SIGTERM)
        except ProcessLookupError:
            pass
        sys.exit(128 + signum)

    for signum in (signal.SIGTERM, signal.SIGINT, signal.SIGHUP):
        signal.signal(signum, on_signal)

    try:
        procs[0].stdin.write(text.encode())
        procs[0].stdin.close()
    except BrokenPipeError:
        pass
    codes = [proc.wait() for proc in procs]

    if read_pgid(path) != pgid:
        return 0
    os.remove(path)
    return 0 if all(code == 0 for code in codes) else 1


def main():
    """Parse the arguments and run the requested action."""
    parser = argparse.ArgumentParser(
        prog="speak",
        description="Read text from stdin aloud with a local voice.",
    )
    group = parser.add_mutually_exclusive_group()
    group.add_argument(
        "--print",
        action="store_true",
        help="write the prose that would be spoken to stdout and exit",
    )
    group.add_argument(
        "--stop", action="store_true", help="stop the running read"
    )
    args = parser.parse_args()

    if args.stop:
        stop()
        return 0

    prose = to_prose(sys.stdin.read())
    if args.print:
        sys.stdout.write(prose)
        return 0

    stop()
    if not prose.strip():
        return 0
    return speak(prose)


if __name__ == "__main__":
    sys.exit(main())
