"""Shared humanoid body + animation library for the playable heroes.

Axes (armature space): +X = character's left, -Y = forward, +Z = up.
Rotation cheat-sheet (degrees, armature-space Euler XYZ):
  legs / hanging arms : -X swings forward, +X swings back
  knees               : +X bends (foot goes back)
  elbows              : -X bends (hand comes forward/up)
  spine / chest       : +X leans forward
  any bone            : +Z turns toward the character's left
  left arm            : -Y raises it sideways (right arm: +Y)
"""
import math

from rigkit import Character, box, cone, ellipsoid, env, ease, merge, sw, torus, tube, v


def build_body(c: Character, p=None):
    """Create the standard heroic skeleton (V torso, big head). p: proportion overrides."""
    P = dict(height=1.0, shoulder=0.27, hip=0.11, chest_r=(0.25, 0.15), waist_r=(0.125, 0.095),
             hip_r=(0.15, 0.11), arm_r=0.07, fore_r=0.06, thigh_r=0.105, shin_r=0.075, neck_r=0.065,
             head=(0.15, 0.16, 0.17), hand=0.075, foot=(0.075, 0.14, 0.06), bulk=1.0)
    if p:
        P.update(p)
    h = P["height"]
    b = P["bulk"]

    def s(x, y, z):
        return (x, y, z * h)

    def r(val):
        return tuple(x * b for x in val) if isinstance(val, tuple) else val * b

    c.j("hips", s(0, 0, 0.95), r(P["hip_r"]))
    c.j("spine", s(0, 0, 1.12), r(P["waist_r"]), "hips")
    c.j("chest", s(0, 0, 1.36), r(P["chest_r"]), "spine")
    c.j("neck", s(0, 0, 1.56), r(P["neck_r"]), "chest")
    c.j("head", s(0, 0, 1.63), r(P["neck_r"] * 0.9), "neck")
    c.j("head_top", s(0, 0, 1.78), 0.05, "head")
    sh = P["shoulder"]
    c.jm("clav", s(sh * 0.45, 0, 1.48), r(P["arm_r"] * 1.15), "chest")
    c.jm("shoulder", s(sh, 0.0, 1.47), r(P["arm_r"] * 1.2), "clav")
    c.jm("elbow", s(sh + 0.06, 0.02, 1.2), r(P["fore_r"]), "shoulder")
    c.jm("wrist", s(sh + 0.10, -0.02, 0.98), r(P["fore_r"] * 0.78), "elbow")
    c.jm("hand", s(sh + 0.11, -0.03, 0.91), 0.03, "wrist")
    hp = P["hip"]
    c.jm("thigh", s(hp, 0, 0.90), r(P["thigh_r"]), "hips")
    c.jm("knee", s(hp + 0.02, -0.02, 0.50), r(P["shin_r"]), "thigh")
    c.jm("ankle", s(hp + 0.03, 0.02, 0.12), r(P["shin_r"] * 0.8), "knee")
    c.jm("toe", s(hp + 0.03, -0.10, 0.06), 0.035, "ankle")
    c.head_center = (0, -0.01, 1.76 * h)
    c.head_size = P["head"]
    c.P = P
    return P


def add_head(c, mat, shape=None):
    c.part(ellipsoid(c.head_center, shape or c.head_size, segs=20, rings=14), "head", mat)


def head_point(c, fx, fy, fz):
    """Point on/in the head ellipsoid in normalised coords (fy=-1 is the face)."""
    hc = c.head_center
    hx, hy, hz = c.head_size
    return (hc[0] + fx * hx, hc[1] + fy * hy, hc[2] + fz * hz)


