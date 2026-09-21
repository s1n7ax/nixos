#!/usr/bin/env python3
"""Is the audio track continuous, and is it the *right* source?

    python audiocheck.py FILE [--tone 440]

Decodes the file's audio to mono 8 kHz and reports, per 250 ms window, the RMS
and the strongest frequency. The stand-in mic is a 440 Hz sine, so a window
that is silent, or peaks somewhere else, says the rebuilt source connected to
something other than the node it was told to connect to - which is exactly the
failure #130 found with a node *name* and which no amount of "it recorded fine"
would have shown.
"""

import argparse
import subprocess
import sys

import numpy as np

SR = 8000
WIN = SR // 4


def decode(path):
    r = subprocess.run(
        ["ffmpeg", "-v", "error", "-i", path, "-ac", "1", "-ar", str(SR),
         "-f", "f32le", "-"],
        capture_output=True,
    )
    if r.returncode:
        print(r.stderr.decode()[:400], file=sys.stderr)
    return np.frombuffer(r.stdout, dtype="<f4")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("file")
    ap.add_argument("--tone", type=float, default=440.0)
    ap.add_argument("--quiet-db", type=float, default=-60.0)
    args = ap.parse_args()

    x = decode(args.file)
    n = len(x) // WIN
    print(f"{args.file}: {len(x) / SR:.3f}s of audio, {n} windows of 250ms")
    win = np.hanning(WIN)
    bad, rows = [], []
    for i in range(n):
        seg = x[i * WIN:(i + 1) * WIN]
        rms = float(np.sqrt(np.mean(seg**2)))
        db = 20 * np.log10(rms) if rms > 0 else -200.0
        spec = np.abs(np.fft.rfft(seg * win))
        freq = float(np.fft.rfftfreq(WIN, 1 / SR)[int(np.argmax(spec[1:]) + 1)])
        rows.append((i * 0.25, db, freq))
        off = abs(freq - args.tone) > 15
        if db < args.quiet_db or off:
            bad.append((i * 0.25, round(db, 1), round(freq, 1)))
    dbs = [r[1] for r in rows]
    freqs = [r[2] for r in rows]
    print(f"  level    min {min(dbs):.1f} dB  median {np.median(dbs):.1f} dB  "
          f"max {max(dbs):.1f} dB")
    print(f"  peak Hz  min {min(freqs):.1f}  median {np.median(freqs):.1f}  "
          f"max {max(freqs):.1f}   (expected {args.tone})")
    print(f"  windows that are quiet or off-tone: "
          f"{bad if bad else 'none - continuous and on the right source'}")


if __name__ == "__main__":
    main()
