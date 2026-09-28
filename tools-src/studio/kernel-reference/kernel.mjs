// Unbound world kernel - the integer reference (JavaScript).
//
// This file is the spec. The GDScript kernel in game/scripts/studio/kernel/ must match it hash for
// hash and chronicle line for line (golden.mjs writes the expected values; run.gd checks them).
// It follows the S1 prototype (kernel-prototype/sim.mjs) with every float removed, because floats
// drift between phone chips (fused multiply-add, differing maths libraries) and integers do not.
//
// The integer rules, which both implementations follow exactly:
//   - every value is an integer inside the signed 32-bit range; no Math.sqrt, Math.hypot or floats;
//   - chances are parts per million (ppm), multipliers per mille (pm), map positions tenths (0..1000);
//   - every division has non-negative operands, so floor and truncation agree;
//   - randomness is keyed: a draw is a hash chain of (seed, year, place, purpose, extra), never a stream;
//   - actions sort by every field, so any arrival order gives one canonical order;
//   - hashes cover the whole state and every chronicle event.

// ---------- randomness ----------
export function mix(h) {
  // lowbias32 (Chris Wellons' hash prospector); everything mod 2^32
  h = Math.imul(h ^ (h >>> 16), 0x7feb352d);
  h = Math.imul(h ^ (h >>> 15), 0x846ca68b);
  return (h ^ (h >>> 16)) >>> 0;
}
const key = (h, k) => mix((h ^ k) >>> 0);
const TWO32 = 4294967296;
const ppmOf = (d) => Math.floor((d * 1000000) / TWO32); // 0..999999
const pick = (d, n) => Math.floor((d * n) / TWO32); // 0..n-1, n <= 1,000,000

// Purpose codes keep keyed draws apart (same codes as S1).
export const P = { CLIMATE: 1, FLOOD: 2, GROW: 3, DISCOVER: 4, LOSE: 5, FOUND: 6, RAID: 7, TRADE: 8, NAME: 9, PLACE: 10, SPREAD: 11 };

// ---------- content ----------
export const PEOPLES = [
  { name: "Mainlanders", land: 0, fertile: 1150, ore: 200, forest: 1000 },
  { name: "Ashfolk", land: 1, fertile: 900, ore: 1000, forest: 600 },
  { name: "Tethered", land: 2, fertile: 1000, ore: 500, forest: 800 },
];

// Trades are bits in a mask.
export const TR = { FARMER: 1, WOODCUTTER: 2, MINER: 4, CARPENTER: 8, SMITH: 16, HERBALIST: 32 };

// Knowledge that needs other trades first. needs = bitmask of techs.
export const T = { FIRE: 0, FARMING: 1, POTTERY: 2, CHARCOAL: 3, COPPER: 4, MILL: 5, BREAD: 6, IRON: 7, WRITING: 8, BOATS: 9, MEDICINE: 10 };
export const TECH = [
  { name: "fire", needs: 0, trade: 0, minPop: 0 },
  { name: "farming", needs: 1 << T.FIRE, trade: 0, minPop: 0 },
  { name: "pottery", needs: 1 << T.FIRE, trade: 0, minPop: 0 },
  { name: "charcoal", needs: 1 << T.FIRE, trade: TR.WOODCUTTER, minPop: 0 },
  { name: "copper", needs: 1 << T.CHARCOAL, trade: TR.MINER, minPop: 0 },
  { name: "the mill", needs: 1 << T.FARMING, trade: TR.CARPENTER, minPop: 0 },
  { name: "bread", needs: (1 << T.MILL) | (1 << T.POTTERY), trade: 0, minPop: 0 },
  { name: "iron", needs: (1 << T.COPPER) | (1 << T.CHARCOAL), trade: TR.SMITH, minPop: 0 },
  { name: "writing", needs: 1 << T.POTTERY, trade: 0, minPop: 90 },
  { name: "boats", needs: 1 << T.COPPER, trade: TR.CARPENTER, minPop: 0 },
  { name: "medicine", needs: 1 << T.WRITING, trade: TR.HERBALIST, minPop: 0 },
];
const NT = TECH.length;
export const has = (mask, t) => ((mask >> t) & 1) === 1;
function topBit(mask) {
  for (let t = NT - 1; t >= 0; t--) if (has(mask, t)) return t;
  return -1;
}

