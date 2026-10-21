"""Procedural textures for shaders and particles (all generated, no external assets)."""
import math
import os

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "game", "assets", "textures")
os.makedirs(OUT, exist_ok=True)
rng = np.random.default_rng(1337)


def tileable_noise(n, scale, seed):
    """Band-limited tileable noise through FFT filtering of white noise."""
    r = np.random.default_rng(seed)
    w = r.standard_normal((n, n))
    f = np.fft.fft2(w)
    ky = np.fft.fftfreq(n)[:, None]
    kx = np.fft.fftfreq(n)[None, :]
    k = np.sqrt(kx ** 2 + ky ** 2) * n
    filt = np.exp(-(k / scale) ** 2)
    out = np.real(np.fft.ifft2(f * filt))
    out -= out.min()
    out /= out.max()
    return out


def fbm(n, seed, base=4.0, octaves=5):
    acc = np.zeros((n, n))
    amp, tot = 1.0, 0.0
    for o in range(octaves):
        acc += amp * tileable_noise(n, base * (2 ** o), seed + o)
        tot += amp
        amp *= 0.5
    acc /= tot
    acc -= acc.min()
    return acc / acc.max()


def save_gray_channels(name, chans):
    arr = np.stack([(c * 255).astype(np.uint8) for c in chans], axis=-1)
    mode = "RGBA" if len(chans) == 4 else "RGB"
    Image.fromarray(arr, mode).save(os.path.join(OUT, name))


N = 256
n1 = fbm(N, 1, 3.0)
n2 = fbm(N, 20, 6.0)
cell = np.abs(tileable_noise(N, 10, 40) - 0.5) * 2  # ridges -> veins
veins = np.clip(1.0 - cell * 6.0, 0, 1) ** 2
n4 = fbm(N, 60, 12.0, 3)
save_gray_channels("noise.png", [n1, n2, veins, n4])

# Grain for horror post-process
g = rng.random((256, 256))
save_gray_channels("grain.png", [g, rng.random((256, 256)), rng.random((256, 256))])

# Smoke flipbook 4x4 frames, 128px each, soft puffs evolving
F, S = 4, 128
sheet = np.zeros((F * S, F * S, 4), dtype=np.float32)
yy, xx = np.mgrid[0:S, 0:S] / (S - 1) * 2 - 1
rr = np.sqrt(xx ** 2 + yy ** 2)
base_n = fbm(S, 99, 3.0)
base_n2 = fbm(S, 120, 5.0)
for i in range(F * F):
    t = i / (F * F - 1)
    sh = int(t * S * 0.5)
    nn = 0.6 * np.roll(base_n, sh, axis=0) + 0.4 * np.roll(base_n2, -sh // 2, axis=1)
    radius = 0.55 + 0.35 * t
    falloff = np.clip(1.0 - rr / radius, 0, 1) ** 1.5
    a = np.clip(falloff * (0.35 + nn * 1.1) - 0.15 * t, 0, 1)
    a *= (1.0 - t * 0.55)
    shade = 0.75 + 0.25 * (1 - yy) * 0.5 + 0.2 * nn
    fx, fy = i % F, i // F
    sheet[fy * S:(fy + 1) * S, fx * S:(fx + 1) * S, 0] = shade
    sheet[fy * S:(fy + 1) * S, fx * S:(fx + 1) * S, 1] = shade
    sheet[fy * S:(fy + 1) * S, fx * S:(fx + 1) * S, 2] = shade
    sheet[fy * S:(fy + 1) * S, fx * S:(fx + 1) * S, 3] = a
Image.fromarray((np.clip(sheet, 0, 1) * 255).astype(np.uint8), "RGBA").save(os.path.join(OUT, "smoke_sheet.png"))

# Soft round glow
S = 128
yy, xx = np.mgrid[0:S, 0:S] / (S - 1) * 2 - 1
rr = np.sqrt(xx ** 2 + yy ** 2)
glow = np.clip(1 - rr, 0, 1) ** 2.2
Image.fromarray((np.stack([np.ones_like(glow), np.ones_like(glow), np.ones_like(glow), glow], -1) * 255).astype(np.uint8), "RGBA").save(os.path.join(OUT, "glow.png"))

# Spark streak
sp = np.clip(1 - np.abs(xx) * 6, 0, 1) * np.clip(1 - np.abs(yy), 0, 1) ** 0.6
Image.fromarray((np.stack([np.ones_like(sp)] * 3 + [sp], -1) * 255).astype(np.uint8), "RGBA").save(os.path.join(OUT, "spark.png"))

# Shock ring
ring = np.clip(1 - np.abs(rr - 0.8) * 8, 0, 1) ** 1.5
Image.fromarray((np.stack([np.ones_like(ring)] * 3 + [ring], -1) * 255).astype(np.uint8), "RGBA").save(os.path.join(OUT, "ring.png"))

# Organic splat decal (black ichor, non graphic)
S = 256
yy, xx = np.mgrid[0:S, 0:S] / (S - 1) * 2 - 1
ang = np.arctan2(yy, xx)
rr = np.sqrt(xx ** 2 + yy ** 2)
nn = fbm(S, 300, 4.0)
edge = 0.55 + 0.25 * np.sin(ang * 7 + 1.3) * np.sin(ang * 3) + 0.2 * (nn - 0.5)
a = np.clip((edge - rr) * 12, 0, 1)
drops = np.zeros_like(a)
r2 = np.random.default_rng(5)
for _ in range(14):
    cx, cy, rad = r2.uniform(-0.9, 0.9), r2.uniform(-0.9, 0.9), r2.uniform(0.03, 0.08)
    drops = np.maximum(drops, np.clip((rad - np.sqrt((xx - cx) ** 2 + (yy - cy) ** 2)) * 60, 0, 1))
a = np.maximum(a, drops)
Image.fromarray((np.stack([nn * 0.3, nn * 0.15, nn * 0.4, a], -1) * 255).astype(np.uint8), "RGBA").save(os.path.join(OUT, "goo_splat.png"))

# Claw marks / creature tracks decal
im = Image.new("RGBA", (256, 256), (0, 0, 0, 0))
d = ImageDraw.Draw(im)
for k in range(3):
    x0 = 70 + k * 45
    d.line([(x0, 30), (x0 + 30, 120), (x0 + 20, 230)], fill=(10, 5, 15, 230), width=14 - k * 2)
im = im.filter(ImageFilter.GaussianBlur(2))
im.save(os.path.join(OUT, "claw_marks.png"))
im = Image.new("RGBA", (128, 256), (0, 0, 0, 0))
d = ImageDraw.Draw(im)
for (x, y) in ((40, 60), (88, 190)):
    d.ellipse((x - 18, y - 30, x + 18, y + 30), fill=(8, 4, 12, 210))
    for t in (-1, 0, 1):
        d.polygon([(x + t * 12, y - 30), (x + t * 18, y - 62), (x + t * 6, y - 32)], fill=(8, 4, 12, 210))
im.filter(ImageFilter.GaussianBlur(1.5)).save(os.path.join(OUT, "footprint.png"))

# Toon ramp for skies / gradients (vertical)
print("textures ok")
