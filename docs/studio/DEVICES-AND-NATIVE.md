---
title: "Unbound - going native on iPhone and Android, the device lab, and the optimisation budget"
created: 2026-09-28
type: agent-draft
voice: agent-draft
author: Claude, Claude Code on Hilmi's PC, lead agent, session 2
status: awaiting-hilmi-review
relates_to: docs/studio/ROUTE.md (D4 native builds), docs/studio/CAMERA-AND-FORMAT.md (the horizon cost)
next_step: Hilmi approves the tool downloads in section 5; then the first native Android build runs on the S10 and the optimisation loop starts there
evidence_base: docs/studio/evidence/s10 (the S10 measured on 28 Sep); docs/studio/evidence/camera; web sources in section 6
---

# Going native, the device lab, and the optimisation budget

**Labels:** `[repo]` measured in this repo or its git history · `[run]` produced by running something here · `[web]` cited source · `[chat]` Hilmi's words · `[design]` my proposal.

Hilmi, 28 Sep `[chat]`: "I do think many optimisations will need to be taken to get this actually running, and not only that but your suggestion to replace the browser format sounds like it's needed but would an iphone face issues with that? Also I have connected a lesser s10 for now, assess whether this would be good enough to test with".

---

## 0. Verdict

1. **The iPhone itself gains from going native; the friction is all in building and delivering.**
   - It drops the web build's limits: one thread, the WebGL 2 renderer, Safari's audio-crash reports.
   - Of the three phones, it holds its performance best under sustained load (r3).
   - The costs are one-off and none of them blocks:
     - a macOS build step: free on GitHub for Enea's public repo `[repo]` `[web]`;
     - the $99-a-year Apple account;
     - signing setup;
     - TestFlight builds that expire after 90 days;
     - a slower update loop than a web refresh;
     - two known traps: shaders silently not precompiled in headless builds, and iOS's per-app memory ceiling (section 1).
2. **Yes, the S10 is good enough, as the always-connected floor and automation device.** It is not a preview of the game on your phone or on Enea's.
   - **Measured on it today** `[run]`: the kernel runs 500 years in 44 ms and produced the **identical world hash** to this PC. Enea's web build runs 27 fps at the current camera, 24 after 3 minutes, and 22 at the low camera.
   - **Its GPU is about a fifth of both targets** `[web]`, and its Mali graphics driver is a different family from your S24's Adreno and Enea's Apple GPU. For a floor device, both are advantages.
   - **Use the S24 Ultra for periodic target checks:** look, 20-minute heat, the on-device model's speed. Use the iPhone only for Enea's play.
3. **You're right about optimisation, and the S10 is where to force it.** Today's measured costs, and the budget to hit, are in section 4. The order: go native first (it removes the biggest limits in one step), then optimise until the S10 holds 30 fps at the low camera on a "low" quality tier. The flagships then have 4-5x headroom for the "high" tier.

---

## 1. Going native on the iPhone: what changes, what can go wrong

