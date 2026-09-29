// Crime and knowledge. A crime needs a motive (hunger, greed, a grudge, fear), an opportunity (the target
// unwatched, read from the day plans) and inhibitions too weak to stop it (honesty, the law in one's
// values, how the age rates the act). It leaves traces and sightings; knowledge then travels only where
// plans put people together, weighted by trust and bent by dislike (Talk of the Town), and a case opens
// only when an accuser holds two independent sources (a complex contagion, Centola and Macy).
import { key, ppm, pick, chance, clamp, idiv } from "./rng.mjs";
import * as C from "./content.mjs";
import { logEvent, nameOf } from "./events.mjs";
import { P, YEAR, ageOf, opinion, setOpinion, isKin, placeAt, witnessesAt, living, die } from "./village.mjs";
import { scheduleTrial, authorityCapacity, scheduleMob } from "./justice.mjs";
import { lethalAllowed } from "./director.mjs";

const TRACE_ORIGIN = 1000000; // origins at or above this are traces (feathers, bones), not people
const MAX_BELIEFS = 8;
const PREJUDICE_ORIGIN = 2000000; // + household: a family's shared suspicion counts once

const inhibition = (V, p, act) => {
  const rating = C.ACTS[act].norms[p.era];
  const normWeight = [0, 0, 5, 15, 25, 110][rating];
  return p.traits[C.HONESTY] + idiv(p.values.law, 2) + normWeight + (V.authority === p.id ? 60 : 0);
};

export function crimesToday(V) {
  const dk = key(key(V.base, P.CRIME), V.day);
  for (const p of V.people) {
    if (!p.alive || !p.present || p.locked || ageOf(V, p) < 14) continue;
    const k = key(dk, p.id);
    tryTheft(V, p, k);
    tryBrawl(V, p, key(k, 7));
    tryMurder(V, p, key(k, 11));
    tryFamineRite(V, p, key(k, 13));
    tryPoaching(V, p, key(k, 17));
  }
  witchFear(V, dk);
  hoardingAnger(V, dk);
}

// ---------- poaching: game from the woods that belong to the village (the elder's to grant) ----------
function tryPoaching(V, p, k) {
  if (!["woodcutter", "hunter", "herder", "farmer"].includes(p.role)) return;
  const motive = idiv(p.hunger, 6) + p.traits[C.BOLD] + idiv(p.traits[C.GREED], 2);
  const inhib = inhibition(V, p, "poaching") + idiv(p.values.tradition, 2);
  if (motive <= inhib || !chance(k, (motive - inhib) * 700)) return;
  V.households[p.household].food += 6;
  const crime = addCrime(V, "poaching", p.id, -1, -1, 300, "woods", "a deer", [], "a snare in the elder's woods, blood on the moss", { motive: p.hunger >= 300 ? "hunger" : "boldness" });
  sightings(V, crime, k);
  crime.discovered = true;
  crime.discoveryEvent = crime.event;
}

// ---------- hoarding: in hard times the hungry turn on whoever still eats well ----------
function hoardingAnger(V, dk) {
  if (V.hardship < 350) return;
  let rich = -1;
  for (const h of V.households) if (h.members.some((m) => V.people[m].alive && V.people[m].present) && (rich < 0 || h.food > V.households[rich].food)) rich = h.id;
  if (rich < 0 || V.households[rich].food < 20) return;
  const head = V.households[rich].members.find((m) => V.people[m].alive && V.people[m].present && ageOf(V, V.people[m]) >= 18);
  if (head === undefined) return;
  let open = V.crimes.find((c) => c.act === "hoarding" && c.culprit === head && !c.closed);
  for (const q of V.people) {
    if (!q.alive || !q.present || q.hunger < 400 || isKin(V, q.id, head) || ageOf(V, q) < 16) continue;
    if (!chance(key(dk, 90000 + q.id), 20000 + q.traits[C.TEMPER] * 400)) continue;
    if (!open) open = addCrime(V, "hoarding", head, -1, -1, 720, V.households[rich].home, "grain", famineCause(V, q),
      "full sacks glimpsed through a barn door in a hungry year", { motive: "hunger", falseAccusation: false });
    open.discovered = true;
    giveBelief(V, q.id, open.id, head, 500 + idiv(q.hunger, 4), q.id, 0, -1);
  }
}

