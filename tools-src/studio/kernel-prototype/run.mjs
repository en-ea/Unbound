// Runs the S1 experiments and prints the numbers quoted in plan/ROUTE-r2-2026-09-28.md.
// Usage: node run.mjs            (writes results.txt beside this file)
import { runHistory, resume, hashWorld, describe, snapshot, stageOf } from "./sim.mjs";
import { writeFileSync } from "node:fs";
import { performance } from "node:perf_hooks";

const PRESENT = 500;
const out = [];
const say = (s = "") => { out.push(s); console.log(s); };
const ms = (t) => `${t.toFixed(1)} ms`;
const median = (a) => { const b = [...a].sort((x, y) => x - y); return b[Math.floor(b.length / 2)]; };

// strict: any number differs at all. meaningful: what a player would notice - the village's size
// stage, what it knows, whether it is a ruin, or its population by more than 10%.
function differing(a, b) {
  let n = 0, m = 0;
  const len = Math.max(a.settlements.length, b.settlements.length);
  for (let i = 0; i < len; i++) {
    const x = a.settlements[i], y = b.settlements[i];
    if (!x || !y) { n++; m++; continue; }
    if (x.pop !== y.pop || x.tech !== y.tech || (x.ruinedYear ?? -1) !== (y.ruinedYear ?? -1)) n++;
    if (stageOf(x.pop) !== stageOf(y.pop) || x.tech !== y.tech || (x.pop <= 0) !== (y.pop <= 0) || Math.abs(x.pop - y.pop) > 0.1 * Math.max(x.pop, y.pop)) m++;
  }
  return { n, m, of: len };
}

say(`S1 - world as a function. Node ${process.version}, ${new Date().toISOString()}`);
say();

// 1. Determinism and speed
say("1. Generate 500 years of history (12 founding villages, 3 peoples)");
const seeds = Array.from({ length: 20 }, (_, i) => 1000 + i * 7919);
runHistory(seeds[0], PRESENT); // warm the JIT
const times = [], counts = [], evs = [];
for (const seed of seeds) {
  const t0 = performance.now();
  const { world } = runHistory(seed, PRESENT);
  times.push(performance.now() - t0);
  counts.push(world.settlements.length);
  evs.push(world.events.length);
}
const a1 = runHistory(seeds[3], PRESENT).world, a2 = runHistory(seeds[3], PRESENT).world;
say(`   median ${ms(median(times))} per 500-year history (max ${ms(Math.max(...times))}) over ${seeds.length} seeds`);
say(`   settlements by year 500: median ${median(counts)}; events logged: median ${median(evs)}`);
say(`   same seed twice -> ${hashWorld(a1)} / ${hashWorld(a2)} (${hashWorld(a1) === hashWorld(a2) ? "identical" : "DIFFERENT"})`);
say();

// 2. Checkpoints
const { world: base, checkpoints } = runHistory(seeds[3], PRESENT);
const cpBytes = [...checkpoints.values()].reduce((n, c) => n + JSON.stringify(c).length, 0);
say(`2. Checkpoints every 25 years: ${checkpoints.size} snapshots, ${(cpBytes / 1024).toFixed(0)} KB as JSON in total`);
say();

// 3. A time-storm view: any place, any year
const ruins = base.settlements.filter((s) => s.pop <= 0 && s.ruinedYear > 20);
const place = ruins.find((s) => s.hadMill) ?? ruins[0] ?? base.settlements[0];
const past = Math.max(0, (place.ruinedYear ?? 200) - 15);
let t0 = performance.now();
const cp = checkpoints.get(Math.floor(past / 25) * 25);
const then = resume(base.seed, cp, past);
const tView = performance.now() - t0;
t0 = performance.now();
const future = resume(base.seed, snapshot(base), PRESENT + 100);
const tFuture = performance.now() - t0;
say(`3. Time-storm view of ${place.name}`);
say(`   today (year ${PRESENT}): ${describe(place)}`);
say(`   inside a storm, year ${past}: ${describe(then.settlements[place.id])}  [${ms(tView)}]`);
say(`   the future, year ${PRESENT + 100} (whole world simulated forward): ${future.settlements.length} settlements  [${ms(tFuture)}]`);
say();

