import { createVillage, run, YEAR } from '../../../../../tools-src/studio/village-reference/village.mjs';

const villages = 20, years = 1000, pace = 1;
let failed = 0, totalCases = 0, totalClosed = 0, totalPending = 0;
const overall = {};
for (let s = 0; s < villages; s++) {
  const seed = 5000 + s * 7919;
  const stormPlan = [];
  for (let y = 50; y < years; y += 97) stormPlan.push({ day: y * YEAR + 20, household: (seed + y) % 6, days: 90 });
  const V = createVillage(seed, { pace, stormPlan });
  run(V, years * YEAR);
  const cases = V.cases.length;
  const closedCases = V.cases.filter(cs => V.crimes[cs.crime].closed).length;
  const pendingCases = cases - closedCases;
  const outcomes = Object.fromEntries(Object.entries(V.stats.outcomes).sort((a, b) => a[0].localeCompare(b[0])));
  const classified = Object.values(outcomes).reduce((a, b) => a + b, 0);
  const unclassified = cases - classified;
  const [largest, count] = Object.entries(outcomes).sort((a, b) => b[1] - a[1] || a[0].localeCompare(b[0]))[0] ?? ['none', 0];
  const largestShare = +(count * 100 / cases).toFixed(2);
  const under40 = count / cases <= 0.4;
  if (!under40) failed++;
  totalCases += cases; totalClosed += closedCases; totalPending += pendingCases;
  for (const [name, n] of Object.entries(outcomes)) overall[name] = (overall[name] ?? 0) + n;
  console.log(JSON.stringify({ seed, cases, closedCases, pendingCases, outcomes, classified, unclassified,
    largest, count, largestShare, under40 }));
}
console.log(JSON.stringify({ summary: true, villages, years, pace, totalCases, totalClosed, totalPending, outcomes: overall,
  classified: Object.values(overall).reduce((a, b) => a + b, 0), failingVillages: failed }));
if (failed) process.exitCode = 1;
