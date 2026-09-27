#!/usr/bin/env bash
# Cloud (Linux) sessions only: installs Godot 4.7.2 with its Web export templates, and Blender 4.5 as the
# `bpy` Python module (blender.org is blocked there; PyPI is not), so the game can be checked,
# screenshotted, exported and its models rebuilt without the Windows tools. Safe to run again.
set -e
G=~/godot/Godot_v4.7.2-stable_linux.x86_64
T=~/.local/share/godot/export_templates/4.7.2.stable
URL=https://github.com/godotengine/godot-builds/releases/download/4.7.2-stable
mkdir -p ~/godot "$T"
if [ ! -x "$G" ]; then
	curl -sSL -o ~/godot/godot.zip "$URL/Godot_v4.7.2-stable_linux.x86_64.zip"
	unzip -oq ~/godot/godot.zip -d ~/godot && rm ~/godot/godot.zip
fi
if [ ! -f "$T/web_nothreads_release.zip" ]; then
	curl -sSL -o ~/godot/tpl.tpz "$URL/Godot_v4.7.2-stable_export_templates.tpz"
	unzip -ojq ~/godot/tpl.tpz 'templates/web*' 'templates/version.txt' -d "$T" && rm ~/godot/tpl.tpz
fi
if [ ! -x ~/blender-venv/bin/python ]; then
	python3.11 -m venv ~/blender-venv
	~/blender-venv/bin/pip install -q bpy==4.5.14
fi
echo "Godot ready: $G"
echo "Blender ready: ~/blender-venv/bin/python tools-src/blender/<script>.py"
