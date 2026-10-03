---
title: "People rebuild - status for Enea"
created: 2026-10-03
type: status-note
voice: agent-draft
author: Codex, Foundations integration and delivery lead, Hilmi's studio
status: Foundations built locally; Body/Mind/animation implementation underway; integrated delivery pending
next_step: Enea and his agents read this status; studio integrates the three workers and reports the playable result and marked proposals
---

# People rebuild: where the studio is now

**3 Oct [chat/repo]:** Hilmi has moved the people work from planning into implementation. Foundations are built locally; two Codex leads are now building physical actions/controls and perception/memory, while Claude implements the actual animations and rigging. The goal is a connected, expressive encounter in ordinary play. This update publishes the status document and a start-page link only. The new game code remains on local `pass3` and isolated worker branches; checking out the remote `studio` branch does not yet give you this rebuild.

[chat] Hilmi's direction is: "We want this dark, funny and incredibly interactive in a fluid way - not clicking buttons like those types of games." He wants characters to have reusable physical capacities and different motives, rather than a new scripted reaction for every incident. He also wants the overall phone buttons redesigned; flicks are promising but unfinished. Existing Heavy/hold/flick bindings are interim, not an agreed final scheme.

## The encounter being built

[design] A carried load brushes one of two talkers; a deliberate shove or strike hurts someone. The victim responds from remembered history. A friend who saw the act steps in; a timid witness goes for help, and the helper actually travels, arrives and makes their own choice. A distracted worker notices later, with only the evidence they could have captured or subsequently observed. Repeated aggression changes the response and can cause a planted fall and recovery. Leaving and returning keeps the deed; a gift can soften hostility without erasing it.

[design] Direct fire exercises the same route: a burning person can choose reachable water; another person can choose to help, travel there and physically extinguish them. Neglect can leave a corpse that later observers discover without being told who caused it. The humour should come from different motives, timing and qualified misunderstandings. These beats are a delivery target, not a claim that the current integrated game already achieves them all.

## What has actually been built

[repo/run] The local Foundations spine follows [PEOPLE-ARCHITECTURE.md](PEOPLE-ARCHITECTURE.md): body, perception, inner state, choice and seams with your game.

- General actor/action/contact records are independent of buttons and gesture directions. Live sensing measures the event, sufferer, emitter and apparent actor separately; a heard cry or seen corpse does not automatically identify an aggressor.
- Root actions, consequences, ready witness memories and semantic progress share one checked save before acceptance or effects publish. A failed write publishes nothing; retained keys make retries idempotent. Existing injury, rule death and the reflective save codec remain their owners. Pose/animation frames are not saved.
- One movement owner and composable physical constraints underpin body expression and smooth continuation from actual position. Helpers keep their own chooser. Concrete water destinations, standable routes, contact and checked extinguishing seams exist; the complete integrated journey still needs demonstration.
- Elements, stimulus sources, offers and modifiers use discovered files/data rows. Appearance modifiers compose as patches rather than restoring hidden identity. Condition sources declare the accepted facts they can observe; attention delay is a modifier port, not a named special case. Idle semantic work uses cached deadlines instead of repeatedly scanning everyone.
- Migrated incidents have one state/choice authority. All 26 inherited reaction modules are preserved behind the explicit compatibility boundary for unmigrated content; pillory release remains. Version 5.0, inherited/generated UIDs and dormant work are preserved.

[repo] Exact local checkpoints: initial Foundations product `ebf2a3a18e666fb1ce0f28241f59a6ac79ce7815`; frozen independent planning input `84851a1ca13c1a684705df7519d78ba3dbe1e4da`; shared integration base `cff40b71a7bfeddb889f4da1842b775d432e95d2`; corrected worker base **`75ef0f35f7b0b5ea21ffa02977b019f0f6865775`**. These new commits are local, not published by this document. Their actual headers/index are in local `docs/studio/PEOPLE-CONTRACTS.md`; implementation/build records distinguish built contracts from remaining work.

