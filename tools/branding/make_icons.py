"""White silhouette icons for the touch HUD and menus (128x128 RGBA PNGs)."""
import math
import os

from PIL import Image, ImageDraw, ImageFilter

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "game", "assets", "icons")
os.makedirs(OUT, exist_ok=True)
S = 128
W = (255, 255, 255, 255)


def canvas():
    im = Image.new("RGBA", (S * 2, S * 2), (0, 0, 0, 0))
    return im, ImageDraw.Draw(im)


def save(im, name):
    im = im.resize((S, S), Image.LANCZOS)
    im.save(os.path.join(OUT, name + ".png"))


def poly_star(d, cx, cy, r1, r2, n, rot=0.0, fill=W):
    pts = []
    for i in range(n * 2):
        r = r1 if i % 2 == 0 else r2
        a = rot + math.pi * i / n
        pts.append((cx + math.cos(a) * r, cy + math.sin(a) * r))
    d.polygon(pts, fill=fill)


def arrow(d, x0, y0, x1, y1, w=18, head=40, fill=W):
    d.line([(x0, y0), (x1, y1)], fill=fill, width=w)
    a = math.atan2(y1 - y0, x1 - x0)
    p1 = (x1 + math.cos(a) * head * 0.6, y1 + math.sin(a) * head * 0.6)
    p2 = (x1 + math.cos(a + 2.4) * head, y1 + math.sin(a + 2.4) * head)
    p3 = (x1 + math.cos(a - 2.4) * head, y1 + math.sin(a - 2.4) * head)
    d.polygon([p1, p2, p3], fill=fill)


C = S  # centre in the 2x canvas


def icon_attack():
    im, d = canvas()
    poly_star(d, C, C, 100, 42, 8, 0.2)
    d.ellipse((C - 30, C - 30, C + 30, C + 30), fill=(0, 0, 0, 0))
    return im


def icon_heavy():
    im, d = canvas()
    d.rectangle((C - 70, C - 20, C + 20, C + 20), fill=W)
    d.rectangle((C + 20, C - 60, C + 70, C + 60), fill=W)
    return im


def icon_dodge():
    im, d = canvas()
    d.arc((C - 80, C - 80, C + 80, C + 80), 200, 500, fill=W, width=22)
    arrow(d, C + 40, C + 70, C + 80, C + 20, 0, 50)
    return im


def icon_interact():
    im, d = canvas()
    d.rounded_rectangle((C - 50, C - 20, C + 50, C + 90), 30, fill=W)
    for i, h in enumerate((70, 95, 90, 75)):
        x = C - 45 + i * 28
        d.rounded_rectangle((x, C - h, x + 22, C), 11, fill=W)
    d.rounded_rectangle((C - 95, C - 10, C - 45, C + 30), 18, fill=W)
    return im


def icon_crouch():
    im, d = canvas()
    d.ellipse((C - 10, C - 95, C + 40, C - 45), fill=W)
    d.polygon([(C - 40, C - 40), (C + 40, C - 30), (C + 20, C + 30), (C - 50, C + 20)], fill=W)
    d.polygon([(C - 50, C + 20), (C + 20, C + 30), (C + 60, C + 90), (C + 30, C + 95), (C, C + 55), (C - 60, C + 95), (C - 85, C + 85)], fill=W)
    return im


def icon_flashlight():
    im, d = canvas()
    d.polygon([(C - 90, C - 30), (C - 20, C - 30), (C - 20, C + 30), (C - 90, C + 30)], fill=W)
    d.polygon([(C - 20, C - 45), (C + 10, C - 45), (C + 10, C + 45), (C - 20, C + 45)], fill=W)
    for a in (-25, 0, 25):
        r = math.radians(a)
        d.line([(C + 30, C), (C + 30 + 70 * math.cos(r), C + 70 * math.sin(r))], fill=W, width=12)
    return im


def icon_pause():
    im, d = canvas()
    d.rounded_rectangle((C - 60, C - 75, C - 15, C + 75), 10, fill=W)
    d.rounded_rectangle((C + 15, C - 75, C + 60, C + 75), 10, fill=W)
    return im


def icon_cycle():
    im, d = canvas()
    d.arc((C - 70, C - 70, C + 70, C + 70), 30, 300, fill=W, width=20)
    arrow(d, C + 40, C - 70, C + 75, C - 30, 0, 45)
    return im


def icon_projectile():
    im, d = canvas()
    d.ellipse((C + 10, C - 40, C + 90, C + 40), fill=W)
    for i, w in enumerate((20, 14, 8)):
        y = C - 25 + i * 25
        d.line([(C - 90, y), (C + 10, y)], fill=W, width=w)
    return im


def icon_shockwave():
    im, d = canvas()
    for r, w in ((30, 0), (65, 14), (100, 12)):
        if w == 0:
            d.ellipse((C - r, C - r, C + r, C + r), fill=W)
        else:
            d.ellipse((C - r, C - r, C + r, C + r), outline=W, width=w)
    return im


