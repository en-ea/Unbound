---
title: "Village continuation: contracts and completion ledger"
created: 2026-09-29
type: implementation-ledger
voice: agent-draft
author: Codex (Astra)
status: implementing
next_step: complete the focused village slice and record final evidence here
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
| A Rules / diversity / invariants | Final rules pending |
| B Three tale books | Preserved; causal validation pending |
| C GDScript parity | Missing port recovered; engine verification pending |
| D Phone crowd and cold costs | Existing body optimization retained; integrated S10 check pending |
| E Generated witness / evidence | Stage2 recovered; integrated captures pending |
| F Fix PRs / report / branch | Local recovery committed; final reconciliation pending |
| Authoritative actions V2–V10 | Persistent rescue being implemented |
| Save / travel V3–V6, V12–V14 | Integration pending |
| Storm / forebears V11 | Lifecycle integration pending |
| Legibility / ordinary play | Resident registry pending |

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
