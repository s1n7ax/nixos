import sys, collections, os

SOF = {0xC0:"SOF0 baseline",0xC1:"SOF1 extended-seq",0xC2:"SOF2 progressive",
       0xC3:"SOF3 lossless",0xC5:"SOF5",0xC6:"SOF6",0xC7:"SOF7",
       0xC9:"SOF9",0xCA:"SOF10",0xCB:"SOF11",0xCD:"SOF13",0xCE:"SOF14",0xCF:"SOF15"}

def parse(buf):
    """Return (sofname, w, h, comps, dri) for one JPEG."""
    i, dri = 2, 0
    name = w = h = None; comps = []
    while i < len(buf) - 1:
        if buf[i] != 0xFF: i += 1; continue
        m = buf[i+1]
        if m in (0xD8, 0x01) or 0xD0 <= m <= 0xD7: i += 2; continue
        if m == 0xD9: break
        if i + 4 > len(buf): break
        ln = (buf[i+2] << 8) | buf[i+3]
        seg = buf[i+4:i+2+ln]
        if m in SOF:
            name = SOF[m]
            h = (seg[1] << 8) | seg[2]; w = (seg[3] << 8) | seg[4]
            n = seg[5]
            comps = [(seg[6+c*3], seg[7+c*3] >> 4, seg[7+c*3] & 15) for c in range(n)]
        elif m == 0xDD:
            dri = (seg[0] << 8) | seg[1]
        elif m == 0xDA:
            break
        i += 2 + ln
    return name, w, h, comps, dri

path = sys.argv[1]
secs = float(sys.argv[2]) if len(sys.argv) > 2 else None
data = open(path, "rb").read()

# split on SOI; 0xFFD8 never occurs inside entropy-coded data (0xFF is stuffed as 0xFF00)
starts = []
i = 0
while True:
    j = data.find(b"\xff\xd8\xff", i)
    if j < 0: break
    starts.append(j); i = j + 2
frames = [data[starts[k]:(starts[k+1] if k+1 < len(starts) else len(data))] for k in range(len(starts))]

print(f"file        : {path}  ({len(data)} bytes, {len(data)/1e6:.2f} MB)")
print(f"frames      : {len(frames)}")
if secs: print(f"wall clock  : {secs:.2f} s  ->  {len(frames)/secs:.2f} fps sustained")
if not frames: sys.exit(0)

parsed = [parse(f) for f in frames]
dims = collections.Counter((p[1], p[2]) for p in parsed)
sofs = collections.Counter(p[0] for p in parsed)
dris = collections.Counter(p[4] for p in parsed)
subs = collections.Counter(tuple(p[3]) for p in parsed)

print("\ngeometry    :")
for (w, h), n in dims.most_common():
    print(f"  {w}x{h}  x{n}  ({100*n/len(frames):.1f}%)  aspect {w/h:.4f}" if w else f"  UNPARSED x{n}")
print("\nSOF marker  :", dict(sofs))
print("DRI         :", dict(dris))
for s, n in subs.most_common():
    print("components  :", [f"id{c[0]} {c[1]}x{c[2]}" for c in s], f"x{n}")

sz = sorted(len(f) for f in frames)
print(f"\nframe bytes : min {sz[0]}  p50 {sz[len(sz)//2]}  mean {sum(sz)//len(sz)}  max {sz[-1]}")
print(f"              -> {sum(sz)/len(sz)/1024:.1f} KiB/frame avg")
if secs: print(f"              -> {8*len(data)/secs/1e6:.2f} Mbit/s on the USB link")

print("\nfirst 12 frames (libgphoto2 #567: leading frames can differ):")
for k, (nm, w, h, _, _) in enumerate(parsed[:12]):
    print(f"  [{k:2d}] {w}x{h}  {len(frames[k]):7d} B  {nm}")
print("last 3 frames:")
for k in range(max(0, len(parsed)-3), len(parsed)):
    nm, w, h, _, _ = parsed[k]
    print(f"  [{k:2d}] {w}x{h}  {len(frames[k]):7d} B  {nm}")

# dump a mid-stream frame for visual inspection
mid = len(frames)//2
out = os.path.splitext(path)[0] + f".frame{mid}.jpg"
open(out, "wb").write(frames[mid][:frames[mid].rfind(b"\xff\xd9")+2] if b"\xff\xd9" in frames[mid] else frames[mid])
print(f"\nmid frame   : {out}")
