"""The four draggable corners of the page, in photo coordinates."""

from __future__ import annotations

import math

from perspective import Quad, full_frame

Point = tuple[float, float]

DEFAULT_INSET = 0.05
CORNER_COUNT = 4


class Selection:
    """A quad whose corners stay inside the photo.

    Corner 0 is meant for the top-left of the page and the rest follow
    clockwise, which is what decides how the crop comes out rotated. Dragging a
    corner past its neighbour is allowed and folds the result, so the handles
    are labelled by position rather than policed.
    """

    def __init__(self, width: int, height: int, inset: float = DEFAULT_INSET) -> None:
        self.width = width
        self.height = height
        self.inset = inset
        self.selected = 0
        self.reset()

    @property
    def corners(self) -> Quad:
        return tuple(self._corners)

    def reset(self) -> None:
        """Put every corner back on the inset frame of the photo."""
        self._corners = list(full_frame(self.width, self.height, self.inset))
        self.selected = 0

    def move(self, index: int, point: Point) -> None:
        """Drop corner ``index`` on ``point``, clamped to the photo."""
        x = min(max(point[0], 0.0), float(self.width))
        y = min(max(point[1], 0.0), float(self.height))
        self._corners[index] = (x, y)

    def nudge(self, index: int, delta: Point) -> None:
        """Shift corner ``index`` by ``delta`` photo pixels."""
        current = self._corners[index]
        self.move(index, (current[0] + delta[0], current[1] + delta[1]))

    def nearest(self, point: Point, within: float = math.inf) -> int | None:
        """Index of the corner closest to ``point``, or None if all are further than ``within``."""
        index = min(range(CORNER_COUNT), key=lambda i: math.dist(point, self._corners[i]))
        return index if math.dist(point, self._corners[index]) <= within else None

    def select(self, index: int) -> None:
        self.selected = index % CORNER_COUNT

    def select_next(self, step: int = 1) -> None:
        self.select(self.selected + step)
