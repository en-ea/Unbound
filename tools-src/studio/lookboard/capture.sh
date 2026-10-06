#!/usr/bin/env bash
# Look board capture: one windowed render per line of a shot list, using the project's own screenshot
# dev argument; then sheet.gd turns them into JPEGs and a contact sheet (Godot does the image work, so
# no Python imaging library is needed).
# Usage: capture.sh <godot_project_dir> <out_dir> <shots.txt> [WxH]
#   shots.txt: one shot per line: <name> <renderer: gl_compatibility | mobile> <dev args...>  (# comments)
#   The project must accept a dev argument --shot=<png path> that saves a frame and quits.
set -u
GODOT="${LAB_GODOT:-C:/Users/hilmi/AppData/Local/UnboundStudio/tools/godot/Godot_v4.7.2-stable_win64_console.exe}"
proj=$1 out=$2 list=$3 res=${4:-1560x720}
mkdir -p "$out"
while read -r name renderer args; do
  case "$name" in ""|\#*) continue ;; esac
  rm -f "$out/$name.png"
  timeout 120 "$GODOT" --path "$proj" --rendering-method "$renderer" --resolution "$res" -- $args --shot="$out/$name.png" \
    > "$out/$name.log" 2>&1 < /dev/null
  if [ -f "$out/$name.png" ]; then echo "ok   $name"; rm -f "$out/$name.log"; else echo "FAIL $name (see $name.log)"; fi
done < "$list"
# Godot runs from the project folder, so every path it gets is absolute
abs() { echo "$(cd "$(dirname "$1")" && (pwd -W 2>/dev/null || pwd))/$(basename "$1")"; }
"$GODOT" --headless --path "$proj" --script "$(abs "${BASH_SOURCE[0]}" | sed 's/capture\.sh$/sheet.gd/')" -- "$(abs "$out/x" | sed 's|/x$||')" "$(abs "$list")" 2>&1 | grep -v "^Godot Engine"
