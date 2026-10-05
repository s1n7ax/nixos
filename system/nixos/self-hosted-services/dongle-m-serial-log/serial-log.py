"""Timestamped logger for the SONOFF Dongle-M serial console.

Usage: dongle-m-serial-log DEVICE LOG_DIR

Reads the ESP32's UART0 through the dongle's CP2102N (USB-C) and appends
every line, prefixed with an ISO 8601 timestamp that carries the UTC
offset, to LOG_DIR/console.log. Each ESP32 boot ROM banner
("rst:0x.. (REASON),boot:0x..") is also copied to LOG_DIR/resets.log
together with the lines just before it, so the reason for every reboot is
kept after console.log has rotated.

DTR and RTS drive the ESP32's EN and IO0 pins through the auto-reset
circuit, so the logger never moves them: the port is opened read-only and
no modem-control ioctl is ever issued. The one change comes from the kernel
on the first open after plug-in: the cp210x driver raises both lines in a
single USB request, and both asserted together leaves EN and IO0 alone.
HUPCL is cleared, so closing or restarting the logger leaves the lines as
they are.
"""

import collections
import datetime
import errno
import fcntl
import logging
import logging.handlers
import os
import re
import select
import signal
import struct
import sys
import termios

BAUD = termios.B115200
MIB = 1024 * 1024
CONSOLE_MAX_BYTES, CONSOLE_BACKUPS = 16 * MIB, 9
RESETS_MAX_BYTES, RESETS_BACKUPS = 1 * MIB, 4
# Lines copied to resets.log ahead of each banner: a panic, watchdog or
# brownout message is printed just before the chip resets.
CONTEXT_LINES = 30
# A line still open after this much silence is written anyway, so the last
# output before a power cut is not held back until the next newline.
IDLE_FLUSH_SECONDS = 1.0
# Output without newlines (binary data) is cut into pieces of this size.
MAX_LINE_BYTES = 4096

RESET_BANNER = re.compile(r"\brst:0x[0-9a-fA-F]+")
ANSI_COLOUR = re.compile(r"\x1b\[[0-9;]*m")
CONTROL_CHAR = re.compile(r"[\x00-\x08\x0b-\x1f\x7f]")


class Stop(BaseException):
    """Raised by the signal handler.

    A BaseException, so logging's own `except Exception` can't swallow it.
    """


def on_signal(signum, frame):
    raise Stop(signal.Signals(signum).name)


def now():
    return datetime.datetime.now().astimezone().isoformat(
        timespec="milliseconds"
    )


def rotating_log(path, max_bytes, backups):
    handler = logging.handlers.RotatingFileHandler(
        path, maxBytes=max_bytes, backupCount=backups, encoding="utf-8"
    )
    handler.setFormatter(logging.Formatter("%(message)s"))
    log = logging.getLogger(path)
    log.setLevel(logging.INFO)
    log.propagate = False
    log.addHandler(handler)
    return log.info


def clean(raw):
    """Turn raw bytes into one printable line, escaping what isn't text."""
    text = raw.decode("utf-8", "backslashreplace").rstrip("\r")
    text = ANSI_COLOUR.sub("", text)
    return CONTROL_CHAR.sub(lambda m: "\\x%02x" % ord(m.group()), text)


def open_port(path):
    # Read-only: nothing is ever sent to the dongle. O_NONBLOCK keeps open()
    # from waiting for carrier before CLOCAL is set.
    fd = os.open(path, os.O_RDONLY | os.O_NOCTTY | os.O_NONBLOCK)
    # Turn away other non-root openers: a second reader would take bytes
    # out of the log, and tools like esptool toggle DTR/RTS on purpose.
    fcntl.ioctl(fd, termios.TIOCEXCL)
    _, _, cflag, _, _, _, cc = termios.tcgetattr(fd)
    # Raw 8N1: no CR/NL translation, no XON/XOFF, no RTS/CTS flow control
    # (that would hand RTS to the chip), and no DTR/RTS drop on close.
    off = termios.CSIZE | termios.PARENB | termios.CSTOPB
    off |= termios.CRTSCTS | termios.HUPCL
    cflag = (cflag & ~off) | termios.CS8 | termios.CREAD | termios.CLOCAL
    cc[termios.VMIN], cc[termios.VTIME] = 1, 0
    termios.tcsetattr(fd, termios.TCSANOW, [0, 0, cflag, 0, BAUD, BAUD, cc])
    return fd


