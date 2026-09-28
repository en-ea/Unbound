// S1 spike - the world as a pure function of (seed, year, interventions).
// Coarse, village-level history for three peoples. No engine, no dependencies.
// Two randomness modes:
//   "keyed"  - every draw is a hash of (seed, year, settlement, purpose), so a change only
//              affects what it causally touches;
//   "stream" - one shared random stream, the usual approach, where any change shifts every
//              later draw.

// ---------- randomness ----------
function mix(h) {
  h = Math.imul(h ^ (h >>> 16), 0x7feb352d);
  h = Math.imul(h ^ (h >>> 15), 0x846ca68b);
  return (h ^ (h >>> 16)) >>> 0;
}
function keyed(seed) {
  return (...key) => {
    let h = mix(seed ^ 0x9e3779b9);
    for (const k of key) h = mix(h ^ (k | 0));
    return h / 4294967296;
  };
}
function stream(seed) {
  let s = seed >>> 0;
  return () => {
    s = (s + 0x6d2b79f5) >>> 0;
    let t = Math.imul(s ^ (s >>> 15), 1 | s);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

// Purpose codes keep keyed draws apart.
const P = { CLIMATE: 1, FLOOD: 2, GROW: 3, DISCOVER: 4, LOSE: 5, FOUND: 6, RAID: 7, TRADE: 8, NAME: 9, PLACE: 10, SPREAD: 11 };

// ---------- the world's content ----------
export const PEOPLES = [
  { name: "Mainlanders", land: 0, fertile: 1.15, ore: 0.2, forest: 1.0 },
  { name: "Ashfolk", land: 1, fertile: 0.9, ore: 1.0, forest: 0.6 },
  { name: "the Tethered", land: 2, fertile: 1.0, ore: 0.5, forest: 0.8 },
];

// Knowledge that needs other trades first: "one guy needs to cook for the other to continue".
export const TECH = [
  { name: "fire", needs: [] },
  { name: "farming", needs: [0] },
  { name: "pottery", needs: [0] },
  { name: "charcoal", needs: [0], trade: "woodcutter" },
  { name: "copper", needs: [3], trade: "miner" },
  { name: "the mill", needs: [1], trade: "carpenter" },
  { name: "bread", needs: [5, 2] },
  { name: "iron", needs: [4, 3], trade: "smith" },
  { name: "writing", needs: [2], minPop: 90 },
  { name: "boats", needs: [4], trade: "carpenter" },
  { name: "medicine", needs: [8], trade: "herbalist" },
];
const has = (s, t) => (s.tech & (1 << t)) !== 0;
const STAGES = ["hut", "homestead", "hamlet", "village", "town"];
const stageOf = (pop) => (pop <= 0 ? -1 : pop < 20 ? 0 : pop < 50 ? 1 : pop < 120 ? 2 : pop < 250 ? 3 : 4);

function trades(s, people) {
  const t = new Set(["farmer"]);
  if (people.forest > 0.5) t.add("woodcutter");
  if (people.ore > 0.4 || s.oreSite) t.add("miner");
  if (s.pop >= 30) t.add("carpenter");
  if (has(s, 4) && s.pop >= 45) t.add("smith");
  if (s.pop >= 60) t.add("herbalist");
  return t;
}

const SYL = ["ar", "bel", "cor", "dun", "el", "fen", "gar", "hol", "is", "kel", "lor", "mor", "nor", "or", "pel", "ran", "sil", "tor", "ul", "ven", "wen", "yr", "ash", "brin"];
function nameFrom(r, ...key) {
  const n = 2 + Math.floor(r(...key, 0) * 2);
  let s = "";
  for (let i = 0; i < n; i++) s += SYL[Math.floor(r(...key, i + 1) * SYL.length)];
  return s[0].toUpperCase() + s.slice(1);
}

// ---------- world creation ----------
export function createWorld(seed, mode = "keyed") {
  const K = keyed(seed);
  const S = mode === "stream" ? stream(seed) : null;
  const r = S ? () => S() : K; // stream mode ignores keys
  const world = { seed, mode, year: 0, settlements: [], nextId: 0, events: [] };
  world._r = r;
  for (let p = 0; p < PEOPLES.length; p++) {
    for (let i = 0; i < 4; i++) addSettlement(world, p, r(0, p * 10 + i, P.PLACE, 0) * 100, r(0, p * 10 + i, P.PLACE, 1) * 100, 18 + Math.floor(r(0, p * 10 + i, P.GROW) * 12), null);
  }
  return world;
}

function addSettlement(world, people, x, y, pop, parent, quiet = false) {
  const r = world._r;
  const id = world.nextId++;
  const s = {
    id, people, x, y, pop, food: 20, tech: 1, // everyone starts with fire
    river: r(0, id, P.PLACE, 2) < 0.45, oreSite: r(0, id, P.PLACE, 3) < 0.3,
    name: nameFrom(r, 0, id, P.NAME), founded: world.year, parent, ruinedYear: null,
    hadMill: false, lostTech: 0, rel: {}, floodProof: 0,
  };
  world.settlements.push(s);
  if (!quiet) log(world, s, "founded", parent === null ? `${s.name} is founded by the ${PEOPLES[people].name}` : `settlers from ${world.settlements[parent].name} found ${s.name}`);
  return s;
}

function log(world, s, type, text, other = null) {
  world.events.push({ year: world.year, id: s.id, type, text, other });
}

// ---------- one year ----------
export function stepYear(world, interventions = []) {
  const r = world._r;
  const y = world.year;
  for (const iv of interventions) applyIntervention(world, iv);
  const alive = world.settlements.filter((s) => s.pop > 0);
  for (const s of alive) {
    const ppl = PEOPLES[s.people];
    const tr = trades(s, ppl);
    // climate
    let climate = 1;
    if (r(y, s.id, P.CLIMATE) < 0.06) { climate = 0.55; log(world, s, "drought", `drought in ${s.name}`); }
    if (s.river && r(y, s.id, P.FLOOD) < 0.025) {
      if (s.floodProof > y) {
        log(world, s, "flood-held", `the river rises at ${s.name}, but the dykes hold`);
      } else {
        const lost = Math.ceil(s.pop * 0.25);
        s.pop -= lost;
        log(world, s, "flood", `a flood takes ${lost} lives in ${s.name}` + (has(s, 5) ? " and destroys the mill" : ""));
        if (has(s, 5)) { s.tech &= ~(1 << 5); s.tech &= ~(1 << 6); s.lostTech |= (1 << 5); }
      }
    }
    // food: land is shared with close neighbours, so crowding caps growth
    let prod = 1.0 * ppl.fertile;
    if (has(s, 1)) prod += 0.22;
    if (has(s, 6)) prod += 0.18;
    if (has(s, 7)) prod += 0.08;
    if (has(s, 10)) prod += 0.04;
    const cap = capacity(s, alive);
    const worked = Math.min(s.pop, cap);
    const made = Math.floor((worked * prod + (s.pop - worked) * 0.7) * climate);
    s.food += made - s.pop;
    if (s.food > s.pop * 2) s.food = s.pop * 2;
    if (s.food >= 0) {
      const g = 0.02 + r(y, s.id, P.GROW) * 0.03;
      s.pop += Math.max(1, Math.floor(s.pop * g));
    } else {
      const loss = Math.max(1, Math.floor(s.pop * (0.06 + r(y, s.id, P.GROW) * 0.1)));
      s.pop -= loss;
      s.food = 0;
      log(world, s, "hunger", `hunger in ${s.name}: ${loss} die or leave`);
      raidOrPlead(world, s, alive);
    }
    // knowledge: discover, spread, lose
    for (let t = 1; t < TECH.length; t++) {
      if (has(s, t)) continue;
      const d = TECH[t];
      if (!d.needs.every((n) => has(s, n))) continue;
      if (d.trade && !tr.has(d.trade)) continue;
      if (d.minPop && s.pop < d.minPop) continue;
      const again = (s.lostTech & (1 << t)) !== 0; // rediscovery is easier: the ruins remember
      const chance = (again ? 0.06 : 0.018) * Math.min(3, s.pop / 40);
      if (r(y, s.id, P.DISCOVER, t) < chance) {
        s.tech |= 1 << t;
        if (t === 5) s.hadMill = true;
        log(world, s, again ? "rediscovery" : "discovery", `${s.name} ${again ? "rediscovers" : "discovers"} ${d.name}`);
      }
    }
    if (s.pop < 15 && s.tech > 3) {
      const top = 31 - Math.clz32(s.tech);
      if (top > 0 && r(y, s.id, P.LOSE) < 0.2) {
        s.tech &= ~(1 << top); s.lostTech |= 1 << top;
        log(world, s, "knowledge-lost", `${s.name} forgets ${TECH[top].name}`);
      }
    }
    // founding a daughter village, while the land has room
    const land = PEOPLES[s.people].land;
    const onLand = alive.filter((o) => o.pop > 0 && PEOPLES[o.people].land === land).length;
    if (s.pop > cap * 0.8 && s.pop > 90 && onLand < 12 && r(y, s.id, P.FOUND) < 0.08) {
      s.pop -= 40;
      const d = addSettlement(world, s.people, clamp(s.x + (r(y, s.id, P.FOUND, 1) - 0.5) * 30), clamp(s.y + (r(y, s.id, P.FOUND, 2) - 0.5) * 30), 40, s.id);
      d.tech = s.tech & ~(1 << 8); // settlers carry skills, not the scribes
    }
  }
  trade(world, alive);
  for (const s of alive) {
    if (s.pop <= 0) {
      s.pop = 0; s.ruinedYear = y;
      log(world, s, "ruin", `${s.name} is abandoned` + (s.hadMill ? "; its mill stands empty" : ""));
    }
  }
  world.year++;
}

function capacity(s, alive) {
  const land = PEOPLES[s.people].land;
  let crowd = 0;
  for (const o of alive) if (o.pop > 0 && PEOPLES[o.people].land === land && dist(s, o) < 20) crowd++;
  const base = 110 + (has(s, 1) ? 50 : 0) + (has(s, 6) ? 50 : 0) + (has(s, 7) ? 25 : 0);
  return Math.floor((base * PEOPLES[s.people].fertile) / Math.sqrt(crowd));
}

function clamp(v) { return Math.max(0, Math.min(100, v)); }
function dist(a, b) { return Math.hypot(a.x - b.x, a.y - b.y); }
function canReach(a, b) {
  if (PEOPLES[a.people].land === PEOPLES[b.people].land) return dist(a, b) < 45;
  return has(a, 9) && has(b, 9); // across the sea only with boats on both shores
}

function raidOrPlead(world, s, alive) {
  const r = world._r;
  const rich = alive.filter((o) => o !== s && o.pop > 0 && o.food > 30 && canReach(s, o)).sort((a, b) => b.food - a.food || a.id - b.id)[0];
  if (!rich) return;
  const rel = s.rel[rich.id] ?? 0;
  if (rel > 20) {
    const gift = Math.floor(rich.food / 3);
    rich.food -= gift; s.food += gift;
    log(world, s, "aid", `${rich.name} sends grain to ${s.name}`);
  } else if (r(world.year, s.id, P.RAID) < 0.35) {
    const take = Math.floor(rich.food / 2);
    rich.food -= take; s.food += take;
    const dead = Math.min(rich.pop, 1 + Math.floor(rich.pop * 0.05));
    rich.pop -= dead;
    s.rel[rich.id] = rel - 40; rich.rel[s.id] = (rich.rel[s.id] ?? 0) - 60;
    log(world, s, "raid", `${s.name} raids ${rich.name} for grain; ${dead} fall`, rich.id);
  }
}

function trade(world, alive) {
  const r = world._r;
  const y = world.year;
  for (let i = 0; i < alive.length; i++) {
    for (let j = i + 1; j < alive.length; j++) {
      const a = alive[i], b = alive[j];
      if (a.pop <= 0 || b.pop <= 0 || !canReach(a, b)) continue;
      if ((a.rel[b.id] ?? 0) < -30) continue;
      if (r(y, a.id * 1000 + b.id, P.TRADE) < 0.25) {
        a.rel[b.id] = Math.min(100, (a.rel[b.id] ?? 0) + 3);
        b.rel[a.id] = Math.min(100, (b.rel[a.id] ?? 0) + 3);
        // knowledge travels with traders
        for (let t = 1; t < TECH.length; t++) {
          const from = has(a, t) && !has(b, t) ? a : has(b, t) && !has(a, t) ? b : null;
          if (!from) continue;
          const to = from === a ? b : a;
          if (TECH[t].needs.every((n) => has(to, n)) && r(y, a.id * 1000 + b.id, P.SPREAD, t) < 0.05) {
            to.tech |= 1 << t;
            if (t === 5) to.hadMill = true;
            log(world, to, "learned", `${to.name} learns ${TECH[t].name} from ${from.name}`, from.id);
          }
        }
      }
    }
  }
}

// ---------- interventions: what players do, in any era ----------
function applyIntervention(world, iv) {
  const s = world.settlements.find((x) => x.id === iv.target);
  if (!s || s.pop <= 0) return;
  switch (iv.kind) {
    case "warn-of-flood": s.floodProof = world.year + (iv.years ?? 20); log(world, s, "intervention", `a stranger from another age warns ${s.name} of the flood; they raise dykes`); break;
    case "teach": s.tech |= 1 << iv.tech; log(world, s, "intervention", `a stranger teaches ${s.name} ${TECH[iv.tech].name}`); break;
    case "gift-food": s.food += iv.amount; log(world, s, "intervention", `a traveller leaves ${iv.amount} grain at ${s.name}`); break;
    case "fell-forest": s.food -= iv.amount; log(world, s, "intervention", `${iv.by} clears the woods by ${s.name}`); break;
    case "fund-bridge": s.rel = Object.fromEntries(Object.entries(s.rel).map(([k, v]) => [k, v + 10])); log(world, s, "intervention", `${iv.by} funds a bridge at ${s.name}`); break;
    case "storm-enclave": stormEnclave(world, s, iv); break;
  }
}

// A time storm turns part of a village into its own past. The district's present residents are
// displaced; the people of year `past.year` stand in their place, with that year's knowledge and
// grudges. Both claim the same fields and the same name. Nothing below scripts a fight: any
// conflict comes from the ordinary rules (shared land -> hunger -> raid or plead).
function stormEnclave(world, origin, iv) {
  const { share, past } = iv;
  const gone = Math.floor(origin.pop * share);
  origin.pop -= gone;
  const e = addSettlement(world, origin.people, clamp(origin.x + 2), clamp(origin.y + 1), Math.max(8, Math.floor(past.pop * share)), origin.id, true);
  e.name = `Old ${origin.name}`;
  e.tech = past.tech;
  e.hadMill = (past.tech & (1 << 5)) !== 0;
  e.era = past.year;
  e.enclaveOf = origin.id;
  e.food = Math.floor(past.food * share);
  e.rel = { ...past.rel };
  const gap = world.year - past.year;
  const pride = (past.tech & ~origin.tech) !== 0 ? 10 : 0; // "you let the mill fall"
  e.rel[origin.id] = -10 - Math.floor(gap / 10) - pride;
  origin.rel[e.id] = -10 - Math.floor(gap / 20);
  log(world, e, "storm", `a time storm folds ${gone} of ${origin.name}'s people into year ${past.year}; ${e.pop} people of that age stand in their place and call themselves ${e.name}`, origin.id);
}

// ---------- running history, with checkpoints ----------
export function snapshot(world) {
  const { _r, events, ...rest } = world;
  return JSON.parse(JSON.stringify(rest));
}

// Runs from year 0 to `toYear`. Interventions are sorted into one canonical order so every device
// computes the same world whatever order the logs arrived in.
export function runHistory(seed, toYear, interventions = [], { mode = "keyed", every = 25 } = {}) {
  const w = createWorld(seed, mode);
  const byYear = canonical(interventions);
  const checkpoints = new Map();
  while (w.year < toYear) {
    if (w.year % every === 0) checkpoints.set(w.year, snapshot(w));
    stepYear(w, byYear.get(w.year) ?? []);
  }
  return { world: w, checkpoints };
}

export function canonical(interventions) {
  const sorted = [...interventions].sort((a, b) => a.year - b.year || (a.player ?? "").localeCompare(b.player ?? "") || (a.seq ?? 0) - (b.seq ?? 0));
  const m = new Map();
  for (const iv of sorted) (m.get(iv.year) ?? m.set(iv.year, []).get(iv.year)).push(iv);
  return m;
}

// Resume from a checkpoint (for time-storm views and edits to the past). Keyed mode only: a
// shared stream would have to be replayed from year 0, which is part of why keyed randomness wins.
export function resume(seed, cp, toYear, interventions = []) {
  const w = { ...JSON.parse(JSON.stringify(cp)), events: [] };
  w._r = keyed(seed);
  const byYear = canonical(interventions);
  while (w.year < toYear) stepYear(w, byYear.get(w.year) ?? []);
  return w;
}

export function hashWorld(world) {
  let h = 2166136261;
  for (const s of world.settlements) {
    for (const v of [s.id, s.pop, s.food, s.tech, s.lostTech, s.ruinedYear ?? -1]) h = mix(h ^ v);
  }
  return h.toString(16).padStart(8, "0");
}

export function describe(s) {
  if (s.pop <= 0) return `${s.name}: ruin since year ${s.ruinedYear}`;
  const known = TECH.map((t, i) => (has(s, i) ? t.name : null)).filter(Boolean);
  return `${s.name}: ${STAGES[stageOf(s.pop)]} of ${s.pop}, knows ${known.join(", ")}`;
}
export { stageOf, STAGES, has };
