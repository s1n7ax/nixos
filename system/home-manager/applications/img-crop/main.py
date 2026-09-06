#!/usr/bin/env python3
"""Paperless-style four-point crop for photos of documents.

``img-crop photo.jpg ...`` opens each photo with a draggable handle on every
corner of the page. Applying rewrites the file with the selected quad
straightened into an upright rectangle, so a hand-held snap of a sheet of paper
comes out looking scanned.
"""

from __future__ import annotations

import sys
from pathlib import Path

import gi
from PIL import Image

import imagefile
from perspective import warp
from render import Preview, draw_scene, preview_surface
from selection import Selection
from viewport import Viewport

gi.require_version("Gtk", "4.0")
gi.require_version("Gdk", "4.0")

from gi.repository import Gdk, Gio, Gtk

APPLICATION_ID = "dev.s1n7ax.img-crop"
CANVAS_MARGIN = 28.0
GRAB_RADIUS = 70.0
NUDGE = 1.0
COARSE_NUDGE = 20.0
HINT = (
    "drag the corners onto the page · tab: next corner · arrows: nudge (shift: faster) · "
    "r: reset · enter: crop · esc: skip · q: quit"
)
CSS = b"""
window { background: #0f0f13; }
label.header { color: #e9e9f2; font-size: 15px; padding: 12px 18px; }
label.footer { color: #9aa0b4; font-size: 13px; padding: 10px 18px; }
label.error { color: #ff7b72; }
"""


