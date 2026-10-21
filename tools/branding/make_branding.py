"""Builds the studio logo PNG (from the SuperEssence artwork), the app icon and the title art."""
import math, os, random
from PIL import Image, ImageDraw, ImageFilter, ImageFont, ImageChops
ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "game")
B = os.path.join(ROOT, "assets", "branding")
FONT = os.path.join(ROOT, "assets", "fonts", "LuckiestGuy-Regular.ttf")

# 1) Studio logo: crop the artwork around the lettering, make black transparent.
src = Image.open(os.path.join(B, "superessence_logo.jpg")).convert("RGB")
gray = src.convert("L").point(lambda p: 255 if p > 40 else 0)
bbox = gray.getbbox()
pad = 60
box = (max(0, bbox[0] - pad), max(0, bbox[1] - pad), min(src.width, bbox[2] + pad), min(src.height, bbox[3] + pad))
crop = src.crop(box)
alpha = crop.convert("L").point(lambda p: min(255, int(p * 2.2)))
logo = crop.copy(); logo.putalpha(alpha)
logo.save(os.path.join(B, "superessence_logo.png"))
# boot splash: logo centered on black at 1920x1080
splash = Image.new("RGB", (1920, 1080), (0, 0, 0))
lw = 1300; lh = int(logo.height * lw / logo.width)
splash.paste(crop.resize((lw, lh), Image.LANCZOS), ((1920 - lw) // 2, (1080 - lh) // 2))
splash.save(os.path.join(B, "boot_splash.png"))

# 2) App icon: a symbiote eye over a dark abyss.
S = 512
ic = Image.new("RGBA", (S, S), (0, 0, 0, 255))
d = ImageDraw.Draw(ic)
for r in range(S // 2, 0, -2):
    t = r / (S / 2)
    col = (int(10 + 40 * (1 - t)), int(6 + 10 * (1 - t)), int(20 + 60 * (1 - t)), 255)
    d.ellipse((S / 2 - r, S / 2 - r, S / 2 + r, S / 2 + r), fill=col)
random.seed(7)
blob = Image.new("L", (S, S), 0); bd = ImageDraw.Draw(blob)
for i in range(14):
    a = i / 14 * 2 * math.pi
    pts = []
    for k in range(18):
        rr = 60 + k * 11 + random.uniform(-4, 4)
        aa = a + math.sin(k * 0.45 + i) * 0.35
        pts.append((S / 2 + math.cos(aa) * rr, S / 2 + math.sin(aa) * rr))
    for k in range(len(pts) - 1):
        w = int(30 - k * 1.6)
        if w > 1:
            bd.line([pts[k], pts[k + 1]], fill=255, width=w)
bd.ellipse((S / 2 - 120, S / 2 - 120, S / 2 + 120, S / 2 + 120), fill=255)
blob = blob.filter(ImageFilter.GaussianBlur(3)).point(lambda p: 255 if p > 128 else 0)
ic.paste((8, 6, 10, 255), (0, 0), blob)
glow = Image.new("RGBA", (S, S), (0, 0, 0, 0)); gd = ImageDraw.Draw(glow)
gd.polygon([(S/2-95, S/2-5), (S/2-20, S/2-45), (S/2-15, S/2+10)], fill=(255, 215, 40, 255))
gd.polygon([(S/2+95, S/2-5), (S/2+20, S/2-45), (S/2+15, S/2+10)], fill=(255, 215, 40, 255))
gb = glow.filter(ImageFilter.GaussianBlur(14))
ic = Image.alpha_composite(ic, gb); ic = Image.alpha_composite(ic, glow)
f = ImageFont.truetype(FONT, 92)
d = ImageDraw.Draw(ic)
txt = "ABYSS"; w = d.textlength(txt, font=f)
d.text(((S - w) / 2 + 4, S - 150 + 4), txt, font=f, fill=(0, 0, 0, 255))
d.text(((S - w) / 2, S - 150), txt, font=f, fill=(255, 210, 40, 255))
ic.save(os.path.join(B, "icon.png"))
for n, sz in (("icon_foreground.png", 432), ("icon_background.png", 432)):
    pass
fg = ic.resize((432, 432), Image.LANCZOS)
canvas = Image.new("RGBA", (432, 432), (0, 0, 0, 0)); canvas.paste(fg.resize((300, 300), Image.LANCZOS), (66, 66))
canvas.save(os.path.join(B, "icon_foreground.png"))
Image.new("RGBA", (432, 432), (8, 6, 14, 255)).save(os.path.join(B, "icon_background.png"))
print("branding ok", box)
