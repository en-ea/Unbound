---
title: "Opening gesture and ordinary web smoke"
created: 2026-09-29
type: verification
voice: agent-draft
author: Codex (Astra)
status: passed
next_step: owner phone feel review
---

[run] Candidate: `b1e0c5f` plus the action-button gesture fix committed with this packet. Godot 4.7.2 Compatibility. Windows RTX 3050 Laptop for the rendered test; Codex in-app Chromium at 1280x720 for the Web export. This is functional evidence, not browser or iPhone performance evidence.

[run] A real web click on Craft first generated a screen-touch press, opened the workbench, and then sent a mouse press to its new dismissible backdrop. The panel immediately closed. `web-input-before.json` preserves that event order. The action button now owns that emulated mouse press until its finger releases, including while hidden by a panel. The hidden button also processes its finger release. No rule, time or event consequence changed.

[run] `touch-menu-final.txt` reports twenty PASS assertions and exit 0. It enters play, injects touch then mouse into the real viewport at the action button, verifies the merchant remains open with unchanged coins, releases the hidden button, buys an actual priced item and closes. It also covers legacy/new/malformed/truncated saves, gathering, combat, down/locked rejection and bribe acceptance/refusal/duplicate/reload. The earlier `touch-menu-probe-initial.txt` is a failed probe, not a product pass: initial synthetic coordinates used global rather than viewport space, and the earlier combat fixture's stay-armed window had not expired. The final probe waits for that normal window before tapping Trade.

```powershell
& 'C:/Users/hilmi/AppData/Local/UnboundStudio/tools/godot/Godot_v4.7.2-stable_win64_console.exe' --path game -- --studio=village/live --village-checks --test-save=input-guard-unique-7
```

[run] Exported Web was checked through visible Play, movement, Craft, Done, the gear menu, Save, reload and Play. Craft stayed open after a tap (`web-craft-after.png`); normal menu save and restored workbench position appear in `web-saved.png` and `web-resume.png`. The resumed named residents and changing world render normally. No browser warning/error was reported during the final smoke. Save internals and rescue continuity are verified by the native atomic-save tests, not inferred from the web screenshot. No developer time skip was used in this browser route.

[run] `web-final-build.txt` records successful export. Earlier failed export attempts are retained elsewhere in this directory; they are not passes. The browser preview is served locally with `node tools-src/serve.js --local`, with the existing manifest/offline worker copied into the export. Real iPhone Safari/offline lifecycle and owner feel remain untested here.
