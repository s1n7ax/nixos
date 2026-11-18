"""Tell a parked vehicle that Frigate found again from a vehicle that arrived.

Frigate loses a vehicle that sits still (the light changes, someone stands in
front of it) and later tracks it as a new event; or a long-tracked one gets its
clip late, when its box flickers. With vehicles parked side by side, its track
also jumps between them, so its path hops from one to the other. Either way
nothing arrived. A vehicle is parked when it has not moved since Frigate first
saw it and was first seen a while ago; or when an earlier vehicle event on the
same camera ended in the same place, and every point of its path is where it
stands now or where an earlier vehicle stood still.

Boxes are (x1, y1, x2, y2) and points (x, y), both as fractions of the frame.
Frigate's path points are the bottom centre of the box.
"""

from __future__ import annotations

from collections.abc import Awaitable, Callable, Iterable
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
# A still vehicle's path points stay this share of its box's width to either side
# of where it stands now, and this share of its height above it: a flickering box
# keeps only the vehicle's top, which lifts its bottom by up to a third. Below it,
# only POINT_GROWTH.
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
    # Every path point stayed where the vehicle stood: it never moved.
    stood_still: bool = False


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


def _stands_at(point: Point, box: Box) -> bool:
    """Whether a path point is close to where a vehicle in this box stands, the
    bottom centre of the box."""
    x, y = (box[0] + box[2]) / 2, box[3]
    width, height = box[2] - box[0], box[3] - box[1]
    return (
        abs(point[0] - x) <= width * STILL_WIDTH_SHARE
        and -height * STILL_HEIGHT_SHARE <= point[1] - y <= height * POINT_GROWTH
    )


def still(box: Box, path: Iterable[Point]) -> bool:
    """Whether every point of the path so far is close to where the vehicle stands now."""
    return all(_stands_at(point, box) for point in path)


def on_spots(path: Iterable[Point], spots: Iterable[Box]) -> bool:
    """Whether every point of the path is where a vehicle stands in one of the spots:
    Frigate's track jumped between parked vehicles side by side, it did not move."""
    spots = list(spots)
    return all(any(_stands_at(point, spot) for spot in spots) for point in path)


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


def parked_spot(sighting: Sighting, now: float) -> bool:
    """Whether an earlier vehicle event stood still in its place, in the last day."""
    if sighting.end_time is not None and now - sighting.end_time > MEMORY_SECONDS:
        return False
    return sighting.stood_still


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
        sighted = (x, y, x + w, y + h)
        found.append(Sighting(sighted, points[-1], ended, still(sighted, points)))
    return found


async def is_parked(
    *,
    label: str,
    box: Box | None,
    path: Iterable[Point],
    event_id: str,
    start_time: float,
    now: float,
    earlier: Callable[[], Awaitable[Iterable[Any] | None]],
) -> bool:
    """Whether a detection is a parked vehicle that Frigate found again.

    `box` is where it is now, as fractions of the frame. `earlier` fetches the
    camera's newest vehicle events from Frigate's `api/events`, or None when they
    cannot be read; the detection then alerts as usual. It is not called for a
    vehicle that stood still for a while.
    """
    if label not in VEHICLES or box is None:
        return False
    path = list(path)
    if still(box, path) and seen_for_a_while(start_time, now):
        return True
    events = await earlier()
    if events is None:
        return False
    found = sightings(events, event_id, start_time)
    if not any(ended_here(s, box, now) for s in found):
        return False
    spots = [box, *(s.box for s in found if parked_spot(s, now))]
    return on_spots(path, spots)
