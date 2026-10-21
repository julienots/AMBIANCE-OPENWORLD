"""Symbiote creatures, bosses and NPC survivors. All designs are original.

Material names: flesh* / vein* -> symbiote shader; bone*/plate* -> symbiote shader without veins;
glow* / eye* -> emissive toon. Every model faces -Y in Blender (+Z in Godot).
"""
import math

import humanoid as H
from rigkit import Character, box, cone, ease, ellipsoid, env, merge, sw, torus, tube


def symbiote_mats(c, flesh=(0.05, 0.035, 0.07), eye=(1.0, 0.85, 0.2), vein=(0.75, 0.08, 0.2)):
    c.mat("flesh", flesh, roughness=0.25)
    c.mat("bone", (0.82, 0.78, 0.7))
    c.mat("eye_glow", eye, emission=5.0)
    c.mat("glow_vein", vein, emission=3.5)


# ===========================================================================
# CRAWLER — small, fast, six-legged wall crawler
# ===========================================================================

def crawler():
    c = Character("crawler")
    symbiote_mats(c, eye=(1.0, 0.25, 0.15))
    c.weight_sigma = 0.035
    c.j("body", (0, 0, 0.32), (0.16, 0.18), mat="flesh")
    c.j("abdomen", (0, 0.32, 0.4), (0.21, 0.24), "body")
    c.j("tail", (0, 0.55, 0.36), 0.08, "abdomen")
    c.j("head", (0, -0.22, 0.32), (0.11, 0.1), "body")
    c.j("jaw", (0, -0.36, 0.26), 0.05, "head")
    for i, y in enumerate((-0.12, 0.0, 0.12)):
        c.jm(f"leg{i}a", (0.12, y, 0.33), 0.045, "body")
        c.jm(f"leg{i}b", (0.36, y * 1.8, 0.56), 0.035, f"leg{i}a")
        c.jm(f"leg{i}c", (0.62, y * 2.4, 0.0), 0.012, f"leg{i}b")
    for sg in (1, -1):
        c.part(cone((sg * 0.05, -0.33, 0.27), 0.03, 0.0, 0.14, rot=(110, 0, sg * 25), segs=6), "jaw", "bone")
    for x, z, s in [(0.05, 0.38, 0.03), (-0.05, 0.38, 0.03), (0.09, 0.35, 0.02), (-0.09, 0.35, 0.02), (0.0, 0.41, 0.022)]:
        c.part(ellipsoid((x, -0.29, z), (s, s, s)), "head", "eye_glow")
    c.part(ellipsoid((0, 0.36, 0.55), (0.12, 0.14, 0.08)), "abdomen", "glow_vein")
    for k in range(4):
        c.part(cone((0, 0.15 + k * 0.1, 0.55 + 0.02 * math.sin(k)), 0.03, 0.0, 0.12, rot=(-20, 0, 0), segs=5), "abdomen", "bone")
    c.build()

    def legs(t, speed=1.0, lift=25.0, swing=22.0):
        p = {}
        for i in range(3):
            for side, sg in (("l", 1), ("r", -1)):
                group = (i + (0 if side == "l" else 1)) % 2
                ph = 0.5 * group
                s = sw(t * speed, ph)
                up = max(0.0, sw(t * speed, ph + 0.25))
                p[f"leg{i}a_{side}"] = (0, -sg * lift * up, -sg * swing * s)
                p[f"leg{i}b_{side}"] = (0, sg * 12 * up, 0)
        return p

    c.add_anim("idle", 40, lambda t: merge(legs(t, 1.0, 4, 3), {
        "abdomen": (4 * sw(t), 0, 3 * sw(t, 0.3)), "head": (3 * sw(t, 0.2), 0, 5 * sw(t, 0.6)),
        "jaw": (-10 * max(0, sw(t * 2)), 0, 0), "_loc": {"body": (0, 0, 0.01 * sw(t))}}))
    c.add_anim("run", 12, lambda t: merge(legs(t), {
        "abdomen": (-6 * sw(t * 2), 0, 6 * sw(t)), "head": (4 * sw(t * 2), 0, 0),
        "_loc": {"body": (0, 0, 0.03 * abs(sw(t)))}}))
    c.add_anim("attack", 18, lambda t: merge(legs(0.1, 1, 6, 4), {
        "body": (-25 * env(t, 0.1, 0.35, 0.5, 0.9) + 10 * env(t, 0, 0.1, 0.1, 0.3), 0, 0),
        "head": (-20 * env(t, 0.2, 0.4, 0.5, 0.9), 0, 0), "jaw": (-40 * env(t, 0.25, 0.4, 0.45, 0.6), 0, 0),
        "abdomen": (25 * env(t, 0.1, 0.35, 0.5, 0.9), 0, 0),
        "_loc": {"body": (0, -0.35 * env(t, 0.15, 0.4, 0.5, 0.9), 0.2 * env(t, 0.15, 0.3, 0.3, 0.45))}}), loop=False)
    c.add_anim("hit", 10, lambda t: {"body": (15 * env(t, 0, 0.2, 0.3, 1.0), 0, 10 * env(t, 0, 0.2, 0.3, 1)),
                                     "_loc": {"body": (0, 0.1 * env(t, 0, 0.2, 0.3, 1.0), 0)}}, loop=False)

    def death(t):
        k = ease(min(1, t / 0.6))
        p = {"body": (0, 180 * ease(min(1, t / 0.5)), 0), "_loc": {"body": (0, 0, 0.15 * math.sin(math.pi * min(1, t / 0.5)))}}
        for i in range(3):
            for side, sg in (("l", 1), ("r", -1)):
                p[f"leg{i}a_{side}"] = (0, -sg * 40 * k, 0)
                p[f"leg{i}b_{side}"] = (0, -sg * 60 * k, 0)
        return p
    c.add_anim("death", 30, death, loop=False)
    return c


# ===========================================================================
# STALKER — lean hunter with blade claws and digitigrade legs
# ===========================================================================

