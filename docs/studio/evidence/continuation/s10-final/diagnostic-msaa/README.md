---
title: S10 MSAA memory diagnostic - preserved raw comparison
created: 2026-09-29
type: evidence
voice: agent-draft
author: Codex helper
status: checked
next_step: Parent cites this bounded comparison alongside the final guarded 120/900-second results; no diagnostic rerun is needed.
---

## Result

[run] These are the **original** two 60-second diagnostic runs from source commit `2ef8d7266f550c770ebc59d005ebee52a9ce1242`, copied into this folder without rerunning. The uncapped no-MSAA run completed at 60.053203 seconds. The normal-MSAA capped control crossed the 2,000,000 KB native-heap guard at 55 seconds and was force-stopped. Both ran the same soon public act in the separate `com.unboundstudio.unbound.continuation` package, with 31 resident bodies and `background=false` in recorded Godot samples. No package data was cleared or uninstalled.

| Run | Native heap 10 s | 30 s | 55 s | Godot counters at 50 s | End |
|---|---:|---:|---:|---|---|
| MSAA disabled, uncapped | 186,008 KB | 188,732 KB | 189,708 KB | 116,795,685 static bytes; 114,439,798 video bytes; 3,092 nodes; 709 resources | Complete JSON result, 60.053203 s |
| Normal MSAA, capped | 435,900 KB | 1,332,756 KB | 2,440,608 KB | 116,639,437 static bytes; 116,565,614 video bytes; 3,092 nodes; 709 resources | Guard abort/force-stop at 55 s |

[run] Godot object/node/resource/video counters remained nearly flat in the MSAA-on control while Android native heap grew. The initial frozen `5ebc55a` arrival, which had normal MSAA and was uncapped, also grew past 3.9 million KB native heap and stalled before 120 seconds; its original record is in the parent `README.md`. The combination of uncapped MSAA-on failure, capped MSAA-on growth, and uncapped MSAA-off stability supports an MSAA-dependent native allocation path on this S10. It does not identify the deeper renderer/driver allocation mechanism. The two diagnostic variants also differ in frame cap, so their frame-time figures are not a matched performance comparison.

[run] The no-MSAA run's saved JSON is `s10-diag-no-msaa-probe-read.stdout`; its steady frame time p50/p95/max was 17.202/21.738/122.206 ms, stage including acquisition 0.184/0.491/13.929 ms, and sampled draws p50/max 397/401. The capped MSAA control intentionally has no completed probe JSON. `s10-diag-no-msaa-status.txt` and `s10-diag-msaa-cap-status.txt` record these different outcomes. Raw logcat, screen, thermal, memory and window captures at 0/10/30/55 seconds are preserved for each run. `run_diag.py` is the bounded collector, copied unchanged.

[repo] Godot 4.7.2 exported the `Android Continuation` debug preset from that source. Android SDK build-tools 35.0.1 re-signed/verified all APKs with the existing Studio debug keystore. The raw diagnostic APK has SHA-256 `D0FE86CFC6D94B2DC55A4667D7A4B18A1E1F2AA1AE25BB0CD824F19944930AF0`; the no-MSAA copy has `EF808462E2205CF61032846688F5DBD308EBDBA23F1D6BD18154C4F69BA29EE6`; the capped control has `70B18BEC1F3EC1601F994FBD4F65E9242CA46281AAF31899BF3FDA719ED53988`. The APKs remain in ignored `build/android/` outputs, not this commit.

```text
No-MSAA: --studio=village/live --village-soon --village-measure=60 --measure-uncapped --measure-no-msaa --measure-label=s10-diag-no-msaa --test-save=s10-diag-no-msaa-unique
Control: --studio=village/live --village-soon --village-measure=60 --measure-label=s10-diag-msaa-cap --test-save=s10-diag-msaa-cap-unique
```

[repo] The diagnostic files here are copies of the existing captured files. No source, game setting, benchmark, or device state was changed to make this evidence packet.
