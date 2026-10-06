---
title: "Village continuation: contracts and completion ledger"
created: 2026-09-29
type: implementation-ledger
voice: agent-draft
author: Codex (Astra)
status: engineering complete locally
next_step: Hilmi reviews the delivered build for feel and separately decides whether to publish studio
---

## Contracts [design]

The persistent runtime owns integer absolute game minutes. Daily rules plan; due event transitions commit. Input admitted strictly before a deadline commits immediately; input at the deadline is late. Rendering cannot extend a deadline. Pause/background and app closure freeze village time. Region loading rebuilds presentation; time continues during play elsewhere.

Commands name the village, event, local player and a unique action ID. Receipts make retries harmless. A freed resident escapes to a refuge for two days, retaining identity and the authority grievance; the body follows that destination. A stage's finish signal has no authority. Pending acts and all future-affecting state are saved. Recent terminal events are retained seven days and receipts 256 actions; monotonically increasing event IDs reject older commands.

## Recovery [repo]

- `23abab8`: preserved previously untracked live bridge and night report.
- `d11047a`: merged all five staging commits ending at `a7c350f` without rewriting history.
- `c019320`: imported the missing reference fixes, from Sol commit `0bbccbd`.
- Existing worktrees and their untracked UID files retained. Remote checked once: `origin/main` advanced to `b9618d6`.
- Helper launched with explicit `model: gpt-6-sol`; tool accepted selection. Helper sees generic GPT-6 identity; exact subtype is not independently exposed by helper introspection.

## Ledger

| Requirement | Status / evidence |
|---|---|
| A Rules / diversity / invariants | Complete `1a8f000`, `3ae594f`: 20x1000 final invariants; zero diversity failures, case denominator and unclassified cases disclosed in `final-rules/README.md` |
| B Three tale books | Complete `3ae594f`: original seeds, refreshed examples, exact regeneration and causal-link audit; original blobs preserved |
| C GDScript parity | Complete: PC `3ae594f`, added source/gesture tests `3554d91`; final S10 source `17c1f06` matches all 3 x 20 x 6 golden checkpoints, plus live/storm suites (`s10-final/FINAL-RESULTS.md`) |
| D Phone crowd and cold costs | Complete: PC `a2e9f92`, `3554d91`; repaired S10 `b1e0c5f` completes 120/900 seconds with stable memory; final `17c1f06` 45 walkers pass capped/uncapped. Cold hitches and thermal throttling disclosed; 60 remains historical stretch evidence |
| E Generated witness / evidence | Complete `f4e0e9b`: eight inspected captures, seed/minute/event index; board `evidence/witness/CONTINUATION.md` |
| F Fix PRs / report / branch | Complete locally: main/fix PRs reconciled at `b9618d6`; source `17c1f06`, Web package `6c4667b`, ordinary Android APK and final report with hashes. No push authorized |
| Authoritative actions V2–V10 | Complete `882c35d`, `2f0b94e`, `4d3fa68`, `1a8f000`, `3554d91`: acceptance matrix below |
| Save / travel V3–V6, V12–V14 | Complete `5ebc55a`, `a2e9f92`, `e714c93`: actual save, touch input, airborne-pause and scene replacement checks |
| Storm / forebears V11 | Complete `2f0b94e`, `fce94d0`, `4d3fa68`: kernel transition, reversible district and interruptible rite, checked in `final-rules/` |
| Legibility / ordinary play | Complete engineering checks: named registry/actions `4d3fa68`, captures `f4e0e9b`, Web/phone touch `e714c93`, conditional trace cue `17c1f06`; natural first hearing at 763.936s without seeking. Human feel remains owner review |

Publication: this continuation has no blanket push authorization. Finish and commit local engineering first. No merge into Enea's main or outward message is authorized.

## M1 evidence [run]

`node tools-src/studio/village-reference/runtime-test.mjs`: PASS last-minute rescue, range rejection, duplicate, deadline rejection, midnight, full save continuation.

Godot `--headless --path game --script res://scripts/studio/run.gd -- village/sim/runtime_test`: PASS typed state codec and canonical continuation.

Godot `--headless --path game --quit-after 600 -- --studio=village/live --village-soon --village-rescue-test --test-save=rescue`: PASS real input twice, immediate normal save/load, midnight, actual region reload/return. This rendering-disabled run emits existing item-icon null texture errors; a rendered candidate check remains required. Uses `user://studio-test-rescue.json`, never the owner's save.

Godot runtime recovered by helper at the documented UnboundStudio path, official 4.7.2. Baseline village: three cases × 20 checkpoints × six columns, 10 live villages and 20 storms PASS. Kernel: 420/420 checkpoints and all scenarios PASS. S10 `R58N53475EH` detected; measurements pending.

`origin/main` through `b9618d6` integrated into studio before normal-game hooks, retaining Wren, Brakk, Morrow and quests. Existing fixes imported without rewriting their branches: safe saves `d9cc90c`, safe area `1c4611c`, swipe exit `9b7ecf3`.

## M2 integration [repo/run]

