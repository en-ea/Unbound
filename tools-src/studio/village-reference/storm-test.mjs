// Storm scenarios: a storm folds one household back to its ancestors for a season, in many villages; checks
// what the forebears do and that the rules hold. Usage: node storm-test.mjs [seeds=20] [pace=10]
import { createVillage, stepDay, hashVillage, ageOf, YEAR } from "./village.mjs";
import { NOTABLE } from "./events.mjs";
import * as C from "./content.mjs";

const seeds = Number(process.argv[2] ?? 20), pace = Number(process.argv[3] ?? C.LIVE_PACE);
const tally = {};
const add = (k, n = 1) => { tally[k] = (tally[k] ?? 0) + n; };
const fail = [];
const runOne = (seed, anchored = false) => {
  const V = createVillage(seed, { pace, anchored, stormPlan: [{ day: 90, household: seed % 6, days: 120 }] });
  for (let d = 0; d < 4 * YEAR; d++) stepDay(V);
  return V;
};
for (let s = 0; s < seeds; s++) {
  const seed = 3000 + s * 7919;
  const V = runOne(seed);
  // determinism: the same seed twice gives the same world
  if (hashVillage(runOne(seed)) !== hashVillage(V)) fail.push(`seed ${seed}: two runs differ`);
  const st = V.storms[0];
  if (!st) { fail.push(`seed ${seed}: no storm`); continue; }
  add("storms"); add("ancestors", st.ancestors.length); add("lost", st.lost.length);
  for (const e of V.events) {
    if (e.type === "rite") add("rite:" + (e.data.outcome ?? e.data.rite));
    if (e.type === "rite" && e.data.heart) add("rite:heart");
    if (e.type === "accusation" && V.people[e.other].ancestor !== undefined) add("ancestors accused");
    if (e.type === "accusation" && V.people[e.who].ancestor !== undefined) add("ancestors accusing");
    if (e.type === "public_act" && V.people[e.who].ancestor !== undefined) add("ancestors punished:" + e.data.kind);
    if (e.type === "crime" && V.people[e.who].ancestor !== undefined) add("ancestor crimes:" + e.data.act);
    if (e.type === "crime" && e.data.act === "sorcery" && V.people[e.who].ancestor !== undefined) add("ancestors called witches");
    if (NOTABLE.has(e.type) && !e.cue) fail.push(`seed ${seed}: ${e.type} without a cue`);
    // never a child as an offering
    if (e.type === "rite" && e.data.rite === "seized" && ageOf(V, V.people[e.other]) < 16) fail.push(`seed ${seed}: a child seized`);
  }
  // after the storm: no forebear present, every living lost one home
  for (const id of st.ancestors) if (V.people[id].alive && V.people[id].present) fail.push(`seed ${seed}: ancestor ${id} still present`);
  for (const id of st.lost) if (V.people[id].alive && !V.people[id].present && !V.outlaws.includes(id)) fail.push(`seed ${seed}: lost ${id} not home`);
  // an anchored village is never touched
  const A = runOne(seed, true);
  if (A.storms.length) fail.push(`seed ${seed}: anchored village struck`);
}
console.log(Object.entries(tally).sort().map(([k, v]) => `${k.padEnd(34)} ${v}`).join("\n"));
console.log(fail.length ? "FAIL\n" + fail.slice(0, 20).join("\n") : `PASS: ${seeds} villages, determinism, no child offerings, recede, anchored exempt`);
if (fail.length) process.exitCode = 1;
