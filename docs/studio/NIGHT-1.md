---
title: "Night 1 - the village lives: what was built, what it measured, what is left"
created: 2026-09-29
type: agent-draft
voice: agent-draft
author: Codex (Astra), continuing Claude's preserved night work
status: implementation complete locally; final device repair verification in progress
next_step: finish the recorded device gate, then Hilmi reviews feel and decides separately whether to publish studio
---

# Night 1: the village lives

## 1. Verdict

[repo/run] The focused village is integrated into ordinary Unbound play on local `studio`. The player can investigate an accusation, carry testimony to the elder, offer a bounded bribe, plant locally discoverable evidence, shield one projectile, free a captive, or approach a forebear rite with a wood gesture. Hearings and rites remain undecided during their intervention windows. Accepted actions change the persistent person immediately, before the visible reaction.

[run] Rescue survives duplicate input, midnight, immediate normal disk save/load and actual region replacement. A generated airborne prop, player health and event outcome all freeze in menus/background. Untouched offscreen events resolve identically to their headless continuation. A rescued resident appears at the far-woods refuge and remembers the player. Normal gathering, combat and an actual merchant purchase pass the integration checks.

[run] The first S10 gate found rapid native-memory growth and a frozen renderer. A bounded comparison isolated MSAA: capped MSAA reached 2.44 GB native heap by 55 seconds, while uncapped no-MSAA stayed near 186-190 MB; game objects and reported game memory stayed flat in both. `b1e0c5f` disables that failing path only on Android's Mali-G76 Compatibility renderer. The repaired candidate's full device result is recorded in the final delivery entry below when complete. The failed candidate is preserved, not called a pass.

[repo/chat] All recovery and implementation milestones are committed locally. No push, main merge or message to Enea was made. This is one playable slice, not the entire game or multiplayer.

## 2. What to look at first

[repo] Read the [witness board](evidence/witness/CONTINUATION.md) for the visible sequence and the [completion ledger](CONTINUATION.md) for exact V1-V14 evidence. The eight native captures show ordinary residents, a theft hearing, an accessible doorstep trace, Free at the restraint, accepted rescue, the same Hawise at refuge, forebears and a rite, then recession. Captures seek separate generated fixtures; they are not natural-cadence or performance evidence.

[repo] Web is the immediate delivery target. The local export is `build/web/index.html`. Run `node tools-src/serve.js --local` from this game repository and open **http://localhost:8087/**. Loopback needs no certificate. The Android `Unbound Village` package is separate from the older studio app and keeps its data intact. Final build identities/hashes are recorded below.

```powershell
$unboundGodot = 'C:/Users/hilmi/AppData/Local/UnboundStudio/tools/godot/Godot_v4.7.2-stable_win64_console.exe'
# Ordinary play, normal save:
& $unboundGodot --path game
# Quick generated rescue opportunity, separate test save:
& $unboundGodot --path game -- --studio=village/live --village-soon --test-save=owner-rescue-demo
```

[design] Short play route: press Play, walk among the houses and merchant, gather or craft something, and approach named residents. When a hearing develops, Listen beside a witness, inspect the marked doorstep trace and return to the elder to Testify. A greedy elder may accept five coins; a principled one can refuse. Planting costs one wood and risks being seen. At a restraint, the normal action button becomes Free; standing in a projectile's path shields only that contact. Stone contact can cost a heart. Follow a rescued resident towards the far woods, near `(-70, -40)`. They hide there for two game days, then resume ordinary life; the authority retains its grievance. At a rite, cut the rope before dawn or try a one-wood gesture with its leader. A refused gesture still allows rescue.

[repo] One day is twelve real minutes. Menus/background/app closure freeze village time. Playing elsewhere continues it. Sleep/time jumps visit the same due boundaries. Actions strictly before a deadline may be accepted; at the deadline they are late. A ninety-real-second hearing allows investigation. `--village-soon` deliberately seeks an event; omit it when judging cadence. Use a fresh `--test-save` name for a fresh scenario.

## 3. What was built

