---
title: "Unbound - how we develop it, starting today"
created: 2026-09-28
type: agent-draft
voice: agent-draft
author: Claude (claude-opus-5-5), Claude Code on Hilmi's PC, lead agent, session 2
status: awaiting-hilmi-review
relates_to: docs/studio/ROUTE.md (what we build), docs/studio/CAMERA-AND-FORMAT.md, docs/studio/DEVICES-AND-NATIVE.md, docs/studio/IOS-FINDINGS.md (research agent)
next_step: Hilmi reviews; gate G0 (section 5) - his yes on the two outward steps and on sending the pitch to Enea; the next session starts with W2-1 (the kernel in GDScript) and W4-1 (the look board)
---

# How we develop Unbound, starting today

**Labels:** `[repo]` `[run]` `[web]` `[chat]` `[design]`, as in the other plan documents.

Hilmi, 28 Sep `[chat]`: "plan how we will develop this game starting tofay".

---

## 0. Verdict

- **Development started today.** Enea's game now builds natively and runs on the S10, driven from this PC with no one touching the phone `[run]`. Native alone lifts the S10 from 22-24 fps (web) to a steady 30 at both cameras.
- **Tools are installed:** Godot 4.7.2, export templates, JDK 17, adb.
- **The first toolbox piece is written:** `tools-src/studio/device-lab/android.sh`.
- **From here the work runs as six workstreams**, gated by owner decisions rather than dates (section 2). Everything that doesn't depend on Enea's answers starts now, on our own branch, without touching his day-to-day work:
  - the kernel in GDScript;
  - the look board;
  - the camera prototype;
  - the build pipeline;
  - the deep village, headless.
- **Two steps need your yes before they happen:** pushing our branch (for continuous builds), and sending the pitch to Enea (section 5).

---

## 1. Who does what

| Who | Role | Called for |
|---|---|---|
| **Enea** | Owns the product, look and feel. Keeps building his fighting and loot pass on `main` meanwhile `[repo]` | Decisions D1-D7 (r3); picking from look boards; playing builds at gates (his phone is never the bug harness) |
| **Hilmi** | Owns the method; relays between the studio and Enea | Gate reviews; outward steps; connecting the S24 Ultra at checkpoints. Never bug hunting |
| **Claude (lead)** | Technical calls, building, measuring, recording | - |
| **Research agents** | At most 2 at a time, only where they clearly add value (first one: iPhone specifics) | - |
| **The S10** | Always-on floor device, driven by the agent | - |

**Working in Enea's repo** `[design]`:
- **Our work lives on `studio/*` branches.** Today there is one local branch, `studio/native-baseline`, whose only change is an Android export preset.
- **Additive changes.** New scripts go in their own folder (`game/scripts/studio/`). Edits to Enea's files are limited to small, named hooks.
- **Rebase weekly** onto his `main`, so his fighting pass and our work don't collide.
- **Nothing merges into `main` without Enea's yes**, and nothing is pushed without yours.

---

## 2. The workstreams

```
 W1 platform & pipeline    native Android ✓ → CI builds (Android APK + iOS unsigned .ipa) → AltStore path for Enea → tiers
 W2 world kernel           S1 ✓ (JS) → S2: GDScript, fixed-point, headless runner, S10 timing, cross-device hash → decide GDScript / C++
 W3 social layer           A0: ~30 people, values, practices, rumours, 3 misbehaviours, storyteller - headless, with invariants
 W4 camera & look          look board from the real game → camera director prototype (explore / fight / build) on S10 + S24
 W5 the living world       A1: world clock + action log + chronicle panel + the village of A0 inside Enea's game, you in it
 W6 later                  storms (B) → civilisations (C) → cross-play + on-device minds (D)
```

| Workstream | First task (starts next session) | Done when | Verified by | Needs Enea? |
|---|---|---|---|---|
| **W1** | W1-1: CI workflow for the Android APK on every push to `studio/*`; W1-2: the iOS unsigned `.ipa` on `macos-26` (per the iOS findings) | A phone-installable build appears for every change, with no one at a keyboard | CI logs; S10 install; hash of the build | No (but pushing needs **your** yes) |
| **W2** | W2-1: port the S1 kernel to typed GDScript under `game/scripts/studio/kernel/`, with fixed-point state and a headless runner (`--headless --script`) | 500 years runs on the S10 inside Godot, timed; the same world hash on the PC and the S10 | Headless runs; device lab | No |
| **W3** | W3-1: design the L1 values per people and age, and 3 practices, as data, then run headless | The invariants pass over 1,000 simulated years: no collapse loops, every notable act has a logged reason, legibility coverage above threshold | Headless, in seconds | No (content limits D2 before any violent act ships) |
| **W4** | W4-1: a look board. Enea's real game rendered from the PC in EXPLORE / FIGHT / BUILD / VANTAGE framings at dawn and dusk (needs a small `--fov` dev argument on our branch) | Enea can pick by picture | Vision rung; Enea's pick | **Yes (D5)** |
| **W5** | After G1 | You and Enea each tell a story the village made that the other didn't know | Owner play | **Yes (D1)** |
| **W6** | After G2 | See r3 section 11 | - | Yes |

