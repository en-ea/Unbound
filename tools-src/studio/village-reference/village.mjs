// The living village (tier V): about 30 named people in households and lineages, living a day at a time.
// Each day: food and life, the director, dawn plans (who is where, when), today's scheduled events
// (trials, public acts, funerals, festivals), crimes, discoveries, gossip, cases, and minds (stress,
// guilt, confessions). Integers only; every random draw is keyed. The spec for the GDScript port.
import { key, ppm, pick, chance, clamp, idiv } from "./rng.mjs";
import * as C from "./content.mjs";
import { logEvent, nameOf } from "./events.mjs";
import { crimesToday, discoverCrimes, gossip, checkCases } from "./crime.mjs";
import { runScheduled, confessGuilt, remember, resolvePublic } from "./justice.mjs";
import { directorDay } from "./director.mjs";
import { stormDay } from "./storm.mjs";

export const YEAR = 60; // days in a village year: four seasons of 15
export const DAY = 1440; // minutes
export const P = {
  TRAIT: 1, NAME: 2, ROLE: 3, BIRTH: 4, DEATH: 5, MARRY: 6, PLAN: 7, CRIME: 8, SIGHT: 9, GOSSIP: 10,
  TRIAL: 11, CROWD: 12, HARVEST: 13, OMEN: 14, CYCLE: 15, OPINION: 16, SEX: 17, AGE: 18, VALUE: 19, FOOD: 20,
  CONFESS: 21, FESTIVAL: 22, STORM: 23, ARRIVAL: 24, STAGE: 25, EXILE: 26, RETURN: 27, MOTIVE: 28,
};

// The meadow village as a layout of the reusable type (content.mjs PLACE_KINDS); decimetres. Homes follow
// Enea's houses (sites.gd); pens sit beside them; public places match sites.gd.
export const MEADOW = {
  homes: ["cottage", "cabin", "round", "hill", "lodge", "loaf"],
  pos: {
    cottage: [-32, 126], cabin: [80, 140], round: [-64, 234], hill: [58, 224], lodge: [-32, 300], loaf: [-102, 36],
    pen_cottage: [-70, 100], pen_cabin: [120, 150], pen_round: [-100, 250], pen_hill: [100, 250], pen_lodge: [-70, 320], pen_loaf: [-140, 50],
    square: [15, 180], pillory: [-5, 170], gallows: [10, 70], stake: [40, -50], shrine: [-110, 140], well: [40, 250],
    mill: [120, 60], field: [-140, 200], pasture: [60, 330], forge: [-170, 120], woods: [-220, -60], gate_south: [20, 400],
    // beyond the village: where errands go, and where no one sees (the road south, the far woods)
    road: [40, 1100], far_woods: [-700, -400],
  },
};

