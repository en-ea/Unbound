extends RefCounted
## What a resident says when the player talks to them: one short line, chosen from what the resident view
## (sim/view.gd describe) says about them. Pure: the same person in the same situation says the same thing
## for a whole game day (the choice is keyed by resident id and day, never by a random number).
##
##   line(d, day, minute)  -> one line of at most MAX_WORDS words
##   event_line(d, part, day) -> the line during an open event ("judge", "witness", "accuser", "leader")
##
## What decides it (first that applies): a forebear (gestures and a few odd words); a child (shy); a strong
## memory of the player (freed by you, angered, struck, seen planting); the first meeting; a mood that
## presses (grief, hunger, fear, guilt); how they feel about the player (wary, hostile); the elder and the
## priest; a mild memory; what they are doing (with their trade); the time of day.
##
## Voice: plain, in-world, short. Never a rule, a number or a system: no "source", "evidence", "case",
## "origin", no digits or counting words (lines_test.gd checks all of this on every line here). {name} is
## the speaker's own name, {culprit} is filled by the talk screens (not here).

const MAX_WORDS := 12

## A forebear (a person out of the old time, whose speech the village no longer shares).
const FOREBEAR := {
	"calm": ["*Points at your boots, then at the sky.* Rrek.", "*Touches your sleeve, murmurs something soft and strange.*",
		"*Taps their chest.* {name}. {name}.", "*Lifts both hands, palms open.* Hai. Hai.",
		"*Mimes a fire, points at you, smiles.*", "*Says a long word, then laughs, delighted.*",
		"*Kneels, draws a circle in the dust, waits.*"],
	"afraid": ["*Flinches, hands raised, whispers a strange prayer.*", "*Shakes their head hard and points away, away.*",
		"*Clutches your arm, eyes wide, repeats a single strange word.*"],
	"hungry": ["*Rubs their belly and points at your pack.*", "*Mimes eating, then shows empty hands.*",
		"*Says a word that sounds like bread. Perhaps it is.*"],
	"grieving": ["*Looks at the ground and hums something low.*", "*Presses a fist to their heart. Says nothing.*"],
	"wary": ["*Steps back, eyes narrow, a sharp word.*", "*Turns away and mutters. It sounds like a warning.*"],
	"hostile": ["*Spits a harsh word and waves you off.*", "*Turns their back. Old words, hard ones.*"],
	"uneasy": ["*Glances at the shadows, whispers something, glances again.*", "*Fidgets, points at the trees, shakes their head.*"],
	"freed": ["*Presses your hand to their forehead. Old words, warm ones.*", "*Bows low, murmurs the same soft word again.*"],
}

