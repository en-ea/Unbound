// Integer game minutes own consequences. Presentation never resolves state.
import { createVillage, stepDay, ageOf, setOpinion, opinion, planDay, placeAt } from './village.mjs';
import { resolvePublic, trial, remember, earn } from './justice.mjs';
import { riteAct, stormHits } from './storm.mjs';
import { giveBelief } from './crime.mjs';
import { logEvent } from './events.mjs';
import * as C from './content.mjs';
import { stormTransition } from './storm-bridge.mjs';
export function attachRuntime(V, minute = 432) {
  if (V.runtime) return V;
  V.live = true;
  V.runtime = { version: 1, village: `wenbrook:${V.seed}`, now: V.day * 1440,
    events: [], receipts: {}, sequence: 0, residents: {}, players: {}, fraction: 0,
    hearings: [], rites: [], traces: [], resolving: false, challenge: false, storm_cycle: 0 };
  advance(V, V.runtime.now + minute);
  return V;
}
export const createRuntime = (seed = 1, opts = {}) => attachRuntime(createVillage(seed, { pace: 10, focus: true, ...opts }));
export const terminal = e => ['resolved', 'cancelled'].includes(e.phase);
export const eventById = (V, id) => V.runtime.events.find(e => e.id === id);
export function syncEvents(V) {
  const r = V.runtime;
  for (const a of [...V.pending, ...r.hearings, ...r.rites]) {
    if (eventById(V, a.staging)) continue;
    const st = V.stagings.find(s => s.id === a.staging);
    if (!st) throw new Error('pending act without staging');
    const windows = st.phases.filter(p => p.rescue);
    const type = r.hearings.includes(a) ? 'hearing' : r.rites.includes(a) ? 'rite' : 'public';
    const e = { id: st.id, revision: 0, type, victim: a.victim, place: st.place,
      from: st.day * 1440 + Math.min(st.start, ...windows.map(p => p.from)),
      deadline: st.day * 1440 + (a.deadline ?? (windows.length ? Math.max(...windows.map(p => p.to)) : st.end)),
      end: st.day * 1440 + st.end, phase: 'prepared', outcome: '', shields: [],
      witnesses: (a.attend ?? st.roles.crowd).slice(), actors: [...new Set([a.victim, st.roles.authority, st.roles.accuser].filter(id => id >= 0))],
      testimony: [], bribe: '', challenge: 0, source: type === 'public' ? null : a.s };
    // Reserve the victim and venue; shift the whole plan in stable staging order.
    for (const prior of r.events) {
      if (terminal(prior) || prior.end <= e.from || (prior.place !== e.place && !prior.actors.some(id => e.actors.includes(id)))) continue;
      const shift = prior.end + 5 - e.from;
      e.from += shift; e.deadline += shift; e.end += shift;
      st.start += shift; st.end += shift;
      for (const p of st.phases) { p.from += shift; p.to += shift; }
      for (const b of st.beats) b.at += shift;
    }
    r.events.push(e);
  }
}
export function advance(V, target) {
  const r = V.runtime;
  if (!Number.isSafeInteger(target) || target < r.now) throw new Error('clock must advance monotonically');
  while (true) {
    syncEvents(V);
    const due = r.events.filter(e => !terminal(e)).sort((a,b) => a.deadline - b.deadline || a.id - b.id)[0];
    const dawn = V.day * 1440;
    const traceAt = Math.min(Infinity,...r.traces.filter(t=>!t.discovered).map(t=>t.discover_at));
    const next = Math.min(dawn, due?.deadline ?? Infinity,traceAt);
    if (next > target) break;
    r.now = Math.max(r.now, next);
    if (traceAt <= dawn && traceAt <= (due?.deadline ?? Infinity)) discoverTraces(V);
    else if (due && due.deadline <= dawn) resolve(V, due);
    else {
      stepDay(V); syncEvents(V);
      // A small ordinary district can regress. Story NPCs and the player's possessions are outside this data.
      if (!V.anchored && V.day >= r.storm_cycle + 4) {
        r.storm_cycle = V.day;
        const eligible = V.households.filter(h => ['round', 'hill'].includes(h.home));
        const transition = stormTransition(V.seed, Math.floor(V.day / 4));
        if (eligible.length && transition) {
          const id = stormHits(V, eligible[(Math.floor(V.day / 4) - 1) % eligible.length].id, 3);
          if (id >= 0) V.storms[id].kernel = transition;
        }
      }
    }
    discoverTraces(V);
  }
  r.now = target;
  for (const e of r.events) {
    if (terminal(e)) continue;
    const p = V.people[e.victim];
    if (!validParticipants(V,e)) cancel(V, e, 'participant unavailable');
    else if (r.now >= e.from) { e.phase = 'active'; if (e.type !== 'hearing') { p.locked = true; p.lockedAt = e.place; } }
  }
  r.events = r.events.filter(e => !terminal(e) || e.end > r.now - 7 * 1440);
}
function validParticipants(V,e) {
  return e.actors.every(id => V.people[id]?.alive && V.people[id].present)
    && (e.type !== 'rite' || (V.storms[e.source.storm]?.active && V.runtime.now < V.storms[e.source.storm].until * 1440));
}
function resolve(V, e) {
  const p = V.people[e.victim];
  if (!validParticipants(V,e)) return cancel(V, e, 'participant unavailable');
  if (e.type === 'hearing') {
    V.runtime.resolving = true; V.runtime.challenge = e.challenge >= 700;
    const before = V.stagingCount;
    trial(V, e.source);
    V.runtime.resolving = false; V.runtime.challenge = false;
    const realized = V.stagings.find(s => s.id === before);
    e.outcome = realized?.verdict ?? 'dismissed';
    e.phase = 'resolved'; e.revision++;
    V.runtime.hearings = V.runtime.hearings.filter(a => a.staging !== e.id);
    return;
  }
  if (e.type === 'rite') {
    V.runtime.resolving = true; riteAct(V,e.source); V.runtime.resolving = false;
    V.runtime.rites = V.runtime.rites.filter(a => a.staging !== e.id);
  } else resolvePublic(V, e.id, '');
  p.locked = false;
  e.phase = 'resolved'; e.revision++;
  e.outcome = p.alive ? (p.present ? 'released' : 'exiled') : 'died';
}
export function cancel(V, e, reason) {
  V.pending = V.pending.filter(a => a.staging !== e.id);
  V.runtime.hearings = V.runtime.hearings.filter(a => a.staging !== e.id);
  V.runtime.rites = V.runtime.rites.filter(a => a.staging !== e.id);
  e.phase = 'cancelled'; e.outcome = reason; e.revision++;
  if (V.people[e.victim]) V.people[e.victim].locked = false;
}
// The bridge samples spatial context at input time, never in a delayed animation callback.
export function act(V, request, context = {}) {
  const r = V.runtime, id = request.action_id;
  if (typeof id !== 'string' || !id || id.length > 120) return { accepted: false, reason: 'invalid action' };
  if (r.receipts[id]) return { ...r.receipts[id], duplicate: true };
  const fail = reason => ({ accepted: false, reason });
  if (request.village_id !== r.village || request.player_id !== 'player:local' || request.logical_time !== r.now) return fail('stale context');
  const e = eventById(V, request.event_id);
  if (!e || terminal(e) || r.now < e.from || r.now >= e.deadline) return fail('window closed');
  const p = V.people[e.victim];
  if (!p?.alive || !p.present || context.distance_dm > (request.verb === 'shield' ? 100 : 25) || context.distance_dm < 0 || !Number.isFinite(context.distance_dm)) return fail('out of reach');
  const verb = request.verb, params = request.parameters ?? {};
  const player = r.players[request.player_id] ??= { knowledge: [], standing: 0, enemies: [] };
  const accept = (outcome, costs = {}) => {
    const receipt = { accepted: true, action_id:id, event_id:e.id, verb, at:r.now, outcome, revision:e.revision, player:request.player_id, ...costs };
    r.receipts[id] = receipt; r.sequence++;
    const keys = Object.keys(r.receipts); if (keys.length > 256) delete r.receipts[keys[0]];
    return receipt;
  };
  if (verb === 'listen') {
    const speaker = V.people[params.speaker];
    if (!speaker?.alive || !speaker.present || !e.witnesses.includes(speaker.id)) return fail('no witness here');
    if (C.LANG_DISTANCE[V.age][speaker.era] >= 60) return fail('Their words are unfamiliar; use gestures.');
    const cs = e.type === 'hearing' ? V.cases[e.source.case] : V.cases[V.pending.find(a => a.staging === e.id)?.cs];
    if (!cs) return fail('no testimony');
    const belief = speaker.beliefs.filter(b => b.crime === cs.crime).sort((a,b)=>b.strength-a.strength)[0];
    if (!belief) return fail('I did not see it.');
    const clue = { crime: belief.crime, culprit: belief.culprit, origin: belief.origin, strength: belief.strength, via:'retelling', speaker:speaker.id };
    if (!player.knowledge.some(k => k.crime === clue.crime && k.origin === clue.origin && k.culprit === clue.culprit)) player.knowledge.push(clue);
    player.knowledge = player.knowledge.slice(-32);
    return accept('heard', { clue });
  }
  if (verb === 'inspect') {
    if (e.type !== 'hearing') return fail('no open case');
    const cs = V.cases[e.source.case], crime = V.crimes[cs.crime];
    if (!crime.traceAt || params.place !== crime.traceAt) return fail('no trace here');
    const clue = { crime:crime.id, culprit:crime.culprit, origin:1000000+crime.id, strength:800, via:'trace', speaker:-1 };
    if (!player.knowledge.some(k => k.crime === clue.crime && k.origin === clue.origin)) player.knowledge.push(clue);
    return accept('found a trace', { clue });
  }
  if (verb === 'testify') {
    if (e.type !== 'hearing') return fail('hearing closed');
    const cs = V.cases[e.source.case];
    const clue = player.knowledge.find(k => k.crime === cs.crime && k.origin === params.origin);
    if (!clue) return fail('no evidence to offer');
    if (e.testimony.includes(clue.origin)) return fail('already heard this source');
    e.testimony.push(clue.origin);
    const judge = V.stagings.find(s=>s.id===e.id).roles.authority;
    if (judge < 0 || !V.people[judge].alive || !V.people[judge].present) return fail('no judge');
    const known = V.people[judge].beliefs.some(b => b.crime === cs.crime && b.origin === clue.origin && b.culprit === clue.culprit);
    giveBelief(V,judge,cs.crime,clue.culprit,clue.strength,clue.origin,1,-2);
    if (!known) {
      if (clue.culprit === cs.accused) cs.evidence += Math.floor(clue.strength / 2);
      else { cs.evidence = Math.max(0,cs.evidence-clue.strength); e.challenge += clue.strength; }
    }
    e.revision++;
    return accept(known ? 'We already heard that account.' : clue.culprit === cs.accused ? 'That supports the accusation.' : 'That casts doubt on the accusation.');
  }
  if (verb === 'bribe') {
    if (e.type !== 'hearing' || e.bribe) return fail('offer already decided');
    if ((context.coins ?? 0) < 5) return fail('requires 5 coins');
    const judge = V.people[V.stagings.find(s=>s.id===e.id).roles.authority];
    if (!judge?.alive || !judge.present) return fail('no judge');
    e.bribe = judge.traits[C.GREED] > judge.traits[C.HONESTY] && judge.values.law < 75 ? 'accepted' : 'refused';
    if (e.bribe === 'accepted') V.cases[e.source.case].evidence = Math.max(0,V.cases[e.source.case].evidence-350);
    else { player.standing -= 5; if (judge.traits[C.HONESTY] >= 70 && !player.enemies.includes(judge.id)) player.enemies.push(judge.id); }
    e.revision++;
    return accept(e.bribe === 'accepted' ? 'I will weigh your request.' : 'Keep your coins. This is a hearing.', { coins: e.bribe === 'accepted' ? 5 : 0 });
  }
  if (verb === 'plant') {
    if (e.type !== 'hearing' || r.traces.some(t=>t.event===e.id)) return fail('trace already placed');
    if ((context.wood ?? 0) < 1) return fail('requires 1 wood');
    const home = V.households[p.household].home;
    if (params.place !== home) return fail('not at their doorstep');
    const observers = (context.witnesses ?? []).filter(id => V.people[id]?.alive && V.people[id].present);
    r.traces.push({ event:e.id, crime:V.cases[e.source.case].crime, culprit:p.id, place:home,
      origin:3000000+e.id, discover_at:r.now+15, observers, discovered:false, planted_by:request.player_id });
    return accept(observers.length ? 'Someone saw you leave the marked wood.' : 'Marked wood left by the door.', { wood:1 });
  }
  if (verb === 'shield') {
    if (e.type !== 'public' || !Number.isInteger(params.beat) || e.shields.includes(params.beat)) return fail('contact already resolved');
    const st = V.stagings.find(s=>s.id===e.id), beat = st.beats[params.beat];
    if (!beat || beat.do !== 'throw' || !context.intercepted || Math.abs(r.now-(st.day*1440+beat.at)) > 5) return fail('no contact');
    e.shields.push(params.beat); player.standing += 2;
    // One contact affects that exposure only. All lethal stones must be intercepted to prevent a planned stone death.
    const a = V.pending.find(a=>a.staging===e.id);
    const stones = st.beats.map((b,i)=>b.do==='throw'&&b.prop==='stone'?i:-1).filter(i=>i>=0);
    if (a && a.lethalByStones && stones.length && stones.every(i=>e.shields.includes(i))) a.lethalByStones = false;
    return accept('intercepted one throw', { damage: beat.prop === 'stone' ? 1 : 0 });
  }
  let ritualOffer = false;
  if (verb === 'offer') {
    if (e.type !== 'rite' || e.bribe) return fail('offering already decided');
    if ((context.wood ?? 0) < 1) return fail('requires 1 wood');
    const leader = V.people[e.source.who];
    e.bribe = 'offered'; ritualOffer = true;
    if (leader.traits[C.COMPASSION] + leader.values.mercy < 105) return accept('They turn back to the fire.', { wood: 1 });
  }
  if ((!ritualOffer && verb !== 'free') || e.type === 'hearing') return fail('unknown action');
  if (e.type === 'rite') {
    const leader = V.people[e.source.who];
    const ev = logEvent(V,'rite',leader.id,p.id,{rite:'sacrifice',outcome:'rescued',by:request.player_id},e.source.causes,'the rope cut; the captive running towards refuge');
    if (!ritualOffer) { remember(leader,-2,ev); player.enemies.push(leader.id); }
    r.rites = r.rites.filter(a=>a.staging!==e.id);
  } else {
    const pending = V.pending.find(a=>a.staging===e.id);
    resolvePublic(V, e.id, 'free');
    player.standing -= C.PUBLIC[pending.kind].shame * 10;
    for (const id of e.actors.filter(id=>id!==p.id)) if (!player.enemies.includes(id)) player.enemies.push(id);
  }
  p.present = true; p.locked = false; p.lockedAt = undefined;
  V.outlaws = V.outlaws.filter(x => x !== p.id);
  V.schedule = V.schedule.filter(s => !((s.kind === 'return' && s.who === p.id) || (s.case !== undefined && V.cases[s.case]?.accused === p.id)));
  r.residents[p.id] = { refuge_until: r.now + 2880, rescued_by: request.player_id, destination: 'far_woods' };
  for (const other of r.events) if (other !== e && other.victim === p.id && !terminal(other)) cancel(V, other, 'rescued');
  e.phase = 'resolved'; e.outcome = ritualOffer ? 'spared' : 'rescued'; e.revision++;
  planDay(V);
  return accept(e.outcome, ritualOffer ? { wood:1 } : {});
}

