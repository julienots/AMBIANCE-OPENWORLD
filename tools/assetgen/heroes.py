"""Hero models for SYMBIOTE: ABYSS. All designs are original.

Material naming convention read by the game's toon material builder:
  glow*  -> emissive (pulses with the hero's energy)
  metal* -> sharper specular
  eye*   -> emissive eyes
  other  -> standard toon surface
"""
import humanoid as H
from humanoid import (add_belt, add_boots, add_cape, add_emblem, add_gloves, add_head, add_limb_stripes,
                      add_mask_eyes, add_pecs, add_shoulder_pads, build_body, head_point)
from rigkit import Character, box, cone, ellipsoid, merge, sw, torus, tube
from mathutils import Vector


def forearm_point(c, sg, f):
    """Point at fraction f from elbow (0) to wrist (1) of the left (+1) or right (-1) arm, rest pose."""
    e = c.joints["elbow_l" if sg > 0 else "elbow_r"].pos
    w = c.joints["wrist_l" if sg > 0 else "wrist_r"].pos
    p = e.lerp(w, f)
    return (p.x, p.y, p.z)


def forearm_blade(c, sg, length, width):
    """Flat blade starting at the wrist and extending past the fist along the forearm axis."""
    e = c.joints["elbow_l" if sg > 0 else "elbow_r"].pos
    w = c.joints["wrist_l" if sg > 0 else "wrist_r"].pos
    d = (w - e).normalized()
    start = w - d * 0.12 + Vector((sg * 0.05, 0.02, 0))
    pts = [start, start + d * length * 0.5, start + d * length]
    return tube([tuple(p) for p in pts], [width, width * 0.8, 0.004], segs=4)


def hand_claw(c, sg, offset, length):
    """Hooked claw growing out of the knuckles, continuing the hand direction."""
    w = c.joints["wrist_l" if sg > 0 else "wrist_r"].pos
    h = c.joints["hand_l" if sg > 0 else "hand_r"].pos
    d = (h - w).normalized()
    base = h + Vector((offset * sg, -0.04, 0.0))
    pts = [base, base + d * length * 0.6 + Vector((0, -0.03, 0)), base + d * length + Vector((0, -0.09, 0))]
    return tube([tuple(p) for p in pts], [0.018, 0.012, 0.002], segs=5)

STD_ANIMS = [("idle", 60, "idle", True), ("run", 20, "run", True), ("sprint", 16, "sprint", True),
             ("crouch", 36, "crouch", True), ("attack1", 16, "attack_r", False), ("attack2", 16, "attack_l", False),
             ("attack3", 24, "attack_spin", False), ("heavy", 28, "heavy_slam", False), ("cast", 18, "cast_forward", False),
             ("cast_up", 26, "cast_up", False), ("dodge", 16, "dodge_roll", False), ("hit", 12, "hit_react", False),
             ("death", 40, "death", False), ("spawn", 40, "spawn", False), ("pose", 60, "hero_pose", True),
             ("block", 24, "block", True)]


def anim_fn(key, style):
    if key == "run":
        return H.run(style, 1.0)
    if key == "sprint":
        return H.run(style, 1.35)
    if key == "attack_r":
        return H.attack("r", style)
    if key == "attack_l":
        return H.attack("l", style)
    return getattr(H, key)(style)


def add_anims(c, style, extra=None):
    """extra(t, anim_name) -> additive pose (secondary motion: capes, tentacles…)."""
    for name, frames, key, loop in STD_ANIMS:
        fn = anim_fn(key, style)
        if extra:
            def wrapped(t, fn=fn, name=name):
                return merge(fn(t), extra(t, name))
            c.add_anim(name, frames, wrapped, loop=loop)
        else:
            c.add_anim(name, frames, fn, loop=loop)


def vortex():
    c = Character("vortex")
    c.mat("suit", (0.93, 0.95, 0.98))
    c.mat("teal", (0.03, 0.32, 0.42))
    c.mat("glow_cyan", (0.25, 0.95, 1.0), emission=4.0)
    c.mat("metal_trim", (0.6, 0.68, 0.76), metallic=0.8, roughness=0.3)
    build_body(c)
    for n in ("hips", "thigh_l", "thigh_r", "clav_l", "clav_r"):
        c.joints[n].mat = "teal"
    add_head(c, "teal")
    add_mask_eyes(c, "glow_cyan", "angular", 1.1)
    c.part(box(head_point(c, 0, 0.1, 0.92), (0.03, 0.2, 0.07), rot=(-18, 0, 0), bevel=0.012), "head", "suit")
    add_pecs(c, "suit")
    add_emblem(c, "glow_cyan", "ring", z=1.4)
    c.part(torus((0, 0.32, 1.46), 0.3, 0.024, rot=(80, 0, 0), segs=36), "chest", "glow_cyan")
    add_shoulder_pads(c, "suit")
    add_gloves(c, "teal")
    add_boots(c, "teal")
    add_belt(c, "metal_trim", "glow_cyan")
    add_limb_stripes(c, "glow_cyan")
    c.build()
    add_anims(c, dict(pose="fist"))
    return c