| Issue | Why | What we do | Cost |
|---|---|---|---|
| **Builds need macOS and Xcode 26** | Since 28 Apr 2026, uploads to App Store Connect must be built with Xcode 26 and the iOS 26 SDK `[web]`. No Mac here | GitHub's `macos-26` runner. Standard runners are free on public repos, and `en-ea/Unbound` is public `[repo]` `[web]` | £0 |
| **Godot 4.7.2 needs a recent Xcode** | A public Godot project's archive failed to link on `macos-14` with 4.7.2 templates; `macos-latest` fixed it `[web]` | Pin `macos-26` | - |
| **Shaders silently not precompiled** | Godot 4.5+'s shader baker cut load times about 20x for Apple's graphics in Godot's own test. But a headless (windowless) export skips it without warning, which gave another project's iOS users **5-130 s freezes** on first draw `[web]` | Export with a windowed editor on the runner, and **fail the build if the log lacks "Started Baking shaders"** | - |
| **Signing** | A fresh runner can't use Xcode's automatic signing; Apple has deprecated password logins `[web]` | An App Store Connect API key, a distribution certificate and profiles in the repo's secrets | One setup session |
| **Apple account** | TestFlight needs the $99-a-year Apple Developer Program `[web]` | Enea's decision (r3 D4) | $99 a year |
| **TestFlight rules** | Internal testers (up to 100) get builds with no review; every build expires 90 days after upload `[web]` | Continuous integration uploads on every push to our branch, so no build ever expires | - |
| **Slower loop than the web** | Web: push and refresh. Native: build, upload, processing, then tap Update in TestFlight | Most checks happen on the S10 and headless anyway (section 3). Enea gets fewer, better builds. The web build stays live as a fallback during the switch | Minutes per build |
| **Memory ceiling** | iOS kills apps above about 3.3-4 GB on 8 GB iPhones. The `increased-memory-limit` entitlement raises that to about 6 GB `[web]` | Budget in section 4. Add the entitlement once an on-device model ships. Read the real limit at runtime (`os_proc_available_memory()`) | - |
| **Apple's model and Game Mode** | See r2 section 4.8 and r3 section 9 | Spike S3 | - |
| **Gone for good** | The web build's single thread, WebGL 2 renderer, Safari audio-crash reports and service-worker workarounds `[repo]` `[web]` | - | - |

**The honest part.** Nobody here can run an automated test on an iPhone without a Mac. So iOS gets:
- TestFlight builds;
- crash logs;
- Enea's own play (for feel only; his phone is not the test harness, per the studio rules);
- later, if needed, a cloud device farm or a Mac mini runner.

---

## 2. Going native on Android (your phones)

- **Installing:** an APK over the USB cable (`adb install`). No Google developer verification needed: ADB installs are exempt, and verification doesn't reach the UK until 2027 `[web]` (r3).
- **Tools on this PC** `[run]`:
  - present: Android SDK build-tools 34/35 and adb;
  - missing: **JDK 17** (only Java 8 is installed), Godot 4.7.2 and its export templates.
- **Risk to check early:** Godot's Vulkan Mobile renderer has crash reports on some Mali drivers (Mali-G78, G715, and a Mali-G76 crash in Unreal) `[web]`. Your S10 has an old Mali-G76 driver (r32p1) `[run]`. That is exactly why it is useful: if the Mobile renderer misbehaves there, we learn it now. The fallback is the Compatibility renderer for that tier.

---

## 3. The device lab

