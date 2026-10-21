"""Procedural music loops and ambience beds. Stereo, 32 kHz, encoded to OGG."""
import numpy as np

import synth as S
from synth import bp, brown, env_adsr, env_exp, hp, lp, midi, noise, normalize, osc_saw, osc_sine, osc_square, osc_tri, place, reverb, sweep

MSR = 32000


def stereo(l, r):
    n = max(len(l), len(r))
    return np.stack([S.pad_to(l, n), S.pad_to(r, n)], axis=1)


def t_(d):
    return np.arange(int(d * MSR)) / MSR


# ---------------------------------------------------------------- instruments
def pad(notes, dur, cutoff=1400, detune=0.006, rng=None):
    n = int(dur * MSR)
    L = np.zeros(n)
    R = np.zeros(n)
    for m in notes:
        f = midi(m)
        L += osc_saw(f * (1 - detune), dur, MSR) + 0.5 * osc_saw(f * 2 * (1 + detune / 2), dur, MSR)
        R += osc_saw(f * (1 + detune), dur, MSR) + 0.5 * osc_saw(f * 2 * (1 - detune / 2), dur, MSR)
    e = env_adsr(n, min(1.5, dur * 0.3), 0.5, 0.8, min(1.5, dur * 0.3), MSR)
    return lp(L, cutoff, MSR) * e / len(notes), lp(R, cutoff, MSR) * e / len(notes)


def choir(notes, dur, vowel="a"):
    n = int(dur * MSR)
    out = np.zeros(n)
    t = t_(dur)
    for m in notes:
        f = midi(m) * (1 + 0.004 * np.sin(2 * np.pi * 5 * t + m))
        src = osc_saw(f, dur, MSR) + 0.05 * noise(dur, MSR)
        out += S.formant(src, vowel, MSR)
    return out * env_adsr(n, dur * 0.35, 0.3, 0.8, dur * 0.35, MSR) / len(notes)


def pluck(m, dur=0.6, bright=3000):
    n = int(dur * MSR)
    f = midi(m)
    tone = osc_saw(f, dur, MSR) * 0.4 + osc_sine(f, dur, MSR)
    return S.sweep_filter(tone, bright, 300, "low", MSR) * env_exp(n, dur * 0.3, MSR)


def bell(m, dur=2.5):
    n = int(dur * MSR)
    f = midi(m)
    out = osc_sine(f, dur, MSR) + 0.5 * osc_sine(f * 2.76, dur, MSR) * env_exp(n, 0.6, MSR) + 0.3 * osc_sine(f * 5.4, dur, MSR) * env_exp(n, 0.3, MSR)
    return out * env_exp(n, dur * 0.4, MSR)


def bass(m, dur, kind="saw"):
    n = int(dur * MSR)
    f = midi(m)
    tone = osc_saw(f, dur, MSR) if kind == "saw" else osc_sine(f, dur, MSR) + 0.3 * osc_square(f, dur, MSR)
    return lp(tone, 500, MSR) * env_adsr(n, 0.005, 0.1, 0.8, 0.05, MSR)


def kick(dur=0.45):
    n = int(dur * MSR)
    return osc_sine(sweep(140, 42, dur, MSR), dur, MSR) * env_exp(n, 0.13, MSR) * 1.2


def snare(dur=0.3, seed=0):
    n = int(dur * MSR)
    return (bp(noise(dur, MSR, np.random.default_rng(seed)), 1000, 7000, MSR) * env_exp(n, 0.07, MSR)
            + osc_sine(190, dur, MSR) * env_exp(n, 0.04, MSR) * 0.6)


def hat(dur=0.08, seed=0):
    n = int(dur * MSR)
    return hp(noise(dur, MSR, np.random.default_rng(seed)), 7000, MSR) * env_exp(n, 0.015, MSR) * 0.5


def taiko(dur=0.9):
    n = int(dur * MSR)
    return osc_sine(sweep(90, 50, dur, MSR), dur, MSR) * env_exp(n, 0.25, MSR) * 1.3 + lp(noise(dur, MSR), 600, MSR) * env_exp(n, 0.05, MSR) * 0.5


def stab(notes, dur=0.35, cutoff=2200):
    n = int(dur * MSR)
    out = np.zeros(n)
    for m in notes:
        out += osc_saw(midi(m), dur, MSR) + osc_saw(midi(m) * 1.005, dur, MSR)
    return lp(out, cutoff, MSR) * env_exp(n, 0.12, MSR) / len(notes)