def stalker():
    c = Character("stalker")
    symbiote_mats(c, flesh=(0.06, 0.05, 0.09), eye=(0.65, 1.0, 0.35))
    c.j("hips", (0, 0, 1.05), (0.13, 0.1), mat="flesh")
    c.j("spine", (0, -0.08, 1.3), (0.12, 0.1), "hips")
    c.j("chest", (0, -0.22, 1.52), (0.19, 0.14), "spine")
    c.j("neck", (0, -0.4, 1.66), 0.06, "chest")
    c.j("head", (0, -0.52, 1.7), 0.07, "neck")
    c.j("snout", (0, -0.78, 1.62), 0.04, "head")
    c.jm("shoulder", (0.22, -0.24, 1.6), 0.07, "chest")
    c.jm("elbow", (0.33, -0.3, 1.2), 0.05, "shoulder")
    c.jm("wrist", (0.38, -0.42, 0.85), 0.04, "elbow")
    c.jm("claw", (0.4, -0.5, 0.5), 0.01, "wrist")
    c.jm("thigh", (0.13, 0, 1.0), 0.09, "hips")
    c.jm("knee", (0.16, -0.22, 0.65), 0.065, "thigh")
    c.jm("hock", (0.17, 0.12, 0.3), 0.05, "knee")
    c.jm("foot", (0.17, -0.08, 0.04), 0.03, "hock")
    c.chain("tailb", "hips", [(0, 0.25, 1.0), (0, 0.5, 0.85), (0, 0.72, 0.6)], [0.07, 0.05, 0.02], mat="flesh")
    c.part(ellipsoid((0, -0.62, 1.7), (0.08, 0.17, 0.08), rot=(-10, 0, 0)), "head", "flesh")
    c.part(box((0, -0.74, 1.69), (0.1, 0.01, 0.012), rot=(0, 0, 0)), "head", "eye_glow")
    for sg in (1, -1):
        c.part(cone((sg * 0.04, -0.7, 1.64), 0.012, 0.0, 0.07, rot=(180, 0, 0), segs=4), "head", "bone")
        for k in range(3):
            c.part(cone((sg * (0.38 + 0.02 * k), -0.45 - 0.02 * k, 0.86), 0.022, 0.0, 0.42 - 0.08 * k,
                        rot=(165 - 10 * k, sg * -5, 0), segs=4, scale=(0.4, 1, 1)), "wrist" + ("_l" if sg > 0 else "_r"), "bone")
    for k in range(5):
        c.part(cone((0, -0.05 - 0.07 * k, 1.42 + 0.06 * k), 0.035, 0.0, 0.15, rot=(-30, 0, 0), segs=5), "spine" if k < 2 else "chest", "bone")
    c.part(tube([(0.1, -0.2, 1.55), (0.05, -0.12, 1.35), (0.07, -0.05, 1.15)], [0.012, 0.01, 0.005], segs=5), "chest", "glow_vein")
    c.build()

    def gait(t, k=1.0):
        s = sw(t)
        return {
            "hips": (0, 0, 6 * s), "spine": (4 * k, 0, -5 * s), "chest": (6 * k, 0, -5 * s), "head": (-8 * k, 0, 8 * s),
            "thigh_l": (-35 * k * s, 0, 0), "thigh_r": (35 * k * s, 0, 0),
            "knee_l": (-25 * k * max(0, sw(t, 0.1)), 0, 0), "knee_r": (-25 * k * max(0, -sw(t, 0.1)), 0, 0),
            "hock_l": (30 * k * max(0, sw(t, 0.15)), 0, 0), "hock_r": (30 * k * max(0, -sw(t, 0.15)), 0, 0),
            "shoulder_l": (25 * k * s, 0, 0), "shoulder_r": (-25 * k * s, 0, 0),
            "elbow_l": (-20, 0, 0), "elbow_r": (-20, 0, 0),
            "tailb0": (8 * sw(t, 0.2), 0, 10 * sw(t, 0.3)), "tailb1": (6 * sw(t, 0.4), 0, 14 * sw(t, 0.5)),
            "_loc": {"hips": (0, 0, 0.04 * k * abs(sw(t, 0.25)))},
        }

    c.add_anim("idle", 60, lambda t: {"chest": (3 * sw(t), 0, 2 * sw(t, 0.3)), "head": (5 * sw(t, 0.1), 0, 12 * sw(t * 0.5)),
                                      "shoulder_l": (5 * sw(t), 0, 0), "shoulder_r": (5 * sw(t, 0.5), 0, 0),
                                      "tailb0": (0, 0, 10 * sw(t)), "tailb1": (0, 0, 15 * sw(t, 0.2)),
                                      "_loc": {"hips": (0, 0, 0.01 * sw(t))}})
    c.add_anim("walk", 36, lambda t: gait(t, 0.6))
    c.add_anim("run", 18, lambda t: merge(gait(t, 1.2), {"spine": (12, 0, 0), "chest": (10, 0, 0), "head": (-15, 0, 0)}))

    def slash(t):
        a = env(t, 0.0, 0.3, 0.3, 0.45)
        b = env(t, 0.3, 0.45, 0.6, 1.0)
        return {"chest": (-15 * a + 25 * b, 0, 20 * a - 30 * b), "spine": (10 * b, 0, 0), "head": (15 * a, 0, 0),
                "shoulder_l": (-110 * a + 40 * b, 0, -20 * a + 50 * b), "elbow_l": (-60 * a, 0, 0),
                "shoulder_r": (-110 * a + 40 * b, 0, 20 * a - 50 * b), "elbow_r": (-60 * a, 0, 0),
                "_loc": {"hips": (0, -0.25 * b, -0.05 * b)}}
    c.add_anim("attack", 22, slash, loop=False)
    c.add_anim("scream", 40, lambda t: {"chest": (-25 * env(t, 0.1, 0.3, 0.7, 0.95), 0, 0),
                                        "head": (-35 * env(t, 0.1, 0.3, 0.7, 0.95), 0, 6 * sw(t * 6)),
                                        "shoulder_l": (-30 * env(t, 0.1, 0.3, 0.7, 0.95), -50 * env(t, 0.1, 0.3, 0.7, 0.95), 0),
                                        "shoulder_r": (-30 * env(t, 0.1, 0.3, 0.7, 0.95), 50 * env(t, 0.1, 0.3, 0.7, 0.95), 0)}, loop=False)
    c.add_anim("hit", 12, lambda t: {"chest": (-20 * env(t, 0, 0.2, 0.3, 1), 0, 10 * env(t, 0, 0.2, 0.3, 1)),
                                     "head": (-15 * env(t, 0, 0.2, 0.3, 1), 0, 0)}, loop=False)
    c.add_anim("death", 36, lambda t: {"hips": (-70 * ease(min(1, max(0, (t - 0.2) / 0.5))), 0, 0),
                                       "knee_l": (40 * ease(min(1, t / 0.4)), 0, 0), "knee_r": (50 * ease(min(1, t / 0.4)), 0, 0),
                                       "head": (-30 * ease(t), 0, 20 * ease(t)),
                                       "_loc": {"hips": (0, 0.3 * ease(t), -0.8 * ease(min(1, t / 0.7)))}}, loop=False)
    return c


# ===========================================================================
# COLOSSUS — massive knuckle-walking brute with a glowing core
# ===========================================================================