// ---------- theft ----------
function tryTheft(V, p, k) {
  // envy: a household watching its neighbours eat better than it does
  const mine = V.households[p.household].food;
  let richest = mine;
  for (const h of V.households) if (h.food > richest && h.members.some((m) => V.people[m].alive)) richest = h.food;
  const motive = idiv(p.hunger, 7) + p.traits[C.GREED] + clamp(idiv(richest - mine, 3), 0, 70);
  const inhib = inhibition(V, p, "theft");
  if (motive <= inhib) return;
  if (!chance(k, (motive - inhib) * 900 * V.pace)) return;
  // the target: a household with something worth taking, preferring those the thief dislikes
  let target = -1, best = -1000;
  for (const h of V.households) {
    if (h.id === p.household || h.lineage === p.lineage) continue;
    if (!h.members.some((m) => V.people[m].alive && V.people[m].present)) continue;
    const worth = h.food + h.geese * 15;
    if (worth < 12) continue;
    const head = h.members.find((m) => V.people[m].alive) ?? -1;
    const s = worth - (head >= 0 ? opinion(V, p.id, head) : 0) + pick(key(k, 100 + h.id), 10);
    if (s > best) { best = s; target = h.id; }
  }
  if (target < 0) return;
  const h = V.households[target];
  const place = "pen_" + h.home;
  if (!V.layout.pos[place]) return;
  // the opportunity: the minute (work hours) with the fewest eyes on the pen
  let when = -1, fewest = 99;
  for (let m = 420; m <= 1020; m += 60) {
    const eyes = witnessesAt(V, place, m, p.id).length;
    if (eyes < fewest || (eyes === fewest && (key(k, m) & 3) === 0)) { fewest = eyes; when = m; }
  }
  if (fewest > (p.hunger > 800 ? 3 : 1)) return; // too many eyes; not today
  const item = h.geese > 0 ? "goose" : "grain";
  if (item === "goose") h.geese--; else h.food -= 10;
  V.households[p.household].food += 10;
  const causes = famineCause(V, p);
  const crime = addCrime(V, "theft", p.id, target, -1, when, place, item, causes,
    item === "goose" ? `feathers by ${nameOf(V, p.id)}'s door` : "a torn grain sack", { motive: p.hunger >= 300 ? "hunger" : "greed" });
  sightings(V, crime, k);
  // the trace: goose feathers blow about the thief's door, or spilled grain leads to it
  crime.traceAt = V.households[p.household].home;
}

// ---------- brawls (assault): grudges meeting in the evening ----------
function tryBrawl(V, p, k) {
  if (p.traits[C.TEMPER] < 60) return;
  const evening = placeAt(p, 1150);
  if (!evening || evening.startsWith("pen")) return;
  for (const [o, v] of p.rel) {
    if (v > -40) continue;
    const q = V.people[o];
    if (!q.alive || !q.present || placeAt(q, 1150) !== evening || ageOf(V, q) < 14) continue;
    const inhib = inhibition(V, p, "assault");
    const motive = -v + p.traits[C.TEMPER];
    if (motive <= inhib || !chance(key(k, o), (motive - inhib) * 800 * V.pace)) continue;
    const why = p.grudges.get(o);
    // a brawl between deep enemies can end in a death (the blow that went too far), in the director's on-cycles
    const cold = p.traits[C.TEMPER] + p.traits[C.BOLD] - p.traits[C.HONESTY] - idiv(p.traits[C.COMPASSION], 2);
    if (v <= -80 && cold >= 40 && V.director.on && chance(key(k, 9000 + o), 180000 + (C.ROLES[p.role]?.strong ? 100000 : 0))) {
      const crime = addCrime(V, "murder", p.id, q.household, o, 1150, evening, "", why !== undefined ? [why] : [], `a brawl at the ${evening} that ended with someone not getting up`, { motive: why !== undefined ? "revenge" : "rage" });
      crime.deathEvent = die(V, o, "murder", [crime.event], `blood on the ground at the ${evening}, and a crowd gone silent`);
      sightings(V, crime, k, true);
      crime.discovered = true;
      return;
    }
    const crime = addCrime(V, "assault", p.id, q.household, o, 1150, evening, "", why !== undefined ? [why] : [], `a scuffle at the ${evening}`, { motive: "grudge" });
    q.stress = clamp(q.stress + 60, 0, 400);
    setOpinion(V, o, p.id, opinion(V, o, p.id) - 30);
    // the victim saw who did it; so did everyone there
    giveBelief(V, o, crime.id, p.id, 900, o, 0, -1);
    sightings(V, crime, k, true);
    crime.discovered = true;
    return;
  }
}