export function createVillage(seed, opts = {}) {
  const V = {
    seed: seed >>> 0, base: key(seed >>> 0, 0x5eed), day: 0, age: opts.age ?? C.VILLAGE,
    // pace: how dense life is. 1 = the chronicle (history at a believable per-head rate); the live game runs
    // faster (C.LIVE_PACE), as a named cast standing for a larger settlement. It scales how often people
    // act on a motive, never whether they have one.
    pace: opts.pace ?? 1,
    tier: opts.tier ?? "private", layout: opts.layout ?? MEADOW, name: opts.name ?? "Wenbrook",
    people: [], households: [], lineages: [], authority: -1, priest: -1,
    hardship: 0, fear: 0, harvest: 100, events: [], evHash: 2166136261,
    crimes: [], cases: [], schedule: [], stagings: [], stagingCount: 0, outlaws: [], shrines: [],
    // time storms (storm.mjs): an anchored story village is exempt; stormPlan is the kernel's stand-in for tests
    storms: [], stormPlan: opts.stormPlan ?? [], anchored: opts.anchored ?? false,
    // the live game (live.gd): public acts wait on the stage for the player (justice.mjs resolvePublic)
    live: opts.live ?? false, pending: [], stranger: { standing: 0, enemies: [] },
    director: { on: false, until: 0, lethal: 0, cooldown: 0, last: [], cycles: 0 },
    stats: { crimes: 0, cases: 0, trials: 0, acts: {}, outcomes: {}, deaths: 0, violentDeaths: 0, births: 0, famines: 0, omens: 0, festivals: 0, exonerations: 0, mobs: 0 },
  };
  V.culture = { ...C.CULTURE[V.age] };
  // six founding lineages, one household each
  const names = C.LINEAGE_NAMES[V.age];
  const used = new Set();
  for (let h = 0; h < V.layout.homes.length; h++) {
    let n = pick(key(V.base, 100 + h), names.length);
    while (used.has(n)) n = (n + 1) % names.length;
    used.add(n);
    V.lineages.push({ id: h, name: names[n], age: V.age, feuds: {}, deeds: [], pastNames: [] });
    V.households.push({ id: h, lineage: h, home: V.layout.homes[h], members: [], food: 40, geese: pick(key(V.base, 200 + h), 5) });
  }
  // people: a couple, children, sometimes a grandparent, per household
  for (let h = 0; h < V.households.length; h++) {
    const hk = key(V.base, 300 + h);
    const father = addPerson(V, h, 0, 25 + pick(key(hk, 1), 20), -1, -1);
    const mother = addPerson(V, h, 1, 22 + pick(key(hk, 2), 18), -1, -1);
    V.people[father].spouse = mother; V.people[mother].spouse = father;
    const kids = 1 + pick(key(hk, 3), 4);
    for (let k = 0; k < kids; k++) addPerson(V, h, pick(key(hk, 10 + k), 2), 1 + pick(key(hk, 20 + k), 17), father, mother);
    if (chance(key(hk, 4), 400000)) addPerson(V, h, pick(key(hk, 5), 2), 58 + pick(key(hk, 6), 12), -1, -1);
  }
  // the elder: the oldest adult; the priest: the most pious other adult (a shaman in the tribal age)
  electAuthorities(V);
  // a few friendships and rivalries between households
  const n = V.people.length;
  for (let i = 0; i < n * 2; i++) {
    const k = key(V.base, 5000 + i);
    const a = pick(k, n), b = pick(key(k, 1), n);
    if (a === b || V.people[a].household === V.people[b].household) continue;
    const v = pick(key(k, 2), 120) - 60;
    setOpinion(V, a, b, v); setOpinion(V, b, a, clamp(v + pick(key(k, 3), 40) - 20, -100, 100));
  }
  return V;
}

// A child is named for a dead forebear of the lineage when one is free (the old custom), else a name no one
// living in the village holds; two living people never share a given name, so the tales can tell them apart.
function nameChild(V, hh, given, sex, k) {
  const held = new Set(V.people.filter((q) => q.alive).map((q) => q.name));
  const lin = hh ? V.lineages[hh.lineage] : null;
  const forebears = (lin?.pastNames ?? []).filter((nm) => given.includes(nm) && !held.has(nm));
  if (forebears.length && chance(key(k, 1), 600000)) return forebears[pick(key(k, 2), forebears.length)];
  const free = given.filter((nm) => !held.has(nm));
  const pool = free.length ? free : given;
  return pool[pick(k, pool.length)];
}

