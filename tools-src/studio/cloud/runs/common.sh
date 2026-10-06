#!/usr/bin/env bash
# Shared by gate.sh and regression.sh (sourced, not run). Sets the engine, the evidence directory, the studio clone that
# holds the real saves, and step(), which runs one job.sh job and keeps the worst status.
#   STUDIO_ROOT   the studio repo clone (21017478/unbound-studio-plan); default: next to this repository
#   GODOT         the engine; default: setup.sh's install
here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
root=$(cd "$here/../../../.." && pwd)
game=$root/game
job=$here/../job.sh
export GODOT=${GODOT:-$HOME/godot/Godot_v4.7.2-stable_linux.x86_64}
STUDIO_ROOT=${STUDIO_ROOT:-$(cd "$root/.." && pwd)/unbound-studio-plan}
fixtures=$STUDIO_ROOT/plan/evidence/people-integration/20261004
# The three real saves (rule 7): the captured failing save, the verified pre-install backup, the 4 Oct phone backup.
saves="$fixtures/owner-live-161221/save.json;$fixtures/phone-ready-153718708/verified-copy/files/save.json;$fixtures/phone-ready-201229663/verified-copy/files/save.json"
# Godot's Linux user folder; the owner-play probe reads its test save from here as studio-test-<name>.json.
userdata=$HOME/.local/share/godot/app_userdata/Unbound
status=0

# begin TAG EVIDENCE_DIR: refuses a missing engine, missing saves or existing evidence, then records the inputs.
begin() {
	local tag=$1
	ev=${2:?usage: $0 <evidence_dir>}
	if [ -e "$ev" ]; then echo "$tag REFUSE existing evidence $ev"; exit 1; fi
	[ -x "$GODOT" ] || { echo "$tag REFUSE no engine at $GODOT (run tools-src/studio/cloud/setup.sh)"; exit 3; }
	for f in ${saves//;/ } "$fixtures/phone-201229-meadow-test-save.json"; do
		[ -f "$f" ] || { echo "$tag REFUSE missing fixture $f (set STUDIO_ROOT to the studio clone)"; exit 3; }
	done
	mkdir -p "$ev" "$userdata"
	ev=$(cd "$ev" && pwd)
	export JOB_DIR=$ev
	run=$(basename "$ev")
	# Test saves are named after the run; a previous run of the same name left its save and journal behind, and a
	# check would load that village instead of a fresh one (5 Oct: two release runs both named "regression").
	rm -f "$userdata/studio-test-$run-"*
	echo "$tag start game=$(git -C "$root" rev-parse --short HEAD) studio=$(git -C "$STUDIO_ROOT" rev-parse --short HEAD) $(date -u +%H:%M:%S)"
}

# step NAME SECONDS DONE_REGEX EXPECT_REGEX EXPECT_N -- <godot args>: one job; the first failing status is kept.
step() {
	local name=$1 limit=$2 done_re=$3 expect=$4 n=$5
	shift 5
	JOB_EXPECT=$expect JOB_EXPECT_N=$n bash "$job" "$name" "$limit" "$done_re" "$@"
	local code=$?
	[ $code -ne 0 ] && [ $status -eq 0 ] && status=$code
	return 0
}

import_step() { step import 1200 '.' '' 1 -- --headless --path "$game" --import; }

# The checks shared by both runners. Counts are what pass3 produces; a count rises only in the commit that lands the
# check adding it.
owner_save_step() {
	step owner-save 600 '^RUN people/owner_save_test complete' '^PASS owner-save ' 40 \
		-- --headless --path "$game" --script res://scripts/studio/run.gd -- people/owner_save_test "--owner-saves=$saves"
}
owner_play_step() {
	cp "$fixtures/phone-201229-meadow-test-save.json" "$userdata/studio-test-$run-201229.json"
	step owner-play 900 '^OWNER PLAY complete' '^PASS owner-play ' 9 \
		-- --headless --max-fps 30 --fixed-fps 30 --resolution 1560x720 --path "$game" \
		-- --studio=village/live --owner-play "--test-save=$run-201229" --save-guard
}
encounter_step() {
	step encounter 600 '^ENCOUNTER complete' '^PASS encounter ' 28 \
		-- --headless --max-fps 30 --fixed-fps 30 --resolution 1560x720 --path "$game" \
		-- --studio=village/live --village-seed=1 --village-encounter=check "--test-save=$run-encounter" --save-guard
}