def colossus(name="colossus", split=False, scale=1.0):
    c = Character(name)
    symbiote_mats(c, flesh=(0.07, 0.05, 0.08), eye=(1.0, 0.4, 0.1), vein=(1.0, 0.35, 0.1))
    c.mat("plate", (0.25, 0.22, 0.28))
    c.weight_sigma = 0.09
    S = scale

    def p(x, y, z):
        return (x * S, y * S, z * S)
    c.j("hips", p(0, 0.2, 1.3), (0.4 * S, 0.32 * S), mat="flesh")
    c.j("spine", p(0, 0.0, 1.75), (0.45 * S, 0.38 * S), "hips")
    c.j("chest", p(0, -0.25, 2.2), (0.62 * S, 0.45 * S), "spine")
    c.j("neck", p(0, -0.55, 2.3), 0.2 * S, "chest")
    c.j("head", p(0, -0.72, 2.25), 0.17 * S, "neck")
    c.j("jaw", p(0, -0.88, 2.12), 0.1 * S, "head")
    c.jm("shoulder", p(0.7, -0.3, 2.4), 0.28 * S, "chest")
    c.jm("elbow", p(0.95, -0.45, 1.5), 0.24 * S, "shoulder")
    c.jm("wrist", p(1.0, -0.6, 0.55), 0.28 * S, "elbow")
    c.jm("fist", p(1.0, -0.7, 0.12), 0.1 * S, "wrist")
    c.jm("thigh", p(0.32, 0.2, 1.2), 0.24 * S, "hips")
    c.jm("knee", p(0.42, 0.0, 0.65), 0.2 * S, "thigh")
    c.jm("ankle", p(0.45, 0.25, 0.15), 0.16 * S, "knee")
    c.jm("toe", p(0.45, -0.1, 0.06), 0.08 * S, "ankle")
    for sg in (1, -1):
        side = "_l" if sg > 0 else "_r"
        c.part(ellipsoid(p(sg * 1.02, -0.68, 0.25), (0.3 * S, 0.32 * S, 0.24 * S)), "wrist" + side, "flesh")
        c.part(box(p(sg * 0.98, -0.62, 0.9), (0.42 * S, 0.42 * S, 0.6 * S), rot=(8, sg * 6, 0), bevel=0.08 * S), "elbow" + side, "plate")
        c.part(ellipsoid(p(sg * 0.75, -0.25, 2.55), (0.36 * S, 0.34 * S, 0.24 * S), rot=(0, sg * -20, 0)), "shoulder" + side, "plate")
        for k in range(3):
            c.part(cone(p(sg * (0.72 + 0.08 * k), -0.2 + 0.1 * k, 2.68), 0.08 * S, 0.0, (0.35 - 0.06 * k) * S,
                        rot=(-20 + 10 * k, sg * 25, 0), segs=6), "shoulder" + side, "bone")
    for k in range(5):
        c.part(cone(p(0, 0.25 - 0.15 * k, 2.1 + 0.15 * k), 0.12 * S, 0.0, (0.45 - 0.04 * k) * S, rot=(-35, 0, 0), segs=6),
               "spine" if k < 2 else "chest", "bone")
    c.part(ellipsoid(p(0, -0.78, 2.32), (0.18 * S, 0.17 * S, 0.12 * S)), "head", "plate")
    for sg in (1, -1):
        c.part(ellipsoid(p(sg * 0.07, -0.9, 2.3), (0.035 * S, 0.02 * S, 0.025 * S)), "head", "eye_glow")
        c.part(cone(p(sg * 0.07, -0.96, 2.08), 0.035 * S, 0.0, 0.12 * S, rot=(200, 0, 0), segs=5), "jaw", "bone")
    if split:
        c.part(ellipsoid(p(0, -0.62, 2.05), (0.24 * S, 0.12 * S, 0.34 * S)), "chest", "glow_vein")
        for sg in (1, -1):
            c.part(box(p(sg * 0.22, -0.66, 2.05), (0.12 * S, 0.2 * S, 0.62 * S), rot=(0, sg * 25, 0), bevel=0.04 * S), "chest", "plate")
    else:
        c.part(ellipsoid(p(0, -0.62, 2.0), (0.17 * S, 0.1 * S, 0.17 * S)), "chest", "glow_vein")
    c.build()

    def walk(t, k=1.0):
        s = sw(t)
        return {"hips": (0, 0, 5 * s), "spine": (0, 0, -6 * s), "chest": (3 * abs(s), 0, -8 * s), "head": (0, 0, 8 * s),
                "shoulder_l": (35 * k * s, 0, 0), "shoulder_r": (-35 * k * s, 0, 0),
                "elbow_l": (-15 * k * max(0, sw(t, 0.1)), 0, 0), "elbow_r": (-15 * k * max(0, -sw(t, 0.1)), 0, 0),
                "thigh_l": (-28 * k * s, 0, 0), "thigh_r": (28 * k * s, 0, 0),
                "knee_l": (35 * k * max(0, sw(t, 0.15)), 0, 0), "knee_r": (35 * k * max(0, -sw(t, 0.15)), 0, 0),
                "_loc": {"hips": (0, 0, 0.06 * S * k * abs(sw(t, 0.25)))}}
    c.add_anim("idle", 60, lambda t: {"chest": (3 * sw(t), 0, 0), "head": (4 * sw(t, 0.2), 0, 10 * sw(t * 0.5)),
                                      "shoulder_l": (4 * sw(t), 0, 0), "shoulder_r": (4 * sw(t, 0.4), 0, 0),
                                      "jaw": (8 * max(0, sw(t)), 0, 0), "_loc": {"hips": (0, 0, 0.03 * S * sw(t))}})
    c.add_anim("walk", 40, lambda t: walk(t, 1.0))
    c.add_anim("run", 24, lambda t: merge(walk(t, 1.5), {"chest": (15, 0, 0), "spine": (8, 0, 0)}))

    def slam(t):
        up = env(t, 0.05, 0.45, 0.45, 0.55)
        down = env(t, 0.45, 0.55, 0.75, 1.0)
        return {"spine": (-20 * up + 30 * down, 0, 0), "chest": (-25 * up + 25 * down, 0, 0), "head": (20 * up - 10 * down, 0, 0),
                "shoulder_l": (-150 * up + 20 * down, -15 * up, 0), "shoulder_r": (-150 * up + 20 * down, 15 * up, 0),
                "elbow_l": (-40 * up, 0, 0), "elbow_r": (-40 * up, 0, 0), "jaw": (25 * up, 0, 0),
                "_loc": {"hips": (0, 0, 0.25 * S * up - 0.2 * S * down)}}
    c.add_anim("slam", 36, slam, loop=False)

    def swipe(t):
        w = env(t, 0.0, 0.35, 0.35, 0.5)
        h = env(t, 0.35, 0.5, 0.65, 1.0)
        return {"chest": (0, 0, 35 * w - 50 * h), "spine": (0, 0, 15 * w - 20 * h),
                "shoulder_r": (-60 * w - 40 * h, 60 * w - 30 * h, 0), "elbow_r": (-50 * w, 0, 0),
                "_loc": {"hips": (0, -0.2 * S * h, 0)}}
    c.add_anim("swipe", 28, swipe, loop=False)
    c.add_anim("roar", 48, lambda t: {"chest": (-30 * env(t, 0.1, 0.3, 0.75, 1.0), 0, 0), "head": (-30 * env(t, 0.1, 0.3, 0.75, 1.0), 0, 4 * sw(t * 8)),
                                      "jaw": (45 * env(t, 0.1, 0.3, 0.75, 1.0), 0, 0),
                                      "shoulder_l": (-40 * env(t, 0.1, 0.3, 0.75, 1), -60 * env(t, 0.1, 0.3, 0.75, 1), 0),
                                      "shoulder_r": (-40 * env(t, 0.1, 0.3, 0.75, 1), 60 * env(t, 0.1, 0.3, 0.75, 1), 0)}, loop=False)
    c.add_anim("stagger", 50, lambda t: {"chest": (-30 * env(t, 0, 0.15, 0.8, 1.0), 0, 8 * sw(t * 4)), "head": (-25 * env(t, 0, 0.15, 0.8, 1), 0, 0),
                                         "shoulder_l": (-10, -55 * env(t, 0, 0.15, 0.8, 1), 0), "shoulder_r": (-10, 55 * env(t, 0, 0.15, 0.8, 1), 0),
                                         "knee_l": (40 * env(t, 0, 0.15, 0.8, 1), 0, 0), "knee_r": (40 * env(t, 0, 0.15, 0.8, 1), 0, 0),
                                         "_loc": {"hips": (0, 0.1 * S, -0.3 * S * env(t, 0, 0.15, 0.8, 1))}}, loop=False)
    c.add_anim("hit", 14, lambda t: {"chest": (-12 * env(t, 0, 0.2, 0.3, 1), 0, 6 * env(t, 0, 0.2, 0.3, 1))}, loop=False)
    c.add_anim("death", 50, lambda t: {"hips": (-60 * ease(min(1, max(0, (t - 0.3) / 0.5))), 0, 0),
                                       "chest": (-20 * ease(t), 0, 15 * ease(t)),
                                       "knee_l": (60 * ease(min(1, t / 0.4)), 0, 0), "knee_r": (70 * ease(min(1, t / 0.4)), 0, 0),
                                       "_loc": {"hips": (0, 0.5 * S * ease(t), -1.0 * S * ease(min(1, t / 0.7)))}}, loop=False)
    return c


def colosse_fendu():
    return colossus("colosse_fendu", split=True, scale=1.35)


# ===========================================================================
# MIMIC — looks like a hunched survivor until its head blooms open
# ===========================================================================

def mimic():
    c = Character("mimic")
    c.mat("jacket", (0.42, 0.36, 0.28))
    c.mat("pants", (0.2, 0.22, 0.3))
    c.mat("flesh", (0.06, 0.04, 0.07), roughness=0.25)
    c.mat("skin", (0.62, 0.55, 0.5))
    c.mat("eye_glow", (1.0, 0.2, 0.3), emission=5.0)
    c.mat("glow_vein", (0.9, 0.1, 0.25), emission=3.0)
    H.build_body(c, dict(shoulder=0.23, chest_r=(0.2, 0.14), waist_r=(0.13, 0.1), height=1.05))
    for n in c.joints:
        c.joints[n].mat = "jacket"
    for n in ("hips", "thigh_l", "thigh_r", "knee_l", "knee_r", "ankle_l", "ankle_r", "toe_l", "toe_r"):
        c.joints[n].mat = "pants"
    for n in ("wrist_l", "wrist_r", "hand_l", "hand_r"):
        c.joints[n].mat = "flesh"
    hc = c.head_center
    # inner maw (visible when petals open)
    c.part(ellipsoid((0, hc[1], hc[2]), (0.09, 0.09, 0.1)), "head", "glow_vein")
    # 4 petals forming the fake head — real bones
    for i, (dx, dy) in enumerate([(1, 0), (-1, 0), (0, -1), (0, 1)]):
        base = (hc[0] + dx * 0.04, hc[1] + dy * 0.04, hc[2] - 0.1)
        mid = (hc[0] + dx * 0.11, hc[1] + dy * 0.11, hc[2] + 0.02)
        tip = (hc[0] + dx * 0.05, hc[1] + dy * 0.05, hc[2] + 0.15)
        c.chain(f"petal{i}_", "head", [base, mid, tip], [0.06, 0.085, 0.03], mat="skin")
    for sg in (1, -1):
        c.part(ellipsoid((sg * 0.045, hc[1] - 0.12, hc[2] + 0.02), (0.018, 0.01, 0.012)), "petal2_0", "eye_glow")
    c.part(ellipsoid((0, 0.12, 1.42), (0.15, 0.08, 0.2)), "chest", "jacket")
    H.add_gloves(c, "flesh", cuff=False)
    H.add_boots(c, "pants", cuff=False)
    c.part_m(lambda s: cone((s * 0.38, -0.05, 0.86), 0.02, 0.0, 0.18, rot=(160, 0, 0), segs=4), "wrist", "flesh")
    c.build()

    def petals(openness, t=0.0):
        p = {}
        for i, (dx, dy) in enumerate([(1, 0), (-1, 0), (0, -1), (0, 1)]):
            # rotate outward: around Y for x-petals, around X for y-petals
            a = 70 * openness + 8 * openness * sw(t * 3, i * 0.25)
            if dx:
                p[f"petal{i}_0"] = (0, -dx * a, 0)
                p[f"petal{i}_1"] = (0, -dx * a * 0.6, 0)
            else:
                p[f"petal{i}_0"] = (-dy * a, 0, 0)
                p[f"petal{i}_1"] = (-dy * a * 0.6, 0, 0)
        return p
    hunch = {"spine": (18, 0, 0), "chest": (10, 0, 0), "head": (15, 0, -10)}
    c.add_anim("idle", 60, lambda t: merge(H.idle({})(t), hunch, {"head": (3 * sw(t * 0.5), 0, 8 * sw(t * 0.25))}))
    c.add_anim("walk", 30, lambda t: merge(H.run({}, 0.45)(t), hunch))
    c.add_anim("run", 18, lambda t: merge(H.run({}, 1.2)(t), petals(1.0, t), {"spine": (20, 0, 0)}))
    c.add_anim("reveal", 36, lambda t: merge(hunch if t < 0.3 else {}, petals(ease(min(1, max(0, (t - 0.2) / 0.5))), t),
                                             {"chest": (-25 * env(t, 0.3, 0.5, 0.8, 1.0), 0, 0),
                                              "shoulder_l": (-30 * env(t, 0.3, 0.5, 0.8, 1), -70 * env(t, 0.3, 0.5, 0.8, 1), 0),
                                              "shoulder_r": (-30 * env(t, 0.3, 0.5, 0.8, 1), 70 * env(t, 0.3, 0.5, 0.8, 1), 0)}), loop=False)
    c.add_anim("attack", 20, lambda t: merge(H.attack("r", {})(t), petals(1.0, t), {"head": (25 * env(t, 0.2, 0.4, 0.5, 0.8), 0, 0)}), loop=False)
    c.add_anim("hit", 12, lambda t: merge(H.hit_react({})(t), petals(0.6)), loop=False)
    c.add_anim("death", 40, lambda t: merge(H.death({})(t), petals(1.0 - 0.5 * t)), loop=False)
    return c


