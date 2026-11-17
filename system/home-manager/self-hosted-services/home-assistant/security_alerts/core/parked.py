"""Tell a parked vehicle that Frigate found again from a vehicle that arrived.

Frigate loses a vehicle that sits still (the light changes, someone stands in
front of it) and later tracks it as a new event; or a long-tracked one gets its
clip late, when its box flickers. Either way nothing arrived. A vehicle is
parked when it has not moved since Frigate first saw it, and it was either
first seen a while ago, or an earlier vehicle event on the same camera ended in
the same place.

Boxes are (x1, y1, x2, y2) and points (x, y), both as fractions of the frame.
Frigate's path points are the bottom centre of the box.
"""

from __future__ import annotations

from collections.abc import Iterable
from dataclasses import dataclass
from typing import Any

from .geometry import Box

Point = tuple[float, float]

VEHICLES = frozenset({"bicycle", "bus", "car", "motorcycle", "truck"})
# A vehicle still in its first place this long after Frigate first saw it was
# already standing there.
SEEN_FOR_SECONDS = 60
# How long ago an earlier event may have ended in the same place.
MEMORY_SECONDS = 24 * 60 * 60
# Boxes that overlap this much are the same place.
SAME_PLACE_IOU = 0.5
# A parked vehicle's box flickers; its points may fall this share outside it.
POINT_GROWTH = 0.1
# A still vehicle's path points stay this share of its box's width and height
# from where it stands now; a flickering box moves its bottom up by a third.
STILL_WIDTH_SHARE = 0.4
STILL_HEIGHT_SHARE = 0.5
# How many of the camera's newest vehicle events to look through.
HISTORY_EVENTS = 100


@dataclass(frozen=True)
class Sighting:
    """An earlier vehicle event on the same camera."""

    box: Box
    last_point: Point
    end_time: float | None


def iou(a: Box, b: Box) -> float:
    """The overlap of two boxes over their union, 0 to 1."""
    width = min(a[2], b[2]) - max(a[0], b[0])
    height = min(a[3], b[3]) - max(a[1], b[1])
    if width <= 0 or height <= 0:
        return 0.0
    overlap = width * height
    union = (a[2] - a[0]) * (a[3] - a[1]) + (b[2] - b[0]) * (b[3] - b[1]) - overlap
    return overlap / union if union > 0 else 0.0


def _inside(point: Point, box: Box, growth: float) -> bool:
    dx = (box[2] - box[0]) * growth
    dy = (box[3] - box[1]) * growth
    return box[0] - dx <= point[0] <= box[2] + dx and box[1] - dy <= point[1] <= box[3] + dy


def still(box: Box, path: Iterable[Point]) -> bool:
    """Whether every point of the path so far is close to where the vehicle stands now,
    the bottom centre of its current box."""
    x, y = (box[0] + box[2]) / 2, box[3]
    width, height = box[2] - box[0], box[3] - box[1]
    return all(
        abs(px - x) <= width * STILL_WIDTH_SHARE and abs(py - y) <= height * STILL_HEIGHT_SHARE
        for px, py in path
    )


def seen_for_a_while(start_time: float, now: float) -> bool:
    return now - start_time >= SEEN_FOR_SECONDS


def ended_here(sighting: Sighting, box: Box, now: float) -> bool:
    """Whether an earlier vehicle event stopped being tracked in this box: it was lost
    where it stood, rather than driving off."""
    if sighting.end_time is not None and now - sighting.end_time > MEMORY_SECONDS:
        return False
    return iou(sighting.box, box) >= SAME_PLACE_IOU and _inside(
        sighting.last_point, box, POINT_GROWTH
    )


def _number(value: Any) -> bool:
    return isinstance(value, int | float) and not isinstance(value, bool)


def path_points(path_data: Any) -> list[Point]:
    """The points of Frigate's `path_data`, a list of [[x, y], time]; malformed ones
    are skipped."""
    points: list[Point] = []
    for entry in path_data if isinstance(path_data, list) else ():
        point = entry[0] if isinstance(entry, list) and entry else None
        if isinstance(point, list) and len(point) == 2 and all(_number(v) for v in point):
            points.append((float(point[0]), float(point[1])))
    return points


def sightings(events: Iterable[Any], event_id: str, start_time: float) -> list[Sighting]:
    """The events from Frigate's `api/events` that began before this one, as sightings.

    Frigate gives an event's box as (x, y, width, height); one without a box or a
    path is skipped.
    """
    found = []
    for event in events:
        if not isinstance(event, dict) or event.get("id") == event_id:
            continue
        began, ended = event.get("start_time"), event.get("end_time")
        if not _number(began) or began >= start_time or not (ended is None or _number(ended)):
            continue
        data = event.get("data")
        if not isinstance(data, dict):
            continue
        box, points = data.get("box"), path_points(data.get("path_data"))
        if not points or not isinstance(box, list) or len(box) != 4:
            continue
        if not all(_number(v) for v in box):
            continue
        x, y, w, h = box
        found.append(Sighting((x, y, x + w, y + h), points[-1], ended))
    return found