def noctis():
    c = Character("noctis")
    c.mat("cloak", (0.1, 0.07, 0.17))
    c.mat("suit", (0.22, 0.17, 0.34))
    c.mat("mask", (0.05, 0.04, 0.08))
    c.mat("glow_violet", (0.78, 0.35, 1.0), emission=4.0)
    c.mat("metal_silver", (0.75, 0.75, 0.85), metallic=0.9, roughness=0.25)
    build_body(c, dict(shoulder=0.24, chest_r=(0.22, 0.14), waist_r=(0.11, 0.085), hip_r=(0.135, 0.1),
                       thigh_r=0.092, height=1.04, head=(0.14, 0.15, 0.165)))
    for n in c.joints:
        c.joints[n].mat = "suit"
    add_head(c, "mask")
    add_mask_eyes(c, "glow_violet", "slit", 1.2)
    # hood with a swept point
    hc = c.head_center
    c.part(ellipsoid((0, hc[1] + 0.025, hc[2] + 0.025), (0.17, 0.17, 0.185)), "head", "cloak")
    c.part(cone((0, hc[1] + 0.11, hc[2] + 0.1), 0.07, 0.0, 0.22, rot=(-128, 0, 0), segs=10), "head", "cloak")
    # scarf + long tattered cape
    c.part(torus((0, 0, 1.56), 0.09, 0.04, segs=20), "neck", "cloak")
    c.part(tube([(0.05, 0.08, 1.54), (0.1, 0.22, 1.42), (0.13, 0.33, 1.2), (0.09, 0.4, 0.98)],
                [0.045, 0.04, 0.032, 0.012]), "chest", "cloak")
    add_cape(c, "cloak", length=1.5, width=0.95)
    for i, x in enumerate((-0.2, -0.07, 0.07, 0.2)):
        c.part(cone((x, 0.31, 0.6 - 0.04 * (i % 2)), 0.06, 0.0, 0.16, rot=(180, 0, 0), segs=4, scale=(1, 0.3, 1)), "chest", "cloak")
    add_pecs(c, "suit", 0.85)
    add_emblem(c, "metal_silver", "chevron", z=1.36)
    c.part_m(lambda s: forearm_blade(c, s, 0.55, 0.05), "wrist", "glow_violet", smooth=False)
    add_gloves(c, "mask")
    add_boots(c, "cloak")
    add_belt(c, "cloak", "metal_silver", "box")
    c.build()
    add_anims(c, dict(pose="cross"))
    return c


def pyra():
    c = Character("pyra")
    c.mat("suit", (0.9, 0.24, 0.1))
    c.mat("char", (0.16, 0.09, 0.09))
    c.mat("skin", (0.96, 0.74, 0.58))
    c.mat("mask", (0.12, 0.05, 0.05))
    c.mat("glow_fire", (1.0, 0.55, 0.1), emission=5.0)
    c.mat("glow_core", (1.0, 0.88, 0.35), emission=6.0)
    c.mat("eye_white", (1.0, 0.97, 0.9), emission=1.0)
    build_body(c, dict(shoulder=0.24, chest_r=(0.2, 0.135), waist_r=(0.105, 0.085), hip_r=(0.15, 0.11),
                       thigh_r=0.098, height=0.99, head=(0.145, 0.15, 0.165)))
    for n in ("hips",):
        c.joints[n].mat = "char"
    add_head(c, "skin")
    # domino mask + eyes
    c.part(ellipsoid(head_point(c, 0, -0.72, 0.12), (0.14, 0.06, 0.05), rot=(0, 0, 0)), "head", "mask")
    add_mask_eyes(c, "eye_white", "round", 0.9)
    # flame hair sweeping back
    hc = c.head_center
    c.part(ellipsoid((0, hc[1] + 0.03, hc[2] + 0.06), (0.155, 0.155, 0.13)), "head", "glow_fire")
    for x, zr, ang, ln in [(0, 0.12, -32, 0.34), (0.08, 0.1, -42, 0.26), (-0.08, 0.1, -42, 0.26),
                           (0.045, 0.14, -18, 0.24), (-0.045, 0.14, -18, 0.24), (0, 0.07, -72, 0.3),
                           (0.11, 0.03, -80, 0.2), (-0.11, 0.03, -80, 0.2)]:
        c.part(cone((x, hc[1] + 0.03, hc[2] + zr - 0.02), 0.075, 0.0, ln, rot=(ang, x * 140, 0), segs=8), "head", "glow_fire")
    add_emblem(c, "glow_core", "flame", z=1.36, size=1.1)
    add_gloves(c, "char")
    add_boots(c, "char")
    c.part_m(lambda s: torus((s * 0.37, -0.02, 1.0), 0.064, 0.016), "wrist", "glow_fire")
    c.part_m(lambda s: torus((s * 0.135, 0.0, 0.38), 0.098, 0.016), "knee", "glow_fire")
    add_belt(c, "char", "glow_core")
    c.build()
    add_anims(c, dict(pose="open"))
    return c