def add_mask_eyes(c, mat, style="angular", size=1.0):
    """Big readable cartoon eye lenses on the mask."""
    hx, hy, hz = c.head_size
    if style == "angular":
        for sg in (1, -1):
            c.part(ellipsoid(head_point(c, sg * 0.38, -0.86, 0.12), (0.055 * size, 0.03, 0.032 * size),
                             rot=(0, sg * -18, sg * 22), segs=12, rings=8), "head", mat)
    elif style == "round":
        for sg in (1, -1):
            c.part(ellipsoid(head_point(c, sg * 0.36, -0.86, 0.1), (0.04 * size, 0.03, 0.045 * size),
                             rot=(0, sg * -20, 0), segs=12, rings=8), "head", mat)
    elif style == "slit":
        for sg in (1, -1):
            c.part(ellipsoid(head_point(c, sg * 0.37, -0.88, 0.1), (0.05 * size, 0.025, 0.014 * size),
                             rot=(0, sg * -18, sg * 14), segs=10, rings=6), "head", mat)
    elif style == "visor":
        c.part(ellipsoid(head_point(c, 0, -0.66, 0.1), (hx * 0.86, hy * 0.42, hz * 0.3), segs=18, rings=8), "head", mat)


def add_pecs(c, mat, size=1.0):
    for sg in (1, -1):
        c.part(ellipsoid((sg * 0.085, -0.105, 1.39), (0.1 * size, 0.06 * size, 0.075 * size), rot=(10, sg * 12, 0)), "chest", mat)


def add_gloves(c, mat, cuff=True, size=1.0):
    P = c.P
    h = P["height"]
    sh = P["shoulder"]
    hr = P["hand"] * size
    c.part_m(lambda sg: ellipsoid((sg * (sh + 0.11), -0.035, 0.895 * h), (hr * 0.85, hr, hr * 1.12)), "wrist", mat)
    if cuff:
        c.part_m(lambda sg: cone((sg * (sh + 0.085), 0.005, 1.08 * h), 0.068 * size, 0.055 * size, 0.13,
                                 rot=(180, sg * -9, 0), segs=12), "elbow", mat)


def add_boots(c, mat, cuff=True, size=1.0):
    P = c.P
    hp = P["hip"]
    fx, fy, fz = P["foot"]
    c.part_m(lambda sg: ellipsoid((sg * (hp + 0.03), -0.055, 0.06), (fx * size, fy * size, fz * size)), "ankle", mat)
    if cuff:
        c.part_m(lambda sg: cone((sg * (hp + 0.025), 0.0, 0.1), 0.082 * size, 0.092 * size, 0.3,
                                 rot=(0, 0, 0), segs=12), "knee", mat)


def add_belt(c, mat, buckle_mat=None, buckle="round"):
    c.part(torus((0, 0, 1.0), 0.152, 0.03, segs=28, scale=(1.0, 0.78, 1.0)), "hips", mat)
    if buckle_mat:
        if buckle == "round":
            c.part(ellipsoid((0, -0.13, 1.0), (0.05, 0.02, 0.045)), "hips", buckle_mat)
        else:
            c.part(box((0, -0.125, 1.0), (0.08, 0.025, 0.06), bevel=0.01), "hips", buckle_mat)


def add_emblem(c, mat, shape="diamond", z=1.38, size=1.0):
    y = -0.168
    if shape == "diamond":
        c.part(box((0, y, z), (0.09 * size, 0.02, 0.09 * size), rot=(0, 45, 0), bevel=0.008), "chest", mat)
    elif shape == "ring":
        c.part(torus((0, y, z), 0.06 * size, 0.016, rot=(90, 0, 0)), "chest", mat)
        c.part(ellipsoid((0, y, z), (0.035 * size, 0.012, 0.035 * size)), "chest", mat)
    elif shape == "flame":
        c.part(cone((0, y, z - 0.06 * size), 0.05 * size, 0.0, 0.16 * size, rot=(0, 0, 0), segs=6, scale=(1, 0.3, 1)), "chest", mat)
    elif shape == "chevron":
        for sg in (1, -1):
            c.part(box((sg * 0.045, y, z), (0.09 * size, 0.02, 0.025), rot=(0, sg * 35, 0), bevel=0.006), "chest", mat)
    elif shape == "star":
        for a in (0, 60, 120):
            c.part(box((0, y, z), (0.13 * size, 0.018, 0.026), rot=(0, a, 0), bevel=0.005), "chest", mat)


def add_cape(c, mat, length=1.0, width=1.0):
    pts = [(0, 0.13, 1.5), (0, 0.19, 1.25), (0, 0.24, 1.0), (0, 0.27, 0.95 - 0.35 * length)]
    rad = [0.2 * width, 0.23 * width, 0.27 * width, 0.3 * width]
    c.part(tube(pts, rad, segs=12), "chest", mat)


