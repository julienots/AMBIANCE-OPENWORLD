#!/bin/bash
# Render a model sheet: tools/view_model.sh res://assets/models/x.glb out.png [anims] [times] [symb]
cd "$(dirname "$0")/../game"
timeout 300 /opt/godot/Godot_v4.5.1-stable_linux.x86_64 --headless --path . --import >/dev/null 2>&1
ARGS="model=$1 out=$2"
[ -n "$3" ] && ARGS="$ARGS anims=$3"
[ -n "$4" ] && ARGS="$ARGS times=$4"
[ -n "$5" ] && ARGS="$ARGS symb=$5"
timeout 120 xvfb-run -a -s "-screen 0 1600x900x24" /opt/godot/Godot_v4.5.1-stable_linux.x86_64 --path . --rendering-driver opengl3 --audio-driver Dummy res://src/tests/model_viewer.tscn -- $ARGS 2>&1 | grep -E "SCRIPT ERROR|ERROR|saved" | grep -v "ALSA" | head -20
