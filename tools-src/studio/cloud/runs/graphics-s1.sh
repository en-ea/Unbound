#!/usr/bin/env bash
# Graphics S1 (studio plan GRAPHICS-STAGES-2026-10-04.md): the region's still meshes drawn merged per cell (StaticBatch),
# proved in place against the originals it hides. Changes no game file; evidence only.
#   1. static_batch_check.gd with batching and the S2 merge on (as a build has them): the build's members, cells, cost
#      and size; lights per cell; morning and night at three framings, each drawn with the originals, the batches,
#      then the originals again; a member hidden, shown, moved and freed.
#   2. the parity tool on those captures: batched against originals, judged against originals against originals again.
#   3. the draw probe (graphics S0) in the meadow and the forest, batching off and on (S2's merge on in both).
# Usage: graphics-s1.sh <evidence_dir>    STUDIO_ROOT: the studio clone (default: next to this repository).
# Prints S1 lines; exit 0 when the check passes, every capture is within noise and nothing errs, else 1.
set -u
here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
root=$(cd "$here/../../../.." && pwd)
game=$root/game
GODOT=${GODOT:-$HOME/godot/Godot_v4.7.2-stable_linux.x86_64}
STUDIO_ROOT=${STUDIO_ROOT:-$(cd "$root/.." && pwd)/unbound-studio-plan}
parity=$STUDIO_ROOT/toolbox/parity/parity.gd
ev=${1:?usage: graphics-s1.sh <evidence_dir>}
if [ -e "$ev" ]; then echo "S1 REFUSE existing evidence $ev"; exit 1; fi
[ -x "$GODOT" ] || { echo "S1 REFUSE no engine at $GODOT (run tools-src/studio/cloud/setup.sh)"; exit 3; }
command -v xvfb-run >/dev/null 2>&1 || { echo "S1 REFUSE no xvfb-run (run tools-src/studio/cloud/setup.sh)"; exit 3; }
[ -f "$parity" ] || { echo "S1 REFUSE no parity tool at $parity (set STUDIO_ROOT to the studio clone)"; exit 3; }
mkdir -p "$ev"
ev=$(cd "$ev" && pwd)
run=$(basename "$ev")-$(date -u +%Y%m%dT%H%M%S)   # every launch on its own never-used test save
echo "S1 start game=$(git -C "$root" rev-parse --short HEAD) studio=$(git -C "$STUDIO_ROOT" rev-parse --short HEAD) $(date -u +%H:%M:%S)"
status=0
"$GODOT" --headless --path "$game" --import > "$ev/import.log" 2>&1
code=$?
errors=$(grep -c 'SCRIPT ERROR' "$ev/import.log")
echo "S1 import exit=$code script_errors=$errors $(date -u +%H:%M:%S)"
[ $code -ne 0 ] || [ "$errors" -ne 0 ] && status=1

render() {   # render <log> <script> <args...>
	local log=$1 script=$2
	shift 2
	LIBGL_ALWAYS_SOFTWARE=1 timeout 1500 xvfb-run -a -s "-screen 0 1560x720x24" "$GODOT" --rendering-driver opengl3 \
		--fixed-fps 30 --path "$game" --resolution 1560x720 --script "$script" -- "$@" > "$log" 2>&1
}

mkdir -p "$ev/check"
render "$ev/check/run.log" res://scripts/studio/render/static_batch_check.gd "--test-save=s1-$run-check" \
	"--check-out=$ev/check" --studio-batch=on --studio-merge=on
code=$?
errors=$(grep -c 'SCRIPT ERROR' "$ev/check/run.log")
echo "S1 check exit=$code script_errors=$errors $(date -u +%H:%M:%S)"
grep -E '^CHECK' "$ev/check/run.log" | sed 's/^/  /'
[ $code -ne 0 ] || [ "$errors" -ne 0 ] && status=1
for shot in "$ev/check"/*-originals.png; do
	[ -f "$shot" ] || { echo "S1 missing captures"; status=1; break; }
	name=$(basename "${shot%-originals.png}")
	"$GODOT" --headless --path "$game" --script "$parity" -- "$shot" "$ev/check/$name-batched.png" \
		"--floor=$ev/check/$name-originals-again.png" "--heat=$ev/check/$name-heat.png" 2>/dev/null \
		| grep '^PARITY' | sed "s/^PARITY/PARITY $name/" | tee -a "$ev/parity.txt" | cut -c1-300
done
not_within=$(grep -vc '"verdict":"WITHIN NOISE"' "$ev/parity.txt")
echo "S1 parity: $(grep -c '^PARITY' "$ev/parity.txt") captures; not within noise: $not_within"
[ "$not_within" -ne 0 ] && status=1

for region in meadow forest; do
	args=""
	[ "$region" = forest ] && args="--probe-region=forest --probe-at=0,-47 --probe-yaw=180"
	for mode in off on; do
		out=$ev/probe-$region-$mode
		mkdir -p "$out"
		# shellcheck disable=SC2086
		render "$out/run.log" res://scripts/studio/render/draw_probe.gd "--test-save=s1-$run-$region-$mode" \
			"--probe-out=$out" --probe-lod-at=explore --studio-merge=on "--studio-batch=$mode" $args
		code=$?
		errors=$(grep -c 'SCRIPT ERROR' "$out/run.log")
		echo "S1 probe $region batch=$mode exit=$code script_errors=$errors $(date -u +%H:%M:%S)"
		grep '^DRAWPROBE' "$out/run.log" | sed 's/^/  /' | cut -c1-160
		[ $code -ne 0 ] || [ "$errors" -ne 0 ] && status=1
	done
done
echo "S1 complete status=$status $(date -u +%H:%M:%S)"
exit $status
