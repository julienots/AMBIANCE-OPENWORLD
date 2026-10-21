"""Generate every sound of the game into game/assets/audio. Usage: python make_audio.py [sfx|music]"""
import os
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import music  # noqa: E402
import sfx  # noqa: E402
import synth  # noqa: E402

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "game", "assets", "audio")


def main():
    what = sys.argv[1:] or ["sfx", "music"]
    t0 = time.time()
    if "sfx" in what:
        for name, (fn, variants) in sfx.SFX.items():
            for v in range(variants):
                x = fn(v)
                x = synth.fade(x, 0.002, 0.01) if name not in sfx.LOOPING else synth.loopify(x, 0.15)
                fname = f"{name}_{v + 1}.wav" if variants > 1 else f"{name}.wav"
                synth.write_wav(os.path.join(OUT, "sfx", fname), x)
        print(f"[audiogen] sfx done {time.time() - t0:.1f}s", flush=True)
    if "music" in what:
        for name, fn in {**music.TRACKS, **music.AMBIENCES}.items():
            x = fn()
            sub = "music" if name in music.TRACKS else "ambience"
            synth.write_ogg(os.path.join(OUT, sub, name + ".ogg"), x, music.MSR, quality=3)
            print(f"[audiogen] {sub}/{name}.ogg {len(x) / music.MSR:.1f}s", flush=True)
    print(f"[audiogen] total {time.time() - t0:.1f}s")


if __name__ == "__main__":
    main()
