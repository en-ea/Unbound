---
title: S10 final-device gate - memory exhaustion on arrival
created: 2026-09-29
type: evidence
voice: agent-draft
author: Codex helper
status: blocked
next_step: Repair the Android memory growth, then run one bounded arrival and one normal-cadence observation on a new frozen candidate; restore a raw APK without baked arguments.
---

## Verdict

[run] The frozen candidate **failed the 120-second S10 arrival gate**. The app displayed and stayed foreground, but stopped drawing before it could write its measurement JSON. Native heap grew from 1.30 GB at the first sample to 2.87 GB near 40 seconds and 3.92 GB after the freeze. Godot reported an MSAA framebuffer allocation failure at 15:25:06, followed by repeated libc `malloc(32768) failed, errno: 12` at 15:25:08. The 115-second and later screenshots are byte-identical. There is no valid phone p50/p95/max result. The 900-second normal-cadence run and 45-body benchmark were not started on this failed build.

[repo] Source commit: `5ebc55ad3eb36cfaed401e82acf88189fbe28441`, merged into the isolated `unbound-night-port` checkout. Exported with Godot 4.7.2 `Android Continuation` debug preset. Package `com.unboundstudio.unbound.continuation` is separate from `com.unboundstudio.unbound.dev`. Existing SDK 35.0.1 `apksigner` re-signed and verified the APK using the existing `debug.keystore`; package identity was confirmed with `aapt`.

[run] Raw APK: `C:\Users\hilmi\AppData\Local\Temp\unbound-night-port\build\android\unbound-continuation-raw.apk`, SHA-256 `3872F762A2CB2D8B2C3962C1E0EE12097F3B3EF20C99F4750B8F5630FB463C81`. The separate arrival copy has SHA-256 `84CE9AE39228ED184C2BC4D68CBF77BD00BC869037C8B38280A76E061FA476D8` after `lab_args` added `--studio=village/live --village-soon --village-measure=120 --measure-uncapped --measure-label=s10-arrival --test-save=s10-arrival-unique-final` and re-signed it. Both APKs verified; neither was committed. No package was uninstalled, and no app data was cleared.

| Sample | Native heap (KB) | Total PSS (KB) | Swap PSS (KB) | AP | Skin | Observation |
|---|---:|---:|---:|---:|---:|---|
| Start | 1,304,212 | 1,629,945 | 215 | 35.7 C | 29.2 C | Foreground app launched |
| ~40 s | 2,865,628 | 4,583,687 | 1,454,539 | 55.3 C | 31.9 C | Public act visible, overlay 60 fps / worst 21 ms / 395 draws / 183k triangles |
| 115 s | - | - | - | 53.1 C | 34.5 C | Foreground still named, frozen frame |
| Later | 3,923,436 | 6,852,769 | 2,733,951 | - | - | Exactly same PNG hash as 115 s; process alive but stalled |

[run] `MEASURE start` logged at 15:23:32.944 with cap `0`, 1520×720 viewport and 0.8 render scale. There was no `MEASURE result` by more than four minutes later and no `user://studio-measure-s10-arrival.json`; the raw `run-as` failure is retained in `probe-read-failure.txt`. Screenshot `s10-arrival-0040.png` visibly shows the staged scene. The 115-second screenshot and late screenshot have identical SHA-256 `94DD7D6AB652ED0EE3D82731D12C6F23CA325C93597052F5F092FC10A8C31D9F`. The app window remained focused and the keyguard stayed off. The log contains four startup RGBAFloat-to-RGBAHalf compatibility warnings, the MSAA failure, and native allocation failures; it does not contain a completed probe or a Java crash. This supports memory exhaustion, but the allocation source is not yet identified.

[run] The Samsung/Play Protect package verifier initially delayed installs. The raw APK and then arrival APK installed successfully with `adb install -r --no-incremental` after waiting; no security setting was changed. A separate on-device conformance APK was signed, verified and installed, but the parent asked to pause expensive tests just after its launch. The Continuation package was force-stopped immediately; no conformance result is claimed. Its aborted log is retained. At the handoff the package is installed with baked conformance arguments but stopped; a raw APK should be installed before owner play.

```powershell
$godot = 'C:\Users\hilmi\AppData\Local\UnboundStudio\tools\godot\Godot_v4.7.2-stable_win64_console.exe'
& $godot --headless --path game --export-debug 'Android Continuation' (Join-Path (Get-Location).Path 'build/android/unbound-continuation-raw.apk')
$sdk = 'C:\Users\hilmi\AppData\Local\Android\Sdk'
& "$sdk\build-tools\35.0.1\apksigner.bat" sign --ks 'C:\Users\hilmi\AppData\Local\UnboundStudio\tools\debug.keystore' --ks-pass pass:android --ks-key-alias androiddebugkey build/android/unbound-continuation-raw.apk
& "$sdk\build-tools\35.0.1\apksigner.bat" verify build/android/unbound-continuation-raw.apk
# The arrival copy was passed to tools-src/studio/device-lab/android.sh lab_args with the options above.
& "$sdk\platform-tools\adb.exe" install -r --no-incremental build/android/unbound-continuation-arrival.apk
py docs/studio/evidence/continuation/s10-final/run_device.py s10-arrival build/android/unbound-continuation-arrival.apk
```

[repo] Raw logcat, screen captures, thermal, memory, window and activity dumps, export/sign/package details, and the bounded collection script are beside this report. No shipping code was changed. The exact serving backend subtype is not exposed to this helper; `gpt-6-sol` was explicitly requested and its launch accepted, but cannot be independently verified here.