export const STAGES = ["hut", "homestead", "hamlet", "village", "town"];
export const stageOf = (pop) => (pop <= 0 ? -1 : pop < 20 ? 0 : pop < 50 ? 1 : pop < 120 ? 2 : pop < 250 ? 3 : 4);

const SYL = ["ar", "bel", "cor", "dun", "el", "fen", "gar", "hol", "is", "kel", "lor", "mor", "nor", "or", "pel", "ran", "sil", "tor", "ul", "ven", "wen", "yr", "ash", "brin"];

// Chronicle event types.
export const E = {
  FOUNDED: 0, DROUGHT: 1, FLOOD_HELD: 2, FLOOD: 3, HUNGER: 4, DISCOVERY: 5, REDISCOVERY: 6, FORGOT: 7,
  AID: 8, RAID: 9, LEARNED: 10, RUIN: 11, WARNED: 12, TAUGHT: 13, GIFT: 14, FELLED: 15, BRIDGE: 16, STORM: 17,
};

// Player actions. Every field is an integer: {year, player, seq, kind, target, a, b}.
export const A = { WARN: 1, TEACH: 2, GIFT: 3, FELL: 4, BRIDGE: 5, STORM: 6 };
// WARN a=years of dykes · TEACH a=tech · GIFT a=grain · FELL a=grain lost · BRIDGE -
// STORM a=share of the village folded (per mille), b=the year it is folded into

const REL_STRIDE = 4096; // relation key = from * 4096 + to
const START_FOOD = 20;

// ---------- the world ----------
export function createWorld(seed) {
  const w = {
    seed: seed >>> 0, base: mix((seed ^ 0x9e3779b9) >>> 0), year: 0, n: 0,
    people: [], x: [], y: [], pop: [], food: [], tech: [], lost: [], river: [], ore: [], founded: [],
    parent: [], ruined: [], hadMill: [], floodProof: [], era: [], enclaveOf: [], name: [],
    rel: new Map(),
    ev: { year: [], type: [], sub: [], other: [], a: [], b: [], c: [] }, evHash: 2166136261,
  };
  const h0 = key(w.base, 0);
  for (let p = 0; p < PEOPLES.length; p++) {
    for (let i = 0; i < 4; i++) {
      const hK = key(h0, p * 10 + i);
      const hP = key(hK, P.PLACE);
      addSettlement(w, p, pick(key(hP, 0), 1000), pick(key(hP, 1), 1000), 18 + pick(key(hK, P.GROW), 12), -1, false);
    }
  }
  return w;
}

function addSettlement(w, people, x, y, pop, parent, quiet) {
  const id = w.n++;
  const hI = key(key(w.base, 0), id);
  const hP = key(hI, P.PLACE);
  w.people.push(people); w.x.push(x); w.y.push(y); w.pop.push(pop); w.food.push(START_FOOD);
  w.tech.push(1 << T.FIRE); w.lost.push(0);
  w.river.push(ppmOf(key(hP, 2)) < 450000 ? 1 : 0);
  w.ore.push(ppmOf(key(hP, 3)) < 300000 ? 1 : 0);
  w.founded.push(w.year); w.parent.push(parent); w.ruined.push(-1); w.hadMill.push(0);
  w.floodProof.push(0); w.era.push(-1); w.enclaveOf.push(-1);
  const hN = key(hI, P.NAME);
  const syl = 2 + pick(key(hN, 0), 2);
  let s = "";
  for (let i = 0; i < syl; i++) s += SYL[pick(key(hN, i + 1), SYL.length)];
  w.name.push(s[0].toUpperCase() + s.slice(1));
  if (!quiet) event(w, E.FOUNDED, id, parent, 0, 0, 0);
  return id;
}

