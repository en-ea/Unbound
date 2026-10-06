#!/usr/bin/env bash
# Graphics S0 (studio plan GRAPHICS-STAGES-2026-10-04.md): where the draw calls come from, and the parity noise floor
# every later graphics stage is judged against. Changes no game file; evidence only.
#   per region: the draw probe (game/scripts/studio/render/draw_probe.gd) launched twice, a and b, each with a fresh
#   test save and the graphics stages switched off (--studio-merge=off: the game as it is), rendered on a virtual
#   display at 1560x720 and a fixed 30 fps; then the parity tool (studio
#   toolbox/parity/parity.gd) on every capture of launch a:
#     floor     a against a-again: the same paused frame drawn again after the control (the noise floor per framing);
#     control   a without the player judged against that floor: expected CHANGED (the tool sees a missing character);
#     launches  a against b: two identical launches, for information. The live village does not replay exactly
#               between launches (people stand elsewhere hours on), so whole-frame parity across launches is not a
#               proof; later stages compare in place, in one paused launch, against the floor above.
# Usage: graphics-s0.sh <evidence_dir> [regions...]   (default: meadow forest)
#   STUDIO_ROOT: the studio clone (default: next to this repository). GODOT: the engine.
# Prints S0 lines; exit 0 when every breakdown sums and every control is seen, else 1.
set -u
here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
root=$(cd "$here/../../../.." && pwd)
game=$root/game
GODOT=${GODOT:-$HOME/godot/Godot_v4.7.2-stable_linux.x86_64}
STUDIO_ROOT=${STUDIO_ROOT:-$(cd "$root/.." && pwd)/unbound-studio-plan}
parity=$STUDIO_ROOT/toolbox/parity/parity.gd
ev=${1:?usage: graphics-s0.sh <evidence_dir> [regions...]}
shift
regions=${*:-meadow forest}
if [ -e "$ev" ]; then echo "S0 REFUSE existing evidence $ev"; exit 1; fi
[ -x "$GODOT" ] || { echo "S0 REFUSE no engine at $GODOT (run tools-src/studio/cloud/setup.sh)"; exit 3; }
command -v xvfb-run >/dev/null 2>&1 || { echo "S0 REFUSE no xvfb-run (run tools-src/studio/cloud/setup.sh)"; exit 3; }
[ -f "$parity" ] || { echo "S0 REFUSE no parity tool at $parity (set STUDIO_ROOT to the studio clone)"; exit 3; }
mkdir -p "$ev"
ev=$(cd "$ev" && pwd)
# Every launch starts from its own never-used test save: the game autosaves into it, so a name used before would load
# that run's later state (a killed run's night once came back as a fresh run's morning).
run=$(basename "$ev")-$(date -u +%Y%m%dT%H%M%S)
echo "S0 start game=$(git -C "$root" rev-parse --short HEAD) studio=$(git -C "$STUDIO_ROOT" rev-parse --short HEAD) $(date -u +%H:%M:%S)"
status=0
# A worktree or a fresh clone may hold an import cache from another commit (a new class_name then fails to compile and
# characters vanish from the counts), so every run imports first and a script error anywhere fails it.
"$GODOT" --headless --path "$game" --import > "$ev/import.log" 2>&1
code=$?
errors=$(grep -c 'SCRIPT ERROR' "$ev/import.log")
echo "S0 import exit=$code script_errors=$errors $(date -u +%H:%M:%S)"
[ $code -ne 0 ] || [ "$errors" -ne 0 ] && status=1

probe() {   # probe <region> <launch>
	local out=$ev/$1/$2 args=""
	# The forest's spawn is its gate, where the game's camera looks back north at the gate and the valley wall (and the
	# low camera sits inside the gate's arch); play heads south, so the forest is measured on the path 40 m in, at the
	# clearing (0, -47), looking south into it.
	[ "$1" = forest ] && args="--probe-region=forest --probe-at=0,-47 --probe-yaw=180"
	mkdir -p "$out"
	# shellcheck disable=SC2086
	LIBGL_ALWAYS_SOFTWARE=1 timeout 1500 xvfb-run -a -s "-screen 0 1560x720x24" "$GODOT" --rendering-driver opengl3 \
		--fixed-fps 30 --path "$game" --resolution 1560x720 --script res://scripts/studio/render/draw_probe.gd \
		-- "--test-save=s0-$run-$1-$2" "--probe-out=$out" --studio-merge=off $args > "$out/run.log" 2>&1
	local code=$?
	local errors
	errors=$(grep -c 'SCRIPT ERROR' "$out/run.log")
	echo "S0 probe $1 $2 exit=$code script_errors=$errors $(date -u +%H:%M:%S)"
	grep '^DRAWPROBE' "$out/run.log" | sed 's/^/  /' | cut -c1-260
	[ $code -ne 0 ] || [ "$errors" -ne 0 ] && status=1
	return 0
}

compare() {   # compare <tag> <base> <candidate> [floor]: one PARITY line into parity.txt
	local extra=""
	[ -n "${4:-}" ] && extra="--floor=$4"
	# shellcheck disable=SC2086
	"$GODOT" --headless --path "$game" --script "$parity" -- "$2" "$3" $extra --heat="${3%.png}-$1-heat.png" 2>/dev/null \
		| grep '^PARITY' | sed "s/^PARITY/PARITY $1/" >> "$ev/parity.txt"
}

for region in $regions; do
	for launch in a b; do
		probe "$region" "$launch"
	done
	for shot in "$ev/$region"/a/*-*.png; do
		case "$shot" in *-again.png|*-noplayer.png|*-heat.png) continue ;; esac
		name=$(basename "$shot")
		b=$ev/$region/b/$name
		[ -f "${shot%.png}-again.png" ] || { echo "S0 missing capture $region $name"; status=1; continue; }
		compare "floor $region" "$shot" "${shot%.png}-again.png"
		compare "control $region" "$shot" "${shot%.png}-noplayer.png" "${shot%.png}-again.png"
		[ -f "$b" ] && compare "launches $region" "$shot" "$b"
	done
done
control_bad=$(grep '^PARITY control' "$ev/parity.txt" | grep -vc '"verdict":"CHANGED"')
echo "S0 parity: $(grep -c '^PARITY floor' "$ev/parity.txt") floors; controls not seen: $control_bad"
[ "$control_bad" -ne 0 ] && status=1
echo "S0 complete status=$status $(date -u +%H:%M:%S)"
exit $status
