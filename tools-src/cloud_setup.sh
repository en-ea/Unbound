#!/usr/bin/env bash
# Cloud (Linux) sessions only: installs Godot 4.7.2 and its Web export templates, so the game can be
# checked, screenshotted and exported without the Windows tools. Safe to run again.
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
echo "Godot ready: $G"
