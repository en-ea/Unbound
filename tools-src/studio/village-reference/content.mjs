// The village's content: ages, what each age thinks of each act, its laws, roles, places, names and
// epithets. Data, not code: both implementations (this reference and the GDScript port) read the same
// tables, and new acts or places are added here. All numbers are integers.

export const AGES = ["tribal", "village", "town"];
export const TRIBAL = 0, VILLAGE = 1, TOWN = 2;

// Norm ratings (RimWorld precepts, Crusader Kings doctrines): how an age sees an act.
export const REQUIRED = 0, RESPECTED = 1, INDIFFERENT = 2, SHUNNED = 3, CRIMINAL = 4, ABHORRENT = 5;
export const RATING_NAMES = ["required", "respected", "indifferent", "shunned", "criminal", "abhorrent"];

// Acts people can do or be accused of. For each: the rating per age [tribal, village, town], a base
// severity (0-9) and what it leaves behind.
export const ACTS = {
  theft:          { norms: [SHUNNED, CRIMINAL, CRIMINAL],     severity: 2, trace: "feathers", noun: "theft" },
  poaching:       { norms: [INDIFFERENT, SHUNNED, CRIMINAL],  severity: 1, trace: "snare", noun: "poaching" },
  assault:        { norms: [SHUNNED, CRIMINAL, CRIMINAL],     severity: 3, trace: "blood", noun: "a beating" },
  murder:         { norms: [CRIMINAL, ABHORRENT, ABHORRENT],  severity: 8, trace: "body", noun: "murder" },
  arson:          { norms: [CRIMINAL, ABHORRENT, ABHORRENT],  severity: 6, trace: "ashes", noun: "arson" },
  false_witness:  { norms: [SHUNNED, CRIMINAL, CRIMINAL],     severity: 3, trace: "", noun: "false witness" },
  hoarding:       { norms: [CRIMINAL, SHUNNED, INDIFFERENT],  severity: 2, trace: "grain", noun: "hoarding grain" },
  sorcery:        { norms: [SHUNNED, ABHORRENT, CRIMINAL],    severity: 6, trace: "charms", noun: "witchcraft" },
  well_poison:    { norms: [ABHORRENT, ABHORRENT, ABHORRENT], severity: 8, trace: "sick", noun: "poisoning the well" },
  grave_robbing:  { norms: [ABHORRENT, CRIMINAL, SHUNNED],    severity: 4, trace: "open grave", noun: "grave robbing" },
  cannibal_famine:{ norms: [SHUNNED, ABHORRENT, ABHORRENT],   severity: 9, trace: "bones", noun: "eating the dead" },
  cannibal_rite:  { norms: [RESPECTED, ABHORRENT, ABHORRENT], severity: 9, trace: "bones", noun: "the heart-rite" },
  sacrifice:      { norms: [RESPECTED, ABHORRENT, ABHORRENT], severity: 9, trace: "altar", noun: "a sacrifice" },
};

// Public acts (the stagings). lethal: counts against the director's violence budget. place: where it
// happens. minutes: how long it runs (game minutes). The kinds match staging.gd KINDS.
export const PUBLIC = {
  fine:            { lethal: false, place: "square",     minutes: 60,  shame: 1 },
  pillory:         { lethal: false, place: "pillory",    minutes: 360, shame: 3 },
  stocks:          { lethal: false, place: "pillory",    minutes: 240, shame: 2 },
  branding:        { lethal: false, place: "square",     minutes: 90,  shame: 4 },
  exile:           { lethal: false, place: "gate_south", minutes: 120, shame: 5 },
  ordeal:          { lethal: false, place: "well",       minutes: 120, shame: 2 },
  trial_by_combat: { lethal: true,  place: "square",     minutes: 90,  shame: 2 },
  hanging:         { lethal: true,  place: "gallows",    minutes: 480, shame: 9 },
  bonfire:         { lethal: true,  place: "stake",      minutes: 540, shame: 9 },
  stoning:         { lethal: true,  place: "square",     minutes: 30,  shame: 9 },
  sacrifice:       { lethal: true,  place: "stake",      minutes: 300, shame: 9 },
  scapegoat:       { lethal: false, place: "gate_south", minutes: 90,  shame: 6 },
  mob:             { lethal: true,  place: "square",     minutes: 45,  shame: 9 },
};

