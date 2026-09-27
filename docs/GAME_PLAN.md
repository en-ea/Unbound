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

## Build order (most playable game soonest)
1. **Forest region + region travel** (path out of the meadow, loading, new enemy and resource).
2. **Food and cooking** (heals and buffs).
3. **Money, the trader and the first village project.**
4. **Class unlock at the shrine + first abilities.**
5. **Forest boss** and the full rarity list.
Then more regions, home, the special companion, the second land.