def modem_lines(fd):
    """Read (never set) DTR and RTS as the chip reports them."""
    try:
        buf = fcntl.ioctl(fd, termios.TIOCMGET, struct.pack("i", 0))
    except OSError as error:
        return "DTR/RTS unreadable (%s)" % error.strerror
    bits = struct.unpack("i", buf)[0]
    return "DTR=%s RTS=%s" % (
        "on" if bits & termios.TIOCM_DTR else "off",
        "on" if bits & termios.TIOCM_RTS else "off",
    )


def describe(path):
    """Name the tty and the USB device behind it, to show what matched."""
    tty = os.path.basename(os.path.realpath(path))
    port = os.path.realpath("/sys/class/tty/%s/device" % tty)
    usb = os.path.dirname(os.path.dirname(port))
    fields = [tty]
    for attr in ("idVendor", "idProduct", "manufacturer", "product",
                 "serial"):
        try:
            with open(os.path.join(usb, attr)) as f:
                fields.append("%s=%s" % (attr, f.read().strip()))
        except OSError:
            pass
    return "%s (%s)" % (path, ", ".join(fields))


def main(device, log_dir):
    console = rotating_log(
        os.path.join(log_dir, "console.log"),
        CONSOLE_MAX_BYTES,
        CONSOLE_BACKUPS,
    )
    resets = rotating_log(
        os.path.join(log_dir, "resets.log"),
        RESETS_MAX_BYTES,
        RESETS_BACKUPS,
    )
    context = collections.deque(maxlen=CONTEXT_LINES)

    def note(message):
        line = "%s -- logger: %s" % (now(), message)
        console(line)
        resets(line)

    def emit(stamp, raw):
        text = clean(raw)
        line = "%s %s" % (stamp, text) if text else stamp
        console(line)
        if RESET_BANNER.search(text):
            for earlier in context:
                resets(earlier)
            resets(line)
            context.clear()
        else:
            context.append(line)

    signal.signal(signal.SIGTERM, on_signal)
    signal.signal(signal.SIGINT, on_signal)

    fd = open_port(device)
    note("opened %s at 115200 8N1, %s" % (describe(device), modem_lines(fd)))

    # Each line is stamped with the time its first byte arrived.
    pending, stamp, why = bytearray(), None, "exited"
    try:
        while True:
            timeout = IDLE_FLUSH_SECONDS if pending else None
            ready, _, _ = select.select([fd], [], [], timeout)
            if not ready:
                emit(stamp, pending)
                pending.clear()
                continue
            try:
                chunk = os.read(fd, 4096)
            except BlockingIOError:
                continue
            except OSError as error:
                if error.errno != errno.EIO:
                    raise
                chunk = b""
            if not chunk:
                why = "device went away"
                break
            when = now()
            parts = chunk.split(b"\n")
            for i, part in enumerate(parts):
                complete = i < len(parts) - 1
                if not part and not complete:
                    break
                if not pending:
                    stamp = when
                pending += part
                while len(pending) > MAX_LINE_BYTES:
                    emit(stamp, pending[:MAX_LINE_BYTES])
                    del pending[:MAX_LINE_BYTES]
                if complete:
                    emit(stamp, pending)
                    pending.clear()
    except Stop as stop:
        why = "stopped by %s" % stop
    except Exception as error:
        why = "failed: %r" % error
        raise
    finally:
        if pending:
            emit(stamp, pending)
        note(why)
        try:
            fcntl.ioctl(fd, termios.TIOCNXCL)
        except OSError:
            pass
        os.close(fd)


if __name__ == "__main__":
    if len(sys.argv) != 3:
        sys.exit("usage: %s DEVICE LOG_DIR" % sys.argv[0])
    main(sys.argv[1], sys.argv[2])