export function addPerson(V, household, sex, ageYears, father, mother, opts = {}) {
  const id = V.people.length;
  const k = key(key(V.base, 1000), id);
  const age = opts.era ?? V.age;
  const traits = [];
  for (let t = 0; t < C.TRAITS.length; t++) {
    // inherited from a parent when there is one (with drift), else drawn; two draws averaged
    const inherit = father >= 0 ? V.people[chance(key(k, 30 + t), 500000) ? father : mother]?.traits[t] : -1;
    const drawn = idiv(pick(key(k, t), 101) + pick(key(k, 10 + t), 101), 2);
    traits.push(inherit >= 0 ? clamp(idiv(inherit * 2 + drawn, 3), 0, 100) : drawn);
  }
  const cul = C.CULTURE[age];
  const dev = (v, i) => clamp(v + pick(key(k, 40 + i), 51) - 25, 0, 100);
  const given = C.GIVEN[age][sex];
  const hh = V.households[household];
  const p = {
    id, name: opts.name ?? nameChild(V, hh, given, sex, key(k, P.NAME)), lineage: hh ? hh.lineage : -1, household, sex,
    born: V.day - ageYears * YEAR - pick(key(k, P.AGE), YEAR), alive: true, died: -1, deathCause: "", present: true, clearedDay: -1,
    role: "child", era: age, traits,
    values: { tradition: dev(cul.tradition, 0), faith: dev(cul.faith, 1), law: dev(cul.law, 2), mercy: dev(cul.mercy, 3) },
    hunger: 0, stress: 0, guilt: 0, offences: 0, spouse: -1, father, mother,
    rel: new Map(), grudges: new Map(), beliefs: [], marks: {}, epithets: [], plan: [], locked: false, secret: [],
  };
  V.people.push(p);
  if (hh) hh.members.push(id);
  p.role = roleFor(V, p);
  if (hh && V.day > 0 && !opts.quiet) logEvent(V, "birth", id, mother, { lineage: p.lineage }, [], "a newborn's cry");
  return id;
}

export const ageOf = (V, p) => idiv(V.day - p.born, YEAR);

function roleFor(V, p) {
  const a = ageOf(V, p);
  if (a < 14) return "child";
  const roles = C.ADULT_ROLES[p.era];
  return roles[pick(key(key(V.base, 2000), p.id), roles.length)];
}

export function electAuthorities(V) {
  let elder = -1, priest = -1;
  for (const p of V.people) {
    if (!p.alive || !p.present || p.era !== V.age || ageOf(V, p) < 30) continue;
    if (elder < 0 || p.born < V.people[elder].born || (p.born === V.people[elder].born && p.id < elder)) elder = p.id;
  }
  for (const p of V.people) {
    if (!p.alive || !p.present || p.id === elder || p.era !== V.age || ageOf(V, p) < 20) continue;
    if (priest < 0 || p.traits[C.PIETY] > V.people[priest].traits[C.PIETY]) priest = p.id;
  }
  if (V.authority !== elder && elder >= 0) V.people[elder].role = "elder";
  if (V.priest !== priest && priest >= 0) V.people[priest].role = "priest";
  V.authority = elder; V.priest = priest;
}

// Opinions: sparse, -100..100; kin are fond of each other by default.
export function opinion(V, a, b) {
  const pa = V.people[a];
  if (pa.rel.has(b)) return pa.rel.get(b);
  return isKin(V, a, b) ? 50 : 0;
}
export function setOpinion(V, a, b, v) {
  const pa = V.people[a];
  pa.rel.set(b, clamp(v, -100, 100));
  if (pa.rel.size > 16) { // keep the strongest feelings (Bannerlord: grudges are personal and few)
    let weakest = -1, w = 1000;
    for (const [k, val] of pa.rel) if (Math.abs(val) < w || (Math.abs(val) === w && k < weakest)) { w = Math.abs(val); weakest = k; }
    pa.rel.delete(weakest);
  }
}
export const isKin = (V, a, b) => {
  const pa = V.people[a], pb = V.people[b];
  return pa.household === pb.household || pa.lineage === pb.lineage || pa.spouse === b || pa.father === b || pa.mother === b || pb.father === a || pb.mother === a;
};

export const living = (V) => V.people.filter((p) => p.alive && p.present);

// ---------- one day ----------
export function stepDay(V) {
  // anything the stage did not finish yesterday resolves as it was going to
  while (V.pending.length) resolvePublic(V, V.pending[0].staging, "");
  const doy = V.day % YEAR;
  if (doy === 0) yearStart(V);
  food(V);
  life(V);
  directorDay(V);
  planDay(V);
  runScheduled(V);
  crimesToday(V);
  if (V.storms.length || V.stormPlan.length) stormDay(V);
  discoverCrimes(V);
  gossip(V);
  checkCases(V);
  minds(V);
  V.day++;
}

export function run(V, days) {
  for (let i = 0; i < days; i++) stepDay(V);
  return V;
}