def icon_shield():
    im, d = canvas()
    d.polygon([(C, C - 100), (C + 85, C - 65), (C + 70, C + 30), (C, C + 100), (C - 70, C + 30), (C - 85, C - 65)], fill=W)
    d.polygon([(C, C - 70), (C + 55, C - 45), (C + 45, C + 20), (C, C + 70)], fill=(0, 0, 0, 0))
    return im


def icon_dash():
    im, d = canvas()
    arrow(d, C - 40, C, C + 40, C, 28, 70)
    for i, y in enumerate((C - 50, C + 50)):
        d.line([(C - 100, y), (C - 30, y)], fill=W, width=12)
    return im


def icon_teleport():
    im, d = canvas()
    d.ellipse((C - 95, C - 40, C - 25, C + 40), outline=W, width=14)
    d.ellipse((C + 25, C - 40, C + 95, C + 40), fill=W)
    for x in (C - 10, C + 5):
        d.ellipse((x - 6, C - 6, x + 6, C + 6), fill=W)
    return im


def icon_blades():
    im, d = canvas()
    for a in (-35, 0, 35):
        r = math.radians(a - 90)
        p = (C + math.cos(r) * 100, C + 30 + math.sin(r) * 100)
        q1 = (C + math.cos(r + 1.57) * 14, C + 30 + math.sin(r + 1.57) * 14)
        q2 = (C + math.cos(r - 1.57) * 14, C + 30 + math.sin(r - 1.57) * 14)
        d.polygon([p, q1, q2], fill=W)
    return im


def icon_invisibility():
    im, d = canvas()
    d.ellipse((C - 95, C - 50, C + 95, C + 50), outline=W, width=14)
    d.ellipse((C - 30, C - 30, C + 30, C + 30), fill=W)
    d.line([(C - 90, C + 80), (C + 90, C - 80)], fill=W, width=16)
    return im


def icon_wall():
    im, d = canvas()
    for i, x in enumerate(range(C - 90, C + 91, 45)):
        h = 70 + 30 * (i % 2)
        d.polygon([(x - 22, C + 80), (x + 22, C + 80), (x + 8, C + 80 - h), (x, C + 80 - h - 30), (x - 8, C + 80 - h)], fill=W)
    return im


def icon_taunt():
    im, d = canvas()
    d.polygon([(C - 30, C - 40), (C + 10, C - 40), (C + 80, C - 90), (C + 80, C + 90), (C + 10, C + 40), (C - 30, C + 40)], fill=W)
    d.rectangle((C - 80, C - 40, C - 40, C + 40), fill=W)
    return im


def icon_seismic():
    im, d = canvas()
    pts = [(C - 100, C + 70), (C - 50, C + 20), (C - 20, C + 50), (C + 20, C - 10), (C + 50, C + 20), (C + 100, C - 60)]
    d.line(pts, fill=W, width=18, joint="curve")
    d.rectangle((C - 100, C + 80, C + 100, C + 100), fill=W)
    return im


def icon_portal():
    im, d = canvas()
    for i in range(4):
        r = 95 - i * 22
        d.arc((C - r, C - r, C + r, C + r), i * 60, i * 60 + 250, fill=W, width=14)
    return im


def icon_regen():
    im, d = canvas()
    d.rounded_rectangle((C - 25, C - 90, C + 25, C + 90), 12, fill=W)
    d.rounded_rectangle((C - 90, C - 25, C + 90, C + 25), 12, fill=W)
    return im


def icon_root():
    im, d = canvas()
    d.line([(C, C - 100), (C, C + 20)], fill=W, width=22)
    for a in (-60, -25, 25, 60):
        r = math.radians(a + 90)
        d.line([(C, C + 10), (C + math.cos(r) * 100, C + math.sin(r) * 95)], fill=W, width=16)
    return im


def icon_gravity_storm():
    im, d = canvas()
    for i in range(5):
        r = 100 - i * 18
        d.arc((C - r, C - r * 0.7, C + r, C + r * 0.7), i * 40, i * 40 + 220, fill=W, width=12)
    d.ellipse((C - 16, C - 16, C + 16, C + 16), fill=W)
    return im


def icon_dark_domain():
    im, d = canvas()
    d.ellipse((C - 95, C - 95, C + 95, C + 95), fill=W)
    d.ellipse((C - 55, C - 105, C + 125, C + 75), fill=(0, 0, 0, 0))
    return im


def icon_meteor():
    im, d = canvas()
    d.ellipse((C + 10, C + 10, C + 90, C + 90), fill=W)
    for i, w in enumerate((22, 16, 10)):
        o = i * 22 - 22
        d.line([(C - 90 + o, C - 90 - o), (C + 30 + o, C + 30 - o)], fill=W, width=w)
    return im


def icon_fortress():
    im, d = canvas()
    d.pieslice((C - 100, C - 80, C + 100, C + 120), 180, 360, fill=W)
    d.pieslice((C - 70, C - 50, C + 70, C + 90), 180, 360, fill=(0, 0, 0, 0))
    d.rectangle((C - 100, C + 20, C + 100, C + 40), fill=W)
    return im