def add_shoulder_pads(c, mat, size=1.0):
    sh = c.P["shoulder"]
    c.part_m(lambda sg: ellipsoid((sg * (sh + 0.01), 0, 1.52), (0.11 * size, 0.11 * size, 0.08 * size),
                                  rot=(0, sg * -22, 0)), "shoulder", mat)


def add_limb_stripes(c, mat, which=("elbow", "knee")):
    sh = c.P["shoulder"]
    hp = c.P["hip"]
    for w in which:
        if w == "elbow":
            c.part_m(lambda sg: torus((sg * (sh + 0.04), 0.01, 1.3), 0.066, 0.012, rot=(0, sg * 10, 0)), "shoulder", mat)
        if w == "knee":
            c.part_m(lambda sg: torus((sg * (hp + 0.015), -0.01, 0.68), 0.1, 0.014), "thigh", mat)


def add_hands_feet(c, glove, boot):
    add_gloves(c, glove, cuff=False)
    add_boots(c, boot, cuff=False)


def add_eyes(c, mat, spread=0.045, y=None, z=None, size=(0.025, 0.012, 0.018), tilt=8):
    hc = c.head_center
    hx, hy, hz = c.head_size
    yy = hc[1] - hy * 0.92 if y is None else y
    zz = hc[2] + 0.01 if z is None else z
    c.part(ellipsoid((spread, yy, zz), size, rot=(0, -tilt, 0), segs=10, rings=6), "head", mat)
    c.part(ellipsoid((-spread, yy, zz), size, rot=(0, tilt, 0), segs=10, rings=6), "head", mat)


# ---------------------------------------------------------------------------
# Animations
# ---------------------------------------------------------------------------

def _arms_rest(spread=8):
    return {"shoulder_l": (0, -spread, 0), "shoulder_r": (0, spread, 0),
            "elbow_l": (-12, 0, 0), "elbow_r": (-12, 0, 0)}


def idle(style):
    heavy = style.get("heavy", 0.0)

    def f(t):
        b = sw(t)
        return merge(_arms_rest(10 + 6 * heavy), {
            "chest": (-2 * b, 0, 0), "spine": (2 + heavy * 4, 0, 0),
            "neck": (b * 1.5, 0, 0), "head": (-2, 0, 2 * sw(t, 0.25)),
            "shoulder_l": (2 * b, -2 * b, 0), "shoulder_r": (2 * b, 2 * b, 0),
            "thigh_l": (0, -3 - heavy * 3, 4), "thigh_r": (0, 3 + heavy * 3, -4),
            "knee_l": (3 + 2 * heavy, 0, 0), "knee_r": (3 + 2 * heavy, 0, 0),
            "_loc": {"hips": (0, 0, -0.008 * (1 + b) - 0.02 * heavy)},
        })
    return f


def run(style, speed=1.0):
    k = speed

    def f(t):
        s = sw(t)
        c = sw(t, 0.25)
        legL = -38 * k * s
        legR = 38 * k * s
        kneeL = 20 + 55 * k * max(0, sw(t, 0.12))
        kneeR = 20 + 55 * k * max(0, -sw(t, 0.12))
        return {
            "hips": (0, 0, 8 * s), "spine": (10 * k, 0, -6 * s), "chest": (4, 0, -6 * s),
            "head": (-10 * k, 0, 6 * s),
            "thigh_l": (legL, 0, 0), "thigh_r": (legR, 0, 0),
            "knee_l": (kneeL, 0, 0), "knee_r": (kneeR, 0, 0),
            "ankle_l": (-10 * s, 0, 0), "ankle_r": (10 * s, 0, 0),
            "shoulder_l": (32 * k * s, -12, 0), "shoulder_r": (-32 * k * s, 12, 0),
            "elbow_l": (-70, 0, 0), "elbow_r": (-70, 0, 0),
            "_loc": {"hips": (0, 0, 0.035 * k * abs(c) - 0.03)},
        }
    return f