function yearStart(V) {
  const y = idiv(V.day, YEAR);
  // harvest quality: most years fair, some poor, a few ruinous (droughts); keyed per year
  const r = ppm(key(key(V.base, P.HARVEST), y));
  V.harvest = r < 70000 ? 45 : r < 220000 ? 70 : r < 850000 ? 100 : 125;
  if (V.harvest <= 45) {
    V.stats.famines++;
    logEvent(V, "famine", -1, -1, { year: y }, [], "the grain rots in the ear");
    V.hardship = clamp(V.hardship + 500, 0, 1000);
    V.fear = clamp(V.fear + 250, 0, 1000);
  }
  // children come of age; the elder and priest are re-chosen if gone
  for (const p of V.people) if (p.alive && p.role === "child" && ageOf(V, p) >= 14) p.role = roleFor(V, p);
  if (V.authority < 0 || !V.people[V.authority].alive || !V.people[V.authority].present) electAuthorities(V);
  else if (V.priest < 0 || !V.people[V.priest].alive || !V.people[V.priest].present) electAuthorities(V);
  marriages(V);
  arrivals(V);
}

const SEASON = [80, 120, 150, 40]; // spring, summer, autumn, winter: percent of a role's yield

function food(V) {
  const season = SEASON[idiv(V.day % YEAR, 15)];
  for (const h of V.households) {
    let made = 0, eaters = 0;
    for (const id of h.members) {
      const p = V.people[id];
      if (!p.alive || !p.present) continue;
      eaters++;
      if (p.locked) continue;
      made += C.ROLES[p.role]?.yield ?? 0;
    }
    if (eaters === 0) continue;
    h.food += idiv(made * season * V.harvest, 10000) - eaters;
    if (h.food > eaters * 25) h.food = eaters * 25;
    const hungry = h.food < 0;
    if (hungry) h.food = Math.max(h.food, -eaters * 20);
    for (const id of h.members) {
      const p = V.people[id];
      if (!p.alive) continue;
      p.hunger = clamp(p.hunger + (hungry ? 60 : -80), 0, 1000);
    }
  }
  V.hardship = clamp(V.hardship - 5, 0, 1000);
  V.fear = clamp(V.fear - 8, 0, 1000);
}

function life(V) {
  for (const p of V.people) {
    if (!p.alive || !p.present) continue;
    const a = ageOf(V, p);
    const k = key(key(key(V.base, P.DEATH), V.day), p.id);
    // natural death: rises after 50; hunger raises it (famine); store-tier children never die of hunger
    let risk = a < 50 ? 30 : a < 60 ? 250 : a < 70 ? 900 : 2500;
    if (p.hunger >= 900 && !(V.tier === "store" && a < 14)) risk += 1500;
    if (chance(k, risk)) die(V, p.id, p.hunger >= 900 ? "hunger" : "age", [], p.hunger >= 900 ? "the empty bowl by the bed" : "the bell for the dead");
  }
  // births: married women 18-40 with a living husband, not in famine, small household
  for (const p of V.people) {
    if (!p.alive || !p.present || p.sex !== 1 || p.spouse < 0 || !V.people[p.spouse].alive) continue;
    const a = ageOf(V, p);
    if (a < 18 || a > 40) continue;
    const hh = V.households[p.household];
    if (hh.members.filter((m) => V.people[m].alive).length >= 8 || hh.food < 0) continue;
    if (chance(key(key(key(V.base, P.BIRTH), V.day), p.id), 9000)) {
      const k = key(key(V.base, P.SEX), V.people.length);
      const baby = addPerson(V, p.household, pick(k, 2), 0, p.spouse, p.id, p.ancestor !== undefined ? { era: p.era } : {});
      if (p.ancestor !== undefined) { V.people[baby].ancestor = p.ancestor; V.storms[p.ancestor].ancestors.push(baby); } // born in the storm, goes with it
      V.stats.births++;
    }
  }
}