// ---------- murder: rare, and only when everything lines up ----------
function tryMurder(V, p, k) {
  // a cold heart: temper and boldness against honesty and compassion
  const cold = p.traits[C.TEMPER] + p.traits[C.BOLD] - p.traits[C.HONESTY] - idiv(p.traits[C.COMPASSION], 2);
  if (cold < 30) return;
  if (!V.director.on) return; // the director keeps murder for its on-cycles
  for (const [o, v] of p.rel) {
    if (v > -70) continue;
    const q = V.people[o];
    if (!q.alive || !q.present || ageOf(V, q) < 16) continue; // never a child, in any tier
    if (!chance(key(k, o), (cold + (-v - 70) * 3) * 300 * V.pace)) continue;
    // alone somewhere: at dawn, at work, or walking home at dusk, with no one near
    let place = "", minute = -1;
    for (const m of [390, 900, 920, 1290]) {
      const at = placeAt(q, m);
      if (!at || ["home", "square", "shrine"].includes(at) || at.startsWith("pen")) continue;
      if (witnessesAt(V, at, m, p.id).filter((w) => w !== o).length > 1) continue; // one pair of eyes may be missed
      place = at; minute = m; break;
    }
    if (minute < 0) continue;
    const why = p.grudges.get(o);
    const crime = addCrime(V, "murder", p.id, q.household, o, minute, place, "", why !== undefined ? [why] : [], `a body at the ${place}`, { motive: why !== undefined ? "revenge" : "grudge" });
    crime.deathEvent = die(V, o, "murder", [crime.event], `crows over the ${place}`);
    sightings(V, crime, k);
    return;
  }
}

// ---------- famine and the unspeakable ----------
function tryFamineRite(V, p, k) {
  if (V.tier === "store") return;
  const h = V.households[p.household];
  if (h.food > -15 || p.traits[C.PIETY] > 40 || p.hunger < 950) return;
  const dead = V.people.find((q) => !q.alive && q.household === p.household && V.day - q.died <= 4 && q.deathCause === "hunger" && !q.eaten);
  if (!dead) return;
  const inhib = inhibition(V, p, "cannibal_famine");
  if (!chance(k, Math.max(0, 1100 - inhib * 4))) return;
  dead.eaten = true;
  h.food += 12;
  const crime = addCrime(V, "cannibal_famine", p.id, p.household, dead.id, 60, "pen_" + h.home, "the dead", famineCause(V, p),
    "bones in the ash behind the house", { motive: "hunger" });
  crime.traceAt = h.home;
  sightings(V, crime, k);
}

// ---------- fear, omens and the witch: people 'remember' things about the village's outsiders ----------
function witchFear(V, dk) {
  if (V.fear < 420) return;
  // the most 'other' person: outsiders, loners, the marked, midwives and old women first (the trial record)
  let target = -1, best = -1;
  for (const q of V.people) {
    if (!q.alive || !q.present || ageOf(V, q) < 16 || q.id === V.authority) continue;
    let other = 100 - q.traits[C.SOCIABLE];
    if (q.outsider) other += 60;
    if (q.era !== V.age) other += 120; // storm people: the natural out-group
    if (q.role === "midwife") other += 40;
    if (q.sex === 1 && ageOf(V, q) >= 50) other += 40;
    if (q.marks.branded) other += 50;
    if (q.clearedDay >= 0 && V.day - q.clearedDay < 3 * YEAR) other -= 200;
    if (other > best || (other === best && q.id < target)) { best = other; target = q.id; }
  }
  if (target < 0) return;
  // the fearful and unkind form the belief themselves (confabulation: each is its own origin)
  let open = V.crimes.find((c) => c.act === "sorcery" && c.culprit === target && !c.closed);
  for (const q of V.people) {
    if (!q.alive || !q.present || q.id === target || ageOf(V, q) < 16 || isKin(V, q.id, target)) continue;
    const pull = idiv(V.fear, 8) + (100 - q.traits[C.COMPASSION]) + q.traits[C.PIETY] - opinion(V, q.id, target) - 150;
    if (pull <= 0 || !chance(key(dk, 70000 + q.id), pull * 1500 * V.pace)) continue;
    if (!open) open = addCrime(V, "sorcery", target, -1, -1, 1200, V.households[V.people[target].household].home, "", V.omenEvent >= 0 ? [V.omenEvent] : [],
      "charms of twisted straw found by a doorway", { motive: "fear", falseAccusation: true });
    giveBelief(V, q.id, open.id, target, 450 + idiv(V.fear, 4), q.id, 3, -1);
    open.discovered = true;
  }
}

