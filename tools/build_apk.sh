#!/bin/bash
# Reproducible APK build: imports the project, exports with Godot's prebuilt Android
# template, signs (v1 + v2) through tools/apksigner, then verifies signature and alignment.
#   tools/build_apk.sh            -> dist/SymbioteAbyss-<version>.apk (debug-signed, installable)
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT=/opt/godot/Godot_v4.5.1-stable_linux.x86_64
export ANDROID_HOME=/opt/android-sdk-lite
export GODOT_ANDROID_KEYSTORE_DEBUG_PATH=${GODOT_ANDROID_KEYSTORE_DEBUG_PATH:-$HOME/.android/debug.keystore}
export GODOT_ANDROID_KEYSTORE_DEBUG_USER=${GODOT_ANDROID_KEYSTORE_DEBUG_USER:-androiddebugkey}
export GODOT_ANDROID_KEYSTORE_DEBUG_PASSWORD=${GODOT_ANDROID_KEYSTORE_DEBUG_PASSWORD:-android}
VERSION=$(grep -oP 'config/version="\K[^"]+' "$ROOT/game/project.godot")
OUT="$ROOT/dist/SymbioteAbyss-$VERSION.apk"
mkdir -p "$ROOT/dist"
rm -f "$OUT"
cd "$ROOT/game"
timeout 600 $GODOT --headless --path . --import >/dev/null 2>&1 || true
timeout 900 $GODOT --headless --path . --export-debug Android "$OUT" 2>&1 | grep -E "ERROR|WARNING|Signed|DONE" | grep -v "first_scan" || true
[ -f "$OUT" ] || { echo "Export failed"; exit 1; }
"$ANDROID_HOME/build-tools/35.0.0/apksigner" verify "$OUT"
python3 - "$OUT" <<'PY'
import struct, sys, zipfile
z = zipfile.ZipFile(sys.argv[1]); f = open(sys.argv[1], 'rb'); bad = 0
for i in z.infolist():
    if i.compress_type == 0:
        f.seek(i.header_offset); h = f.read(30); n, e = struct.unpack('<HH', h[26:30])
        if (i.header_offset + 30 + n + e) % (4096 if i.filename.endswith('.so') else 4): bad += 1
assert z.testzip() is None, "corrupt zip"
assert any(n.startswith('META-INF/') and n.endswith('.SF') for n in z.namelist()), "missing v1 signature"
assert bad == 0, f"{bad} misaligned entries"
print("zip ok, aligned, v1 present, pck:", [n for n in z.namelist() if n.endswith('.pck') or 'assets' in n][:3])
PY
ls -la "$OUT"
