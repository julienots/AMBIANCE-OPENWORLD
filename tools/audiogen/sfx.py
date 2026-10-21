"""Sound effects for SYMBIOTE: ABYSS. Each function returns a mono float array at SR."""
import numpy as np

from synth import *  # noqa: F401,F403

R = np.random.default_rng


# ---------------------------------------------------------------- UI
def ui_click(seed=0):
    n = int(0.06 * SR)
    return osc_sine(sweep(2200, 1400, 0.06), 0.06) * env_exp(n, 0.015) * 0.6


def ui_back(seed=0):
    n = int(0.09 * SR)
    return osc_tri(sweep(900, 500, 0.09), 0.09) * env_exp(n, 0.03) * 0.6


def ui_confirm(seed=0):
    out = np.zeros(int(0.3 * SR))
    for i, f in enumerate((660, 990)):
        n = int(0.18 * SR)
        place(out, (osc_sine(f, 0.18) + 0.3 * osc_sine(f * 2, 0.18)) * env_exp(n, 0.07), i * 0.07)
    return out * 0.5


def ui_error(seed=0):
    n = int(0.25 * SR)
    return lp(osc_square(140, 0.25), 1200) * env_adsr(n, 0.005, 0.05, 0.6, 0.08) * 0.4


def ui_reward(seed=0):
    out = np.zeros(int(0.7 * SR))
    for i, m in enumerate((72, 76, 79, 84)):
        n = int(0.4 * SR)
        place(out, (osc_sine(midi(m), 0.4) + 0.25 * osc_sine(midi(m) * 3, 0.4)) * env_exp(n, 0.15), i * 0.07)
    return reverb(out, decay=0.8, wet=0.25)[:int(0.9 * SR)] * 0.5


def levelup(seed=0):
    out = np.zeros(int(1.6 * SR))
    for i, m in enumerate((60, 64, 67, 72, 76, 79)):
        n = int(0.9 * SR)
        tone = osc_saw(midi(m), 0.9) * 0.3 + osc_sine(midi(m), 0.9)
        place(out, lp(tone, 3000) * env_adsr(n, 0.01, 0.2, 0.4, 0.5), i * 0.08)
    return normalize(reverb(out, decay=1.2, wet=0.3), 0.7)


def logo_sting(seed=0):
    """SuperEssence studio intro: shimmering swell resolving on a bright chord + soft impact."""
    d = 3.2
    n = int(d * SR)
    out = np.zeros(n)
    for m in (50, 57, 62, 66, 69, 74):
        f = midi(m)
        tone = osc_saw(f * (1 + 0.003 * np.sin(np.arange(n) / SR * 5)), d) * 0.25 + osc_sine(f * 2, d) * 0.3
        out += lp(tone, 2500) * np.clip(np.linspace(-0.2, 1.4, n), 0, 1) * np.exp(-np.maximum(0, np.arange(n) / SR - 1.6) * 1.2)
    sh = hp(noise(d, rng=R(2)), 6000) * np.clip(np.linspace(0, 1.2, n), 0, 1) ** 3 * 0.25
    hit = osc_sine(sweep(120, 40, 1.2), 1.2) * env_exp(int(1.2 * SR), 0.35)
    out = mix(out, sh)
    place(out, hit * 1.2, 1.55)
    return normalize(reverb(out, decay=2.5, wet=0.35), 0.85)


def toast(seed=0):
    n = int(0.15 * SR)
    return osc_sine(1320, 0.15) * env_exp(n, 0.05) * 0.35


# ---------------------------------------------------------------- Player
def step_concrete(seed=0):
    r = R(10 + seed)
    n = int(0.12 * SR)
    nz = bp(noise(0.12, rng=r), 900 + 300 * seed, 4500) * env_exp(n, 0.018)
    th = osc_sine(sweep(110, 60, 0.12), 0.12) * env_exp(n, 0.025) * 0.6
    return normalize(nz + th, 0.5)


def step_dirt(seed=0):
    r = R(20 + seed)
    n = int(0.14 * SR)
    nz = lp(noise(0.14, rng=r), 1500 + 200 * seed) * env_exp(n, 0.03)
    return normalize(nz, 0.45)


def step_metal(seed=0):
    r = R(30 + seed)
    n = int(0.3 * SR)
    exc = noise(0.3, rng=r) * env_exp(n, 0.006)
    ring = resonator(exc, [430 + 40 * seed, 1180, 2310, 3410], [0.08, 0.06, 0.05, 0.03])
    return normalize(ring * 0.5 + bp(exc, 1000, 5000) * 0.6, 0.5)


def step_wet(seed=0):
    r = R(40 + seed)
    n = int(0.2 * SR)
    sq = sweep_filter(noise(0.2, rng=r), 3000, 500, "band") * env_exp(n, 0.05)
    return normalize(sq, 0.45)


def swing(seed=0):
    r = R(50 + seed)
    d = 0.22
    n = int(d * SR)
    w = sweep_filter(noise(d, rng=r), 700, 3200 + 400 * seed, "band", q_width=0.9) * np.sin(np.linspace(0, np.pi, n)) ** 2
    return normalize(w, 0.6)


