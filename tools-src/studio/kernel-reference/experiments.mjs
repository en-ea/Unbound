// Re-runs the S1 experiments on the integer reference, to check that removing every float kept the
// behaviour the prototype showed (growth that levels off, edits that stay local, storms that turn).
// Usage: node experiments.mjs   (writes experiments-results.txt beside this file)
import { History, A, E, hashWorld, snapshot, stageOf, describe, line } from "./kernel.mjs";
import { writeFileSync } from "node:fs";
import { performance } from "node:perf_hooks";

const YEARS = 500;
const SEEDS = Array.from({ length: 20 }, (_, i) => 1000 + i * 7919);
const out = [];
const say = (s = "") => { out.push(s); console.log(s); };
const median = (a) => { const b = [...a].sort((x, y) => x - y); return b[Math.floor(b.length / 2)]; };
const pct = (n, d) => (d ? `${Math.round((100 * n) / d)}%` : "-");

say(`Integer reference - S1 experiments re-run. Node ${process.version}, ${new Date().toISOString()}`);
say();

// 1. Speed, size, determinism
new History(SEEDS[0]).run(YEARS); // warm the JIT
const times = [], counts = [], evs = [], alive = [];
for (const seed of SEEDS) {
  const t0 = performance.now();
  const w = new History(seed).run(YEARS);
  times.push(performance.now() - t0);
  counts.push(w.n); evs.push(w.ev.year.length);
  alive.push(w.pop.filter((p) => p > 0).length);
}
say("1. 500 years of history, 20 seeds");
say(`   median ${median(times).toFixed(1)} ms (max ${Math.max(...times).toFixed(1)} ms); settlements ever ${median(counts)}, alive at 500 ${median(alive)}; events ${median(evs)}`);
const h1 = hashWorld(new History(SEEDS[3]).run(YEARS)), h2 = hashWorld(new History(SEEDS[3]).run(YEARS));
say(`   same seed twice: ${h1} / ${h2} (${h1 === h2 ? "identical" : "DIFFERENT"})`);
say();

// 2. Growth levels off (the S1 fix: land shared with neighbours, 12 per land)
say("2. Population over time, seed 1000 (total, alive settlements)");
{
  const hist = new History(SEEDS[0]);
  hist.run(YEARS);
  const row = [];
  for (let y = 0; y < YEARS; y += 100) {
    const w = hist.checkpoints.get(y);
    row.push(`yr ${y}: ${w.pop.reduce((a, b) => a + b, 0)} in ${w.pop.filter((p) => p > 0).length}`);
  }
  say("   " + row.join(" | "));
}
say();

// 3. Edit the past: warn a village of its flood. How far does the change spread?
say("3. Warn one village of the flood that hit it; what a player would notice by year 500");
const noticed = [], resumeOk = [];
for (const seed of SEEDS) {
  const base = new History(seed);
  const w = base.run(YEARS);
  let f = -1;
  for (let i = 0; i < w.ev.year.length; i++) if (w.ev.type[i] === E.FLOOD && w.ev.year[i] > 100 && w.ev.year[i] < 400) { f = i; break; }
  if (f < 0) continue;
  const actions = [{ year: w.ev.year[f] - 1, player: 1, seq: 1, kind: A.WARN, target: w.ev.sub[f], a: 3, b: 0 }];
  const edited = new History(seed, actions);
  const e = edited.run(YEARS);
  // resuming from the checkpoint before the edit must equal the full re-run
  const cpYear = Math.floor((w.ev.year[f] - 1) / 25) * 25;
  const resumed = edited.resume(base.checkpoints.get(cpYear), YEARS);
  resumeOk.push(hashWorld(resumed) === hashWorld(e));
  let m = 0;
  const len = Math.max(w.n, e.n);
  for (let s = 0; s < len; s++) {
    if (s >= w.n || s >= e.n) { m++; continue; }
    if (stageOf(w.pop[s]) !== stageOf(e.pop[s]) || w.tech[s] !== e.tech[s] || (w.pop[s] <= 0) !== (e.pop[s] <= 0) || Math.abs(w.pop[s] - e.pop[s]) * 10 > Math.max(w.pop[s], e.pop[s])) m++;
  }
  noticed.push(Math.round((100 * m) / len));
}
say(`   noticeable change: median ${median(noticed)}% of settlements (S1 float prototype: 21%); per trial: ${noticed.join(" ")}`);
say(`   resume from a checkpoint equals a full re-run: ${resumeOk.every(Boolean) ? "yes, every trial" : "NO"}`);
say();

