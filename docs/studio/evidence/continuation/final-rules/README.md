---
title: Final clemency rule verification
created: 2026-09-29
type: evidence
voice: agent-draft
author: Codex helper
status: checked
next_step: Parent integrates this verified rule packet into the final candidate and runs the separate rendered and device release gates.
---

## Verdict

[run] The parent's intentional clemency rule passes the refreshed JavaScript golden, typed Godot village conformance, runtime/actions/lifecycle tests, world-kernel conformance, and live/save/storm checks. The 20-village ending-diversity output already produced by the parent was checked for internal consistency; it was **not simulated again**. The JavaScript invariant run passed 20 villages × 1,000 years at pace 1 (181,300 events, 13–54 survivors); its raw result is recorded in adjacent files.

[repo] Exact parent source/base was `1a8f000`; this isolated checkout merged it before verification. The rule can lower an actual non-grave sentence by one position when carried-out judgments have exceeded 35% of cases and the elder is merciful enough. It requires a sentence above the minimum and does not relabel an unchanged fine or commute a grave offence. This intentional change altered the live-pace golden case beginning at day 120; the two chronicle-pace cases stayed byte-for-byte unchanged. `golden_data.gd` was regenerated once from the current JavaScript reference, then independently matched by Godot at every checkpoint.

[run] The supplied `integration-m3/endings-clemency.jsonl` has exactly 20 seeds in the specified sequence, 1,000 years at pace 1, and internally consistent case, outcome, and share arithmetic. It records **zero villages above 40%**. Across 3,767 total cases, all were closed, none pending, and 3,684 had one of the original `stats.outcomes` categories: `acquitted` 944, `carried_out` 1,287, `commuted` 444, `confessed_spared` 918, `crowd_turned` 91. The remaining 83 closed cases have no recorded category. `verify-clemency.mjs` checks the rows; it does not claim to rerun the parent's simulation.

[run] Godot full village conformance: seed 1000/8919 at pace 1 and 16838 at pace 10 each matched **20/20 checkpoints × six columns**. Its embedded live suite passed 10 villages (five freed, all alive, 42 shield contacts); its storm suite passed 20 villages (97 ancestors, 99 lost, 17 carried rites, five rescued rites). Godot runtime, actions, and new lifecycle test passed with empty stderr. Lifecycle checks three seeds over eight days using short foreground steps versus one offscreen advance, then reservation ordering, cancellation on disappearance and a dead judge, rejection of actions after cancellation, one-contact shield replay and save continuation, late-action rejection, terminal unlock, and routine restoration. The dead-judge addition was run separately after the full suite, passing in 4,284 ms. Godot world kernel matched 420/420 checkpoint hashes, all scenarios, and chronicle hash.

[run] The JavaScript live check passed 10 villages (five freed, all alive, 42 shields); save check passed 10 villages over six years, three reload points each (largest save 766 KB); storm check passed 20 villages at pace 10 (20 storms, 97 ancestors, 99 lost, 17 carried and five rescued rites). The JavaScript lifecycle source check also passed. Raw stdout, stderr, exit code, and elapsed milliseconds for each command are adjacent to this file.

[run] The three Tale books were regenerated once with their original seeds (1000 Wenbrook, 8919 Harrowmere, 16838 Ashcombe), 1,000 years, three tales per century, and the generator's every-97-year storm plan. They now contain 24, 23, and 27 tales respectively. A separate in-memory audit found **exact byte equality** for every book, zero invalid earlier-event cause links, zero selected roots without a cause, and zero selected roots without a cue. Prior blob hashes are retained in `original-artifact-hashes.txt`, so their earlier versions remain available through Git history.

```powershell
node docs/studio/evidence/continuation/final-rules/verify-clemency.mjs
node tools-src/studio/village-reference/golden.mjs game/scripts/studio/village/sim/golden_data.gd
node tools-src/studio/village-reference/book.mjs 1000 1000 docs/studio/tales/wenbrook-1000-years.md 3
node tools-src/studio/village-reference/book.mjs 8919 1000 docs/studio/tales/harrowmere-1000-years.md 3
node tools-src/studio/village-reference/book.mjs 16838 1000 docs/studio/tales/ashcombe-1000-years.md 3
node docs/studio/evidence/continuation/final-rules/audit-books.mjs
$godot = 'C:\Users\hilmi\AppData\Local\UnboundStudio\tools\godot\Godot_v4.7.2-stable_win64_console.exe'
& $godot --headless --path game --import
& $godot --headless --path game --script res://scripts/studio/run.gd -- village/sim/conformance
& $godot --headless --path game --script res://scripts/studio/run.gd -- village/sim/runtime_test
& $godot --headless --path game --script res://scripts/studio/run.gd -- village/sim/actions_test
& $godot --headless --path game --script res://scripts/studio/run.gd -- village/sim/lifecycle_test
& $godot --headless --path game --script res://scripts/studio/kernel/run.gd -- --conform
node tools-src/studio/village-reference/lifecycle-test.mjs
node tools-src/studio/village-reference/invariants.mjs 20 1000 1
node tools-src/studio/village-reference/live-test.mjs 10
node tools-src/studio/village-reference/save-test.mjs 10 6
node tools-src/studio/village-reference/storm-test.mjs 20 10
```

[repo] Ownership was restricted to the new typed `lifecycle_test.gd` and its UID, the generated `golden_data.gd`, the three generated Tale books, and this evidence folder. Godot import also generated untracked `checks_probe.gd.uid`, `measure_probe.gd.uid`, and `actions_test.gd.uid`; those are outside this helper's ownership and were left for the parent. No rule, live-scene, normal-save, phone, or export change was made by this helper.

[run] The parent explicitly requested `gpt-6-sol` and its launch was accepted. This process has no serving-model identifier with which to verify the exact backend subtype independently; none is inferred.
