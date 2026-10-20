#!/usr/bin/python3
"""fallback.py <artist> <title> <cache-dir>: print the path of a pixel cassette cover in the
AngelOS palette (~/.cache/angelos/palette.json), seeded by artist+title. Cached per palette."""
import hashlib, json, os, random, sys
from PIL import Image, ImageDraw

artist, title, cdir = sys.argv[1:4]
pp = os.path.expanduser("~/.cache/angelos/palette.json")
try:
    raw = open(pp, "rb").read(); pal = json.loads(raw)
except Exception:
    raw = b""; pal = {}
def c(*ks, d="#888888"):
    for k in ks:
        v = pal.get(k)
        if isinstance(v, str) and v.startswith("#") and len(v) >= 7:
            return tuple(int(v[i:i+2], 16) for i in (1, 3, 5))
    return tuple(int(d[i:i+2], 16) for i in (1, 3, 5))
seed = hashlib.sha1((artist + "\x01" + title).encode()).hexdigest()
ph = hashlib.sha1(raw).hexdigest()[:8]
out = os.path.join(cdir, f"fallback-{seed[:12]}-{ph}.png")
if os.path.exists(out):
    os.utime(out); print(out); sys.exit()
rnd = random.Random(seed)
bg, bg2, sunk = c("face"), c("faceAlt"), c("sunken", "desk")
text, dim, edge = c("text"), c("textDim"), c("shadow", d="#000000")
accent = c("accent")
hues = [c(f"color{i}") for i in (1, 2, 3, 4, 5, 6)]
tape = rnd.choice(hues); stripe = rnd.choice([h for h in hues if h != tape] or hues)

N = 64
im = Image.new("RGB", (N, N), bg); d = ImageDraw.Draw(im)
# background: seeded diagonal dither bands + sparkles
band = rnd.randint(5, 9); off = rnd.randint(0, 20)
for y in range(N):
    for x in range(N):
        if ((x + y + off) // band) % 2 and (x + y) % 2 == 0:
            im.putpixel((x, y), bg2)
for _ in range(rnd.randint(6, 12)):
    x, y = rnd.randrange(2, N - 2), rnd.randrange(2, N - 2)
    if 9 <= y <= 50:  # keep off the cassette
        continue
    col = rnd.choice([dim, stripe, tape])
    d.point([(x, y)], col)
    if rnd.random() < .5:
        d.point([(x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)], col)
# cassette (x 10..53, y 16..47) with a hard pixel shadow
X0, Y0, X1, Y1 = 10, 17, 53, 46
d.rectangle([X0 + 2, Y0 + 2, X1 + 2, Y1 + 2], edge)
d.rectangle([X0, Y0, X1, Y1], accent)
d.rectangle([X0, Y0, X1, Y1], outline=edge)
d.line([X0 + 1, Y0 + 1, X1 - 1, Y0 + 1], tuple(min(255, v + 40) for v in accent))
# label with a seeded stripe
d.rectangle([X0 + 3, Y0 + 3, X1 - 3, Y0 + 19], text)
d.rectangle([X0 + 3, Y0 + 3, X1 - 3, Y0 + 5], stripe)
for i, ch in enumerate(seed[:6]):  # "handwriting": seeded dashes on the label
    w = 2 + int(ch, 16) % 5
    x = X0 + 5 + i * 5
    d.line([x, Y0 + 7, min(X1 - 5, x + w - 1), Y0 + 7], dim)
# window with two reels and tape
d.rectangle([X0 + 9, Y0 + 9, X1 - 9, Y0 + 17], sunk)
d.rectangle([X0 + 9, Y0 + 9, X1 - 9, Y0 + 17], outline=edge)
r = rnd.randint(1, 2)
for cx in (X0 + 14, X1 - 14):
    d.rectangle([cx - 3, Y0 + 10, cx + 3, Y0 + 16], tape)
    d.rectangle([cx - 1, Y0 + 12, cx + 1, Y0 + 14], text)
    d.point([(cx, Y0 + 13)], edge)
d.line([X0 + 18, Y0 + 16, X1 - 18, Y0 + 16], tape)
# bottom trapezoid with screw holes
d.polygon([(X0 + 8, Y1), (X0 + 11, Y1 - 5), (X1 - 11, Y1 - 5), (X1 - 8, Y1)], bg2, outline=edge)
for x in (X0 + 15, X0 + 21, X1 - 21, X1 - 15):
    d.point([(x, Y1 - 3)], edge)
for x, y in ((X0 + 2, Y0 + 2), (X1 - 2, Y0 + 2), (X0 + 2, Y1 - 2), (X1 - 2, Y1 - 2)):
    d.point([(x, y)], edge)
os.makedirs(cdir, exist_ok=True)
for f in os.listdir(cdir):  # older palettes of this track
    if f.startswith(f"fallback-{seed[:12]}-") and not f.endswith(ph + ".png"):
        try: os.remove(os.path.join(cdir, f))
        except OSError: pass
tmp = out + ".part"
im.resize((512, 512), Image.NEAREST).save(tmp, "PNG"); os.replace(tmp, out)
print(out)
