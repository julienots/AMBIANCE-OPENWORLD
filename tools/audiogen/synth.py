"""Tiny synthesis toolkit (numpy/scipy) used to generate every sound of the game."""
import os
import subprocess
import wave

import numpy as np
from scipy import signal

SR = 22050


def T(dur, sr=SR):
    return np.arange(int(dur * sr)) / sr


def osc_sine(freq, dur=None, sr=SR, phase=0.0):
    f = np.full(int(dur * sr), freq, dtype=np.float64) if np.isscalar(freq) else np.asarray(freq, dtype=np.float64)
    return np.sin(2 * np.pi * np.cumsum(f) / sr + phase)


def osc_saw(freq, dur=None, sr=SR):
    f = np.full(int(dur * sr), freq, dtype=np.float64) if np.isscalar(freq) else np.asarray(freq, dtype=np.float64)
    ph = np.cumsum(f) / sr
    return 2.0 * (ph - np.floor(ph + 0.5))


def osc_square(freq, dur=None, sr=SR, duty=0.5):
    f = np.full(int(dur * sr), freq, dtype=np.float64) if np.isscalar(freq) else np.asarray(freq, dtype=np.float64)
    ph = np.cumsum(f) / sr
    return np.where((ph % 1.0) < duty, 1.0, -1.0)


def osc_tri(freq, dur=None, sr=SR):
    return 2 * np.abs(osc_saw(freq, dur, sr)) - 1


def noise(dur, sr=SR, rng=None):
    rng = rng or np.random.default_rng()
    return rng.uniform(-1, 1, int(dur * sr))


def pink(dur, sr=SR, rng=None):
    w = noise(dur, sr, rng)
    b, a = [0.049922035, -0.095993537, 0.050612699, -0.004408786], [1, -2.494956002, 2.017265875, -0.522189400]
    return normalize(signal.lfilter(b, a, w), 1.0)


def brown(dur, sr=SR, rng=None):
    w = np.cumsum(noise(dur, sr, rng))
    w = signal.lfilter([1, -1], [1, -0.995], w)
    return normalize(w, 1.0)


def sweep(f0, f1, dur, sr=SR, curve="exp"):
    n = int(dur * sr)
    if curve == "exp":
        return f0 * (f1 / f0) ** np.linspace(0, 1, n)
    return np.linspace(f0, f1, n)


def env_adsr(n, a=0.01, d=0.1, s=0.7, r=0.2, sr=SR):
    a_n, d_n, r_n = int(a * sr), int(d * sr), int(r * sr)
    s_n = max(0, n - a_n - d_n - r_n)
    e = np.concatenate([np.linspace(0, 1, max(a_n, 1)), np.linspace(1, s, max(d_n, 1)), np.full(s_n, s), np.linspace(s, 0, max(r_n, 1))])
    return pad_to(e, n)


def env_exp(n, decay, sr=SR, attack=0.002):
    t = np.arange(n) / sr
    e = np.exp(-t / max(decay, 1e-4))
    a_n = int(attack * sr)
    if a_n > 0:
        e[:a_n] *= np.linspace(0, 1, a_n)
    return e


def pad_to(x, n):
    if len(x) >= n:
        return x[:n]
    return np.concatenate([x, np.zeros(n - len(x))])


def mix(*parts):
    n = max(len(p) for p in parts)
    out = np.zeros(n)
    for p in parts:
        out[:len(p)] += p
    return out


def place(buf, x, at, sr=SR):
    i = int(at * sr)
    if i >= len(buf):
        return buf
    end = min(len(buf), i + len(x))
    buf[i:end] += x[:end - i]
    return buf


def lp(x, fc, sr=SR, order=2):
    fc = min(fc, sr / 2 * 0.98)
    sos = signal.butter(order, fc, "low", fs=sr, output="sos")
    return signal.sosfilt(sos, x)


def hp(x, fc, sr=SR, order=2):
    sos = signal.butter(order, fc, "high", fs=sr, output="sos")
    return signal.sosfilt(sos, x)


def bp(x, lo, hi, sr=SR, order=2):
    hi = min(hi, sr / 2 * 0.98)
    sos = signal.butter(order, [lo, hi], "band", fs=sr, output="sos")
    return signal.sosfilt(sos, x)