## A child: shy, small, and never anything but gentle towards them.
const CHILD := {
	"general": ["...hello.", "*Hides half behind a sleeve.* Hi.", "Are you a traveller? Do you have a dog?",
		"Mama says not to talk to strangers.", "I can climb the whole wall by the well.", "Shh. I'm hiding from my brother.",
		"Do you know any stories?", "My shoes are too big. They're my cousin's.", "I'm not supposed to be out here.",
		"*Stares at your boots and says nothing.*", "I found a feather. Want to see?", "Is your bag heavy? Mine is.",
		"I can whistle. Want to hear? No? Okay.", "Frogs live in the pond. Big ones. I'm not scared.", "Papa lets me hold the rope sometimes.",
		"I saw a rabbit. It saw me first.", "My hen is called Duchess. She's very rude.", "Do you like honey? I like honey.",
		"I can jump over the puddle. Watch. ...Never mind.", "I'm going to be a miller when I'm big. Or a dragon.",
		"There's a loose stone by the gate. I know where.", "I lost a tooth. It's in my pocket.",
		"The big kids don't let me play. It's fine."],
	"morning": ["I have chores. But first I'm looking at you.", "The grass is wet. My feet are wetter.", "Did you see the fog? It was so big."],
	"noon": ["Is it dinner time? It feels like dinner time.", "My shadow is very short today."],
	"afternoon": ["I'm supposed to be helping. I'm helping by watching.", "The hens don't like me. I don't like them."],
	"evening": ["It's getting dark. I should go in.", "Supper smells good tonight.", "Mama calls when the sun goes red."],
	"night": ["I'm not sleepy. Not even a little.", "The stars are out. Mama says count them. I forget."],
	"hungry": ["Is there any bread? My tummy is so loud.", "We had thin soup again. I don't mind. Much."],
	"grieving": ["Our house is quiet now.", "Mama cried in the night. I stayed very still."],
	"afraid": ["Is it safe? Mama says stay close.", "I heard something at the fence last night."],
	"uneasy": ["I broke a bowl. Please don't tell.", "I'm not hiding anything. Really."],
	"wary": ["Mama says I shouldn't talk to you.", "Please go away."],
	"hostile": ["Please go away.", "I don't want to talk. Sorry."],
	"freed": ["Thank you for helping me!", "You were so brave. I'll remember."],
	"met": ["You came back!", "Hello again. I remembered you."],
	"helped": ["Mama says you're kind.", "Thank you for helping us."],
	"told": ["Everybody talks about you.", "Grown-ups whisper your name."],
	"verbs": {
		"at_home": ["I'm minding the door. It's important.", "I'm not allowed past the gate. It's a long gate."],
		"eating": ["Bread and cheese! I saved the crust.", "Don't watch me eat. It's rude."],
		"chatting": ["We're playing who's-the-elder. I'm the elder.", "Shh, we're telling secrets."],
		"visiting": ["I'm visiting my friend. She's grumpy today.", "We're going to look at the ducks."],
		"loitering": ["Nothing to do. Nothing at all.", "I'm guarding this stone. It's mine."],
		"fetching_water": ["The bucket is bigger than me.", "I carried it all the way. Nearly."],
		"walking": ["I'm on an errand. It's very serious.", "Can't stop. Running."],
		"travelling": ["I'm on an errand. It's very serious.", "Can't stop. Running."],
		"trading": ["I'm watching the stall. Not touching.", "Look at all the ribbons."],
		"praying": ["Shh. The old ones are listening.", "I'm being very quiet. Can you tell?"],
		"hiding": ["Shh! Don't tell them where I am.", "I'm a stone. Stones don't talk."],
	},
}

## The first meeting: they don't know you.
const STRANGER := ["New face. I'm {name}. Mind the geese.", "You're the stranger from the road. I'm {name}.",
	"Well. A stranger. Welcome, I suppose.", "I haven't seen you before. Staying long?",
	"Travellers don't stop here often. What brings you?", "{name}, that's me. And you're new.",
	"Not many strangers come this far. Sit, if you like.", "So you're the stranger everyone mentions.",
	"Ah. You're not from around here. Nor was I, once.", "A stranger. Wipe your boots, then we'll talk.",
	"You walk like someone with a long road behind them.", "Welcome to Wenbrook. It's smaller than it looks.",
	"You've the look of a person who asks questions.", "Newcomers are rare. Gossip about them is not.",
	"I'm {name}. Don't mind the mud, it's part of the village.", "Well met, stranger. Or well enough."]

## A strong memory of the player: it comes first, every time.
const FREED := ["You cut me loose. I won't forget it.", "There's a place at my fire for you.",
	"They'd have finished me. You didn't let them.", "I hid in the woods, thinking of you.",
	"Ask anything of me. I mean it.", "Bless your hands, stranger."]
const ANGERED := ["You've got some nerve, showing your face here.", "Keep walking, stranger.",
	"I've nothing to say to you.", "We remember what you did.", "Turn around. There's no welcome here."]
const HIT := ["You struck me. Keep your distance.", "My ribs still ache. Thank you for that.", "Don't come near me again."]
const SAW_HIT := ["I saw you strike him. That's not how we do things here.", "Keep your hands to yourself. Everyone saw."]
const SAW_PLANT := ["I saw you at that door. I'll say nothing. For now.", "I know what you left at his door.",
	"Choose your friends carefully. I saw what you did."]
const PLANTED := ["Someone marked my door. I'll find out who.", "Wood on my step, and nobody knows why."]

## A mild memory: sometimes, not always.
const MET := ["Back again? Good to see you.", "Ah, it's you. How goes the road?", "You again. Welcome.", "Still about, then?"]
const SHIELDED := ["You stepped in front of those stones. I remember.", "Nobody else moved. You did.",
	"That took nerve, standing there for me.", "I saw who stood in the way. Thank you."]
