---
title: "D1 - Galaxy S10 baseline: specs, the kernel and Enea's current build, measured on the phone"
created: 2026-09-28
type: agent-draft
voice: agent-draft
author: Claude, session 2
status: done - evidence for docs/studio/DEVICES-AND-NATIVE.md and docs/studio/DEVELOPMENT-PLAN.md (native builds added 28 Sep, 23:00-23:20)
next_step: repeat the native runs on the S24 Ultra when Hilmi connects it; S10 becomes the nightly floor check (tools-src/studio/device-lab/android.sh)
---

# D1 - Galaxy S10 baseline

Everything here was driven from this PC over USB (adb): read-only device queries, then Chrome opened with pages served from the PC through `adb reverse`. The phone's rotation setting was switched to landscape for the game run and then restored to its original value (auto-rotate off, portrait). Nothing was installed on the phone for these runs. (Later the same evening our own test app, `com.unboundstudio.unbound.dev`, was installed; see the native section.)

## The device `[run]`

| | Value |
|---|---|
| Model | SM-G973F (Galaxy S10, UK/EU) |
| Chip | Exynos 9820, arm64 |
| GPU | Mali-G76 MP12; driver r32p1; **Vulkan 1.1.177**; OpenGL ES 3.2 |
| OS | Android 12 (SDK 31), One UI 4.1, security patch March 2023 (updates have ended) |
| RAM | 7.6 GB (about 4 GB available at the time) |
| Screen | 1440x3040 panel running at 1080x2280, 60 Hz |
| Storage | **8 GB free (93% full)** |
| Battery | Health reported good; charging over USB |

## The world kernel in the phone's browser `[run]` (`kernel-bench.txt`)

| Test | S10 (Chrome 153) | This PC (Node 24) |
|---|---|---|
| 500 years of history (median of 20 seeds) | 43.6 ms | ~25 ms |
| Edit the past and recompute to today | 16.8 ms | ~19 ms |
| 30-year catch-up | 1.6 ms | ~1.2 ms |
| Storm view of one year | 0.6 ms | ~1 ms |
| World hash, seed 24757 | **40572043** | **40572043**: identical across chip, OS and JS engine |

## Enea's published web build on the phone `[run]` (screenshots in this folder)

| Moment | fps (30 lock) | Worst frame | Draw calls | Triangles |
|---|---|---|---|---|
| Title screen, just loaded (`s10-title.png`) | 9 | 112 ms | 516 | 125k |
| Title screen, settled: the low camera (`s10-title-settled.png`) | 22 | 109 ms | 499 | 122k |
| Gameplay, 45° camera, start (`s10-gameplay-0m.png`) | 27 | 52 ms | 269 | 82k |
| Gameplay after 3 minutes standing still (`s10-gameplay-3m.png`) | 24 | 44 ms | 281 | 84k |

Temperatures over those 3 minutes (`thermal-3min.txt`): the chip went from 40.2 to 42.2 °C and the back ("SKIN") from 28.8 to 30.8 °C. The thermal status stayed 0 (no throttling flagged).

## Native Android builds of the same game `[run]` (added the same evening)

Enea's project was built at `e08cbca` on our local branch `studio/native-baseline` with one change: an Android export preset (test package `com.unboundstudio.unbound.dev`, arm64). It was exported with Godot 4.7.2, re-signed with build-tools 35.0.1, and installed over adb.

- **Signing trap:** Godot 4.7.2 found no build-tools matching target SDK 36 and fell back to 28.0.3. That signer failed silently: the export said DONE, but the APK had no signature, so the phone refused it (`INSTALL_PARSE_FAILED_NO_CERTIFICATES`). `tools-src/studio/device-lab/android.sh` now re-signs every build.
- **Clean runs:** every measured run below started with cleared app data. The first Mobile-renderer launch loaded the previous run's save, including its time of day, so it isn't used for comparison.

| Build | Title screen (low camera) | Gameplay after 3 min (45° camera) | Chip / back temperature after 3 min |
|---|---|---|---|
| Web (Chrome), from above | 22 fps, worst 109 ms, 499 draws | 24 fps, worst 44 ms, 281 draws | 42.2 / 30.8 °C |
| **Native, Compatibility renderer (OpenGL ES 3.2)** | **30 fps (the lock), worst 33 ms**, 472 draws | **30 fps, worst 33 ms**, 271 draws | 40.3 / 32.2 °C |
| Native, Mobile renderer (Vulkan) | 25 fps, worst 49 ms, 392 draws | 27 fps, worst 47 ms, 275 draws | 42.0 / 33.7 °C |

Screenshots: `native-compat-*.png`, `native-mobile-*.png`. The APK is 36 MB; the web build is 47 MB.

**Reading:**
- **Going native alone fixes the floor device.** With no other change, both cameras hold the 30 fps lock.
- **The Mobile renderer works on the S10's old Mali driver** (no crash, no black screen) but costs 10-15% and changes the look. Enea's lighting is tuned for Compatibility, so the Mobile image comes out greyer and hazier.
- **Proposed** `[design]`: ship Compatibility for the "low" tier and use the Mobile renderer, retuned, for "high". Godot picks its renderer at startup, so this means either two builds or a settings override written on first launch followed by one restart. Both are to be tested.

## Reading `[design]`

- **It works as a floor device.** It already runs today's web build near its 30 fps lock at the current camera. The low camera costs about a quarter of the frame rate and brings 100 ms spikes. That is the horizon cost measured on a real phone.
- **Cross-device determinism holds for the JavaScript kernel.** JavaScript fixes arithmetic rounding by specification. The real kernel, in GDScript or C++ on native builds, still needs its own cross-device hash check.
- **Its GPU scores about a fifth of both target phones** in 3DMark Wild Life Extreme (~950, against ~4,700 for the Snapdragon 8 Gen 3 and ~4,360 for the A18 Pro) `[web]`. So it is a budget floor, not a preview of how the game will look on the targets.