// The law: for an act and an age, the punishments from lenient to harsh. The trial picks along this list
// by severity, repeat offences, hardship and fear, minus mercy and a confession.
export const LAW = {
  theft:          [["fine", "exile"], ["fine", "pillory", "branding", "exile", "hanging"], ["fine", "stocks", "branding", "exile", "hanging"]],
  poaching:       [["fine"], ["fine", "stocks", "branding"], ["fine", "stocks", "branding", "exile"]],
  assault:        [["fine", "exile"], ["fine", "pillory", "exile"], ["fine", "stocks", "exile"]],
  murder:         [["stoning", "exile"], ["exile", "hanging"], ["exile", "hanging"]],
  arson:          [["exile", "stoning"], ["branding", "hanging", "bonfire"], ["exile", "hanging"]],
  false_witness:  [["fine"], ["pillory", "branding"], ["fine", "stocks", "branding"]],
  hoarding:       [["exile"], ["fine", "pillory"], ["fine"]],
  sorcery:        [["scapegoat", "sacrifice"], ["pillory", "exile", "bonfire"], ["stocks", "exile", "bonfire"]],
  well_poison:    [["stoning"], ["hanging", "bonfire"], ["hanging"]],
  grave_robbing:  [["stoning"], ["pillory", "branding", "hanging"], ["stocks", "branding"]],
  cannibal_famine:[["exile"], ["hanging", "bonfire"], ["hanging"]],
  cannibal_rite:  [[], ["exile", "hanging", "bonfire"], ["exile", "hanging"]],
  sacrifice:      [[], ["exile", "hanging", "bonfire"], ["exile", "hanging"]],
};

// Roles: where they work, and what their work yields (food per day, in rations; a person eats 1).
export const ROLES = {
  farmer:     { work: "field", yield: 5, strong: false },
  herder:     { work: "pasture", yield: 4, strong: false },
  miller:     { work: "mill", yield: 3, strong: true },
  smith:      { work: "forge", yield: 3, strong: true },   // paid in food for tools
  woodcutter: { work: "woods", yield: 3, strong: true },
  priest:     { work: "shrine", yield: 2, strong: false }, // tithes
  elder:      { work: "square", yield: 2, strong: false },
  midwife:    { work: "home", yield: 3, strong: false },
  merchant:   { work: "square", yield: 4, strong: false },
  hunter:     { work: "woods", yield: 4, strong: true },
  gatherer:   { work: "woods", yield: 3, strong: false },
  child:      { work: "home", yield: 0, strong: false },
  beggar:     { work: "square", yield: 0, strong: false },
};
export const ADULT_ROLES = [["hunter", "gatherer", "gatherer", "herder"], ["farmer", "farmer", "herder", "miller", "woodcutter", "smith", "midwife"], ["farmer", "merchant", "miller", "smith", "woodcutter", "herder", "midwife"]];

// Traits (Dwarf Fortress facets): 0-100, the middle band (40-60) stays silent and only extremes show.
export const TRAITS = ["boldness", "piety", "greed", "compassion", "honesty", "temper", "alertness", "sociability"];
export const [BOLD, PIETY, GREED, COMPASSION, HONESTY, TEMPER, ALERT, SOCIABLE] = [0, 1, 2, 3, 4, 5, 6, 7];

// Culture values per age (the village's; each person deviates): tradition, faith, law, mercy (0-100).
export const CULTURE = [
  { tradition: 80, faith: 75, law: 30, mercy: 25 },  // tribal
  { tradition: 60, faith: 65, law: 60, mercy: 40 },  // village
  { tradition: 40, faith: 45, law: 80, mercy: 50 },  // town
];

