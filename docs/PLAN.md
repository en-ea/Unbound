# Build plan

Small milestones. Each one ends with something the owner plays on the iPhone and gives feedback on.
Don't start the next milestone until the current one feels good on the phone.

## How we work (keeps usage low)
- **One milestone per chat, roughly.** Start each chat from the prompt in `docs/NEXT_CHAT_PROMPT.md` (updated at the end of each milestone), so nothing gets re-explained.
- **Read only what the task needs.** Keep files small and focused (one system per script), so edits touch little.
- **Verify cheaply:**
  - headless import to catch script errors,
  - one screenshot with the `--shot` helper,
  - one web export.
  - No repeated screenshot loops.
- **The owner tests on the phone** and reports FPS, feel and bugs. Performance problems get fixed straight away, while they are small.
- **Commit to git** after each working step.
- **Ask before any big direction change.** The owner makes design calls; Claude makes technical calls.

## Performance rules (learned from the tests on an iPhone 16 Pro Max, Safari)
- **Frame rate:** locked **30 FPS by default** (steady and cool), with a 60 FPS option in settings. Sustained heavy load makes the phone throttle.
- **Sharpness:** 3D render scale ~0.8. 100% was not visibly better.
- **Shadows:**
  - only near the player, off when the sun is low,
  - grass, particles and small props never cast shadows.
- **Characters:**
  - far characters stop animating,
  - about 6–8 enemies in a fight, ~20 animated characters on screen at most.
- **Scenery:** use MultiMesh for repeated scenery (trees, rocks, grass). Simpler distant models, plus fog.
- **Weather:** rain is a light screen effect, not thousands of particles.
- **Memory:** texture budget ~150–250 MB.

## Milestones
- **M1 · Walk the world**
  - A small slice of the mainland with the Tunic-style fixed camera, lighting, fog and day/night.
  - The player character with idle/walk/run on a joystick.
  - Proper free models: the owner downloads a Quaternius nature + character pack, and Claude picks it apart.
  - FPS counter, 30/60 cap.
  - Web export on the phone.
  - *Goal: "this looks and feels nice to walk around in".*
- **M2 · Gather:** chop trees, mine rocks, pick up items; a simple inventory UI; resources respawn.
- **M3 · Fight:** one enemy type, attack/dodge, health, death and respawn, loot drops.
- **M4 · Craft and grow:** crafting at a workbench, gear tiers (the axe/pickaxe/sword get better), and skills that level with use. **Built** (awaiting the owner's review): tiers, workbench, ores, found tools with bonuses, skills, bag slots, fists.
- **M5 · Save and offline:** save anywhere, instantly (on-device storage), plus an iPhone-friendly offline mode so it works on the train without the PC. Then move hosting off the PC (free GitHub Pages).
- **M6 · Village and people:** a village hub, NPCs with routines, the shrine that wakes (the story start), the first companion.
- **After M6:** more zones and underground, fishing/farming/animals, bosses, the second land, the third land, co-op.

## Parked ideas (owner wants these later)
- **Night-only creature** with special loot (the owner picked this for nights).
- **Fishing** at the pond: a timing game with rare fish. Will be in the game, just not yet.
- **Expand ruins and chests** once the map grows (the concept is in: `treasure.gd`).
- **House style:** four styles now stand in the village (cottage, cabin, round house, longhouse). The owner picks a favourite vibe.
