#!/usr/bin/env bash
# Graphics S2 (studio plan GRAPHICS-STAGES-2026-10-04.md): characters drawn merged, proved against Enea's own parts.
# Changes no game file; evidence only.
#   1. character_merge_check.gd with the switch off (the scene starts as today; the check merges its subjects itself):
#      the default look, five random looks, Wren, Morrow, Brakk and Moss-Cap; idle and mid-swing; a live look change;
#      the flash; surfaces, other meshes and skinned vertices per subject; draws per subject both ways.
#   2. the parity tool on its captures: merged against unmerged, judged against unmerged against unmerged again.
#   3. the draw probe (graphics S0) in the real scene with --studio-merge=off and =on: the whole frame's draws, with
#      the characters by group. Off must equal the S0 numbers; on is what the player gets.
# Usage: graphics-s2.sh <evidence_dir>    STUDIO_ROOT: the studio clone (default: next to this repository).
# Prints S2 lines; exit 0 when the check passes and every merged capture is within noise, else 1.
set -u
here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
root=$(cd "$here/../../../.." && pwd)
game=$root/game
GODOT=${GODOT:-$HOME/godot/Godot_v4.7.2-stable_linux.x86_64}
STUDIO_ROOT=${STUDIO_ROOT:-$(cd "$root/.." && pwd)/unbound-studio-plan}
parity=$STUDIO_ROOT/toolbox/parity/parity.gd
ev=${1:?usage: graphics-s2.sh <evidence_dir>}
if [ -e "$ev" ]; then echo "S2 REFUSE existing evidence $ev"; exit 1; fi
[ -x "$GODOT" ] || { echo "S2 REFUSE no engine at $GODOT (run tools-src/studio/cloud/setup.sh)"; exit 3; }
command -v xvfb-run >/dev/null 2>&1 || { echo "S2 REFUSE no xvfb-run (run tools-src/studio/cloud/setup.sh)"; exit 3; }
[ -f "$parity" ] || { echo "S2 REFUSE no parity tool at $parity (set STUDIO_ROOT to the studio clone)"; exit 3; }
mkdir -p "$ev"
ev=$(cd "$ev" && pwd)
run=$(basename "$ev")-$(date -u +%Y%m%dT%H%M%S)   # every launch on its own never-used test save
echo "S2 start game=$(git -C "$root" rev-parse --short HEAD) studio=$(git -C "$STUDIO_ROOT" rev-parse --short HEAD) $(date -u +%H:%M:%S)"
status=0
# A worktree or a fresh clone may hold an import cache from another commit (a new class_name then fails to compile and
# characters vanish from the counts), so every run imports first and a script error anywhere fails it.
"$GODOT" --headless --path "$game" --import > "$ev/import.log" 2>&1
code=$?
errors=$(grep -c 'SCRIPT ERROR' "$ev/import.log")
echo "S2 import exit=$code script_errors=$errors $(date -u +%H:%M:%S)"
[ $code -ne 0 ] || [ "$errors" -ne 0 ] && status=1

render() {   # render <log> <script> <args...>
	local log=$1 script=$2
	shift 2
	LIBGL_ALWAYS_SOFTWARE=1 timeout 1500 xvfb-run -a -s "-screen 0 1560x720x24" "$GODOT" --rendering-driver opengl3 \
		--fixed-fps 30 --path "$game" --resolution 1560x720 --script "$script" -- "$@" > "$log" 2>&1
}

mkdir -p "$ev/check"
render "$ev/check/run.log" res://scripts/studio/render/character_merge_check.gd "--test-save=s2-$run-check" \
	"--check-out=$ev/check" --studio-merge=off
code=$?
errors=$(grep -c 'SCRIPT ERROR' "$ev/check/run.log")
echo "S2 check exit=$code script_errors=$errors $(date -u +%H:%M:%S)"
grep -E '^CHECK' "$ev/check/run.log" | sed 's/^/  /'
[ $code -ne 0 ] || [ "$errors" -ne 0 ] && status=1
box=$(cat "$ev/check/box.txt" 2>/dev/null)
for pose in idle swing live; do
	b=$ev/check/$pose-unmerged.png
	[ -f "$b" ] || { echo "S2 missing capture $pose"; status=1; continue; }
	"$GODOT" --headless --path "$game" --script "$parity" -- "$b" "$ev/check/$pose-merged.png" \
		"--floor=$ev/check/$pose-unmerged-again.png" "--heat=$ev/check/$pose-heat.png" 2>/dev/null \
		| grep '^PARITY' | sed "s/^PARITY/PARITY frame $pose/" | tee -a "$ev/parity.txt" | cut -c1-400
	# the characters' box alone (the check writes it): motion elsewhere in the frame neither hides nor fakes a change
	"$GODOT" --headless --path "$game" --script "$parity" -- "$b" "$ev/check/$pose-merged.png" \
		"--floor=$ev/check/$pose-unmerged-again.png" "--rect=$box" 2>/dev/null \
		| grep '^PARITY' | sed "s/^PARITY/PARITY box $pose/" | tee -a "$ev/parity.txt" | cut -c1-400
done
not_within=$(grep -vc '"verdict":"WITHIN NOISE"' "$ev/parity.txt")
echo "S2 parity: $(grep -c '^PARITY' "$ev/parity.txt") poses; not within noise: $not_within"
[ "$not_within" -ne 0 ] && status=1

for mode in off on; do
	mkdir -p "$ev/probe-$mode"
	render "$ev/probe-$mode/run.log" res://scripts/studio/render/draw_probe.gd "--test-save=s2-$run-probe-$mode" \
		"--probe-out=$ev/probe-$mode" --probe-lod-at= "--studio-merge=$mode"
	code=$?
	errors=$(grep -c 'SCRIPT ERROR' "$ev/probe-$mode/run.log")
	echo "S2 probe merge=$mode exit=$code script_errors=$errors $(date -u +%H:%M:%S)"
	grep '^DRAWPROBE' "$ev/probe-$mode/run.log" | sed 's/^/  /' | cut -c1-200
	[ $code -ne 0 ] || [ "$errors" -ne 0 ] && status=1
done
echo "S2 complete status=$status $(date -u +%H:%M:%S)"
exit $status
