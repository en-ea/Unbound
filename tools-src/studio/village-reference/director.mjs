// The pacing director (RimWorld's storyteller): the village alternates quiet and eventful cycles of keyed
// length. Blood is rationed (at most one lethal public act per eventful cycle, and a cooldown after any
// killing); quiet cycles carry festivals; omens arrive rarely, likelier in hard times, and raise the fear
// that finds scapegoats. The director never forces an act: it only permits, withholds and paces.
import { key, pick, chance, clamp, idiv } from "./rng.mjs";
import * as C from "./content.mjs";
import { logEvent } from "./events.mjs";
import { P, YEAR } from "./village.mjs";

const FEASTS = { 22: "Midsummer", 44: "Harvest Home", 57: "Midwinter" };

export function directorDay(V) {
  const d = V.director;
  const k = key(key(V.base, P.CYCLE), V.day);
  if (V.day >= d.until) {
    d.on = !d.on;
    d.until = V.day + (d.on ? 12 + pick(k, 10) : 25 + pick(key(k, 1), 20));
    d.lethal = 0;
    d.cycles++;
  }
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

export const lethalAllowed = (V) => V.director.on && V.director.lethal < 1 && V.day >= V.director.cooldown;

export function noteAct(V, kind) {
  const d = V.director;
  d.last.push(kind);
  if (d.last.length > 5) d.last.shift();
  if (C.PUBLIC[kind]?.lethal) { d.lethal++; d.cooldown = V.day + 15; }
}