def hit_flesh(seed=0):
    r = R(60 + seed)
    n = int(0.22 * SR)
    th = osc_sine(sweep(160, 45, 0.22), 0.22) * env_exp(n, 0.05)
    cr = bp(noise(0.22, rng=r), 600, 3500) * env_exp(n, 0.03)
    return normalize(dist(th + 0.8 * cr, 2.0), 0.8)


def hit_heavy(seed=0):
    r = R(70 + seed)
    n = int(0.5 * SR)
    th = osc_sine(sweep(120, 30, 0.5), 0.5) * env_exp(n, 0.12)
    cr = lp(noise(0.5, rng=r), 2500) * env_exp(n, 0.06)
    return normalize(dist(th * 1.2 + cr, 2.5), 0.9)


def dodge(seed=0):
    d = 0.3
    n = int(d * SR)
    w = sweep_filter(noise(d, rng=R(80)), 2500, 400, "band", q_width=1.0) * np.sin(np.linspace(0, np.pi, n))
    return normalize(w, 0.55)


def land(seed=0):
    n = int(0.25 * SR)
    return normalize(osc_sine(sweep(90, 40, 0.25), 0.25) * env_exp(n, 0.06) + lp(noise(0.25, rng=R(81)), 900) * env_exp(n, 0.04), 0.6)


def player_hurt(seed=0):
    d = 0.35
    n = int(d * SR)
    src = osc_saw(sweep(190 + 20 * seed, 120, d), d) + 0.3 * noise(d, rng=R(82 + seed))
    v = formant(src, "a" if seed % 2 == 0 else "o") * env_adsr(n, 0.01, 0.1, 0.5, 0.15)
    return normalize(mix(v, hit_flesh(seed) * 0.6), 0.8)


def player_death(seed=0):
    d = 1.6
    n = int(d * SR)
    src = osc_saw(sweep(170, 70, d), d) + 0.3 * noise(d, rng=R(83))
    v = formant(src, "o") * env_adsr(n, 0.02, 0.3, 0.4, 0.8)
    th = osc_sine(sweep(80, 30, 0.8), 0.8) * env_exp(int(0.8 * SR), 0.3)
    out = place(v, th, 0.9)
    return normalize(reverb(out, decay=1.8, wet=0.4), 0.8)


def heartbeat(seed=0):
    d = 0.9
    out = np.zeros(int(d * SR))
    for at, a in ((0.0, 1.0), (0.22, 0.7)):
        n = int(0.18 * SR)
        place(out, osc_sine(sweep(70, 40, 0.18), 0.18) * env_exp(n, 0.05) * a, at)
    return normalize(lp(out, 300), 0.9)


def breath(seed=0):
    d = 2.0
    n = int(d * SR)
    nz = noise(d, rng=R(84))
    e = np.abs(np.sin(np.linspace(0, 2 * np.pi, n))) ** 1.5
    return normalize(bp(nz, 400, 2200) * e, 0.4)


def energy_bolt(seed=0):
    d = 0.3
    n = int(d * SR)
    f = sweep(1800 + 200 * seed, 380, d)
    fm = osc_sine(f + 300 * osc_sine(f * 0.5, d), d)
    sp = hp(noise(d, rng=R(85)), 5000) * env_exp(n, 0.03) * 0.3
    return normalize((fm * env_exp(n, 0.09) + sp), 0.6)


def energy_impact(seed=0):
    d = 0.35
    n = int(d * SR)
    b = noise(d, rng=R(86)) * env_exp(n, 0.02)
    ring = resonator(b, [900, 1500, 2600], [0.05, 0.04, 0.03])
    th = osc_sine(sweep(200, 60, d), d) * env_exp(n, 0.05)
    return normalize(ring * 0.4 + th + lp(b, 3000) * 0.5, 0.7)


def shockwave(seed=0):
    d = 1.0
    n = int(d * SR)
    boom = osc_sine(sweep(90, 28, d), d) * env_exp(n, 0.25)
    wh = sweep_filter(noise(d, rng=R(87)), 300, 4000, "band", q_width=1.0) * env_exp(n, 0.3)
    return normalize(reverb(dist(boom * 1.4 + wh * 0.7, 1.8), decay=1.0, wet=0.25), 0.9)


def shield_up(seed=0):
    d = 0.8
    n = int(d * SR)
    out = np.zeros(n)
    for f in (420, 630, 840, 1260):
        out += osc_sine(sweep(f, f * 1.15, d), d) * 0.25
    out *= env_adsr(n, 0.05, 0.2, 0.5, 0.4)
    sh = hp(noise(d, rng=R(88)), 5000) * env_adsr(n, 0.05, 0.1, 0.2, 0.4) * 0.2
    return normalize(reverb(out + sh, decay=0.8, wet=0.3), 0.6)


def shield_hit(seed=0):
    n = int(0.4 * SR)
    exc = noise(0.4, rng=R(89)) * env_exp(n, 0.004)
    return normalize(resonator(exc, [1200, 1810, 2650, 3900], [0.12, 0.1, 0.08, 0.05]), 0.6)


