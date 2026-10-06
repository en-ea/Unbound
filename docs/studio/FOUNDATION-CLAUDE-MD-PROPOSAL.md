---
title: "Proposed section for Enea's CLAUDE.md - read FOUNDATION.md first"
created: 2026-10-06
type: proposal
voice: agent-draft
author: Claude, Foundations thread in Hilmi's studio
status: PROPOSAL, not applied; nothing is sent to Enea and his CLAUDE.md is not edited without Hilmi's yes
next_step: Hilmi decides whether this goes to Enea with the merge; if yes, Enea (or his AI, with his OK) pastes it near the top of his CLAUDE.md
---

# Proposed section (for Enea's CLAUDE.md, near the top)

> ## The studio foundation (read before changing people, villages, saves, things or graphics)
> The game now runs on a foundation from Hilmi's studio: the people system (Mind, Body, Choice), the living village, the step 4 save, facts on things, and graphics S1-S5. **Read `docs/studio/FOUNDATION.md` first.** It explains the layers, the rules that keep them working, and worked examples for adding a reaction, a thing, an ability, a saved kind or a region.
> - Every fact goes through the one checked door (`people_bridge.accept`, then `acceptance.gd transact`): no shortcuts, no special cases.
> - Game state changes only through action functions. Visuals and input never write it.
> - Lines marked `# studio:` in your files are the studio's hooks. Keep them, and keep new ones marked.
> - Visible studio changes have switches (`studio/render/*` in project.godot).
> - Before calling a change done, run `tools-src/studio/cloud/runs/regression.sh` and `gate.sh`. Every job must pass and no `FAIL save-image guard` line may appear.