## Who owns the current work

[chat/repo/design] All four independent Body/Mind proposals were completed and preserved before selection. The chosen builders synthesize compatible ideas, not the union of both plans. The three workers use distinct worktrees of this game repo and exclusive files.

| Role | Current responsibility |
|---|---|
| Codex Body lead | Controls, measured contact/capability, force versus injury, physical runtime, constraints and fact reconciliation. Publishes the real element/pose port before dependent visual work. |
| Codex Mind lead | Honest evidence/attention, temperament, affect, appraisal, episodes/stances and expression hints. Must prove additional knowledge within the same evidence channel becomes the correct saved belief once. |
| Claude animation/rigging | Actual pose/body/element visuals, rig/clip work and reproducible studio assets against Body's implemented port. Uses existing rigs/UAL clips first; Blender where useful. |
| Foundations integration lead | Shared schema/action/stimulus/acceptance seams, local integration of original worker commits, contract index, connected encounter evidence and final delivery. |

[design] Mind chooses no animation clip or destination; physical elements choose no goals and create no separate injury/save model. Body supplies capability and actual contact; choice supplies goals. The specialist can inspect/prepare immediately; dependent changes wait until Body's actual port is incorporated into a named integration base.

## Your code and the proposals

[repo/design] Your authored characters, rigs/art, enemy brains and native combat remain yours. Current local marked `# studio:` proposal hooks are:

| File | Purpose |
|---|---|
| `game/scripts/player/fighter.gd` | Interim ordinary Heavy contact reaches eligible unsquared residents, with stable contact keys and existing landed-hit feedback. |
| `game/scripts/player/abilities.gd` | Meteor's actual landing reaches village bodies through one checked fire/contact route. |
| `game/scripts/core/save_game.gd` | Exposes the real write result so accepted batches publish only after success; isolated checks use separate save paths. |

[design] Body's ongoing work may add marked player/core/UI/carry hooks as the controls are reconciled. The final handover will list the actual changed proposal files/lines. New visual assets are scoped studio assets, not an overwrite of your inherited art. Missing scream/limb assets remain explicit future seams. Nothing in this status is your approval of those proposals or a merge into `main`.

## Evidence, limits and what comes next

[run] The original local slice exercised the connected encounter, return/gift/save-load and a second Meteor stimulus, produced a hidden before/after board and a normal signed Foundations r2 build installed on Hilmi's phone. His phone judgement remains pending. The latest corrections passed 34 focused game checks (16 shared, 18 state/extension/forward), including composed masks, a one-file condition, anonymous corpse memory, checked hearing-to-sight improvement after failed-save retry/codec reload, and no idle deadline scan/save. Failed attempts remain recorded.

[run/design] Those checks do not establish the fuller Mind evidence/residual appraisal, finished controls/rig, natural humour or phone feel. The previous board's small crowded frames were insufficient evidence of timing; the integrated delivery needs clearer larger beats. Whole desktop acceptance measured 33.050 ms median/49.823 ms maximum: the full-save/clone hitch remains an explicit later step 4 issue, not solved by delaying accepted memories. Co-op, factions, captivity, larger situations and other lands are not being built in this slice.

[repo/design] Heavy engine/Blender work is serialised, hidden/background and admitted only after all active editors acknowledge a pause, with native platform thermal-zone/load/memory gating and cooldown. This is a development safeguard, not a performance or quality verdict.

[design] Next: integrate Body's real port, advance the specialist's preserved checkout, integrate the three owned implementations, and exercise the actual helper/contact/recovery/return/gift/fire/rescue/death route. Deliver readable hidden before/after evidence and one normal studio-key build for Hilmi's play, with current-data backup and a fresh installation yes. Choice planning waits for the actual integrated contracts; Voice/World follow their real prerequisites. The studio will report the resulting commit, evidence, remaining limits and marked proposals through Hilmi before any proposed landing into your main game.
