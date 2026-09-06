# img-crop

A paperless-style crop for photos of documents: every photo opens fullscreen
with a handle on each corner of the page, and applying rewrites the file with
that quad straightened into an upright rectangle.

Bound in yazi to `g c` over the selected images, in place of yazi's built-in
`g c` (this config reaches `~/.config` with `' c` instead).

The crop is written over the photo: a symlink is followed to the real file and
the permissions are kept, but EXIF metadata is not — the orientation is baked
into the pixels on load and the rest goes with it.

| key | action |
| --- | --- |
| drag | move the nearest corner |
| `tab` | select the next corner |
| arrows | nudge the selected corner (`shift` for 20px) |
| `r` | reset the corners |
| `enter` | crop the photo in place and move to the next |
| `esc` | leave this photo untouched and move to the next |
| `q` | quit |

## Tests

The GTK glue in `main.py` is thin; everything else is covered headlessly.

```sh
python3 -m unittest discover --pattern 'test_*.py'
```