export function die(V, id, cause, causes, cue) {
  const p = V.people[id];
  if (!p.alive) return -1;
  // a deathbed confession: the dying who let another pay may tell the priest at the last
  if (p.guilt > 0 && ["age", "hunger"].includes(cause) && p.traits[C.PIETY] >= 35) confessGuilt(V, id, true);
  p.alive = false; p.died = V.day; p.deathCause = cause; p.locked = false;
  V.lineages[p.lineage]?.pastNames.push(p.name);
  V.stats.deaths++;
  const violent = !["age", "hunger"].includes(cause);
  if (violent) V.stats.violentDeaths++;
  const ev = logEvent(V, violent ? "violent_death" : "death", id, -1, { cause }, causes, cue);
  // grief: kin and friends take it hard; a funeral tomorrow is the damper (Dwarf Fortress's lesson)
  for (const q of V.people) {
    if (!q.alive || q.id === id) continue;
    const o = opinion(V, q.id, id);
    if (o > 30) q.stress = clamp(q.stress + (isKin(V, q.id, id) ? 90 : 40), 0, 400);
  }
  V.schedule.push({ day: V.day + 1, kind: "funeral", who: id, causes: [ev] });
  if (V.authority === id || V.priest === id) electAuthorities(V);
  return ev;
}

function marriages(V) {
  const single = V.people.filter((p) => p.alive && p.present && p.spouse < 0 && ageOf(V, p) >= 18 && ageOf(V, p) <= 45 && p.era === V.age);
  for (const m of single) {
    if (m.sex !== 0 || m.spouse >= 0) continue;
    let best = -1, bestScore = -20;
    for (const w of single) {
      if (w.sex !== 1 || w.spouse >= 0 || isKin(V, m.id, w.id)) continue;
      const s = opinion(V, m.id, w.id) + opinion(V, w.id, m.id) + pick(key(key(V.base, P.MARRY), m.id * 997 + w.id + V.day), 60);
      if (s > bestScore) { bestScore = s; best = w.id; }
    }
    if (best < 0) continue;
    const w = V.people[best];
    m.spouse = best; w.spouse = m.id;
    // the bride joins the groom's household (patrilocal, as the villages of the age did)
    const old = V.households[w.household];
    old.members = old.members.filter((x) => x !== best);
    w.household = m.household; w.lineage = m.lineage;
    V.households[m.household].members.push(best);
    setOpinion(V, m.id, best, 70); setOpinion(V, best, m.id, 70);
    // the one who wanted her too: a rival's grudge against the groom, remembered (and sometimes repaid)
    let rival = -1, rs = 25;
    for (const r of single) {
      if (r.sex !== 0 || r.id === m.id || r.spouse >= 0 || isKin(V, r.id, best)) continue;
      const s = opinion(V, r.id, best) + pick(key(key(V.base, P.MARRY), r.id * 131 + best + V.day), 50);
      if (s > rs) { rs = s; rival = r.id; }
    }
    if (rival >= 0) {
      const rv = V.people[rival];
      const ev = logEvent(V, "rivalry", rival, m.id, { bride: best, motive: "love" }, [], `${rv.name} walking away from the wedding feast before the dancing`);
      setOpinion(V, rival, m.id, opinion(V, rival, m.id) - 30 - idiv(rv.traits[C.TEMPER], 2));
      remember(rv, m.id, ev);
    }
    V.schedule.push({ day: V.day + 3, kind: "wedding", who: m.id, other: best, causes: [] });
  }
}