function famineCause(V, p) {
  if (p.hunger < 300) return [];
  for (let i = V.events.length - 1; i >= 0 && i > V.events.length - 400; i--) if (V.events[i].type === "famine") return [i];
  return [];
}

function addCrime(V, act, culprit, household, victim, minute, place, item, causes, cue, data) {
  const crime = {
    id: V.crimes.length, act, culprit, household, victim, day: V.day, minute, place, item,
    discovered: false, closed: false, witnesses: [], traceAt: "", falseAccusation: data?.falseAccusation ?? false,
  };
  V.crimes.push(crime);
  V.stats.crimes++;
  crime.event = logEvent(V, "crime", culprit, victim, { crime: crime.id, act, item, motive: data?.motive ?? "", place, household }, causes, cue);
  if (!crime.falseAccusation) V.people[culprit].secret.push(crime.id);
  return crime;
}

// Who saw it: anyone whose plan puts them within sight, with a keyed chance by alertness (less by night).
function sightings(V, crime, k, publicAct = false) {
  const eyes = witnessesAt(V, crime.place, crime.minute, crime.culprit);
  const night = crime.minute < 360 || crime.minute >= 1260;
  for (const w of eyes) {
    const q = V.people[w];
    const odds = publicAct ? 900000 : (night ? 2500 : 7000) * q.traits[C.ALERT];
    if (!chance(key(k, 5000 + w), odds)) continue;
    crime.witnesses.push(w);
    giveBelief(V, w, crime.id, crime.culprit, 500 + q.traits[C.ALERT] * 4, w, 0, -1);
  }
}

// ---------- discovery: the loss is noticed; traces are seen ----------
export function discoverCrimes(V) {
  for (const c of V.crimes) {
    if (c.closed) continue;
    if (!c.discovered && V.day > c.day) {
      c.discovered = true;
      const owners = c.household >= 0 ? V.households[c.household].members.filter((m) => V.people[m].alive && V.people[m].present) : [];
      c.discoveryEvent = logEvent(V, "discovery", owners[0] ?? -1, -1, { crime: c.id, act: c.act }, [c.event],
        c.item === "goose" ? "an empty goose pen, a squawk remembered" : c.item === "grain" ? "the grain sacks lighter than yesterday" : c.act === "murder" ? "crows over a still shape" : "something wrong at the house");
      if (c.act === "murder") V.fear = clamp(V.fear + 250, 0, 1000);
      // prejudice: the wronged suspect someone they already dislike, or who is known for it (each such
      // suspicion is its own origin; with one real rumour it makes an accusation, right or wrong)
      for (const o of owners) suspect(V, o, c);
      // a killing: the elder asks who hated the dead (everyone saw the quarrels)
      if (c.act === "murder" && V.authority >= 0 && !owners.includes(V.authority)) suspect(V, V.authority, c);
      // honest witnesses come to the door the next day (Dwarf Fortress: a case exists through its witnesses)
      const told = owners.find((o) => ageOf(V, V.people[o]) >= 14);
      if (told !== undefined) for (const w of c.witnesses) {
        const q = V.people[w];
        if (!q.alive || !q.present || isKin(V, w, c.culprit) || q.traits[C.HONESTY] < 45 || opinion(V, w, c.culprit) > 30) continue;
        const seen = q.beliefs.find((b) => b.crime === c.id && b.origin === w);
        if (!seen) continue;
        const nb = giveBelief(V, told, c.id, seen.culprit, seen.strength, w, 1, w);
        nb.event = logEvent(V, "rumour", w, told, { crime: c.id, culprit: seen.culprit, via: 1 }, [c.discoveryEvent ?? c.event], `${nameOf(V, w)} at ${nameOf(V, told)}'s door with news`);
      }
    }
    // traces: neighbours of the thief's home who pass by may notice (feathers, bones)
    if (c.traceAt && V.day - c.day <= 3) {
      const eyes = witnessesAt(V, c.traceAt, 1100, c.culprit);
      for (const w of eyes) {
        if (isKin(V, w, c.culprit)) continue;
        if (chance(key(key(key(V.base, P.SIGHT), V.day), c.id * 131 + w), V.people[w].traits[C.ALERT] * 3000))
          giveBelief(V, w, c.id, c.culprit, 380, TRACE_ORIGIN + c.id, 0, -1);
      }
    }
  }
}

