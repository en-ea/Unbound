---
title: "The studio branch - what happens next, and how to reply"
created: 2026-09-28
type: agent-draft
voice: agent-draft
author: Claude (claude-opus-5-5), lead agent in Hilmi's studio
status: proposal, waiting for Enea's reply
next_step: Enea replies (any of the ways below); the studio then plans the next steps with his answers
---

# What happens next

## What we would like from you, Enea

1. **Answers to D1-D6** (`START-HERE.md`). One line each is fine, and "not sure yet" is an answer.
2. **Anything that clashes with what you are building now**: the rest of the fighting pass, new forest enemies, hit feel, the loot and gear chase. We plan around your work, not over it.
3. **Your picks** when we send look boards: renders of your own game in different camera framings, and with each renderer. You choose by picture, never by description.

## How to reply

Pick whichever is easiest:
- a message through Hilmi;
- comments on the draft pull request for this branch;
- a file `docs/studio/FROM-ENEA.md` on your own `main` or branch. We read it before planning anything.

## What we propose to do next (after your answers)

| Step | What | Needs you? |
|---|---|---|
| 1 | **The world kernel inside Godot:** the prototype ported to typed GDScript, timed on phones, with the same world on every phone. **Done 29 Sep** (`KERNEL-S2.md`) | No |
| 2 | **A look board:** your game rendered in the proposed camera framings, and with the Compatibility vs Mobile renderer (the Mobile renderer runs on Metal on the iPhone, but needs your lighting retuned) | Yes: you pick |
| 3 | **Three small phone fixes**, each offered as its own small pull request for you to merge or not: (a) HUD placed from the phone's safe area; (b) one swipe can't exit the game mid-fight; (c) saves written safely, so a crash mid-save can't wipe progress | Yes: you merge or not |
| 4 | **Automatic builds:** an Android app and an iPhone app built on GitHub for every change on this branch, only if you agree to a small build workflow here | Yes |
| 5 | **The deep village, headless:** about 30 people with values, rumours, three kinds of misbehaviour and a storyteller that paces events, tested by running thousands of simulated years before anything reaches a phone | After D1 |
| 6 | **You in that village,** on both phones | After D1, D4, D5 |

## How we work alongside you

- Our work stays on `studio`.
- New code goes in its own folders (`game/scripts/studio/`, `tools-src/studio/`). Your files only get small, clearly named hooks.
- We rebase onto your `main` weekly, so this branch always sits on your latest work.
- Anything you want in `main` arrives as a small, separate pull request that **you** merge.
- **We won't** push to `main`, touch your live site, or rewrite your systems.
