We're building my game "Unbound" (Godot 4.7.2, played on my iPhone as a web app). Repo: GitHub en-ea/Unbound; Vercel serves the `web/` folder. Read CLAUDE.md, docs/PLAN.md and docs/SYSTEMS.md first (docs/DESIGN.md and docs/GAME_PLAN.md for design work). Cloud sessions: run `bash tools-src/cloud_setup.sh` first. To publish: export Web, copy the two files, `bash tools-src/publish_web.sh`, commit, push to main.

Branches: `main` is my real app. `camera-test` = main + the new low turning camera (drag the right half to turn, lock-on ring) and has its own test link: https://unbound-git-camera-test-en-eas-projects.vercel.app (separate save). Work on `main`; afterwards merge main into `camera-test`, export and push it too, so the test link stays current. Hilmi's `studio` branch: don't merge or build on it without my OK. Ideas I want kept (not scheduled): docs/IDEAS.md. Reference pictures: docs/Builds/characters/.

What's new on camera-test (30 Sep, built while I was away; see the in-game Update log): music, an Update log
screen, better hit feel (move out of swings, damage numbers, kill finisher, level-up banner), loot flashes, Parry
button and perfect dodge, the Red Hand bandits and their camp in the Whispering Wood, sneaking and takedowns,
Morrow's dark quest "The Black Seal", and the story start (the shrine on the meadow hill wakes, the class screen,
the Pyromancer with Flame Dash and Meteor). All of this was merged into main on 4 Oct.

Also on camera-test (30 Sep evening, from my playtest): buttons that stay put (Compact flick option), sword on the
back, the quest system (Story/Job tags, foldable tracker, quest log, guide beam), bag Drop, quiet sneaking,
Cinderburst + a 12-talent Pyromancer tree, hunting (stags, bodies you carve/drag/cart to the butcher, rot, crows,
scavenging wolves, the Duskmaw called by three bodies at night, the ox cart, Wren's Harvest Supper), six more
houses and a second inside (layout + feel, changeable). I may send more mob pictures (medium/big) to build.

New on main (4 Oct): redesigned buttons, the Glimmerdeep cave, fishing, Fernhollow (forest village), the Shade
class, Stonecrest Highlands (region 3, no village yet), Runeblade + Frost blade sword looks, slide-between-buttons
setting, and an in-game story opening (story/intro.gd; I liked the visuals, it needs much more). Later that day from
my playtest: Shadow Dance replaced Shadowstep, the Shade's roll is a slip through shadow, double fixes (it sat on
heads / sank into the ground) and a cooler double, a sturdier elk, and the Highlands got tors, crags, cairns,
drystone walls and bolder colours. A crash after ~30 s happened once on Safari; I now use Chrome on the phone
(much faster). Dev arg --memlog prints memory every 5 s if it comes back.

Later on 4 Oct: bounty boards (one per region; hunt, gather, wanted elites; renown), the meadow village
rearranged round a green, village residents from Hilmi's ideas (Tomas, Elsa, Nell, Bram: a daily round, their
own goods, gifts and liking, three enterable houses), the Crystal Bow (Swap button / T; Attack shoots, Heavy
power shot), elk taming (Highlands, Calm while sneaking) and riding, laptop controls (Shift sprint, click attack,
Space roll, 1-3 abilities, Tab bag, J quests). Ideas I liked for later are in docs/IDEAS.md "Longer play".

New on 5 Oct (from my playtest): the Grand Swoop Home (do up the Swoop Lodge at the mailbox: bigger room, bigger
stash, longer Well Rested, a lodger's rent), a Stash in your trunk, Well Rested from your bed, Swoop and Mill room
feels, seven new furniture pieces, the mill and three village houses to let (buy, rent each day, do up), the bow
rebuilt (hold to draw with a real draw pose, let go to shoot, Perfect release, Triple Shot on Heavy, homing arrows),
weapons on the back outside fights and while doing other things (they had been on the chest), elk taming fixed
(freeze when it listens), and a clearer fishing screen.

Waiting on me: AI pictures of swords, bows, armour and the Hollowhorn sword (I'll send them; build the models
from them then). Brakk is dropped (still boxy).

Then tell me concisely what changed and what to test, and give me the updated options list:
- Polish: tune fight difficulty from my playtest; camp performance (~670 draw calls in view); villager
  performance; hats and masks; villager life; menus; prices and drops.
- Build on: more classes (I name them); class levels and more Pyromancer abilities; more quests; a forest boss
  (Hollowhorn the Elder Stag, or Tuskfather / Greymaw / Thornmother / Lantern Moth Queen); two weapon slots and
  bows; Morrow's next job; second village project; trader's rare stock.
- New: Stumplings and Sporecaps (forest mobs); elite enemies; bounty board; dangerous nights; knock-out that costs
  something; a small cave dungeon; a dog companion; challenges; shrines as fast travel; light rain and mist; fishing.

How I like to work: I don't code; keep replies short and plain. Batch my requests into one go, commit after each
working step, only screenshot when a visual check really matters, and watch usage (no waste, but good quality).