def bastion():
    c = Character("bastion")
    c.mat("armor", (0.22, 0.42, 0.66), metallic=0.4, roughness=0.35)
    c.mat("under", (0.15, 0.16, 0.2))
    c.mat("metal_steel", (0.66, 0.7, 0.75), metallic=0.85, roughness=0.3)
    c.mat("glow_gold", (1.0, 0.8, 0.25), emission=3.5)
    build_body(c, dict(shoulder=0.32, chest_r=(0.31, 0.19), waist_r=(0.17, 0.13), hip_r=(0.18, 0.13), arm_r=0.09,
                       fore_r=0.085, thigh_r=0.125, shin_r=0.1, neck_r=0.085, height=1.06, hand=0.095,
                       head=(0.15, 0.16, 0.16), foot=(0.095, 0.16, 0.075)))
    for n in c.joints:
        c.joints[n].mat = "under"
    for n in ("chest", "spine", "shoulder_l", "shoulder_r"):
        c.joints[n].mat = "armor"
    add_head(c, "armor")
    c.part(box(head_point(c, 0, -0.84, 0.1), (0.21, 0.04, 0.045), bevel=0.012), "head", "glow_gold")
    c.part(box(head_point(c, 0, 0.0, 0.9), (0.06, 0.26, 0.08), bevel=0.022), "head", "metal_steel")
    c.part_m(lambda s: ellipsoid((s * 0.37, 0, 1.6), (0.18, 0.17, 0.12), rot=(0, s * -25, 0)), "shoulder", "metal_steel")
    c.part_m(lambda s: box((s * 0.37, 0, 1.71), (0.12, 0.14, 0.045), rot=(0, s * -25, 0), bevel=0.015), "shoulder", "armor")
    c.part(box((0, -0.2, 1.4), (0.36, 0.08, 0.28), rot=(8, 0, 0), bevel=0.045), "chest", "armor")
    add_emblem(c, "glow_gold", "star", z=1.42, size=0.9)
    sx, sy, sz = forearm_point(c, 1, 0.5)
    c.part(box((sx + 0.13, sy - 0.03, sz), (0.07, 0.5, 0.74), rot=(0, 6, 0), bevel=0.045), "elbow_l", "metal_steel")
    c.part(box((sx + 0.17, sy - 0.03, sz), (0.02, 0.38, 0.6), rot=(0, 6, 0), bevel=0.01), "elbow_l", "armor")
    c.part(torus((sx + 0.185, sy - 0.03, sz), 0.1, 0.022, rot=(0, 90, 0), segs=20), "elbow_l", "glow_gold")
    add_gloves(c, "metal_steel", size=1.1)
    add_boots(c, "metal_steel", size=1.1)
    add_belt(c, "armor", "glow_gold", "box")
    c.build()
    add_anims(c, dict(pose="guard", heavy=1.0))
    return c


