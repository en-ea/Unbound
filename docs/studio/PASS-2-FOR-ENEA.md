---
title: "For Enea - what the studio built on your game in Pass 2, and why"
created: 2026-10-01
type: note
voice: agent-draft
author: Claude, lead agent in Hilmi's studio
status: for Enea to read and play; nothing here is decided until he says so
next_step: Enea plays it (section 5) and tells Hilmi what feels right or wrong; whether and when any of it goes into main is his call
---

# For Enea: the village around you

**In one line:** the village now lives around the player. You can meet its people, give them things or pick a fight with them, and they react as themselves and remember. All of it is built on your systems, behind a switch you control.

## 1. Why

- **It's your living world, made playable.** You said the simulated living world "sounds good if done well, keeps the game playable after the story". This is the first part of it you can walk into: a village with a life of its own, not a backdrop.
- **The player is a person among people.** Villagers notice you, answer what you actually do in their own way, and remember it later. It happens through things you see and do with your hands, not through menus or quest text.
- **It stays optional.** Most of the time the village just gets on with its day. Now and then something small happens near you. Ignore it and go adventuring, and the game is the same game.
- **Your work is the base.** Hilmi asked the studio to work with you as a creative partner: "we are working towards the same goals and should see his work as a creative partner". So this pass extends what you built rather than building beside it (section 3).

## 2. What you'll see

- **Something happens near you.** After a few quiet minutes in the village:
  - two villagers quarrel at the well;
  - a neighbour brings bread to a hungry house;
  - friends stop to chat, or one helps another carry a sack;
  - children play;
  - someone eyes a goose pen. If they see you watching, they think better of it.
- **A day of work.** People farm, cut wood, herd, mill and smith. They eat at midday, chat at the well in the evening and go indoors at night.
- **Talk to anyone.** Every villager has a short line through your talk screen, which fits their trade, their age and what they remember of you. A child talks differently from a smith.
- **Give…** coins or food. It warms them to you, and softens a grudge.
- **Pick a fight.** This talk option appears for grown-ups only. It is never offered for children or for your own characters. Then:
  - your lock-on and Attack take over;
  - the villager answers in their own way: puzzled, protesting, running home, calling for help, pleading, knocked down, or fighting back;
  - bystanders who could actually see it step in, shout, run or back away;
  - one of them tells the elder;
  - later, the right people greet you coldly or warn you, and people who saw nothing know nothing.

## 3. Built on your systems

| Yours | What the village does with it |
|---|---|
| Lock-on ring and Attack | "Pick a fight" makes the villager a target your fighter locks on to. A normal tap never hits a villager |
| Parry and dodge (`receive_attack`) | A villager who fights back swings through it. There is a wind-up, then your glint, then the blow. Parry it and they stagger |
| The bandits' sight cones and line of sight | They decide who saw it. Walls block it, and night and sneaking count |
| Talk screen, portraits and voices | Every villager talks through them. There are four new voices |
| Wren, Brakk, Morrow and the Seeker | Known to the village and protected: never accused, never hurt, never part of a crime. Their quests and bodies are untouched |
| Your hunting, carcasses, hauling and ox cart | Merged in (your camera-test up to 4a1df30). Next, carrying a person would be built on your hauling, not a copy of it |

## 4. You're in control

- **Settings → "Living village".** Turn it off and you have your village exactly as it was. It is on by default on this branch. In `main` it's your choice.
- **Nothing goes into `main` without your OK.**
- **Merging works both ways.** The studio merges your branches into `studio` as soon as it sees new work. You can merge `studio` into yours whenever you like.
  - For `web/`, keep your own build.
  - The few files of yours that `studio` touches are listed in [PASS-2-REPORT.md](PASS-2-REPORT.md), section 8. They are small marked hooks and a few fixes, such as Buy on 4.7 and crash-safe saves.

## 5. Try it

The `studio` branch's `web/` holds this build, so a preview of the branch shows it. To run it locally from the repository, use `node tools-src/serve.js --local` and open `http://127.0.0.1:8087/`.

1. Walk to the square and wait about three minutes. Watch what happens nearby.
2. Talk to a few people. Give someone an apple.
3. Pick a fight with a grown-up and hit them a few times. A bold one fights back: parry when you see the glint.
4. Walk off, come back later, and talk to them and to whoever saw it.

## 6. What's yours to decide

Hilmi will pass on whatever you say.
- **Tone.** Do you want hitting villagers in Unbound at all, and how dark? You said "likely dark".
- **Pace.** How often should something happen near you? Now it's every few quiet minutes.
- **Look and feel.** The reactions, the lines and the outfits by trade. They use existing animations, so some may look stiff.
- **Landing.** Whether, when and how any of this goes into `main`.

## 7. Rough edges, honestly

- **Speed.** On Hilmi's PC the villagers cost under 1 ms a frame. There are two pauses: about 1 s when you press Play, and about a quarter of a second when the first villager appears. It hasn't been checked on the iPhone yet.
- **Wild animals in the village.** Your boars and wolves wander into the village and fight a player who stands still. That's your game working as designed. The villagers don't react to animals yet.

The full technical report, with every check, is [PASS-2-REPORT.md](PASS-2-REPORT.md).
