---
title: M2 long-form village sweeps and preserved books
created: 2026-09-29
type: evidence
voice: agent-draft
author: Codex helper
status: checked with diversity and book drift failures
next_step: Parent decides how to address case-ending variety and whether to refresh the historical tale books after the fixed rules settle; use the six verified fixtures for capture.
---

## Verdict

[run] The original long-form invariant, live, save, and storm checks passed on the parent candidate `fce94d0`. The original ending-diversity target failed in eight of twenty villages when each village's **total cases** are the denominator. The three preserved tale books carry their recorded seeds and causal source labels, and the tales selected by the current source have valid cause links and cues, but their bodies do not match books regenerated in memory from the current rules. The original books were not replaced.

[run] `node tools-src/studio/village-reference/invariants.mjs 20 1000 1` exited 0: 20 villages × 1,000 years, 176,922 events; causes/cues, child victims/throwers, integer state, cases, population, violence budget, and determinism passed. `live-test.mjs 10` exited 0: 10 villages, five freed and all five alive, 38 pillory shields. `save-test.mjs 10 6` exited 0: 10 villages over six years, three save/reload points each, maximum save 836 KB. `storm-test.mjs 20 10` exited 0: 20 villages at pace 10, determinism, child offering, recession, and anchored exemption passed. Their complete output and exit files are adjacent to this note.

```powershell
node tools-src/studio/village-reference/invariants.mjs 20 1000 1
node tools-src/studio/village-reference/live-test.mjs 10
node tools-src/studio/village-reference/save-test.mjs 10 6
node tools-src/studio/village-reference/storm-test.mjs 20 10
node docs/studio/evidence/continuation/sweeps-m2/ending-diversity.mjs
node docs/studio/evidence/continuation/sweeps-m2/audit-books.mjs
node docs/studio/evidence/continuation/sweeps-m2/fixtures.mjs
```

[run] Ending diversity used the same 20 seeds (`5000 + s × 7919`), pace 1, 1,000 years, and every-97-years storm plan as the invariant runner. The denominator was `V.cases.length` separately for each village, as specified in `docs/studio/VILLAGE-PLAN.md`. Across all villages: **3,561 cases**; original `V.stats.outcomes` categories were `acquitted` 940, `carried_out` 1,391, `commuted` 207, `confessed_spared` 834, and `crowd_turned` 111. Their sum is 3,483, leaving 78 cases with no `stats.outcomes` category at the final checkpoint. The aggregate `carried_out` share is 1,391/3,561 = 39.06%, but eight individual villages exceeded 40%:

| Seed | Largest ending | Count / all cases | Share |
|---:|---|---:|---:|
| 5000 | carried_out | 89 / 203 | 43.84% |
| 36676 | carried_out | 53 / 119 | 44.54% |
| 68352 | carried_out | 71 / 166 | 42.77% |
| 100028 | carried_out | 89 / 209 | 42.58% |
| 107947 | carried_out | 62 / 134 | 46.27% |
| 115866 | carried_out | 105 / 238 | 44.12% |
| 131704 | carried_out | 75 / 178 | 42.13% |
| 147542 | carried_out | 90 / 194 | 46.39% |

[run] A separate bounded diagnostic replay records closed and pending cases explicitly in `endings-case-state.stdout.jsonl`; the first diversity output is preserved in `endings.stdout.jsonl`. At the final checkpoints **all 3,561 cases were closed and zero were pending**. The 78 cases absent from `V.stats.outcomes` were therefore closed without one of its recorded ending categories. They are reported as unclassified, without assigning them a new ending. `rescued` and `venerated` did not appear as `stats.outcomes` keys in these headless runs.

[run] Book verification used each recorded seed (1000 Wenbrook, 8919 Harrowmere, 16838 Ashcombe), 1,000 years, three tales per century, the generator's every-97-years storm plan, and its village name. All three preserved headers retain the correct seed and `generated`/`agent-draft` status. Current-source generation produced 26, 26, and 27 selected tales, while the preserved books contain 15, 20, and 19. The first differences are:

| Book | Body character | Preserved next tale | Current source next tale |
|---|---:|---|---|
| Wenbrook | 1,764 | Year 112: Colm's Fine | Year 52: The Stones That Were Not Thrown |
| Harrowmere | 1,843 | Year 2: Isk in the Pillory | Year 1: The Night at the Stone |
| Ashcombe | 812 | Year 51: The Offering of Orla | Year 16: Marjory's Fine |

[repo] The Wenbrook and Harrowmere book blobs exactly match their last generator-touch commit `0b68f95`; Ashcombe exactly matches its last touch `5a87827`. Since those commits, reference rules and tale-selection code changed. The current source's selected roots had zero invalid earlier-event links, zero missing root causes, and zero missing root cues in all three villages. This verifies provenance labels and causal links; it does **not** verify current-source body equality.

[run] Six verified public/rite capture candidates from the existing generated `sim_stagings.gd` fixture were replayed under its source seed/storm inputs. The event IDs are from the current JavaScript reference; every event had a cue and nonempty cause IDs:

| Scene | Seed | Day | Staging ID | Event ID |
|---|---:|---:|---:|---:|
| Pillory with mud | 48514 | 156 | 46 | 303 |
| Pillory, crowd turned | 24757 | 415 | 63 | 313 |
| Bonfire | 32676 | 105 | 7 | 22 |
| Hanging | 40595 | 65 | 11 | 57 |
| Exile | 16838 | 110 | 12 | 66 |
| Rite carried out | 16838 | 52 | 2 | 16 |

[repo] Four original runners printed `FAIL` without a nonzero process exit. Their only code change in this packet is setting `process.exitCode = 1` when their existing failure arrays are nonempty. No rules, goldens, generated books, or game code changed.

[run] The helper was explicitly selected as `gpt-6-sol` by the parent task, but this process exposes no serving-model identifier. The actual serving model cannot be independently introspected here.
