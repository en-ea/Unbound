// Runs villages headless and reports: speed, what happened, the invariants, and sample stagings.
// Usage: node run.mjs [years=200] [seeds=4]
import { createVillage, run, YEAR, hashVillage, living } from "./village.mjs";
import { NOTABLE, causeChain } from "./events.mjs";
import { performance } from "node:perf_hooks";

const years = Number(process.argv[2] ?? 200);
const seeds = Number(process.argv[3] ?? 4);
const all = { acts: {}, outcomes: {} };
for (let s = 0; s < seeds; s++) {
  const seed = 1000 + s * 7919;
  const t0 = performance.now();
  const V = createVillage(seed);
  run(V, years * YEAR);
  const ms = performance.now() - t0;
  const st = V.stats;
  for (const [k, v] of Object.entries(st.acts)) all.acts[k] = (all.acts[k] ?? 0) + v;
  for (const [k, v] of Object.entries(st.outcomes)) all.outcomes[k] = (all.outcomes[k] ?? 0) + v;
  // invariants
  let notable = 0, noCause = 0, noCue = 0;
  for (const e of V.events) {
    if (!NOTABLE.has(e.type)) continue;
    notable++;
    if (!e.causes.length && !e.data.motive && !["omen", "storm", "feud"].includes(e.type)) noCause++;
    if (!e.cue) noCue++;
  }
  console.log(`seed ${seed}: ${years} years in ${ms.toFixed(0)} ms (${(ms / years).toFixed(2)} ms/year); alive ${living(V).length}, people ever ${V.people.length}, hash ${hashVillage(V)}`);
  console.log(`  crimes ${st.crimes}, cases ${st.cases}, trials ${st.trials}, mobs ${st.mobs}, deaths ${st.deaths} (violent ${st.violentDeaths}), births ${st.births}, famines ${st.famines}, omens ${st.omens}, festivals ${st.festivals}, exonerations ${st.exonerations}`);
  console.log(`  acts ${JSON.stringify(st.acts)} outcomes ${JSON.stringify(st.outcomes)}`);
  console.log(`  notable events ${notable}: without a cause ${noCause}, without a cue ${noCue}; events total ${V.events.length}; stagings ${V.stagingCount}`);
}
console.log(`ALL acts ${JSON.stringify(all.acts)}`);
console.log(`ALL outcomes ${JSON.stringify(all.outcomes)}`);
const tot = Object.values(all.outcomes).reduce((a, b) => a + b, 0);
console.log("ending shares: " + Object.entries(all.outcomes).map(([k, v]) => `${k} ${Math.round(100 * v / tot)}%`).join(", "));
