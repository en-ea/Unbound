#!/usr/bin/env bash
# Animation window 6, cloud edition: the laptop's w6.sh steps against this checkout (3b808a0 over integration's base
# 7ec6b4b, plus this tooling, which changes no game file). A fresh clone has no import cache, so step 0 imports.
#   0. import, headless (engine errors fail the run)
#   1. people/animation_checks, headless: 20 PASS lines (the player pose's active clock and attention made visible)
#   2. Body's contact test through Body's own bootstrap (body_contact_run.gd): 11 PASS lines, a regression guard for
#      the elements under residents._physical (Body's gate is Body's)
#   3. look boards after: attention, fear; the sheet
# Usage: animation-w6.sh <evidence_dir>    Exit: the first failing step's status, else 0.
set -u
here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
root=$(cd "$here/../../../.." && pwd)
export GODOT=${GODOT:-$HOME/godot/Godot_v4.7.2-stable_linux.x86_64}
ev=${1:?usage: animation-w6.sh <evidence_dir>}
if [ -e "$ev" ]; then echo "W6 REFUSE existing evidence $ev"; exit 1; fi
[ -x "$GODOT" ] || { echo "W6 REFUSE no engine at $GODOT (run tools-src/studio/cloud/setup.sh)"; exit 3; }
mkdir -p "$ev"
ev=$(cd "$ev" && pwd)
export JOB_DIR=$ev
echo "W6 start $(git -C "$root" rev-parse --short HEAD) $(date -u +%H:%M:%S)"
status=0
bash "$here/../job.sh" import 1200 '.' -- --headless --path "$root/game" --import
code=$?
[ $code -ne 0 ] && status=$code
echo "W6 import exit=$code $(date -u +%H:%M:%S)"
JOB_EXPECT='^PASS ' JOB_EXPECT_N=20 bash "$here/../job.sh" animation-checks 600 '^RUN people/animation_checks complete' \
	-- --headless --path "$root/game" --script res://scripts/studio/run.gd -- people/animation_checks
code=$?
[ $code -ne 0 ] && [ $status -eq 0 ] && status=$code
echo "W6 checks exit=$code $(date -u +%H:%M:%S)"
JOB_EXPECT='^PASS ' JOB_EXPECT_N=11 bash "$here/../job.sh" body-contact-regression 300 '^BODY CONTACT complete:' \
	-- --headless --path "$root/game" --script res://scripts/studio/people/body_contact_run.gd
code=$?
[ $code -ne 0 ] && [ $status -eq 0 ] && status=$code
echo "W6 contact regression exit=$code $(date -u +%H:%M:%S)"
bash "$here/../look.sh" "$ev/boards" "$here/animation-w6-shots.txt" 1560x720
code=$?
[ $code -ne 0 ] && [ $status -eq 0 ] && status=$code
echo "W6 boards exit=$code $(date -u +%H:%M:%S)"
echo "W6 complete status=$status"
exit $status