function discoverTraces(V) {
  for (const t of V.runtime.traces) {
    if (t.discovered || t.discover_at > V.runtime.now) continue;
    const e = eventById(V,t.event);
    if (!e || terminal(e)) { t.discovered = true; continue; }
    // Discovery needs a local resident, never an omniscient update of every mind.
    const finder = V.people.find(p=>p.alive&&p.present&&p.id!==t.culprit&&ageOf(V,p)>=14&&placeAt(p,V.runtime.now%1440)===t.place)?.id;
    if (finder === undefined) { t.discover_at = V.runtime.now + 15; continue; }
    t.discovered = true;
    if (t.observers.length) {
      const player = V.runtime.players[t.planted_by]; player.standing -= 10;
      for (const id of t.observers) if (!player.enemies.includes(id)) player.enemies.push(id);
    } else {
      giveBelief(V,finder,t.crime,t.culprit,350,t.origin,0,-1);
      // It still has to reach the hearing; a later retelling retains this one source.
    }
  }
}
// All future-affecting fields; maps remain ordered, object property order is immaterial.
export function canonical(V) {
  const ordered = v => v instanceof Map ? { __map: [...v].map(([k,x]) => [k, ordered(x)]) }
    : Array.isArray(v) ? v.map(ordered) : v && typeof v === 'object'
      ? Object.fromEntries(Object.keys(v).sort().filter(k => v[k] !== undefined).map(k => [k, ordered(v[k])])) : v;
  return JSON.stringify(ordered(V));
}