`2f0b94e` fixes the reference contracts for undecided hearings and rites, bounded influence, original-source evidence and local trace discovery. `fce94d0` imports Sol's matching GDScript port and raw baseline/action/kernel results in `evidence/continuation/parity-m2/`.

The next integration commit supplies nearby action buttons, lineage/rescue barks, physical traces, storm props, logical-time resident routes, explicit live endings, cold rig-template reuse and typed village recovery. Public acts decide at the first irreversible ending; lethal stoning cannot resolve before its throws. Live stages suppress predicted endings and show the authoritative result. Trace discovery excludes travelling residents and residents currently embodied in an event elsewhere.

Rendered normal rescue with `--village-soon --village-rescue-test --test-save=rescue-m3` passed real input, immediate save/load, midnight, region reload and return with no engine warnings/errors (`evidence/continuation/integration-m2/rescue-rendered.txt`). Runtime codec/continuation and JS/GDScript action tests pass. Broader integrated acceptance, captures and S10 measurements remain pending; this is not yet the final candidate.

## M3 closure [design/run]

The recovered diversity criterion failed in 8/20 villages (original results retained in `sweeps-m2`). A concrete clemency rule now lets a merciful elder lower a non-grave sentence after repeated carried-out punishments. It cannot relabel a minimal fine, override a grave offence, or override a player acquittal. The actual law-list sentence changes and the existing commutation event records it. Repeating the original 20x1000-year case-denominator audit now gives 0/20 failures: 3,767 cases; carried_out 1,287, acquitted 944, confessed_spared 918, commuted 444, crowd_turned 91. The 83 closed cases without an outcome statistic remain explicitly unclassified, not renamed. Golden hashes and books must be regenerated for this intentional rules change.

Normal rendered checks passed legacy-save migration, malformed/truncated-file backup recovery, core progress retained without a valid village backup, menu/background clock freeze, actual gathering and combat input, down/locked rejection, and accepted/refused bribe debits through the live adapter plus immediate disk reload. The first run includes the deliberate truncated JSON diagnostic; `_read` now uses the quiet parser error return while trying backups. Raw first evidence retained. `lifecycle-test.mjs` passes three seeds x eight days of minute-chunk vs offscreen-jump full canonical equality, reservations, disappearance, bounded shield/replay/reload, late free, restraint clearance and routine restoration. Hearings allow ninety real seconds to investigate and return.

## Acceptance matrix [run]

Evidence paths below are relative to `docs/studio/evidence/continuation/`. Earlier failing/diagnostic outputs are deliberately retained; a newer passing file supersedes its specific gate, not every earlier result.

| ID | Implemented check and evidence | Commit / limit |
|---|---|---|
| V1 | `final-rules/godot-conformance.stdout.txt`, `kernel.stdout.txt`: 3 x 20 x 6 village columns; 420 world checkpoints and scenarios. Intentional clemency changes only the live-pace golden after day 120. Final S10 repeats the 3 x 20 x 6, live and storm checks. | `3ae594f`; phone source `17c1f06`, `s10-final/FINAL-RESULTS.md` |
| V2 | `delivery/boundaries-rendered.txt`: actual offered Free button at deadline minus one, Attack cannot steal it, duplicate, midnight, alive/unlocked. Runtime test rejects exact-deadline input. | `882c35d`, `a2e9f92` |
| V3 | Same run: immediately saves through normal SafeFile and reloads before departure animation completes; preserves resident identity/refuge. Bribe wallet also restored in `merchant-purchase-final.txt`. | `5ebc55a`, `a2e9f92` |
| V4 | Actual forest/meadow reload both after rescue and during an untouched event, return before/after deadline; full headless state comparison and no stale stage. `delivery/boundaries-rendered.txt` | `a2e9f92` |
| V5 | Same run freezes an actual airborne generated prop's phase/time/position plus player health and outcome for menu and background. Logical-time jumps verified by full canonical lifecycle checks. | `a2e9f92`; no offline wall-clock advancement |
| V6 | `final-rules/lifecycle-dead-final.stdout.txt`: deterministic shared actor/venue delay; absent/dead judge cancels, testimony/bribe rejected, terminal unlock. Registry borrows existing bodies. | `1a8f000`, `3ae594f` |
| V7 | Two living speakers retell one source, player gains one clue, elder receives one contribution, other residents do not learn it, a fresh action ID for the same source is rejected. JS and GD `delivery/retell-offer-*.txt`. | `3554d91` |
| V8 | Actual live adapter with receptive/unreceptive judges, rapid duplicate input, single five-coin or zero debit and immediate normal reload. `delivery/merchant-purchase-final.txt`. | `5ebc55a` |
| V9 | `final-rules/godot-actions.stdout.txt`: observed/unobserved planting costs one wood, no instant belief, actual eligible local finder after fifteen logical minutes, observer-specific grievance. | `2f0b94e`, `4d3fa68`; controlled finite fixtures |
| V10 | `final-rules/lifecycle-dead-final.stdout.txt`: one recorded throw contact, replay idempotent, other throw untouched, save/reload continuation, late Free rejected. Actual flight pause separately V5. | `1a8f000`, `3ae594f`; human shield positioning feel pending |
| V11 | `final-rules/godot-actions.stdout.txt`: prepared rite alive, rescue/ignored/reload, original residents return, ancestors recede, mid-event recession cancels, anchored exemption, kernel transition hash. `delivery/retell-offer-godot.txt`: gesture accepted/refused, one cost, no leader grievance for gesture, Free remains after refusal. Captures 07/08. | `fce94d0`, `f4e0e9b`, `3554d91` |
| V12 | `delivery/touch-menu-final.txt`: real resource hit, combat start, down/locked rejection, touch plus emulated mouse opens merchant once, hidden finger releases, priced Buy debits/closes. Rescue button priority V2. Web Play, movement, Craft, Save and reload inspected (`delivery/INPUT.md`). | `e714c93`; actual iPhone feel untested |
| V13 | `final-rules/lifecycle*.txt`: 3 seeds x 8 days, small varied steps versus one offscreen jump, entire typed canonical state. Action snapshots compare post-rescue/testimony/rite futures. Actual region-stage case V4 agrees with headless clone. | `1a8f000`, `3ae594f`, `a2e9f92` |
| V14 | `delivery/merchant-purchase-final.txt`: legacy no-village save, new atomic save, malformed village and truncated JSON backup, no-valid-backup core progress plus notice; all files use isolated names. | `5ebc55a` |