---

## 3. How a working day runs

```
 session start ── read the studio log ── pick one task
      │
      ▼
 HEADLESS first (kernel, invariants, metrics: seconds)
      │ passes
      ▼
 BUILD → DEVICE LAB (S10, automatic): install · cold start · screenshots · fps from the overlay · temperatures
      │   compared against the D1 baseline; regressions flagged in the log
      ▼
 LOOK QUESTION?  ── yes ──► look board rendered from the real game ──► Enea picks (through Hilmi)
      │ no
      ▼
 GATE?  ── yes ──► owner play: Hilmi on the S24, Enea on his iPhone (feel and fun only)
      │
      ▼
 session end ── studio log entry ── commit (studio records + this branch)
                 rotate to a fresh session after ~4 hours or ~4 tasks (studio rule)
```

- **The S10 is the regression line.** Every build must hold 30 fps at the low camera on the "low" tier after 20 minutes, from the camera prototype onwards. The S24 checks "high" at checkpoints.
- **Costs so far:** £0.
  - Optional later: $99 a year (Apple), about $5 a month (a Nakama server, stage D).
  - No LLM API costs: the minds run on the phones.

---

## 4. The sequence (gates, not dates)

| When | What | Gate |
|---|---|---|
| **Today (28 Sep)** ✓ | Research, routes r2-r3, the camera and format, devices; tools installed; native Android baseline on the S10; the device-lab script; this plan | **G0**: you review; yes or no to the outward steps |
| **Next ~3 sessions** | W2-1 kernel in GDScript + S10 timing + hash · W4-1 look board · W1 CI (once pushing is allowed) · the pitch pack for Enea (verdict, S1 chronicle excerpt, camera frames, S10 numbers, D1-D7 on one page) | **G1**: Enea answers D1 (direction), D4 (native), D5 (camera) |
| **Following ~4-6 sessions** | W3 A0 deep village headless · W4 camera director prototype on both Android phones · W1 AltStore build on Enea's iPhone · renderer tiers | **G2**: you and Enea read the headless village's chronicle and want to be in it |
| **After G2** | W5 A1: the village in the game, you in it, rumours about you, the chronicle panel | **G3**: each of you tells a story the village made |
| **After G3** | W6: storms (B), civilisations (C), cross-play and minds (D) | r3 section 11 |

Why no dates: each gate depends on an owner answer or an owner judgement, and those can't be scheduled from here. What can be promised is that no session ends without a measured result in the log.

---

## 5. Needs your yes (G0)

| # | Step | Why | Outward? |
|---|---|---|---|
| Y1 | Push `studio/*` branches to `en-ea/Unbound`, or to a fork under your account if you'd rather keep Enea's repo untouched until he agrees | Continuous builds (Android APK, iOS `.ipa`) run on GitHub's free runners only from a pushed branch | Yes. Every push afterwards would still be announced in the log |
| Y2 | Send Enea the pitch pack (D7), in the form you choose | D1, D4 and D5 unblock W5 and W4 | Yes. You send it; I prepare it |
| Y3 | Connect the S24 Ultra once, for about 30 minutes, when convenient | "High" tier baseline and your phone's heat behaviour | No |

---

## 6. Risks and what we do about them