function event(w, type, sub, other, a, b, c) {
  const ev = w.ev;
  ev.year.push(w.year); ev.type.push(type); ev.sub.push(sub); ev.other.push(other); ev.a.push(a); ev.b.push(b); ev.c.push(c);
  let h = w.evHash;
  h = key(h, w.year); h = key(h, type); h = key(h, sub); h = key(h, other); h = key(h, a); h = key(h, b); h = key(h, c);
  w.evHash = h;
}

const relGet = (w, a, b) => w.rel.get(a * REL_STRIDE + b) ?? 0;
const relSet = (w, a, b, v) => w.rel.set(a * REL_STRIDE + b, v);

function tradesOf(w, s) {
  const pp = PEOPLES[w.people[s]];
  const pop = w.pop[s];
  let t = TR.FARMER;
  if (pp.forest > 500) t |= TR.WOODCUTTER;
  if (pp.ore > 400 || w.ore[s]) t |= TR.MINER;
  if (pop >= 30) t |= TR.CARPENTER;
  if (has(w.tech[s], T.COPPER) && pop >= 45) t |= TR.SMITH;
  if (pop >= 60) t |= TR.HERBALIST;
  return t;
}

const d2 = (w, a, b) => { const dx = w.x[a] - w.x[b], dy = w.y[a] - w.y[b]; return dx * dx + dy * dy; };
const NEAR2 = 200 * 200; // 20 map units: shares land
const REACH2 = 450 * 450; // 45 map units: can trade or raid overland

function canReach(w, a, b) {
  if (PEOPLES[w.people[a]].land === PEOPLES[w.people[b]].land) return d2(w, a, b) < REACH2;
  return has(w.tech[a], T.BOATS) && has(w.tech[b], T.BOATS); // across the sea only with boats on both shores
}

// 1000 * sqrt(n), floored, by integer Newton iteration (no floating point).
const SQRT_CACHE = [];
export function sqrt1000(n) {
  if (SQRT_CACHE[n] !== undefined) return SQRT_CACHE[n];
  const v = n * 1000000;
  let x = v, y = Math.floor((x + 1) / 2);
  while (y < x) { x = y; y = Math.floor((x + Math.floor(v / x)) / 2); }
  SQRT_CACHE[n] = x;
  return x;
}

// Land is shared with close neighbours, so crowding caps growth.
function capacity(w, s, alive) {
  const land = PEOPLES[w.people[s]].land;
  let crowd = 0;
  for (const o of alive) if (w.pop[o] > 0 && PEOPLES[w.people[o]].land === land && d2(w, s, o) < NEAR2) crowd++;
  const t = w.tech[s];
  const base = 110 + (has(t, T.FARMING) ? 50 : 0) + (has(t, T.BREAD) ? 50 : 0) + (has(t, T.IRON) ? 25 : 0);
  return Math.floor((base * PEOPLES[w.people[s]].fertile) / sqrt1000(crowd));
}

const clampPos = (v) => (v < 0 ? 0 : v > 1000 ? 1000 : v);