def crouch(style):
    def f(t):
        s = sw(t)
        return {
            "spine": (25, 0, 0), "chest": (10, 0, 0), "head": (-28, 0, 0),
            "thigh_l": (-60 - 20 * s, 0, 0), "thigh_r": (-60 + 20 * s, 0, 0),
            "knee_l": (95 + 15 * max(0, s), 0, 0), "knee_r": (95 + 15 * max(0, -s), 0, 0),
            "ankle_l": (-30, 0, 0), "ankle_r": (-30, 0, 0),
            "shoulder_l": (-25 + 10 * s, -10, 0), "shoulder_r": (-25 - 10 * s, 10, 0),
            "elbow_l": (-80, 0, 0), "elbow_r": (-80, 0, 0),
            "_loc": {"hips": (0, 0.05, -0.32)},
        }
    return f


def attack(side, style, kind="strike"):
    """Fast strike with wind-up, impact (~45%) and recovery."""
    L, R = ("_l", "_r") if side == "l" else ("_r", "_l")
    sg = 1 if side == "l" else -1

    def f(t):
        wind = env(t, 0.0, 0.25, 0.25, 0.45)
        hit = env(t, 0.25, 0.42, 0.6, 1.0)
        twist = -25 * wind + 35 * hit
        p = merge(_arms_rest(), {
            "hips": (0, 0, sg * 0.4 * twist),
            "spine": (8 * hit, 0, sg * twist * 0.6), "chest": (6 * hit, 0, sg * twist * 0.6),
            "head": (0, 0, -sg * twist * 0.8),
            "shoulder" + L: (40 * wind - 95 * hit, -sg * 20 * wind - sg * 10 * hit, 0),
            "elbow" + L: (-110 * wind - 10 * hit, 0, 0),
            "shoulder" + R: (-30 * hit, sg * 20, 0), "elbow" + R: (-90, 0, 0),
            "thigh" + L: (-25 * hit, 0, 0), "thigh" + R: (20 * hit, 0, 0),
            "knee" + L: (20 * hit, 0, 0), "knee" + R: (25 * hit, 0, 0),
            "_loc": {"hips": (0, -0.08 * hit, -0.05 * hit)},
        })
        return p
    return f


def attack_spin(style):
    def f(t):
        spin = 360 * ease(min(1.0, max(0.0, (t - 0.15) / 0.55)))
        up = env(t, 0.1, 0.3, 0.6, 0.9)
        return merge(_arms_rest(), {
            "hips": (0, 0, -spin),
            "spine": (6, 0, 0),
            "shoulder_l": (-30 * up, -70 * up, 0), "shoulder_r": (-30 * up, 70 * up, 0),
            "elbow_l": (-20, 0, 0), "elbow_r": (-20, 0, 0),
            "thigh_l": (-50 * up, -10 * up, 0), "knee_l": (60 * up, 0, 0),
            "thigh_r": (20 * up, 0, 0), "knee_r": (30 * up, 0, 0),
            "_loc": {"hips": (0, 0, 0.12 * math.sin(math.pi * min(1, max(0, (t - 0.1) / 0.7))))},
        })
    return f


def heavy_slam(style):
    def f(t):
        rise = env(t, 0.0, 0.4, 0.4, 0.55)
        slam = env(t, 0.42, 0.55, 0.75, 1.0)
        return {
            "spine": (-20 * rise + 35 * slam, 0, 0), "chest": (-10 * rise + 15 * slam, 0, 0),
            "head": (10 * rise - 20 * slam, 0, 0),
            "shoulder_l": (-170 * rise - 70 * slam, -15, 0), "shoulder_r": (-170 * rise - 70 * slam, 15, 0),
            "elbow_l": (-40 * rise, 0, 0), "elbow_r": (-40 * rise, 0, 0),
            "thigh_l": (-20 * rise - 50 * slam, -10, 0), "thigh_r": (10 * rise + 25 * slam, 10, 0),
            "knee_l": (20 * rise + 60 * slam, 0, 0), "knee_r": (10 * rise + 70 * slam, 0, 0),
            "ankle_l": (-20 * slam, 0, 0),
            "_loc": {"hips": (0, -0.1 * slam, 0.08 * rise - 0.28 * slam)},
        }
    return f