def tremolo_strings(notes, dur, rate=12):
    n = int(dur * MSR)
    t = t_(dur)
    out = np.zeros(n)
    for m in notes:
        out += osc_saw(midi(m) * (1 + 0.003 * np.sin(2 * np.pi * 5 * t)), dur, MSR)
    am = 0.55 + 0.45 * np.sin(2 * np.pi * rate * t)
    return lp(out, 2600, MSR) * am * env_adsr(n, 0.05, 0.1, 0.9, 0.1, MSR) / len(notes)


def drone(m, dur, cutoff=400, wobble=0.1):
    t = t_(dur)
    f = midi(m) * (1 + 0.003 * np.sin(2 * np.pi * wobble * t))
    tone = osc_saw(f, dur, MSR) + osc_saw(f * 1.5, dur, MSR) * 0.3 + osc_sine(f * 0.5, dur, MSR)
    return lp(tone, cutoff, MSR)


# ---------------------------------------------------------------- tracks
def grid(bpm, bars, beats=4):
    beat = 60.0 / bpm
    return beat, beat * beats * bars


def finish(L, R, rv=0.25, decay=2.0, peak=0.8):
    """Reverb whose tail is folded back onto the start so the loop stays seamless."""
    n = len(L)
    out = []
    for ch, sd in ((L, 1), (R, 2)):
        w = reverb(ch, MSR, decay=decay, wet=rv, seed=sd)
        body = w[:n].copy()
        tail = w[n:]
        k = min(len(tail), n)
        body[:k] += tail[:k]
        out.append(body)
    return normalize(stereo(out[0], out[1]), peak)