const HELPED := ["You helped us. The village remembers.", "That was kind, before. It's not forgotten."]
const TESTIFIED := ["You spoke up when it counted. Not everyone would.", "Your words are still being chewed over in every kitchen.",
	"Some thank you for speaking up. Some don't."]
const OFFERED_COINS := ["Careful with coin near the elder. People talk.", "I hear you have deep pockets. Mind who sees."]
const TOLD := ["They say you're not from around here.", "I've heard a few tales about you.", "Word travels. Yours has."]

## How they are, when it presses.
const MOOD := {
	"grieving": ["There is grief in our house.", "We buried someone this season. Forgive me.", "I can't talk of it. Not today.",
		"The house is too quiet now.", "Some days the work is all that holds me up.",
		"We don't speak of it in this house.", "Grief is a long road. I'm still walking it."],
	"hungry": ["The cupboard is bare.", "Thin soup again. But we're alive.", "Bread's dear. Everything's dear.",
		"Got any bread to spare? No? Nor have I.", "Hunger makes people sharp. Mind yourself.",
		"We're stretching the flour with acorns.", "Don't ask what's in the pot."],
	"afraid": ["Something's wrong in this village. Can you feel it?", "I bar my door at dusk now.",
		"Strange times. Keep your eyes open.", "Wolves at the edge, and worse in the dark.", "Nobody sleeps easy lately.",
		"Keep your voice down. Walls listen.", "I keep the shutters closed at night now."],
	"uneasy": ["Hm? Oh. Didn't see you there.", "I've a lot on my mind. Forgive me.", "Don't look at me like that.",
		"Not a good time, friend.", "I did something foolish. Never mind what.",
		"I can't meet your eye today. Sorry.", "Ask me tomorrow. Perhaps I'll be myself."],
	"wary": ["State your business, stranger.", "You're not from here.", "I've my eye on you.", "Speak your piece and move along."],
	"hostile": ["Get away from me.", "You're not welcome here.", "Leave. Now.", "I'll not talk to you."],
}

const AUTHORITY := {
	"general": ["The village keeps its peace. Don't be the fool who breaks it.", "Everyone's trouble finds my door sooner or later.",
		"The elder's chair is heavy. Nobody warns you.", "I listen, I weigh it, I decide. Then I don't sleep.",
		"Come to me with your troubles. Not with a knife.", "A village is a big family with fewer manners."],
	"loitering": ["Keeping an eye on things. That's all a leader is.", "Someone has to stand here and look wise."],
	"chatting": ["Trade, talk, work. That's a village.", "I'm listening to complaints. Free of charge."],
	"at_home": ["Even the head of the village likes a quiet hearth.", "The door is open. It's always open. That's the trouble."],
	"walking": ["Walking helps me think. Mostly about my feet.", "Off to settle a quarrel. There's always a quarrel."],
}
const PRIEST := {
	"general": ["The old stone listens, even when we don't.", "Leave an offering if you've something to spare.",
		"Pray or don't. The shrine doesn't mind.", "The seasons turn. The old ones remember.",
		"Peace, traveller. The shrine is a quiet place."],
	"praying": ["Hush. The old ones are listening.", "Some come here to ask. I come to listen."],
}

