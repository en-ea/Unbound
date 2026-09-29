---
title: S10 final Continuation device gates
created: 2026-09-29
type: evidence
voice: agent-draft
author: Codex helper
status: checked
next_step: Parent integrates this evidence and APK into the delivery ledger; owner play remains a separate decision.
---

## Verdict

[run] The guarded village scene passed a 120-second arrival and a 900-second ordinary-cadence foreground observation on the connected Samsung SM-G973F. The 900-second run used **uncapped** rendering, no `--village-soon` or time skip, and observed its first natural hearing at real second 763.936, village minute 1960. On the final source, the warmed 45-person crowd benchmark, phone simulation conformance, and 20 normal save/input checks passed. The raw final APK was installed without test arguments and launched to its title menu. The separate old `com.unboundstudio.unbound.dev` package remained installed; no package data was cleared or uninstalled.

[repo] Final shipping source commit `17c1f063dbd893a4aa6bbf46cd87ced4c448aa05` includes the narrow Android Compatibility/Mali-G76 MSAA guard, the touch-opened menu fix, and the conditional hearing cue. The complete Android `Android Continuation` debug export was signed and verified with Android SDK build-tools 35.0.1 and the existing Studio debug keystore. Package ID is `com.unboundstudio.unbound.continuation`. The raw APK is `C:\Users\hilmi\AppData\Local\Temp\unbound-night-port\build\android\unbound-continuation-final-17c1f06.apk`, SHA-256 `61834EAD1FAB7F51991600C36611CF05736E4E65C11A91907CB2D0999C9F987A`. Its `assets/_cl_` has only default engine options, no `--` user/test arguments. Export, signer certificate, package, command line, install and launch records are adjacent.

## Sustained village on guarded source

[repo] The performance runs used source `b1e0c5fb562350bc03b6918b82e43ac7fb3987d9` because later final-source changes were confined to input and conditional caption behavior. No performance run was repeated on those later edits. The arrival copy had `--studio=village/live --village-soon --village-measure=120 --measure-uncapped --measure-label=s10-arrival-guard --test-save=s10-arrival-guard-unique`; the ordinary copy had `--studio=village/live --village-measure=900 --measure-uncapped --measure-label=s10-normal-guard --test-save=s10-normal-guard-unique`. Both had `msaa=0` via the production device guard, with no diagnostic `--measure-no-msaa` flag.

| Measurement | 120-second arrival | 900-second ordinary cadence |
|---|---:|---:|
| Result length | 120.004596 s | 900.024760 s |
| First 20 s frame ms p50 / p95 / max | 18.027 / 29.681 / 311.736 | 17.689 / 28.147 / 306.768 |
| Later frame ms p50 / p95 / max | 16.972 / 21.682 / 123.803 | 20.036 / 33.648 / 204.295 |
| Later frame samples | 5,914 | 40,496 |
| Stage including acquisition ms p50 / p95 / max | 0.116 / 0.446 / 13.681 | 0.220 / 0.763 / 10.457 |
| Resident body count and construction microseconds p50 / p95 / max | 31; 5,603 / 13,651 / 176,826 | 30; 6,011 / 14,949 / 180,790 |
| Draws per sampled frame p50 / p95 / max | 398 / 401 / 401 | 380 / 408 / 428 |
| Native heap from 10 s to final sampled time, raw dumpsys KB | 186,632 to 190,316 (115 s) | 183,712 to 189,992 (895 s) |
| Final static/video Godot counters | 117.1 / 114.4 MB | 117.4 / 116.6 MB |

[run] All 13 arrival probe samples and all 91 ordinary probe samples reported `background=false`. Window dumps confirmed the Continuation app foreground and keyguard off. The ordinary run started with AP 37.5 C and skin 34.4 C, reached skin thermal status 3 by 540 seconds, and still finished. Its later frame figures include thermal throttling and are not a cool-phone FPS estimate. The 770-second screenshot visibly shows the natural hearing and its witness/trace/elder cue; probe JSON records event id 0 at 763.936 seconds and village minute 1960. Neither run had a script error or native allocation failure. The four startup RGBAFloat-to-RGBAHalf compatibility warnings remain in the log.

## Final-source finite gates

[run] `--studio=village/crowd_bench --crowd-body --crowd-short --frame=fight --at=2,24` measured a 45-person walking crowd at the normal 30 fps cap: 240 frames, median 33.4 ms, p95 36.5 ms, worst 40.1 ms, zero frames over 50 ms, 429 draws and 212k triangles. The separate `--crowd-uncapped` run measured 313 frames, median 25.3 ms, p95 32.1 ms, worst 34.5 ms, zero over 50 ms, 425 draws and 212k triangles. Both also recorded 0- and 30-body phases. These were warm short runs with skin thermal status 1. The evidence runner initially marked the capped run false because it searched for `45 villagers` instead of the actual output `45 walking villagers`; the captured raw report was complete and was revalidated without rerunning the benchmark. The initial false status and correction are both retained.

[run] On-device `--studio=village/sim/conformance` passed all three seeds at 20/20 checkpoints × six columns, live 10-village checks (five freed and alive, 42 shields), and storm 20-village checks (97 ancestors, 99 lost, 17 carried rites, five rescued rites, 22 seized). Its saved report `s10-final-conformance-result.txt` was captured after 186.031 seconds. The final `--studio=village/live --village-checks --test-save=s10-final-checks-unique` run passed 20/20 assertions with zero failures, including normal save/backup recovery, untouched gathering and combat, touch plus emulated mouse opening a merchant once, no click-through, hidden-finger release, real priced Buy, and bribe debit/reload. No script errors appeared in these gates; only the known startup texture-format warnings did.

[run] The final raw APK installed with `adb install -r --no-incremental` and launched the ordinary Unbound title/Play menu. The app was foreground with keyguard off at capture. `final-raw-launch.png` and `final-raw-godot-log.txt` preserve that state. No other package was launched and no app data was cleared.

## Boundary and provenance

[run] The initial frozen `5ebc55a` arrival failed from native memory exhaustion; `README.md` and its raw logs/screens remain the historical failure record. A bounded comparison from diagnostic source `2ef8d72` found native heap stable near 190,000 KB for 60 seconds with MSAA disabled, versus 2,440,608 KB at 55 seconds with normal MSAA, when the control was force-stopped by a 2,000,000-KB guard. The production source applied a device-specific MSAA setting and passed the 120/900-second runs above. The original 42 diagnostic files are preserved at `f64a421` and indexed in the [MSAA comparison record](diagnostic-msaa/README.md). Its disabled run was uncapped and its enabled control capped, so this is not a matched performance comparison. Together with the initial uncapped MSAA failure, it supports an MSAA-dependent allocation problem on this device without identifying a deeper driver mechanism.

[repo] All APKs stayed in ignored `build/android/` outputs. Baked test copies were installed with `adb install -r --no-incremental`, the Continuation package alone was force-stopped between gates, and the raw APK was restored last. `run_device.py` and `run_short.py` record the bounded collection commands; raw logs, probes, screenshots, thermals, memory and window dumps sit beside this report. The explicit `gpt-6-sol` launch selection was accepted, but this process has no runtime serving-model identifier to verify the exact backend subtype independently.
