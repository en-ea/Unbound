#!/usr/bin/env bash
# Graphics S5 (studio plan GRAPHICS-STAGES-2026-10-04.md): the house and stall grammar over Enea's helpers
# (tools-src/studio/blender/house_grammar.py) and the village's switch for it (render/house_variety.gd), proved. Changes
# no game file; evidence only.
#   1. the grammar's presets of his cottage, cabin and round house against his committed models (glb_same.py: the same
#      bytes, or the same model triangle for triangle), and the game's grammar houses (assets/studio/houses) remade
#      from the grammar and compared the same way;
#   2. ten seeded variants of each style (timber, log, round) and ten stalls, every one standing by check(); drawn on
#      the game's grass by house_board.gd by day and at night;
#   3. house_variety_check.gd with the switch on preset (parity in place against his houses: within noise), on variety
#      (the board) and off (nothing attached);
#   4. the phone boards (toolbox/lookboard/phone_board.py): each style's variants after his preset, day beside night,
#      and the village with variety, his beside the grammar's, by day and at night;
#   5. the draw probe in the meadow with the houses off, preset and variety: what it costs a build.
# Usage: graphics-s5.sh <evidence_dir>    STUDIO_ROOT: the studio clone (default: next to this repository).
# Prints S5 lines; exit 0 when every preset is his model, every check passes, preset parity is within noise and nothing
# errs, else 1.
set -u
here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
root=$(cd "$here/../../../.." && pwd)
game=$root/game
GODOT=${GODOT:-$HOME/godot/Godot_v4.7.2-stable_linux.x86_64}
BPY=${BPY:-$HOME/blender-venv/bin/python}
STUDIO_ROOT=${STUDIO_ROOT:-$(cd "$root/.." && pwd)/unbound-studio-plan}
parity=$STUDIO_ROOT/toolbox/parity/parity.gd
board=$STUDIO_ROOT/toolbox/lookboard/phone_board.py
grammar=$root/tools-src/studio/blender/house_grammar.py
same=$root/tools-src/studio/blender/glb_same.py
ev=${1:?usage: graphics-s5.sh <evidence_dir>}
if [ -e "$ev" ]; then echo "S5 REFUSE existing evidence $ev"; exit 1; fi
[ -x "$GODOT" ] || { echo "S5 REFUSE no engine at $GODOT (run tools-src/studio/cloud/setup.sh)"; exit 3; }
[ -x "$BPY" ] || { echo "S5 REFUSE no Blender module at $BPY (STUDIO_BPY=1 tools-src/studio/cloud/setup.sh)"; exit 3; }
command -v xvfb-run >/dev/null 2>&1 || { echo "S5 REFUSE no xvfb-run"; exit 3; }
[ -f "$parity" ] && [ -f "$board" ] || { echo "S5 REFUSE no toolbox at $STUDIO_ROOT"; exit 3; }
mkdir -p "$ev"
ev=$(cd "$ev" && pwd)
run=$(basename "$ev")-$(date -u +%Y%m%dT%H%M%S)
echo "S5 start game=$(git -C "$root" rev-parse --short HEAD) studio=$(git -C "$STUDIO_ROOT" rev-parse --short HEAD) $(date -u +%H:%M:%S)"
status=0
export PYTHONDONTWRITEBYTECODE=1        # (his tools-src/blender carries his own .pyc files; never rewrite them)

# 1. Presets against his models; the game's grammar houses remade.
"$BPY" "$grammar" -- "$ev/grammar/presets" presets > "$ev/grammar-presets.log" 2>&1 || status=1
for h in house_cottage house_cabin house_round; do
	r=$(python3 "$same" "$ev/grammar/presets/$h.glb" "$game/assets/buildings/$h.glb") || status=1
	echo "S5 preset $h against his committed model: $r"