## Final rules and device gate correction [run/repo]

`3ae594f` records the completed invariants, regenerated goldens, three books and causal audits. The old M3 note above saying they "must be regenerated" is now fulfilled. `af7d233` removes invalid `.unbind(0)` merchant/cooking callbacks; the first purchase probe accidentally selected the Buy tab and failed. `5ebc55a` corrects that probe to a priced Buy button and passes all eighteen normal integration assertions with no engine errors. Both outputs remain for provenance.

`a2e9f92` extends the real rescue probe to airborne pause and untouched active-event travel. `3554d91` adds explicit multi-speaker provenance and gesture branches and hides resident captions in menus. Web export succeeds with the official 4.7.2 nonthreaded templates; the missing-template and missing-folder attempts remain in `delivery/` and are not passes.

`e6aff96` preserves a **failed** S10 arrival run: foreground rendering froze after rapid native-heap growth, then an MSAA framebuffer allocation failure and native out-of-memory messages. No completed phone probe exists for that candidate. `2ef8d72` adds ten-second memory/object/resource/viewport samples and a diagnostic-only no-MSAA option to distinguish the source. The 900-second normal run and fresh 45-body gate wait for the repaired candidate. This is an engineering issue being closed, not an owner feel question.

## Final interaction repair [repo/run]

`e714c93` closes an observed web touch/mouse boundary: the same opening gesture could immediately dismiss a crafting or merchant panel. The action button now consumes its emulated mouse press and releases its held finger even while hidden. The expanded rendered check passes twenty assertions, including a real priced purchase. Web Play, Craft, Done, Save, reload and resumed named residents were inspected. `delivery/INPUT.md` preserves the original event log, final screenshots and failed probe output. The final Web export and SHA256 manifest name `e714c93`; no rule or performance change followed `b1e0c5f`.

## Final device and delivery closure [repo/run]

The repaired S10 completed both uncapped integrated runs on `b1e0c5f`: 120-second arrival and 900-second ordinary cadence, zero background samples, stable native heap and no allocation failure. Cold maximums were 311.736/306.768 ms; steady median/p95 were 16.972/21.682 ms and 20.036/33.648 ms respectively. The long run reached severe skin thermal status, explicitly included in the result. Stage timings include acquisition; resident construction and whole frames are reported separately in `NIGHT-1.md`.

Final source `17c1f06` passes the new 45-body S10 gate (uncapped median/p95 25.3/32.1 ms; capped 33.4/36.5 ms), on-device village/live/storm conformance and all twenty normal-save/touch assertions. The natural assault hearing exposed a misleading cue promising a trace; `17c1f06` conditions that phrase on actual evidence. No simulation or performance code changed after the measured guard. No long benchmark was repeated for this wording fix.

`6c4667b` packages the final Web export in tracked `web/`; equivalent `build/web/` and `build/android/unbound-village-17c1f06.apk` are the local playable artifacts. Exact SHA256 manifests are in `delivery/`. This supersedes the earlier `e714c93` export identity and all pending device notes above. The final packet is `s10-final/FINAL-RESULTS.md`; the original failed gate remains a historical record. Owner feel and actual iPhone Safari/offline checks remain explicitly external, with a runnable play route in the finished night report. Publication, main merge and outward messages were not authorized or performed.

`44a8ba8` imports Sol's final device packet (`3d48ab3`). Astra independently inspected both completed measurement JSONs, the saved phone conformance and twenty-input-check reports, both crowd results, the natural hearing screenshot and the restored ordinary title screen; the copied APK checksum matches the installed raw artifact. The S10 has the ordinary game installed without test arguments. This closes the original A-F engineering ledger and V1-V14 packet; the stated cold-hitch, thermal and external-owner limits remain.