// 4. Change the past: warn a village of its flood. Keyed vs stream randomness, over many seeds.
say("4. Change the past: warn one village of the flood that hit it");
const keyedDiff = [], streamDiff = [], editTimes = [], consistent = [];
let story = null;
for (const seed of seeds) {
  const run = runHistory(seed, PRESENT);
  const flood = run.world.events.find((e) => e.type === "flood" && e.year > 100 && e.year < 400);
  if (!flood) continue;
  const iv = [{ year: flood.year - 1, kind: "warn-of-flood", target: flood.id, years: 3, player: "hilmi", seq: 1 }];
  const start = performance.now();
  const cpYear = Math.floor(iv[0].year / 25) * 25;
  const edited = resume(seed, run.checkpoints.get(cpYear), PRESENT, iv);
  editTimes.push(performance.now() - start);
  const full = runHistory(seed, PRESENT, iv).world;
  consistent.push(hashWorld(full) === hashWorld(edited));
  keyedDiff.push(differing(run.world, edited));
  // the same experiment in a shared-stream world, against that world's own flood
  const sBase = runHistory(seed, PRESENT, [], { mode: "stream" }).world;
  const sFlood = sBase.events.find((e) => e.type === "flood" && e.year > 100 && e.year < 400);
  if (sFlood) {
    const sIv = [{ ...iv[0], year: sFlood.year - 1, target: sFlood.id }];
    streamDiff.push(differing(sBase, runHistory(seed, PRESENT, sIv, { mode: "stream" }).world));
  }
  const destroyedMill = flood.text.includes("mill");
  if (!story || (destroyedMill && !story.mill)) story = { seed, flood, base: run.world, edited: full, mill: destroyedMill };
}
const pct = (d, k) => median(d.map((x) => (100 * x[k]) / x.of)).toFixed(0);
say(`   trials: ${keyedDiff.length} keyed, ${streamDiff.length} stream; re-simulation from the nearest checkpoint: median ${ms(median(editTimes))}`);
say(`   resume-from-checkpoint equals a full re-run from year 0: ${consistent.every(Boolean) ? "yes, every trial" : "NO"}`);
say(`   settlements that differ at all by year ${PRESENT}:      keyed median ${pct(keyedDiff, "n")}% | shared stream median ${pct(streamDiff, "n")}%`);
say(`   settlements a player would notice differ (stage, knowledge, ruin, >10% people): keyed median ${pct(keyedDiff, "m")}% | shared stream median ${pct(streamDiff, "m")}%`);
say(`   (noticeable, per trial - keyed: ${keyedDiff.map((d) => d.m).join(" ")} | stream: ${streamDiff.map((d) => d.m).join(" ")})`);
say();

// 5. Catch-up while away
t0 = performance.now();
resume(base.seed, snapshot(base), PRESENT + 30);
say(`5. Catch-up after 30 days offline at one world-year per day: ${ms(performance.now() - t0)}`);
say();

// 6. Two players, two logs, one world
const logA = [
  { year: 350, kind: "teach", target: 2, tech: 7, player: "hilmi", seq: 1 },
  { year: 499, kind: "fell-forest", target: 1, amount: 60, by: "Hilmi", player: "hilmi", seq: 2 },
];
const logB = [
  { year: 420, kind: "gift-food", target: 5, amount: 200, player: "enea", seq: 1 },
  { year: 499, kind: "fund-bridge", target: 1, by: "Enea", player: "enea", seq: 2 },
];
const ab = runHistory(seeds[3], PRESENT, [...logA, ...logB]).world;
const ba = runHistory(seeds[3], PRESENT, [...logB].reverse().concat([...logA].reverse())).world;
say(`6. Two players' logs merged in different arrival orders: ${hashWorld(ab)} / ${hashWorld(ba)} (${hashWorld(ab) === hashWorld(ba) ? "identical" : "DIFFERENT"}); without them: ${hashWorld(base)}`);
say(`   what travels between phones: ${JSON.stringify([...logA, ...logB]).length} bytes of JSON`);
say();

// 7. The chronicle of one place, before and after the edit
if (story) {
  const id = story.flood.id;
  const name = story.base.settlements[id].name;
  const lines = (w) => w.events.filter((e) => e.id === id && !["drought", "hunger"].includes(e.type)).slice(0, 14).map((e) => `     yr ${String(e.year).padStart(3)}  ${e.text}`);
  say(`7. Chronicle of ${name} (seed ${story.seed})`);
  say("   as it happened:");
  lines(story.base).forEach((l) => say(l));
  say(`     ... today: ${describe(story.base.settlements[id])}`);
  say(`   after a player warned them before year ${story.flood.year}:`);
  lines(story.edited).forEach((l) => say(l));
  say(`     ... today: ${describe(story.edited.settlements[id])}`);
}

// 8. Hinge search: the game tries every flood in its own history as a counterfactual and ranks
// them by how much the present would change. Storms can then be sent to the moments that matter.
say();
say("8. Hinge search: prevent each flood in turn, rank by how much today changes");
for (const seed of seeds.slice(0, 5)) {
  const run = runHistory(seed, PRESENT);
  const floods = run.world.events.filter((e) => e.type === "flood" && e.year >= 50 && e.year < 450);
  const t = performance.now();
  const scored = floods.map((f) => {
    const iv = [{ year: f.year - 1, kind: "warn-of-flood", target: f.id, years: 3, player: "search", seq: 1 }];
    const w = resume(seed, run.checkpoints.get(Math.floor(iv[0].year / 25) * 25), PRESENT, iv);
    return { f, d: differing(run.world, w).m };
  }).sort((a, b) => b.d - a.d);
  const spent = performance.now() - t;
  const ds = scored.map((s) => s.d);
  say(`   seed ${seed}: ${floods.length} floods tried in ${ms(spent)}; villages changed today - median ${median(ds)}, best ${ds[0]} ("${scored[0].f.text}", year ${scored[0].f.year})`);
}

writeFileSync(new URL("./results.txt", import.meta.url), out.join("\n") + "\n");
