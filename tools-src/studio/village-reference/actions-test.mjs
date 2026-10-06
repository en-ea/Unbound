import assert from 'node:assert/strict';
import { createRuntime, advance, act, terminal, canonical, syncEvents } from './runtime.mjs';
import { createVillage, stepDay } from './village.mjs';
import { trial } from './justice.mjs';
import { stormHits, riteAct, stormRecedes } from './storm.mjs';
import { giveBelief } from './crime.mjs';
import { saveVillage, loadVillage } from './save.mjs';
import * as C from './content.mjs';
const request = (V,e,verb,params={},extra={})=>act(V,{action_id:`${e.id}:${verb}:${JSON.stringify(params)}`,player_id:'player:local',village_id:V.runtime.village,logical_time:V.runtime.now,event_id:e.id,verb,parameters:params},{distance_dm:0,coins:50,wood:1,...extra});
function hearing() {
  for(let seed=1;seed<30;seed++) {
    const V=createRuntime(seed,{anchored:true});
    for(let i=0;i<60;i++) {
      advance(V,V.day*1440);
      const e=V.runtime.events.find(e=>e.type==='hearing'&&!terminal(e));
      if(e) { advance(V,Math.max(V.runtime.now,e.from)); return [V,e]; }
    }
  }
  throw Error('no hearing');
}
const [V,e]=hearing(), cs=V.cases[e.source.case];
assert.equal(V.crimes[cs.crime].closed,false,'no verdict before hearing');
// A known trace points elsewhere. One source, however often retold, stays one source.
const other=V.people.find(p=>p.alive&&p.present&&p.id!==cs.accused&&p.id!==V.authority);
V.crimes[cs.crime].traceAt=V.households[other.household].home;
V.crimes[cs.crime].culprit=other.id;
assert.equal(request(V,e,'inspect',{place:V.crimes[cs.crime].traceAt}).accepted,true);
const origin=1000000+cs.crime;
const before=cs.evidence;
assert.equal(request(V,e,'testify',{origin}).accepted,true);
assert.ok(cs.evidence<before);
const once=cs.evidence; assert.equal(request(V,e,'testify',{origin}).duplicate,true); assert.equal(cs.evidence,once);
const snap=loadVillage(saveVillage(V));
advance(V,e.deadline); advance(snap,e.deadline);
assert.equal(e.outcome,'acquitted'); assert.equal(canonical(V),canonical(snap));
assert.equal(V.people[e.victim].alive,true);
// Two living speakers repeat one original account. Listening cannot manufacture corroboration.
{
  const [T,te]=hearing(), tc=T.cases[te.source.case], judge=T.stagings.find(s=>s.id===te.id).roles.authority;
  const speakers=T.people.filter(p=>p.alive&&p.present&&p.id!==judge&&p.id!==tc.accused).slice(0,2);
  const source=4000000+tc.crime;
  for(const p of speakers) {
    p.era=T.age; p.beliefs=p.beliefs.filter(b=>b.crime!==tc.crime);
    giveBelief(T,p.id,tc.crime,tc.accused,600,source,1,speakers[0].id);
    if(!te.witnesses.includes(p.id))te.witnesses.push(p.id);
    assert.equal(request(T,te,'listen',{speaker:p.id}).accepted,true);
  }
  const knowledge=T.runtime.players['player:local'].knowledge;
  assert.equal(knowledge.filter(k=>k.origin===source).length,1);
  const before=T.people.map(p=>p.beliefs.length), evidence=tc.evidence;
  assert.equal(request(T,te,'testify',{origin:source}).accepted,true);
  assert.equal(tc.evidence,evidence+300);
  for(const p of T.people)if(p.id!==judge)assert.equal(p.beliefs.length,before[p.id]);
  assert.equal(act(T,{action_id:'new-input-same-origin',player_id:'player:local',village_id:T.runtime.village,
    logical_time:T.runtime.now,event_id:te.id,verb:'testify',parameters:{origin:source}},{distance_dm:0}).accepted,false);
  assert.equal(tc.evidence,evidence+300);
}
for(const accepted of [true,false]) {
  const [B,be]=hearing(), judge=B.people[B.stagings.find(s=>s.id===be.id).roles.authority];
  judge.traits[C.GREED]=accepted?100:0; judge.traits[C.HONESTY]=accepted?0:100; judge.values.law=50;
  const result=request(B,be,'bribe'); assert.equal(result.coins,accepted?5:0);
  assert.equal(request(B,be,'bribe').duplicate,true);
  const restored=loadVillage(saveVillage(B)); assert.equal(request(restored,be,'bribe').duplicate,true);
}
for(const watched of [true,false]) {
  const [P,pe]=hearing(), home=P.households[P.people[pe.victim].household].home;
  const judge=P.stagings.find(s=>s.id===pe.id).roles.authority;
  const beliefs=P.people.map(p=>p.beliefs.length);
  assert.equal(request(P,pe,'plant',{place:home},{witnesses:watched?[judge]:[]}).wood,1);
  assert.deepEqual(P.people.map(p=>p.beliefs.length),beliefs,'plant is not instantly known');
  const finder=P.people.find(p=>p.alive&&p.present&&p.id!==pe.victim&&p.id!==judge&&P.day-p.born>=14*60).id;
  P.people[finder].plan = [[0,1440,home]];
  P.stagings.find(s=>s.id===pe.id).people=P.stagings.find(s=>s.id===pe.id).people.filter(p=>p.id!==finder);
  // Discovery happens on a semantic boundary even between day plans.
  advance(P,P.runtime.now+16);
  assert.equal(P.runtime.traces[0].discovered,true);
  const account=P.runtime.players['player:local'];
  assert.equal(account.enemies.includes(judge),watched);
}
function rite() {
  const R=createRuntime(16838,{anchored:false});
  const sid=stormHits(R,2,3), storm=R.storms[sid];
  const who=storm.ancestors.find(id=>R.people[id].role!=='child');
  const victim=R.people.find(p=>p.alive&&p.present&&p.ancestor===undefined&&R.day-p.born>=16*60&&p.lineage!==R.people[who].lineage);
  const s={day:R.day,kind:'rite',who,other:victim.id,storm:sid,causes:[storm.event]};
  victim.locked=true; riteAct(R,s); syncEvents(R);
  const event=R.runtime.events.find(e=>e.type==='rite');
  advance(R,event.from); return [R,event,storm];
}
for(const accepts of [true,false]) {
  const [O,oe]=rite(), leader=O.people[oe.source.who];
  leader.traits[C.COMPASSION]=accepts?100:0; leader.values.mercy=accepts?100:0;
  assert.equal(request(O,oe,'offer').wood,1);
  assert.equal(terminal(oe),accepts);
  assert.equal(request(O,oe,'offer').duplicate,true);
  assert.equal(O.runtime.players['player:local'].enemies.includes(leader.id),false);
  if(!accepts)assert.equal(request(O,oe,'free').accepted,true,'refused offering still allows rescue');
}
for(const rescue of [true,false]) {
  const [R,re,storm]=rite(); assert.equal(R.people[re.victim].alive,true,'no death at preparation');
  if(rescue) assert.equal(request(R,re,'free').accepted,true);
  const saved=loadVillage(saveVillage(R));
  advance(R,re.deadline); advance(saved,re.deadline); assert.equal(canonical(R),canonical(saved));
  if(rescue) assert.equal(R.people[re.victim].alive,true);
  stormRecedes(R,storm); advance(R,R.runtime.now);
  for(const id of storm.lost) assert.equal(R.people[id].present,true);
  for(const id of storm.ancestors) assert.equal(R.people[id].present,false);
}
const [R,re,storm]=rite(); stormRecedes(R,storm); advance(R,re.deadline);
assert.equal(re.phase,'cancelled'); assert.equal(R.people[re.victim].alive,true,'obsolete rite cannot kill');
const anchor=createRuntime(1,{anchored:true}); assert.equal(stormHits(anchor,0,3),-1);
console.log('PASS actions: undecided hearing; provenance and duplicate testimony; acquittal; bounded bribe/refusal/reload; local planting/discovery; rite preparation/rescue/inaction/recession; anchor; canonical continuation');