def rift():
    c = Character("rift")
    c.mat("suit", (0.08, 0.08, 0.22))
    c.mat("white", (0.88, 0.88, 0.97))
    c.mat("glow_magenta", (1.0, 0.25, 0.85), emission=4.5)
    c.mat("glow_star", (0.7, 0.82, 1.0), emission=5.0)
    build_body(c, dict(shoulder=0.25, chest_r=(0.22, 0.14), waist_r=(0.11, 0.088), thigh_r=0.095, height=1.02))
    for n in ("shoulder_l", "elbow_l", "wrist_l", "thigh_r", "knee_r"):
        c.joints[n].mat = "white"
    add_head(c, "suit")
    c.part(ellipsoid(head_point(c, 0, -0.55, 0.0), (0.12, 0.08, 0.13)), "head", "white")
    c.part(box(head_point(c, 0.0, -0.97, 0.0), (0.014, 0.012, 0.19), rot=(0, 14, 0)), "head", "glow_magenta")
    add_mask_eyes(c, "glow_star", "slit", 0.9)
    for x, y, z, rx in [(0.4, 0.05, 1.72, 20), (-0.42, 0.0, 1.64, -30), (0.22, 0.2, 1.92, 45), (-0.16, 0.25, 1.98, 70)]:
        c.part(cone((x, y, z), 0.05, 0.0, 0.18, rot=(rx, rx * 0.5, 0), segs=4), "chest", "glow_star", smooth=False)
    c.part(torus((0, 0, 1.36), 0.24, 0.012, rot=(15, 20, 0), segs=36), "chest", "glow_magenta")
    add_emblem(c, "glow_star", "star", z=1.4, size=0.8)
    add_pecs(c, "suit", 0.9)
    c.part_m(lambda s: box((s * 0.125, -0.085, 0.7), (0.012, 0.01, 0.3), rot=(0, s * 10, 0)), "thigh", "glow_magenta")
    add_gloves(c, "white")
    add_boots(c, "suit")
    add_belt(c, "white", "glow_magenta")
    c.build()
    add_anims(c, dict(pose="open"))
    return c


def porteur():
    """Le Porteur — a survivor bonded with a tamed symbiote. Tentacles are real bones."""
    c = Character("porteur")
    c.mat("symbiote", (0.05, 0.04, 0.06), roughness=0.25)
    c.mat("vein", (0.6, 0.05, 0.1))
    c.mat("eye_white", (0.97, 0.97, 1.0), emission=2.5)
    c.mat("glow_red", (1.0, 0.1, 0.15), emission=4.0)
    build_body(c, dict(shoulder=0.29, chest_r=(0.27, 0.16), waist_r=(0.13, 0.1), arm_r=0.08, fore_r=0.072,
                       height=1.05, head=(0.15, 0.16, 0.175)))
    for n in c.joints:
        c.joints[n].mat = "symbiote"
    add_head(c, "symbiote")
    for sg in (1, -1):
        c.part(ellipsoid(head_point(c, sg * 0.4, -0.84, 0.1), (0.065, 0.03, 0.04), rot=(0, sg * -25, sg * 28)), "head", "eye_white")
    add_pecs(c, "symbiote", 1.1)
    c.part(tube([(0.0, -0.2, 1.47), (0.06, -0.19, 1.32), (0.03, -0.15, 1.14), (0.08, -0.13, 1.0)],
                [0.016, 0.014, 0.012, 0.006], segs=6), "chest", "glow_red")
    c.part(tube([(-0.02, -0.2, 1.47), (-0.1, -0.18, 1.34), (-0.13, -0.13, 1.2)], [0.014, 0.012, 0.006], segs=6), "chest", "glow_red")
    for i, (sx, sz) in enumerate([(0.1, 1.44), (-0.1, 1.44), (0.08, 1.27), (-0.08, 1.27)]):
        d = 1 if sx > 0 else -1
        pts = [(sx, 0.15, sz), (sx + d * 0.12, 0.3, sz + 0.1), (sx + d * 0.28, 0.42, sz + 0.12),
               (sx + d * 0.42, 0.5, sz + 0.05), (sx + d * 0.52, 0.55, sz - 0.08)]
        c.chain(f"tent{i}_", "chest", pts, [0.05, 0.042, 0.032, 0.022, 0.01], mat="symbiote")
    for k in range(3):
        c.part_m(lambda sg, k=k: hand_claw(c, sg, (k - 1) * 0.03, 0.2), "wrist", "vein", smooth=False)
    add_gloves(c, "symbiote", cuff=False, size=1.1)
    add_boots(c, "symbiote", cuff=False)
    c.build()

    def tentacles(t, name):
        amp = 2.2 if name in ("cast", "attack3", "cast_up", "heavy") else 1.0
        p = {}
        for i in range(4):
            for k in range(4):
                ph = i * 0.21 + k * 0.12
                p[f"tent{i}_{k}"] = (amp * 14 * sw(t, ph), amp * 10 * sw(t, ph + 0.3), amp * 12 * sw(t, ph + 0.6))
        return p
    add_anims(c, dict(pose="guard"), tentacles)
    return c