# ===========================================================================
# BURROWER — segmented worm with three mandibles; digs through rock
# ===========================================================================

def burrower():
    c = Character("burrower")
    symbiote_mats(c, flesh=(0.08, 0.05, 0.05), eye=(1.0, 0.6, 0.2), vein=(1.0, 0.45, 0.15))
    c.mat("plate", (0.3, 0.22, 0.2))
    c.weight_sigma = 0.07
    pts = [(0, 1.8, 0.35), (0, 1.4, 0.45), (0, 1.0, 0.6), (0, 0.6, 0.85), (0, 0.25, 1.15), (0, 0.0, 1.45), (0, -0.15, 1.7)]
    rad = [0.12, 0.2, 0.26, 0.3, 0.3, 0.27, 0.22]
    names = ["seg0", "seg1", "seg2", "seg3", "seg4", "seg5", "headb"]
    parent = None
    for n, pt, r in zip(names, pts, rad):
        c.j(n, pt, r, parent, mat="flesh")
        parent = n
    c.j("mouth", (0, -0.25, 1.9), 0.12, "headb")
    for k, (pt, r) in enumerate(zip(pts[1:6], rad[1:6])):
        c.part(torus(pt, r * 0.95, 0.05, rot=(-30 + 8 * k, 0, 0), segs=16, scale=(1, 1, 0.6)), names[k + 1], "plate")
        c.part(cone((pt[0], pt[1] + 0.05, pt[2] + r * 0.9), 0.06, 0.0, 0.2, rot=(-30, 0, 0), segs=5), names[k + 1], "bone")
    for i, a in enumerate((0, 120, 240)):
        ang = math.radians(a)
        bx, bz = math.sin(ang) * 0.15, math.cos(ang) * 0.15
        c.j(f"mand{i}", (bx, -0.3, 1.9 + bz), 0.06, "mouth", mat="bone")
        c.j(f"mand{i}t", (bx * 2.2, -0.62, 1.9 + bz * 2.2), 0.015, f"mand{i}", mat="bone")
    c.part(ellipsoid((0, -0.3, 1.9), (0.12, 0.05, 0.12)), "mouth", "glow_vein")
    for x in (-0.12, 0.12):
        c.part(ellipsoid((x, -0.18, 2.05), (0.03, 0.02, 0.03)), "headb", "eye_glow")
    c.build()

    def body_wave(t, amp=1.0):
        return {n: (amp * 8 * sw(t, i * 0.12), 0, amp * 14 * sw(t, i * 0.15)) for i, n in enumerate(names)}

    def mand(o):
        p = {}
        for i, a in enumerate((0, 120, 240)):
            ang = math.radians(a)
            p[f"mand{i}"] = (-math.cos(ang) * 40 * o, math.sin(ang) * 40 * o, 0)
        return p
    c.add_anim("idle", 50, lambda t: merge(body_wave(t, 0.6), mand(0.2 + 0.2 * max(0, sw(t * 2)))))
    c.add_anim("move", 24, lambda t: merge(body_wave(t, 1.4), mand(0.3)))
    c.add_anim("emerge", 30, lambda t: merge(body_wave(t, 1.0), mand(env(t, 0.5, 0.8)),
                                             {"_loc": {"seg0": (0, 0, -2.4 * (1 - ease(t)))}}), loop=False)
    c.add_anim("dive", 30, lambda t: merge(body_wave(t, 1.0), {"headb": (60 * ease(t), 0, 0), "seg5": (30 * ease(t), 0, 0),
                                                               "_loc": {"seg0": (0, 0, -2.4 * ease(t))}}), loop=False)
    c.add_anim("attack", 20, lambda t: merge(mand(env(t, 0.0, 0.3, 0.5, 0.7)),
                                             {"seg4": (-30 * env(t, 0, 0.3, 0.3, 0.45) + 40 * env(t, 0.3, 0.45, 0.6, 1), 0, 0),
                                              "seg5": (-20 * env(t, 0, 0.3, 0.3, 0.45) + 30 * env(t, 0.3, 0.45, 0.6, 1), 0, 0),
                                              "headb": (20 * env(t, 0.3, 0.45, 0.6, 1), 0, 0)}), loop=False)
    c.add_anim("hit", 12, lambda t: {"seg5": (-20 * env(t, 0, 0.2, 0.3, 1), 0, 15 * env(t, 0, 0.2, 0.3, 1))}, loop=False)
    c.add_anim("death", 40, lambda t: merge({n: (25 * ease(t), 0, 10 * ease(t) * (i % 2 * 2 - 1)) for i, n in enumerate(names)},
                                            mand(1.0)), loop=False)
    return c


# ===========================================================================
# ABYSSAL — rare deep predator, serpentine with glowing lures
# ===========================================================================

