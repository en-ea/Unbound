---
title: "The owner's crash on 1 Oct - Android killed the game for memory: 3D MSAA leaks native memory every frame on the Compatibility renderer"
created: 2026-10-01
type: evidence
voice: agent-draft
author: Claude, lead agent in Hilmi's studio
status: cause measured on the S24 Ultra and fixed in pass3 29bba30; 10 minutes from his save flat; a session as long as his (22 min) is not yet measured
next_step: Hilmi plays unbound-studio-29bba30.apk (installed); a session as long as his, with a talk and a gift, should stay smooth
---

# The crash: memory, not the coins

**Verdict** `[run]`: Android's low-memory killer ended the game. With 3D MSAA on, Godot's Compatibility renderer grows the game's native memory every frame on Android, about 5 MB a second on the S24 Ultra while standing still. Twenty-two minutes of play reached 7.8 GB. Without MSAA it is flat. The fix turns MSAA off on Android's Compatibility renderer, for the game's view and the talk screen's portrait (`scripts/studio/render_gate.gd`, pass3 `29bba30`). This is Godot's known issue godotengine/godot#97967 `[web]`.

**The owner's report** `[owner]` (Hilmi, 1 Oct): "it was running for a while, my phone started getting a little hot over time and then I decided to talk to some guy who seemed not happy with me so I gave him 5 coins then suddenly the frame rate dropped more and more until it just crashed."

## What the phone recorded `[run]` (`owner-session-log-excerpt.txt`)

| Time | What |
|---|---|
| 15:38:57 | the game starts |
| 15:41:35 | the allocator: "Can't populate more pages for size class 1104" (2 min 38 s in) |
| 15:43:27 | two script errors: the player's talk target was freed that frame (`residents.gd:644`, `hold_to_fight.gd:97`); harmless, fixed in the same commit |
| 16:00:25 | the game's resident memory: 3.9 GB |
| 16:01:31 | 7.8 GB, about 60 MB a second by then |
| 16:01:35 | Android's low-memory killer reclaims the game: "min2x watermark is breached even after kill" |

**Every probe run carried it** (`probe-runs-allocator-lines.txt`): the same allocator line 2 min 41 s to 2 min 43 s after each start (14:27, 14:40, 14:52). The probe runs ended at 8 minutes, before memory ran out, and measured frames, not memory.

## The cause, measured `[run]` (`toolbox/device-lab/phone_memory.sh`, `dumpsys meminfo` every 10 s)

The same build (`e0fc716`), the same spot in the village, standing still:

| Run | Native memory | Rate |
|---|---|---|
| MSAA on, as shipped (`s24-msaa-on.csv`) | 248 -> 1,072 MB in 172 s | +5 MB a second |
| MSAA off (`s24-msaa-off.csv`) | 223 -> 221 MB in 160 s | flat |
| The PC, his save, 5 min, MSAA on | 144 MB from 50 s to 300 s; 8,186 objects | flat: the leak is in Android's graphics path, not in the game's scripts |

The talk screen's portrait is a second 3D view that asked for 2x MSAA of its own (`ui/dialogue_panel.gd`), which fits the faster growth at the end of his session, after the talk `[design]`. Giving coins does only bookkeeping and a save (`player_acts.gd`, `world_actions.gd` "give") `[repo]`.

**The same mechanism was found on 29 Sep** on an S10 (Mali-G76): about 40 MB a second with MSAA, flat without (`../../continuation/s10-final/diagnostic-msaa/`). The guard written then covered only that GPU (`settings.gd`, `b1e0c5f`). The S24's Adreno 750 was never measured for memory.

## The fix, checked

| Check | Result |
|---|---|
| Talk, give and fight on the phone (the people provoke probe, `s24-fix-talk-give-fight.csv`) | native 219-238 MB throughout; 24 passes, 0 failures, no script errors, no allocator lines |
| From a copy of his save on the phone, planned 25 minutes (`s24-fix-his-save-10min.csv`) | stopped at 590 s so Hilmi could play: native 215-220 MB throughout (the shipped build would have grown about 2.9 GB by then). **Longer than 10 minutes is not yet measured** |
| The PC: people tests, people provoke, provoke, village checks | 38/38, 24, pass, 20/20 |

**The look** `[design]`: edges in 3D lose their 2x MSAA smoothing on Android. At the S24's 3120x1440 the steps are small; whether a replacement is worth it is a look question for Enea, through Hilmi.
