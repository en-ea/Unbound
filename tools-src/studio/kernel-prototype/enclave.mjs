// S1b - time-storm enclaves. A storm turns part of a village into its own past; does the past
// turn on the present? Nothing here scripts conflict: it has to come from the ordinary rules.
// Usage: node enclave.mjs   (writes enclave-results.txt beside this file)
import { runHistory, resume, describe } from "./sim.mjs";
import { writeFileSync } from "node:fs";

const STORM = 500, AFTER = 25;
const out = [];
const say = (s = "") => { out.push(s); console.log(s); };
const seeds = Array.from({ length: 20 }, (_, i) => 1000 + i * 7919);
const pct = (n, d) => (d ? `${Math.round((100 * n) / d)}%` : "-");

say(`S1b - time-storm enclaves, ${new Date().toISOString()}`);
say(`A storm at year ${STORM} folds a share of one village into year ${STORM} - gap; we watch ${AFTER} years.`);
say();

const rows = [];
let story = null;
for (const gap of [40, 150, 300]) {
  for (const share of [0.3, 0.6]) {
    const agg = { trials: 0, enclaveRaids: 0, originRaids: 0, anyRaid: 0, enclaveRuined: 0, originRuined: 0, taught: 0, originLoss: [] };
    for (const seed of seeds) {
      const run = runHistory(seed, STORM);
      const pastYear = STORM - gap;
      const then = resume(seed, run.checkpoints.get(Math.floor(pastYear / 25) * 25), pastYear);
      // the largest village that already existed back then
      const origin = run.world.settlements
        .filter((s) => s.pop >= 60 && then.settlements[s.id] && then.settlements[s.id].pop > 0)
        .sort((a, b) => b.pop - a.pop || a.id - b.id)[0];
      if (!origin) continue;
      const p = then.settlements[origin.id];
      const iv = [{ year: STORM, kind: "storm-enclave", target: origin.id, share, past: { year: pastYear, pop: p.pop, tech: p.tech, food: p.food, rel: p.rel }, player: "storm", seq: 1 }];
      const withStorm = runHistory(seed, STORM + AFTER, iv).world;
      const without = runHistory(seed, STORM + AFTER).world;
      const enclave = withStorm.settlements.find((s) => s.enclaveOf === origin.id);
      const after = withStorm.events.filter((e) => e.year >= STORM);
      const eRaids = after.filter((e) => e.type === "raid" && e.id === enclave.id && e.other === origin.id).length;
      const oRaids = after.filter((e) => e.type === "raid" && e.id === origin.id && e.other === enclave.id).length;
      const taught = after.filter((e) => e.type === "learned" && e.other === enclave.id).length;
      agg.trials++;
      if (eRaids) agg.enclaveRaids++;
      if (oRaids) agg.originRaids++;
      if (eRaids || oRaids) agg.anyRaid++;
      if (enclave.pop <= 0) agg.enclaveRuined++;
      if (withStorm.settlements[origin.id].pop <= 0) agg.originRuined++;
      if (taught) agg.taught++;
      const base = without.settlements[origin.id].pop;
      agg.originLoss.push(base ? (base - withStorm.settlements[origin.id].pop) / base : 0);
      if (!story && eRaids && gap >= 150) story = { seed, gap, share, origin: origin.id, enclave: enclave.id, w: withStorm };
    }
    const loss = agg.originLoss.sort((a, b) => a - b)[Math.floor(agg.originLoss.length / 2)] ?? 0;
    rows.push({ gap, share, ...agg, loss });
  }
}

say("gap (yrs) | share | trials | past raids present | present raids past | any fighting | past taught others | enclave ruined | origin ruined | origin smaller than without storm (median)");
for (const r of rows) {
  say(`${String(r.gap).padStart(9)} | ${r.share.toFixed(1).padStart(5)} | ${String(r.trials).padStart(6)} | ${pct(r.enclaveRaids, r.trials).padStart(18)} | ${pct(r.originRaids, r.trials).padStart(18)} | ${pct(r.anyRaid, r.trials).padStart(12)} | ${pct(r.taught, r.trials).padStart(18)} | ${pct(r.enclaveRuined, r.trials).padStart(14)} | ${pct(r.originRuined, r.trials).padStart(13)} | ${(100 * r.loss).toFixed(0)}%`);
}

if (story) {
  say();
  const { w, origin, enclave } = story;
  say(`One storm, told by the chronicle (seed ${story.seed}, ${story.gap} years back, ${Math.round(story.share * 100)}% of the village):`);
  w.events
    .filter((e) => e.year >= STORM && (e.id === origin || e.id === enclave) && !["drought", "hunger"].includes(e.type))
    .slice(0, 14)
    .forEach((e) => say(`   yr ${e.year}  ${e.text}`));
  say(`   ... year ${STORM + AFTER}: ${describe(w.settlements[origin])} | ${describe(w.settlements[enclave])}`);
}

writeFileSync(new URL("./enclave-results.txt", import.meta.url), out.join("\n") + "\n");
