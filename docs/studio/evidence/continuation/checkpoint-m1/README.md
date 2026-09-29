---
title: M1 frozen candidate delivery checks
created: 2026-09-29
type: evidence
voice: agent-draft
author: Codex helper
status: checked
next_step: Re-run export and S10 checks against the parent's final candidate, then have the owner review the result.
---

## Verdict

[run] The frozen candidate `882c35d9de141372831745a13c700ff97ea54ab6` passed the rendered rescue integration check after a one-time asset import. The exact run exited 0, printed `PASS rescue integration: real input twice, immediate save/load, midnight, actual region reload and return`, and wrote no stderr. The rendered process used Godot 4.7.2 with OpenGL Compatibility on the NVIDIA RTX 3050 Laptop GPU. Raw output and exit records are adjacent to this file.

[run] The first attempt, before import, timed out after 90 seconds and logged missing imported font data and cascading parse errors. Its raw files are preserved as `m1-rendered-unique.*`. `m1-import.*` records the successful import. `m1-rendered-after-import.*` records the passing retry.

[repo] Work was isolated at `C:/Users/hilmi/AppData/Local/Temp/unbound-night-port`. Four generated village UID files were preserved in snapshot commit `0d8e0ce442e1ff056c449ac07b8d3033908d7b2d` before merging the frozen candidate. The merge commit is `c072383e1ce79faff166214ad2b5e97a86e472a3`; its four UID conflicts took the candidate versions after the snapshot. The import generated an additional untracked `game/scripts/studio/village/rescue_probe.gd.uid`; it was left for the parent to decide.

## Commands and environment

```powershell
$godot = 'C:\Users\hilmi\AppData\Local\UnboundStudio\tools\godot\Godot_v4.7.2-stable_win64_console.exe'
& $godot --headless --path game --import
& $godot --path game --rendering-driver opengl3 -- --studio=village/live --village-soon --village-rescue-test --test-save=m1-rendered-unique
```

[run] Each process was bounded to 90 seconds by the test harness. The final rendered process exited within the bound.

[repo] PR [#2](https://github.com/en-ea/Unbound/pull/2), [#3](https://github.com/en-ea/Unbound/pull/3), and [#4](https://github.com/en-ea/Unbound/pull/4) were open when queried. Their fetched heads were `8870ce9ab99fca06c54994594bac83da93c9be4a` (`studio-fix-safe-saves`), `443df900903c884b051b5dae3a569a6a8b53db07` (`studio-fix-safe-area`), and `6d54f3372a35912f67e2f44c2a2c97c65152c3f4` (`studio-fix-swipe-exit`). `git merge-tree --write-tree origin/main origin/<branch>` exited 0 separately for all three against fetched `origin/main` `b9618d6745d8ab338b972be88b978548ce84da75`. GitHub's API returned `mergeable: null`, `mergeable_state: unknown` for all three, and each had `Vercel Preview Comments: completed: success`. This check did not test the three fixes merged together.

[run] Android SDK build tools 35.0.1, `adb`, Android Studio JBR 21, and connected Galaxy S10 `R58N53475EH` / `SM_G973F` were found. A junction at `C:/Users/hilmi/AppData/Local/UnboundStudio/tools/jdk/android-studio-jbr` and a debug keystore at `C:/Users/hilmi/AppData/Local/UnboundStudio/tools/debug.keystore` were created for the existing `tools-src/studio/device-lab/android.sh`; its `androiddebugkey` entry was verified. These local prerequisites are outside Git.

[repo] The Godot editor setting `export/android/java_sdk_path` is empty, while `export/android/android_sdk_path` names the installed SDK. The device helper sets `JAVA_HOME` to the linked JBR when sourced; Android export is still unverified. Git Bash is present at `C:/Program Files/Git/bin/bash.exe` for the helper.

[run] Godot export templates for 4.7.2 were absent at `%APPDATA%/Godot/export_templates` at inspection. The official 4.7.2 archive (1,281,349,702 bytes) was downloaded, and its `web_release.zip`, `web_debug.zip`, `android_debug.apk`, `android_release.apk`, and `version.txt` were installed in `%APPDATA%/Godot/export_templates/4.7.2.stable`. Local HTTPS serving with `tools-src/serve.js` also needs `tools/dev-cert.pfx` and `tools/trust-me.cer`, which were absent in this isolated worktree. Neither web nor Android export or S10 performance run was performed in this packet.

For the final candidate, after templates are present, the minimal web build command from this repository is:

```powershell
& $godot --headless --path game --export-release Web ../build/web/index.html
Copy-Item tools-src/app.webmanifest build/web/
Copy-Item tools-src/offline.sw.js build/web/
```

The existing S10 helper starts with:

```bash
source tools-src/studio/device-lab/android.sh
mkdir -p build/android docs/studio/evidence/continuation/checkpoint-m1/s10
export LAB_OUT=docs/studio/evidence/continuation/checkpoint-m1/s10
lab_build game Android build/android/unbound-studio.apk
lab_args build/android/unbound-studio.apk --studio=village/live --village-soon --test-save=m1-s10
lab_install build/android/unbound-studio.apk
lab_wake
lab_run com.unboundstudio.unbound.dev m1-s10
```

[repo] `lab_run` clears app data, takes a screenshot after 35 seconds, then samples temperature for three minutes by default. Run it only for the parent's final candidate. The debug APK signing path uses Android build tools 35.0.1 and the new local debug keystore.

[run] The helper was requested as `gpt-6-sol`, but the local process environment exposed no model identifier that verifies the actual serving model. The model claim remains unverified; no substitute model is asserted.
