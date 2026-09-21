#!/usr/bin/env python3
"""On-screen "recording" pill for screen-record.

It sits in the bottom-right corner, inside the rectangle that
gpu-screen-recorder fills with the camera overlay, so the pill is visible on
the screen but covered by the facecam in the recorded file.
"""

import argparse
import os
import signal
import sys
import time

import gi

gi.require_version("Gtk", "4.0")
gi.require_version("Gdk", "4.0")
gi.require_version("Gtk4LayerShell", "1.0")

from gi.repository import Gdk, Gio, GLib, Gtk
from gi.repository import Gtk4LayerShell as LayerShell

CSS = b"""
window { background: transparent; }
.pill {
    background: rgba(18, 18, 22, 0.92);
    border: 1px solid rgba(255, 70, 70, 0.75);
    border-radius: 999px;
    padding: 4px 12px;
}
.dot {
    color: #ff3b3b;
    font-size: 15px;
}
.dot.dim { opacity: 0.15; }
.elapsed {
    color: #f4f4f5;
    font-family: monospace;
    font-size: 13px;
    font-weight: bold;
}
"""

MARGIN = 6
BLINK_MS = 600
WATCH_MS = 1000


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--max-width", type=int, default=384)
    parser.add_argument("--max-height", type=int, default=216)
    parser.add_argument("--monitor", default="")
    parser.add_argument("--watch-pid", type=int, default=0)
    return parser.parse_args()


def format_elapsed(seconds: int) -> str:
    hours, rest = divmod(seconds, 3600)
    minutes, secs = divmod(rest, 60)
    if hours:
        return f"{hours}:{minutes:02d}:{secs:02d}"
    return f"{minutes}:{secs:02d}"


def find_monitor(connector: str) -> Gdk.Monitor | None:
    """Resolves a Hyprland monitor name (e.g. DP-1) to the matching Gdk.Monitor.

    Returns None when the name is unknown, which leaves placement to the
    compositor.
    """
    if not connector:
        return None

    display = Gdk.Display.get_default()
    if display is None:
        return None

    monitors = display.get_monitors()
    for index in range(monitors.get_n_items()):
        monitor = monitors.get_item(index)
        if monitor.get_connector() == connector:
            return monitor

    return None


def build_pill(args: argparse.Namespace) -> tuple[Gtk.Widget, Gtk.Label, Gtk.Label]:
    dot = Gtk.Label(label="●")
    dot.add_css_class("dot")

    elapsed = Gtk.Label(label=format_elapsed(0))
    elapsed.add_css_class("elapsed")

    pill = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
    pill.add_css_class("pill")
    pill.set_size_request(
        min(110, max(20, args.max_width - MARGIN)),
        min(32, max(12, args.max_height - MARGIN)),
    )
    pill.append(dot)
    pill.append(elapsed)

    return pill, dot, elapsed


def on_activate(app: Gtk.Application, args: argparse.Namespace) -> None:
    win = Gtk.ApplicationWindow(application=app)
    win.set_decorated(False)

    LayerShell.init_for_window(win)
    LayerShell.set_layer(win, LayerShell.Layer.OVERLAY)
    monitor = find_monitor(args.monitor)
    if monitor is not None:
        LayerShell.set_monitor(win, monitor)
    LayerShell.set_anchor(win, LayerShell.Edge.BOTTOM, True)
    LayerShell.set_anchor(win, LayerShell.Edge.RIGHT, True)
    LayerShell.set_margin(win, LayerShell.Edge.BOTTOM, MARGIN)
    LayerShell.set_margin(win, LayerShell.Edge.RIGHT, MARGIN)
    LayerShell.set_namespace(win, "screen-record-indicator")

    pill, dot, elapsed = build_pill(args)
    win.set_child(pill)

    started = time.monotonic()

    def tick() -> bool:
        elapsed.set_label(format_elapsed(int(time.monotonic() - started)))
        return GLib.SOURCE_CONTINUE

    def blink() -> bool:
        if dot.has_css_class("dim"):
            dot.remove_css_class("dim")
        else:
            dot.add_css_class("dim")
        return GLib.SOURCE_CONTINUE

    def watch_recorder() -> bool:
        """Quits with the recorder so a crashed capture cannot leave the pill up."""
        try:
            os.kill(args.watch_pid, 0)
        except ProcessLookupError:
            app.quit()
            return GLib.SOURCE_REMOVE
        except PermissionError:
            pass
        return GLib.SOURCE_CONTINUE

    GLib.timeout_add_seconds(1, tick)
    GLib.timeout_add(BLINK_MS, blink)
    if args.watch_pid > 0:
        GLib.timeout_add(WATCH_MS, watch_recorder)

    css = Gtk.CssProvider()
    css.load_from_data(CSS)
    Gtk.StyleContext.add_provider_for_display(
        Gdk.Display.get_default(),
        css,
        Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION,
    )

    win.present()


def main() -> int:
    args = parse_args()
    signal.signal(signal.SIGTERM, lambda *_: sys.exit(0))
    signal.signal(signal.SIGINT, lambda *_: sys.exit(0))
    app = Gtk.Application(
        application_id="dev.s1n7ax.screen-record-indicator",
        flags=Gio.ApplicationFlags.NON_UNIQUE,
    )
    app.connect("activate", on_activate, args)
    return app.run([])


if __name__ == "__main__":
    sys.exit(main())