## What they are doing, by activity verb (sim/view.gd). Trades are in the verbs: farming, milling, smithing...
const VERBS := {
	"farming": ["Good soil this year, if the rain holds.", "Backs ache, but the barley grows.", "Mind the rows, friend.",
		"Crows again. They know when I look away.", "Harvest waits for nobody.", "Dry spell coming. I feel it in my knee.",
		"Planted before dawn, cursed before noon.", "A field is a long conversation with the sky.",
		"Turnips are honest. Barley is a gossip.", "Weeds don't take the day off."],
	"herding": ["The flock's restless today.", "Sheep don't listen. Neither do children.", "Wolves about lately. I keep close.",
		"Green pasture, quiet day. Can't complain.", "I count them every dusk, and pray.", "My dog does the real work.",
		"Wool's thin this year. Cold spring.", "That ewe has opinions about the fence.", "Long day, short grass. That's herding."],
	"woodcutting": ["Oak's a stubborn thing.", "Stand clear. Tree's coming down.", "Winter wants wood. I want dinner.",
		"Good axe, poor knees.", "Listen. Trees creak before they fall.", "Boar tracks by the stumps. Careful out here.",
		"Split it green, burn it dry. That's the trade.", "Sap's rising. The wood is stubborn today.", "Every stump has a story. Mostly sore ones."],
	"hunting": ["Quiet, you'll scare the deer.", "Tracks all over the ridge this morning.", "Boar out east. Dangerous this season.",
		"The woods feed those who wait.", "Downwind, friend. Always downwind.", "Fresh prints by the stream. Big ones.", "Patience is most of hunting. Hush now.", "I've a snare to check before dark."],
	"gathering": ["Mushrooms, berries, kindling. Enough for supper.", "The best berries hide under the worst brambles.",
		"Mind your feet. Roots everywhere.", "Nettles make a fine soup, if you know how.",
		"Foraging is just hunting with better manners.", "Pockets full of acorns. Don't ask.", "Wild garlic by the stream. Smell that?", "Kindling first, berries after. Order matters."],
	"milling": ["Wind's fair. Flour by dusk.", "The sails creak, the grain flows.", "Nothing beats fresh-ground barley.",
		"Flour in my hair, flour in my lungs.", "A mill is only as good as its stones.", "Stand clear of the sails, friend.", "Grain in, flour out. The mill does the thinking.", "Wet wind, heavy sails. Slow day."],
	"smithing": ["Hot work. Stand back from the sparks.", "A good edge takes all afternoon.", "Bring me iron and I'll make you an edge.",
		"Hammer, heat, patience. Again.", "Every nail in this village came off this anvil.", "Strong arms, short temper. The forge does that.", "Nothing is the right shape on the first try.", "Pass me those tongs. No? Never mind."],
	"praying": ["Hush. The old ones are listening.", "Light a candle if you like.", "Peace, traveller.",
		"Some come here to ask. I come to listen.", "The shrine is old, but it isn't asleep.", "Leave your worries on the stone. It carries them."],
	"fetching_water": ["Well's running low.", "Cold water, honest work.", "Careful, the rope's wet.",
		"Heavier going home than coming.", "The well hears everything said around it.", "Best water in the valley, I'd say.", "The bucket is older than I am, and leaks the same.", "Stay a moment. The well hums at noon."],
	"chatting": ["Have you heard the news? Well. Never mind.", "We were just talking about the weather.",
		"Gossip is the village's second bread.", "Don't mind us. We're only complaining.", "Pull up a stump. Everyone else does.",
		"Bad news travels faster than the mill.", "Sit down, you're blocking the gossip.", "We're not idle. We're consulting."],
	"trading": ["Fair prices, fair goods. Have a look.", "Coin or barter, I take both.", "Look all you like. Looking is free.",
		"Prices are up. Everything is up but wages.", "Salt, needles, thread. Anything else is dear.", "Honest scales, honest weights. Ask anyone.", "Haggling is a friendly kind of quarrel."],
	"loitering": ["Just watching the day go by.", "Nothing to do till the light changes.", "Standing is a fine occupation.",
		"The square is where the village breathes.", "I'm not idle. I'm supervising.", "Waiting for someone. They're late. They're always late."],
	"eating": ["Midday bread. Don't stare.", "Leave a person to their supper.", "Bread, cheese, an onion. A feast.",
		"Best hour of the day, this.", "Eat first, talk after.", "Warm bread. Say nothing to spoil it."],
	"at_home": ["Home's where the roof holds.", "Come by the fire another day.", "Just mending. There's always mending.",
		"Quiet morning. I'll take it.", "The hearth wants tending.", "Sweeping. The dust always wins.", "Airing the blankets. The sun is good for it."],
	"visiting": ["Just dropped by for a word.", "Neighbours look in on each other here.", "I was passing. Also, I'm nosy.",
		"Bring a loaf when you visit. That's manners.", "Borrowed a ladle. Returning it. Eventually."],
	"walking": ["Can't stop long. Errands.", "On my way, friend.", "Road's long, day's short.", "Walk with me if you're going my way.",
		"Late already. Don't tell anyone.", "Mind your feet, the path is slick.", "Hm? Oh, hello. Mind on other things.",
		"Off to see about something. It can't wait.", "Fine day for a walk, if you've the legs.", "Must be quick. Someone's expecting me."],
	"travelling": ["Can't stop long. Errands.", "On my way, friend.", "Road's long, day's short.", "Walk with me if you're going my way.",
		"Late already. Don't tell anyone.", "Mind your feet, the path is slick.", "Hm? Oh, hello. Mind on other things.",
		"Off to see about something. It can't wait.", "Fine day for a walk, if you've the legs.", "Must be quick. Someone's expecting me."],
	"hiding": ["Shh! Keep your voice down.", "I'm not here. You didn't see me.", "Stay low. They may still be looking."],
	"idle": ["Quiet day.", "Not much happening.", "Nothing to report, friend."],
}