def abyssal():
    c = Character("abyssal")
    symbiote_mats(c, flesh=(0.03, 0.04, 0.08), eye=(0.3, 1.0, 0.9), vein=(0.2, 0.8, 1.0))
    c.weight_sigma = 0.12
    n = 9
    names = []
    parent = None
    for i in range(n):
        y = 4.0 - i * 0.9
        z = 1.6 + 0.3 * math.sin(i * 0.7)
        r = 0.25 + 0.45 * math.sin(math.pi * (i + 1) / (n + 1))
        name = f"sp{i}"
        c.j(name, (0, y, z), (r * 1.1, r), parent, mat="flesh")
        names.append(name)
        parent = name
    c.j("skull", (0, -4.6, 1.9), (0.45, 0.4), parent)
    c.j("lowjaw", (0, -4.9, 1.45), 0.2, "skull")
    c.j("lowjaw_t", (0, -5.6, 1.5), 0.08, "lowjaw")
    for sg in (1, -1):
        for k in (2, 4, 6):
            c.part(cone((sg * 0.5, 4.0 - k * 0.9, 1.7), 0.3, 0.0, 1.1, rot=(0, sg * 80, 0), segs=6, scale=(1, 0.2, 1)), f"sp{k}", "bone")
        c.part(ellipsoid((sg * 0.3, -4.95, 2.1), (0.08, 0.05, 0.06)), "skull", "eye_glow")
        c.part(tube([(sg * 0.2, -4.6, 2.3), (sg * 0.5, -5.0, 2.9), (sg * 0.7, -5.6, 2.8)], [0.04, 0.03, 0.015], segs=6), "skull", "flesh")
        c.part(ellipsoid((sg * 0.7, -5.65, 2.75), (0.12, 0.12, 0.12)), "skull", "glow_vein")
    for k in range(6):
        c.part(cone((0.25 - 0.1 * k, -5.2, 1.65), 0.05, 0.0, 0.3, rot=(180, 0, 0), segs=4), "skull", "bone")
    c.build()

    def swim(t, amp=1.0):
        return {nm: (amp * 6 * sw(t, i * 0.1), 0, amp * 12 * sw(t, i * 0.11)) for i, nm in enumerate(names)}
    c.add_anim("swim", 60, lambda t: merge(swim(t), {"lowjaw": (8 * max(0, sw(t * 2)), 0, 0),
                                                     "_loc": {"sp0": (0, 0, 0.3 * sw(t))}}))
    c.add_anim("attack", 30, lambda t: merge(swim(t, 0.5), {"lowjaw": (50 * env(t, 0.1, 0.3, 0.5, 0.8), 0, 0),
                                                            "sp8": (-20 * env(t, 0, 0.3, 0.3, 0.5) + 25 * env(t, 0.3, 0.5, 0.6, 1), 0, 0),
                                                            "skull": (-15 * env(t, 0, 0.3, 0.3, 0.5) + 20 * env(t, 0.3, 0.5, 0.6, 1), 0, 0)}), loop=False)
    c.add_anim("roar", 50, lambda t: merge(swim(t, 0.3), {"lowjaw": (60 * env(t, 0.1, 0.3, 0.7, 1.0), 0, 0),
                                                          "skull": (-30 * env(t, 0.1, 0.3, 0.7, 1.0), 0, 5 * sw(t * 10))}), loop=False)
    c.add_anim("death", 50, lambda t: merge({nm: (20 * ease(t), 30 * ease(t), 0) for nm in names},
                                            {"_loc": {"sp0": (0, 0, -1.5 * ease(t))}}), loop=False)
    return c


# ===========================================================================
# THE DEVOURER — signature horror stalker
# ===========================================================================

def devourer():
    c = Character("devourer")
    c.mat("flesh", (0.025, 0.02, 0.035), roughness=0.2)
    c.mat("flesh_wet", (0.06, 0.03, 0.05), roughness=0.15)
    c.mat("bone", (0.78, 0.74, 0.68))
    c.mat("eye_glow", (1.0, 0.92, 0.55), emission=7.0)
    c.mat("glow_vein", (0.85, 0.05, 0.12), emission=3.0)
    c.weight_sigma = 0.045
    # very tall, emaciated, slightly twisted
    c.j("hips", (0, 0.05, 1.75), (0.13, 0.09), mat="flesh")
    c.j("spine", (0.02, 0.0, 2.1), (0.1, 0.075), "hips")
    c.j("chest", (0.0, -0.08, 2.45), (0.2, 0.12), "spine")
    c.j("neck", (-0.04, -0.2, 2.75), 0.05, "chest")
    c.j("head", (-0.06, -0.3, 2.92), 0.06, "neck")
    c.j("head_top", (-0.02, -0.38, 3.2), 0.05, "head")
    c.j("jaw", (-0.05, -0.48, 2.82), 0.04, "head")
    c.jm("clav", (0.12, -0.08, 2.58), 0.06, "chest")
    c.jm("shoulder", (0.26, -0.06, 2.6), 0.055, "clav")
    c.jm("elbow", (0.4, 0.0, 1.9), 0.04, "shoulder")
    c.jm("wrist", (0.46, -0.08, 1.15), 0.035, "elbow")
    c.jm("finger", (0.48, -0.15, 0.7), 0.012, "wrist")
    c.jm("thigh", (0.13, 0.05, 1.7), 0.07, "hips")
    c.jm("knee", (0.17, -0.12, 0.95), 0.05, "thigh")
    c.jm("ankle", (0.18, 0.05, 0.14), 0.04, "knee")
    c.jm("toe", (0.18, -0.2, 0.04), 0.02, "ankle")
    # back / shoulder tentacles (bones)
    tents = []
    for i, (sx, sy, sz, dx, dz) in enumerate([(0.08, 0.1, 2.5, 0.5, 0.3), (-0.08, 0.1, 2.5, -0.55, 0.45),
                                              (0.05, 0.1, 2.2, 0.35, -0.3), (-0.06, 0.12, 2.25, -0.3, -0.45),
                                              (0.0, 0.12, 2.65, 0.1, 0.8)]):
        pts = [(sx, sy, sz)]
        for k in range(1, 5):
            f = k / 4
            pts.append((sx + dx * f + 0.08 * math.sin(k * 1.7 + i), sy + 0.3 * f + 0.1 * math.sin(k + i), sz + dz * f))
        nm = c.chain(f"t{i}_", "chest" if i != 2 and i != 3 else "spine", pts, [0.045, 0.036, 0.026, 0.016, 0.006], mat="flesh")
        tents.append(nm)
    # asymmetric head: elongated skull, side growth, 5 eyes of different sizes
    c.part(ellipsoid((-0.05, -0.36, 3.02), (0.13, 0.17, 0.2), rot=(-20, 10, 12)), "head", "flesh")
    c.part(ellipsoid((0.08, -0.32, 3.12), (0.09, 0.1, 0.12), rot=(0, 0, -30)), "head", "flesh_wet")
    for (x, y, z, s) in [(0.02, -0.5, 3.05, 0.03), (-0.1, -0.48, 3.0, 0.022), (0.08, -0.43, 3.18, 0.016),
                         (-0.04, -0.47, 3.15, 0.012), (0.1, -0.44, 2.98, 0.01)]:
        c.part(ellipsoid((x, y, z), (s, s * 0.6, s)), "head", "eye_glow")
    for k in range(7):
        a = -0.12 + 0.04 * k
        c.part(cone((a, -0.5, 2.86), 0.012, 0.0, 0.09 + 0.03 * (k % 2), rot=(185, 0, 0), segs=4), "head", "bone")
        c.part(cone((a, -0.55, 2.8), 0.01, 0.0, 0.08, rot=(-10, 0, 0), segs=4), "jaw", "bone")
    # exposed ribs, spine ridges
    for k in range(4):
        z = 2.3 + 0.08 * k
        c.part(torus((0, -0.1, z), 0.17 - 0.01 * k, 0.012, rot=(10, 0, 0), segs=16, scale=(1, 0.75, 1)), "chest", "bone")
    for k in range(6):
        c.part(cone((0, 0.1, 1.85 + 0.15 * k), 0.025, 0.0, 0.1, rot=(-60, 0, 0), segs=4), "spine" if k < 3 else "chest", "bone")
    # long finger claws
    for sg in (1, -1):
        side = "_l" if sg > 0 else "_r"
        for k in range(4):
            c.part(cone((sg * (0.45 + 0.025 * k), -0.12 - 0.02 * k, 1.12), 0.012, 0.0, 0.55 + 0.05 * (k % 2),
                        rot=(172 - 4 * k, sg * (-6 + 4 * k), 0), segs=4), "wrist" + side, "bone")
    c.part(tube([(0.06, -0.18, 2.55), (0.12, -0.14, 2.3), (0.05, -0.1, 2.05), (0.09, -0.05, 1.8)],
                [0.014, 0.012, 0.01, 0.004], segs=5), "chest", "glow_vein")
    c.build()

    def tent_wave(t, amp=1.0, speed=1.0):
        p = {}
        for i in range(5):
            for k in range(4):
                ph = i * 0.17 + k * 0.11
                p[f"t{i}_{k}"] = (amp * 16 * sw(t * speed, ph), amp * 12 * sw(t * speed, ph + 0.33), amp * 14 * sw(t * speed, ph + 0.6))
        return p

    base_crook = {"spine": (8, 0, 6), "chest": (10, 4, -8), "neck": (25, 0, 10), "head": (10, 0, 18),
                  "shoulder_l": (-5, -4, 0), "shoulder_r": (-10, 6, 0), "elbow_l": (-15, 0, 0), "elbow_r": (-25, 0, 0),
                  "knee_l": (8, 0, 0), "knee_r": (5, 0, 0)}

    def idle(t):
        # long stillness then sudden twitches of the head and fingers
        tw = env(t, 0.55, 0.58, 0.6, 0.64) - env(t, 0.8, 0.82, 0.84, 0.88)
        return merge(base_crook, tent_wave(t, 0.6), {
            "chest": (2.5 * sw(t), 0, 0), "spine": (1.5 * sw(t, 0.1), 0, 0),
            "head": (0, 25 * tw, 35 * tw), "neck": (0, 0, -15 * tw),
            "elbow_r": (-20 * env(t, 0.3, 0.33, 0.36, 0.4), 0, 0), "jaw": (12 * max(0, sw(t * 2)), 0, 0),
            "_loc": {"hips": (0, 0, 0.015 * sw(t))}})
    c.add_anim("idle", 90, idle)

    def walk(t):
        s = sw(t)
        return merge(base_crook, tent_wave(t, 0.8), {
            "hips": (0, 0, 10 * s), "spine": (0, 0, -8 * s), "chest": (0, 0, -6 * s), "head": (0, 0, 10 * s),
            "thigh_l": (-30 * s, 0, 0), "thigh_r": (30 * s, 0, 0),
            "knee_l": (45 * max(0, sw(t, 0.12)), 0, 0), "knee_r": (45 * max(0, -sw(t, 0.12)), 0, 0),
            "shoulder_l": (18 * s, 0, 0), "shoulder_r": (-18 * s, 0, 0),
            "_loc": {"hips": (0, 0, 0.05 * abs(sw(t, 0.25)))}})
    c.add_anim("walk", 44, walk)

    def run(t):
        s = sw(t)
        return merge(tent_wave(t, 1.6, 2.0), {
            "hips": (0, 0, 10 * s), "spine": (35, 0, -8 * s), "chest": (25, 0, -8 * s), "neck": (-10, 0, 0), "head": (-30, 0, 12 * s),
            "thigh_l": (-55 * s, 0, 0), "thigh_r": (55 * s, 0, 0),
            "knee_l": (20 + 75 * max(0, sw(t, 0.12)), 0, 0), "knee_r": (20 + 75 * max(0, -sw(t, 0.12)), 0, 0),
            "shoulder_l": (-60 + 50 * s, -20, 0), "shoulder_r": (-60 - 50 * s, 20, 0),
            "elbow_l": (-30, 0, 0), "elbow_r": (-30, 0, 0), "jaw": (20, 0, 0),
            "_loc": {"hips": (0, 0, -0.15 + 0.1 * abs(sw(t, 0.25)))}})
    c.add_anim("run", 20, run)

    def attack(t):
        w = env(t, 0.0, 0.3, 0.3, 0.45)
        h = env(t, 0.3, 0.45, 0.65, 1.0)
        return merge(tent_wave(t, 2.0, 2.0), {
            "spine": (-15 * w + 40 * h, 0, 0), "chest": (-20 * w + 25 * h, 0, 0), "head": (-25 * w + 10 * h, 0, 0),
            "jaw": (55 * env(t, 0.2, 0.4, 0.6, 0.9), 0, 0),
            "shoulder_l": (-140 * w - 70 * h, -40 * w + 30 * h, 0), "shoulder_r": (-140 * w - 70 * h, 40 * w - 30 * h, 0),
            "elbow_l": (-20 * w, 0, 0), "elbow_r": (-20 * w, 0, 0),
            "thigh_l": (-40 * h, 0, 0), "knee_l": (40 * h, 0, 0), "thigh_r": (20 * h, 0, 0),
            "_loc": {"hips": (0, -0.5 * h, -0.2 * h)}})
    c.add_anim("attack", 26, attack, loop=False)

    def scream(t):
        k = env(t, 0.08, 0.25, 0.8, 1.0)
        return merge(tent_wave(t, 2.5, 3.0), {
            "chest": (-30 * k, 0, 0), "spine": (-10 * k, 0, 0), "neck": (-30 * k, 0, 0), "head": (-35 * k, 0, 6 * sw(t * 12) * k),
            "jaw": (70 * k, 0, 0),
            "shoulder_l": (-30 * k, -80 * k, 0), "shoulder_r": (-30 * k, 80 * k, 0),
            "elbow_l": (-30 * k, 0, 0), "elbow_r": (-30 * k, 0, 0)})
    c.add_anim("scream", 54, scream, loop=False)

    def search(t):
        look = sw(t)
        sniff = max(0, sw(t * 4))
        return merge(base_crook, tent_wave(t, 1.0), {
            "spine": (20, 0, 0), "chest": (15, 0, 15 * look), "neck": (10 + 8 * sniff, 0, 25 * look), "head": (5 * sniff, 0, 30 * look),
            "shoulder_l": (-25, -15, 0), "shoulder_r": (-35, 15, 0), "elbow_r": (-50, 0, 0),
            "knee_l": (20, 0, 0), "knee_r": (25, 0, 0), "_loc": {"hips": (0, 0, -0.1)}})
    c.add_anim("search", 80, search)

    def stunned(t):
        k = env(t, 0.0, 0.15, 0.85, 1.0)
        return merge(tent_wave(t, 2.0, 4.0), {
            "chest": (-20 * k, 0, 10 * k), "neck": (-10 * k, 0, 0), "head": (20 * k, 0, -30 * k),
            "shoulder_l": (-120 * k, 20 * k, 0), "elbow_l": (-110 * k, 0, 0),
            "shoulder_r": (-100 * k, -10 * k, 0), "elbow_r": (-120 * k, 0, 0),
            "knee_l": (30 * k, 0, 0), "knee_r": (35 * k, 0, 0), "_loc": {"hips": (0, 0.2 * k, -0.25 * k)}})
    c.add_anim("stunned", 60, stunned, loop=False)
    c.add_anim("hit", 14, lambda t: merge(base_crook, {"chest": (-20 * env(t, 0, 0.2, 0.3, 1), 0, 12 * env(t, 0, 0.2, 0.3, 1))}), loop=False)
    c.add_anim("death", 70, lambda t: merge(tent_wave(t, 3.0 * (1 - t), 3.0), {
        "hips": (-50 * ease(min(1, max(0, (t - 0.3) / 0.5))), 0, 0), "chest": (-30 * ease(t), 0, 0), "jaw": (70 * ease(t), 0, 0),
        "knee_l": (70 * ease(min(1, t / 0.4)), 0, 0), "knee_r": (80 * ease(min(1, t / 0.4)), 0, 0),
        "_loc": {"hips": (0, 0.5 * ease(t), -1.4 * ease(min(1, t / 0.7)))}}), loop=False)
    return c