def cast_forward(style):
    def f(t):
        push = env(t, 0.15, 0.35, 0.65, 1.0)
        pull = env(t, 0.0, 0.15, 0.15, 0.3)
        return merge(_arms_rest(), {
            "spine": (5 * push - 6 * pull, 0, 0), "chest": (6 * push, 0, 0),
            "shoulder_l": (-85 * push + 20 * pull, -10 * push, 0), "shoulder_r": (-85 * push + 20 * pull, 10 * push, 0),
            "elbow_l": (-60 * pull - 5 * push, 0, 0), "elbow_r": (-60 * pull - 5 * push, 0, 0),
            "thigh_l": (-25 * push, 0, 0), "thigh_r": (20 * push, 0, 0),
            "knee_l": (15 * push, 0, 0), "knee_r": (20 * push, 0, 0),
            "_loc": {"hips": (0, -0.05 * push, -0.04 * push)},
        })
    return f


def cast_up(style):
    def f(t):
        up = env(t, 0.1, 0.45, 0.75, 1.0)
        crouch_ = env(t, 0.0, 0.15, 0.15, 0.4)
        return {
            "spine": (-15 * up + 20 * crouch_, 0, 0), "chest": (-10 * up, 0, 0), "head": (-20 * up, 0, 0),
            "shoulder_l": (-160 * up, -30 * up, 0), "shoulder_r": (-160 * up, 30 * up, 0),
            "elbow_l": (-20 * up - 60 * crouch_, 0, 0), "elbow_r": (-20 * up - 60 * crouch_, 0, 0),
            "thigh_l": (-40 * crouch_, -12 * up, 0), "thigh_r": (-40 * crouch_, 12 * up, 0),
            "knee_l": (70 * crouch_, 0, 0), "knee_r": (70 * crouch_, 0, 0),
            "_loc": {"hips": (0, 0, -0.2 * crouch_ + 0.06 * up)},
        }
    return f


def dodge_roll(style):
    def f(t):
        r = 360 * ease(min(1, max(0, (t - 0.08) / 0.75)))
        tuck = env(t, 0.0, 0.2, 0.7, 0.95)
        return {
            "hips": (r, 0, 0),
            "spine": (35 * tuck, 0, 0), "chest": (20 * tuck, 0, 0), "head": (30 * tuck, 0, 0),
            "thigh_l": (-110 * tuck, 0, 0), "thigh_r": (-110 * tuck, 0, 0),
            "knee_l": (130 * tuck, 0, 0), "knee_r": (130 * tuck, 0, 0),
            "shoulder_l": (-60 * tuck, -10, 0), "shoulder_r": (-60 * tuck, 10, 0),
            "elbow_l": (-110 * tuck, 0, 0), "elbow_r": (-110 * tuck, 0, 0),
            "_loc": {"hips": (0, 0, -0.45 * tuck)},
        }
    return f


def hit_react(style):
    def f(t):
        k = env(t, 0.0, 0.15, 0.3, 1.0)
        return merge(_arms_rest(), {
            "spine": (-18 * k, 0, 6 * k), "chest": (-10 * k, 0, 0), "head": (-15 * k, 0, -8 * k),
            "shoulder_l": (25 * k, -30 * k, 0), "shoulder_r": (25 * k, 30 * k, 0),
            "elbow_l": (-40 * k, 0, 0), "elbow_r": (-40 * k, 0, 0),
            "thigh_l": (10 * k, 0, 0), "knee_l": (15 * k, 0, 0),
            "_loc": {"hips": (0, 0.06 * k, -0.03 * k)},
        })
    return f


def death(style):
    def f(t):
        k = ease(min(1, t / 0.6))
        fall = ease(min(1, max(0, (t - 0.3) / 0.5)))
        return {
            "hips": (-80 * fall, 0, 10 * k),
            "spine": (-10 * k, 0, 0), "head": (-25 * k, 0, 15 * k),
            "thigh_l": (-30 * k + 30 * fall, -10 * k, 0), "thigh_r": (-10 * k + 20 * fall, 10 * k, 0),
            "knee_l": (70 * k - 50 * fall, 0, 0), "knee_r": (40 * k - 30 * fall, 0, 0),
            "shoulder_l": (-40 * fall, -60 * k, 0), "shoulder_r": (-20 * fall, 70 * k, 0),
            "elbow_l": (-30 * k, 0, 0), "elbow_r": (-50 * k, 0, 0),
            "_loc": {"hips": (0, 0.25 * fall, -0.55 * k - 0.25 * fall)},
        }
    return f


