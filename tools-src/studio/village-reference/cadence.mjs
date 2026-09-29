// What a player near one village would see per hour of play (a game day is 12 real minutes, so an hour is 5
// game days): the chronicle's pace, the live pace, and the live pace in the player's own village (the
// director paces it by play time). Usage: node cadence.mjs [seeds=20] [years=10]
import { createVillage, run, YEAR } from "./village.mjs";
import * as C from "./content.mjs";

const seeds = Number(process.argv[2] ?? 20), years = Number(process.argv[3] ?? 10);
const DAYS_PER_HOUR = 5;
for (const [pace, focus] of [[1, false], [C.LIVE_PACE, false], [C.LIVE_PACE, true]]) {
  const n = {};
  for (let s = 0; s < seeds; s++) {
    const V = createVillage(9000 + s * 7919, { pace, focus });
    run(V, years * YEAR);
    for (const e of V.events) {
      let k = null;
      if (e.type === "public_act") k = ["hanging", "bonfire", "stoning", "mob", "trial_by_combat"].includes(e.data.kind) ? "grave public act (hanging, burning, mob)" : "public act (fine, pillory, brand, exile)";
      else if (e.type === "crime" && e.data.act !== "poaching") k = "crime (not poaching)";
      else if (["accusation", "festival", "wedding", "funeral", "omen", "rite", "trial"].includes(e.type)) k = e.type;
      else if (e.type === "arrival" && e.data.lodger) k = "incident: a lodger";
      else if (e.type === "famine" && e.data.blight) k = "incident: blight";
      else if (e.type === "rivalry" && e.data.motive === "land") k = "incident: a boundary quarrel";
      if (k) n[k] = (n[k] ?? 0) + 1;
    }
  }
  const hours = seeds * years * YEAR / DAYS_PER_HOUR;
  console.log(`pace ${pace}${focus ? ", the player's village (focus)" : ""}: per hour of play near one village (${seeds} villages x ${years} years)`);
  for (const [k, v] of Object.entries(n).sort((a, b) => b[1] - a[1])) console.log(`  ${k.padEnd(42)} ${(v / hours).toFixed(3)}  (one every ${(hours / v).toFixed(1)} h)`);
}