// ---------- one year ----------
export function step(w, acts, hist) {
  const yr = w.year;
  for (const act of acts) applyAction(w, act, hist);
  const alive = [];
  for (let i = 0; i < w.n; i++) if (w.pop[i] > 0) alive.push(i);
  const hY = key(w.base, yr);
  for (const s of alive) {
    if (w.pop[s] <= 0) continue; // killed earlier this year (a raid); ruined below
    const pp = PEOPLES[w.people[s]];
    const hS = key(hY, s);
    const tr = tradesOf(w, s);
    // climate
    let climate = 1000;
    if (ppmOf(key(hS, P.CLIMATE)) < 60000) { climate = 550; event(w, E.DROUGHT, s, -1, 0, 0, 0); }
    if (w.river[s] && ppmOf(key(hS, P.FLOOD)) < 25000) {
      if (w.floodProof[s] > yr) {
        event(w, E.FLOOD_HELD, s, -1, 0, 0, 0);
      } else {
        const lost = Math.floor((w.pop[s] + 3) / 4); // a quarter, rounded up
        w.pop[s] -= lost;
        const mill = has(w.tech[s], T.MILL) ? 1 : 0;
        event(w, E.FLOOD, s, -1, lost, mill, 0);
        if (mill) { w.tech[s] &= ~((1 << T.MILL) | (1 << T.BREAD)); w.lost[s] |= 1 << T.MILL; }
        if (w.pop[s] <= 0) continue;
      }
    }
    // food
    const t = w.tech[s];
    const prod = pp.fertile + (has(t, T.FARMING) ? 220 : 0) + (has(t, T.BREAD) ? 180 : 0) + (has(t, T.IRON) ? 80 : 0) + (has(t, T.MEDICINE) ? 40 : 0);
    const cap = capacity(w, s, alive);
    const pop = w.pop[s];
    const worked = Math.min(pop, cap);
    const made = Math.floor(((worked * prod + (pop - worked) * 700) * climate) / 1000000);
    w.food[s] += made - pop;
    if (w.food[s] > pop * 2) w.food[s] = pop * 2;
    const hG = key(hS, P.GROW);
    if (w.food[s] >= 0) {
      const g = 20000 + pick(hG, 30000); // 2-5% a year
      w.pop[s] += Math.max(1, Math.floor((pop * g) / 1000000));
    } else {
      const lossPpm = 60000 + pick(hG, 100000); // 6-16%
      const loss = Math.max(1, Math.floor((pop * lossPpm) / 1000000));
      w.pop[s] -= loss;
      w.food[s] = 0;
      event(w, E.HUNGER, s, -1, loss, 0, 0);
      raidOrPlead(w, s, alive, hS);
    }
    // knowledge: discover, then lose
    const hD = key(hS, P.DISCOVER);
    for (let k = 1; k < NT; k++) {
      if (has(w.tech[s], k)) continue;
      const d = TECH[k];
      if ((w.tech[s] & d.needs) !== d.needs) continue;
      if (d.trade && !(tr & d.trade)) continue;
      if (d.minPop && w.pop[s] < d.minPop) continue;
      const again = has(w.lost[s], k); // rediscovery is easier: the ruins remember
      const chance = Math.floor(((again ? 60000 : 18000) * Math.min(w.pop[s], 120)) / 40);
      if (ppmOf(key(hD, k)) < chance) {
        w.tech[s] |= 1 << k;
        if (k === T.MILL) w.hadMill[s] = 1;
        event(w, again ? E.REDISCOVERY : E.DISCOVERY, s, -1, k, 0, 0);
      }
    }
    if (w.pop[s] < 15 && w.tech[s] > 3) {
      const top = topBit(w.tech[s]);
      if (top > 0 && ppmOf(key(hS, P.LOSE)) < 200000) {
        w.tech[s] &= ~(1 << top); w.lost[s] |= 1 << top;
        event(w, E.FORGOT, s, -1, top, 0, 0);
      }
    }
    // a daughter village, while the land has room
    if (w.pop[s] > 90 && w.pop[s] * 5 > cap * 4) {
      const hF = key(hS, P.FOUND);
      if (ppmOf(hF) < 80000 && countOnLand(w, alive, pp.land) < 12) {
        w.pop[s] -= 40;
        const d = addSettlement(w, w.people[s], clampPos(w.x[s] + pick(key(hF, 1), 301) - 150), clampPos(w.y[s] + pick(key(hF, 2), 301) - 150), 40, s, false);
        w.tech[d] = w.tech[s] & ~(1 << T.WRITING); // settlers carry skills, not the scribes
        w.hadMill[d] = has(w.tech[d], T.MILL) ? 1 : 0;
      }
    }
  }
  trade(w, alive, hY);
  for (const s of alive) {
    if (w.pop[s] <= 0) {
      w.pop[s] = 0; w.ruined[s] = yr;
      event(w, E.RUIN, s, -1, w.hadMill[s], 0, 0);
    }
  }
  w.year++;
}