def fire_cast(seed=0):
    d = 0.6
    n = int(d * SR)
    r = R(90 + seed)
    roar = lp(noise(d, rng=r), 1800) * env_adsr(n, 0.02, 0.1, 0.6, 0.3)
    crackle = np.zeros(n)
    for _ in range(40):
        i = r.integers(0, n - 200)
        crackle[i:i + 60] += r.uniform(-1, 1, 60) * np.exp(-np.arange(60) / 10)
    wh = sweep_filter(noise(d, rng=r), 400, 2500, "band") * env_exp(n, 0.2)
    return normalize(roar + hp(crackle, 2000) * 0.5 + wh * 0.6, 0.7)


def explosion(seed=0):
    d = 1.8
    n = int(d * SR)
    r = R(91 + seed)
    body = sweep_filter(noise(d, rng=r), 5000, 200, "low") * env_exp(n, 0.35)
    sub = osc_sine(sweep(70, 25, d), d) * env_exp(n, 0.4)
    crack = np.zeros(n)
    for _ in range(60):
        i = r.integers(int(0.1 * SR), n - 100)
        crack[i:i + 40] += r.uniform(-1, 1, 40) * np.exp(-np.arange(40) / 8) * np.exp(-i / SR / 0.5)
    return normalize(reverb(dist(body * 1.2 + sub * 1.3 + crack * 0.4, 2.2), decay=1.5, wet=0.25), 0.95)


def teleport(seed=0):
    d = 0.5
    n = int(d * SR)
    up = osc_sine(sweep(300, 2400, d), d) * np.linspace(0, 1, n) ** 2
    rw = sweep_filter(noise(d, rng=R(92)), 300, 6000, "band") * np.linspace(0, 1, n) ** 3
    zap = np.zeros(n)
    place(zap, osc_square(sweep(1600, 200, 0.08), 0.08) * env_exp(int(0.08 * SR), 0.02), d - 0.08)
    return normalize(up * 0.5 + rw * 0.6 + lp(zap, 4000) * 0.6, 0.6)


def shadow_blades(seed=0):
    out = mix(swing(1), np.concatenate([np.zeros(int(0.08 * SR)), swing(2)]))
    n = int(0.6 * SR)
    shing = resonator(noise(0.6, rng=R(93)) * env_exp(n, 0.003), [3100, 4700, 6200], [0.15, 0.1, 0.08])
    out = mix(out, shing * 0.3)
    return normalize(reverb(out, decay=0.6, wet=0.2), 0.7)


def invis(seed=0):
    d = 1.0
    n = int(d * SR)
    out = np.zeros(n)
    for f in (1600, 2100, 2800):
        out += osc_sine(sweep(f, f * 0.5, d), d) * 0.3
    return normalize(reverb(out * env_exp(n, 0.35), decay=1.2, wet=0.4), 0.5)


def dash(seed=0):
    d = 0.35
    n = int(d * SR)
    return normalize(sweep_filter(noise(d, rng=R(94 + seed)), 600, 5000, "band", q_width=1.2) * np.sin(np.linspace(0, np.pi, n)) ** 0.5, 0.65)


def portal(seed=0):
    d = 1.2
    n = int(d * SR)
    t = np.arange(n) / SR
    f = 200 + 80 * np.sin(2 * np.pi * 3 * t)
    v = osc_sine(f + 150 * osc_sine(f * 1.5, d), d) * env_adsr(n, 0.1, 0.2, 0.7, 0.4)
    sh = bp(noise(d, rng=R(95)), 2000, 6000) * 0.2 * (0.5 + 0.5 * np.sin(2 * np.pi * 6 * t))
    return normalize(reverb(v + sh, decay=1.0, wet=0.3), 0.6)


def electric(seed=0):
    d = 0.5
    n = int(d * SR)
    r = R(96 + seed)
    buzz = osc_square(sweep(120, 90, d), d) * (r.uniform(0.2, 1, n) > 0.6)
    cr = hp(noise(d, rng=r), 3000) * (r.uniform(0, 1, n) > 0.85)
    return normalize(lp(buzz * 0.6 + cr, 7000) * env_exp(n, 0.2), 0.6)


def roots(seed=0):
    d = 0.9
    n = int(d * SR)
    r = R(97)
    creak = lp(osc_saw(sweep(60, 110, d) * (1 + 0.1 * r.uniform(-1, 1, n)), d), 900) * env_adsr(n, 0.05, 0.2, 0.6, 0.3)
    cracks = np.zeros(n)
    for _ in range(10):
        i = r.integers(0, n - 400)
        cracks[i:i + 300] += bp(r.uniform(-1, 1, 300), 800, 4000) * np.exp(-np.arange(300) / 50)
    return normalize(creak * 0.6 + cracks, 0.7)


def regen(seed=0):
    out = np.zeros(int(1.2 * SR))
    for i, m in enumerate((67, 71, 74, 79, 83)):
        n = int(0.6 * SR)
        place(out, osc_sine(midi(m), 0.6) * env_exp(n, 0.25) * 0.4, i * 0.12)
    return normalize(reverb(out, decay=1.0, wet=0.35), 0.5)