// The village's places (a reusable layout type: every generated village has these kinds). Positions
// are in decimetres (integers). The meadow village (Enea's) maps onto this in its layout.
export const PLACE_KINDS = ["home", "pen", "square", "well", "shrine", "field", "pasture", "mill", "forge", "woods", "pillory", "gallows", "stake", "gate_south", "road", "far_woods"];
// How far apart the ages' speech is (0 = the same tongue, 100 = none shared): gossip carries less across it
// and misunderstandings (slights) come easier. [tribal, village, town] x [tribal, village, town].
export const LANG_DISTANCE = [[0, 70, 90], [70, 0, 40], [90, 40, 0]];

// The live game's pace (village.mjs): about ten times the chronicle's, so a village near the player has a
// quarrel most days, a public act most weeks and a grave one every month or two of game days.
export const LIVE_PACE = 10;
// (poaching alone does not scale with pace: it is the woods' steady background, not a motive's drama)
export const SEE_DAY = 160; // dm: people see what happens within 16 m by day
export const SEE_NIGHT = 60; // 6 m by night

// Names. Given names per age and sex; lineage names per age. Ancestors (tribal) get older-sounding names.
export const GIVEN = [
  [["Asgar", "Brakka", "Dunn", "Orm", "Harl", "Tuk", "Grom", "Vesk", "Kell", "Rud", "Bor", "Skarn", "Holt", "Ulf", "Garr", "Tarn"],
   ["Ysa", "Morra", "Tessa", "Hild", "Anka", "Wren", "Sif", "Brynn", "Oda", "Leth", "Runa", "Kesh", "Aud", "Dagny", "Faer", "Isk"]],
  [["Aldric", "Tobin", "Garrow", "Hob", "Bram", "Oswin", "Wat", "Colm", "Edric", "Piers", "Rolf", "Ansel",
    "Godric", "Hugh", "Simkin", "Dunstan", "Jory", "Merric", "Osric", "Rafe", "Tam", "Wystan", "Cuthbert", "Alder"],
   ["Mara", "Ilse", "Petra", "Sella", "Nell", "Wenna", "Agnes", "Maud", "Joan", "Elsbet", "Tilda", "Rose",
    "Alys", "Bettony", "Cecily", "Edith", "Gwen", "Hawise", "Isolde", "Juliana", "Lettice", "Marjory", "Orla", "Sybil"]],
  [["Tomas", "Henrik", "Jasper", "Lucan", "Matthias", "Felix", "Anselm", "Conrad", "Emeric", "Florian", "Gregor", "Konrad", "Leopold", "Niklas", "Rupert", "Valentin"],
   ["Clara", "Beatrix", "Helena", "Ottilie", "Marthe", "Sabine", "Gisela", "Luise", "Adela", "Brigitta", "Dorothea", "Emilia", "Franziska", "Irmgard", "Kunigunde", "Theresa"]],
];
export const LINEAGE_NAMES = [
  ["Two-Crows", "Ash-Tooth", "Stone-Hand", "Red-Elk", "Fen-Walker", "Bone-Singer"],
  ["Hollin", "Thatcher", "Miller", "Cooper", "Wendmoor", "Ashby", "Fenwick", "Carrow", "Hale", "Brook"],
  ["Hollinsworth", "Thatch", "Mulner", "Kupfer", "Wendt", "Aschen", "Fenn", "Karrow"],
];

// Epithets earned by deeds (Caves of Qud, Dwarf Fortress): shown on the notice board and in the tales.
export const EPITHETS = {
  branded: "the Branded", exiled: "Who Walked Out", pilloried: "of the Pillory", hanged: "the Hanged",
  burned: "the Burned", venerated: "the Blessed", false_accuser: "the False", merciful: "the Merciful",
  champion: "the Champion", confessed: "Who Confessed", survivor: "the Stone-Spared", rescuer: "the Brave",
  thief: "the Light-Fingered", mob_leader: "Who Threw First", returned: "Who Came Home",
};

// Where newcomers came from, when their family name is already held in the village.
export const FROM = ["of the Ford", "from over the Hill", "of the Marsh", "from the Coast", "of the Old Road"];

// Omens (read through the age's beliefs): each raises fear and may call for a scapegoat.
export const OMENS = ["a red moon", "a two-headed calf", "lights over the marsh", "a hailstorm in summer", "a stillborn foal", "crows on the church roof"];
