#!/usr/bin/env python3
"""Read the sync offsets straight out of a recorded composite.

The recording carries the same white flash twice - through the desktop branch
and, later, through the camera pointed at the monitor - plus a click in the
audio. Three numbers fall out of that:

    camera vs screen      how far the face lags the desktop
    desk audio vs screen  how far app sound lags the desktop
    camera vs desk audio  the two above, combined

    python syncread.py FILE [--audio-track 2] [--clap]

`--clap` switches the camera detector from "brightness rises" (a flash) to
"brightness changes fastest" (hands meeting in front of the lens), which is
how the mic is measured: no speaker exists on this machine, so a clap is the
only stimulus the camera and the microphone can both witness.
"""

import argparse
import subprocess
import sys

import numpy as np

CANVAS_W, CANVAS_H = 2560, 1440
CIRCLE = 440
MARGIN = 48
SR = 8000


def frames(path, w, h, fps):
    """Decode to a tiny greyscale so a whole take fits in memory."""
    r = subprocess.run(
        ["ffmpeg", "-v", "error", "-i", path, "-map", "0:v:0",
         "-vf", f"fps={fps},scale={w}:{h},format=gray",
         "-f", "rawvideo", "-"],
        capture_output=True,
    )
    if r.returncode:
        print(r.stderr.decode()[:400], file=sys.stderr)
    a = np.frombuffer(r.stdout, dtype=np.uint8)
    return a[: (len(a) // (w * h)) * w * h].reshape(-1, h, w).astype(np.float32)


def audio(path, track, t0=0.0, t1=0.0):
    cmd = ["ffmpeg", "-v", "error"]
    if t0:
        cmd += ["-ss", str(t0)]
    if t1:
        cmd += ["-to", str(t1)]
    cmd += ["-i", path, "-map", f"0:a:{track}",
            "-ac", "1", "-ar", str(SR), "-f", "f32le", "-"]
    r = subprocess.run(cmd, capture_output=True)
    if r.returncode:
        print(r.stderr.decode()[:400], file=sys.stderr)
    return np.frombuffer(r.stdout, dtype="<f4")


def rises(sig, fps, thresh, refractory=0.5):
    """Times where `sig` jumps by more than `thresh` in one frame."""
    d = np.diff(sig)
    out, last = [], -1e9
    for i, v in enumerate(d):
        t = (i + 1) / fps
        if v > thresh and t - last > refractory:
            out.append(t)
            last = t
    return out


def swings(sig, fps, refractory=0.5, k=4.0):
    """Times where `sig` changes fastest - a clap filling the frame."""
    d = np.abs(np.diff(sig))
    thresh = d.mean() + k * d.std()
    out, last = [], -1e9
    for i, v in enumerate(d):
        t = (i + 1) / fps
        if v > thresh and t - last > refractory:
            out.append(t)
            last = t
    return out


def clicks(x, refractory=0.5, k=6.0):
    """Times of sharp audio transients."""
    n = SR // 200
    env = np.sqrt(np.convolve(x.astype(np.float64) ** 2, np.ones(n) / n, "same"))
    d = np.diff(env)
    thresh = d.mean() + k * d.std()
    out, last = [], -1e9
    for i, v in enumerate(d):
        t = (i + 1) / SR
        if v > thresh and t - last > refractory:
            out.append(t)
            last = t
    return out


def pair(a, b, window=1.0):
    """Match each `a` to the nearest later `b`, and report the distances."""
    out = []
    for ta in a:
        cands = [tb for tb in b if -0.05 <= tb - ta <= window]
        if cands:
            out.append((ta, cands[0], cands[0] - ta))
    return out


def report(name, pairs):
    if not pairs:
        print(f"{name:26s} no pairs")
        return
    ds = np.array([p[2] for p in pairs]) * 1000
    print(f"{name:26s} n={len(ds):2d}  median {np.median(ds):7.1f}ms  "
          f"mean {ds.mean():7.1f}ms  spread {ds.min():7.1f}..{ds.max():7.1f}ms")


def xcorr(va, vb, rate, span=0.6):
    """Lag of `vb` behind `va`, from the peak of their cross-correlation.

    Every clap contributes, so a detector that mistakes the approach for the
    impact costs accuracy rather than a wrong pairing, and nothing has to be
    thresholded. Parabolic interpolation around the peak puts the answer
    below one sample of the common rate.
    """
    a = np.asarray(va, dtype=np.float64)
    b = np.asarray(vb, dtype=np.float64)
    n = min(len(a), len(b))
    a, b = a[:n], b[:n]
    a = (a - a.mean()) / (a.std() or 1)
    b = (b - b.mean()) / (b.std() or 1)
    lags = int(span * rate)
    best, bestlag, curve = -1e18, 0, {}
    for k in range(-lags, lags + 1):
        if k >= 0:
            v = float(np.dot(a[: n - k], b[k:]))
        else:
            v = float(np.dot(a[-k:], b[: n + k]))
        curve[k] = v
        if v > best:
            best, bestlag = v, k
    y0 = curve.get(bestlag - 1, best)
    y1 = best
    y2 = curve.get(bestlag + 1, best)
    denom = y0 - 2 * y1 + y2
    frac = 0.5 * (y0 - y2) / denom if denom else 0.0
    return (bestlag + frac) / rate * 1000.0


def envelope(x, sr, rate):
    """Audio energy resampled to `rate` Hz."""
    n = max(1, sr // 200)
    env = np.sqrt(np.convolve(x.astype(np.float64) ** 2, np.ones(n) / n, "same"))
    idx = (np.arange(int(len(x) / sr * rate)) * sr / rate).astype(int)
    idx = idx[idx < len(env)]
    return env[idx]


def motion(sig, fps, rate):
    """Frame-to-frame change resampled to `rate` Hz."""
    d = np.abs(np.diff(sig))
    idx = (np.arange(int(len(d) / fps * rate)) * fps / rate).astype(int)
    idx = idx[idx < len(d)]
    return d[idx]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("file")
    ap.add_argument("--fps", type=float, default=60.0)
    ap.add_argument("--audio-track", type=int, default=2,
                    help="which audio track carries the click (raw desk)")
    ap.add_argument("--mic-track", type=int, default=1)
    ap.add_argument("--clap", action="store_true",
                    help="measure a clap against the mic instead of a flash")
    ap.add_argument("--thresh", type=float, default=12.0)
    ap.add_argument("--from", dest="t0", type=float, default=0.0,
                    help="analyse only from this second")
    ap.add_argument("--to", dest="t1", type=float, default=0.0,
                    help="analyse only up to this second (0 = the end)")
    args = ap.parse_args()

    w, h = 256, 144
    f = frames(args.file, w, h, args.fps)
    if args.t0 or args.t1:
        i0 = int(args.t0 * args.fps)
        i1 = int(args.t1 * args.fps) if args.t1 else len(f)
        f = f[i0:i1]
        print(f"  windowed to {args.t0:.1f}..{args.t1 or len(f) / args.fps:.1f}s")
    print(f"{args.file}: {len(f)} frames at {args.fps}fps "
          f"({len(f) / args.fps:.2f}s)")

    # the desktop shows through everywhere the camera circle is not; sample a
    # band along the top, well clear of the bottom-right corner
    screen = f[:, : h // 3, :].mean(axis=(1, 2))
    x0 = int((CANVAS_W - CIRCLE - MARGIN) / CANVAS_W * w)
    x1 = int((CANVAS_W - MARGIN) / CANVAS_W * w)
    y0 = int((CANVAS_H - CIRCLE - MARGIN) / CANVAS_H * h)
    y1 = int((CANVAS_H - MARGIN) / CANVAS_H * h)
    cam = f[:, y0:y1, x0:x1].mean(axis=(1, 2))

    if args.clap:
        rate = 200.0
        micx = audio(args.file, args.mic_track, args.t0, args.t1)
        deskx = audio(args.file, args.audio_track, args.t0, args.t1)
        cam_m = motion(cam, args.fps, rate)
        scr_m = motion(screen, args.fps, rate)
        print(f"  cross-correlating {len(cam_m) / rate:.1f}s at {rate:.0f}Hz")
        print(f"{'camera vs mic':26s} {xcorr(envelope(micx, SR, rate), cam_m, rate):7.1f}ms"
              "   (+ve = the camera lags the microphone)")
        print(f"{'camera vs desk audio':26s} "
              f"{xcorr(envelope(deskx, SR, rate), cam_m, rate):7.1f}ms")
        print(f"{'screen vs mic':26s} "
              f"{xcorr(envelope(micx, SR, rate), scr_m, rate):7.1f}ms")
        cam_t = swings(cam, args.fps)
        mic_t = clicks(micx)
        print(f"  (threshold cross-check: {len(cam_t)} camera swings, "
              f"{len(mic_t)} mic transients)")
        report("camera vs mic, paired", pair(mic_t, cam_t))
        return

    s_t = rises(screen, args.fps, args.thresh)
    c_t = rises(cam, args.fps, args.thresh)
    a_t = clicks(audio(args.file, args.audio_track, args.t0, args.t1))
    print(f"  screen flashes: {len(s_t)}   camera flashes: {len(c_t)}   "
          f"audio clicks: {len(a_t)}")
    report("camera vs screen", pair(s_t, c_t))
    report("desk audio vs screen", pair(s_t, a_t))
    report("camera vs desk audio", pair(a_t, c_t))


if __name__ == "__main__":
    main()