function countOnLand(w, alive, land) {
  let c = 0;
  for (const o of alive) if (w.pop[o] > 0 && PEOPLES[w.people[o]].land === land) c++;
  return c;
}

function raidOrPlead(w, s, alive, hS) {
  let rich = -1;
  for (const o of alive) {
    if (o === s || w.pop[o] <= 0 || w.food[o] <= 30 || !canReach(w, s, o)) continue;
    if (rich < 0 || w.food[o] > w.food[rich]) rich = o; // ties keep the lower id
  }
  if (rich < 0) return;
  const rel = relGet(w, s, rich);
  if (rel > 20) {
    const gift = Math.floor(w.food[rich] / 3);
    w.food[rich] -= gift; w.food[s] += gift;
    event(w, E.AID, s, rich, gift, 0, 0);
  } else if (ppmOf(key(hS, P.RAID)) < 350000) {
    const take = Math.floor(w.food[rich] / 2);
    w.food[rich] -= take; w.food[s] += take;
    const dead = Math.min(w.pop[rich], 1 + Math.floor((w.pop[rich] * 5) / 100));
    w.pop[rich] -= dead;
    relSet(w, s, rich, rel - 40);
    relSet(w, rich, s, relGet(w, rich, s) - 60);
    event(w, E.RAID, s, rich, dead, take, 0);
  }
}

function trade(w, alive, hY) {
  for (let i = 0; i < alive.length; i++) {
    const a = alive[i];
    for (let j = i + 1; j < alive.length; j++) {
      const b = alive[j];
      if (w.pop[a] <= 0 || w.pop[b] <= 0 || !canReach(w, a, b)) continue;
      if (relGet(w, a, b) < -30) continue;
      const hPair = key(hY, a * 1000 + b);
      if (ppmOf(key(hPair, P.TRADE)) >= 250000) continue;
      relSet(w, a, b, Math.min(100, relGet(w, a, b) + 3));
      relSet(w, b, a, Math.min(100, relGet(w, b, a) + 3));
      // knowledge travels with traders
      const hSp = key(hPair, P.SPREAD);
      for (let k = 1; k < NT; k++) {
        const ha = has(w.tech[a], k), hb = has(w.tech[b], k);
        if (ha === hb) continue;
        const from = ha ? a : b, to = ha ? b : a;
        if ((w.tech[to] & TECH[k].needs) !== TECH[k].needs) continue;
        if (ppmOf(key(hSp, k)) < 50000) {
          w.tech[to] |= 1 << k;
          if (k === T.MILL) w.hadMill[to] = 1;
          event(w, E.LEARNED, to, from, k, 0, 0);
        }
      }
    }
  }
}

// ---------- actions: what players (and storms) do, in any era ----------
function applyAction(w, act, hist) {
  const s = act.target;
  if (s < 0 || s >= w.n || w.pop[s] <= 0) return;
  switch (act.kind) {
    case A.WARN: w.floodProof[s] = w.year + act.a; event(w, E.WARNED, s, -1, act.a, 0, 0); break;
    case A.TEACH:
      if (act.a < 1 || act.a >= NT) return;
      w.tech[s] |= 1 << act.a;
      if (act.a === T.MILL) w.hadMill[s] = 1;
      event(w, E.TAUGHT, s, -1, act.a, 0, 0);
      break;
    case A.GIFT: w.food[s] += act.a; event(w, E.GIFT, s, -1, act.a, 0, 0); break;
    case A.FELL: w.food[s] -= act.a; event(w, E.FELLED, s, -1, act.a, act.player, 0); break;
    case A.BRIDGE:
      for (const [k, v] of w.rel) if (Math.floor(k / REL_STRIDE) === s) w.rel.set(k, v + 10);
      event(w, E.BRIDGE, s, -1, 0, act.player, 0);
      break;
    case A.STORM: stormEnclave(w, s, act.a, act.b, hist); break;
  }
}

