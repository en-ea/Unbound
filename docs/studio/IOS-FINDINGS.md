---
title: "iPhone-specific findings for Unbound (research agent)"
created: 2026-09-28
type: agent-draft
voice: agent-draft
author: Claude research agent (subagent of the session-2 lead)
status: reviewed by the lead 28 Sep (repo claims spot-checked); folded into docs/studio/DEVELOPMENT-PLAN.md section 7
next_step: the lead folds these into docs/studio/DEVELOPMENT-PLAN.md and the first iOS spike
---

# iPhone-specific findings for Unbound

**Labels:** `[repo]` measured by me in `game/` · `[web]` cited source (numbered, section 9) · `[design]` my proposal or inference. Nothing was installed, pushed or sent.

## 0. Verdict

1. **"He will experience no difference" is not true.** Remote AltServers remove the PC from the *weekly* refresh, and nothing else. Five things still differ:
   - a one-time PC setup;
   - a VPN app that must stay connected;
   - a hard 7-day expiry that bites whenever Apple's sign-in path breaks;
   - one of his two free app slots;
   - no TestFlight-style feedback or crash reports.

   Sign-in did break in 2026: every AltStore sign-in failed for several days in early September `[web 5,6]`. Section 1 gives the precise answer.
2. **The free route is fit for a first spike, not for routine feel-testing.** `[design]` Use it to prove the build runs on his phone, then ask Enea about the $99 account before his play sessions become regular.
3. **An installable .ipa from Godot 4.7.2 on `macos-26` with no paid account is proven by others** `[web 12,13]`:
   - export the Xcode project only;
   - `xcodebuild build` (not `archive`) with signing off;
   - zip the result into `Payload/`.

   There are four traps to guard in CI (section 3). One is ours alone: an unsigned binary carries no entitlements, so AltStore cannot grant the memory entitlement unless we ad-hoc sign with it `[web 9]` `[design]`.
4. **The biggest runtime finding is the renderer.** Unbound uses the Compatibility renderer on mobile `[repo]`. On iOS that runs on Apple's deprecated OpenGL ES 3.0, not Metal `[web 17]`. The shader baker and native Metal only come with the Mobile renderer `[web 18,19]`. Switching changes the look, so it is Enea's call, backed by a side-by-side board `[design]`.
5. **Three game-code items will bite natively and are cheap to fix** `[repo]` `[design]`:
   - HUD margins sized for the web's inset canvas;
   - one-swipe exits from the home-indicator setting;
   - an in-place save write that a kill can truncate.

## 1. The precise answer: what Enea experiences with AltStore Classic 2.3 and Remote AltServers

```
 once (needs a Windows PC + cable)        weekly (automatic, IF all conditions hold)            when it breaks
 ───────────────────────────────          ─────────────────────────────────────────            ──────────────
 iTunes + iCloud (Apple's installers)     iOS wakes AltStore in the background ─► sign in to    app will not open after
 AltServer ─► install AltStore            Apple via a community anisette server ─► re-sign ─►   day 7; data kept; refresh
 Trust profile, Developer Mode, restart   reinstall through LocalDevVPN loopback                restores it. If AltStore
 LocalDevVPN (App Store) + pairing        conditions: Wi-Fi (not cellular), VPN connected,      itself lapses: back to the
 (iOS 26: pair via PC; iOS 27: on-device) Apple accepts the request, profile not "banned"        PC with AltServer
```