def icon_singularity():
    im, d = canvas()
    d.ellipse((C - 40, C - 40, C + 40, C + 40), fill=W)
    d.ellipse((C - 100, C - 30, C + 100, C + 30), outline=W, width=12)
    d.ellipse((C - 28, C - 28, C + 28, C + 28), fill=(0, 0, 0, 0))
    return im


def icon_transform():
    im, d = canvas()
    d.ellipse((C - 40, C - 70, C + 40, C + 10), fill=W)
    for a in range(0, 360, 45):
        r = math.radians(a)
        d.line([(C, C - 30), (C + math.cos(r) * 100, C - 30 + math.sin(r) * 100)], fill=W, width=10)
    d.polygon([(C - 50, C + 20), (C + 50, C + 20), (C + 30, C + 100), (C - 30, C + 100)], fill=W)
    return im


def icon_flare():
    im, d = canvas()
    d.rounded_rectangle((C - 18, C - 20, C + 18, C + 100), 8, fill=W)
    poly_star(d, C, C - 55, 55, 22, 6)
    return im


def icon_decoy():
    im, d = canvas()
    d.rounded_rectangle((C - 35, C - 50, C + 35, C + 70), 12, fill=W)
    for r in (60, 90):
        d.arc((C - r, C - 10 - r, C + r, C - 10 + r), 200, 340, fill=W, width=10)
    return im


def icon_medkit():
    im, d = canvas()
    d.rounded_rectangle((C - 90, C - 65, C + 90, C + 80), 18, fill=W)
    d.rounded_rectangle((C - 15, C - 45, C + 15, C + 60), 4, fill=(0, 0, 0, 0))
    d.rounded_rectangle((C - 52, C - 8, C + 52, C + 22), 4, fill=(0, 0, 0, 0))
    return im


def icon_cell():
    im, d = canvas()
    d.rounded_rectangle((C - 45, C - 80, C + 45, C + 95), 14, fill=W)
    d.rectangle((C - 18, C - 98, C + 18, C - 80), fill=W)
    d.polygon([(C + 10, C - 55), (C - 25, C + 10), (C, C + 10), (C - 10, C + 70), (C + 25, C - 5), (C, C - 5)], fill=(0, 0, 0, 0))
    return im


def icon_smoke():
    im, d = canvas()
    for x, y, r in ((C - 40, C + 20, 50), (C + 30, C + 10, 55), (C - 5, C - 40, 50), (C + 60, C - 40, 35)):
        d.ellipse((x - r, y - r, x + r, y + r), fill=W)
    return im


def icon_barricade():
    im, d = canvas()
    for i in range(3):
        y = C - 60 + i * 55
        d.polygon([(C - 100, y + 10), (C + 100, y - 10), (C + 100, y + 20), (C - 100, y + 40)], fill=W)
    return im


def icon_capture():
    im, d = canvas()
    d.ellipse((C - 80, C - 80, C + 80, C + 80), outline=W, width=16)
    d.rectangle((C - 80, C - 8, C + 80, C + 8), fill=W)
    d.ellipse((C - 25, C - 25, C + 25, C + 25), fill=W)
    return im


def icon_mine():
    im, d = canvas()
    d.pieslice((C - 80, C - 40, C + 80, C + 120), 180, 360, fill=W)
    for a in (-50, 0, 50):
        r = math.radians(a - 90)
        d.line([(C, C + 30), (C + math.cos(r) * 90, C + 30 + math.sin(r) * 90)], fill=W, width=12)
    return im


def icon_dig():
    im, d = canvas()
    d.line([(C - 70, C + 90), (C + 30, C - 10)], fill=W, width=20)
    d.polygon([(C - 20, C - 70), (C + 100, C - 20), (C + 60, C + 10), (C + 10, C - 30)], fill=W)
    return im


def icon_build():
    im, d = canvas()
    d.rectangle((C - 80, C - 10, C + 80, C + 90), fill=W)
    d.polygon([(C - 100, C - 10), (C, C - 95), (C + 100, C - 10)], fill=W)
    d.rectangle((C - 20, C + 30, C + 20, C + 90), fill=(0, 0, 0, 0))
    return im


def icon_map():
    im, d = canvas()
    d.polygon([(C - 95, C - 70), (C - 30, C - 90), (C + 30, C - 70), (C + 95, C - 90), (C + 95, C + 70), (C + 30, C + 90), (C - 30, C + 70), (C - 95, C + 90)], fill=W)
    d.line([(C - 30, C - 85), (C - 30, C + 70)], fill=(0, 0, 0, 0), width=8)
    d.line([(C + 30, C - 70), (C + 30, C + 85)], fill=(0, 0, 0, 0), width=8)
    return im


ICONS = {k[5:]: v for k, v in globals().items() if k.startswith("icon_")}

if __name__ == "__main__":
    for name, fn in ICONS.items():
        save(fn(), name)
    print("icons:", len(ICONS))
