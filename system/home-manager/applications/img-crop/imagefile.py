"""Reading and writing the photos img-crop edits."""

from __future__ import annotations

import os
import shutil
from pathlib import Path

from PIL import Image, ImageOps

JPEG_QUALITY = 95


def load(path: Path) -> Image.Image:
    """Open an image with its EXIF orientation already baked into the pixels.

    The detected format is carried on the result so a file without a usable
    extension can still be written back in the format it arrived in.
    """
    with Image.open(path) as opened:
        opened.load()
        detected = opened.format
        image = ImageOps.exif_transpose(opened)

    image.format = detected
    return image


def save_in_place(image: Image.Image, path: Path, image_format: str | None = None) -> None:
    """Overwrite ``path`` with ``image`` via a temporary neighbour.

    The photo only disappears once the replacement is fully written, so a crash
    mid-encode cannot leave a half-written original behind. A symlinked photo is
    followed to the real file rather than replaced by one, and the original
    permissions are carried over. ``image_format`` covers photos whose name
    carries no extension for Pillow to go on.

    EXIF metadata does not survive: the orientation is already baked into the
    pixels by :func:`load`, and the rest goes with it.
    """
    target = path.resolve()
    encoding = image_format or Image.registered_extensions().get(target.suffix.lower())

    options = {}
    if encoding == "JPEG":
        options["quality"] = JPEG_QUALITY
        if image.mode not in ("RGB", "L"):
            image = image.convert("RGB")

    profile = image.info.get("icc_profile")
    if profile:
        options["icc_profile"] = profile

    temporary = target.with_name(f".{target.name}.img-crop{target.suffix}")
    try:
        image.save(temporary, format=encoding, **options)
        if target.exists():
            shutil.copymode(target, temporary)
        os.replace(temporary, target)
    finally:
        temporary.unlink(missing_ok=True)
