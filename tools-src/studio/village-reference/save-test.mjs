// Save-load-save: a village saved and loaded mid-run must end exactly where an unbroken run ends, and a
// save of the loaded village must equal the original save. Usage: node save-test.mjs [seeds=10] [years=6]
import { createVillage, stepDay, hashVillage, YEAR } from "./village.mjs";
import { saveVillage, loadVillage } from "./save.mjs";
import * as C from "./content.mjs";

const seeds = Number(process.argv[2] ?? 10), years = Number(process.argv[3] ?? 6);
const fails = [];
let bytes = 0;
for (let s = 0; s < seeds; s++) {
  const seed = 7000 + s * 7919;
  const opts = { pace: s % 2 ? C.LIVE_PACE : 1, stormPlan: [{ day: 100, household: s % 6, days: 60 }] };
  const A = createVillage(seed, opts);
  for (let d = 0; d < years * YEAR; d++) stepDay(A);
  let B = createVillage(seed, opts);
  for (let d = 0; d < years * YEAR; d++) {
    if (d % 97 === 50) {
      const saved = saveVillage(B);
      B = loadVillage(saved);
      if (saveVillage(B) !== saved) fails.push(`seed ${seed} day ${d}: save of the loaded village differs`);
      bytes = Math.max(bytes, saved.length);
    }
    stepDay(B);
  }
  if (hashVillage(A) !== hashVillage(B) || A.evHash !== B.evHash) fails.push(`seed ${seed}: a saved and loaded run ends elsewhere (${hashVillage(A)} vs ${hashVillage(B)})`);
}
console.log(`largest save ${(bytes / 1024).toFixed(0)} KB (${years} years)`);
console.log(fails.length ? "FAIL\n" + fails.join("\n") : `PASS: ${seeds} villages saved and loaded ${Math.floor(years * YEAR / 97)} times each end where unbroken runs end; save(load(save)) = save`);
if (fails.length) process.exitCode = 1;