def ult_cast(seed=0):
    d = 2.0
    n = int(d * SR)
    riser = sweep_filter(noise(d, rng=R(98)), 200, 6000, "band", q_width=0.8) * np.linspace(0, 1, n) ** 2
    tone = osc_saw(sweep(80, 320, d), d) * np.linspace(0, 1, n) ** 2 * 0.4
    out = mix(lp(tone, 2000) + riser * 0.6, np.zeros(int(2.8 * SR)))
    place(out, explosion() * 0.9, 1.85)
    return normalize(out, 0.95)


def meteor(seed=0):
    d = 1.3
    n = int(d * SR)
    wh = osc_sine(sweep(2500, 300, d), d) * np.linspace(0.1, 1, n) * 0.3 + sweep_filter(noise(d, rng=R(99)), 4000, 300, "band") * np.linspace(0, 1, n)
    out = mix(wh, np.zeros(int(3.0 * SR)))
    place(out, explosion(1), 1.25)
    return normalize(out, 0.95)


def singularity(seed=0):
    d = 2.5
    n = int(d * SR)
    t = np.arange(n) / SR
    drone = osc_sine(sweep(220, 35, d), d) * env_adsr(n, 0.1, 0.3, 0.8, 0.4)
    suck = sweep_filter(noise(d, rng=R(100)), 6000, 200, "band") * (0.5 + 0.5 * np.sin(2 * np.pi * 8 * t)) * 0.6
    return normalize(dist(drone + suck, 1.5), 0.85)


def transform(seed=0):
    d = 1.6
    n = int(d * SR)
    growl = lp(osc_saw(sweep(55, 90, d) * (1 + 0.05 * noise(d, rng=R(101))), d), 700)
    swell = osc_sine(sweep(40, 70, d), d) * np.linspace(0, 1, n)
    return normalize(reverb(dist(growl + swell, 3.0) * env_adsr(n, 0.2, 0.3, 0.8, 0.4), decay=1.2, wet=0.3), 0.85)


def metal_clang(seed=0):
    n = int(1.0 * SR)
    exc = noise(1.0, rng=R(102 + seed)) * env_exp(n, 0.005)
    return normalize(resonator(exc, [310, 812, 1650, 2470, 3600], [0.4, 0.3, 0.2, 0.15, 0.1]), 0.6)


# ---------------------------------------------------------------- Creatures
def crawler_chitter(seed=0):
    r = R(200 + seed)
    d = 0.5
    out = np.zeros(int(d * SR))
    t = 0.0
    while t < d - 0.02:
        click = bp(r.uniform(-1, 1, 120), 1500 + 600 * r.random(), 6000) * np.exp(-np.arange(120) / 18)
        place(out, click * r.uniform(0.4, 1.0), t)
        t += r.uniform(0.012, 0.04)
    return normalize(out, 0.55)


def crawler_screech(seed=0):
    d = 0.6
    n = int(d * SR)
    f = sweep(2400 + 300 * seed, 1500, d)
    v = osc_sine(f + 900 * osc_sine(f * 0.73, d), d) * env_adsr(n, 0.01, 0.1, 0.6, 0.2)
    return normalize(dist(v + 0.3 * hp(noise(d, rng=R(201)), 3000), 2.0) * 0.7, 0.6)


def crawler_death(seed=0):
    d = 0.7
    n = int(d * SR)
    sq = sweep_filter(noise(d, rng=R(202)), 2500, 300, "band") * env_exp(n, 0.2)
    scr = osc_sine(sweep(2000, 400, d) * (1 + 0.2 * osc_sine(30, d)), d) * env_exp(n, 0.25) * 0.5
    return normalize(sq + scr, 0.6)


def stalker_growl(seed=0):
    d = 1.3
    n = int(d * SR)
    r = R(210 + seed)
    src = osc_saw(sweep(75, 62, d) * (1 + 0.03 * lp(r.uniform(-1, 1, n), 20)), d) + 0.5 * noise(d, rng=r)
    v = formant(src, "o") * env_adsr(n, 0.15, 0.2, 0.8, 0.4)
    return normalize(dist(v, 2.5), 0.7)


def stalker_scream(seed=0):
    d = 1.5
    n = int(d * SR)
    f = sweep(420, 650, d) * (1 + 0.04 * osc_sine(9, d))
    src = osc_saw(f, d) + 0.6 * noise(d, rng=R(211))
    v = formant(src, "a") + 0.4 * osc_sine(f * 2.7 + 400 * osc_sine(f * 0.5, d), d)
    return normalize(reverb(dist(v * env_adsr(n, 0.05, 0.2, 0.8, 0.5), 3.0), decay=1.2, wet=0.3), 0.8)


def colossus_roar(seed=0):
    d = 2.4
    n = int(d * SR)
    r = R(220)
    src = osc_saw(sweep(48, 60, d) * (1 + 0.05 * lp(r.uniform(-1, 1, n), 15)), d) + 0.7 * brown(d, rng=r)
    v = formant(src, "a") * 1.5 + lp(src, 200)
    return normalize(reverb(dist(v * env_adsr(n, 0.2, 0.3, 0.8, 0.8), 4.0), decay=1.8, wet=0.3), 0.9)


