# Game plan (decided with the owner)

The big shape of the game. DESIGN.md has the look and feel; PLAN.md has the build rules.

## World
- **Three lands.** Mainland (start), a second land (details open), and a third land that is the ultimate goal.
- **Each land is a home village with regions around it** (meadow, forest, highlands, coast, caves...). Regions
  are separate scenes joined by paths, with a short load at each border. Only one region is loaded at a time.
- **Woken shrines are fast-travel points.** Second land by boat; the third has its own special way in (story).
- **Expandable:** a new region is a new path out of a village. Each land has its own people, look and village style.
- **Co-op idea:** player 2 can start on the second land, player 1 on the mainland; the story brings them together.
  Code must keep state separate from visuals (already a rule) so this stays possible.

## Story and after it
- The story unlocks the lands in order. Each land has an arc and a guardian; the third land's "strong one" is the big one.
- **After the story** all three lands stay open, with: ruins that change each visit, roaming elite beasts,
  veil nights (random events), relic hunting, growing your home and village, co-op. More added over time.

## Getting stronger
- **Gear:** tools, weapons, armour. Skills level with use (built).
- **Classes:** you start as a normal villager. Early in the story you unlock a class tree. You progress it
  through levels and achievements and pick abilities, which you keep.
- **Relics (add-on):** rare equippable items that change an ability (e.g. your roll leaves fire).
- **Rarities:** Common, Uncommon, Rare, Epic, Legendary, then **Mythic** (special, rare but findable).
  Above that, **Heirlooms**: only 3 exist, one per land, tied to the story (a weapon passed down for generations).

## Money
1. Your home and its upgrades (buy one of a few).
2. **Village projects:** fund buildings that unlock things (smith = better gear, harbour = boat trips). Easy to add more.
3. A trader with changing rare stock.

## Companions
- **One special companion** you keep: fights beside you and does special tasks only they can do.
- **A few casual ones:** each has a purpose, or you send them on trips to gather or explore.

## Owner notes (round 2)
- **Romance (light):** one townsperson you slowly warm up to, picked at random per save, so friends compare who they got.
- **Festivals:** fine, much later.
- **Betrayal:** one of the main people (not the big three) betrays you a little. In co-op this can be a player, told in secret.
- **Weapons:** sword (shield always optional), greatsword, scythe, bow, magic staff. Maybe later: hammer, spear,
  dual blades / general dual wielding. Not wanted: fists, whip, throwing, crossbow.
  Switching: two slots (e.g. melee + bow or staff), one button swaps them.
- **Knock-out:** a toggle (lose nothing / drop items where you fell).
- **Bases:** one per land.
- **Blacksmithing minigame:** maybe, much later.
- **Getting to the 2nd land:** open (boat, bridge, horse?).
- **Balancing:** all numbers (costs, drops, XP curves, damage, prices) live in one data file with formulas, tuned together
  once the forest, money and classes exist. Until then numbers are placeholders.
- Older notes worth keeping: story and idea bank in DESIGN.md; parked ideas in PLAN.md.

## World persistence and building
- **Resources:** each region has fixed spawn points saved per region. Trees, rocks and so on regrow on timers, which
  keep counting while you are away (worked out from the elapsed time when the region loads).
- **Village buildings:** pre-set spots. Village projects make a building appear at its spot (scaffolding, then built).
- **Your base (one per land) grows into your own town:** start with a pre-set home, then unlock more land around it
  in stages and place things freely on a grid: stations, farms, workshops, houses. Settlers (and companions) move in,
  and working buildings produce things. A long-term goal that keeps going after the story.
- **Every village in each land** (several per land) has its own projects at fixed spots, so there is always somewhere to build up.

## Armour and looks
- Armour has stats and its own look. The best armour clearly looks the best (trims, glow), so by the end you look strong.
- Some sets suit certain things (e.g. a class or an activity) with set bonuses; optional, never forced.
- **No clash with the character screen:** face, hair and body are always yours. Each armour slot has a "show armour /
  show my style" toggle, so the outfit pieces you picked become a style layer. A shown helmet replaces the hat.

## Build order (owner's pick)
Must do, in this order:
1. **Region travel + the forest.**
2. **Food and cooking.**
3. **Money, the trader, the first village project.**
4. **Class tree + first abilities** (with the story start: ordinary day, shrine wakes, class unlocks) and two
   weapon slots. Classes and weapons are separate (Outriders style): any class can use any weapon; they can
   complement each other, never lock you in.
5. **Forest boss, full rarities, relics, and the first armour.**
6. **Balance pass** (all numbers in one file).
7. **Your home base** (free placement).
Kept in mind for later: more weapons, more regions (highlands, caves), special companion, fishing, then the 2nd land.
