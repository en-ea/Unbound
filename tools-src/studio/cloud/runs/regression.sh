#!/usr/bin/env bash
# The integration regression suite, cloud edition: the 14 checks the laptop ran (plus Body's labels check, 5 Oct) in repair-r6..r8, checks-r16/r19 and
# play-r25 (plan/evidence/people-integration/20261004/), against this checkout. Includes the gate's checks.
# Live runs use --max-fps 30 --fixed-fps 30 (game time = wall time), as Body's verified body-r23 sequence did: the
# physical probe stops after 45 wall seconds without enough game time, so a half-speed clock fails it on a slow VM.
# village/sim/save_test: 32 PASS since the gap (d) fix (claude/step4-save-wip 24c8022).
# --save-guard (step 4): every checked batch in these runs verifies the save image equals the live village, or fails.
# F4 (5 Oct): physical 33 and Body's talk, feet, gesture and speech checks at people-body d56594f; crowd 7 and
# gesture 56 at people-body 19247e1.
# Usage: regression.sh <evidence_dir>    Exit: the first failing step's status, else 0.
set -u
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
begin REGRESSION "${1:-}"
headless=(--headless --path "$game" --script res://scripts/studio/run.gd --)
live=(--headless --max-fps 30 --fixed-fps 30 --resolution 1560x720 --path "$game" -- --studio=village/live --save-guard)
import_step
step bench 600 '^RUN village/save_cost_bench complete' '^BENCH ' 6 -- "${headless[@]}" village/save_cost_bench "--owner-saves=$saves"
owner_save_step
owner_play_step
step save-test 300 '^RUN village/sim/save_test complete' '^PASS ' 32 -- "${headless[@]}" village/sim/save_test --save-guard
step mind-state 300 '^RUN people/mind_state_test complete' '^PASS ' 17 -- "${headless[@]}" people/mind_state_test --save-guard
step mind-choice 300 '^RUN people/mind_choice_test complete' '^PASS ' 6 -- "${headless[@]}" people/mind_choice_test --save-guard
step foundation-state 300 '^RUN people/foundation_state_test complete' '^PASS ' 18 -- "${headless[@]}" people/foundation_state_test --save-guard
step integration-shared 300 '^RUN people/integration_shared_test complete' '^PASS ' 23 -- "${headless[@]}" people/integration_shared_test --save-guard
step animation-checks 300 '^RUN people/animation_checks complete' '^PASS ' 20 -- "${headless[@]}" people/animation_checks --save-guard
step labels 300 '^BODY PLAY complete mode=labels' '^PASS BODY PLAY ' 4 -- "${live[@]}" --body-play=labels "--test-save=$run-labels"
step inactive 300 '^BODY PLAY complete mode=inactive' '^PASS BODY PLAY ' 4 -- "${live[@]}" --body-play=inactive "--test-save=$run-inactive"
step physical 600 '^BODY PLAY complete mode=sequence' '^PASS BODY PLAY ' 33 -- "${live[@]}" --village-seed=1 --body-play=sequence "--test-save=$run-physical"
encounter_step
# Body's checks (people-body d56594f, desk 5 Oct): talk in the world, the stick's feet, the gesture table, speech layout.
step talk 600 '^BODY PLAY complete mode=talk' '^PASS BODY PLAY ' 8 -- "${live[@]}" --village-seed=1 --body-play=talk "--test-save=$run-talk"
step feet 300 '^BODY PLAY complete mode=feet' '^PASS BODY PLAY ' 7 -- "${live[@]}" --body-play=feet "--test-save=$run-feet"
step crowd 900 '^BODY PLAY complete mode=crowd' '^PASS BODY PLAY ' 7 -- "${live[@]}" --body-play=crowd "--test-save=$run-crowd"
step act-gesture 300 '^RUN player/act_gesture_test complete' '^PASS ' 56 -- "${headless[@]}" player/act_gesture_test
step speech 300 '^RUN people/speech_test complete' '^PASS ' 19 -- "${headless[@]}" people/speech_test
# Fire and damage on things (world-things cf99d1a, desk 5 Oct): the state home and save, the rules, and Body's probe in the live game.
step thing-facts 300 '^RUN village/sim/thing_facts_test complete' '^PASS ' 14 -- "${headless[@]}" village/sim/thing_facts_test --save-guard
step thing-actions 300 '^RUN village/sim/thing_actions_test complete' '^PASS ' 25 -- "${headless[@]}" village/sim/thing_actions_test --save-guard
step things 600 '^BODY PLAY complete mode=things' '^PASS BODY PLAY ' 10 -- "${live[@]}" --village-seed=1 --body-play=things "--test-save=$run-things"
step water 600 '^WATER complete' '^PASS encounter ' 4 -- "${live[@]}" --village-seed=1 --village-encounter=water_check "--test-save=$run-water"
# Graphics (desk 5 Oct, pass3 7057e7a): Animation's S2 and S1 runs, rendered (job.sh takes headless jobs only), each
# with its check count, parity within noise and its draw probes.
graphics_step() {   # graphics_step <name> <script> <checks>
	local name=$1 script=$2 n=$3 out="$ev/$1" code
	bash "$here/$script" "$out" > "$ev/$name.txt" 2>&1
	code=$?
	grep -q "^CHECK complete: $n checks, 0 failed" "$out/check/run.log" 2>/dev/null || { [ $code -eq 0 ] && code=1; }
	echo "JOB $name $([ $code -eq 0 ] && echo PASS || echo FAIL) exit=$code $(grep -h '^CHECK complete' "$out/check/run.log" 2>/dev/null) log=$ev/$name.txt"
	[ $code -ne 0 ] && [ $status -eq 0 ] && status=$code
	return 0
}
graphics_step graphics-s2 graphics-s2.sh 26
graphics_step graphics-s1 graphics-s1.sh 9
graphics_step graphics-s4 graphics-s4.sh 10
# Graphics S5 (pass3 67467c0): the village's houses at the game's own setting (preset when absent), rendered, as
# Animation's final-head run did; graphics-s5.sh also rebuilds the houses in Blender, which a cloud VM may not have.
houses_step() {
	local out="$ev/graphics-s5-houses" code
	mkdir -p "$out"
	LIBGL_ALWAYS_SOFTWARE=1 timeout 1500 xvfb-run -a -s "-screen 0 1560x720x24" "$GODOT" --rendering-driver opengl3 \
		--fixed-fps 30 --path "$game" --resolution 1560x720 --script res://scripts/studio/render/house_variety_check.gd \
		-- "--test-save=$run-houses" "--check-out=$out" > "$out/run.log" 2>&1
	code=$?
	grep -q 'SCRIPT ERROR' "$out/run.log" && [ $code -eq 0 ] && code=1
	grep -q "^CHECK complete: 4 checks, 0 failed" "$out/run.log" || { [ $code -eq 0 ] && code=1; }
	echo "JOB graphics-s5-houses $([ $code -eq 0 ] && echo PASS || echo FAIL) exit=$code $(grep -h '^CHECK complete' "$out/run.log") log=$out/run.log"
	[ $code -ne 0 ] && [ $status -eq 0 ] && status=$code
	return 0
}
houses_step
echo "REGRESSION complete status=$status $(date -u +%H:%M:%S)"
exit $status