```
 village rules (JavaScript spec)            tools-src/studio/village-reference/
   people, households, lineages, day plans, crime (motive + opportunity + inhibition), sightings,
   gossip, 2-source accusations, trials (confession trade, millpond ordeal, trial by combat), public acts
   with crowds (threshold cascade), rescue windows, aftermath (grudges, feuds, guilt, confessions,
   the wrongly exiled come home), a pacing director, time storms with forebears and their rites
        |                      |                        |
        | golden hashes        | stagings (JSON)         | the Book of Tales
        v                      v                        v
 GDScript port (game)    stage (game)               docs/studio/tales/
 scripts/studio/          scripts/studio/village/    three villages x 1000 years
 village/sim/             stage.gd + VillagerBody
                          + props
```

[repo] Recovery: `23abab8` preserved the untracked live bridge and this unfinished report; `d11047a` merged all five night-stage commits through `a7c350f`; `c019320` recovered the missing reference port. Existing worktrees/UIDs were retained. Main was checked and integrated once through `b9618d6`, including Wren/Brakk/Morrow and quests, then the three existing phone fixes were imported without rewriting published branches.

[repo] `882c35d` supplies authoritative rescue, typed village saves, one clock and persistent identity. `2f0b94e`/`fce94d0` supply matching JS/GD undecided hearings/rites, provenance and storm contracts. `4d3fa68` connects nearby actions, local traces, ordinary routes and authoritative visible endings. `1a8f000` closes shared-actor/venue reservations, absence/death cancellation and real lesser-sentence clemency. `f4e0e9b` makes household evidence reachable at doorsteps. `af7d233` repairs invalid merchant/cooking callbacks, with a real priced Buy checked in `5ebc55a`. `a2e9f92` adds rendered pause/travel boundary evidence. `3554d91` verifies multiple speakers sharing one origin and accepted/refused rite gestures, and hides resident captions in menus.

[repo] Persistent records include event identity/revision, opening/deadline/end, participants, witness origins, reservations, recent receipts, standing/knowledge/grievances, refuge memory, storms and all future-affecting legacy simulation fields. Recent terminal events retain seven game days and receipts retain 256 actions; IDs never recycle. Normal atomic saves include village and wallet/inventory together. The typed codec preserves ordered structures without deserializing executable objects. Legacy saves keep player progress; bad village data tries valid backups, otherwise retains core progress and displays a recovery notice.

[repo] Ordinary residents and stage actors now use the same bodies and identities. Routes derive from logical trip progress and the existing obstacle paths. On region return, residents resume the same journey. The original merged meshes/detail tiers remain, with a shared stripped rig template to reduce cold construction. Construction is included in stage/whole-frame accounting.

[repo] The small storm bridge invokes the existing kernel transition and records its epoch/hash. Eligible ordinary round/hill districts may regress; anchored story NPCs and player possessions are outside that replacement. Forebears belong to the district's existing lineages. Recession cancels an obsolete rite and restores original inhabitants without undoing accepted rescue. No new models, animation set, camera system, navigation framework or networking implementation was added.

## 4. Measured

[run] Final rules: **20 villages x 1,000 years passed**, 181,300 events, survivors 13-54. Live: five of five rescues survive over ten seeds. Save: ten seeds x six years, three reloads, maximum tested save 766 KB. Storms: twenty seeds, 97 ancestors, 99 displaced residents, seventeen carried rites and five rescues. GDScript matches three village golden cases x twenty checkpoints x six columns; the world kernel matches 420/420 checkpoints and all scenarios. [Raw final rules packet](evidence/continuation/final-rules/README.md).

[run] Ending diversity originally failed in 8/20 villages. A merciful elder can now reduce a real non-grave sentence one level when carried-out punishments dominate; unchanged minimal fines and grave offences cannot be relabelled as mercy. The exact twenty-seed audit now has **zero villages above 40%**, using each village's total cases as denominator. Across 3,767 closed cases: carried out 1,287, acquitted 944, confession/spared 918, commuted 444, crowd turned 91. Another 83 closed cases lack a legacy outcome category and remain explicitly unclassified. None were pending. This finite sample is not a guarantee for every seed.

[run] The three books were refreshed once because the final rules changed their examples: Wenbrook 24 tales, Harrowmere 23, Ashcombe 27. Original seeds and thousand-year spans remain. Independent regeneration matched exact bytes and earlier causal links/cues. Original book versions remain in Git with recorded blob hashes.