// 4. Storm enclaves (S1b), the storm computed by the kernel from the log alone
say("4. Time-storm enclaves: a share of the largest old village folded into its past at year 500; 25 years watched");
say("gap | share | trials | past raids present | present raids past | any fighting | past taught others | origin smaller (median)");
let story = null;
for (const gap of [40, 150, 300]) {
  for (const share of [300, 600]) {
    let trials = 0, er = 0, or = 0, any = 0, taught = 0;
    const loss = [];
    for (const seed of SEEDS) {
      const hist = new History(seed);
      const w = hist.run(YEARS);
      const then = hist.stateAt(YEARS - gap);
      let origin = -1;
      for (let s = 0; s < w.n; s++) {
        if (w.pop[s] < 60 || s >= then.n || then.pop[s] <= 0) continue;
        if (origin < 0 || w.pop[s] > w.pop[origin]) origin = s;
      }
      if (origin < 0) continue;
      const withStorm = new History(seed, [{ year: YEARS, player: 0, seq: 1, kind: A.STORM, target: origin, a: share, b: YEARS - gap }]).run(YEARS + 25);
      const without = new History(seed).run(YEARS + 25);
      const e = withStorm.enclaveOf.indexOf(origin);
      if (e < 0) continue;
      trials++;
      let eR = 0, oR = 0, tg = 0;
      for (let i = 0; i < withStorm.ev.year.length; i++) {
        if (withStorm.ev.year[i] < YEARS) continue;
        const t = withStorm.ev.type[i], s = withStorm.ev.sub[i], o = withStorm.ev.other[i];
        if (t === E.RAID && s === e && o === origin) eR++;
        if (t === E.RAID && s === origin && o === e) oR++;
        if (t === E.LEARNED && o === e) tg++;
      }
      if (eR) er++;
      if (oR) or++;
      if (eR || oR) any++;
      if (tg) taught++;
      const b = without.pop[origin];
      loss.push(b ? Math.round((100 * (b - withStorm.pop[origin])) / b) : 0);
      if (!story && eR && gap >= 150) story = { w: withStorm, origin, e, seed, gap, share };
    }
    say(`${String(gap).padStart(3)} | ${String(share / 10).padStart(4)}% | ${String(trials).padStart(6)} | ${pct(er, trials).padStart(18)} | ${pct(or, trials).padStart(18)} | ${pct(any, trials).padStart(12)} | ${pct(taught, trials).padStart(18)} | ${median(loss)}%`);
  }
}
if (story) {
  const { w, origin, e } = story;
  say();
  say(`One storm, from the chronicle (seed ${story.seed}, ${story.gap} years back, ${story.share / 10}% of the village):`);
  let shown = 0;
  for (let i = 0; i < w.ev.year.length && shown < 12; i++) {
    if (w.ev.year[i] < YEARS || (w.ev.sub[i] !== origin && w.ev.sub[i] !== e)) continue;
    if (w.ev.type[i] === E.DROUGHT || w.ev.type[i] === E.HUNGER) continue;
    say(`   yr ${w.ev.year[i]}  ${line(w, i)}`);
    shown++;
  }
  say(`   ... year ${YEARS + 25}: ${describe(w, origin)} | ${describe(w, e)}`);
}

writeFileSync(new URL("./experiments-results.txt", import.meta.url), out.join("\n") + "\n");
