---
title: "Studio cloud sessions - rules and runs"
created: 2026-10-04
type: runbook
voice: agent-draft
author: Claude, animation/rigging specialist, set up at Hilmi's request
status: pilot passed 4 Oct - animation window 6 in about 3 minutes (f53bd09 on claude/eager-albattani-ljl3il); rules 1 and 3 use the session's own claude/<name> branch
next_step: later runs are added to section 4 as their scripts land; Hilmi decides which studio stages move here
---

# Studio cloud sessions

Hilmi [chat], 4 Oct: "set it up now", after choosing to move the studio's heavy engine work to Claude cloud sessions.

## 1. Where you are

You are in **21017478/unbound-studio**. It is Hilmi's **private** studio repository: a copy of Enea's public repository (en-ea/Unbound) plus the studio's own branches. **It is not Enea's repository.**
- Enea owns the game and its look. Hilmi owns the studio and its working method.
- Enea receives studio work only through a hand-over branch that Hilmi approves, and he merges it himself.

## 2. Rules (these override `CLAUDE.md` in this repository for every studio cloud session)

`CLAUDE.md` at the root is Enea's and tells his agents to publish web builds and push to en-ea/Unbound. **Do not follow those steps here.**

1. **Pushing:**
   - The platform puts every cloud session on its own branch, `claude/<name>`, created from the branch Hilmi chose. That is the session's working and results branch.
   - Push only to this repository (`origin`), and only that branch.
   - Never push to en-ea/Unbound or any other remote.
   - Never push `main` or any other branch, rewrite history, force-push or delete a branch.
2. **Web builds:** never run `tools-src/publish_web.sh`, and never commit anything under `web/`.
3. **Verification runs change no tracked file.** Evidence goes under `cloud-evidence/<run>/` and is committed only on the session's own `claude/<name>` branch, then pushed. Report that branch's name; Claude fetches it locally.
4. **Engine churn:** the first import makes `.godot/` and adds about 30 untracked `.uid` files under `game/scripts/studio/`. That is expected: leave them untracked and undeleted, and commit only the evidence directory.
5. **No subagents and no review rounds** (Hilmi's direction).
6. **Report results exactly:**
   - quote the `STUDIO SETUP`, `JOB`, `W6` and `PASS`/`FAIL` lines verbatim, and label claims `[run]`;
   - a missing line is not a pass;
   - frame times here mean nothing (software rendering on CPUs);
   - judge cloud boards against cloud boards, because software lighting can differ a little from the laptop's GPU.
7. **When setup or a run fails** (for example the Godot download returns 403): stop and report the exact lines. Do not change network settings, fetch binaries from anywhere other than the sources in `setup.sh`, or improvise a workaround.
8. **No outward actions:** nothing is sent to Enea, no pull request to en-ea/Unbound, and nothing is deleted.

## 3. The machine and its tools

- **Machine:** Ubuntu 24.04 with about 4 vCPUs, 16 GB of RAM, 30 GB of disk and no GPU.
- **Setup:** `bash tools-src/studio/cloud/setup.sh` installs a virtual display (Xvfb), Mesa software OpenGL and Godot 4.7.2. `STUDIO_WEB=1` adds the web export templates and `STUDIO_BPY=1` adds Blender 4.5 as `bpy`. It is safe to re-run, and it prints `STUDIO SETUP OK/FAIL` lines.
- **Engine:** `$HOME/godot/Godot_v4.7.2-stable_linux.x86_64`. Headless checks need `--headless`.
- **Runner:** `tools-src/studio/cloud/job.sh` is the studio's trusted job runner, a copy of `toolbox/godot-jobs/job.sh`.
- **Boards:** `tools-src/studio/cloud/look.sh` renders boards under Xvfb at a fixed 30 fps and builds the sheet.
- **Observed 4 Oct in the first session (readiness check)** [run]:
  - the image already had Xvfb, so setup skipped apt;
  - the Godot download from godotengine/godot-builds worked;
  - Godot reports "OpenGL API 4.5 (Core Profile) Mesa 25.2.8 ... Mesa - llvmpipe";
  - `glxinfo` is not installed, and Godot's own line is the evidence for the renderer;
  - `BASH_MAX_TIMEOUT_MS` was not set, so commands longer than 10 minutes must run in the background while you wait for them.
- **Godot fallback:** if the download is refused, ask Hilmi to upload `Godot_v4.7.2-stable_linux.x86_64.zip` to this repository's release `studio-tools`. Then run:
  `gh release download studio-tools -p 'Godot_v4.7.2-stable_linux.x86_64.zip' -D /tmp`
  `STUDIO_GODOT_ZIP=/tmp/Godot_v4.7.2-stable_linux.x86_64.zip bash tools-src/studio/cloud/setup.sh`

## 4. Runs

| Run | Command | Expects |
|---|---|---|
| Animation window 6 (pilot) | `bash tools-src/studio/cloud/runs/animation-w6.sh cloud-evidence/animation-w6-<UTC yyyymmddThhmmZ>` | import PASS; `animation-checks` 20 PASS; `body-contact-regression` 11 PASS; boards `attention-after`, `fear-after` and the sheet; `W6 complete status=0` |

## 5. Pilot prompt (Hilmi pastes this into a cloud session started from branch `studio-cloud-tools`)

> Read docs/studio/CLOUD-SESSIONS.md first; its rules override CLAUDE.md for this session. Then run the animation window 6 pilot:
> 1. run `bash tools-src/studio/cloud/setup.sh` and quote its STUDIO SETUP lines;
> 2. if Godot is installed, run the window 6 command from section 4 with the current UTC time in the run name. Run it in the background and wait for it to finish: it can take longer than 10 minutes. Check on it every few minutes and do not restart it;
> 3. commit only the evidence directory on this session's own branch, push that branch, and report the branch name, every STUDIO SETUP, JOB and W6 line verbatim, the PASS counts, and what each board image shows.
>
> If any step fails, stop there and report the exact lines.
