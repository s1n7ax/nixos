"""Tee gphoto2's MJPEG stdout to a file, timestamping every frame boundary."""
import sys, time, statistics

out = open(sys.argv[1], "wb")
tsf = open(sys.argv[1] + ".times", "w")
t0 = time.monotonic()
tail = b""
times = []
first_byte = None

while True:
    chunk = sys.stdin.buffer.read(65536)
    if not chunk: break
    now = time.monotonic()
    if first_byte is None: first_byte = now
    out.write(chunk)
    buf = tail + chunk
    i = 0
    while True:
        j = buf.find(b"\xff\xd8\xff", i)
        if j < 0: break
        times.append(now - t0); i = j + 2
    tail = buf[-2:]

out.close()
for t in times: tsf.write(f"{t:.6f}\n")
tsf.close()

wall = time.monotonic() - t0
print(f"\n--- capture timing ---", file=sys.stderr)
print(f"wall {wall:.2f}s, first byte at {first_byte-t0:.2f}s, {len(times)} SOI markers seen", file=sys.stderr)
if len(times) > 2:
    span = times[-1] - times[0]
    print(f"mean {len(times)/span:.2f} fps over {span:.2f}s of streaming", file=sys.stderr)
    gaps = [b-a for a, b in zip(times, times[1:])]
    gaps_s = sorted(gaps)
    p = lambda q: gaps_s[min(len(gaps_s)-1, int(q*len(gaps_s)))]
    print(f"inter-frame gap ms: min {1000*gaps_s[0]:.1f}  p50 {1000*p(.5):.1f}  "
          f"p90 {1000*p(.9):.1f}  p99 {1000*p(.99):.1f}  max {1000*gaps_s[-1]:.1f}", file=sys.stderr)
    print(f"gap stdev {1000*statistics.pstdev(gaps):.1f} ms  "
          f"(paced stream would be ~0)", file=sys.stderr)
    # per-10s buckets: does it sag over time (thermal / buffer)?
    import collections
    b = collections.Counter(int(t//10) for t in times)
    print("fps per 10s bucket: " + "  ".join(f"{k*10}-{k*10+10}s:{v/10:.1f}" for k, v in sorted(b.items())), file=sys.stderr)