def spark():
    """Spark — a street-smart electric courier (Commun)."""
    c = Character("spark")
    c.mat("jacket", (0.98, 0.78, 0.12))
    c.mat("black", (0.09, 0.09, 0.11))
    c.mat("skin", (0.62, 0.42, 0.3))
    c.mat("glow_volt", (0.55, 0.85, 1.0), emission=4.0)
    c.mat("metal_lens", (0.3, 0.32, 0.36), metallic=0.9, roughness=0.2)
    build_body(c, dict(shoulder=0.24, chest_r=(0.21, 0.14), waist_r=(0.115, 0.09), height=0.97,
                       head=(0.15, 0.155, 0.165)))
    for n in ("hips", "thigh_l", "thigh_r", "knee_l", "knee_r"):
        c.joints[n].mat = "black"
    add_head(c, "skin")
    hc = c.head_center
    c.part(ellipsoid((0, hc[1] + 0.02, hc[2] + 0.05), (0.158, 0.158, 0.13)), "head", "black")
    for x in (-0.07, 0.0, 0.07):
        c.part(cone((x, hc[1] + 0.02, hc[2] + 0.12), 0.045, 0.0, 0.14, rot=(-50, x * 200, 0), segs=6), "head", "black")
    c.part(torus(head_point(c, 0, 0.0, 0.25), 0.155, 0.018, segs=28, scale=(1, 1, 1)), "head", "black")
    for sg in (1, -1):
        c.part(torus(head_point(c, sg * 0.36, -0.86, 0.15), 0.04, 0.013, rot=(90, 0, sg * 20)), "head", "metal_lens")
        c.part(ellipsoid(head_point(c, sg * 0.36, -0.88, 0.15), (0.034, 0.012, 0.034)), "head", "glow_volt")
    add_emblem(c, "glow_volt", "chevron", z=1.36)
    c.part(box((0, 0.17, 1.3), (0.22, 0.12, 0.3), bevel=0.03), "chest", "black")
    c.part(cone((0.06, 0.2, 1.42), 0.012, 0.012, 0.35, rot=(-15, 10, 0), segs=6), "chest", "metal_lens")
    add_gloves(c, "black")
    add_boots(c, "jacket")
    add_belt(c, "black", "glow_volt", "box")
    c.build()
    add_anims(c, dict(pose="fist"))
    return c


def sylve():
    """Sylve — a botanist who grew living bark armour to resist spores (Rare)."""
    c = Character("sylve")
    c.mat("bark", (0.36, 0.24, 0.15))
    c.mat("leaf", (0.25, 0.62, 0.3))
    c.mat("moss", (0.14, 0.32, 0.18))
    c.mat("glow_sap", (0.6, 1.0, 0.45), emission=3.5)
    build_body(c, dict(shoulder=0.26, chest_r=(0.23, 0.15), height=1.02, head=(0.15, 0.16, 0.17)))
    for n in c.joints:
        c.joints[n].mat = "moss"
    for n in ("chest", "shoulder_l", "shoulder_r", "knee_l", "knee_r"):
        c.joints[n].mat = "bark"
    add_head(c, "bark")
    add_mask_eyes(c, "glow_sap", "round", 1.0)
    hc = c.head_center
    for i, (x, rz) in enumerate([(0.1, 30), (-0.1, -30), (0.0, 0), (0.14, 60), (-0.14, -60)]):
        c.part(ellipsoid((x, hc[1] + 0.05, hc[2] + 0.15), (0.05, 0.13, 0.02), rot=(35, 0, rz)), "head", "leaf")
    for x, z in [(0.12, 1.44), (-0.1, 1.3), (0.05, 1.2)]:
        c.part(ellipsoid((x, -0.16, z), (0.06, 0.03, 0.05), rot=(0, 0, 30)), "chest", "bark")
    add_shoulder_pads(c, "leaf", 1.15)
    add_emblem(c, "glow_sap", "diamond", z=1.38)
    add_cape(c, "leaf", length=0.9, width=0.85)
    add_gloves(c, "bark")
    add_boots(c, "bark")
    add_belt(c, "bark", "glow_sap")
    c.build()
    add_anims(c, dict(pose="guard"))
    return c


ALL = [vortex, noctis, pyra, bastion, rift, porteur, spark, sylve]
