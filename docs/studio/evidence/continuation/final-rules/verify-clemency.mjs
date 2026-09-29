import { readFileSync } from 'node:fs';

const path = new URL('../integration-m3/endings-clemency.jsonl', import.meta.url);
const rows = readFileSync(path, 'utf8').trim().split(/\r?\n/).map(JSON.parse);
const villages = rows.filter(r => !r.summary);
const summary = rows.find(r => r.summary);
let valid = villages.length === 20 && summary?.villages === 20 && summary?.years === 1000 && summary?.pace === 1;
const counts = {};
let cases = 0, closed = 0, pending = 0, classified = 0, failures = 0;
for (let i = 0; i < villages.length; i++) {
  const r = villages[i];
  const recorded = Object.values(r.outcomes).reduce((a, b) => a + b, 0);
  const [largest, count] = Object.entries(r.outcomes).sort((a, b) => b[1] - a[1] || a[0].localeCompare(b[0]))[0];
  valid &&= r.seed === 5000 + i * 7919 && r.cases === r.closedCases + r.pendingCases
    && r.classified === recorded && r.unclassified === r.cases - recorded
    && r.largest === largest && r.count === count
    && r.largestShare === +(100 * count / r.cases).toFixed(2)
    && r.under40 === (count / r.cases <= 0.4);
  if (!r.under40) failures++;
  cases += r.cases; closed += r.closedCases; pending += r.pendingCases; classified += recorded;
  for (const [name, n] of Object.entries(r.outcomes)) counts[name] = (counts[name] ?? 0) + n;
}
valid &&= cases === summary.totalCases && closed === summary.totalClosed && pending === summary.totalPending
  && classified === summary.classified && failures === summary.failingVillages
  && JSON.stringify(counts) === JSON.stringify(summary.outcomes);
console.log(JSON.stringify({ valid, villages: villages.length, years: summary.years, pace: summary.pace,
  cases, closed, pending, classified, unclassified: cases - classified, failures, outcomes: counts }));
if (!valid) process.exitCode = 1;
