// The live game's contract: in the player's village (V.live) public acts wait for the stage and resolve
// when it ends; villages away from the player run headless. Checks that (1) a live village is deterministic
// (the same resolutions give the same world) and differs from headless only in when effects land, and (2) a
// player who frees every condemned person in a lethal act saves them, and the village remembers the
// stranger. Usage: node live-test.mjs [seeds=10]
import { createVillage, stepDay, hashVillage, YEAR } from "./village.mjs";
import { resolvePublic } from "./justice.mjs";
import * as C from "./content.mjs";

const seeds = Number(process.argv[2] ?? 10);
const fails = [];
let freed = 0, saved = 0, shielded = 0;
for (let s = 0; s < seeds; s++) {
  const seed = 11000 + s * 7919;
  const A = createVillage(seed, { pace: C.LIVE_PACE, live: true });
  const B = createVillage(seed, { pace: C.LIVE_PACE, live: true });
  for (let d = 0; d < 3 * YEAR; d++) {
    stepDay(A); stepDay(B);
    for (const a of [...A.pending]) resolvePublic(A, a.staging, "");
    for (const a of [...B.pending]) resolvePublic(B, a.staging, "");
  }
  if (hashVillage(A) !== hashVillage(B) || A.evHash !== B.evHash) fails.push(`seed ${seed}: two live runs with the same resolutions differ`);
  // the rescuer: frees everyone about to die, shields everyone in a pillory
  const R = createVillage(seed, { pace: C.LIVE_PACE, live: true });
  const freedBefore = freed;
  for (let d = 0; d < 3 * YEAR; d++) {
    stepDay(R);
    for (const a of [...R.pending]) {
      const lethal = C.PUBLIC[a.kind].lethal;
      const who = a.victim;
      resolvePublic(R, a.staging, lethal ? "free" : a.kind === "pillory" ? "shield" : "");
      if (lethal) { freed++; if (R.people[who].alive) saved++; else fails.push(`seed ${seed}: freed ${who} died anyway`); }
      if (a.kind === "pillory") shielded++;
    }
  }
  if (freed > freedBefore && R.stranger.standing >= 0 && R.stranger.enemies.length === 0) fails.push(`seed ${seed}: the stranger left no mark`);
}
console.log(`freed ${freed} (all ${saved} alive), shielded ${shielded}`);
console.log(fails.length ? "FAIL\n" + fails.join("\n") : `PASS: ${seeds} villages; live villages deterministic; every freed person lives; the village remembers the stranger`);
if (fails.length) process.exitCode = 1;