function suspect(V, pid, c) {
  const p = V.people[pid];
  if (ageOf(V, p) < 16) return;
  let who = -1, best = 30;
  for (const q of V.people) {
    if (!q.alive || !q.present || q.id === pid || isKin(V, pid, q.id) || ageOf(V, q) < 14) continue;
    let s = -opinion(V, pid, q.id) + q.offences * 40 + (q.outsider ? 25 : 0) + (q.marks.branded ? 40 : 0) + idiv(q.hunger, 25);
    if (q.clearedDay >= 0 && V.day - q.clearedDay < 3 * YEAR) s -= 120; // wrongly punished once: the village is ashamed
    if (c.victim >= 0 && opinion(V, q.id, c.victim) <= -50) s += 90; // known to hate the dead
    s += key(key(V.base, c.id * 7 + pid), q.id) % 15;
    if (s > best) { best = s; who = q.id; }
  }
  // a household's prejudice is one source, however many of them share it (it is not independent evidence)
  if (who >= 0) giveBelief(V, pid, c.id, who, 250 + best * 3, PREJUDICE_ORIGIN + p.household, 3, -1);
}

export function giveBelief(V, pid, crime, culprit, strength, origin, via, from) {
  const p = V.people[pid];
  const have = p.beliefs.find((b) => b.crime === crime && b.culprit === culprit && b.origin === origin);
  if (have) { have.strength = clamp(Math.max(have.strength, strength), 0, 1000); return have; }
  const b = { crime, culprit, strength: clamp(strength, 0, 1000), origin, via, from, day: V.day };
  p.beliefs.push(b);
  if (p.beliefs.length > MAX_BELIEFS) {
    let w = 0;
    for (let i = 1; i < p.beliefs.length; i++) if (p.beliefs[i].strength < p.beliefs[w].strength) w = i;
    p.beliefs.splice(w, 1);
  }
  return b;
}

// ---------- gossip: knowledge travels where people are together ----------
const SOCIAL = [[720, 780], [1080, 1260], [540, 660]]; // meals, evenings, the holy-day service
export function gossip(V) {
  const gk = key(key(V.base, P.GOSSIP), V.day);
  for (const [from, to] of SOCIAL) {
    const groups = new Map();
    for (const p of V.people) {
      if (!p.alive || !p.present || p.locked || ageOf(V, p) < 12) continue;
      const at = placeAt(p, from + 10);
      if (!at || placeAt(p, to - 10) !== at) continue;
      if (!groups.has(at)) groups.set(at, []);
      groups.get(at).push(p.id);
    }
    const places = [...groups.keys()].sort();
    for (const place of places) {
      const ids = groups.get(place);
      for (let i = 0; i < ids.length; i++) {
        for (let j = 0; j < ids.length; j++) {
          if (i === j) continue;
          const k = key(gk, ids[i] * 4099 + ids[j] + from);
          tell(V, ids[i], ids[j], k);
          mingle(V, ids[i], ids[j], key(k, 77));
        }
      }
    }
  }
}

// Everyday friction and warmth (RimWorld's chitchat and slights): the hot-tempered give offence, the
// sociable make friends. Each is small; over years they add up to friendships and enmities, and an old
// dislike makes the next slight likelier (so enmities deepen unless time heals them).
function mingle(V, a, b, k) {
  const sp = V.people[a], ls = V.people[b];
  const slight = sp.traits[C.TEMPER] * 60 + Math.max(0, -opinion(V, a, b)) * 450 - sp.traits[C.COMPASSION] * 20;
  if (slight > 0 && chance(k, slight * V.pace)) { setOpinion(V, b, a, opinion(V, b, a) - 4 - idiv(ls.traits[C.TEMPER], 12)); return; }
  if (chance(key(k, 1), (20000 + sp.traits[C.SOCIABLE] * 300) * V.pace)) setOpinion(V, b, a, opinion(V, b, a) + 2);
}