// A time storm turns part of a village into its own past. The district's present residents are
// displaced; the people of year `pastYear` stand in their place, with that year's knowledge, food and
// grudges. Both claim the same fields and the same name. Nothing scripts a fight: any conflict comes
// from the ordinary rules (shared land -> hunger -> raid or plead). The kernel computes the past
// itself, so the action in the log is only (target, share, year).
function stormEnclave(w, origin, sharePm, pastYear, hist) {
  if (!hist || pastYear < 0 || pastYear >= w.year || sharePm <= 0 || sharePm > 1000) return;
  const then = hist.stateAt(pastYear);
  if (origin >= then.n || then.pop[origin] <= 0) return; // the village did not exist yet
  const gone = Math.floor((w.pop[origin] * sharePm) / 1000);
  w.pop[origin] -= gone;
  const e = addSettlement(w, w.people[origin], clampPos(w.x[origin] + 20), clampPos(w.y[origin] + 10), Math.max(8, Math.floor((then.pop[origin] * sharePm) / 1000)), origin, true);
  w.name[e] = "Old " + w.name[origin];
  w.tech[e] = then.tech[origin];
  w.hadMill[e] = has(then.tech[origin], T.MILL) ? 1 : 0;
  w.era[e] = pastYear;
  w.enclaveOf[e] = origin;
  w.food[e] = Math.floor((then.food[origin] * sharePm) / 1000);
  for (const [k, v] of then.rel) if (Math.floor(k / REL_STRIDE) === origin) relSet(w, e, k % REL_STRIDE, v);
  const gap = w.year - pastYear;
  const pride = (then.tech[origin] & ~w.tech[origin]) !== 0 ? 10 : 0; // "you let the mill fall"
  relSet(w, e, origin, -10 - Math.floor(gap / 10) - pride);
  relSet(w, origin, e, -10 - Math.floor(gap / 20));
  event(w, E.STORM, e, origin, gone, pastYear, w.pop[e]);
}

// ---------- the action log ----------
export function canonical(actions) {
  const F = ["year", "player", "seq", "kind", "target", "a", "b"];
  const sorted = [...actions].sort((p, q) => { for (const f of F) if (p[f] !== q[f]) return p[f] - q[f]; return 0; });
  const byYear = new Map();
  for (const act of sorted) {
    if (!byYear.has(act.year)) byYear.set(act.year, []);
    byYear.get(act.year).push(act);
  }
  return byYear;
}

// ---------- snapshots, hashing ----------
const FIELDS = ["people", "x", "y", "pop", "food", "tech", "lost", "river", "ore", "founded", "parent", "ruined", "hadMill", "floodProof", "era", "enclaveOf"];

export function snapshot(w) {
  const c = { seed: w.seed, base: w.base, year: w.year, n: w.n, name: [...w.name], rel: new Map(w.rel), evHash: w.evHash };
  for (const f of FIELDS) c[f] = [...w[f]];
  c.ev = { year: [], type: [], sub: [], other: [], a: [], b: [], c: [] }; // events stay with the run that made them
  return c;
}

export function hashWorld(w) {
  let h = 2166136261;
  h = key(h, w.year); h = key(h, w.n);
  for (let i = 0; i < w.n; i++) for (const f of FIELDS) h = key(h, w[f][i]);
  const keys = [...w.rel.keys()].sort((p, q) => p - q);
  for (const k of keys) { h = key(h, k); h = key(h, w.rel.get(k)); }
  h = key(h, w.evHash);
  return h.toString(16).padStart(8, "0");
}

