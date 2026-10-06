#!/usr/bin/env bash
# Rule 7 release gate, cloud edition: the real-save checks of plan/PHONE-DELIVERY-RULES-2026-10-03.md rule 7 against
# this checkout. The saves come from the studio clone (STUDIO_ROOT, default ../unbound-studio-plan).
#   0. import, headless
#   1. people/owner_save_test on the three real saves: 40 PASS (step 4 adds v1 rows and the interruption check)
#   2. owner play (--save-guard): the live village boots from the 4 Oct phone save placed in the meadow, real Heavy memories accepted
#      and reloaded, journal replay and checkpoint from data equal the live village, no recovery fallback: 9 PASS
#   3. the connected encounter: 28 PASS
# Usage: gate.sh <evidence_dir>    Exit: the first failing step's status, else 0.
set -u
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"
begin GATE "${1:-}"
import_step
owner_save_step
owner_play_step
encounter_step
echo "GATE complete status=$status $(date -u +%H:%M:%S)"
exit $status
