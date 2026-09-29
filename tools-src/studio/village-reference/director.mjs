// The pacing director (RimWorld's storyteller): the village alternates quiet and eventful cycles of keyed
// length. Blood is rationed (at most one lethal public act per eventful cycle, and a cooldown after any
// killing); quiet cycles carry festivals; omens arrive rarely, likelier in hard times, and raise the fear
// that finds scapegoats. The director never forces an act: it only permits, withholds and paces.
import { key, pick, chance, clamp, idiv } from "./rng.mjs";
import * as C from "./content.mjs";
import { logEvent } from "./events.mjs";
import { P, YEAR, addPerson, ageOf, opinion, setOpinion } from "./village.mjs";
import { remember } from "./justice.mjs";

const FEASTS = { 22: "Midsummer", 44: "Harvest Home", 57: "Midwinter" };

export function directorDay(V) {
  const d = V.director;
  const k = key(key(V.base, P.CYCLE), V.day);
  if (V.day >= d.until) {
    d.on = !d.on;
    // (the village the player is in rests less between its eventful stretches)
    d.until = V.day + (d.on ? 12 + pick(k, 10) : V.focus ? 6 + pick(key(k, 1), 6) : 25 + pick(key(k, 1), 20));
    d.lethal = 0;
    d.cycles++;
  }
  if (V.focus) focusDay(V, k);
  const doy = V.day % YEAR;
  if (FEASTS[doy]) V.schedule.push({ day: V.day, kind: "festival", name: FEASTS[doy], who: -1, other: -1, causes: [] });
  // omens: rare; hardship makes them likelier (a hungry village reads signs everywhere)
  if (chance(key(k, 2), (900 + idiv(V.hardship, 2) * 8) * V.pace)) {
    const omen = C.OMENS[pick(key(k, 3), C.OMENS.length)];
    V.fear = clamp(V.fear + 460, 0, 1000);
    V.stats.omens++;
    V.omenEvent = logEvent(V, "omen", -1, -1, { omen }, [], omen);
  }
}

// The player's village, paced by play time (a game day is 12 real minutes: an hour is 5 days). When nothing
// public has happened for longer than the target, pressure builds and the director sends an incident: a real
// event with consequences the tales can cite, never an act forced on anyone. People still decide.
const FOCUS_GAP = 5; // game days without a public act before pressure builds (about an hour of play)
function focusDay(V, k) {
  const d = V.director;
  if (V.day - d.lastAct <= FOCUS_GAP) { d.pressure = 0; return; }
  d.pressure++;
  if (!chance(key(k, 50), d.pressure * 60000)) return;
  d.pressure = 0;
  const which = pick(key(k, 51), 4);
  if (which === 0) { // an omen
    const omen = C.OMENS[pick(key(k, 3), C.OMENS.length)];
    V.fear = clamp(V.fear + 460, 0, 1000);
    V.stats.omens++;
    V.omenEvent = logEvent(V, "omen", -1, -1, { omen }, [], omen);
  } else if (which === 1) { // blight: a hard season
    V.hardship = clamp(V.hardship + 250, 0, 1000);
    for (const h of V.households) h.food = Math.max(0, h.food - 12);
    logEvent(V, "famine", -1, -1, { year: idiv(V.day, YEAR), blight: true }, [], "black spots on the leaves, and the field half lost in a week");
  } else if (which === 2) { // a lodger: a stranger taken in by the poorest house (outsiders draw suspicion, and some deserve it)
    let poor = -1;
    for (const h of V.households) if (h.members.some((m) => V.people[m].alive && V.people[m].present) && (poor < 0 || h.food < V.households[poor].food)) poor = h.id;
    if (poor < 0) return;
    const id = addPerson(V, poor, pick(key(k, 52), 2), 20 + pick(key(k, 53), 25), -1, -1, { quiet: true });
    const p = V.people[id];
    p.outsider = true; p.role = "beggar";
    p.traits[C.GREED] = clamp(p.traits[C.GREED] + 25, 0, 100); p.traits[C.HONESTY] = clamp(p.traits[C.HONESTY] - 20, 0, 100);
    logEvent(V, "arrival", id, -1, { lodger: true, household: poor }, [], `a stranger with a pack at the ${V.households[poor].home} house, taken in for the price of the work`);
  } else { // a quarrel: a boundary stone moved in the night between two houses
    const heads = V.households.map((h) => h.members.find((m) => V.people[m].alive && V.people[m].present && ageOf(V, V.people[m]) >= 18)).filter((m) => m !== undefined);
    if (heads.length < 2) return;
    const a = heads[pick(key(k, 54), heads.length)];
    let b = heads[pick(key(k, 55), heads.length)];
    if (a === b) b = heads[(heads.indexOf(a) + 1) % heads.length];
    const ev = logEvent(V, "rivalry", a, b, { motive: "land" }, [], `a boundary stone moved in the night between the ${V.households[V.people[a].household].home} and ${V.households[V.people[b].household].home} fields`);
    setOpinion(V, a, b, opinion(V, a, b) - 40); remember(V.people[a], b, ev);
    setOpinion(V, b, a, opinion(V, b, a) - 40); remember(V.people[b], a, ev);
  }
}

export const lethalAllowed = (V) => V.director.on && V.director.lethal < 1 && V.day >= V.director.cooldown;

export function noteAct(V, kind) {
  const d = V.director;
  d.lastAct = V.day;
  d.last.push(kind);
  if (d.last.length > 5) d.last.shift();
  if (C.PUBLIC[kind]?.lethal) { d.lethal++; d.cooldown = V.day + 15; }
}