## Their trade, said when they are not at work (at home, eating, visiting, loitering, chatting).
const TRADE := {
	"midwife": ["Babies arrive when they please. Day or night.", "If someone's due, they'll send for me.",
		"Herbs drying by the fire. Don't touch them.", "Every child in this village passed through my hands."],
	"elder": ["I've seen more harvests than I can count.", "Sit. Old legs love a listener.", "The winters were kinder when I was young. Or I was."],
	"merchant": ["The ledger won't balance itself.", "Trade follows the road. Roads follow trouble."],
	"hunter": ["Game's thin. I'm thinner.", "The deer know me. That's the problem."],
	"farmer": ["The field won't wait, but neither will my back.", "Barley's honest. It only asks for everything."],
	"herder": ["Sheep have opinions. Mostly wrong ones.", "A herder's day is all waiting and walking."],
	"miller": ["Flour gets into everything. Everything.", "The mill keeps its own hours."],
	"smith": ["My hands remember the anvil even when I don't.", "Bring tools that need mending. I'm bored."],
	"woodcutter": ["My axe and I have an understanding.", "Split it yourself and it warms you double."],
	"gatherer": ["The woods provide, if you ask nicely.", "I know every bramble by name."],
	"priest": ["The old ones ask little. Mostly attention.", "Tend the shrine, and the shrine tends you."],
	"beggar": ["Spare a crust for a hungry soul?", "I was somebody once. Now I'm a story."],
}

## Only the old: the years in it.
const OLD := ["My knees know the weather before the sky does.", "I've walked this path since before you were born.",
	"Young legs. Enjoy them.", "Everything was better when I was young. Even the mud.", "The old stories are true. Mostly."]

const TIME := {
	"morning": ["Morning. Frost's off the grass already.", "Sun's up, and so is everyone.", "Early birds, us. Or fools.",
		"The day smells of woodsmoke."],
	"noon": ["Sun's high. My shadow's hiding.", "Midday. Nothing moves, not even the flies."],
	"afternoon": ["Afternoon's for finishing what morning started.", "Long shadows soon.", "Warm today. Suspiciously warm."],
	"evening": ["Evening. Getting cold, isn't it?", "Smoke from the chimneys. Supper soon.", "Best light of the day, this.",
		"Dusk brings out the gossips."],
	"night": ["Late to be out, stranger.", "Dark's no time to wander.", "The stars are out. So are the wolves."],
}

## Said by anyone, any time: the weather, the small news.
const GENERAL := ["Wolves howled last night. Close, too.", "The well tastes of iron lately.", "The geese are loud. Something's upset them.",
	"Heard a fox at the hen house. Or a neighbour.", "Fine weather for minding your own business.", "Rain soon. My knee says so.",
	"The old road washes out every spring.", "Have you tried the honey cakes? No? Shame.", "Smoke on the hill last night. Nobody knows why.",
	"Chimney needs sweeping, roof needs mending. That's life.", "Strange birds in the reeds this year.", "The children have grown like weeds.",
	"Last winter was hard. This one may be worse.", "The path to the mill is muddy again.", "Somebody left the gate open. Again.",
	"Bees are early this year. A good sign, they say.",
	"Someone's been at my woodpile. I have my suspicions.", "The mill wheel needs grease and the miller needs patience.",
	"Do you hear that? Nothing. Lovely.", "Boars have been rooting by the fence again.", "The elder's been quiet lately. Make of that what you will.",
	"Bread never comes out the same, whatever the flour.", "My neighbour's rooster has no respect for sleep.",
	"They say the old stone hums on still nights.", "Autumn's near. I smell it in the smoke.",
	"Half the village claims to be cousin to the other half.", "Mud on the boots, mud on the floor, mud in the soup.",
	"A traveller's luck is worth more than a merchant's coin.", "Lost a hen yesterday. She'll turn up, or she won't.",
	"The reeds by the pond whisper at night. Don't listen.", "Winter's coming. I can tell by how much I complain.",
	"The hills look closer today. Rain, I expect."]

