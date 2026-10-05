# How the game is put together (for adding things)

Game state is separate from visuals: state scripts hold data and change through small action
functions; visual scripts listen to signals. Keep it that way (co-op later).

## Add an item
1. `game/scripts/state/items.gd`: add an entry to `DEFS` (name, colour, rarity).
2. `tools-src/blender/make_items.py`: add a model function and an `export(...)` line; run it.
   Drops and Bag icons pick the model up automatically (`Items.mesh`, `ItemIcons`).

## Add a gatherable resource (like trees, rocks, plants)
1. `game/scripts/state/world_resources.gd`: add a type to `TYPES` (hits, respawn, reach, tool,
   verb, drops as `[item, min, max, chance]`). Trees use `TREE_STAGES` (size decides hits/wood).
2. `game/scripts/world/scatter.gd`: place it with `_place(model, kind, pos, scale, tilt, "<type>")`.
   Shake, chips, sounds, stumps, regrowth and drops are handled by `resource_visuals.gd`.

## Tools, tiers and crafting (M4)
- `game/scripts/state/gear.gd` (autoload `Gear`): `TIERS` (Worn, Stone, Copper, Iron: power = hits per
  swing / sword damage, speed = swing speed), `RECIPES` (slot, tier, cost in items), owned and equipped
  tools, and the actions `craft()` and `equip()`. Saved with the game.
- Resource types can require a tier with `min_tier` (ore rocks in `world_resources.gd`); a weaker tool
  just glances off and the HUD hints what's needed.
- The workbench (`world/workbench.gd`) is an "interactable": any node in that group with `verb`, `reach`
  and `interact()` takes over the action button when you're near (see `player.gd`).
