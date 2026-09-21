#!/usr/bin/env python3
"""Measure a recording the way #124 did: duration, frames, largest inter-frame gap.

    python seam.py FILE [FILE...]

For the crash tests it also takes a --progress file written by deadfeed.py and
reports the loss window: how much of what the muxer was handed never reached
a readable fragment.
"""

import argparse
import json
import pathlib
import subprocess
import sys


def probe(path):
    r = subprocess.run(
        ["ffprobe", "-v", "error", "-show_format", "-show_streams",
         "-of", "json", path],
        capture_output=True, text=True,
    )
    try:
        return json.loads(r.stdout or "{}"), r.stderr.strip()
    except json.JSONDecodeError:
        return {}, r.stderr.strip()


def frame_times(path):
    r = subprocess.run(
        ["ffprobe", "-v", "error", "-select_streams", "v:0", "-show_entries",
         "frame=pts_time,key_frame", "-of", "csv=p=0", path],
        capture_output=True, text=True,
    )
    ts, keys = [], 0
    for line in r.stdout.splitlines():
        parts = line.split(",")
        if len(parts) < 2:
            continue
        try:
            ts.append(float(parts[1]))
        except ValueError:
            continue
        if parts[0] == "1":
            keys += 1
    ts.sort()
    return ts, keys


def decode_check(path):
    r = subprocess.run(
        ["ffmpeg", "-v", "error", "-i", path, "-f", "null", "-"],
        capture_output=True, text=True,
    )
    return r.stderr.strip()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("files", nargs="+")
    ap.add_argument("--progress", default="")
    args = ap.parse_args()

    handed = None
    if args.progress and pathlib.Path(args.progress).exists():
        lines = [l.split() for l in
                 pathlib.Path(args.progress).read_text().splitlines() if l.strip()]
        if lines:
            handed = float(lines[-1][1]) / 1e9
            print(f"muxer was handed video up to pts {handed:.3f}s "
                  f"({lines[-1][2]} buffers)")

    for path in args.files:
        size = pathlib.Path(path).stat().st_size if pathlib.Path(path).exists() else 0
        fmt, err = probe(path)
        dur = fmt.get("format", {}).get("duration")
        streams = fmt.get("streams", [])
        vdur = adur = None
        for s in streams:
            if s.get("codec_type") == "video":
                vdur = s.get("duration")
            if s.get("codec_type") == "audio":
                adur = s.get("duration")
        ts, keys = frame_times(path)
        gaps = [b - a for a, b in zip(ts, ts[1:])]
        print(f"\n=== {path}")
        print(f"  bytes            {size:,}")
        print(f"  ffprobe duration {dur or 'UNREADABLE'}   (err: {err or 'none'})")
        print(f"  video duration   {vdur}   audio duration {adur}")
        print(f"  frames           {len(ts)}   keyframes {keys}")
        if ts:
            print(f"  first/last pts   {ts[0]:.4f} / {ts[-1]:.4f}")
        if gaps:
            mx = max(gaps)
            i = gaps.index(mx)
            print(f"  max gap          {mx:.4f}s  at pts {ts[i]:.4f} "
                  f"(one frame at 60fps = 0.0167)")
            big = [(round(ts[j], 4), round(g, 4)) for j, g in enumerate(gaps)
                   if g > 0.025]
            print(f"  gaps > 25ms      {big if big else 'none'}")
        if handed is not None and ts:
            print(f"  LOSS WINDOW      {handed - ts[-1]:.3f}s "
                  f"(handed {handed:.3f}, readable to {ts[-1]:.3f})")
        dec = decode_check(path)
        print(f"  decode errors    {dec[:300] if dec else 'none'}")


if __name__ == "__main__":
    sys.exit(main())