## During an open event (the talk screen adds the actions).
const EVENT := {
	"judge": ["Say what you know, or hold your peace.", "The village is listening. Choose your words.", "Be brief. The day is short.",
		"Speak plainly. I've heard every lie there is."],
	"witness": ["I saw what I saw. Ask me plainly.", "Ask, and I'll tell you what I remember.", "It's hard, speaking against a neighbour.",
		"I was there. I wish I hadn't been."],
	"accuser": ["It was mine. Everyone knows it was mine.", "I want this settled. Properly.", "Ask anyone. They'll tell you what I lost."],
	"leader": ["The fire wants an answer tonight.", "The old stone is hungry. We do what we must.", "Come, or step aside. It begins."],
	"accused": ["I'll answer what's asked of me.", "Whatever they say, hear me too.", "This is not how I meant to spend the day.",
		"Look at me and tell me I'm what they say."],
}

## The times of day, from the minute of the day.
static func part_of_day(minute: int) -> String:
	var m := posmod(minute, 1440)
	if m < 360 or m >= 1320:
		return "night"
	if m < 660:
		return "morning"
	if m < 780:
		return "noon"
	if m < 1020:
		return "afternoon"
	return "evening"


## The main line. `d` is sim/view.gd describe(); day is the game day, minute the minute of the day.
static func line(d: Dictionary, day: int, minute: int) -> String:
	var id := int(d.id)
	var h := _mix(id, day)
	var name := _first(str(d.name))
	var mood: String = d.mood
	var known: Array = (d.toward_player as Dictionary).memories
	var part := part_of_day(minute)
	var verb: String = (d.activity as Dictionary).verb
	var met: bool = (d.toward_player as Dictionary).met
	if d.forebear:
		var key := "freed" if known.has("freed_by_you") else mood if FOREBEAR.has(mood) else "calm"
		return _fill(_pick(FOREBEAR[key], h), name)
	if d.age_group == "child":
		return _fill(_child(id, day, known, mood, part, verb, met, h), name)
	# a strong memory of the player comes first
	if known.has("freed_by_you"):
		return _fill(_pick(FREED, h), name)
	for pair: Array in [["hit_by_you", HIT], ["saw_you_hit", SAW_HIT], ["saw_you_plant", SAW_PLANT], ["angered", ANGERED], ["you_planted", PLANTED]]:
		if known.has(pair[0]):
			return _fill(_pick(pair[1], h), name)
	if not met and _chance(h, 1, 45):
		return _fill(_spread(STRANGER, id, day, 0), name)
	if mood in ["grieving", "hungry", "afraid"] or (mood == "uneasy" and _chance(h, 2, 70)):
		return _fill(_pick(MOOD[mood], h >> 5), name)
	if mood in ["wary", "hostile"]:
		return _fill(_pick(MOOD[mood], h >> 5), name)
	if d.priest and _chance(h, 3, 60):
		return _fill(_pick(PRIEST.get(verb, PRIEST.general), h >> 4), name)
	if d.authority and _chance(h, 3, 60):
		return _fill(_pick(AUTHORITY.get(verb, AUTHORITY.general), h >> 4), name)
	var mild := _mild(known, h)
	if mild != "":
		return _fill(mild, name)
	var role: String = d.role
	# What they are doing, said about half the time; else anything a neighbour might say.
	if VERBS.has(verb) and _chance(h, 6, 55):
		return _fill(_spread(VERBS[verb], id, day, 1), name)
	var pool: Array = []
	pool.append_array(TIME[part])
	pool.append_array(GENERAL)
	if TRADE.has(role):
		pool.append_array(TRADE[role])
	if d.age_group == "elder":
		pool.append_array(OLD)
	if verb in ["at_home", "eating", "visiting", "loitering", "chatting", "idle"] and VERBS.has(verb):
		pool.append_array(VERBS[verb])
	return _fill(_spread(pool, id, day, 2), name)