// When the village shrinks, newcomers arrive: a new lineage takes an empty home (outsiders: suspicion's
// first targets, as in the witch-trial record).
function arrivals(V) {
  const alive = living(V).length;
  if (alive >= 22) return;
  const empty = V.households.find((h) => h.members.every((m) => !V.people[m].alive || !V.people[m].present));
  if (!empty) return;
  const k = key(key(V.base, P.ARRIVAL), V.day);
  const names = C.LINEAGE_NAMES[V.age];
  // a name no living lineage holds; if all are held, the newcomers are named for where they came from
  const held = new Set(V.households.filter((h) => h.members.some((m) => V.people[m].alive && V.people[m].present)).map((h) => V.lineages[h.lineage].name));
  const free = names.filter((nm) => !held.has(nm));
  const lname = free.length ? free[pick(k, free.length)] : names[pick(k, names.length)] + " " + C.FROM[pick(key(k, 4), C.FROM.length)];
  const lin = { id: V.lineages.length, name: lname, age: V.age, feuds: {}, deeds: [], pastNames: [], outsider: true };
  V.lineages.push(lin);
  empty.lineage = lin.id; empty.members = []; empty.food = 30;
  const a = addPerson(V, empty.id, 0, 24 + pick(key(k, 1), 15), -1, -1, { quiet: true });
  const b = addPerson(V, empty.id, 1, 22 + pick(key(k, 2), 15), -1, -1, { quiet: true });
  V.people[a].spouse = b; V.people[b].spouse = a; V.people[a].outsider = true; V.people[b].outsider = true;
  for (let c = 0; c < 1 + pick(key(k, 3), 3); c++) addPerson(V, empty.id, pick(key(k, 10 + c), 2), 2 + pick(key(k, 20 + c), 10), a, b, { quiet: true });
  logEvent(V, "arrival", a, b, { lineage: lin.id }, [], "a cart with strangers at the gate");
}

// ---------- dawn plans: who is where, and when ----------
// A plan is a list of [from, to, place] in minutes. Night 21:00-06:00 at home; work 06:00-12:00 and
// 13:00-18:00 at the role's place; a meal at noon; the evening is a choice among places that offer something
// (the well and the square offer company, the shrine comfort, home family), weighted by needs and traits,
// picked at random among the top three (never always the best: crowds must not move in lockstep).
export function planDay(V) {
  const dk = key(key(V.base, P.PLAN), V.day);
  const holy = V.day % 7 === 0, market = V.day % 7 === 3;
  for (const p of V.people) {
    p.plan = [];
    if (!p.alive || !p.present) continue;
    const home = V.households[p.household].home;
    if (p.locked) { p.plan = [[0, DAY, p.lockedAt ?? "pillory"]]; continue; }
    const k = key(dk, p.id);
    const work = workPlace(V, p);
    const plan = [[0, 360, home]];
    if (holy && p.traits[C.PIETY] >= 35) plan.push([360, 540, home], [540, 660, "shrine"], [660, 1080, market ? "square" : home]);
    else if (market && (p.role === "merchant" || chance(key(k, 1), 350000))) plan.push([360, 600, work], [600, 780, "square"], [780, 1080, work]);
    else plan.push([360, 720, work], [720, 780, p.role === "farmer" || p.role === "herder" ? work : home], ...afternoon(p, work, k));
    plan.push([1080, 1260, eveningChoice(V, p, k)], [1260, DAY, home]);
    p.plan = plan;
  }
}

// Most afternoons are work; now and then an errand takes a person out alone (to the next village's market,
// to the far woods for timber or game): the lonely hours where no one sees.
function afternoon(p, work, k) {
  if (["child", "elder", "priest", "beggar"].includes(p.role) || !chance(key(k, 2), 60000)) return [[780, 1080, work]];
  const far = ["woodcutter", "hunter", "gatherer"].includes(p.role) ? "far_woods" : "road";
  return [[780, 840, work], [840, 1000, far], [1000, 1080, work]];
}

function workPlace(V, p) {
  const w = C.ROLES[p.role]?.work ?? "home";
  if (w === "home") return V.households[p.household].home;
  if (p.role === "child") return V.households[p.household].home;
  return w;
}

