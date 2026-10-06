#!/bin/bash
# Copied unchanged (below this line) from the studio toolbox, toolbox/godot-jobs/job.sh, which is game-agnostic,
# so cloud sessions, which clone only this repository, run checks exactly as the laptop does.
# One Godot job whose result can be trusted. The engine's own exit status (or the timeout's), the run's explicit
# failures and engine errors, its completion marker and the result lines asked for are folded into one line and one
# exit status. The full log stays on disk.
#
#   job.sh NAME SECONDS DONE_REGEX [-- ] <godot args...>
#
# Environment:
#   GODOT       the engine (required)
#   JOB_DIR     where the log goes (default: $TEMP/godot-jobs); the log is $JOB_DIR/NAME.log
#   JOB_FAIL    a failure line (default: lines starting "FAIL " or "PROBE FAIL ")
#   JOB_ERR     an engine error (default: SCRIPT ERROR, Parse Error, Invalid call/access, Failed to load script)
#   JOB_EXPECT  a result line that must appear (e.g. "^MOTION "), at least JOB_EXPECT_N times (default 1)
#
# Prints:  JOB NAME PASS|FAIL|INCOMPLETE exit=N done=yes|no fails=K errors=K results=K log=PATH
#          then the failure and error lines (at most JOB_SHOW, default 20).
# Exit:    0 PASS; 1 FAIL (failures, errors, or a non-zero exit with the run complete);
#          2 INCOMPLETE (timed out, no completion marker, or results missing). Never 0 unless all of it holds.

name=$1; limit=$2; done_re=$3
shift 3
[ "${1:-}" = "--" ] && shift
if [ -z "${GODOT:-}" ] || [ -z "$name" ] || [ -z "$limit" ] || [ -z "$done_re" ]; then
	echo "JOB ${name:-?} INCOMPLETE usage: GODOT=... job.sh NAME SECONDS DONE_REGEX -- <godot args>"; exit 2
fi
hidden=no
for argument in "$@"; do
	[ "$argument" = '--' ] && break
	[ "$argument" = '--headless' ] && hidden=yes
done
if [ "$hidden" != yes ]; then
	echo "JOB $name REFUSED: ordinary jobs require --headless; rendered looks use capture_hidden.sh"
	exit 3
fi
dir=${JOB_DIR:-${TEMP:-/tmp}/godot-jobs}
mkdir -p "$dir"
log="$dir/$name.log"

timeout "$limit" "$GODOT" "$@" > "$log" 2>&1
code=$?                                   # the engine's status (124: the timeout ended it), before anything formats

fail_re=${JOB_FAIL:-'^(FAIL|PROBE FAIL) '}
err_re=${JOB_ERR:-'SCRIPT ERROR|Parse Error|Invalid call|Invalid access|Failed to load script'}
fails=$(grep -cE "$fail_re" "$log")
errs=$(grep -cE "$err_re" "$log")
done=no
grep -qE "$done_re" "$log" && done=yes
results=-
missing=no
if [ -n "${JOB_EXPECT:-}" ]; then
	results=$(grep -cE "$JOB_EXPECT" "$log")
	[ "$results" -lt "${JOB_EXPECT_N:-1}" ] && missing=yes
fi

if [ "$fails" -gt 0 ] || [ "$errs" -gt 0 ]; then
	verdict=FAIL; status=1
elif [ $code -eq 124 ] || [ $done = no ] || [ $missing = yes ]; then
	verdict=INCOMPLETE; status=2
elif [ $code -ne 0 ]; then
	verdict=FAIL; status=1
else
	verdict=PASS; status=0
fi
[ $code -eq 124 ] && verdict="$verdict (timed out after ${limit}s)"
echo "JOB $name $verdict exit=$code done=$done fails=$fails errors=$errs results=$results log=$log"
grep -E "$fail_re|$err_re" "$log" | head -n "${JOB_SHOW:-20}" | cut -c1-300 | sed 's/^/    /'
exit $status