// ---------- history: checkpoints, resume, the past on demand ----------
export class History {
  constructor(seed, actions = [], every = 25) {
    this.seed = seed >>> 0;
    this.byYear = canonical(actions);
    this.every = every;
    this.checkpoints = new Map();
  }
  // Runs from year 0 (or the latest checkpoint at or before `from`) to `toYear`.
  run(toYear) {
    const w = createWorld(this.seed);
    while (w.year < toYear) {
      if (w.year % this.every === 0) this.checkpoints.set(w.year, snapshot(w));
      step(w, this.byYear.get(w.year) ?? [], this);
    }
    return w;
  }
  // The world as it stood at `year`: from the nearest checkpoint, never from year 0.
  stateAt(year) {
    const at = Math.floor(year / this.every) * this.every;
    const cp = this.checkpoints.get(at);
    if (!cp) throw new Error(`no checkpoint at ${at}`);
    return this.resume(cp, year);
  }
  resume(cp, toYear) {
    const w = snapshot(cp);
    while (w.year < toYear) step(w, this.byYear.get(w.year) ?? [], this);
    return w;
  }
}

// ---------- reading the chronicle ----------
const PLAYER_NAMES = ["someone", "Hilmi", "Enea"];
const nameOf = (w, i) => (i >= 0 && i < w.n ? w.name[i] : "?");
const who = (p) => PLAYER_NAMES[p] ?? `player ${p}`;

export function line(w, i) {
  const ev = w.ev;
  const X = nameOf(w, ev.sub[i]), O = nameOf(w, ev.other[i]), a = ev.a[i], b = ev.b[i], c = ev.c[i];
  switch (ev.type[i]) {
    case E.FOUNDED: return ev.other[i] < 0 ? `${X} is founded by the ${PEOPLES[w.people[ev.sub[i]]].name}` : `settlers from ${O} found ${X}`;
    case E.DROUGHT: return `drought in ${X}`;
    case E.FLOOD_HELD: return `the river rises at ${X}, but the dykes hold`;
    case E.FLOOD: return `a flood takes ${a} lives in ${X}` + (b ? " and destroys the mill" : "");
    case E.HUNGER: return `hunger in ${X}: ${a} die or leave`;
    case E.DISCOVERY: return `${X} discovers ${TECH[a].name}`;
    case E.REDISCOVERY: return `${X} rediscovers ${TECH[a].name}`;
    case E.FORGOT: return `${X} forgets ${TECH[a].name}`;
    case E.AID: return `${O} sends ${a} grain to ${X}`;
    case E.RAID: return `${X} raids ${O} for ${b} grain; ${a} fall`;
    case E.LEARNED: return `${X} learns ${TECH[a].name} from ${O}`;
    case E.RUIN: return `${X} is abandoned` + (a ? "; its mill stands empty" : "");
    case E.WARNED: return `a stranger from another age warns ${X} of the flood; they raise dykes`;
    case E.TAUGHT: return `a stranger teaches ${X} ${TECH[a].name}`;
    case E.GIFT: return `a traveller leaves ${a} grain at ${X}`;
    case E.FELLED: return `${who(b)} clears the woods by ${X}`;
    case E.BRIDGE: return `${who(b)} funds a bridge at ${X}`;
    case E.STORM: return `a time storm folds ${a} of ${O}'s people into year ${b}; ${c} people of that age stand in their place and call themselves ${X}`;
  }
  return `? event ${ev.type[i]}`;
}

export function describe(w, s) {
  if (w.pop[s] <= 0) return `${w.name[s]}: ruin since year ${w.ruined[s]}`;
  const known = TECH.map((t, k) => (has(w.tech[s], k) ? t.name : null)).filter(Boolean);
  return `${w.name[s]}: ${STAGES[stageOf(w.pop[s])]} of ${w.pop[s]}, knows ${known.join(", ")}`;
}
