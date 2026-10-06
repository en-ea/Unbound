#!/usr/bin/env bash
# Look boards in a cloud VM. Each shot is a windowed render on a virtual display (Xvfb) with Mesa's software OpenGL
# (llvmpipe) at a fixed 30 frames a second, so frame-driven boards reach the same moments as on the laptop. Then
# tools-src/studio/lookboard/sheet.gd lays the shots out. This is the Linux counterpart of the studio toolbox's
# capture_hidden.sh (a Windows hidden desktop). Frame times here mean nothing, and software lighting can differ a
# little from a GPU, so judge cloud boards against cloud boards.
#
# Usage: look.sh <out_dir> <shots.txt> [WxH]
#   shots.txt: one shot per line, "<name> <args...>" (# comments; <name> is "<row>-<column>" for the sheet).
#   The project is this repository's game/ and must accept --shot=<png path> (save a frame and quit).
#   LOOK_TIMEOUT: seconds a shot may take (default 300; software rendering is slow). GODOT: the engine.
# Prints "ok <name>", "FAIL <name> (see <name>.log)" or "BLANK <name>" per shot (a PNG under 20 kB drew nothing),
# then the sheet's line. Exit: 0 when every shot is ok, else 1. Evidence is never overwritten or deleted.
set -u
root=$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)
GODOT=${GODOT:-$HOME/godot/Godot_v4.7.2-stable_linux.x86_64}
out=$1 list=$2 res=${3:-1560x720}
w=${res%x*} h=${res#*x}
[ -x "$GODOT" ] || { echo "REFUSE no engine at $GODOT (run tools-src/studio/cloud/setup.sh)"; exit 3; }
command -v xvfb-run >/dev/null 2>&1 || { echo "REFUSE no xvfb-run (run tools-src/studio/cloud/setup.sh)"; exit 3; }
mkdir -p "$out"
out=$(cd "$out" && pwd)   # Godot changes its working directory to the project; evidence paths must be absolute.
names=""
status=0
while read -r name args; do
	name=${name%$'\r'}; args=${args%$'\r'}
	case "$name" in ""|\#*) continue ;; esac
	if [ -e "$out/$name.png" ] || [ -e "$out/$name.log" ]; then
		echo "REFUSE $name (existing evidence; choose a fresh output directory)"
		exit 1
	fi
	names="$names$name x"$'\n'
	# shellcheck disable=SC2086
	LIBGL_ALWAYS_SOFTWARE=1 timeout "${LOOK_TIMEOUT:-300}" xvfb-run -a -s "-screen 0 ${w}x${h}x24" \
		"$GODOT" --rendering-driver opengl3 --fixed-fps 30 --path "$root/game" --resolution "$res" \
		-- $args --shot="$out/$name.png" > "$out/$name.log" 2>&1
	if [ ! -f "$out/$name.png" ]; then
		echo "FAIL $name (see $name.log)"; status=1
	elif [ "$(stat -c %s "$out/$name.png")" -lt 20000 ]; then
		echo "BLANK $name ($(stat -c %s "$out/$name.png") bytes)"; status=1
	else
		echo "ok   $name"
	fi
done < "$list"
printf '%s' "$names" > "$out/sheet-shots.txt"
"$GODOT" --headless --path "$root/game" --script "$root/tools-src/studio/lookboard/sheet.gd" -- "$out" "$out/sheet-shots.txt" 2>&1 \
	| grep -v "^Godot Engine" | tail -n 3
exit $status
