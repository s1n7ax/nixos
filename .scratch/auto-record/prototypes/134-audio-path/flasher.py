#!/usr/bin/env python3
"""A fullscreen black window that flashes white, and clicks at the same instant.

Point the R5 at the monitor and record. The composite then carries the same
flash twice - once through the desktop branch and once, later, through the
camera - and the distance between them IS the camera's lag, measured on the
real pipeline rather than inferred from #127's clock photograph.

The click goes to the default sink in the same process and on the same tick,
so the desktop-audio branch gets a mark that lines up with the flash frame.

    python flasher.py --period 2.0 --flashes 12
"""

import argparse
import time

import gi

gi.require_version("Gst", "1.0")
gi.require_version("Gtk", "4.0")

from gi.repository import GLib, Gst, Gtk  # noqa: E402

Gst.init(None)


class Flasher:
    def __init__(self, args):
        self.args = args
        self.n = 0
        self.white = False
        self.marks = []
        # A square wave held at zero volume, opened for one flash. Same
        # process as the window, so the click and the white frame are on the
        # same main-loop tick; two processes could not promise that.
        self.audio = Gst.parse_launch(
            "audiotestsrc wave=square freq=1000 is-live=true "
            "! volume name=vol volume=0 ! audioconvert ! audioresample "
            "! pipewiresink sync=false"
        )
        self.vol = self.audio.get_by_name("vol")
        self.audio.set_state(Gst.State.PLAYING)

    def build(self, app):
        self.win = Gtk.ApplicationWindow(application=app)
        self.win.set_title("proto134 flasher")
        self.area = Gtk.DrawingArea()
        self.area.set_draw_func(self.draw)
        self.win.set_child(self.area)
        self.win.fullscreen()
        self.win.present()
        GLib.timeout_add(int(self.args.period * 1000), self.flash)

    def draw(self, _area, cr, w, h):
        v = 1.0 if self.white else 0.0
        cr.set_source_rgb(v, v, v)
        cr.rectangle(0, 0, w, h)
        cr.fill()

    def flash(self):
        if self.n >= self.args.flashes:
            self.audio.set_state(Gst.State.NULL)
            self.win.close()
            return False
        self.n += 1
        self.white = True
        self.vol.set_property("volume", 0.4)
        self.area.queue_draw()
        self.marks.append(time.monotonic())
        print(f"flash {self.n} at {time.monotonic():.4f}", flush=True)
        GLib.timeout_add(self.args.width, self.unflash)
        return True

    def unflash(self):
        self.white = False
        self.vol.set_property("volume", 0.0)
        self.area.queue_draw()
        return False


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--period", type=float, default=2.0, help="seconds between flashes")
    ap.add_argument("--flashes", type=int, default=12)
    ap.add_argument("--width", type=int, default=50, help="ms the flash lasts")
    args = ap.parse_args()

    app = Gtk.Application(application_id="dev.proto134.flasher")
    f = Flasher(args)
    app.connect("activate", f.build)
    app.run([])


if __name__ == "__main__":
    main()
