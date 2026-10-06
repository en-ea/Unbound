import assert from 'node:assert/strict';
import { createRuntime, advance, act, canonical, terminal } from './runtime.mjs';
import { saveVillage, loadVillage } from './save.mjs';
function pending() {
  const V = createRuntime(16838);
  for (let i=0; i<150; i++) {
    advance(V, V.day*1440);
    const e = V.runtime.events.find(e => !terminal(e) && e.deadline > V.runtime.now);
    if (e) return [V,e];
  }
  throw new Error('seed did not produce a public act');
}
const [V,e] = pending();
advance(V, e.deadline-1);
const req = { action_id:'rescue:1', player_id:'player:local', village_id:V.runtime.village,
  logical_time:V.runtime.now, event_id:e.id, verb:'free' };
assert.equal(act(V,req,{distance_dm:99}).accepted,false);
assert.equal(act(V,req,{distance_dm:10}).accepted,true);
assert.equal(act(V,req,{distance_dm:10}).duplicate,true);
assert.equal(V.people[e.victim].locked,false);
const restored = loadVillage(saveVillage(V));
assert.equal(canonical(V),canonical(restored));
advance(V,V.runtime.now+1441); advance(restored,restored.runtime.now+1441);
assert.equal(canonical(V),canonical(restored));
assert.equal(V.people[e.victim].alive,true);
assert.equal(V.runtime.residents[e.victim].rescued_by,'player:local');
const [late,le] = pending(); advance(late,le.deadline);
assert.equal(act(late,{...req, village_id:late.runtime.village,event_id:le.id,logical_time:late.runtime.now},{distance_dm:0}).accepted,false);
console.log('PASS runtime rescue: range, last minute, duplicate, exact deadline, midnight, immediate save/read/continue, full canonical state');
