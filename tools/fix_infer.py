"""Iteratively fixes 'Cannot infer the type' errors by turning `:=` into `=` on the reported line."""
import re, subprocess, sys
G = "/opt/godot/Godot_v4.5.1-stable_linux.x86_64"
ROOT = "/home/user/AMBIANCE-OPENWORLD/game"
pat = re.compile(r'Cannot infer the type of "(\w+)".*?\n\s*at: GDScript::reload \(res://([^:]+):(\d+)\)', re.S)
files = subprocess.run(["find", "src", "-name", "*.gd"], cwd=ROOT, capture_output=True, text=True).stdout.split()
for f in files:
    for it in range(60):
        r = subprocess.run([G, "--headless", "--path", ROOT, "--check-only", "--script", "res://" + f], capture_output=True, text=True, timeout=120)
        out = r.stdout + r.stderr
        m = pat.search(out)
        if not m:
            break
        var, path, line = m.group(1), m.group(2), int(m.group(3))
        p = ROOT + "/" + path
        lines = open(p).read().split("\n")
        l = lines[line - 1]
        new = re.sub(r"(\b(?:var|const)\s+" + var + r")\s*:=", r"\1 =", l, count=1)
        if new == l:
            new = re.sub(r"\bfor\s+" + var, "for " + var, l)
            print("could not fix", path, line, l); break
        lines[line - 1] = new
        open(p, "w").write("\n".join(lines))
        print("fixed", path, line, var)