def spawn(style):
    """Superhero landing then rise to a confident stance."""
    def f(t):
        land = 1.0 - ease(min(1, max(0, (t - 0.35) / 0.45)))
        return merge(_arms_rest(), {
            "spine": (45 * land, 0, 0), "chest": (10 * land, 0, 0), "head": (-40 * land, 0, 0),
            "thigh_l": (-95 * land, -10 * land, 0), "knee_l": (110 * land, 0, 0), "ankle_l": (-20 * land, 0, 0),
            "thigh_r": (10 * land, 10 * land, 0), "knee_r": (120 * land, 0, 0), "ankle_r": (40 * land, 0, 0),
            "shoulder_r": (-70 * land, 10 * land, 0), "elbow_r": (-10 * land, 0, 0),
            "shoulder_l": (20 * land, -50 * land, 0), "elbow_l": (-30 * land, 0, 0),
            "_loc": {"hips": (0, 0.05 * land, -0.5 * land)},
        })
    return f


def hero_pose(style):
    pose = style.get("pose", "fist")

    def f(t):
        b = sw(t)
        base = {
            "spine": (-3, 0, 0), "chest": (-4 + 1.5 * b, 0, 0), "head": (-6, 0, 10),
            "thigh_l": (-8, -10, 8), "thigh_r": (6, 12, -10),
            "knee_l": (8, 0, 0), "knee_r": (4, 0, 0),
            "_loc": {"hips": (0, 0, -0.01 * (1 + b))},
        }
        if pose == "fist":
            base.update({"shoulder_r": (-150, 25, 0), "elbow_r": (-25, 0, 0),
                         "shoulder_l": (5, -25, 0), "elbow_l": (-90, 0, 40)})
        elif pose == "guard":
            base.update({"shoulder_l": (-60, -10, 0), "elbow_l": (-90, 0, 0),
                         "shoulder_r": (-40, 20, 0), "elbow_r": (-100, 0, 0)})
        elif pose == "cross":
            base.update({"shoulder_l": (-70, 25, 0), "elbow_l": (-100, 0, 0),
                         "shoulder_r": (-70, -25, 0), "elbow_r": (-100, 0, 0)})
        elif pose == "open":
            base.update({"shoulder_l": (-20, -55, 0), "elbow_l": (-30, 0, 0),
                         "shoulder_r": (-20, 55, 0), "elbow_r": (-30, 0, 0)})
        return base
    return f


def block(style):
    def f(t):
        b = sw(t)
        return {
            "spine": (8, 0, 0), "chest": (4 + b, 0, 0), "head": (6, 0, 0),
            "shoulder_l": (-75, 20, 0), "elbow_l": (-95, 0, 0),
            "shoulder_r": (-75, -20, 0), "elbow_r": (-95, 0, 0),
            "thigh_l": (-25, -6, 0), "thigh_r": (15, 6, 0), "knee_l": (30, 0, 0), "knee_r": (25, 0, 0),
            "_loc": {"hips": (0, 0, -0.08)},
        }
    return f


def add_hero_anims(c, style):
    c.add_anim("idle", 60, idle(style))
    c.add_anim("run", 20, run(style, 1.0))
    c.add_anim("sprint", 16, run(style, 1.35))
    c.add_anim("crouch", 36, crouch(style))
    c.add_anim("attack1", 16, attack("r", style), loop=False)
    c.add_anim("attack2", 16, attack("l", style), loop=False)
    c.add_anim("attack3", 24, attack_spin(style), loop=False)
    c.add_anim("heavy", 28, heavy_slam(style), loop=False)
    c.add_anim("cast", 18, cast_forward(style), loop=False)
    c.add_anim("cast_up", 26, cast_up(style), loop=False)
    c.add_anim("dodge", 16, dodge_roll(style), loop=False)
    c.add_anim("hit", 12, hit_react(style), loop=False)
    c.add_anim("death", 40, death(style), loop=False)
    c.add_anim("spawn", 40, spawn(style), loop=False)
    c.add_anim("pose", 60, hero_pose(style))
    c.add_anim("block", 24, block(style))