| Risk | Early signal | Response |
|---|---|---|
| GDScript too slow for the kernel | W2-1 timing on the S10 above ~2 s per 500 years | A C++ module compiled into custom templates (r3) |
| The camera feels wrong in the hand | Owner play at the camera prototype | Iterate framings; keep today's camera as BUILD and FIGHT |
| The Mobile renderer too costly on the floor device | S10 below 30 fps on "low" | Compatibility for "low" (already 30 fps), Mobile for "high" |
| Free iPhone sideloading breaks (Apple changes) | AltStore sign-in or refresh failures | The $99 account (anyone's), TestFlight |
| Our branch and Enea's main diverge | Rebase conflicts | Weekly rebase; hooks, not rewrites |
| Scope creep | A stage shipping thin | The cut rule (r3): what can't be deep waits |

---

## 7. The iPhone path (folded in from `docs/studio/IOS-FINDINGS.md`, research agent, 28 Sep)

The lead spot-checked the report's repo claims against Enea's code, and they hold `[repo]`:
- the HUD margin is `Vector2(64, 24)`;
- `Engine.max_fps` and the physics tick rate are both set to the cap;
- saves are written in place;
- the web page has no `viewport-fit`.

**What changes in the plan** `[design]`:

| # | Change | Workstream |
|---|---|---|
| i1 | **Free sideloading is for the first iOS spike only**, not for routine play. Enea would notice a difference: a one-time PC setup with Developer Mode, the LocalDevVPN app kept connected, a silent 7-day expiry whenever Apple's sign-in path breaks (three multi-day breaks in 2026), and one of his two free app slots. The $99 question goes into the pitch (D4) with this record attached | W1 |
| i2 | **The iOS build recipe:** Godot export with `--export-release` (Xcode project only) → `xcodebuild build` with signing off → **ad-hoc sign with an entitlements file** (the memory limit; otherwise AltStore can't grant it) → zip `Payload/` into an `.ipa`. Hang guards: `DEBUG_INFORMATION_FORMAT=dwarf`, `-jobs 1`, a timeout. A 1024 px icon | W1-2 |
| i3 | **Renderer per platform.** On iOS the Compatibility renderer runs on Apple's deprecated OpenGL ES, not Metal. Proposal: **iOS and "high" Android on the Mobile renderer (Metal/Vulkan), "low" Android on Compatibility** (the S10 already holds 30 fps with it). Enea's lighting needs a retune for Mobile, which goes on a side-by-side look board (Compatibility vs Mobile) for his decision. To test: whether a per-OS override (`rendering_method` with an `ios` feature tag) works | W1, W4 |
| i4 | **Three small fixes before any native build reaches Enea**, each a hook-sized change and useful on every platform: (a) place the HUD from `DisplayServer.get_display_safe_area()` instead of the fixed 64 px margin; (b) set `hide_home_indicator=false`, so one swipe can't exit mid-fight (Godot issue #104411); (c) **write saves to a temporary file and rename, keeping one backup**, so a kill mid-write can't wipe progress | W1-3 (new) |
| i5 | **Frame pacing:** measure frame-time spread on device; prefer 30/60 over 40 (40 doesn't divide 60); decouple physics from the frame cap | W1, measured by the device lab |
| i6 | **Crash reports:** Sentry for Godot (supports iOS on 4.5+) or Enea sharing Analytics Data files; keep dSYMs as build artifacts | W1 |
| i7 | **Identity and sync:** the sideloaded bundle ID differs from any later TestFlight build, so saves and Nakama accounts must not depend on it. Use a linkable account, and prefer a Nakama relay over LAN multicast (not available on a free account) | W6 (stage D) |

**Still unknown** (report section 8): whether remote refresh really holds across a 7-day window in the UK; whether the ad-hoc-signed memory entitlement survives AltStore; Foundation Models in a free-signed build and under Game Mode. The first iOS spike measures these.

## 8. Progress (29 Sep)

- **W2-1 done** `[run]` (`KERNEL-S2.md`). The kernel is in GDScript (`game/scripts/studio/kernel/`):
  - it matches an integers-only JavaScript reference at all 420 checkpoints, on the PC and on the S10;
  - 500 years takes 367 ms median on the S10 (decision line: 2 s);
  - run non-stop on a worker thread during play, it left the game at 30 fps.
  - **Decision:** stay in GDScript for W3. The trigger for C++ (GDExtension) is a village-year above ~50 ms on the S10's worker thread.
- **W4-1 done** `[run]` (`LOOKBOARD-1.md`): 4 framings x 2 renderers x day and dusk, plus the fog pushed out.
  - On the S10 every framing holds 30 fps standing still (EXPLORE: 629 draw calls).
  - Turning the camera stutters on early launches (up to 235 ms) and is clean once the shader cache has filled. The fix is shader warm-up at the first load.
  - **Correction (later that night):** after seven more launches, stutters while turning also occur on some relaunches (4 of 7 launches, worst 242 ms). They are not the tree fade, and mostly not scripts; the time lies outside what Godot measures. Next: a Perfetto system trace in the camera prototype, and the same test on the S24.
  - The Mobile renderer can't be judged until the lighting gets a pass for it.
  - The autosave costs 17-22 ms on the main thread on the S10, every 15 s.
- **Device lab:** `lab_args` bakes dev arguments into an APK; `lab_wake` catches a locked phone (Android pauses the game, and a run silently does nothing).
- **i4 done:** pull requests #2 (safe saves), #3 (HUD from the safe area) and #4 (iPhone swipe), each off `main` and tested as its description says. Saves were checked on the S10, including recovery from a cut-off save.
- **Superseded sequencing (29 Sep, later):** the order of work is now `ROUTE-r4.md` section 5:
  - M1: the village, headless;
  - M2: the village on screen;
  - M3: the camera;
  - M4: the slice playtest, each on your own phone;
  - M5: the multiplayer spike;
  - M6: live together.

  Every milestone follows the multiplayer-ready rules and passes a replay test (r4 section 3.9). The workstreams and gates above stay as the record.