done
"$BPY" "$grammar" -- "$ev/grammar/game" game > "$ev/grammar-game.log" 2>&1 || status=1
for f in "$game"/assets/studio/houses/*.glb; do
	r=$(python3 "$same" "$ev/grammar/game/$(basename "$f")" "$f") || status=1
	echo "S5 game asset $(basename "$f") remade: $r"
done

# 2. Variants and stalls, each standing by check().
"$BPY" "$grammar" -- "$ev/grammar/variants" all > "$ev/grammar-variants.log" 2>&1 || status=1
echo "S5 variants built: $(grep -c 'GRAMMAR variant' "$ev/grammar-variants.log") (each passed check(); tries above 1: $(grep -c 'tries [2-9]' "$ev/grammar-variants.log"))"
"$GODOT" --headless --path "$game" --import > "$ev/import.log" 2>&1
errors=$(grep -c 'SCRIPT ERROR' "$ev/import.log")
echo "S5 import script_errors=$errors $(date -u +%H:%M:%S)"
[ "$errors" -ne 0 ] && status=1

render() {   # render <log> <script> <args...>
	local log=$1 script=$2
	shift 2
	LIBGL_ALWAYS_SOFTWARE=1 timeout 1500 xvfb-run -a -s "-screen 0 1560x720x24" "$GODOT" --rendering-driver opengl3 \
		--fixed-fps 30 --path "$game" --resolution 1560x720 --script "$script" -- "$@" > "$log" 2>&1
}

list="house_cottage,house_cabin,house_round"
for st in timber log round stall; do for i in $(seq 1 10); do list="$list,${st}_$i"; done; done
mkdir -p "$ev/board-src"
render "$ev/board-src/run.log" res://scripts/studio/render/house_board.gd "--test-save=s5-$run-board" \
	"--board-in=$ev/grammar/variants" "--board-out=$ev/board-src" "--board-list=$list"
code=$?
errors=$(grep -c 'SCRIPT ERROR' "$ev/board-src/run.log")
echo "S5 board renders exit=$code script_errors=$errors $(grep -c '^BOARD ' "$ev/board-src/run.log") $(date -u +%H:%M:%S)"
[ $code -ne 0 ] || [ "$errors" -ne 0 ] && status=1

# 3. The village's switch.
for mode in preset variety off; do
	out=$ev/village-$mode
	mkdir -p "$out"
	render "$out/run.log" res://scripts/studio/render/house_variety_check.gd "--test-save=s5-$run-$mode" \
		"--check-out=$out" "--studio-houses=$mode" --studio-batch=on --studio-merge=on
	code=$?
	errors=$(grep -c 'SCRIPT ERROR' "$out/run.log")
	echo "S5 village $mode exit=$code script_errors=$errors $(date -u +%H:%M:%S)"
	grep -E '^CHECK' "$out/run.log" | sed 's/^/  /' | cut -c1-240
	[ $code -ne 0 ] || [ "$errors" -ne 0 ] && status=1
done
for t in day night; do
	for v in game cottage cabin round; do
		p=$ev/village-preset/$t-$v
		"$GODOT" --headless --path "$game" --script "$parity" -- "$p-his.png" "$p-grammar.png" "--floor=$p-his-again.png" \
			"--heat=$p-heat.png" 2>/dev/null | grep '^PARITY' | sed "s/^PARITY/PARITY $t-$v/" >> "$ev/parity.txt"
	done
done
not_within=$(grep -vc '"verdict":"WITHIN NOISE"' "$ev/parity.txt" 2>/dev/null)
echo "S5 preset parity: $(grep -c '^PARITY' "$ev/parity.txt" 2>/dev/null) views; not within noise: ${not_within:-1}"
[ "${not_within:-1}" != 0 ] && status=1

# 4. Phone boards.
pair() {     # pair <out> <left> <right>: two frames side by side
	convert "$2" "$3" -resize 540x +append "$1"
}
mkdir -p "$ev/pairs"
names=(timber log round stall)
his=(house_cottage house_cabin house_round "")
titles=("Timber houses: variants" "Log houses: variants" "Round houses: variants" "Market stalls: new")
for k in 0 1 2 3; do
	st=${names[$k]}
	rows=()
	if [ -n "${his[$k]}" ]; then
		pair "$ev/pairs/${his[$k]}.png" "$ev/board-src/${his[$k]}-day.png" "$ev/board-src/${his[$k]}-night.png"
		rows+=("$ev/pairs/${his[$k]}.png=Before: his ${his[$k]#house_} (preset: same model)")
	fi
	for i in $(seq 1 10); do
		pair "$ev/pairs/${st}_$i.png" "$ev/board-src/${st}_$i-day.png" "$ev/board-src/${st}_$i-night.png"
		rows+=("$ev/pairs/${st}_$i.png=Variant $i (seed $i)")
	done
	python3 "$board" "$ev/board-$st.jpg" --title "${titles[$k]} (S5, off)" \
		--caption "Day left, night right. Each is seeded and checked: nothing floats, windows clear the door, walls within his footprint. A look proposal, off by default until approved." \
		"${rows[@]}" | sed 's/^/  /'
done
for t in day night; do
	rows=()
	for v in game cottage cabin round; do
		pair "$ev/pairs/village-$t-$v.png" "$ev/village-variety/$t-$v-his.png" "$ev/village-variety/$t-$v-grammar.png"
		rows+=("$ev/pairs/village-$t-$v.png=$([ $v = game ] && echo "The game's view" || echo "His $v")")
	done
	python3 "$board" "$ev/board-village-$t.jpg" --title "Village with variety, $([ $t = day ] && echo 'by day' || echo 'at night') (off)" \
		--caption "Left: his houses today. Right: the switch on variety (his cottage, cabin and round house each a seeded variant of its style, within his footprint). On preset the right is his house exactly." \
		"${rows[@]}" | sed 's/^/  /'
done

# 5. Its cost in a build: the meadow with the houses off, preset and variety.
for mode in off preset variety; do
	out=$ev/probe-meadow-$mode
	mkdir -p "$out"
	render "$out/run.log" res://scripts/studio/render/draw_probe.gd "--test-save=s5-$run-probe-$mode" "--probe-out=$out" \
		--probe-times=morning,night --probe-frames=explore,low --studio-merge=on --studio-batch=on "--studio-houses=$mode"
	code=$?
	errors=$(grep -c 'SCRIPT ERROR' "$out/run.log")
	echo "S5 probe meadow houses=$mode exit=$code script_errors=$errors $(date -u +%H:%M:%S)"
	grep '^DRAWPROBE' "$out/run.log" | sed 's/^/  /' | cut -c1-110
	[ $code -ne 0 ] || [ "$errors" -ne 0 ] && status=1
done
echo "S5 complete status=$status $(date -u +%H:%M:%S)"
exit $status
