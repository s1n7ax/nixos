"""Mapping between photo pixels and the pixels drawn on screen."""

from __future__ import annotations

from dataclasses import dataclass

Point = tuple[float, float]


@dataclass(frozen=True)
class Viewport:
    """Where the photo sits inside the canvas, and how much it was shrunk."""

    scale: float
    offset_x: float
    offset_y: float

    @classmethod
    def fit(
        cls,
        image_size: tuple[int, int],
        canvas_size: tuple[float, float],
        margin: float = 0.0,
    ) -> Viewport:
        """Centre the whole photo in the canvas, leaving ``margin`` on every side."""
        image_width, image_height = image_size
        canvas_width, canvas_height = canvas_size
        usable_width = max(1.0, canvas_width - 2 * margin)
        usable_height = max(1.0, canvas_height - 2 * margin)
        scale = min(usable_width / image_width, usable_height / image_height)
        return cls(
            scale=scale,
            offset_x=(canvas_width - image_width * scale) / 2,
            offset_y=(canvas_height - image_height * scale) / 2,
        )

    def to_display(self, point: Point) -> Point:
        """Photo pixel to canvas pixel."""
        return (self.offset_x + point[0] * self.scale, self.offset_y + point[1] * self.scale)

    def to_image(self, point: Point) -> Point:
        """Canvas pixel to photo pixel."""
        return ((point[0] - self.offset_x) / self.scale, (point[1] - self.offset_y) / self.scale)
