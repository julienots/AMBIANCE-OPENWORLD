#!/bin/bash
# Runs an automated play-test: tools/play_test.sh <region> [script] [outdir]
cd "$(dirname "$0")/../game"
OUT=${3:-res://../build/screens/play_$1}
timeout 300 /opt/godot/Godot_v4.5.1-stable_linux.x86_64 --headless --path . --import >/dev/null 2>&1
timeout ${TEST_TIMEOUT:-400} xvfb-run -a -s "-screen 0 1280x720x24" /opt/godot/Godot_v4.5.1-stable_linux.x86_64 --path . \
  --rendering-driver opengl3 --audio-driver Dummy res://src/tests/play_test.tscn -- region=$1 script=${2:-basic} out=$OUT 2>&1 \
  | grep -vE "ALSA|set_use_vsync|_load_from_cache|shader_gles3|gl_manager_x11|^\s*$"
