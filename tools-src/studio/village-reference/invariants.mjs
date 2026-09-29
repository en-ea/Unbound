// Long-run invariants: many villages for a long time (with a storm now and then), checking the rules that
// must never break. Usage: node invariants.mjs [seeds=20] [years=1000] [pace=1]
import { createVillage, stepDay, hashVillage, ageOf, YEAR } from "./village.mjs";
import { NOTABLE } from "./events.mjs";
import { performance } from "node:perf_hooks";

const seeds = Number(process.argv[2] ?? 20), years = Number(process.argv[3] ?? 1000), pace = Number(process.argv[4] ?? 1);
const EXEMPT = new Set(["omen", "storm", "feud"]); // things that simply happen (the kernel's, the sky's, the grudge's sum)
const fails = [];
const F = (seed, msg) => { if (fails.length < 40) fails.push(`seed ${seed}: ${msg}`); };
let totalMs = 0, minAlive = 1e9, maxAlive = 0, events = 0;
const village = (seed) => {
  // a storm every century or so, on a keyed household, for a season
  const stormPlan = [];
  for (let y = 50; y < years; y += 97) stormPlan.push({ day: y * YEAR + 20, household: (seed + y) % 6, days: 90 });
  return createVillage(seed, { pace, stormPlan });
};
for (let s = 0; s < seeds; s++) {
  const seed = 5000 + s * 7919;
  const t0 = performance.now();
  const V = village(seed);
  for (let d = 0; d < years * YEAR; d++) {
    stepDay(V);
    if (d % YEAR === 0) {
      const alive = V.people.filter((p) => p.alive && p.present).length;
      minAlive = Math.min(minAlive, alive); maxAlive = Math.max(maxAlive, alive);
      if (alive < 6) F(seed, `year ${d / YEAR}: only ${alive} alive`);
      for (const p of V.people) if (p.alive && (!Number.isInteger(p.stress) || !Number.isInteger(p.hunger) || !Number.isInteger(p.guilt))) F(seed, `person ${p.id} has a non-integer state`);
      for (const h of V.households) if (!Number.isInteger(h.food)) F(seed, `household ${h.id} food ${h.food}`);
      for (const c of V.cases) if (V.crimes[c.crime].caseOpen && !V.crimes[c.crime].closed && V.day - c.day > 120) F(seed, `case ${c.id} (${V.crimes[c.crime].act}) open for ${V.day - c.day} days`);
      const open = V.crimes.filter((c) => !c.closed).length;
      if (open > 60) F(seed, `year ${d / YEAR}: ${open} crimes open`);
    }
  }
  totalMs += performance.now() - t0;
  events += V.events.length;
  for (const e of V.events) {
    if (!NOTABLE.has(e.type)) continue;
    if (!e.cue) F(seed, `${e.type} ${e.id} without a cue`);
    if (!e.causes.length && !e.data.motive && !EXEMPT.has(e.type)) F(seed, `${e.type} ${e.id} (day ${e.day}) without a cause`);
    if (e.type === "crime" && ["murder", "sacrifice"].includes(e.data.act) && e.other >= 0 && ageOf(V, V.people[e.other]) < 16 && V.people[e.other].died === e.day) F(seed, `a child killed (${e.data.act})`);
  }
  // the violence budget: a lethal public act (or rite) sets a 15-day cooldown, so no two fall closer
  let lastLethal = -1e9;
  for (const e of V.events) {
    const lethal = (e.type === "public_act" && ["hanging", "bonfire", "stoning", "mob", "sacrifice"].includes(e.data.kind) && e.data.outcome === "carried_out")
      || (e.type === "rite" && e.data.outcome === "carried_out");
    if (!lethal) continue;
    if (e.day - lastLethal < 15) F(seed, `two lethal public acts ${e.day - lastLethal} days apart (day ${e.day})`);
    lastLethal = e.day;
  }
  for (const st of V.stagings) for (const b of st.beats) if (b.do === "throw") {
    const p = V.people[b.who];
    if (p.born > st.day * 1 - 14 * YEAR) F(seed, `a child threw (${st.kind}, day ${st.day})`);
  }
  for (const c of V.crimes) if (c.act === "sacrifice" && ageOf(V, V.people[c.victim]) < 16) F(seed, "a child offered");
}
// determinism: one village twice
const a = village(5000), b = village(5000);
for (let d = 0; d < 100 * YEAR; d++) { stepDay(a); stepDay(b); }
if (hashVillage(a) !== hashVillage(b)) F(5000, "two runs of one seed differ");
console.log(`${seeds} villages x ${years} years (pace ${pace}): ${(totalMs / seeds / years).toFixed(2)} ms per village-year; alive ${minAlive}-${maxAlive}; ${events} events`);
console.log(fails.length ? "FAIL\n" + fails.join("\n") : "PASS: causes and cues, no child victims or throwers, integer state, no stuck cases, population, violence budget, determinism");