[run] Rendered normal integration passes eighteen assertions for legacy/new/broken saves, gathering, combat, down/locked rejection, merchant opening/priced purchase/closing and bribe accepted/refused/duplicate/reload. Expanded rescue integration passes real input, immediate disk save/load, midnight, actual airborne pause and return before/after an untouched event's offscreen deadline. [Normal checks](evidence/continuation/delivery/merchant-purchase-final.txt), [boundary checks](evidence/continuation/delivery/boundaries-rendered.txt), [source/gesture checks](evidence/continuation/delivery/retell-offer-godot.txt).

[run] PC integrated arrival: Godot 4.7.2 Compatibility, RTX 3050 Laptop / Swift SFX14-41G, 1280x720, render scale 0.8, uncapped, 120 seconds, 31 bodies. Steady frame median/p95/max **6.706/9.828/55.865 ms**. First twenty seconds **6.514/19.357/505.805 ms**; the half-second cold hitch is included. Body construction median/p95/max **3.577/8.682/86.595 ms**. Stage including acquisition **0.076/0.206/8.878 ms**. Maximum 393 sampled draws; final static memory 119,926,262 bytes; boot before probe 7.068 seconds. All sampled `background` flags were false. [Raw arrival](evidence/continuation/delivery/pc-arrival.txt).

[run] The separate 45-walking-body PC benchmark reports 9.3 ms median, 37.9 ms p95, 42.3 ms maximum, 420 draws. It excludes four seconds of settling and had the web preview open in the background; this is not a dedicated-GPU or cold-construction claim. [Raw crowd result](evidence/continuation/delivery/pc-crowd.txt). The old S10 60-body result (20.9 ms median uncapped, 336 draws) justified keeping the optimization, but is not a substitute for the new integrated phone result.

[run] The first S10 failure and narrow comparison are preserved under `evidence/continuation/s10-final/`. Final repaired-candidate measurements are added below after verification; they are not inferred from the old benchmark or a 60-fps overlay.

## 5. What is still wrong

[run/design] The S10 memory workaround is awaiting its full sustained confirmation. Arrival has a measurable construction/shader hitch even on PC. Cold cost is reported separately from warm frames. The browser smoke is functional evidence, not a mobile Safari benchmark. Native iPhone and actual iPhone browser touch/safe-area behaviour are untested here.

[design] Ordinary behaviour still uses the recovered daily planning rules with visible journeys and activities; this milestone does not make every everyday conversation a separately simulated encounter. Human readability, shield positioning, investigation time and atmosphere need owner feel review. Automated stationary cadence observation is not a human playtest. Multiplayer, other lands, full economy/progression redesign and native iOS delivery remain outside this slice.

## 6. Decisions for Hilmi (and Enea through him)

[owner/design] Play the short route and judge whether the gathering, accused, witnesses, trace, rescue and remembered aftermath are understandable without a debug view. Judge the ninety-second hearing and shield positioning at normal speed. No owner approval or opinion is inferred from machine tests.

[repo/chat] Publication is separate. The studio `CLAUDE.md` requires Hilmi's explicit yes for each outward action. The historical overnight grant was not treated as new permission to push this continuation. The concrete remaining publication action is pushing local `studio`, if authorized; main merges and messaging Enea remain separate.

[repo] PRs #2/#3/#4 were open at the remote checkpoint. Fetched heads `8870ce9`, `443df900`, `6d54f337` each merged cleanly with `merge-tree` against main `b9618d6`; GitHub reported mergeability unknown and successful Vercel preview checks. Their combined studio integration was exercised. No unnecessary rebase or history rewrite was performed. [Exact status evidence](evidence/continuation/checkpoint-m1/README.md).

## 7. Notes on the night

[repo] Historical notes from the preserved Claude draft: the requested Sonnet launch failed with `glm-5.1 not found`, then helpers were relaunched without a model override on default Opus; second-round helpers were initially given Enea's machine's Godot path. Those describe the old night, not this continuation.

[repo/chat] This continuation used at most two helpers, explicitly selected as `gpt-6-sol`. The launch tool accepted that selection, but helper introspection exposes generic GPT-6 identity, not an independent serving-subtype identifier; backend verification is unavailable and is not invented. Helpers handled bounded porting, long checks/books and device measurements. Astra implemented the coupled action/lifecycle, causality, clock, residents, save/scene and interaction work, and the concrete integration repairs. No model research or new asset generation was needed.
