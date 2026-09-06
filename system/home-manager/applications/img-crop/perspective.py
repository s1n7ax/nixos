"""Pure geometry for the four-point perspective crop.

Corners are always ordered top-left, top-right, bottom-right, bottom-left and
expressed in pixel coordinates of the source image.
"""

from __future__ import annotations

import math

import numpy as np
from PIL import Image

Point = tuple[float, float]
Quad = tuple[Point, Point, Point, Point]

TOP_LEFT, TOP_RIGHT, BOTTOM_RIGHT, BOTTOM_LEFT = range(4)


def distance(first: Point, second: Point) -> float:
    """Euclidean distance between two points."""
    return math.hypot(second[0] - first[0], second[1] - first[1])


def full_frame(width: int, height: int, inset: float = 0.0) -> Quad:
    """The whole image as a quad, optionally pulled in by a fraction of each side."""
    left = width * inset
    right = width - left
    top = height * inset
    bottom = height - top
    return ((left, top), (right, top), (right, bottom), (left, bottom))


def output_size(corners: Quad) -> tuple[int, int]:
    """Size of the rectangle the quad is straightened into.

    Each dimension takes the longer of the two opposite sides so nothing in the
    selection gets squeezed away.
    """
    top_left, top_right, bottom_right, bottom_left = corners
    width = max(distance(top_left, top_right), distance(bottom_left, bottom_right))
    height = max(distance(top_left, bottom_left), distance(top_right, bottom_right))
    return max(1, round(width)), max(1, round(height))


def perspective_coefficients(destination: Quad, source: Quad) -> list[float]:
    """Solve the projective map that carries each destination point to its source point.

    The eight coefficients are what ``Image.transform`` consumes: it walks the
    output raster and samples the input at ``((a*x + b*y + c) / (g*x + h*y + 1),
    (d*x + e*y + f) / (g*x + h*y + 1))``.
    """
    rows = []
    targets = []
    for (out_x, out_y), (in_x, in_y) in zip(destination, source, strict=True):
        rows.append([out_x, out_y, 1, 0, 0, 0, -in_x * out_x, -in_x * out_y])
        rows.append([0, 0, 0, out_x, out_y, 1, -in_y * out_x, -in_y * out_y])
        targets.extend((in_x, in_y))

    solution = np.linalg.solve(np.array(rows, dtype=float), np.array(targets, dtype=float))
    return solution.tolist()


def project(coefficients: list[float], point: Point) -> Point:
    """Apply the eight coefficients to a destination point, yielding a source point."""
    a, b, c, d, e, f, g, h = coefficients
    x, y = point
    denominator = g * x + h * y + 1
    return ((a * x + b * y + c) / denominator, (d * x + e * y + f) / denominator)


def warp(image: Image.Image, corners: Quad) -> Image.Image:
    """Straighten the quad selected on ``image`` into an upright rectangle."""
    width, height = output_size(corners)
    destination = ((0, 0), (width, 0), (width, height), (0, height))
    coefficients = perspective_coefficients(destination, corners)
    straightened = image.transform(
        (width, height),
        Image.Transform.PERSPECTIVE,
        coefficients,
        resample=Image.Resampling.BICUBIC,
    )

    if "icc_profile" in image.info:
        straightened.info["icc_profile"] = image.info["icc_profile"]

    return straightened