class CropWindow(Gtk.ApplicationWindow):
    """One window that walks through every photo given on the command line."""

    def __init__(self, application: Gtk.Application, paths: list[Path]) -> None:
        super().__init__(application=application, title="img-crop")

        self.paths = paths
        self.index = 0
        self.image: Image.Image | None = None
        self.selection: Selection | None = None
        self.preview: Preview | None = None
        self.drag_origin: tuple[float, float] | None = None

        self.header = Gtk.Label(xalign=0.0)
        self.header.add_css_class("header")
        self.footer = Gtk.Label(xalign=0.0)
        self.footer.add_css_class("footer")

        self.canvas = Gtk.DrawingArea(hexpand=True, vexpand=True)
        self.canvas.set_draw_func(self.on_draw)

        drag = Gtk.GestureDrag()
        drag.connect("drag-begin", self.on_drag_begin)
        drag.connect("drag-update", self.on_drag_update)
        self.canvas.add_controller(drag)

        keys = Gtk.EventControllerKey()
        keys.connect("key-pressed", self.on_key)
        self.add_controller(keys)

        layout = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
        layout.append(self.header)
        layout.append(self.canvas)
        layout.append(self.footer)
        self.set_child(layout)

        self.set_default_size(1280, 860)
        self.fullscreen()
        self.hint(HINT)
        self.show_photo()

    def hint(self, message: str, error: bool = False) -> None:
        self.footer.set_text(message)
        if error:
            self.footer.add_css_class("error")
        else:
            self.footer.remove_css_class("error")

    def show_photo(self) -> None:
        """Load the photo at the current index, skipping over anything unreadable."""
        while self.index < len(self.paths):
            path = self.paths[self.index]
            self.image = None
            self.selection = None
            self.preview = None
            try:
                self.image = imagefile.load(path)
            except Exception as error:
                print(f"img-crop: cannot open {path}: {error}", file=sys.stderr)
                self.index += 1
                continue

            self.selection = Selection(self.image.width, self.image.height)
            self.preview = preview_surface(self.image)
            self.header.set_text(
                f"{self.index + 1}/{len(self.paths)}    {path.name}    "
                f"{self.image.width} × {self.image.height}"
            )
            self.hint(HINT)
            self.canvas.queue_draw()
            return

        self.close()

    def advance(self) -> None:
        self.index += 1
        self.show_photo()

    def apply(self) -> None:
        """Straighten the selected quad and write it back over the photo."""
        if self.image is None:
            return

        path = self.paths[self.index]
        try:
            imagefile.save_in_place(
                warp(self.image, self.selection.corners), path, self.image.format
            )
        except (OSError, ValueError) as error:
            self.hint(f"could not write {path.name}: {error}", error=True)
            return

        print(path, flush=True)
        self.advance()

    def viewport(self) -> Viewport:
        return Viewport.fit(
            self.image.size,
            (self.canvas.get_width(), self.canvas.get_height()),
            margin=CANVAS_MARGIN,
        )

    def on_draw(self, area: Gtk.DrawingArea, context, width: int, height: int) -> None:
        if self.image is None:
            return

        draw_scene(
            context,
            (width, height),
            self.preview,
            self.viewport(),
            self.selection.corners,
            self.selection.selected,
        )

    def on_drag_begin(self, gesture: Gtk.GestureDrag, x: float, y: float) -> None:
        if self.image is None:
            return

        viewport = self.viewport()
        grabbed = self.selection.nearest(
            viewport.to_image((x, y)), within=GRAB_RADIUS / viewport.scale
        )
        if grabbed is None:
            self.drag_origin = None
            return

        self.selection.select(grabbed)
        self.drag_origin = self.selection.corners[grabbed]
        self.canvas.queue_draw()

    def on_drag_update(self, gesture: Gtk.GestureDrag, offset_x: float, offset_y: float) -> None:
        if self.drag_origin is None:
            return

        scale = self.viewport().scale
        self.selection.move(
            self.selection.selected,
            (self.drag_origin[0] + offset_x / scale, self.drag_origin[1] + offset_y / scale),
        )
        self.canvas.queue_draw()

    def on_key(
        self,
        controller: Gtk.EventControllerKey,
        keyval: int,
        keycode: int,
        state: Gdk.ModifierType,
    ) -> bool:
        if self.selection is None:
            return False

        step = COARSE_NUDGE if state & Gdk.ModifierType.SHIFT_MASK else NUDGE
        nudges = {
            Gdk.KEY_Left: (-step, 0.0),
            Gdk.KEY_Right: (step, 0.0),
            Gdk.KEY_Up: (0.0, -step),
            Gdk.KEY_Down: (0.0, step),
        }

        if keyval in nudges:
            self.selection.nudge(self.selection.selected, nudges[keyval])
        elif keyval in (Gdk.KEY_Return, Gdk.KEY_KP_Enter):
            self.apply()
            return True
        elif keyval in (Gdk.KEY_Tab, Gdk.KEY_space):
            self.selection.select_next()
        elif keyval == Gdk.KEY_ISO_Left_Tab:
            self.selection.select_next(-1)
        elif keyval in (Gdk.KEY_r, Gdk.KEY_R):
            self.selection.reset()
        elif keyval == Gdk.KEY_Escape:
            self.advance()
            return True
        elif keyval in (Gdk.KEY_q, Gdk.KEY_Q):
            self.close()
            return True
        else:
            return False

        self.canvas.queue_draw()
        return True


def activate(application: Gtk.Application, paths: list[Path]) -> None:
    """Install the styling once the display is up, then show the first photo."""
    provider = Gtk.CssProvider()
    provider.load_from_data(CSS)
    Gtk.StyleContext.add_provider_for_display(
        Gdk.Display.get_default(), provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
    )
    CropWindow(application, paths).present()


def main(argv: list[str]) -> int:
    paths = [Path(argument) for argument in argv[1:]]
    if not paths:
        print("Usage: img-crop <image>...", file=sys.stderr)
        return 1

    for path in paths:
        if not path.is_file():
            print(f"img-crop: not a file: {path}", file=sys.stderr)

    paths = [path for path in paths if path.is_file()]
    if not paths:
        print("img-crop: nothing to crop", file=sys.stderr)
        return 1

    application = Gtk.Application(
        application_id=APPLICATION_ID, flags=Gio.ApplicationFlags.NON_UNIQUE
    )
    application.connect("activate", activate, paths)
    return application.run([])


if __name__ == "__main__":
    sys.exit(main(sys.argv))
