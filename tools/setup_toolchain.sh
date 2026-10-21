#!/bin/bash
# Reproducible toolchain for SYMBIOTE: ABYSS (Linux x86_64).
# Installs Godot 4.5.1 + export templates, Blender (bpy) for asset generation,
# and a minimal Android signing kit (no Google SDK download required).
set -euo pipefail
GODOT_VER=4.5.1-stable
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
mkdir -p /opt/godot
if [ ! -x /opt/godot/Godot_v${GODOT_VER}_linux.x86_64 ]; then
  curl -sSL -o /opt/godot/godot.zip https://github.com/godotengine/godot/releases/download/${GODOT_VER}/Godot_v${GODOT_VER}_linux.x86_64.zip
  unzip -o -q /opt/godot/godot.zip -d /opt/godot
fi
TPL=~/.local/share/godot/export_templates/${GODOT_VER/-/.}
if [ ! -f "$TPL/android_release.apk" ]; then
  curl -sSL -o /opt/godot/templates.tpz https://github.com/godotengine/godot/releases/download/${GODOT_VER}/Godot_v${GODOT_VER}_export_templates.tpz
  mkdir -p ~/.local/share/godot/export_templates && cd ~/.local/share/godot/export_templates
  unzip -o -q /opt/godot/templates.tpz && rm -rf "${GODOT_VER/-/.}" && mv templates "${GODOT_VER/-/.}"
fi
# Blender as a Python module (asset generation only)
if [ ! -x /opt/bpyenv/bin/python ]; then
  uv venv -p 3.11 /opt/bpyenv && uv pip install --python /opt/bpyenv/bin/python bpy
fi
# Android signing kit: apksig from Maven Central + our apksigner shim
SDK=/opt/android-sdk-lite
mkdir -p $SDK/build-tools/35.0.0/lib $SDK/platform-tools $SDK/cmdline-tools/latest/bin $SDK/platforms/android-35
curl -sSL -o $SDK/build-tools/35.0.0/lib/apksig.jar https://repo1.maven.org/maven2/com/android/tools/build/apksig/2.3.0/apksig-2.3.0.jar
javac -cp $SDK/build-tools/35.0.0/lib/apksig.jar -d $SDK/build-tools/35.0.0/lib "$ROOT/tools/apksigner/ApkSignerShim.java"
cp "$ROOT/tools/apksigner/apksigner.sh" $SDK/build-tools/35.0.0/apksigner
chmod +x $SDK/build-tools/35.0.0/apksigner
printf '#!/bin/sh\necho "adb not available"\n' > $SDK/platform-tools/adb; chmod +x $SDK/platform-tools/adb
cp $SDK/platform-tools/adb $SDK/cmdline-tools/latest/bin/sdkmanager
mkdir -p ~/.android
[ -f ~/.android/debug.keystore ] || keytool -genkeypair -keystore ~/.android/debug.keystore -storepass android \
  -alias androiddebugkey -keypass android -keyalg RSA -keysize 2048 -validity 10000 -dname "CN=Android Debug,O=Android,C=US"
echo "Toolchain ready."