function tell(V, a, b, k) {
  const sp = V.people[a], ls = V.people[b];
  if (!sp.beliefs.length) return;
  if (!chance(k, 250000 + sp.traits[C.SOCIABLE] * 5000)) return;
  // the speaker's strongest belief the listener has not heard (old news about settled cases is not told)
  let best = null;
  for (const bf of sp.beliefs) {
    const cr = V.crimes[bf.crime];
    if (bf.culprit === b || cr.closed || (!cr.caseOpen && V.day - cr.day > 30)) continue; // cold or settled: not told
    if (ls.beliefs.some((x) => x.crime === bf.crime && x.culprit === bf.culprit && x.origin === bf.origin)) continue;
    if (!best || bf.strength > best.strength) best = bf;
  }
  if (!best) return;
  const trust = clamp(500 + opinion(V, b, a) * 4, 100, 900);
  const heardBefore = ls.beliefs.some((x) => x.crime === best.crime);
  let culprit = best.culprit, origin = best.origin, via = 1;
  // bent by dislike: sometimes the listener hears what they already wanted to believe
  const crime = V.crimes[best.crime];
  let enemy = -1, worst = -40;
  for (const [o, v] of ls.rel) if (v < worst && V.people[o].alive && V.people[o].present && o !== a && o !== b) { worst = v; enemy = o; }
  if (enemy >= 0 && crime.act !== "sorcery" && !heardBefore && chance(key(k, 3), 45000)) { culprit = enemy; origin = b; via = 3; }
  const nb = giveBelief(V, b, best.crime, culprit, idiv(best.strength * trust, 1000), origin, via, a);
  best.strength = clamp(best.strength + 15, 0, 1000); // retelling strengthens the teller's own belief
  // only what reaches the wronged household or the elder is kept in the chronicle (the tales follow it)
  const wronged = crime.household >= 0 && ls.household === crime.household;
  if ((wronged || b === V.authority) && !heardBefore) {
    nb.event = logEvent(V, "rumour", a, b, { crime: best.crime, culprit, via }, [best.event ?? crime.event], `${nameOf(V, a)} whispering to ${nameOf(V, b)}`);
  }
}

// ---------- cases: two independent sources make an accusation ----------
export function checkCases(V) {
  for (const c of V.crimes) {
    if (c.closed || !c.discovered || c.caseOpen) continue;
    // who may accuse: the wronged household (and the elder); for witchcraft, anyone
    const accusers = c.household >= 0 && c.act !== "sorcery"
      ? [...V.households[c.household].members.filter((m) => V.people[m].alive && V.people[m].present && ageOf(V, V.people[m]) >= 14), V.authority].filter((x) => x >= 0)
      : living(V).filter((q) => ageOf(V, q) >= 16).map((q) => q.id);
    let pickAcc = -1, pickCul = -1, pickStr = 0, pickEv = [];
    for (const acc of accusers) {
      const by = new Map();
      for (const bf of V.people[acc].beliefs) {
        if (bf.crime !== c.id || bf.culprit === acc) continue;
        if (!by.has(bf.culprit)) by.set(bf.culprit, new Map());
        const m = by.get(bf.culprit);
        m.set(bf.origin, Math.max(m.get(bf.origin) ?? 0, bf.strength));
      }
      for (const [cul, origins] of by) {
        if (origins.size < 2) continue;
        const total = [...origins.values()].reduce((s, v) => s + v, 0);
        if (total < 600) continue;
        if (total > pickStr || (total === pickStr && cul < pickCul)) {
          pickStr = total; pickAcc = acc; pickCul = cul;
          pickEv = V.people[acc].beliefs.filter((bf) => bf.crime === c.id && bf.culprit === cul && bf.event !== undefined).map((bf) => bf.event);
        }
      }
    }
    if (pickAcc < 0 || !V.people[pickCul].alive || !V.people[pickCul].present) continue;
    c.caseOpen = true;
    V.stats.cases++;
    const causes = [c.discoveryEvent ?? c.event, ...pickEv.slice(0, 4)];
    const ev = logEvent(V, "accusation", pickAcc, pickCul, { crime: c.id, act: c.act, evidence: pickStr, wrongful: pickCul !== c.culprit || c.falseAccusation },
      causes, `${nameOf(V, pickAcc)} pointing at ${nameOf(V, pickCul)} in the square`);
    const cs = { id: V.cases.length, crime: c.id, accuser: pickAcc, accused: pickCul, evidence: pickStr, event: ev, day: V.day };
    V.cases.push(cs);
    // the elder tries it, unless the village no longer listens to the elder and the crowd is hot
    const anger = idiv(V.fear, 2) + idiv(V.hardship, 3) + C.ACTS[c.act].severity * 90;
    const cap = authorityCapacity(V);
    if (lethalAllowed(V) && cap < 420 && anger > cap + 250) scheduleMob(V, cs);
    else scheduleTrial(V, cs);
  }
}

export { TRACE_ORIGIN };