| Question | Answer | Label |
|---|---|---|
| Is a computer ever needed? | Yes, to install AltStore Classic at all. The UK has no alternative marketplaces, so AltStore PAL is not an option. On iOS 26 the pairing step is also "Pair with a PC". On iOS 27, AltStore 2.3 can generate the pairing file on the phone. | `[web 1,2,3,20]` |
| Does anything recur weekly? | Only if background refresh fails. AltStore 2.3rc suppresses the "Couldn't reach remote AltServer" error when a background refresh runs without the VPN, so a missed week is silent. A Siri Shortcut ("Add to Siri", runnable from a Personal Automation) can force a refresh. | `[web 2,4]` `[design]` |
| Does 2.3 make it computer-free on iOS 26? | After setup, yes for refresh. The setup still needs a PC. | `[web 1,3]` |
| Is it reliable today? | Mixed. After the 14 Sep release, reports include: <br>- 2FA codes never arriving in remote mode (some fixed by aligning language and region locale); <br>- "remote AltServer couldn't complete this operation" on new phones; <br>- iOS 27 pairing errors fixed by reinstalling AltStore. <br>The on-device HTTP 503 fix (PR #1796) was still open on 28 Sep. | `[web 6,7]` |

**So:** in a good week, Enea notices nothing except keeping LocalDevVPN on. In a bad week, the game stops opening on day 7 until someone fixes the chain.

## 2. Free sideloading in detail (A)

### 2.1 Limits

| Limit | Finding | Label |
|---|---|---|
| 3 active apps | AltStore counts as one: "3 apps (including itself)" per SideStore's docs; AltStore's own page says 3 sideloaded apps. That leaves **2 slots**, fewer if Enea already sideloads anything. Deactivating an app backs up its data and frees a slot. | `[web 4,8]` |
| 10 App IDs per 7 days | Reinstalling a new build of the same app reuses its existing App ID while that ID is live; AltStore only registers a new one when none matches. An App ID lasts 7 days, so a weekly refresh re-registers about one per app. AltStore reuses its first rewritten bundle ID (`<ours>.<TEAMID>`) for later installs. Unbound has no app extensions, so it costs 1 App ID a week. | `[web 9]` |
| Certificates | Signing the same Apple ID from another tool (Sideloadly, Xcode, a second device) can revoke AltStore's certificate. Every app then stops opening. Use one Apple ID for one tool; AltStore suggests a throwaway ID. | `[web 10]` |

### 2.2 The 2026 incident record (why "no difference" fails)

| Date (2026) | What happened | Effect | Label |
|---|---|---|---|
| 8 Feb | AltServer 1.7.3 (Windows) fixes -22410 install/refresh error | refresh blocked until updated | `[web 11]` |
| 24 Mar | AltServer 1.7.4 fixes "apps crashing on launch on iOS 26.4" | sideloaded apps would not open | `[web 11]` |
| 22 Aug on | 2FA loop: Apple stops honouring the Xcode 11.2 client identity (#1772, open) | sign-in fails | `[web 7]` |
| 29 Aug on | "The provisioning profile is banned" (0xe8008024) on some devices (#1775, open, 10 comments, no fix) | app cannot install or refresh; advice given there is a new Apple ID | `[web 7]` |
| ~6-11 Sep | Apple's GrandSlam edge rejects any client naming itself Xcode; "Nobody can install or refresh AltStore" (#1790) | all sign-ins fail with HTTP 503. Fixed for AltServer about 11 Sep; the on-device path was still open on 13 Sep (#1796) | `[web 5,6]` |

About three multi-day breaks in 2026 that would have stopped a free-signed app opening if they lasted past its 7 days `[design]`. **Source conflicts:**
- The AltServer release-notes page stops at 1.7.4, although issue threads cite 1.7.5-1.8.1 `[web 11,6]`.
- AltStore's FAQ dates version 2.2 to 16 Apr 2026, while iDownloadBlog and AltStore's own X post date it to April 2025 `[web 2,21]`.

### 2.3 Capabilities with a free Apple ID

| Capability | Free account | Matters for | Label |
|---|---|---|---|
| Increased memory limit | **Works** through AltStore 2.3: about 6 GB vs about 3.3 GB on an iPhone 15 Pro Max (8 GB, iOS 27). The binary must carry the entitlement (section 3) | on-device model, big worlds | `[web 9,22]` |
| Push, Game Center, Sign in with Apple, iCloud (CloudKit, KV, documents), Network extensions, Associated domains, Access WiFi info, App Attest | **No** (Apple's capability table, "Apple Developer" column) | sync fallbacks, identity, leaderboards | `[web 23]` |
| App groups, Background modes, Keychain sharing, HealthKit, Data protection | Yes | - | `[web 23]` |
| Private Cloud Compute model, Foundation Models adapters | No: managed entitlements for paid members | cloud villager minds | `[web 24,25]` |
| Multicast/broadcast networking | No: a restricted entitlement requested from Apple | LAN discovery | `[web 26]` |
| `GCSupportsGameMode`, `LSSupportsGameMode`, `LSApplicationCategoryType` | These are Info.plist keys, not entitlements, so they survive re-signing. Set them through Godot's `application/additional_plist_content`. Game Mode is reported to work for Xcode and TestFlight builds; unconfirmed for AltStore builds | Game Mode | `[web 27,28]` |

### 2.4 Every difference from a TestFlight install

| # | Sideloaded (free, AltStore) | TestFlight ($99) | Label |
|---|---|---|---|
| 1 | Once: PC, iTunes and iCloud, AltServer, cable, Wi-Fi sync, Apple ID in AltServer, Trust profile, **Developer Mode + restart**, LocalDevVPN, pairing | Install the TestFlight app and tap the invite | `[web 3,1]` |
| 2 | Signature lasts 7 days; background refresh needs Wi-Fi plus the VPN; a silent miss means no launch on day 8 | Build valid 90 days, no refresh | `[web 4,2]` |
| 3 | Uses 1 of 2 free slots | No limit | `[web 8]` |
| 4 | New builds appear through an AltStore source JSON (update badge, then tap) or a Files import | Optional automatic updates | `[web 29]` |
| 5 | No push, Game Center, iCloud, Sign in with Apple or cloud model | All available | `[web 23]` |
| 6 | Bundle ID becomes `<ours>.<TEAMID>`, a different app from a later TestFlight/App Store install: **saves do not carry over by themselves** | Stable ID | `[web 9]` `[design]` |
| 7 | Crashes only via Settings > Analytics Data or our own SDK; no screenshot feedback | Crashes and feedback reach App Store Connect automatically | `[web 30]` |
| 8 | Relies on community anisette servers and AltStore keeping pace with Apple (2.2 above); Apple ID lock risk on shared anisette servers | Apple-supported | `[web 6,31]` |
| 9 | Same binary, development-signed. No performance difference expected | - | `[design]` |

## 3. Building the .ipa on GitHub `macos-26` with no paid account (B)

```
godot 4.7.2 (windowed if Mobile renderer)  ─►  Xcode project only  ─►  xcodebuild build, Release, iphoneos,
  --export-release, placeholder team ID                                 CODE_SIGNING_ALLOWED=NO, DEBUG_INFORMATION_FORMAT=dwarf
                                                                        ─► codesign -s - --entitlements (memory)  [design]
                                                                        ─► Payload/Unbound.app ─► zip ─► .ipa ─► Release asset ─► AltStore source
```

| Item | Finding | Label |
|---|---|---|
| Runner | `macos-26` = `macos-latest` (arm64). Default Xcode 26.6; 26.0.1-26.5 also present. `xcode-27` (macOS 27) is in public preview. `macos-14` is deprecated and its Xcode fails to link 4.7.2 templates | `[web 14,15]` |
| Working examples | **Chrono-Exponent `ios-export.yml`**: Godot 4.7.2, `macos-latest`, placeholder team `ABCDE12XYZ`, project-only export, `xcodebuild build ... CODE_SIGNING_ALLOWED=NO`, `ditto` into Payload, GitHub Release; green runs on 19 Sep. **griss `testflight.yml`**: 4.7.2, paid signing, useful for its hang fixes. Avoid TatsunoToru's template: Godot 4.3, broken URLs, and it zips a .pck, not an app | `[web 12,15]` `[web 16]` |
| `archive` vs `build` | With `CODE_SIGNING_ALLOWED=NO`, recent Xcode archives omit the .app; use `build` | `[web 32]` |
| Export preset | Godot 4.7 keys: `application/bundle_identifier`, `export_project_only=true`, "Apple Development"/"Apple Distribution" identities. Needs ETC2/ASTC import (**we have it** `[repo]`) and an icon. Ours is 512 px `[repo]`; griss added a 1024 px icon after a silent validation failure | `[web 15]` `[repo]` |
| Debug vs release | Pass `--export-release`. One project shipped the debug template to the App Store for months. Release templates compile out debug checks: a looping tween on a freed node froze griss on device but not in the editor | `[web 18,15]` |
| Link errors | `_SDL_IsIPad`/`_SDL_IsAppleTV` are undefined in the 4.7.x templates. They bite only with `DEAD_CODE_STRIPPING=NO`, `ENABLE_TESTABILITY=YES` or `-rdynamic`. The fix merged into master today for 4.8 | `[web 33]` |
| Hangs | dsymutil or `SWBBuildService` stalls on the runner. griss settled on `DEBUG_INFORMATION_FORMAT=dwarf -jobs 1 SWIFT_ENABLE_EXPLICIT_MODULES=NO` and a 20-minute timeout | `[web 15]` |
| Shader baker | Skipped **silently** under `--headless`, which caused 5-130 s first-draw freezes on iOS in one project. Fix: windowed export, the Xcode 26 Metal toolchain installed, and fail unless the log shows "Started Baking shaders" plus `.metal.cache` files. Applies only if we move to the Mobile renderer | `[web 18]` |
| Does AltStore re-sign an unsigned .ipa? | Yes. It is common practice (tutorials and several workflows publish unsigned IPAs for AltStore or SideStore to sign) | `[web 32]` |
| **Entitlements** | AltSign reads entitlements from the binary's code signature (`ldid::Entitlements`). An unsigned build has none, so ad-hoc sign with an entitlements file before zipping. Untested | `[web 9]` `[design]` |
| Outward action | Workflows run on our branch of the public `en-ea/Unbound`. Pushing needs Hilmi's yes each time (studio rules) | `[design]` |

## 4. Godot 4.7 runtime on the iPhone (C)

| Topic | Finding | What we do | Label |
|---|---|---|---|
| Renderer | Ours is `gl_compatibility` for mobile `[repo]`. iOS Compatibility = OpenGL ES 3.0 through `EAGLContext` `[web 17]`. The Mobile renderer defaults to native Metal; MoltenVK stays optional (`driver.ios="vulkan"`) `[web 19]` | Look board, Compatibility vs Mobile, for Enea | `[design]` |
| ProMotion | The 4.7.2 Info.plist sets `CADisableMinimumFrameDurationOnPhone`; the display link asks for 120 when `allow_high_refresh_rate` is on (default true) `[web 17,19]`. Low Power Mode drops to 60 `[web 34]` | See the next row | - |
| Frame caps | The game caps at 30/40/60 with `Engine.max_fps` and sets physics ticks to the cap `[repo]`. `max_fps` pacing is sleep-based and known to be uneven `[web 35]`. 40 divides 120 but not 60 | Measure frame-time spread on device; prefer 30/60; decouple physics from the cap | `[design]` |
| Thermal | No `thermalState` API in Godot | Watch frame time in 20-minute runs; small plugin if needed | `[web 17]` `[design]` |
| Safe area | The web page has no `viewport-fit=cover`, so Safari insets the canvas `[repo]`. Native is edge to edge. 16 Pro Max landscape insets: 62/62 pt sides, 21 pt bottom `[web 36]`. HUD `MARGIN.x`=64 viewport units ≈ 39 pt at 720/440 scale `[repo]` | Place the HUD from `DisplayServer.get_display_safe_area()` | `[design]` |
| Gestures | `hide_home_indicator` (default true) defeats `suppress_ui_gesture`, so one swipe up leaves the game (#104411, open) `[web 37]`. The joystick is touch-anywhere on the left half `[repo]` | Set `hide_home_indicator=false` | `[design]` |
| Audio | Default session `Ambient`: muted by the silent switch, mixes with his music. `Playback` ignores the switch. Calls and Siri map to `FOCUS_OUT`/`FOCUS_IN` `[web 19,17,15]` | Enea chooses; Ambient matches most games | `[design]` |
| Saving | `FOCUS_OUT` also fires for Control Centre, notifications and audio interruptions; `PAUSED` fires on background `[web 17]`. We save on both and every 15 s, writing `save.json` in place `[repo]`. A kill mid-write truncates the file, and `_read()` then starts a fresh game `[repo]` | Write `.tmp`, then rename; keep one backup | `[design]` |
| Memory | About 3.3 GB default, about 6 GB with the entitlement (8 GB phone). Godot has `entitlements/increased_memory_limit` and sends `NOTIFICATION_OS_MEMORY_WARNING` | Log the warnings; budget under 3 GB without the entitlement | `[web 22,17]` `[design]` |
| Open iOS issues | Magenta screen on start in Low Power Mode (#118258). Bad `targeted_device_family` gives a silent legacy window (#122265). Shader cache in Documents (#106028). `quit()` does nothing (#110626) | Test Low Power Mode; set the family to 0 (iPhone) | `[web 37]` |

## 5. On-device AI from Godot (D)

| Topic | Finding | Label |
|---|---|---|
| Bridge | No Godot Foundation Models plugin exists (GitHub search). Route: a SwiftGodot GDExtension (bindings "for Godot 4.6"; v0.79, Aug 2026) packed as an iOS xcframework. Models to copy: GodotApplePlugins (Mergeable Library xcframework) and SwiftGodotAppleTemplate | `[web 38,39]` |
| Gotchas | Godot 4.6/4.7 log errors for iOS-only extensions without desktop stubs (`include_tags` arrives in 4.8). Static-library path bug #108012 is open. One Sep 2026 report: a Sentry GDExtension crashes at `initialize_extensions` with Xcode 27 (maintainer could not reproduce) | `[web 40,37,41]` |
| Free account | Baseline `SystemLanguageModel` sessions, guided generation and tools need no managed entitlement (a guide built on Apple's iOS 27 beta docs), so it should run in a sideloaded build. Nobody has published a test | `[web 24]` |
| Preconditions | Apple Intelligence on, a supported Siri language, model downloaded. "Not in Game Mode" appears only in blogs, not Apple docs; r2's caveat rests on that | `[web 42,25]` |
| SDK | iOS 26 APIs build with Xcode 26.6 on `macos-26`; iOS 27 APIs need the `xcode-27` preview runner | `[web 14]` `[design]` |
| llama.cpp | NobodyWho: "Godot has no iOS export". Community llama.cpp GDExtensions exist, with no confirmed iOS build. An in-process model counts against the app's memory, so we would need the entitlement | `[web 43,22]` |

**Spike S3 shape** `[design]`: one Swift class wraps availability, session and streaming, and exposes a signal per token. Measure availability during play with `GCSupportsGameMode` true, then false.

## 6. Networking (E)

- **Nakama Godot client:** no iOS-specific issues filed. The last tag is v3.4.0 (Mar 2024), with commits through 21 Sep 2026. Those include `Nakama.get_device_id()`, added because `OS.get_unique_id()` can be read by other apps `[web 44]`.
- **App Transport Security** applies only to `URLSession` and APIs built on it, not to lower-level sockets (Apple DTS) `[web 45]`. Godot's own HTTP and WebSocket stack is presumably outside it. Use TLS anyway `[design]`.
- **Identity:** the sideloaded bundle ID and vendor differ from a future TestFlight build. Tie the Nakama account to a linkable identity, not the vendor ID `[design]`.
- **LAN co-op:** needs `NSLocalNetworkUsageDescription` and a one-time prompt. Unicast to a known IP works. Broadcast and multicast need the restricted multicast entitlement, which a free account cannot get `[web 26]`. Godot multicast on iOS also has an open bug (#107508) `[web 37]`. Prefer relay through Nakama `[design]`.
- **Background:** iOS suspends a backgrounded app and Godot's loop stops. Reconnect the socket on `NOTIFICATION_APPLICATION_RESUMED` `[web 17]` `[design]`.

## 7. Crash reports without App Store Connect (F)

- **On the phone:** Enea opens Settings > Privacy & Security > Analytics & Improvements > Analytics Data, finds `Unbound_<date>` (crash) or `JetsamEvent_<date>` (memory kill), and shares it. Logs can also move to a Windows PC `[web 30]`.
- **Sentry for Godot 2.2.0** (15 Sep 2026) supports iOS devices on Godot 4.5+ and needs no App Store Connect `[web 41]`. Watch its open iOS startup-crash report.
- **Symbols:** `DEBUG_INFORMATION_FORMAT=dwarf` (the hang workaround) leaves native frames unreadable. Run `dsymutil` as its own step with a timeout and keep the dSYM as an artifact `[design]`.

## 8. What I could not verify

1. Whether Remote AltServer refresh holds across a real 7-day window for a UK free account. No measured reports exist; the issues are mixed.
2. Whether AltStore 2.3 includes the on-device HTTP 503 fix (#1796 open on 28 Sep).
3. Whether an ad-hoc-signed Godot .ipa keeps `increased-memory-limit` through AltStore (inferred from AltSign's code).
4. Whether the remote AltServer ever receives Enea's pairing record. The docs are silent.
5. Game Mode vs Foundation Models, and Foundation Models in a free-signed build.
6. OpenGL ES behaviour and performance on iOS 27 for the Compatibility renderer.
7. Whether Enea's phone locale triggers the remote-mode 2FA bug (language region different from device region).
8. Sentry's free-tier limits.

## 9. Sources (accessed 28 Sep 2026; dates are the source's own)

1. AltStore FAQ, Remote AltServers (updated about 15 Sep 2026): https://faq.altstore.io/altstore-classic/remote-altservers
2. AltStore Classic release notes (2.3, 14 Sep 2026): https://faq.altstore.io/release-notes/altstore · 2.3rc and on-device pairing, iOS 27: https://www.patreon.com/rileyshane/posts/altstore-classic-169262530
3. AltStore install guide, Windows (Developer Mode, Trust): https://faq.altstore.io/altstore-classic/how-to-install-altstore-windows
4. AltStore Getting Started (7 days, 3 apps, background refresh, Siri): https://faq.altstore.io/altstore-classic/your-altstore
5. AltStore PR #1790, HTTP 503 (10 Sep 2026): https://github.com/altstoreio/AltStore/pull/1790 · issue #1789: https://github.com/altstoreio/AltStore/issues/1789
6. AltStore PR #1796, on-device 503 (13 Sep 2026): https://github.com/altstoreio/AltStore/pull/1796 · issue #1782: https://github.com/altstoreio/AltStore/issues/1782
7. AltStore issues #1772, #1775, #1803, #1804, #1811 (Aug-Sep 2026): https://github.com/altstoreio/AltStore/issues?q=1772+OR+1775+OR+1803+OR+1804+OR+1811
8. AltStore Activating Apps: https://faq.altstore.io/altstore-classic/activating-apps · SideStore FAQ: https://docs.sidestore.io/docs/faq
9. AltStore source, `FetchProvisioningProfilesOperation.swift`: https://github.com/altstoreio/AltStore/blob/marketplace/AltStore/Operations/FetchProvisioningProfilesOperation.swift · AltSign `ALTApplication.mm`: https://github.com/rileytestut/AltSign/blob/master/AltSign/Model/ALTApplication.mm
10. AltStore issues #1597, #1330 (certificate revokes): https://github.com/altstoreio/AltStore/issues/1597
11. AltServer release notes: https://faq.altstore.io/release-notes/altserver
12. Chrono-Exponent PR #6 and workflow (19 Sep 2026): https://github.com/NeyJealous/Chrono-Exponent/pull/6
13. wuge0/Actions-IPA (Godot, no Mac): https://github.com/wuge0/Actions-IPA
14. GitHub runner images README and macOS 26 arm64 readme: https://github.com/actions/runner-images
15. griss PRs #3, #11, #18, #20 and `testflight.yml` (Sep 2026): https://github.com/superhighfives/griss/pull/11
16. TatsunoToru template: https://github.com/TatsunoToru/godot-unsigned-ios-build
17. Godot 4.7.2 source: https://github.com/godotengine/godot/tree/4.7.2-stable/drivers/apple_embedded · https://github.com/godotengine/godot/tree/4.7.2-stable/platform/ios · https://github.com/godotengine/godot/tree/4.7.2-stable/misc/dist/apple_embedded_xcode
18. Decentraland godot-explorer #2891 and PR #2886 (Sep 2026): https://github.com/decentraland/godot-explorer/issues/2891
19. Godot 4.7.2 ProjectSettings and iOS export docs: https://github.com/godotengine/godot/blob/4.7.2-stable/doc/classes/ProjectSettings.xml · https://github.com/godotengine/godot/blob/4.7.2-stable/platform/ios/doc_classes/EditorExportPlatformIOS.xml
20. Apple, alternative app distribution regions: https://support.apple.com/en-us/118110
21. iDownloadBlog, AltStore 2.2 (16 Apr 2025): https://www.idownloadblog.com/2025/04/16/altstore-v2-2-released/
22. SideStore #1616, memory limit on a free account (24 Sep 2026): https://github.com/SideStore/SideStore/issues/1616
23. Apple, Supported capabilities (iOS): https://developer.apple.com/help/account/reference/supported-capabilities-ios
24. 3Nsofts, Foundation Models iOS 27 entitlements (24 Jul 2026): https://3nsofts.com/guides/foundation-models/foundation-models-api-ios-27-entitlements
25. Blake Crosley, Foundation Models explained (2026): https://blakecrosley.com/blog/apple-foundation-models-framework
26. Apple TN3179, local network privacy: https://developer.apple.com/documentation/technotes/tn3179-understanding-local-network-privacy · https://developer.apple.com/forums/thread/772642
27. Apple forums, "How to Enable Game Mode": https://developer.apple.com/forums/thread/782343 · https://developer.apple.com/documentation/bundleresources/information-property-list/lssupportsgamemode
28. balatro-mobile-maker #141 (Game Mode on a sideload, Jan 2025): https://github.com/blake502/balatro-mobile-maker/issues/141
29. AltStore, Make a Source: https://faq.altstore.io/developers/make-a-source
30. Apple, Acquiring crash reports and diagnostic logs: https://developer.apple.com/documentation/xcode/acquiring-crash-reports-and-diagnostic-logs
31. SideStore anisette docs (account-lock warning): https://docs.sidestore.io/docs/advanced/anisette
32. Unsigned-IPA practice: https://github.com/baimour/Making-Unsigned-iPA-Files · https://github.com/rnetis/RevIQ/pull/1 · https://github.com/EmoXW/GlassIPA
33. Godot #122549 and PR #123903 (merged 28 Sep 2026): https://github.com/godotengine/godot/issues/122549
34. Godot PR #85026 (Low Power Mode refresh): https://github.com/godotengine/godot/pull/85026
35. Godot #99728 (`max_fps` pacing): https://github.com/godotengine/godot/issues/99728
36. Use Your Loaf, iPhone 16 screen sizes: https://useyourloaf.com/blog/iphone-16-screen-sizes/
37. Godot issues #104411, #118258, #122265, #106028, #110626, #108012, #107508: https://github.com/godotengine/godot/issues?q=is%3Aopen+label%3Aplatform%3Aios
38. SwiftGodot: https://github.com/migueldeicaza/SwiftGodot
39. GodotApplePlugins: https://github.com/migueldeicaza/GodotApplePlugins
40. godot-att-ios #8 (4.7 stubs): https://github.com/poingstudios/godot-att-ios/issues/8
41. sentry-godot README and #995 (27 Sep 2026): https://github.com/getsentry/sentry-godot · https://github.com/getsentry/sentry-godot/issues/995
42. onmyway133, Foundation Models (the Game Mode claim): https://github.com/onmyway133/blog/issues/1063
43. NobodyWho README: https://github.com/nobodywho-ooo/nobodywho
44. nakama-godot commits and PR #231: https://github.com/heroiclabs/nakama-godot/pull/231
45. Apple forums, ATS scope (Quinn, DTS): https://developer.apple.com/forums/thread/747421
