import { readFileSync } from 'node:fs';
import { createVillage, stepDay } from '../../../../../tools-src/studio/village-reference/village.mjs';
import * as C from '../../../../../tools-src/studio/village-reference/content.mjs';

const source = readFileSync(new URL('../../../../../game/scripts/studio/village/sim_stagings.gd', import.meta.url), 'utf8');
const stages = JSON.parse(source.slice(source.indexOf(':=') + 2));
const chosen = [
  ['pillory/mud', stages.find(s => s.kind === 'pillory' && s.outcome === 'carried_out' && s.beats.some(b => b.prop === 'mud'))],
  ['pillory/crowd_turned', stages.find(s => s.kind === 'pillory' && s.outcome === 'crowd_turned')],
  ['bonfire/carried_out', stages.find(s => s.kind === 'bonfire' && s.outcome === 'carried_out')],
  ['hanging/carried_out', stages.find(s => s.kind === 'hanging' && s.outcome === 'carried_out')],
  ['exile', stages.find(s => s.kind === 'exile')],
  ['rite/carried_out', stages.find(s => s.kind === 'sacrifice' && s.outcome === 'carried_out')],
];
let failed = false;
for (const [label, st] of chosen) {
  if (!st) { console.log(JSON.stringify({ label, error: 'fixture missing' })); failed = true; continue; }
  const tries = (st.seed - 16838) / 7919;
  const V = createVillage(st.seed, { pace: C.LIVE_PACE, stormPlan: [{ day: 40, household: tries % 6, days: 90 }] });
  while (V.day <= st.day) stepDay(V);
  const event = V.events.find(e => (e.type === 'public_act' || e.type === 'rite') && e.data.staging === st.id);
  const output = { label, seed: st.seed, day: st.day, stagingId: st.id, eventId: event?.id ?? null,
    eventType: event?.type ?? null, outcome: event?.data.outcome ?? null, causeIds: event?.causes ?? [] };
  console.log(JSON.stringify(output));
  if (!event || !event.cue || !event.causes.length) failed = true;
}
if (failed) process.exitCode = 1;
