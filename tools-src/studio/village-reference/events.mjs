// The village's memory: every notable thing that happens is an event with its causes (earlier event ids)
// and a cue (what someone standing there would see or hear). The cause links are what the tests check
// ("every notable act has a reason") and what the tales follow; the cues are "show, don't read".
import { key } from "./rng.mjs";

// Types that must carry a cause chain and a cue (the invariants check these).
export const NOTABLE = new Set([
  "crime", "accusation", "trial", "verdict", "public_act", "mob", "exile", "exoneration", "veneration",
  "omen", "storm", "violent_death", "confession", "crowd_turned", "feud", "return", "rite",
]);

export function logEvent(V, type, who, other, data, causes, cue) {
  const e = { id: V.events.length, day: V.day, type, who, other, data: data ?? {}, causes: causes ?? [], cue: cue ?? "" };
  V.events.push(e);
  let h = V.evHash;
  h = key(h, e.day); h = key(h, e.id); h = key(h, TYPE_CODE[type] ?? 99); h = key(h, who); h = key(h, other);
  for (const c of e.causes) h = key(h, c);
  V.evHash = h;
  return e.id;
}

// A stable numeric code per type (for hashing; append only).
const TYPE_LIST = ["birth", "death", "marriage", "crime", "sighting", "rumour", "accusation", "trial", "confession",
  "ordeal", "verdict", "public_act", "crowd_turned", "mob", "exile", "return", "exoneration", "veneration",
  "festival", "omen", "famine", "feud", "storm", "epithet", "violent_death", "funeral", "rite", "wedding",
  "arrival", "discovery", "harvest", "rivalry"];
const TYPE_CODE = Object.fromEntries(TYPE_LIST.map((t, i) => [t, i]));

// Walks the cause links back from an event (breadth first, oldest last); used by tests and tales.
export function causeChain(V, id, limit = 40) {
  const seen = new Set([id]);
  const out = [];
  const queue = [id];
  while (queue.length && out.length < limit) {
    const cur = queue.shift();
    out.push(cur);
    for (const c of V.events[cur].causes) if (!seen.has(c)) { seen.add(c); queue.push(c); }
  }
  return out;
}

// A person's name with their epithets (the latest earned), and their lineage.
export function fullName(V, id) {
  if (id < 0 || id >= V.people.length) return "someone";
  const p = V.people[id];
  const ep = p.epithets.length ? " " + p.epithets[p.epithets.length - 1] : "";
  return p.name + ep;
}
export function nameOf(V, id) {
  return id >= 0 && id < V.people.length ? V.people[id].name : "someone";
}
