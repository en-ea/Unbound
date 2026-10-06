---
title: M2 typed village action parity
created: 2026-09-29
type: evidence
voice: agent-draft
author: Codex helper
status: checked
next_step: Parent integrates the port with live presentation and confirms the final candidate on device.
---

## Verdict

[run] The typed Godot port of the fixed reference action contracts passes its runtime and action tests, the historical village golden checks, the live and storm village checks, and world-kernel conformance. The four final test commands below exited 0 with empty stderr. Raw stdout, stderr, and exit records are adjacent to this file.

```powershell
$godot = 'C:\Users\hilmi\AppData\Local\UnboundStudio\tools\godot\Godot_v4.7.2-stable_win64_console.exe'
& $godot --headless --path game --script res://scripts/studio/run.gd -- village/sim/runtime_test
& $godot --headless --path game --script res://scripts/studio/run.gd -- village/sim/actions_test
& $godot --headless --path game --script res://scripts/studio/run.gd -- village/sim/conformance
& $godot --headless --path game --script res://scripts/studio/kernel/run.gd -- --conform
```

[run] Runtime: last-minute public rescue, range rejection, duplicate receipt, immediate save/load, midnight, and canonical future continuation PASS. Actions: pending hearing, unique testimony source, acquittal after trace, bounded bribe and refusal, receipt replay through save/load, planted trace discovery and observer consequence, rite preparation/rescue/inaction/recession, anchored exemption, and canonical continuation PASS. The bridge also asserts the source reference's cycle-1 result for seed 16838: epoch 21, source 0, enclave 12, displaced 17, past 0, hash `22a8b05d`.

[run] Historical village: all three 10-year cases passed 20 checkpoints each across six columns. Live: 10 deterministic villages, five rescues still alive. Storms: 20 villages, recede and anchored checks PASS. Kernel: 420/420 checkpoint hashes, scenario hashes, and chronicle hash PASS. A first import found one Godot `mini()` arity error, repaired before tests. An initial action test compared pre- and post-JSON numeric encodings directly; the test now compares normalized codec output as the existing runtime test does. Both initial records remain for diagnosis.

[repo] Source reference was commit `2f0b94e4bb54fe0f33ac87a23158e8627ee1343f` relative to frozen `882c35d9de141372831745a13c700ff97ea54ab6`, plus the parent's two explicit same-clock corrections: witness lists include the accuser, shield contact opens at the throw time and stays valid until event deadline, and opening boundaries activate before intervening daily plans. At runtime rite preparation, captivity begins at the night opening, rather than at daytime seizure planning. A generated `storm_bridge.gd.uid` remains untracked because UID files were outside this helper's assigned ownership; the parent can account for it before final integration.

[repo] The port keeps `Sched` in event `source`, exposing `source.case_id` for hearings and `source.who` for rites. Place names are converted to internal IDs only at simulation boundaries. `Storm.kernel` stores the existing `History`/`World` transition dictionary, and the existing typed save codec serializes it. Accepted actions return receipts with replayable coin, wood, or damage costs. No JS source, golden files, live scene code, or normal save code was changed by this helper.

[run] The helper was explicitly selected as `gpt-6-sol` by the parent task, but this process exposes no serving-model identifier; actual runtime model introspection remains unavailable.
