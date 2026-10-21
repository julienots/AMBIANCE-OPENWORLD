#!/bin/bash
# Parses every GDScript of the project and prints errors with file:line.
cd "$(dirname "$0")/../game"
timeout 300 /opt/godot/Godot_v4.5.1-stable_linux.x86_64 --headless --path . --import >/dev/null 2>&1
for f in $(find src -name "*.gd"); do
  out=$(timeout 60 /opt/godot/Godot_v4.5.1-stable_linux.x86_64 --headless --path . --check-only --script "res://$f" 2>&1 | grep -E "SCRIPT ERROR|Parse Error|at: GDScript" | grep -v "Failed to compile depended" | head -6)
  if [ -n "$out" ]; then echo "== $f"; echo "$out"; fi
done