| Device | Role | Connected | What it tests | What it can't |
|---|---|---|---|---|
| **Galaxy S10** (yours, now) | **The floor, and automation** | Always | Crashes, input, the Mali driver, determinism hashes, the performance floor, overnight soak runs. All driven by the agent over adb: install, launch, tap, screenshot, logs, temperatures | The look at target quality, your S24's heat behaviour, the on-device model's speed, anything iOS |
| **Galaxy S24 Ultra** (yours) | Android target | Now and then | Look and speed at target, a 20-minute thermal run, a bundled small model's speed, the Adreno GPU | Automation while you're using it |
| **iPhone 16 Pro Max** (Enea's) | iOS target | Never (TestFlight) | Metal, Apple's model and Game Mode, feel | Automated tests; bug hunting (studio rule: the owner's phone is not the harness) |
| **This PC** | Headless and vision | Always | Kernel runs in milliseconds, look boards (once Godot is installed), CI | Phone performance |

**Setting up the S10 for constant connection** `[design]`, from what the phone reported `[run]`:
- **Battery.** Turn on **Protect battery** (Settings → Battery and device care → Battery → More battery settings). It stops charging at 85% so the battery doesn't age from being plugged in all the time. Battery health reads good today.
- **Screen.** Leave the developer option **"Stay awake" off**. The S10 has an OLED screen, and a constantly lit static image risks burn-in. Test runs wake the screen themselves and let it sleep afterwards.
- **Storage.** 8 GB free (93% full). A native build plus a small language model (0.5-1 GB) fits, but freeing a few GB would stop test runs failing on space.
- **Updates.** Its updates ended in March 2023. That's fine for a lab phone. Keep personal accounts off it if you can.
- **Authorisation.** You ticked "Always allow" for this PC, so runs need nothing from you.

---

## 4. The optimisation budget

**What we measured today** `[run]` (D1 and camera frames) **and the targets** `[design]`:

| Item | Measured today | Target | How |
|---|---|---|---|
| Frame rate on the S10 | 27 → 24 fps at the current camera; **22 fps with 109 ms spikes at the low camera** (web build) | **30 fps at the low camera, "low" tier**, after 20 minutes | Native Mobile renderer, then the items below |
| Frame rate on the targets | Not yet measured | 30 fps (60 as an option), "high" tier, after 20 minutes | Same work, higher tier |
| Draw calls | 269 at 45°; **499 at the low camera** | ≤ ~250 at the low camera | Merge each village's static meshes; level of detail and merged far-away versions; impostor cards for distant forests; fog-limited far plane; scenery already on MultiMesh `[repo]` |
| Triangles | 82k-125k | Fine on the targets; cut for the far distance | Level of detail |
| First-load stutter | 9 fps, 112 ms spikes on the S10 title screen | No visible stutter | Shader baker (native), a warm-up scene |
| Crowds | ~20 animated characters at most `[repo]` | Hundreds | Vertex-animation textures plus MultiMesh (r3) |
| World kernel | 44 ms per 500 years on the S10 (JavaScript) | Its own thread; GDScript estimated at 1-2 s per 500 years on the S10 | Spike S2 decides GDScript or a C++ engine module |
| Memory | S10: ~4 GB available. iPhone: ~3.3-4 GB per app `[web]` | Game under ~1.5 GB plus a model of 0.5-1.5 GB | Textures (Enea's 150-250 MB rule `[repo]`), stream regions, memory-map the model |
| Heat | S10 warmed 40 → 42 °C in 3 minutes of idle play | Stable after 20 minutes on every device | 30 fps lock (Enea's rule), render scale per tier |

**Quality tiers** `[design]`:

| | Low (S10 class) | High (S24 Ultra, iPhone 16 Pro Max) |
|---|---|---|
| Render scale | 0.7 | 0.8-1.0 |
| Shadows | Near only | Near plus soft |
| Crowd | Up to ~80 on screen | Up to ~300 on screen |
| Draw distance | Shorter, more fog | Longer; horizon signals at full range |
| Post | Glow only | Glow, depth of field, god-ray post |

**Order:**
1. The first native Android build on the S10, and nothing else changed. This removes the web limits and gives an honest baseline.
2. The camera prototype (explore, fight, build) at the low camera.
3. Optimise until the S10 holds 30 fps on "low".
4. Check "high" on the S24.
5. Build the TestFlight pipeline for Enea.

Every step is measured on the S10 automatically; you are needed only to judge the look and feel.

---

## 5. Needs your go-ahead (downloads, all official sources)

| File | From | Size (approx.) | For |
|---|---|---|---|
| `Godot_v4.7.2-stable_win64.exe.zip` | github.com/godotengine/godot/releases | ~60-70 MB | Editor, headless runs, look boards |
| `Godot_v4.7.2-stable_export_templates.tpz` | Same page | ~1 GB | Native Android (and later iOS) exports |
| Eclipse Temurin JDK 17 (Windows x64 zip) | adoptium.net | ~190 MB | Signing Android builds |

Everything would be unpacked under a tools folder outside both repos, with no system-wide install. The Apple account (D4) stays Enea's decision.

---

## 6. Sources `[web]`

- Apple upload requirements: https://developer.apple.com/news/upcoming-requirements/ · https://dev.to/arshtechpro/ios-26-sdk-is-now-mandatory-here-is-what-actually-changes-for-your-app-39m4
- TestFlight: https://techconcepts.org/blog/testflight-guide · https://ptkd.com/journal/testflight-build-expired-fix
- Godot iOS CI: https://github.com/dulvui/godot-ios-upload · https://github.com/superhighfives/griss/pull/2
- Shader baker: https://godotengine.org/releases/4.5/ · https://github.com/decentraland/godot-explorer/issues/2891
- GitHub macOS runners: https://github.blog/changelog/2026-02-26-macos-26-is-now-generally-available-for-github-hosted-runners/ · https://dev.to/maclessdev/github-actions-free-macos-minutes-explained-33p7
- iOS memory limits: https://zenn.dev/mtfum/articles/ios_memory_entitlements?locale=en · https://developer.apple.com/forums/thread/770868
- GPU scores: https://nanoreview.net/en/soc/samsung-exynos-9820 · https://www.notebookcheck.net/Qualcomm-Adreno-750-GPU-Benchmarks-and-Specs.762136.0.html · https://nanoreview.net/en/soc-compare/qualcomm-snapdragon-8-gen-3-vs-apple-a18-pro
- Godot on Mali: https://github.com/godotengine/godot/issues/115442 · https://github.com/godotengine/godot/issues/94177 · https://forums.unrealengine.com/t/ue-5-8-vulkan-crash-on-mali-g76-libgles-mali-so-ue-5-4-4-works/2737388 · https://developer.arm.com/community/arm-community-blogs/b/mobile-graphics-and-gaming-blog/posts/optimizing-3d-scenes-in-godot-on-arm-gpus
- Android sideloading: https://thehackernews.com/2026/06/google-sets-sept-30-deadline-for.html

---

## 7. Addition (28 Sep, after Hilmi asked): the $99 is not the only way onto Enea's iPhone

Sections 0 and 1 read as if the paid Apple account were required. It isn't. The honest ranking `[web]` `[design]`:

| Route | Cost | Needs a Mac | How long an install lasts | Catches |
|---|---|---|---|---|
| **Free Apple ID, sideloaded with AltStore Classic** (AltServer runs on Windows; Sideloadly and SideStore are alternatives) | £0 | No: we build the `.ipa` on GitHub's free macOS runner, and AltStore re-signs it with Enea's own Apple ID | **7 days**, then refreshed. AltStore 2.3 (Sep 2026) refreshes remotely: one cable pairing on iOS below 27, fully on-device on iOS 27 | Max 3 sideloaded apps; about 10 new app IDs a week; no push notifications or in-app purchases. **Fragile:** Apple broke Apple ID sign-in for all these tools in early Sep 2026 (fixed), and a "provisioning profile is banned" error is being investigated. AltStore suggests a spare Apple ID |
| **Someone else's paid account** | $99 a year, paid by whoever owns it | No (CI) | 90 days per build, updates pushed | Only one person pays. Enea can be an internal tester on another account |
| **The web build** (today) | £0 | No | Permanent | Every web limit in section 1 |
| **Xogot on the iPhone** (the project opened inside the Xogot app) | Free "Lite" with project-size limits; Pro is paid | No | Permanent | Can't load native plugins (no Apple-model bridge); Lite's limits may not fit the project (unverified) |
| **Alternative app stores and web distribution** | - | - | - | EU only. The UK regulator has not required them; as of Sep 2026 it had only proposed a rule on in-app payment links `[web]` |

**Recommendation:** start free with AltStore while it's the two of you testing. It costs about ten minutes of setup on Enea's side, entering his own Apple ID in AltStore himself. Pay the $99 only when one of these bites:
- sideloading breaks too often;
- more testers are needed;
- Apple's cloud model is wanted (its entitlement needs a paid account `[web]`);
- the game goes public.

**Not yet proven here:** that Godot's iOS export can be packed into an unsigned `.ipa` on the CI runner for AltStore to re-sign. It is a known technique (archive with code signing off, then zip `Payload/`), and the first iOS spike should confirm it.

**Correction to section 7 (28 Sep, after the research agent's report `docs/studio/IOS-FINDINGS.md`):** remote refresh is not a difference-free experience. Enea needs:
- a one-time PC setup with Developer Mode and a restart;
- the LocalDevVPN app kept connected, and Wi-Fi, for background refresh;
- Apple's sign-in path to keep working. It broke for several days in September 2026, and a missed refresh is silent, so the game stops opening on day 7.

AltStore also takes one of the 3 app slots. Recommendation revised: free sideloading for the first iOS spike only; settle the $99 account (anyone's) before Enea's play becomes routine. See `docs/studio/DEVELOPMENT-PLAN.md` section 7.
