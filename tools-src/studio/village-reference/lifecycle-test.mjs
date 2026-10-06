import assert from 'node:assert/strict';
import {createRuntime,advance,act,terminal,canonical,syncEvents,routine} from './runtime.mjs';
import {saveVillage,loadVillage} from './save.mjs';
const copy=V=>loadVillage(saveVillage(V));
function find(type, predicate=()=>true) {
  for(let seed=1;seed<30;seed++) {
    const V=createRuntime(seed);
    for(let day=0;day<90;day++) {
      advance(V,V.day*1440);
      const e=V.runtime.events.find(e=>e.type===type&&!terminal(e)&&predicate(V,e));
      if(e) { advance(V,Math.max(V.runtime.now,e.from)); return [V,e]; }
    }
  }
  throw Error('missing '+type);
}
const request=(V,e,verb,parameters={})=>act(V,{action_id:verb+JSON.stringify(parameters),village_id:V.runtime.village,player_id:'player:local',logical_time:V.runtime.now,event_id:e.id,verb,parameters},{distance_dm:0,intercepted:true});
// Simulate foreground minutes vs one offscreen jump: same full future-affecting state.
for(const seed of [1,16838,48514]) {
  const live=createRuntime(seed), away=copy(live), target=live.runtime.now+8*1440;
  while(live.runtime.now<target) advance(live,Math.min(target,live.runtime.now+17));
  advance(away,target);
  assert.equal(canonical(live),canonical(away),'advance chunking seed '+seed);
}
const [V,e]=find('hearing');
const st=V.stagings.find(s=>s.id===e.id), pending=V.runtime.hearings.find(x=>x.staging===e.id);
const other=structuredClone(st); other.id=V.stagingCount++; V.stagings.push(other);
V.runtime.hearings.push({...pending,staging:other.id}); syncEvents(V);
const delayed=V.runtime.events.find(x=>x.id===other.id);
assert.ok(delayed.from>=e.end+5,'shared venue/actors reserved deterministically');
V.people[e.actors.find(id=>id!==e.victim)].present=false;
advance(V,V.runtime.now);
assert.equal(e.phase,'cancelled'); assert.equal(delayed.phase,'cancelled');
assert.equal(request(V,e,'bribe').accepted,false,'absent judge cannot be bribed');
const [D,de]=find('hearing'); D.people[de.actors.find(id=>id!==de.victim)].alive=false;
advance(D,D.runtime.now); assert.equal(de.phase,'cancelled');
assert.equal(request(D,de,'bribe').accepted,false,'dead judge cannot be bribed');
const [S,se]=find('public',(V,e)=>V.stagings.find(s=>s.id===e.id).beats.filter(b=>b.do==='throw').length>=2);
const stage=S.stagings.find(s=>s.id===se.id), throwIds=stage.beats.map((b,i)=>b.do==='throw'?i:-1).filter(i=>i>=0);
const first=throwIds[0], second=throwIds[1];
advance(S,Math.max(S.runtime.now,stage.day*1440+stage.beats[first].at));
assert.equal(request(S,se,'shield',{beat:first}).accepted,true);
assert.equal(request(S,se,'shield',{beat:first}).duplicate,true);
assert.deepEqual(se.shields,[first]); assert.equal(se.shields.includes(second),false,'one contact is not blanket immunity');
const saved=copy(S); advance(S,se.deadline); advance(saved,se.deadline);
assert.equal(canonical(S),canonical(saved)); assert.equal(request(S,se,'free').accepted,false,'late free rejected');
assert.equal(S.people[se.victim].locked,false,'terminal restraint cleared');
const R=createRuntime(1); const id=R.people.find(p=>p.alive&&p.present&&p.plan.some((s,i)=>i>0&&s[2]!==p.plan[i-1][2])).id;
advance(R,600); const trip=routine(R,id); const rr=copy(R);
assert.deepEqual(routine(rr,id),trip,'routine restores from same logical minute');
console.log('PASS lifecycle: chunk-independent live/offscreen continuation 3x8days; shared actor/venue reservations; disappearance cancellation; bounded contact/replay/reload; late free; terminal unlock; routine restore');
