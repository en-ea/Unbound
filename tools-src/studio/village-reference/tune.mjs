// Tuning report: many seeds, rates per village-century against the design's targets.
// Usage: node tune.mjs [seeds=20] [years=200]
import { createVillage, run, YEAR } from "./village.mjs";

const seeds = Number(process.argv[2] ?? 20), years = Number(process.argv[3] ?? 200);
const TARGET = {
  "crime:theft": [15, 30], "crime:assault": [8, 20], "crime:murder": [1, 3], "crime:sorcery": [3, 10],
  "act:fine": [10, 25], "act:pillory": [5, 12], "act:exile": [3, 8], "act:branding": [2, 5], "act:hanging": [1, 2.5],
  "act:bonfire": [0.5, 1.5], "act:mob": [0.3, 1], "act:trial_by_combat": [0.2, 0.6],
  "end:crowd_turned": [1, 3], "end:rescued": [0.3, 1], "exonerations": [1, 3], "feuds": [0.5, 2],
};
const sum = {};
const add = (k, n = 1) => { sum[k] = (sum[k] ?? 0) + n; };
for (let s = 0; s < seeds; s++) {
  const V = createVillage(1000 + s * 7919);
  run(V, years * YEAR);
  for (const c of V.crimes) add("crime:" + c.act);
  for (const e of V.events) {
    if (e.type === "public_act") { add("act:" + e.data.kind); add("end:" + e.data.outcome); }
    if (e.type === "exoneration") add("exonerations");
    if (e.type === "ordeal" && e.data.combat) add("act:trial_by_combat");
    if (e.type === "feud") add("feuds");
    if (e.type === "violent_death") add("violent_deaths");
  }
  for (const cs of V.cases) { const c = V.crimes[cs.crime]; add(cs.accused === c.culprit && !c.falseAccusation ? "cases:right" : "cases:wrongful"); }
}
const per = (k) => (sum[k] ?? 0) * 100 / (seeds * years);
const keys = [...new Set([...Object.keys(TARGET), ...Object.keys(sum)])].sort();
for (const k of keys) {
  const t = TARGET[k], v = per(k);
  const mark = !t ? "" : v < t[0] ? "  LOW" : v > t[1] ? "  HIGH" : "  ok";
  console.log(`${k.padEnd(22)} ${v.toFixed(2).padStart(7)} per village-century${t ? ` (target ${t[0]}-${t[1]})` : ""}${mark}`);
}