# ===========================================================================
# BOSSES
# ===========================================================================

def reine_spores():
    """La Reine des spores — a huge four-legged queen carrying glowing spore sacs."""
    c = Character("reine_spores")
    symbiote_mats(c, flesh=(0.08, 0.06, 0.05), eye=(0.8, 1.0, 0.3), vein=(0.5, 1.0, 0.25))
    c.mat("glow_spore", (0.55, 1.0, 0.3), emission=4.5)
    c.weight_sigma = 0.12
    c.j("pelvis", (0, 1.2, 2.0), (0.8, 0.7), mat="flesh")
    c.j("body", (0, 0.0, 2.4), (0.95, 0.8), "pelvis")
    c.j("neck", (0, -1.0, 3.2), (0.4, 0.35), "body")
    c.j("head", (0, -1.6, 3.6), 0.3, "neck")
    c.j("jaw", (0, -2.1, 3.3), 0.15, "head")
    for side, sg in (("_l", 1), ("_r", -1)):
        for i, (y, ln) in enumerate(((-0.5, 1.0), (0.9, 1.0))):
            c.j(f"leg{i}a{side}", (sg * 0.7, y, 2.2), 0.28, "body" if i == 0 else "pelvis")
            c.j(f"leg{i}b{side}", (sg * 1.7, y - 0.2, 2.6), 0.2, f"leg{i}a{side}")
            c.j(f"leg{i}c{side}", (sg * 2.2, y - 0.3, 0.05), 0.08, f"leg{i}b{side}")
    for i in range(6):
        a = i / 6 * 2 * math.pi
        base = (math.cos(a) * 0.25, -1.6 + math.sin(a) * 0.15, 3.85)
        c.chain(f"crown{i}_", "head", [base, (base[0] * 2.5, base[1] + 0.2, 4.3), (base[0] * 3.5, base[1] + 0.5, 4.6)],
                [0.08, 0.05, 0.015], mat="flesh")
    for (x, y, z, s) in [(0.5, 0.3, 3.2, 0.42), (-0.55, 0.0, 3.25, 0.38), (0.0, 0.7, 3.1, 0.5), (0.4, 1.3, 2.7, 0.35), (-0.4, 1.4, 2.65, 0.3)]:
        c.part(ellipsoid((x, y, z), (s, s, s * 0.9)), "body" if y < 0.6 else "pelvis", "glow_spore")
    for sg in (1, -1):
        c.part(ellipsoid((sg * 0.15, -2.0, 3.65), (0.07, 0.05, 0.05)), "head", "eye_glow")
    c.part(ellipsoid((0, -1.8, 3.6), (0.33, 0.45, 0.3)), "head", "flesh")
    c.build()

    def legs_walk(t, k=1.0):
        p = {}
        for i in range(2):
            for side, sg in (("_l", 1), ("_r", -1)):
                ph = 0.5 * ((i + (0 if sg > 0 else 1)) % 2)
                p[f"leg{i}a{side}"] = (0, -sg * 15 * k * max(0, sw(t, ph + 0.25)), -sg * 18 * k * sw(t, ph))
        return p
    c.add_anim("idle", 70, lambda t: merge({"body": (3 * sw(t), 0, 0), "neck": (5 * sw(t, 0.2), 0, 8 * sw(t * 0.5)),
                                            "_loc": {"pelvis": (0, 0, 0.08 * sw(t))}},
                                           {f"crown{i}_0": (15 * sw(t, i / 6), 10 * sw(t, i / 6 + 0.3), 0) for i in range(6)}))
    c.add_anim("walk", 50, lambda t: merge(legs_walk(t), {"neck": (0, 0, 10 * sw(t)), "_loc": {"pelvis": (0, 0, 0.1 * abs(sw(t)))}}))
    c.add_anim("spit", 40, lambda t: {"neck": (-25 * env(t, 0, 0.35, 0.35, 0.5) + 30 * env(t, 0.35, 0.5, 0.6, 1), 0, 0),
                                      "head": (-20 * env(t, 0, 0.35, 0.35, 0.5) + 25 * env(t, 0.35, 0.5, 0.6, 1), 0, 0),
                                      "jaw": (60 * env(t, 0.35, 0.5, 0.6, 0.9), 0, 0)}, loop=False)
    c.add_anim("summon", 60, lambda t: merge({"body": (-15 * env(t, 0.1, 0.3, 0.7, 1), 0, 0), "neck": (-35 * env(t, 0.1, 0.3, 0.7, 1), 0, 0),
                                              "jaw": (50 * env(t, 0.1, 0.3, 0.7, 1), 0, 0)},
                                             {f"crown{i}_0": (-40 * env(t, 0.1, 0.3, 0.7, 1), 0, 0) for i in range(6)}), loop=False)
    c.add_anim("slam", 40, lambda t: {"leg0a_l": (0, 40 * env(t, 0, 0.4, 0.4, 0.55), 0), "leg0a_r": (0, -40 * env(t, 0, 0.4, 0.4, 0.55), 0),
                                      "body": (-15 * env(t, 0, 0.4, 0.4, 0.55) + 12 * env(t, 0.45, 0.55, 0.7, 1), 0, 0),
                                      "_loc": {"pelvis": (0, 0, 0.4 * env(t, 0, 0.4, 0.4, 0.55))}}, loop=False)
    c.add_anim("hit", 16, lambda t: {"body": (-8 * env(t, 0, 0.2, 0.3, 1), 0, 5 * env(t, 0, 0.2, 0.3, 1))}, loop=False)
    c.add_anim("death", 70, lambda t: merge({"neck": (40 * ease(t), 0, 20 * ease(t)), "_loc": {"pelvis": (0, 0, -1.6 * ease(t))}},
                                            {f"leg{i}a{s}": (0, (1 if s == '_l' else -1) * 50 * ease(t), 0) for i in range(2) for s in ('_l', '_r')}), loop=False)
    return c


