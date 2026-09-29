// Integer game minutes own consequences. Presentation never resolves state.
import { createVillage, stepDay } from './village.mjs';
import { resolvePublic } from './justice.mjs';
export function attachRuntime(V, minute = 432) {
  if (V.runtime) return V;
  V.live = true;
  V.runtime = { version: 1, village: `wenbrook:${V.seed}`, now: V.day * 1440,
    events: [], receipts: {}, sequence: 0, residents: {}, players: {}, fraction: 0 };
  advance(V, V.runtime.now + minute);
  return V;
}
export const createRuntime = (seed, opts = {}) => attachRuntime(createVillage(seed, { pace: 10, focus: true, ...opts }));
export const terminal = e => ['resolved', 'cancelled'].includes(e.phase);
export const eventById = (V, id) => V.runtime.events.find(e => e.id === id);
export function syncEvents(V) {
  const r = V.runtime;
  for (const a of V.pending) {
    if (eventById(V, a.staging)) continue;
    const st = V.stagings.find(s => s.id === a.staging);
    if (!st) throw new Error('pending act without staging');
    const windows = st.phases.filter(p => p.rescue);
    const e = { id: st.id, revision: 0, type: 'public', victim: a.victim, place: st.place,
      from: st.day * 1440 + Math.min(st.start, ...windows.map(p => p.from)),
      deadline: st.day * 1440 + (windows.length ? Math.max(...windows.map(p => p.to)) : st.end),
      end: st.day * 1440 + st.end, phase: 'prepared', outcome: '', shields: [], witnesses: a.attend.slice() };
    // Reserve the victim and venue; shift the whole plan in stable staging order.
    for (const prior of r.events) {
      if (terminal(prior) || prior.end <= e.from || (prior.victim !== e.victim && prior.place !== e.place)) continue;
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
    const next = Math.min(dawn, due?.deadline ?? Infinity);
    if (next > target) break;
    r.now = Math.max(r.now, next);
    if (due && due.deadline <= dawn) resolve(V, due);
    else { stepDay(V); syncEvents(V); }
  }
  r.now = target;
  for (const e of r.events) {
    if (terminal(e)) continue;
    const p = V.people[e.victim];
    if (!p?.alive || !p.present) cancel(V, e, 'participant unavailable');
    else if (r.now >= e.from) { e.phase = 'active'; p.locked = true; p.lockedAt = e.place; }
  }
  r.events = r.events.filter(e => !terminal(e) || e.end > r.now - 7 * 1440);
}
function resolve(V, e) {
  const p = V.people[e.victim];
  if (!p?.alive || !p.present) return cancel(V, e, 'participant unavailable');
  resolvePublic(V, e.id, '');
  p.locked = false;
  e.phase = 'resolved'; e.revision++;
  e.outcome = p.alive ? (p.present ? 'released' : 'exiled') : 'died';
}
export function cancel(V, e, reason) {
  V.pending = V.pending.filter(a => a.staging !== e.id);
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
  if (!p?.alive || !p.present || context.distance_dm > 25 || !Number.isFinite(context.distance_dm)) return fail('out of reach');
  if (request.verb !== 'free') return fail('unknown action');
  resolvePublic(V, e.id, 'free');
  p.present = true; p.locked = false; p.lockedAt = undefined;
  V.outlaws = V.outlaws.filter(x => x !== p.id);
  V.schedule = V.schedule.filter(s => !(s.kind === 'return' && s.who === p.id));
  r.residents[p.id] = { refuge_until: r.now + 2880, rescued_by: request.player_id, destination: 'far_woods' };
  for (const other of r.events) if (other !== e && other.victim === p.id && !terminal(other)) cancel(V, other, 'rescued');
  e.phase = 'resolved'; e.outcome = 'rescued'; e.revision++;
  const receipt = { accepted: true, action_id: id, event_id: e.id, verb: request.verb, at: r.now,
    outcome: e.outcome, revision: e.revision, player: request.player_id };
  r.receipts[id] = receipt; r.sequence++;
  const keys = Object.keys(r.receipts);
  if (keys.length > 256) delete r.receipts[keys[0]];
  return receipt;
}
// All future-affecting fields; maps remain ordered, object property order is immaterial.
export function canonical(V) {
  const ordered = v => v instanceof Map ? { __map: [...v].map(([k,x]) => [k, ordered(x)]) }
    : Array.isArray(v) ? v.map(ordered) : v && typeof v === 'object'
      ? Object.fromEntries(Object.keys(v).sort().filter(k => v[k] !== undefined).map(k => [k, ordered(v[k])])) : v;
  return JSON.stringify(ordered(V));
}
