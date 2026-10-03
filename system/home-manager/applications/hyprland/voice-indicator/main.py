#!/usr/bin/env python3
import json
import math
import os
import signal
import sys
from pathlib import Path

import cairo
import gi

gi.require_version("Gtk", "4.0")
gi.require_version("Gdk", "4.0")
gi.require_version("Gtk4LayerShell", "1.0")

from gi.repository import Gdk, Gio, GLib, Gtk
from gi.repository import Gtk4LayerShell as LayerShell

CSS = b"""
window { background: transparent; }
.indicator {
    background: rgba(18, 18, 22, 0.88);
    border-radius: 28px;
    padding: 10px 22px;
    border: 1px solid rgba(255, 80, 80, 0.55);
    box-shadow: 0 8px 28px rgba(0, 0, 0, 0.55);
}
.indicator.processing {
    border-color: rgba(90, 160, 255, 0.55);
}
"""

WAVE_WIDTH = 240
WAVE_HEIGHT = 36

# hyprwhspr-rs writes its recorder state here (atomically, via rename).
STATUS_FILE = (
    Path(os.environ.get("XDG_CACHE_HOME") or Path.home() / ".cache")
    / "hyprwhspr-rs"
    / "status.json"
)

# status.json "class" -> indicator mode. Anything else hides the indicator.
MODES = {"active": "recording", "processing": "processing"}


class Waveform(Gtk.DrawingArea):
    def __init__(self) -> None:
        super().__init__()
        self.set_content_width(WAVE_WIDTH)
        self.set_content_height(WAVE_HEIGHT)
        self.mode = "recording"
        self.phase = 0.0
        self._last_us: int | None = None
        self.set_draw_func(self._draw)
        self.add_tick_callback(self._tick)

    def _tick(self, _widget, frame_clock) -> bool:
        now = frame_clock.get_frame_time()
        if self._last_us is None:
            self._last_us = now
        # Clamp so the wave does not jump after the window was hidden.
        dt = min((now - self._last_us) / 1_000_000.0, 0.1)
        self._last_us = now
        self.phase += dt * (5.5 if self.mode == "recording" else 2.5)
        self.queue_draw()
        return GLib.SOURCE_CONTINUE

    def _draw(self, _area, cr, width: int, height: int) -> None:
        cy = height / 2
        cr.set_line_width(2.4)
        cr.set_line_cap(1)
        cr.set_line_join(1)

        scale = 0.42 if self.mode == "recording" else 0.18
        steps = max(width, 1)
        cr.move_to(0, cy)
        for i in range(steps + 1):
            t = i / steps
            envelope = math.sin(math.pi * t)
            amp = (height * scale) * envelope * (
                0.62 * math.sin(2 * math.pi * 1.6 * t + self.phase)
                + 0.38 * math.sin(2 * math.pi * 3.1 * t - self.phase * 1.7)
            )
            cr.line_to(i, cy + amp)

        if self.mode == "recording":
            edge, start, end = (1.0, 0.32, 0.32), (1.0, 0.32, 0.32), (1.0, 0.55, 0.32)
        else:
            edge, start, end = (0.35, 0.63, 1.0), (0.35, 0.63, 1.0), (0.55, 0.45, 1.0)
        grad = cairo.LinearGradient(0, 0, width, 0)
        grad.add_color_stop_rgba(0.0, *edge, 0.0)
        grad.add_color_stop_rgba(0.15, *start, 1.0)
        grad.add_color_stop_rgba(0.85, *end, 1.0)
        grad.add_color_stop_rgba(1.0, *edge, 0.0)
        cr.set_source(grad)
        cr.stroke()


def read_mode() -> str | None:
    try:
        status = json.loads(STATUS_FILE.read_text())
    except (OSError, ValueError):
        return None
    return MODES.get(status.get("class"))


def on_activate(app: Gtk.Application) -> None:
    win = Gtk.ApplicationWindow(application=app)
    win.set_decorated(False)
    win.add_css_class("voice-indicator-window")

    LayerShell.init_for_window(win)
    LayerShell.set_layer(win, LayerShell.Layer.OVERLAY)
    LayerShell.set_anchor(win, LayerShell.Edge.BOTTOM, True)
    LayerShell.set_margin(win, LayerShell.Edge.BOTTOM, 80)
    LayerShell.set_namespace(win, "voice-indicator")

    box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=0)
    box.add_css_class("indicator")
    box.set_halign(Gtk.Align.CENTER)
    box.set_valign(Gtk.Align.CENTER)

    wave = Waveform()
    box.append(wave)

    win.set_child(box)

    css = Gtk.CssProvider()
    css.load_from_data(CSS)
    Gtk.StyleContext.add_provider_for_display(
        Gdk.Display.get_default(),
        css,
        Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION,
    )

    def sync(*_args) -> None:
        mode = read_mode()
        if mode is None:
            win.set_visible(False)
            return
        wave.mode = mode
        if mode == "processing":
            box.add_css_class("processing")
        else:
            box.remove_css_class("processing")
        win.set_visible(True)

    # Watch the directory: the file is replaced by rename on every update.
    STATUS_FILE.parent.mkdir(parents=True, exist_ok=True)
    monitor = Gio.File.new_for_path(str(STATUS_FILE.parent)).monitor_directory(
        Gio.FileMonitorFlags.NONE, None
    )
    monitor.connect("changed", sync)
    # Keep a reference so the monitor is not garbage collected.
    win.status_monitor = monitor

    sync()


def main() -> int:
    signal.signal(signal.SIGTERM, lambda *_: sys.exit(0))
    signal.signal(signal.SIGINT, lambda *_: sys.exit(0))
    app = Gtk.Application(application_id="dev.s1n7ax.voice-indicator")
    app.connect("activate", on_activate)
    # The window is hidden while idle; keep the app alive regardless.
    app.hold()
    return app.run([])


if __name__ == "__main__":
    sys.exit(main())