def gardien():
    """Le Gardien du laboratoire — a containment mech overgrown by the symbiote."""
    c = Character("gardien")
    c.mat("metal_hull", (0.55, 0.58, 0.6), metallic=0.8, roughness=0.35)
    c.mat("metal_dark", (0.18, 0.19, 0.22), metallic=0.7, roughness=0.4)
    c.mat("hazard", (0.95, 0.72, 0.1))
    c.mat("flesh", (0.05, 0.03, 0.06), roughness=0.25)
    c.mat("glow_red", (1.0, 0.15, 0.1), emission=5.0)
    c.mat("glow_vein", (0.85, 0.1, 0.25), emission=3.0)
    c.weight_sigma = 0.08
    H.build_body(c, dict(shoulder=0.42, chest_r=(0.42, 0.3), waist_r=(0.25, 0.2), hip_r=(0.3, 0.22), arm_r=0.14, fore_r=0.14,
                         thigh_r=0.17, shin_r=0.15, neck_r=0.12, height=1.5, head=(0.2, 0.2, 0.18), hand=0.16, foot=(0.16, 0.25, 0.1)))
    for n in c.joints:
        c.joints[n].mat = "metal_dark"
    for n in ("chest", "shoulder_l", "shoulder_r", "knee_l", "knee_r"):
        c.joints[n].mat = "metal_hull"
    hc = c.head_center
    c.part(box(hc, (0.34, 0.34, 0.26), bevel=0.04), "head", "metal_hull")
    c.part(box((0, hc[1] - 0.17, hc[2]), (0.26, 0.03, 0.06), bevel=0.01), "head", "glow_red")
    c.part(box((0, -0.3, 2.05), (0.6, 0.16, 0.45), bevel=0.06), "chest", "metal_hull")
    for k in range(4):
        c.part(box((-0.22 + 0.15 * k, -0.39, 1.9), (0.07, 0.02, 0.14), rot=(0, 0, 30)), "chest", "hazard")
    # right arm cannon, left claw
    c.part(cone((-0.6, -0.15, 1.45), 0.17, 0.13, 0.7, rot=(160, 0, 0), segs=12), "elbow_r", "metal_hull")
    c.part(cone((-0.62, -0.42, 0.85), 0.09, 0.09, 0.08, rot=(160, 0, 0), segs=12), "wrist_r", "glow_red")
    for k in range(3):
        c.part(cone((0.6 + 0.04 * (k - 1), -0.2, 1.3), 0.05, 0.0, 0.5, rot=(170, (k - 1) * 15, 0), segs=4), "wrist_l", "metal_hull")
    # symbiote overgrowth
    for (x, y, z, sx) in [(0.2, -0.2, 2.3, 0.22), (-0.3, 0.1, 2.1, 0.25), (0.45, 0.0, 2.25, 0.18), (0.0, 0.25, 1.6, 0.3)]:
        c.part(ellipsoid((x, y, z), (sx, sx * 0.8, sx)), "chest", "flesh")
    c.part(tube([(0.3, -0.35, 2.3), (0.4, -0.2, 1.9), (0.5, -0.1, 1.5)], [0.03, 0.025, 0.01], segs=6), "chest", "glow_vein")
    c.part(tube([(-0.2, 0.3, 2.4), (-0.5, 0.5, 2.7), (-0.7, 0.6, 2.6)], [0.06, 0.04, 0.01], segs=6), "chest", "flesh")
    H.add_boots(c, "metal_hull", cuff=False, size=1.3)
    c.build()
    st = dict(heavy=1.0, pose="guard")
    c.add_anim("idle", 60, H.idle(st))
    c.add_anim("walk", 40, H.run(st, 0.5))
    c.add_anim("run", 24, H.run(st, 0.9))
    c.add_anim("shoot", 30, lambda t: {"shoulder_r": (-85 * env(t, 0, 0.2, 0.8, 1), 15, 0), "elbow_r": (-10, 0, 0),
                                       "chest": (0, 0, -15 * env(t, 0, 0.2, 0.8, 1) + 4 * sw(t * 6) * env(t, 0.2, 0.3, 0.7, 0.8))}, loop=False)
    c.add_anim("sweep", 30, H.attack("l", st), loop=False)
    c.add_anim("slam", 36, H.heavy_slam(st), loop=False)
    c.add_anim("charge", 20, lambda t: merge(H.run(st, 1.3)(t), {"spine": (25, 0, 0), "chest": (15, 0, 0)}))
    c.add_anim("hit", 14, H.hit_react(st), loop=False)
    c.add_anim("death", 50, H.death(st), loop=False)
    return c


