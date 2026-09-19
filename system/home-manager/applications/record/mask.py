"""The circle's alpha mask: one grayscale PNG, generated once and reused for the take.

A static mask through `alphamerge`, never `geq`. Benchmarked at 540 px over 300 frames:
`geq` evaluated per frame costs 31.7 ms, the mask 3.8 ms — 8.3x, and `geq` alone cannot
hold 60 fps on CPU. The mask depends only on diameter and feather, both constants, so it
is written at build time and never computed again.

This module is also the build's own source for those numbers: `default.nix` runs it to
get the filename and the lavfi source string, so the circle is described in exactly one
place rather than being hand-copied into Nix.
"""

from __future__ import annotations

import sys

import config


def filename() -> str:
    """What the mask is called, wherever it is written or looked up."""
    return f"circle-mask-{config.CIRCLE_DIAMETER}.png"


def lavfi_source() -> str:
    """The `-f lavfi` input that draws the mask.

    The feather is a linear alpha ramp `feather` pixels wide at the disc's edge, baked
    in once: antialiasing costs nothing at runtime because it is already in the PNG.
    """
    size = config.CIRCLE_DIAMETER
    radius = size / 2
    centre = radius - 0.5
    return (
        f"color=c=black:s={size}x{size},format=gray,"
        f"geq=lum='clip(({radius:g}-hypot(X-{centre:g},Y-{centre:g}))*255/{config.MASK_FEATHER},0,255)'"
    )


if __name__ == "__main__":
    print({"filename": filename, "lavfi": lavfi_source}[sys.argv[1]]())
