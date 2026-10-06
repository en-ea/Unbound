#!/usr/bin/env bash
# Graphics S4 (studio plan GRAPHICS-STAGES-2026-10-04.md): things with state (ThingState, things/), proved in the real
# scene. Changes no game file; evidence only.
#   1. thing_state_check.gd with the switch on (batching and the S2 merge on, as a build has them): a row of the four
#      carriers found; neutral parity captures; a state change's draw calls and time; Body's runtime stage by stage for
#      the board; a freed thing.
#   2. the parity tool on the neutral captures: the thing copies against his materials, judged against his again.
#   3. the same check with the switch off: nothing attached.
#   4. the phone boards (toolbox/lookboard/phone_board.py): by day, at night, and the effects fix.
#   5. the draw probe in the meadow and the forest, things off and on: what it costs a build with no facts.
# Usage: graphics-s4.sh <evidence_dir>    STUDIO_ROOT: the studio clone (default: next to this repository).
# Prints S4 lines; exit 0 when the check passes, every capture is within noise and nothing errs, else 1.
set -u
here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
root=$(cd "$here/../../../.." && pwd)
game=$root/game
GODOT=${GODOT:-$HOME/godot/Godot_v4.7.2-stable_linux.x86_64}
STUDIO_ROOT=${STUDIO_ROOT:-$(cd "$root/.." && pwd)/unbound-studio-plan}
parity=$STUDIO_ROOT/toolbox/parity/parity.gd
ev=${1:?usage: graphics-s4.sh <evidence_dir>}
if [ -e "$ev" ]; then echo "S4 REFUSE existing evidence $ev"; exit 1; fi
[ -x "$GODOT" ] || { echo "S4 REFUSE no engine at $GODOT (run tools-src/studio/cloud/setup.sh)"; exit 3; }
command -v xvfb-run >/dev/null 2>&1 || { echo "S4 REFUSE no xvfb-run (run tools-src/studio/cloud/setup.sh)"; exit 3; }
[ -f "$parity" ] || { echo "S4 REFUSE no parity tool at $parity (set STUDIO_ROOT to the studio clone)"; exit 3; }
mkdir -p "$ev"
ev=$(cd "$ev" && pwd)
run=$(basename "$ev")-$(date -u +%Y%m%dT%H%M%S)   # every launch on its own never-used test save
echo "S4 start game=$(git -C "$root" rev-parse --short HEAD) studio=$(git -C "$STUDIO_ROOT" rev-parse --short HEAD) $(date -u +%H:%M:%S)"
status=0
"$GODOT" --headless --path "$game" --import > "$ev/import.log" 2>&1
code=$?
errors=$(grep -c 'SCRIPT ERROR' "$ev/import.log")
echo "S4 import exit=$code script_errors=$errors $(date -u +%H:%M:%S)"
[ $code -ne 0 ] || [ "$errors" -ne 0 ] && status=1

render() {   # render <log> <script> <args...>
	local log=$1 script=$2
	shift 2
	LIBGL_ALWAYS_SOFTWARE=1 timeout 1500 xvfb-run -a -s "-screen 0 1560x720x24" "$GODOT" --rendering-driver opengl3 \
		--fixed-fps 30 --path "$game" --resolution 1560x720 --script "$script" -- "$@" > "$log" 2>&1
}

mkdir -p "$ev/check" "$ev/off"
render "$ev/check/run.log" res://scripts/studio/render/thing_state_check.gd "--test-save=s4-$run-check" \
	"--check-out=$ev/check" --studio-things=on --studio-batch=on --studio-merge=on
code=$?
errors=$(grep -c 'SCRIPT ERROR' "$ev/check/run.log")
echo "S4 check exit=$code script_errors=$errors $(date -u +%H:%M:%S)"
grep -E '^CHECK' "$ev/check/run.log" | sed 's/^/  /'
[ $code -ne 0 ] || [ "$errors" -ne 0 ] && status=1
if [ -f "$ev/check/neutral-his.png" ]; then
	"$GODOT" --headless --path "$game" --script "$parity" -- "$ev/check/neutral-his.png" "$ev/check/neutral-things.png" \
		"--floor=$ev/check/neutral-his-again.png" "--heat=$ev/check/neutral-heat.png" 2>/dev/null \
		| grep '^PARITY' | sed "s/^PARITY/PARITY neutral/" | tee -a "$ev/parity.txt" | cut -c1-300