def sweep_filter(x, f0, f1, kind="low", sr=SR, chunk=256, q_width=0.6):
    """Time-varying filter by processing short chunks with interpolated cutoffs (keeps filter state)."""
    out = np.zeros_like(x)
    n = len(x)
    cuts = f0 * (f1 / f0) ** np.linspace(0, 1, max(1, n // chunk + 1))
    zi = None
    for k, i in enumerate(range(0, n, chunk)):
        fc = min(cuts[k], sr / 2 * 0.95)
        if kind == "low":
            sos = signal.butter(2, fc, "low", fs=sr, output="sos")
        elif kind == "high":
            sos = signal.butter(2, fc, "high", fs=sr, output="sos")
        else:
            lo, hi = fc * (1 - q_width / 2), min(fc * (1 + q_width / 2), sr / 2 * 0.95)
            sos = signal.butter(2, [max(lo, 20), hi], "band", fs=sr, output="sos")
        if zi is None:
            zi = signal.sosfilt_zi(sos) * 0
        seg, zi = signal.sosfilt(sos, x[i:i + chunk], zi=zi)
        out[i:i + chunk] = seg
    return out


def resonator(x, freqs, decays, sr=SR):
    """Bank of decaying resonances excited by x (metallic / glassy bodies)."""
    out = np.zeros_like(x)
    for f, d in zip(freqs, decays):
        r = np.exp(-1.0 / (d * sr))
        w = 2 * np.pi * f / sr
        b = [1 - r]
        a = [1, -2 * r * np.cos(w), r * r]
        out += signal.lfilter(b, a, x)
    return out


def formant(x, vowel="a", sr=SR):
    table = {"a": [(800, 80), (1150, 90), (2900, 120)], "o": [(450, 70), (800, 80), (2830, 100)],
             "u": [(325, 50), (700, 60), (2530, 170)], "e": [(400, 60), (1600, 80), (2700, 120)],
             "i": [(300, 50), (2200, 100), (3000, 120)]}
    out = np.zeros_like(x)
    for f, bw in table[vowel]:
        out += bp(x, f - bw, f + bw, sr) * (1.0 if f < 1000 else 0.6)
    return out


def reverb(x, sr=SR, decay=1.5, wet=0.3, predelay=0.02, damp=4000, seed=3):
    rng = np.random.default_rng(seed)
    n = int(decay * sr)
    ir = rng.uniform(-1, 1, n) * np.exp(-np.arange(n) / sr * (6.9 / decay))
    ir = lp(ir, damp, sr)
    ir = np.concatenate([np.zeros(int(predelay * sr)), ir])
    ir /= np.sqrt(np.sum(ir ** 2)) + 1e-9
    wet_sig = signal.fftconvolve(x, ir)[:len(x) + n]
    dry = pad_to(x, len(wet_sig))
    return dry * (1 - wet) + wet_sig * wet


def dist(x, drive=3.0):
    return np.tanh(x * drive) / np.tanh(drive)


def normalize(x, peak=0.85):
    m = np.max(np.abs(x)) + 1e-9
    return x / m * peak


def fade(x, fin=0.005, fout=0.02, sr=SR):
    x = x.copy()
    a, b = int(fin * sr), int(fout * sr)
    if a > 0:
        x[:a] *= np.linspace(0, 1, a)
    if b > 0:
        x[-b:] *= np.linspace(1, 0, b)
    return x


def loopify(x, xfade=0.5, sr=SR):
    """Crossfade the tail into the head so the clip loops seamlessly."""
    n = int(xfade * sr)
    if x.ndim == 1:
        head, tail = x[:n], x[-n:]
        w = np.linspace(0, 1, n)
        body = x[n:-n] if len(x) > 2 * n else x[n:]
        return np.concatenate([tail * (1 - w) + head * w, body])
    return np.stack([loopify(x[:, c], xfade, sr) for c in range(x.shape[1])], axis=1)


def write_wav(path, x, sr=SR):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    x = np.clip(x, -1, 1)
    data = (x * 32767).astype(np.int16)
    ch = 1 if data.ndim == 1 else data.shape[1]
    with wave.open(path, "wb") as w:
        w.setnchannels(ch)
        w.setsampwidth(2)
        w.setframerate(sr)
        w.writeframes(data.tobytes())


def write_ogg(path, x, sr=SR, quality=3):
    tmp = path + ".tmp.wav"
    write_wav(tmp, x, sr)
    subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-i", tmp, "-c:a", "libvorbis", "-q:a", str(quality), path], check=True)
    os.remove(tmp)


def midi(n):
    return 440.0 * 2 ** ((n - 69) / 12)