function eveningChoice(V, p, k) {
  const t = p.traits;
  const home = V.households[p.household].home;
  const offers = [
    ["well", t[C.SOCIABLE] * 2 + 20],
    ["square", t[C.SOCIABLE] + (100 - t[C.PIETY]) + idiv(p.stress, 4)],
    ["shrine", t[C.PIETY] * 2 + idiv(V.fear, 10) + idiv(p.stress, 4) + (p.guilt > 0 ? 60 : 0)],
    [home, (100 - t[C.SOCIABLE]) + 60],
  ];
  // a friend's home: the best-liked person outside one's household
  let friend = -1, fo = 40;
  for (const [o, v] of p.rel) if (v > fo && V.people[o].alive && V.people[o].present && V.people[o].household !== p.household) { fo = v; friend = o; }
  if (friend >= 0) offers.push([V.households[V.people[friend].household].home, fo + t[C.SOCIABLE]]);
  offers.sort((a, b) => b[1] - a[1] || (a[0] < b[0] ? -1 : 1));
  const top = offers.slice(0, 3);
  const total = top.reduce((s, o) => s + Math.max(1, o[1]), 0);
  let r = pick(key(k, 99), total);
  for (const o of top) { r -= Math.max(1, o[1]); if (r < 0) return o[0]; }
  return top[0][0];
}

// Where a person is at a minute (from today's plan); "" if absent.
export function placeAt(p, minute) {
  for (const [from, to, place] of p.plan) if (minute >= from && minute < to) return place;
  return "";
}

// People who can see a place at a minute: anyone whose own place is within sight of it.
export function witnessesAt(V, place, minute, exclude) {
  const [px, pz] = V.layout.pos[place] ?? [0, 0];
  const night = minute < 360 || minute >= 1260;
  const r = night ? C.SEE_NIGHT : C.SEE_DAY;
  const out = [];
  for (const q of V.people) {
    if (!q.alive || !q.present || q.id === exclude) continue;
    const at = placeAt(q, minute);
    if (!at) continue;
    const [qx, qz] = V.layout.pos[at] ?? [0, 0];
    const dx = qx - px, dz = qz - pz;
    if (dx * dx + dz * dz <= r * r) out.push(q.id);
  }
  return out;
}

// ---------- minds: stress, guilt, coping, belief fading, feelings drifting ----------
function minds(V) {
  for (const p of V.people) {
    if (!p.alive || !p.present) continue;
    // stress eases a little each day; hunger and fear feed it
    p.stress = clamp(p.stress - 6 + idiv(p.hunger, 200) + idiv(V.fear, 250), 0, 400);
    // guilt for a crime someone else paid for grows with piety and compassion (it can break a person)
    // (a hard heart feels none: they carry it to the grave, unless the deathbed breaks them)
    if (p.guilt > 0 && p.traits[C.PIETY] + p.traits[C.COMPASSION] >= 100) {
      p.guilt = clamp(p.guilt + idiv(p.traits[C.PIETY] + p.traits[C.COMPASSION] - 60, 40) * V.pace, 0, 400);
      if (p.guilt >= 300) confessGuilt(V, p.id);
    }
    // beliefs fade; the weakest are forgotten
    for (const b of p.beliefs) b.strength -= 4;
    p.beliefs = p.beliefs.filter((b) => b.strength > 60);
    // feelings drift back towards neutral, slowly; deep hatreds hardly at all (grudges are few and kept)
    if (V.day % 10 === p.id % 10) for (const [o, v] of p.rel) {
      if (v < -50 && V.day % 60 !== p.id % 60) continue;
      p.rel.set(o, v > 0 ? v - 1 : v < 0 ? v + 1 : 0);
    }
  }
}

export function hashVillage(V) {
  let h = key(2166136261, V.day);
  for (const p of V.people) {
    h = key(h, p.id); h = key(h, p.alive ? 1 : 0); h = key(h, p.present ? 1 : 0); h = key(h, p.household); h = key(h, p.stress); h = key(h, p.hunger);
    h = key(h, p.offences); h = key(h, p.beliefs.length); h = key(h, p.spouse);
    const rel = [...p.rel.entries()].sort((a, b) => a[0] - b[0]);
    for (const [o, v] of rel) { h = key(h, o); h = key(h, v); }
    for (const b of p.beliefs) { h = key(h, b.crime); h = key(h, b.culprit); h = key(h, b.strength); h = key(h, b.origin); }
  }
  for (const hh of V.households) { h = key(h, hh.food); h = key(h, hh.members.length); h = key(h, hh.geese); }
  h = key(h, V.evHash);
  return (h >>> 0).toString(16).padStart(8, "0");
}