def colossus_slam(seed=0):
    d = 1.4
    n = int(d * SR)
    boom = osc_sine(sweep(70, 22, d), d) * env_exp(n, 0.3) * 1.5
    debris = lp(noise(d, rng=R(221)), 3000) * env_exp(n, 0.15)
    return normalize(reverb(dist(boom + debris, 2.5), decay=1.2, wet=0.2), 0.95)


def mimic_voice(seed=0):
    """An almost-human plea: vowel glides with wrong, sliding pitch."""
    d = 1.8
    n = int(d * SR)
    r = R(230 + seed)
    t = np.arange(n) / SR
    f = 175 + 25 * np.sin(2 * np.pi * 0.6 * t + seed) + 40 * np.maximum(0, t - 1.2) * r.uniform(-1, 1)
    src = osc_saw(f * (1 + 0.012 * np.sin(2 * np.pi * 5.5 * t)), d) + 0.15 * noise(d, rng=r)
    seq = ["e", "a", "o", "u"] if seed % 2 == 0 else ["a", "i", "o", "o"]
    out = np.zeros(n)
    seg = n // len(seq)
    for i, vw in enumerate(seq):
        part = formant(src, vw)
        w = np.zeros(n)
        a, b = max(0, i * seg - seg // 3), min(n, (i + 1) * seg + seg // 3)
        w[a:b] = np.hanning(b - a)
        out += part * w
    out *= env_adsr(n, 0.1, 0.2, 0.8, 0.4)
    return normalize(reverb(out, decay=1.5, wet=0.45), 0.6)


def mimic_reveal(seed=0):
    d = 1.2
    n = int(d * SR)
    tear = sweep_filter(noise(d, rng=R(231)), 800, 4000, "band") * env_adsr(n, 0.01, 0.2, 0.4, 0.4)
    shriek = osc_sine(sweep(600, 2600, d) + 500 * osc_sine(sweep(300, 900, d), d), d) * env_adsr(n, 0.2, 0.2, 0.7, 0.3) * 0.6
    return normalize(reverb(dist(tear + shriek, 2.0), decay=1.0, wet=0.3), 0.85)


def burrower_rumble(seed=0):
    d = 2.5
    n = int(d * SR)
    t = np.arange(n) / SR
    rum = lp(brown(d, rng=R(240)), 160) * (0.6 + 0.4 * np.sin(2 * np.pi * 2.3 * t))
    grit = bp(noise(d, rng=R(241)), 300, 1200) * 0.15 * (R(242).uniform(0, 1, n) > 0.7)
    return normalize((rum + grit) * env_adsr(n, 0.4, 0.3, 0.8, 0.6), 0.8)


def burrower_emerge(seed=0):
    d = 1.5
    out = mix(dig(3) * 1.2, np.zeros(int(d * SR)))
    n = int(1.0 * SR)
    scr = osc_saw(sweep(300, 900, 1.0), 1.0) * env_adsr(n, 0.1, 0.2, 0.6, 0.3)
    place(out, formant(scr, "a") * 0.8, 0.25)
    return normalize(dist(out, 2.0), 0.85)


def abyssal_roar(seed=0):
    d = 3.5
    n = int(d * SR)
    t = np.arange(n) / SR
    f = 55 + 40 * np.sin(np.pi * t / d) ** 2
    src = osc_saw(f, d) + 0.3 * osc_sine(f * 4.1, d)
    v = lp(src, 900) * env_adsr(n, 0.5, 0.5, 0.8, 1.0)
    return normalize(reverb(v, decay=3.0, wet=0.5), 0.85)


def devourer_breath(seed=0):
    d = 3.2
    n = int(d * SR)
    t = np.arange(n) / SR
    cyc = np.sin(np.pi * t / d * 2) ** 2
    air = bp(noise(d, rng=R(250 + seed)), 250, 1800) * cyc
    gurgle = lp(noise(d, rng=R(251)), 120) * (np.sin(2 * np.pi * 13 * t) > 0.6) * cyc * 0.8
    low = osc_saw(52 + 6 * np.sin(2 * np.pi * 0.3 * t), d) * cyc * 0.15
    return normalize(reverb(air + gurgle + lp(low, 300), decay=1.0, wet=0.3), 0.6)


def devourer_scream(seed=0):
    d = 2.8
    n = int(d * SR)
    t = np.arange(n) / SR
    f = 310 + 140 * np.sin(np.pi * np.clip(t / 1.6, 0, 1)) + 25 * np.sin(2 * np.pi * 11 * t)
    human = formant(osc_saw(f, d) + 0.4 * noise(d, rng=R(252)), "a")
    alien = osc_sine(f * 3.3 + 700 * osc_sine(f * 0.51, d), d) * 0.5
    sub = osc_sine(sweep(60, 40, d), d) * 0.8
    v = (human * 1.2 + alien + sub) * env_adsr(n, 0.08, 0.3, 0.8, 1.0)
    return normalize(reverb(dist(v, 3.5), decay=2.5, wet=0.45), 0.95)


def devourer_step(seed=0):
    n = int(0.6 * SR)
    th = osc_sine(sweep(70, 30, 0.6), 0.6) * env_exp(n, 0.12)
    wet = sweep_filter(noise(0.6, rng=R(253 + seed)), 1500, 200, "band") * env_exp(n, 0.1) * 0.6
    return normalize(th + wet, 0.75)


def devourer_click(seed=0):
    r = R(254 + seed)
    d = 1.6
    out = np.zeros(int(d * SR))
    t = 0.0
    while t < d - 0.05:
        burst = r.integers(2, 6)
        for k in range(burst):
            click = resonator(r.uniform(-1, 1, 200) * np.exp(-np.arange(200) / 6), [700 + 300 * r.random(), 2100], [0.01, 0.006])
            place(out, click, t + k * 0.03)
        t += r.uniform(0.18, 0.45)
    return normalize(reverb(out, decay=0.9, wet=0.35), 0.6)


def devourer_vent(seed=0):
    r = R(255)
    d = 2.4
    n = int(d * SR)
    hits = np.zeros(n)
    for _ in range(45):
        i = r.integers(0, n - 300)
        hits[i:i + 200] += r.uniform(-1, 1, 200) * np.exp(-np.arange(200) / 20)
    duct = resonator(hits, [180, 410, 760, 1320], [0.12, 0.1, 0.08, 0.05])
    return normalize(lp(duct, 2500) * env_adsr(n, 0.3, 0.3, 0.8, 0.6), 0.6)


def dissolve(seed=0):
    d = 0.9
    n = int(d * SR)
    fizz = hp(noise(d, rng=R(260 + seed)), 2500) * env_exp(n, 0.35) * (R(261).uniform(0, 1, n) > 0.4)
    low = osc_sine(sweep(400, 80, d), d) * env_exp(n, 0.2) * 0.4
    return normalize(fizz + low, 0.55)


def boss_roar(seed=0):
    return normalize(mix(colossus_roar() * 0.8, stalker_scream() * 0.5, devourer_scream() * 0.3), 0.95)


# ---------------------------------------------------------------- World
def door_open(seed=0):
    d = 0.9
    n = int(d * SR)
    t = np.arange(n) / SR
    f = 380 + 120 * np.sin(2 * np.pi * 1.3 * t)
    squeak = bp(osc_saw(f * (1 + 0.02 * noise(d, rng=R(300))), d), 300, 3000) * env_adsr(n, 0.05, 0.2, 0.5, 0.3)
    latch = np.zeros(n)
    place(latch, metal_clang(1)[:int(0.2 * SR)] * 0.5, 0.0)
    return normalize(squeak * 0.4 + latch, 0.6)


def door_close(seed=0):
    out = mix(np.zeros(int(0.6 * SR)), hit_heavy(2) * 0.5)
    return normalize(out + mix(np.zeros(len(out)), metal_clang(2)[:len(out)] * 0.3), 0.7)


def door_slam(seed=0):
    out = mix(colossus_slam() * 0.7, metal_clang(3) * 0.5)
    return normalize(reverb(out, decay=1.4, wet=0.35), 0.95)


def metal_creak(seed=0):
    d = 1.8
    n = int(d * SR)
    t = np.arange(n) / SR
    f = 90 + 60 * np.sin(2 * np.pi * (0.4 + 0.1 * seed) * t) ** 2
    v = bp(osc_saw(f * (1 + 0.01 * noise(d, rng=R(301 + seed))), d), 200, 2500)
    return normalize(reverb(v * env_adsr(n, 0.3, 0.3, 0.7, 0.6), decay=1.5, wet=0.4), 0.45)


def distant_alarm(seed=0):
    d = 4.0
    n = int(d * SR)
    t = np.arange(n) / SR
    f = np.where((t % 1.0) < 0.5, 660, 520)
    v = lp(osc_square(f, d), 1200) * 0.4
    return normalize(reverb(lp(v, 900), decay=2.5, wet=0.6), 0.35)


def flicker(seed=0):
    d = 0.35
    n = int(d * SR)
    r = R(302 + seed)
    buzz = osc_saw(120, d) * (r.uniform(0, 1, n) > 0.5) * 0.4 + hp(noise(d, rng=r), 4000) * 0.2 * (r.uniform(0, 1, n) > 0.9)
    return normalize(lp(buzz, 5000) * env_adsr(n, 0.005, 0.05, 0.8, 0.05), 0.35)


def generator_start(seed=0):
    d = 2.2
    n = int(d * SR)
    f = sweep(18, 60, d)
    motor = lp(osc_saw(f, d) + 0.5 * osc_saw(f * 2, d), 900) * np.linspace(0.2, 1, n)
    clunk = np.zeros(n)
    place(clunk, hit_heavy(3) * 0.6, 0.0)
    return normalize(motor * 0.6 + clunk, 0.7)


def generator_hum(seed=0):
    d = 2.0
    out = lp(osc_saw(60, d) * 0.5 + osc_sine(120, d) * 0.4 + osc_sine(180, d) * 0.2, 700)
    return normalize(out, 0.4)


def drip(seed=0):
    d = 0.8
    n = int(0.12 * SR)
    p = osc_sine(sweep(1400 + 200 * seed, 700, 0.12), 0.12) * env_exp(n, 0.03)
    return normalize(reverb(mix(p, np.zeros(int(d * SR))), decay=1.2, wet=0.5), 0.35)


def wind_gust(seed=0):
    d = 3.5
    n = int(d * SR)
    t = np.arange(n) / SR
    w = sweep_filter(noise(d, rng=R(303 + seed)), 300, 900, "band", q_width=0.8)
    return normalize(w * np.sin(np.pi * t / d) ** 2, 0.5)


def branch_snap(seed=0):
    n = int(0.3 * SR)
    r = R(304 + seed)
    c = bp(r.uniform(-1, 1, n), 700, 5000) * env_exp(n, 0.02)
    return normalize(reverb(c, decay=0.8, wet=0.3), 0.6)


def whisper(seed=0):
    d = 2.2
    n = int(d * SR)
    r = R(305 + seed)
    nz = noise(d, rng=r)
    out = np.zeros(n)
    t = 0.0
    vows = ["i", "e", "a", "u"]
    k = 0
    while t < d - 0.25:
        ln = r.uniform(0.12, 0.3)
        seg = formant(nz[:int(ln * SR)], vows[k % 4]) * np.hanning(int(ln * SR))
        place(out, seg, t)
        t += ln + r.uniform(0.03, 0.15)
        k += 1
    return normalize(reverb(hp(out, 600), decay=1.6, wet=0.5), 0.4)


def distant_scream(seed=0):
    s = stalker_scream(seed)
    return normalize(reverb(lp(s, 1500), decay=3.0, wet=0.7), 0.4)


def pickup(seed=0):
    out = np.zeros(int(0.45 * SR))
    for i, m in enumerate((79, 84, 88)):
        n = int(0.25 * SR)
        place(out, osc_sine(midi(m), 0.25) * env_exp(n, 0.08), i * 0.05)
    return normalize(out, 0.45)


def chest_open(seed=0):
    return normalize(mix(door_open()[:int(0.6 * SR)] * 0.5, pickup() * 0.6), 0.6)


def dig(seed=0):
    r = R(310 + seed)
    d = 0.6
    n = int(d * SR)
    thud = osc_sine(sweep(110, 45, d), d) * env_exp(n, 0.06)
    crack = bp(noise(d, rng=r), 500, 4500) * env_exp(n, 0.04)
    gravel = np.zeros(n)
    for _ in range(35):
        i = r.integers(int(0.03 * SR), n - 150)
        gravel[i:i + 100] += r.uniform(-1, 1, 100) * np.exp(-np.arange(100) / 15) * np.exp(-i / SR / 0.25)
    return normalize(thud + crack * 0.8 + bp(gravel, 1000, 6000) * 0.6, 0.75)


def build_place(seed=0):
    out = mix(hit_heavy(4) * 0.5, np.zeros(int(0.5 * SR)))
    r = R(320)
    for k in range(4):
        place(out, metal_clang(k)[:int(0.08 * SR)] * 0.25, 0.12 + k * 0.06)
    return normalize(out, 0.7)


def build_complete(seed=0):
    return normalize(mix(build_place() * 0.6, np.concatenate([np.zeros(int(0.3 * SR)), ui_reward()])), 0.7)


def alarm_base(seed=0):
    d = 2.0
    n = int(d * SR)
    t = np.arange(n) / SR
    f = 700 + 250 * np.abs(np.sin(2 * np.pi * 1.0 * t))
    v = lp(osc_square(f, d), 2500) * (np.sin(2 * np.pi * 4 * t) > -0.2)
    return normalize(v, 0.55)


def turret_fire(seed=0):
    n = int(0.25 * SR)
    z = osc_square(sweep(1800, 300, 0.25), 0.25) * env_exp(n, 0.04)
    return normalize(mix(lp(z, 5000), hit_flesh(5)[:n] * 0.3), 0.55)


def flare_ignite(seed=0):
    d = 1.2
    n = int(d * SR)
    hiss = hp(noise(d, rng=R(330)), 2000) * env_adsr(n, 0.01, 0.15, 0.5, 0.5)
    pop = np.zeros(n)
    place(pop, osc_sine(sweep(400, 100, 0.1), 0.1) * env_exp(int(0.1 * SR), 0.02), 0.0)
    return normalize(hiss + pop, 0.6)


def flare_loop(seed=0):
    d = 2.0
    r = R(331)
    n = int(d * SR)
    hiss = hp(noise(d, rng=r), 2500) * 0.3 * (0.8 + 0.2 * r.uniform(0, 1, n))
    return normalize(hiss, 0.3)


def decoy_beep(seed=0):
    out = np.zeros(int(1.0 * SR))
    for k in range(3):
        n = int(0.12 * SR)
        place(out, osc_square(1100, 0.12) * env_adsr(n, 0.005, 0.02, 0.8, 0.02), k * 0.3)
    return normalize(lp(out, 4000), 0.5)


def splash(seed=0):
    d = 0.8
    n = int(d * SR)
    return normalize(sweep_filter(noise(d, rng=R(340 + seed)), 4000, 400, "band") * env_exp(n, 0.2), 0.6)


def crystal_chime(seed=0):
    n = int(1.4 * SR)
    exc = noise(1.4, rng=R(350 + seed)) * env_exp(n, 0.002)
    base = 1500 + 200 * seed
    return normalize(reverb(resonator(exc, [base, base * 2.76, base * 5.4], [0.5, 0.35, 0.2]), decay=1.5, wet=0.4), 0.45)


def jumpscare(seed=0):
    d = 1.8
    n = int(d * SR)
    out = np.zeros(n)
    for m in (49, 50, 55, 56, 61):
        out += lp(osc_saw(midi(m) * (1 + 0.01 * osc_sine(7, d)), d), 2500) * 0.3
    hit = noise(d, rng=R(360 + seed)) * env_exp(n, 0.08)
    sub = osc_sine(sweep(60, 30, d), d)
    v = (out + hit + sub) * env_adsr(n, 0.003, 0.2, 0.6, 1.0)
    return normalize(reverb(dist(v, 2.0), decay=1.5, wet=0.3), 0.98)


def discovery(seed=0):
    d = 3.0
    n = int(d * SR)
    out = np.zeros(n)
    for m in (62, 65, 69, 76):
        out += osc_sine(midi(m), d) * 0.3
    sh = hp(noise(d, rng=R(361)), 6000) * 0.1
    return normalize(reverb((out + sh) * env_adsr(n, 1.0, 0.5, 0.6, 1.2), decay=2.5, wet=0.5), 0.5)


def heal(seed=0):
    return regen(seed)


def capture(seed=0):
    out = mix(portal() * 0.6, np.zeros(int(1.5 * SR)))
    place(out, shield_hit() * 0.7, 1.0)
    return normalize(out, 0.7)


SFX = {
    "ui_click": (ui_click, 1), "ui_back": (ui_back, 1), "ui_confirm": (ui_confirm, 1), "ui_error": (ui_error, 1),
    "ui_reward": (ui_reward, 1), "levelup": (levelup, 1), "logo_sting": (logo_sting, 1), "toast": (toast, 1),
    "step_concrete": (step_concrete, 4), "step_dirt": (step_dirt, 3), "step_metal": (step_metal, 3), "step_wet": (step_wet, 3),
    "swing": (swing, 3), "hit_flesh": (hit_flesh, 3), "hit_heavy": (hit_heavy, 2), "dodge": (dodge, 1), "land": (land, 1),
    "player_hurt": (player_hurt, 2), "player_death": (player_death, 1), "heartbeat": (heartbeat, 1), "breath": (breath, 1),
    "energy_bolt": (energy_bolt, 2), "energy_impact": (energy_impact, 1), "shockwave": (shockwave, 1), "shield_up": (shield_up, 1),
    "shield_hit": (shield_hit, 1), "fire_cast": (fire_cast, 2), "explosion": (explosion, 2), "teleport": (teleport, 1),
    "shadow_blades": (shadow_blades, 1), "invis": (invis, 1), "dash": (dash, 2), "portal": (portal, 1), "electric": (electric, 2),
    "roots": (roots, 1), "regen": (regen, 1), "ult_cast": (ult_cast, 1), "meteor": (meteor, 1), "singularity": (singularity, 1),
    "transform": (transform, 1), "metal_clang": (metal_clang, 2),
    "crawler_chitter": (crawler_chitter, 3), "crawler_screech": (crawler_screech, 2), "crawler_death": (crawler_death, 1),
    "stalker_growl": (stalker_growl, 2), "stalker_scream": (stalker_scream, 1), "colossus_roar": (colossus_roar, 1),
    "colossus_slam": (colossus_slam, 1), "mimic_voice": (mimic_voice, 2), "mimic_reveal": (mimic_reveal, 1),
    "burrower_rumble": (burrower_rumble, 1), "burrower_emerge": (burrower_emerge, 1), "abyssal_roar": (abyssal_roar, 1),
    "devourer_breath": (devourer_breath, 2), "devourer_scream": (devourer_scream, 1), "devourer_step": (devourer_step, 2),
    "devourer_click": (devourer_click, 2), "devourer_vent": (devourer_vent, 1), "dissolve": (dissolve, 2), "boss_roar": (boss_roar, 1),
    "door_open": (door_open, 1), "door_close": (door_close, 1), "door_slam": (door_slam, 1), "metal_creak": (metal_creak, 3),
    "distant_alarm": (distant_alarm, 1), "flicker": (flicker, 2), "generator_start": (generator_start, 1),
    "generator_hum": (generator_hum, 1), "drip": (drip, 3), "wind_gust": (wind_gust, 2), "branch_snap": (branch_snap, 2),
    "whisper": (whisper, 3), "distant_scream": (distant_scream, 2), "pickup": (pickup, 1), "chest_open": (chest_open, 1),
    "dig": (dig, 3), "build_place": (build_place, 1), "build_complete": (build_complete, 1), "alarm_base": (alarm_base, 1),
    "turret_fire": (turret_fire, 1), "flare_ignite": (flare_ignite, 1), "flare_loop": (flare_loop, 1), "decoy_beep": (decoy_beep, 1),
    "splash": (splash, 2), "crystal_chime": (crystal_chime, 3), "jumpscare": (jumpscare, 2), "discovery": (discovery, 1),
    "heal": (heal, 1), "capture": (capture, 1),
}
LOOPING = {"generator_hum", "flare_loop", "breath", "devourer_breath", "heartbeat"}