## During an open event: what the person says before anything is asked. part: judge, witness, accuser, leader.
static func event_line(d: Dictionary, part: String, day: int) -> String:
	var h := _mix(int(d.id), day + 7919)
	if d.forebear:
		return _fill(_pick(FOREBEAR.calm, h), _first(str(d.name)))
	return _fill(_pick(EVENT.get(part, EVENT.witness), h), _first(str(d.name)))


static func _child(id: int, day: int, known: Array, mood: String, part: String, verb: String, met: bool, h: int) -> String:
	if known.has("freed_by_you"):
		return _pick(CHILD.freed, h)
	if mood in ["hungry", "grieving", "afraid", "uneasy", "wary", "hostile"]:
		return _pick(CHILD[mood], h >> 4)
	if known.has("angered"):
		return _pick(CHILD.wary, h >> 4)
	if known.has("helped_by_you") and _chance(h, 1, 60):
		return _pick(CHILD.helped, h >> 3)
	if known.has("told_about_you") and _chance(h, 2, 40):
		return _pick(CHILD.told, h >> 3)
	if met and known.has("met") and _chance(h, 3, 30):
		return _pick(CHILD.met, h >> 3)
	var verbs: Dictionary = CHILD.verbs
	if verbs.has(verb) and _chance(h, 4, 50):
		return _spread(verbs[verb], id, day, 3)
	var pool: Array = []
	pool.append_array(CHILD[part])
	pool.append_array(CHILD.general)
	return _spread(pool, id, day, 4)


## A mild memory, said now and then (not on every visit): "" when none applies or it is not their day for it.
static func _mild(known: Array, h: int) -> String:
	if known.has("you_shielded") and _chance(h, 12, 75):
		return _pick(SHIELDED, h >> 3)
	if known.has("helped_by_you") and _chance(h, 7, 65):
		return _pick(HELPED, h >> 3)
	if known.has("you_testified") and _chance(h, 8, 60):
		return _pick(TESTIFIED, h >> 3)
	if known.has("you_offered_coins") and _chance(h, 9, 55):
		return _pick(OFFERED_COINS, h >> 3)
	if known.has("told_about_you") and _chance(h, 10, 50):
		return _pick(TOLD, h >> 3)
	if known.has("met") and _chance(h, 11, 35):
		return _pick(MET, h >> 3)
	return ""


## Every line the module can say (with {name} and {culprit} left in), for the checks.
static func all_lines() -> Array[String]:
	var out: Array[String] = []
	for pool: Variant in [FOREBEAR, CHILD, STRANGER, FREED, ANGERED, HIT, SAW_HIT, SAW_PLANT, PLANTED, MET, SHIELDED, HELPED, TESTIFIED,
			OFFERED_COINS, TOLD, MOOD, AUTHORITY, PRIEST, VERBS, TRADE, OLD, TIME, EVENT]:
		_collect(pool, out)
	return out


static func _collect(node: Variant, out: Array[String]) -> void:
	if node is String:
		out.append(node)
	elif node is Array:
		for item: Variant in node:
			_collect(item, out)
	elif node is Dictionary:
		for key: Variant in node:
			_collect(node[key], out)


static func words(text: String) -> int:
	return text.replace("{name}", "Name").split(" ", false).size()


## A line for this person from a pool that many people draw on: the step through the pool is set by the id, so
## two people drawing on the same pool land on different lines unless their ids are a whole pool apart. The
## day moves everyone along, so a person's line changes from day to day.
static func _spread(pool: Array, id: int, day: int, slot: int) -> String:
	var n := pool.size()
	var step := 7
	for candidate in [7, 11, 13, 17, 19, 23]:
		if n % candidate != 0:
			step = candidate
			break
	return pool[posmod(id * step + day * 3 + slot * 5, n)]


static func _pick(pool: Array, h: int) -> String:
	return pool[posmod(h, pool.size())]


## A repeatable coin: `slot` keeps one coin's outcome apart from another's for the same person and day.
static func _chance(h: int, slot: int, percent: int) -> bool:
	return _mix(h, slot * 101 + 17) % 100 < percent


static func _fill(text: String, name: String) -> String:
	return text.replace("{name}", name)


static func _first(name: String) -> String:
	return name.split(" ")[0]


static func _mix(a: int, b: int) -> int:
	var h := (a * 73856093) ^ (b * 19349663) ^ 0x9E3779B1
	h = (h ^ (h >> 13)) * 1274126177
	return (h ^ (h >> 16)) & 0x7fffffff
