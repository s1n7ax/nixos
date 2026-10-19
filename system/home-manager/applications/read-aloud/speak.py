"""Read text from stdin aloud with a local voice.

Markdown is read as prose: fenced code blocks become the words "code block"
and markup symbols, link URLs and images are dropped. Only one read plays at
a time: a new read stops the one in progress, and `speak --stop` stops it.
"""

import argparse
import contextlib
import fcntl
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


SIGNALS = (signal.SIGTERM, signal.SIGINT, signal.SIGHUP)


@contextlib.contextmanager
def locked():
    """Hold the read lock with quit signals deferred until it is released.

    Every change to the pid file happens under this lock, so starting,
    stopping and finishing reads never interleave.
    """
    path = pid_file() + ".lock"
    previous = signal.pthread_sigmask(signal.SIG_BLOCK, SIGNALS)
    try:
        with open(path, "a") as f:
            fcntl.flock(f, fcntl.LOCK_EX)
            yield
    finally:
        signal.pthread_sigmask(signal.SIG_SETMASK, previous)


def start_time(pid):
    """Return when process `pid` started, or None when it is gone.

    Uses /proc on Linux and `ps` elsewhere (macOS). Together with the pid it
    names one process, so a reused pid is not mistaken for it.
    """
    try:
        with open(f"/proc/{pid}/stat") as f:
            return f.read().rsplit(")", 1)[1].split()[19]
    except FileNotFoundError:
        if os.path.isdir("/proc/self"):
            return None
    except (OSError, IndexError):
        return None
    try:
        out = subprocess.run(
            ["ps", "-o", "lstart=", "-p", str(pid)],
            capture_output=True,
            text=True,
            check=False,
        ).stdout.strip()
    except OSError:
        return None
    return out or None


def record(pgid, pids):
    """Return the pid file contents for a read in group `pgid`."""
    return {"pgid": pgid, "procs": [[pid, start_time(pid)] for pid in pids]}


def read_record(path):
    """Return the read recorded in `path`, or None."""
    try:
        with open(path) as f:
            data = json.load(f)
        return {"pgid": int(data["pgid"]), "procs": data["procs"]}
    except (OSError, ValueError, TypeError, KeyError):
        return None


def write_record(path, data):
    """Record the running read in `path`."""
    with open(path, "w") as f:
        json.dump(data, f)


def remove_record(path, pgid):
    """Delete `path` if it still names the read in group `pgid`.

    Returns whether it did, i.e. whether that read was still the current one.
    """
    current = read_record(path)
    if current is None or current["pgid"] != pgid:
        return False
    with contextlib.suppress(FileNotFoundError):
        os.remove(path)
    return True


def alive(data):
    """Return whether a process of the recorded read still runs in its group.

    A process counts only when its pid, start time and group all match the
    record, so a group id reused by an unrelated program is never matched.
    """
    for pid, started in data["procs"]:
        if started is None or start_time(pid) != started:
            continue
        try:
            if os.getpgid(pid) == data["pgid"]:
                return True
        except ProcessLookupError:
            continue
    return False


def kill(data):
    """Send SIGTERM to the recorded read's group if it is still that read."""
    if not alive(data):
        return
    try:
        os.killpg(data["pgid"], signal.SIGTERM)
    except (ProcessLookupError, PermissionError):
        pass


def stop_locked():
    """Stop the running read, if there is one; the caller holds the lock."""
    path = pid_file()
    data = read_record(path)
    if data is not None:
        kill(data)
    with contextlib.suppress(FileNotFoundError):
        os.remove(path)


def stop():
    """Stop the running read, if there is one."""
    with locked():
        stop_locked()


def pipeline():
    """Return the commands that turn text on stdin into sound."""
    override = os.environ.get("SPEAK_PIPELINE")
    return json.loads(override) if override else PIPELINE


def unblock_signals():
    """Let a spawned process receive the quit signals `locked` defers."""
    signal.pthread_sigmask(signal.SIG_UNBLOCK, SIGNALS)


def spawn(commands):
    """Start `commands` as one piped process group and return the processes."""
    procs = []
    for index, argv in enumerate(commands):
        last = index == len(commands) - 1
        procs.append(
            subprocess.Popen(
                argv,
                stdin=procs[-1].stdout if procs else subprocess.PIPE,
                stdout=None if last else subprocess.PIPE,
                process_group=procs[0].pid if procs else 0,
                preexec_fn=unblock_signals,
            )
        )
        if index > 0:
            procs[-2].stdout.close()
    return procs


def speak(text):
    """Speak `text`, blocking until it ends or another read stops it.

    Stops the read in progress first. Returns the exit status: 0 when the
    read finished or was stopped.
    """
    path = pid_file()
    with locked():
        stop_locked()
        procs = spawn(pipeline())
        mine = record(procs[0].pid, [proc.pid for proc in procs])
        write_record(path, mine)

        def on_signal(signum, _frame):
            """Stop this read's processes when speak itself is told to quit."""
            with locked():
                kill(mine)
                remove_record(path, mine["pgid"])
            sys.exit(128 + signum)

        for signum in SIGNALS:
            signal.signal(signum, on_signal)

    try:
        procs[0].stdin.write(text.encode())
        procs[0].stdin.close()
    except BrokenPipeError:
        pass
    codes = [proc.wait() for proc in procs]

    with locked():
        current = remove_record(path, mine["pgid"])
    if not current:
        return 0
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

    if not prose.strip():
        stop()
        return 0
    return speak(prose)


if __name__ == "__main__":
    sys.exit(main())