- Screens: `ui/crafting_panel.gd` (workbench), tool badges in the Bag (`ui/inventory_panel.gd`).
- Tool heads are tinted by tier in `character_visual.gd` (`show_tool`).
- Each owned tool is a record `{tier, rarity, bonuses}`; `Gear.roll_found()` makes a found one
  (chests 40%, boars 6%, wolves 8%) with Swift / Mighty / Lucky bonuses. `drop_tool()` leaves you
  with fists (trees take a punch animation, half an axe's power).
- Bags: `Gear.BAGS` (12 / 16 / 22 kinds of item); `Inventory.has_room()`; a full bag leaves new
  kinds of item on the ground (`drop.gd`).

## Loot, rarities and armour
- `state/loot.gd` (`Loot`, static): six rarities (Common..Mythic, `Balance.RARITIES`: colour, stat multiplier,
  bonus count), rolls by source (`Balance.LOOT_ODDS`: enemy, elite, chest, trader), bonuses with values
  (`Balance.BONUSES`: which gear, value range, text), names (Mythic pieces get their own).
- A piece is `{tier, rarity, bonuses: {id: value}, seed}`. Tools and the sword live in `Gear`; armour in
  `state/armor.gd` (autoload `Armor`: helm/chest/boots, `defence()`, `block_chance()`, `bonus_total()`).
  `Gear.roll_found(source)` rolls any kind; `Gear.take(slot, piece)` routes it. Bonus effects are plain numbers
  read in few places: `Gear.damage/hit_damage/speed/luck/lifesteal`, `player.take_damage` (block), player speed
  (Fleet), heart regen (Mending). Swap these hooks if fighting changes; the data stays.
- Worn armour shows on the player (`CharacterVisual.wear_gear`, `_worn_parts`: helm, armour top, boots; Metal
  takes the tier colour). Placeholder looks until armour designs arrive. Drop/icon models: `make_tools.py`.
- UI: `ui/gear_view.gd` (cards, detail with compare, "On you" rows), the Bag's Gear tab, `ui/loot_card.gd`.
  Test menu: Random gear, One of each rarity, Armour set. Dev: `--loot` (with `--bag`), `--lootcard`.

## Skills (M4)
`game/scripts/state/skills.gd` (autoload `Skills`): woodcutting, mining, combat. XP from
`gatherer.gd` (2 per hit, plus the node's hits when it's finished), `fighter.gd` (3 per hit) and
kills (boar 25, wolf 20). Perks: gathering speed +1.5% and extra-drop chance +1% per level, sword
damage +1 per 10 combat levels. The HUD shows a small bar on gains and a message on level-up.

## Food, money and village projects
- `state/food.gd` (autoload `Food`): `FOODS` (hearts healed, buff, seconds), `BUFFS` (strong, swift, nimble,
  sturdy), campfire `RECIPES`; actions `cook()` and `eat()`. Buffs are read by Gear.damage, player speed and
  damage taken, and gatherer pace. Eat from the Bag (Eat button); the HUD shows running buffs.
- `state/money.gd` (autoload `Money`): coins (`earn`, `spend`), the trader (`sell`, `buy`, `stock()` rotates
  every 15 min from `STOCK_POOL`). Sell prices are `value` in `Items.DEFS`.
- `state/projects.gd` (autoload `Projects`): `DEFS` (name, region, spot, coins and item cost, what it unlocks);
  `fund()`. The spot shows scaffolding and a board until funded (`world/project_site.gd`). The Smithy unlocks
  Steel tools (recipes with `"needs": "smithy"` in `gear.gd`).
- One screen for all three: `ui/shop_panel.gd` (mode cook / trade / project), opened by `world/station.gd`
  (any interactable spot) through `hud.open_station()`. Campfires: `world/campfire.gd`, one per region.
- Dev: `--rich` (coins and materials), `--open=cook|trade|project:smithy`.

## Balance
Every gameplay number (enemy health/damage/XP, hearts and regen, tool tiers and recipes, bags, resources,
food, prices, trader stock, project and home costs, skill curve) lives in `state/balance.gd` with the
targets at the top. Other scripts alias its constants (`Gear.TIERS := Balance.TIERS` and so on).

## Home base
`state/home.gd` (autoload `Home`): owned house, pieces built in the yard, `missing()` (needs the Smithy,
a skill total and coins, see Balance.HOME), `buy()`, `place()`, `remove()`. `world/home_plot.gd` shows the
plot (meadow, west of the village); `ui/build_mode.gd` is the building bar (preview in front of you on a
half-metre grid, or Snap: fences join, 1 m grid, square turns; `_hook`). The mailbox by the path opens the home
screen (build, or move into another house). Add a buildable: `Home.PIECES` + its cost in `Balance.HOME_PIECES`. Dev: `--home`.

## Inside your home
`world/home_interior.gd`: one room far off the map (`AT`), built from `assets/interior/room_<house>.glb`
(`tools-src/blender/make_interior.py`: floor, cut-away walls, hearth, windows as a separate "Windows" object,
shelves; furniture `furn_<id>.glb`; the mailbox). Walk into the front door (or Enter) / out through the doorway
(or Leave on the mat), with `Region.fade_through()`. Indoors: `DayNight.set_indoors()` (softer sun, warmer ambient),
camera `enter_room()` / `leave_room()` (closer, steeper, stays on the room), no fog, quieter ambience, wooden steps,
HUD `set_indoors()` (Furnish button, no minimap). The hearth cooks; a bed "Rest" sleeps to morning and heals.
Furniture state: `Home.FURNITURE` (name, model, footprint, "wall"/"rug"/"", action), `Home.furniture`, `Home.stored`
(put away = free to place again), `furnish()`, `put_away()`, `room_fits()` (rects; rugs only mind rugs;
`ROOM_BUILT_IN`, `ROOM_DOORWAY`), `STARTER` (a new home's pieces). Costs: `Balance.HOME_FURNITURE`.
Furnish bar = `ui/build_mode.gd` with `room = true` (0.5 m grid, wall pieces back onto the nearest wall).
Saved indoors → you wake up inside. Add furniture: a model in make_interior.py + `Home.FURNITURE` + its cost.
Dev: `--inside[=hill]`, `--furnish`, `--house=lantern`. Test menu: "One of each furniture".

## Places
`world/places.gd`: named placeholder spots per region (watchtower, farmstead, camp, hollow, cave...),
built from simple shapes; their ground is a clearing in `WorldShape.REGIONS`.

## Regions and travel
- `game/scripts/core/region.gd` (autoload `Region`): the current region, its display name (`NAMES`) and its
  gates (`GATES`: trigger spot, the region it leads to, where you arrive). `travel()` saves, fades, and
  reloads the main scene, which builds the new region; `arrived()` fades in and shows the name.
- `WorldShape.REGIONS`: each region's pond, hill (standing stones), spawn, path, clearings, roughness, seed.
  Scripts read `WorldShape.POND_CENTER` etc., set by `WorldShape.use()` for the current region.
- Per-region content: trees and plants (`scatter.gd`, `_scatter_forest_trees`), enemies (`enemies.gd` HOMES),
  ruins and chests (`treasure.gd`), gates (`world/region_gates.gd`). The village and workbench are meadow only.
- Saving: each region's trees/rocks/chests are saved separately with the time they were saved; on load the
  time away is applied, so things grow back while you are elsewhere or the app is closed.
- Add a region: an entry in `WorldShape.REGIONS`, `Region.NAMES` and `Region.GATES` (both directions), then its
  scatter, enemies and treasure lists. Dev: `--region=forest`.

## Minimap
`ui/minimap.gd`: round, centred on the player, turns with `Controls.cam_yaw` (fixed on main's camera), N on the rim.
The ground is painted once into a texture covering `SPAN` (200 m) and drawn as a round textured polygon; `VIEW` =
metres across. Anything in group `"map_building"` with a `"map_size"` meta (Vector2 footprint) shows as a building.

## Stamina and fighting moves
- `player/stamina.gd` (a child of the player): `use("roll"|"heavy")`, `drain()` while sprinting, `winded` when
  emptied (until `winded_until`). Numbers in `Balance.STAMINA`, `SPRINT_SPEED`, `HEAVY_DAMAGE`, `HEAVY_PUSH`.
- Roll button (`hud._update_roll_button`): a tap rolls (on release), holding it past `HOLD_TO_SPRINT` sprints
  (label turns "Sprint", it lights up, bigger dust). Its rim shows stamina while not full. Q on the keyboard.
- Heavy button (fights only; F on the keyboard): `fighter.heavy()`. The sword glows through the wind-up; the blow
  hits every enemy in front within `HEAVY_REACH`, staggers them (`_hurt_time`), and freezes the world for a
  moment (`Engine.time_scale`), with a shockwave ring (`shaders/shockwave.gdshader`) and a deep thud.
- Attack warnings: in a WINDUP state enemies set `visual.tell` (0..1, red-hot pulse via `warn` in foliage_solid),
  and when their aim locks (`AIM_LOCK`) `visual.glint()` flares a star at the eyes with a "ting"
  (`shaders/glint.gdshader`, `assets/sounds/tell_glint.wav`, made by us). Dev: `--telltest`.

## How enemies fight (smarter fights)
Numbers in `Balance.FIGHT`. The glint is the one honest signal: it always comes the same beat before a real
attack; the red glow before it can be held (random hold) or faked.
- Boar (`boar.gd`): charge with a random hold; tusk swipe (SWIPE) when you are close in front; can't be
  interrupted in WINDUP/CHARGE/SWIPE (only a heavy blow staggers); a charge into a wall/tree = DAZED (free hits);
  a wounded boar may charge again at once; poise: `boar_poise` light hits in a row and it braces and counters.
- Wolves (`wolf.gd`): spread apart (`_spread`) and circle round behind you (`_flank_side`); wolves beside or
  behind you (`_in_view`) strike first; FEINT (no glint, a hop and a snap, often a quick real strike after);
  pincer (the next wolf may go right after); `sense_swing()` from `fighter.attack()` lets a circling wolf hop
  clear (DODGE, `is_evading()` makes the swing miss); a swing at nothing calls `Wolf.open_up()` and a circling
  wolf pounces; a missed lunge = STUMBLE (your opening); a flurry on one wolf makes it leap away.
- Nothing depends on the camera (flanking uses the player's facing), so it works with both cameras.
- Dev: `--fighttest` (mash a boar), `--lab --packtest` (three wolves; prints the lowest health and states seen).

## Add an enemy
Copy the boar pattern: a model made of parts with pivots (`tools-src/blender/make_boar.py`), a
visual script that animates the parts in code (`boar_visual.gd`), a behaviour script with a small
state machine and `take_hit()` / `is_alive()` / group `"enemy"` (`boar.gd`, with a WINDUP state: glow, then a glint), and spawn it from
`scripts/creatures/enemies.gd`. The player's `fighter.gd` finds anything in group `"enemy"`.

## Add a character look or outfit
Parts and colour slots: `tools-src/blender/make_hero.py` (mesh names `H_<slot>_<choice>[_extra]`; choice names
have no underscores; extra pieces can use fixed colours like Gold, Leaf, Fur, Straw). Choices, picker names
(`CHOICE_NAMES`), palettes and the ready-made outfits: `game/scripts/player/character_look.gd`. Headwear that
covers the head is listed in `CharacterVisual.COVERING` (hair switches to its `_hat` cut). The picker
(`ui/look_picker.gd`) shows each slot as tap-to-pick chips; tabs list their slots in `SLOTS`.
Dev: `--lineup[=N]` (7 outfits from the Nth), `--outfit=Mage`.

## Add a building or NPC
Models: `tools-src/blender/make_buildings.py`. Placement, clearings and NPCs:
`game/scripts/world/village.gd` and `WorldShape.clearings`.

## Look and style
All props use `shaders/foliage_solid.gdshader` (per-face colours stored in UVs by the Blender
scripts; `lowpoly.py` / `rigkit.py`). Ground: `shaders/terrain.gdshader`. Light, fog and sky:
`scripts/world/day_night.gd`.

## Test menu (for the owner)
Menu → Settings → Codes → "Paladin": buttons that give coins, items, food, Steel tools, the biggest bag,
skill levels, build every village project (or undo them all), give the home back (`Home.reset()`), heal, or travel. In `ui/settings_panel.gd` (`_cheat_page`);
add a button there whenever a new system needs quick testing. Dev: `--cheats` opens it.

## Build lab (testing in the game)
`dev/build_lab.gd`: a walled floor far below the world with one building on a showcase pad; the Lab board opens
`dev/lab_menu.gd` (switch building, spawn enemies/trees/rocks/ores/chests/loot in front of you, clear). Spawns are
removed on leaving (`WorldResources.truncate`, `ResourceVisuals.forget`, `treasure.remove_chest`), so they never
reach a save. Add a building: `BUILDINGS`; add a spawnable: `GATHERABLES` or `spawn()`. Dev: `--lab`, `--labmenu`, `--labtest`.

## Testing without the phone
Dev arguments (after `--`), see `game/scripts/dev/dev_args.gd`: `--gathertest`, `--fighttest`,
`--lineup`, `--showcase`, `--shot=path.png`, `--at=x,z`, `--view=d,pitch`, `--time=0.5`.

## Smoking
`player/smoking.gd` (child of the player, `player.smoke()`): a cigarette on the head bone (`CharacterVisual.head_attachment()`),
glowing tip, wisp and puffs, burns down over `Balance.SMOKE_SECS`; cosmetic only. Items `tobacco` (a gatherable plant, `tobacco_1`
in make_trees.py; a patch by Wren in `scatter._tobacco_patch`) and `cigarette` (campfire recipe with `"n": 3`, trader stock). Dev: `--smoke`.

## Villagers and quests
- `state/npcs.gd`: each villager (name, title, spot, `look` = CharacterLook parts + colour indices, body scale, hand `prop`, greetings, chatter).
  `world/npc.gd` builds one (an "interactable": the action button says Talk), turns to face you, shows a bubble and a "!" / "?" marker.
  Add one: an entry in `Npcs.NPCS`; the village builds them all. New looks come from make_hero.py (Wren: `sunhat`, `leafcloak`, prop `shears` in make_items.py).
- `state/quests.gd` (autoload `Quests`): `DEFS` (giver, the words for each moment, steps, reward). A step is `have` (finishes itself when you
  carry the items) or `turn_in` (handed over when you talk). Actions `accept()`, `turn_in()`; `talk(npc)` gives the talk screen as
  `{text, options:[{label, do}]}` (`do` returns the next screen, or `{}` to end). Saved with the game.
- UI: `ui/dialogue_panel.gd` (bottom card, typed text), `ui/quest_tracker.gd` (top-left). Dev: `--talk`, `--talk=quest`.
- First quest: Wren's Smokes (pick 4 tobacco, roll 3 cigarettes at a campfire, hand them in for 60 coins and 5 tobacco).

## Brakk the golem blacksmith
Model: `tools-src/blender/make_golem.py` → `assets/characters/golem.glb`, on the UAL rig (all UAL animations work). Built from
chiselled stone blocks (`rock()`), each fixed to one bone so nothing stretches; glowing parts use the "Glow" material. LOD
generation is off in `golem.glb.import` (it broke the blocks). Villager entry "brakk" in `state/npcs.gd` (scale 1.6, hammer,
anvil, portrait). Sonnet's first version is kept: `make_golem_v1.py` / `golem_v1.glb`. Preview: `GV_NPC=brakk GV_MODE=body
GV_ANGLE=-20 GV_DIST=5.5 ... res://scenes/tmp_view.tscn` (writes /tmp/claude-0/s/gv.png); without GV_MODE it shows his talk screen.

## Morrow the wanderer, masks
- Morrow: `tools-src/blender/make_morrow.py` → `assets/characters/morrow.glb` (UAL rig; long split coat whose tails follow the
  thighs, tall open collar, pale mask face with glowing eyes). Staff: `skull_staff` in make_items.py. Villager entry "morrow" in
  `state/npcs.gd` (by the spawn, wanders a little, no quest yet; voice "morrow" in make_voices.py).
- Masks: the "mask" slot in `CharacterLook.PARTS` (Face tab): kitsune, oni, hollow, built in make_hero.py (`plate()` follows the
  head; pieces `H_mask_<name>[_extra]` with fixed colours). Materials ending in "Glow" shine. Random looks get a mask 20% of the time.
- Wren: `sun_hat` (level, wide brim, rounded crown), `leaf_cloak` (five rows of big leaves) + `leaf_ribs`.

## The Moss-Cap Seeker (the first small villager)
`tools-src/blender/make_seeker.py` → `assets/characters/seeker.glb` (UAL rig, no arms showing: a leaf hood with a
drooping tip, a shadowed face with glowing eyes, a bell of pointed leaves, thin legs). Villager "seeker" (scale 0.56,
by the pond, searches the grass; chatter hints at the meadow chests). Voice: `CHIRPS` in make_voices.py.
Brakk's anvil under his arm: `"carry"` in the villager entry (a second prop on another bone; build lab only).

## Two-handed props, lab villagers
- `player/two_hand_hold.gd`: a skeleton modifier that bends both arms (two-bone IK) so the hands grip a prop held low in
  front (Wren's shears). NPC data: `"two_hands": true`; `CharacterVisual.set_two_hand(false)` while working. Prop models
  from Blender come in with their long axis on +Y.
- Build lab: the Lab board's VILLAGERS section shows any villager on a turntable, with Close-up / Whole body framing
  (`build_lab.show_villager`). Dev: `--lab --villager=wren` (add `,far` for the whole body).
- NPC walking (`world/npc.gd`): turns to face the next spot first, eases in and out; `"walk_speed"` per villager.

## Update log (camera-test)
`ui/update_log.gd` (`UpdateLog`): `ENTRIES`, newest first; opened from the title screen (bottom-left) and Settings.
Add an entry with every published test build.

## Music
`audio/music.gd` (`Music`, made by ambience.gd): CC0 tracks in `assets/music/` (credits in LICENSE.txt there),
one at a time with crossfades: village (near the houses), meadow, forest, fight (any enemy whose `is_engaged()`
is true within 26 m), boss (any node in group "boss"/`is_awake()`; Varek uses `is_awake()` directly via the
group check). Quieter at night/indoors; `Music.sting(stream)` ducks it for a story moment. Setting: Music on/off.

## Hit feedback and loot flashes
`world/float_text.gd` (`FloatText.spawn`): damage numbers and words over things. `fighter._hit_feedback`: crit ring,
kill boom, slow motion on the last kill. `ui/banner.gd` (`Banner.show_now`): big top-of-screen moments (level up,
class, target down). Rare+ gear lands with `tool_drop.sparks` + a chime; chests burst in the gear's colour.
Sounds we make ourselves: `tools-src/make_fight_sounds.py` (level up, kill, crit, parry, block, bow, stab, spotted,
fire, shrine, chest).

## Parry, block, perfect dodge
Every enemy blow goes through `player.receive_attack(attacker, damage, push)` → "perfect" | "dodge" | "parry" |
"block" | "hit" | "miss"; enemies react (`parried(seconds)` → stunned and `is_open()` = double damage). Parry
button (R): the first `Balance.DEFENCE.parry` s of the guard parries, later blocks for stamina. A roll whose first
`perfect_dodge` s meets a blow = slow motion + a counter (`take_counter()` doubles the next hit). A swing's
follow-through is cancelled by moving (`fighter.recovering()`). Dev: `--defencetest`.

## Bandits and sneaking
- `creatures/bandit.gd` (`Bandit`): kinds in `Balance.BANDITS` (cutthroat, shield, archer, leader Varek). Built on
  CharacterVisual with `BanditLooks` (dark cloth, red accents, masks); sword via `show_tool` + `tint_tool`, shield/bow
  via `hold_prop` on hand_l; overlay `EnemyOverlay` (glint, health bar, ?/! awareness). States POST (idle/beat) →
  SUSPICIOUS/SEARCH → CIRCLE/WINDUP/ATTACK (glint always `GLINT_LEAD` before a blow)/RECOVER, AIM (archers, arrows
  in `arrow.gd`), STAGGER, HURT, DEAD. Blocks from the front (`block` chance; shields always, heavy breaks it).
- `creatures/bandit_camp.gd` (`BanditCamp`): forest camp at (74, 10) built from `assets/camp/*.glb`
  (`tools-src/blender/make_camp.py`), roster of 8, attack turns (`Balance.BANDIT_TURNS`), `raise_alarm`, bodies
  noticed, respawn after you've been away, Varek drops `black_seal` while Morrow's quest is active.
- Sneaking (`player.sneak()`, button/C): crouch anims via `CharacterVisual.idle_anim/walk_anim`, slower, `noise()`
  radius per action; bandits see in a cone (`Balance.STEALTH`), with a line-of-sight ray, less at night.
  `can_be_taken_down()` → the action verb "Takedown". Lab spawns: Bandit, Shield bandit, Bandit archer, Varek.
  Dev: `--lab --bandittest`, `--region=forest --sealtest`.

## Story start and classes
- `state/classes.gd` (autoload `Classes`): `awakened`, `current`, `CLASSES` (pyromancer + three sealed),
  `ABILITIES` (cooldowns, texts), `use()`. Saved. `world/shrine.gd` (meadow hill): wakes when you come close
  (pillar of light, lines, `awaken()`), then `hud.open_class_panel(true)` (`ui/class_panel.gd`). Before that the
  quest tracker shows "A Strange Hum".
- `player/abilities.gd`: Flame Dash (`player.dash()`, a fast roll: untouchable) and Meteor; fire in
  `world/fire_fx.gd` (flames, burning ground, blast, `ignite()` → `creatures/burning.gd` calling `take_burn`).
  HUD ability buttons above Heavy (Z/X on a keyboard). Test menu: Become Pyromancer, Reset story.
  Dev: `--pyro`, `--classpanel`, `--lab --pyrotest`.

## Morrow's quest: The Black Seal
`Quests.DEFS["morrow_seal"]`: take Varek's seal (dropped by the camp's leader), hand it to Morrow; reward coins and
an Epic sword (`reward.gear = [slot, rarity]`). Quest items can't be sold (`Items.QUEST_ITEMS`).

## Controls layout (camera-test)
- `ui/hud.gd`: every play button keeps its spot (a ring round Attack: Heavy, Parry, Roll, Sneak, three ability slots).
  Attack always works (a swing at the air with nothing near). Settings > Buttons > Compact hides Heavy and Parry:
  flick Attack up for Heavy, left for Parry (`ui/action_button.gd` `swipes`: a tap acts on release, a flick instead).
- The sword rides on your back (`character_visual.gd` BACK_SWORD_*) and is drawn in a fight (`fighter.gd` DRAWN_FOR,
  FIGHT_NEAR); Settings > Sword > Always in hand.

## Quests: story and jobs, tracker, guide
- `state/quests.gd`: `type` story/job; `auto` story quests need no giver and finish on events (`_event_done`);
  steps can be `event` (`Quests.note("sold_stag")`). Each step can say `where` {region, at} (a turn-in points at
  the giver). `tracked_quest()`, `track()`, `guide_point()` (the spot, or the gate towards its region).
- `ui/quest_tracker.gd` (tag, distance, fold), `ui/quest_log.gd` (tap the tracker or Menu > Quests),
  `world/quest_guide.gd` (the golden beam), minimap gold diamond.

## Talents (Pyromancer)
- `state/classes.gd` TALENT_TREES / TALENTS: branches of three learned in order; points = 1 (shrine) + combat
  level - 1 + bonus. Effects are checked with `Classes.has_talent()` in abilities.gd, fire_fx.gd, burning.gd.
  Screen: `ui/talent_panel.gd` (Class screen > Talents). Test: Codes > Paladin > +5 talent points; `--talents`.


## The Delver (Hilmi's class)
- `state/classes.gd` "delver" (abilities burrow, fault_line, sinkhole; its talent tree). `player/delver.gd` does the
  abilities (made by `abilities.gd`, which hands them over). Burrow: `under` hides the visual, a mound follows
  (`world/earth_fx.gd`), `player.burrowed()` blocks damage, roll, heavy, parry, sneak and makes the action button
  Erupt; Burrow again = Drag Under (once a dive). Its cooldown starts when you come up (`Classes.start_cooldown`).
- Holding foes in the earth: `hold()` turns off the enemy's physics (it can't act) and sinks its `visual`;
  `swallow()` sinks it all the way, kills it, removes its body (loot still drops) and puts the visual back when it
  respawns. Bosses and the bandit leader are never swallowed.
- Cracked (`creatures/cracked.gd`, `EarthFX.crack`): more damage from you (`Delver.cracked_damage`, used in
  fighter.gd too) and swallowed at higher health. Claws: `fighter.gd` CLAW_COMBO / HEAVY_CLAW,
  `character_visual.set_claws()` (built in code; no sword shown). Pickaxe work is 40% faster.
- Test: `--delver`, `--delvertest` (all abilities on a pack, screenshots to %TEMP%), `--talents=delver`.
## Hunting, bodies and the ox cart
- `state/hunting.gd` (autoload `Hunting`): KINDS (what carving gives, what the butcher pays), the cart's place and
  load (saved), `carve()`, `sell()`, `freshness(age)`. Numbers: Balance.HUNT, STAG, DUSKMAW.
- `world/carcass.gd`: the body a kill leaves (stag, boar, wolf, shadow wolf, Duskmaw): Take > Carve / Drag / Into
  the cart (`ui/choice_bar.gd`); rots; crows (`world/crow.gd`), wolves eat it (`wolf.gd` `_find_meal`); taken if
  left in the village; at most 6.
- `player/hauling.gd`: dragging (slow, no fighting; Drop) and riding the cart; both come through gates
  (`Region.leaving`, `Hunting.carried/riding`, `main.gd _hunting_arrival`).
- `creatures/stag.gd` + `stag_visual.gd` (model `make_stag.py`): prey that hears and sees you, herds bolt together.
- `world/butcher.gd` (west side of the village), `world/ox_cart.gd` (models `make_oxcart.py`),
  `world/hunt_director.gd` (three bodies at night call the Duskmaw: a `wolf.gd` with `duskmaw`).
- Test: `--hunt` (by the butcher with bodies and a stag), `--hunt=ride`, `--hunt=choices`, `--hunt=wild`.

## Home: houses and the inside
- `state/home.gd` HOUSES has 9 houses (third field: the feel they start with). The inside is chosen apart:
  `layout` (LAYOUTS: hearth, bright; built-ins, hearth, window and cook spots) and `feel` (FEELS). Rooms are
  `room_<feel>[_bright].glb` from `make_interior.py`. Changing layout moves furniture out of the way.
  House pictures in the home screen come from `ItemIcons.icon("house:<id>")`. Test: `--inside=skep --layout=bright --feel=hill`.

## Grand Swoop Home, stash, rest, rent
- `Home.UPGRADES` (lodge -> swoophome): `upgrade()` (cost `Balance.HOME_UPGRADE`), `upgraded` (kept if you move out and back),
  `shown_house()` / `house_model()` / `is_grand()`. A grand home's room is bigger (`GRAND_HALF`, layout "grand",
  `room_<feel>_grand.glb`); use `Home.room_half()` / `doorway()`, never the constants. `_refit()` moves furniture with the walls.
- Stash: the trunk indoors ("Stash", `ui/stash_panel.gd`), `Home.store()` / `take_out()`, room `Balance.HOME_STASH` (more if grand).
- Well Rested: sleeping in your bed (`home_interior._rest`) gives `Food.give("rested", ...)` (`Balance.REST`): XP in `Skills.add`,
  stamina in `stamina.gd`. A night's sleep is a new day for rent.
- Rent: a grand home's lodger (`Home.mail_coins`, `new_day()`), village lettings (`state/lettings.gd`, autoload `Lettings`:
  houses 3, 4, 6 of `village.gd` HOUSES; `buy()`, `do_up()`, `collect()`, `Balance.LETTINGS`). Both are collected at your mailbox
  or a letting's sign (shop_panel mode "letting"). Furniture per level: `visit_interior.gd` LETTING.
- Village rooms you can enter: `village.gd` VISITS (residents' homes, the mill) + the lettings. Room feels: `Home.FEELS`
  (lantern, lodge, hill, swoop, mill) from make_interior.py STYLES. Furniture only for visits (millstone): no cost in
  `Balance.HOME_FURNITURE`, so `Home.for_sale()` leaves it out.
- Dev: `--grand` (with `--inside`), `--stash`, `--visit=5` (the mill), `--visit=3`, `--open=letting:3`. Test menu: Grand Swoop Home, A day of rent.

## The bow
- `fighter.gd` (bow section): hold Attack to draw (`Controls.is_attack_held()`: the HUD's Attack button, left mouse, E), let go
  to loose; damage grows with the draw, a full draw pierces, letting go within `PERFECT` s of full is a critical. Heavy = Triple
  Shot. `_aim_target()` prefers enemies in front. You walk slowly while drawing (`aiming()` in player.gd).
- `player/bow_pose.gd`: arms by two-bone IK, the bare bow (`crystal_bow_bare`, no string) in the left hand, the string drawn
  in code to the right hand, the nocked arrow. `player_arrow.gd`: homing, swept hits, sticks in what it hits.
- Where weapons are: drawn only in a fight (`_fight_on()`: an engaged enemy within FIGHT_NEAR, or a swing/shot in the last
  DRAWN_FOR s); put away at once while your hands are wanted (`_hands_wanted()`: gathering, fishing, hauling/riding, menus);
  `CharacterVisual.hands_busy` overrides "Sword always in hand". The model faces +Z: things on the back go at -Z
  (BACK_SWORD_AT, the bow's `back_prop`). Dev: `--bow`, `--bowdraw [--loose]`.