else
	echo "S4 missing neutral captures"; status=1
fi
not_within=$(grep -vc '"verdict":"WITHIN NOISE"' "$ev/parity.txt" 2>/dev/null)
not_within=${not_within:-1}
echo "S4 parity: $(grep -c '^PARITY' "$ev/parity.txt" 2>/dev/null) captures; not within noise: $not_within"
[ "$not_within" != 0 ] && status=1
render "$ev/off/run.log" res://scripts/studio/render/thing_state_check.gd "--test-save=s4-$run-off" \
	"--check-out=$ev/off" --studio-things=off --studio-batch=on --studio-merge=on
code=$?
errors=$(grep -c 'SCRIPT ERROR' "$ev/off/run.log")
echo "S4 off exit=$code script_errors=$errors $(date -u +%H:%M:%S)"
grep -E '^CHECK' "$ev/off/run.log" | sed 's/^/  /'
[ $code -ne 0 ] || [ "$errors" -ne 0 ] && status=1
# The boards, readable on a phone: one per time of day, a labelled row per stage, the fixture said plainly.
board=$STUDIO_ROOT/toolbox/lookboard/phone_board.py
crop=$(python3 -c "import json,sys; r=json.load(open(sys.argv[1]))['board_rect']; print('%dx%d+%d+%d' % (r[2], r[3], r[0], r[1]))" "$ev/check/check.json" 2>/dev/null)
if [ -n "$crop" ] && [ -f "$board" ]; then
	for t in day night; do
		rows=()
		for st in intact:"Before: intact" burning-2-s:"Burning, 2 s" burning-10-s:"Burning, 10 s: embers in the char" \
				doused:"Doused: steam" dry-scorched:"Dried: scorched" struck:"Struck: flash and shudder" \
				broken:"Broken: charred planks" repaired:"Repaired: as before"; do
			rows+=("$ev/check/$t-${st%%:*}.png=${st#*:}")
		done
		python3 "$board" "$ev/board-$t.jpg" --crop "$crop" \
			--title "Things with state, $([ $t = day ] && echo 'by day' || echo 'at night') (S4 proposal, off)" \
			--caption "Fence, bench, crates, rack. The facts here are a FIXTURE in the check, in the shape asked of Body: nothing in the game sets them yet (after Hilmi plays). Off by default until approved." \
			"${rows[@]}" | sed 's/^/  /'
	done
	python3 "$board" "$ev/board-effects.jpg" --crop 1100x420+230+150 \
		--title "Smoke, steam, flames: the fix (people and things)" \
		--caption "Six frames after each starts, made the old way and the new way in one frame. The black discs were the old way: particles not yet emitted drew black." \
		"$ev/check/fx-before-after.png=Old (disc) and new, side by side" | sed 's/^/  /'
fi

# Its cost in a build, on the real scene (no facts: idle): the meadow and the forest (its camp has crates and a rack).
for region in meadow forest; do
	args=""
	[ "$region" = forest ] && args="--probe-region=forest --probe-at=0,-47 --probe-yaw=180"
	for mode in off on; do
		out=$ev/probe-$region-$mode
		mkdir -p "$out"
		# shellcheck disable=SC2086
		render "$out/run.log" res://scripts/studio/render/draw_probe.gd "--test-save=s4-$run-$region-$mode" \
			"--probe-out=$out" --probe-times=morning,night --probe-frames=explore,low --studio-merge=on --studio-batch=on \
			"--studio-things=$mode" $args
		code=$?
		errors=$(grep -c 'SCRIPT ERROR' "$out/run.log")
		echo "S4 probe $region things=$mode exit=$code script_errors=$errors $(date -u +%H:%M:%S)"
		grep '^DRAWPROBE' "$out/run.log" | sed 's/^/  /' | cut -c1-110
		python3 -c "import json,sys; d=json.load(open(sys.argv[1])); t=d.get('things'); print('  THINGS', json.dumps(t) if t else 'none attached')" "$out/draws.json" 2>/dev/null
		[ $code -ne 0 ] || [ "$errors" -ne 0 ] && status=1
	done
done
echo "S4 complete status=$status $(date -u +%H:%M:%S)"
exit $status