def architecte():
    """L'Architecte symbiotique — final boss rising from a living mass."""
    c = Character("architecte")
    symbiote_mats(c, flesh=(0.04, 0.03, 0.06), eye=(1.0, 0.95, 0.6), vein=(0.7, 0.2, 1.0))
    c.mat("glow_core", (0.85, 0.35, 1.0), emission=6.0)
    c.weight_sigma = 0.15
    c.j("mass", (0, 0, 0.8), (2.2, 2.0), mat="flesh")
    c.j("waist", (0, 0, 2.3), (1.0, 0.8), "mass")
    c.j("chest", (0, -0.1, 4.0), (1.4, 1.0), "waist")
    c.j("neck", (0, -0.3, 5.2), 0.5, "chest")
    c.j("head", (0, -0.4, 5.6), 0.4, "neck")
    c.j("head_t", (0, -0.5, 6.4), 0.2, "head")
    for side, sg in (("_l", 1), ("_r", -1)):
        for i, z in enumerate((4.5, 3.5)):
            c.j(f"arm{i}a{side}", (sg * 1.3, -0.1, z), 0.4 - 0.08 * i, "chest")
            c.j(f"arm{i}b{side}", (sg * 2.6, -0.6, z - 0.6), 0.32 - 0.06 * i, f"arm{i}a{side}")
            c.j(f"arm{i}c{side}", (sg * 3.2, -1.6, z - 1.8), 0.25 - 0.04 * i, f"arm{i}b{side}")
            c.j(f"arm{i}d{side}", (sg * 3.3, -2.3, z - 3.0), 0.05, f"arm{i}c{side}")
    for i in range(7):
        a = i / 7 * 2 * math.pi
        base = (math.cos(a) * 0.35, -0.4 + math.sin(a) * 0.3, 6.0)
        c.chain(f"cr{i}_", "head", [base, (base[0] * 3, base[1] * 2 + 0.3, 6.8), (base[0] * 4.5, base[1] * 3 + 0.8, 7.4)],
                [0.15, 0.09, 0.02], mat="flesh")
    c.part(ellipsoid((0, -1.0, 4.0), (0.55, 0.3, 0.55)), "chest", "glow_core")
    c.part(ellipsoid((0, -0.85, 5.65), (0.35, 0.2, 0.25)), "head", "eye_glow")
    c.part(ellipsoid((0, -0.95, 5.65), (0.12, 0.12, 0.12)), "head", "flesh")
    for k in range(10):
        a = k / 10 * 2 * math.pi
        c.part(cone((math.cos(a) * 1.9, math.sin(a) * 1.7, 0.6), 0.25, 0.0, 1.4 + 0.5 * (k % 3), rot=(math.cos(a) * 30, -math.sin(a) * 30, 0),
                    segs=6), "mass", "bone")
    c.build()

    def arms(t, k):
        p = {}
        for i in range(2):
            for s, sg in (("_l", 1), ("_r", -1)):
                p[f"arm{i}a{s}"] = (k * 10 * sw(t, 0.25 * i), 0, sg * k * 12 * sw(t, 0.3 * i))
                p[f"arm{i}b{s}"] = (k * 8 * sw(t, 0.25 * i + 0.2), 0, 0)
        return p
    crown = lambda t, k: {f"cr{i}_0": (k * 15 * sw(t, i / 7), k * 10 * sw(t, i / 7 + 0.3), 0) for i in range(7)}
    c.add_anim("idle", 80, lambda t: merge(arms(t, 1.0), crown(t, 1.0), {"chest": (3 * sw(t), 0, 4 * sw(t * 0.5))}))
    c.add_anim("sweep", 40, lambda t: merge(crown(t, 1.5), {"chest": (0, 0, 40 * env(t, 0, 0.3, 0.3, 0.45) - 60 * env(t, 0.3, 0.5, 0.6, 1)),
                                                            "arm0a_r": (-40 * env(t, 0, 0.3, 0.6, 1), 60 * env(t, 0, 0.3, 0.6, 1), 0),
                                                            "arm1a_r": (-30 * env(t, 0, 0.3, 0.6, 1), 50 * env(t, 0, 0.3, 0.6, 1), 0)}), loop=False)
    c.add_anim("slam", 44, lambda t: merge(crown(t, 1.5), {f"arm{i}a{s}": (-100 * env(t, 0, 0.4, 0.4, 0.55) + 30 * env(t, 0.45, 0.55, 0.7, 1), 0, 0)
                                                           for i in range(2) for s in ("_l", "_r")},
                                           {"chest": (-15 * env(t, 0, 0.4, 0.4, 0.55) + 25 * env(t, 0.45, 0.55, 0.7, 1), 0, 0)}), loop=False)
    c.add_anim("summon", 60, lambda t: merge(arms(t, 2.0), crown(t, 3.0), {"chest": (-20 * env(t, 0.1, 0.3, 0.7, 1), 0, 0),
                                                                          "head": (-25 * env(t, 0.1, 0.3, 0.7, 1), 0, 0)}), loop=False)
    c.add_anim("beam", 60, lambda t: merge(crown(t, 2.0), {"head": (15 * env(t, 0.1, 0.25, 0.85, 1), 0, 25 * sw(t * 0.5) * env(t, 0.25, 0.3, 0.8, 0.85)),
                                                           "chest": (10 * env(t, 0.1, 0.25, 0.85, 1), 0, 0)}), loop=False)
    c.add_anim("hit", 16, lambda t: {"chest": (-10 * env(t, 0, 0.2, 0.3, 1), 0, 6 * env(t, 0, 0.2, 0.3, 1))}, loop=False)
    c.add_anim("death", 90, lambda t: merge(arms(t, 3 * (1 - t)), {"chest": (40 * ease(t), 0, 20 * ease(t)),
                                                                   "_loc": {"mass": (0, 0, -3.0 * ease(min(1, max(0, (t - 0.3) / 0.7))))}}), loop=False)
    return c


# ===========================================================================
# NPC survivor / scientist
# ===========================================================================

def survivor(name="survivor", coat=(0.85, 0.87, 0.9), pants=(0.25, 0.27, 0.35), skin=(0.85, 0.65, 0.5), hair=(0.25, 0.15, 0.1)):
    c = Character(name)
    c.mat("coat", coat)
    c.mat("pants", pants)
    c.mat("skin", skin)
    c.mat("hair", hair)
    c.mat("eye_dark", (0.05, 0.05, 0.08), emission=0.0)
    H.build_body(c, dict(shoulder=0.22, chest_r=(0.19, 0.13), waist_r=(0.13, 0.1), height=0.97, head=(0.13, 0.14, 0.15)))
    for n in c.joints:
        c.joints[n].mat = "coat"
    for n in ("thigh_l", "thigh_r", "knee_l", "knee_r", "ankle_l", "ankle_r", "toe_l", "toe_r"):
        c.joints[n].mat = "pants"
    H.add_head(c, "skin")
    hc = c.head_center
    c.part(ellipsoid((0, hc[1] + 0.03, hc[2] + 0.05), (0.14, 0.14, 0.12)), "head", "hair")
    H.add_eyes(c, "eye_dark", spread=0.045, y=hc[1] - 0.125, size=(0.016, 0.01, 0.022))
    c.part(tube([(0, 0.0, 1.45), (0, 0.05, 1.1), (0, 0.06, 0.75)], [0.22, 0.2, 0.24], segs=12), "chest", "coat")
    H.add_gloves(c, "skin", cuff=False, size=0.9)
    H.add_boots(c, "pants", cuff=False)
    c.build()
    st = {}
    c.add_anim("idle", 60, H.idle(st))
    c.add_anim("run", 20, H.run(st, 1.0))
    c.add_anim("walk", 30, H.run(st, 0.45))
    c.add_anim("cower", 40, lambda t: merge(H.crouch(st)(0.0), {"shoulder_l": (-100, 20, 0), "elbow_l": (-120, 0, 0),
                                                               "shoulder_r": (-100, -20, 0), "elbow_r": (-120, 0, 0),
                                                               "head": (20 + 4 * sw(t * 3), 0, 0)}))
    c.add_anim("wave", 30, lambda t: merge(H.idle(st)(t), {"shoulder_r": (-160, 30, 0), "elbow_r": (-20 + 30 * sw(t * 2), 0, 0)}))
    c.add_anim("death", 40, H.death(st), loop=False)
    return c


def scientist():
    return survivor("scientist", coat=(0.93, 0.94, 0.96), pants=(0.2, 0.22, 0.28), skin=(0.6, 0.42, 0.3), hair=(0.1, 0.08, 0.07))


ALL = [crawler, stalker, colossus, colosse_fendu, mimic, burrower, abyssal, devourer, reine_spores, gardien, architecte, survivor, scientist]