def track_menu():
    bpm = 72
    beat, total = grid(bpm, 16)
    n = int(total * MSR)
    L, R = np.zeros(n), np.zeros(n)
    prog = [[50, 57, 62, 65], [46, 53, 58, 62], [41, 48, 53, 57], [48, 55, 60, 64]]  # Dm Bb F C
    bar = beat * 4
    for i in range(16):
        ch = prog[(i // 2) % 4]
        if i % 2 == 0:
            l, r = pad(ch, bar * 2 + 0.5, cutoff=1200)
            place(L, l * 0.5, i * bar, MSR)
            place(R, r * 0.5, i * bar, MSR)
            c = choir([ch[1] + 12, ch[2] + 12], bar * 2, "o" if i % 4 == 0 else "a")
            place(L, c * 0.25, i * bar, MSR)
            place(R, c * 0.25, i * bar, MSR)
        place(L, bass(ch[0] - 12, bar * 0.95, "sine") * 0.5, i * bar, MSR)
        place(R, bass(ch[0] - 12, bar * 0.95, "sine") * 0.5, i * bar, MSR)
        if i >= 4:
            place(L, taiko() * 0.6, i * bar, MSR)
            place(R, taiko() * 0.6, i * bar, MSR)
            place(L, taiko() * 0.35, i * bar + beat * 2.5, MSR)
            place(R, taiko() * 0.35, i * bar + beat * 2.5, MSR)
        arp = [ch[0] + 24, ch[2] + 12, ch[3] + 12, ch[1] + 24]
        if i >= 8:
            for k in range(8):
                p = pluck(arp[k % 4], 0.5) * 0.18
                place(L if k % 2 == 0 else R, p, i * bar + k * beat / 2, MSR)
    return finish(L, R, 0.3, 2.5)


def track_explore(kind):
    rng = np.random.default_rng(hash(kind) % 1000)
    bpm = 60
    beat, total = grid(bpm, 12)
    n = int(total * MSR)
    L, R = np.zeros(n), np.zeros(n)
    roots = {"city": 45, "forest": 43, "lab": 47, "depths": 38, "forbidden": 41, "base": 48}
    root = roots[kind]
    minor = [0, 3, 7, 10, 14]
    bar = beat * 4
    for i in range(0, 12, 3):
        notes = [root + x for x in ([0, 7, 12, 15] if i % 6 == 0 else [-2, 5, 10, 15])]
        if kind == "base":
            notes = [root + x for x in ([0, 4, 7, 11] if i % 6 == 0 else [-3, 4, 7, 12])]
        cut = {"city": 900, "forest": 700, "lab": 600, "depths": 500, "forbidden": 700, "base": 1300}[kind]
        l, r = pad(notes, bar * 3 + 1.0, cutoff=cut, detune=0.008)
        place(L, l * 0.45, i * bar, MSR)
        place(R, r * 0.45, i * bar, MSR)
    d = drone(root - 12, total, 250)
    L += d * 0.25
    R += d * 0.25
    if kind in ("city", "base"):
        for k in range(10):
            at = rng.uniform(0, total - 2)
            m = root + 24 + minor[rng.integers(0, 5)]
            p = pluck(m, 1.2, 1800) * 0.2
            place(L if k % 2 else R, p, at, MSR)
    if kind == "depths":
        for k in range(8):
            at = rng.uniform(0, total - 3)
            m = root + 36 + minor[rng.integers(0, 5)]
            b = bell(m, 3.0) * 0.12
            place(L if k % 2 else R, b, at, MSR)
    if kind == "lab":
        for k in range(int(total / (beat / 2))):
            if rng.random() < 0.35:
                m = root + 24 + [0, 7, 12, 15][rng.integers(0, 4)]
                bl = lp(osc_square(midi(m), 0.12, MSR), 2000, MSR) * env_exp(int(0.12 * MSR), 0.04, MSR) * 0.08
                place(L if k % 2 else R, bl, k * beat / 2, MSR)
    if kind == "forest":
        for k in range(14):
            at = rng.uniform(0, total - 1)
            clk = bp(noise(0.1, MSR, rng), 500, 2500, MSR) * env_exp(int(0.1 * MSR), 0.01, MSR) * 0.2
            place(L if k % 2 else R, clk, at, MSR)
        hi = choir([root + 31, root + 34], total, "u") * 0.12
        L += hi
        R += hi
    if kind == "forbidden":
        for k in range(12):
            place(L, kick(0.6) * 0.5, k * bar / 2, MSR)
            place(R, kick(0.6) * 0.5, k * bar / 2 + 0.25, MSR)
        dis = tremolo_strings([root + 13, root + 14], total, 3) * 0.08
        L += dis
        R += dis
    return finish(L, R, 0.35, 3.0, 0.7)


def track_combat(intensity="combat"):
    bpm = {"combat": 128, "chase": 150, "boss": 140}[intensity]
    beat, total = grid(bpm, 16)
    n = int(total * MSR)
    L, R = np.zeros(n), np.zeros(n)
    bar = beat * 4
    prog = [38, 38, 46, 45] if intensity != "chase" else [37, 38, 37, 39]
    for i in range(16):
        root = prog[(i // 2) % 4]
        for k in range(4):
            place(L, kick() * 0.8, i * bar + k * beat, MSR)
            place(R, kick() * 0.8, i * bar + k * beat, MSR)
            if k % 2 == 1:
                place(L, snare(seed=i * 4 + k) * 0.6, i * bar + k * beat, MSR)
                place(R, snare(seed=i * 4 + k + 1) * 0.6, i * bar + k * beat, MSR)
            for h in range(2):
                place(L if h else R, hat(seed=k + h) * 0.5, i * bar + k * beat + h * beat / 2, MSR)
        for k in range(8):
            m = root - 12 + (0 if k % 4 != 3 else 7)
            b = bass(m, beat / 2 * 0.9) * 0.5
            place(L, b, i * bar + k * beat / 2, MSR)
            place(R, b, i * bar + k * beat / 2, MSR)
        if intensity == "combat" and i % 2 == 0:
            s = stab([root + 12, root + 15, root + 19], 0.4) * 0.35
            place(L, s, i * bar, MSR)
            place(R, s, i * bar + beat * 1.5, MSR)
        if intensity == "chase":
            tr = tremolo_strings([root + 12, root + 13, root + 19], bar, 14) * 0.3
            place(L, tr, i * bar, MSR)
            place(R, tr, i * bar, MSR)
            if i % 4 == 3:
                place(L, S.sweep_filter(noise(bar, MSR), 300, 6000, "band", MSR) * np.linspace(0, 1, int(bar * MSR)) * 0.25, i * bar, MSR)
        if intensity == "boss":
            if i % 2 == 0:
                c = choir([root + 12, root + 15, root + 19], bar * 2, "a") * 0.4
                place(L, c, i * bar, MSR)
                place(R, c, i * bar, MSR)
            place(L, taiko() * 0.7, i * bar, MSR)
            place(R, taiko() * 0.7, i * bar + beat * 2, MSR)
            s = stab([root, root + 7, root + 12], 0.5, 1500) * 0.4
            place(L, s, i * bar + beat * 3, MSR)
            place(R, s, i * bar + beat * 3.5, MSR)
    return finish(L, R, 0.18, 1.2, 0.8)


def ambience(kind):
    d = 24.0
    rng = np.random.default_rng(len(kind) * 31)
    n = int(d * MSR)
    t = t_(d)
    L, R = np.zeros(n), np.zeros(n)
    if kind in ("city", "forest"):
        for ch, arr in ((0, L), (1, R)):
            w = S.sweep_filter(noise(d, MSR, np.random.default_rng(ch + 5)), 250, 700, "band", MSR, q_width=0.9)
            arr += w * (0.5 + 0.5 * np.sin(2 * np.pi * (0.07 + 0.02 * ch) * t)) * 0.5
    if kind == "city":
        for k in range(5):
            at = rng.uniform(0, d - 4)
            rum = lp(brown(3.0, MSR, rng), 120, MSR) * np.hanning(int(3 * MSR)) * 0.5
            place(L, rum, at, MSR)
            place(R, rum, at + 0.05, MSR)
    if kind == "forest":
        for k in range(25):
            at = rng.uniform(0, d - 1)
            f = rng.uniform(3000, 5000)
            ins = osc_sine(f + 200 * osc_sine(40, 0.4, MSR), 0.4, MSR) * np.hanning(int(0.4 * MSR)) * 0.04
            place(L if k % 2 else R, ins, at, MSR)
        for k in range(6):
            at = rng.uniform(0, d - 2)
            cr = bp(osc_saw(sweep(80, 130, 1.5, MSR), 1.5, MSR), 100, 1200, MSR) * np.hanning(int(1.5 * MSR)) * 0.12
            place(L if k % 2 else R, cr, at, MSR)
    if kind in ("lab", "base"):
        hum = lp(osc_saw(50, d, MSR) * 0.3 + osc_sine(100, d, MSR) * 0.3, 400, MSR)
        vent = bp(noise(d, MSR, rng), 200, 900, MSR) * 0.25
        L += hum * 0.6 + vent
        R += hum * 0.6 + bp(noise(d, MSR, np.random.default_rng(9)), 200, 900, MSR) * 0.25
        if kind == "lab":
            for k in range(4):
                at = rng.uniform(0, d - 1)
                place(L if k % 2 else R, lp(osc_saw(120, 0.3, MSR), 3000, MSR) * (rng.uniform(0, 1, int(0.3 * MSR)) > 0.5) * 0.1, at, MSR)
    if kind in ("depths", "forbidden"):
        dr = drone(26 if kind == "depths" else 29, d, 180, 0.05)
        L += dr * 0.35
        R += dr * 0.35
        for k in range(14 if kind == "depths" else 6):
            at = rng.uniform(0, d - 1)
            m = rng.integers(84, 96)
            dp = osc_sine(sweep(midi(m), midi(m) * 0.6, 0.1, MSR), 0.1, MSR) * env_exp(int(0.1 * MSR), 0.025, MSR) * 0.2
            place(L if k % 2 else R, dp, at, MSR)
        if kind == "forbidden":
            pulse = osc_sine(40, d, MSR) * (0.5 + 0.5 * np.sin(2 * np.pi * 1.1 * t)) ** 4 * 0.4
            L += pulse
            R += pulse
            wh = bp(noise(d, MSR, rng), 600, 2400, MSR) * (0.5 + 0.5 * np.sin(2 * np.pi * 0.13 * t)) * 0.1
            L += wh
            R -= wh * 0.5
    x = S.loopify(finish(L, R, 0.4, 2.5, 0.6), 1.0, MSR)
    return x


TRACKS = {
    "menu": track_menu,
    "explore_city": lambda: track_explore("city"),
    "explore_forest": lambda: track_explore("forest"),
    "explore_lab": lambda: track_explore("lab"),
    "explore_depths": lambda: track_explore("depths"),
    "explore_forbidden": lambda: track_explore("forbidden"),
    "base": lambda: track_explore("base"),
    "combat": lambda: track_combat("combat"),
    "chase": lambda: track_combat("chase"),
    "boss": lambda: track_combat("boss"),
}
AMBIENCES = {f"amb_{k}": (lambda k=k: ambience(k)) for k in ("city", "forest", "lab", "depths", "forbidden", "base")}
