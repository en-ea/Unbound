// Time storms: a storm folds a household's ground back to its own ancestors. The people who lived there are
// gone for the storm's length (lost in it), and the lineage's forebears from the tribal age stand in their
// place: their own names, their age's norms (theft merely shunned, sacrifice respected), their old feuds
// with the other lineages, and a speech the villagers barely follow. When the storm recedes the ancestors
// fade and the lost come home. An anchored story village is never touched.
//
// The world kernel decides when and where a storm strikes (stormHits); a village can also be given a plan
// for tests (opts.stormPlan). Nothing here runs unless a storm has struck, so a storm-free village behaves
// exactly as before (the golden hashes do not move).
import { key, pick, chance, clamp, idiv } from "./rng.mjs";
import * as C from "./content.mjs";
import { logEvent, nameOf } from "./events.mjs";
import { P, ageOf, opinion, setOpinion, addPerson, electAuthorities, die } from "./village.mjs";
import { giveBelief, addCrime } from "./crime.mjs";
import { lethalAllowed, noteAct } from "./director.mjs";
import { earn, remember, personEntry } from "./justice.mjs";

export function stormHits(V, hid, days, causes = []) {
  if (V.anchored) return -1; // anchored story villages are exempt
  const hh = V.households[hid];
  if (V.storms.some((s) => s.active && s.household === hid)) return -1;
  const k = key(key(V.base, P.STORM), V.day * 31 + hid);
  const lin = V.lineages[hh.lineage];
  const ev = logEvent(V, "storm", -1, -1, { household: hid, lineage: hh.lineage, days, phase: "strikes" }, causes,
    `the air over the ${hh.home} house folding like heat-haze; when it clears, strangers in furs stand at the door`);
  const st = { id: V.storms.length, household: hid, from: V.day, until: V.day + days, lost: [], ancestors: [], event: ev, active: true };
  V.storms.push(st);
  for (const m of hh.members) {
    const p = V.people[m];
    if (!p.alive || !p.present) continue;
    p.present = false; p.lostToStorm = st.id; p.locked = false;
    st.lost.push(m);
  }
  // the forebears: a couple in their prime, sometimes an old one, and children (tribal names, tribal ways)
  const father = addPerson(V, hid, 0, 26 + pick(key(k, 1), 14), -1, -1, { era: C.TRIBAL, quiet: true });
  const mother = addPerson(V, hid, 1, 22 + pick(key(k, 2), 14), -1, -1, { era: C.TRIBAL, quiet: true });
  V.people[father].spouse = mother; V.people[mother].spouse = father;
  const born = [father, mother];
  if (chance(key(k, 3), 500000)) born.push(addPerson(V, hid, pick(key(k, 4), 2), 50 + pick(key(k, 5), 15), -1, -1, { era: C.TRIBAL, quiet: true }));
  for (let c = 0; c < 1 + pick(key(k, 6), 3); c++) born.push(addPerson(V, hid, pick(key(k, 10 + c), 2), 3 + pick(key(k, 20 + c), 14), father, mother, { era: C.TRIBAL, quiet: true }));
  for (const id of born) {
    const a = V.people[id];
    a.ancestor = st.id;
    // a harder age: quicker tempers, deeper faith
    a.traits[C.TEMPER] = clamp(a.traits[C.TEMPER] + 12, 0, 100);
    a.traits[C.PIETY] = clamp(a.traits[C.PIETY] + 18, 0, 100);
    st.ancestors.push(id);
  }
  // the old feuds come with them; their descendants are strangers who share their blood
  for (const id of born) {
    for (const q of V.people) {
      if (!q.alive || !q.present || q.ancestor !== undefined) continue;
      if ((lin.feuds[V.lineages[q.lineage].id] ?? 0) >= 6) setOpinion(V, id, q.id, -45);
      else if (q.lineage === hh.lineage) setOpinion(V, id, q.id, 20);
    }
  }
  V.fear = clamp(V.fear + 200, 0, 1000);
  electAuthorities(V);
  logEvent(V, "arrival", father, mother, { ancestors: born.length, storm: st.id }, [ev], `${nameOf(V, father)} of the ${C.LINEAGE_NAMES[C.TRIBAL][hh.lineage % C.LINEAGE_NAMES[C.TRIBAL].length]}, looking at the houses as if they were a dream`);
  return st.id;
}

export function stormRecedes(V, st) {
  st.active = false;
  for (const id of st.ancestors) {
    const a = V.people[id];
    a.faded = true; // the exiled among them fade too, wherever they are
    if (!a.alive || !a.present) continue;
    a.present = false; a.locked = false;
  }
  V.outlaws = V.outlaws.filter((id) => !st.ancestors.includes(id));
  // their open cases go cold: the accused are not of this world any more
  for (const c of V.crimes) if (!c.closed && st.ancestors.includes(c.culprit)) c.closed = true;
  V.schedule = V.schedule.filter((s) => !(st.ancestors.includes(s.who) || (s.case !== undefined && st.ancestors.includes(V.cases[s.case].accused))));
  for (const id of st.lost) {
    const p = V.people[id];
    if (!p.alive) continue;
    p.present = true; p.lostToStorm = undefined;
  }
  electAuthorities(V);
  logEvent(V, "storm", -1, -1, { household: st.household, phase: "recedes", storm: st.id }, [st.event],
    `morning mist over the ${V.households[st.household].home} house; the strangers gone, a ring of fire-stones on the floor, and the family home, blinking`);
}

// ---------- each day of a storm: its end, and the old gods ----------
export function stormDay(V) {
  for (const s of V.stormPlan) if (s.day === V.day) stormHits(V, s.household, s.days);
  for (const st of V.storms) {
    if (!st.active) continue;
    if (V.day >= st.until) { stormRecedes(V, st); continue; }
    riteToday(V, st);
  }
}

// The forebears read the strange world as the gods' anger and answer it the old way: an offering at the
// stone. The one they fear most is seized at dusk and held overnight (the window in which kin, or the
// player, can free them); at dawn the rite is done. To the village it is murder, and it is tried as one.
function riteToday(V, st) {
  if (V.tier === "store") return; // the store build has no rites
  if (V.schedule.some((s) => s.kind === "rite") || st.offered) return; // one offering satisfies them
  let leader = -1;
  for (const id of st.ancestors) {
    const a = V.people[id];
    if (!a.alive || !a.present || a.locked || ageOf(V, a) < 25) continue;
    if (leader < 0 || a.traits[C.PIETY] > V.people[leader].traits[C.PIETY]) leader = id;
  }
  if (leader < 0) return;
  const L = V.people[leader];
  const k = key(key(key(V.base, P.STORM), V.day), 0x417e + st.id);
  const need = 100 + idiv(V.fear, 4) + idiv(V.hardship, 5) + L.traits[C.PIETY] - 90;
  if (need <= 0 || !lethalAllowed(V) || !chance(k, need * 120 * V.pace)) return;
  // the offering: an adult of this age, not of their blood, the one they like least (never a child)
  let victim = -1, worst = 1000;
  for (const q of V.people) {
    if (!q.alive || !q.present || q.ancestor !== undefined || q.locked || ageOf(V, q) < 16 || q.lineage === L.lineage) continue;
    const o = opinion(V, leader, q.id) + pick(key(k, 100 + q.id), 20);
    if (o < worst || (o === worst && q.id < victim)) { worst = o; victim = q.id; }
  }
  if (victim < 0) return;
  const q = V.people[victim];
  q.locked = true; q.lockedAt = "stake";
  const ev = logEvent(V, "rite", leader, victim, { rite: "seized", storm: st.id }, [st.event],
    `${nameOf(V, victim)} dragged towards the stake at dusk by strangers in furs, drums starting`);
  V.fear = clamp(V.fear + 150, 0, 1000);
  const planned = { day: V.day + 1, kind: "rite", who: leader, other: victim, storm: st.id, causes: [ev] };
  if (V.runtime) { riteAct(V, planned); st.offered = true; }
  else V.schedule.push(planned);
}

export function riteAct(V, s) {
  const L = V.people[s.who], q = V.people[s.other];
  if (V.runtime && !V.runtime.resolving) {
    if (!q.alive || !q.present || !L.alive || !L.present) return;
    const st = V.storms[s.storm];
    const worshippers = st.ancestors.filter(id => V.people[id].alive && V.people[id].present);
    const staging = makeRiteStaging(V, L.id, q.id, worshippers, 'pending', -1, s.causes[0]);
    staging.day = s.day;
    // The night window and the restrained body begin together, before the dawn rite.
    staging.start = -180;
    staging.beats[0].at = -180;
    V.runtime.rites.push({ staging: staging.id, s: { ...s }, victim: q.id, deadline: 360 });
    return;
  }
  q.locked = false;
  if (!q.alive || !q.present || !L.alive || !L.present) return;
  const k = key(key(key(V.base, P.STORM), V.day), 0x5ac + q.id);
  const st = V.storms[s.storm];
  const worshippers = st.ancestors.filter((id) => V.people[id].alive && V.people[id].present);
  // kin try to cut them free in the night (the player's window, taken by the simulation when no player is there)
  for (const r of V.people) {
    if (!r.alive || !r.present || r.ancestor !== undefined || r.id === q.id || ageOf(V, r) < 16 || r.lineage !== q.lineage) continue;
    const nerve = r.traits[C.BOLD] + r.traits[C.COMPASSION] - 80;
    if (nerve > 0 && chance(key(k, 700 + r.id), nerve * 6000)) {
      const ev = logEvent(V, "rite", L.id, q.id, { rite: "sacrifice", outcome: "rescued", rescuer: r.id }, s.causes,
        `ropes cut at the stake before dawn; ${nameOf(V, r.id)} and ${nameOf(V, q.id)} running for the houses`);
      earn(V, r.id, "rescuer");
      setOpinion(V, L.id, r.id, -80); remember(L, r.id, ev);
      V.events[ev].data.staging = makeRiteStaging(V, L.id, q.id, worshippers, "rescued", r.id, ev).id;
      return;
    }
  }
  // the offering (only ever an adult; the heart kept for the fire in the private build, as their fathers did)
  const heart = V.tier !== "store" && chance(key(k, 9), 400000);
  const ev = logEvent(V, "rite", L.id, q.id, { rite: "sacrifice", outcome: "carried_out", heart }, s.causes,
    `drums at the stake before dawn, strangers painted with ash, and a still shape on the stone`);
  noteAct(V, "sacrifice");
  st.offered = true;
  V.stats.acts.sacrifice = (V.stats.acts.sacrifice ?? 0) + 1;
  die(V, q.id, "sacrificed", [ev], "a still shape on the stone at dawn");
  V.events[ev].data.staging = makeRiteStaging(V, L.id, q.id, worshippers, "carried_out", -1, ev).id;
  // to the village it is murder, done openly: every grown member of the dead's household saw the drums
  const c = addCrime(V, "sacrifice", L.id, q.household, q.id, 300, "stake", "", [ev], "ash and blood on the stone", { motive: "rite" });
  c.discovered = true;
  c.discoveryEvent = ev;
  const hh = V.households[q.household];
  for (const m of hh.members) {
    const w = V.people[m];
    if (!w.alive || !w.present || ageOf(V, w) < 14) continue;
    giveBelief(V, m, c.id, L.id, 950, m, 0, -1);
    setOpinion(V, m, L.id, -90); remember(w, L.id, ev);
  }
  if (V.authority >= 0) giveBelief(V, V.authority, c.id, L.id, 900, V.authority, 0, -1);
  V.fear = clamp(V.fear + 200, 0, 1000);
}

function makeRiteStaging(V, leader, victim, worshippers, outcome, rescuer, ev) {
  const start = 300, beats = [];
  const B = (at, who, d, slot = -1, target = -1, anim = "", prop = "") => beats.push({ at, who, do: d, slot, target, anim, prop });
  B(start, victim, "lock", -1, -1, "Idle");
  const ring = worshippers.filter((id) => id !== leader && ageOf(V, V.people[id]) >= 14);
  ring.forEach((id, i) => { B(start + i, id, "walk_to", i, -1, "Walk"); B(start + 20 + i, id, "stand", i, -1, "Idle_FoldArms", "torch"); });
  B(start, leader, "walk_to", -1, victim, "Walk_Formal");
  B(start + 30, leader, "gesture", -1, victim, "Spell_Simple_Idle");
  if (outcome === "rescued") {
    B(start + 10, rescuer, "walk_to", -1, victim, "Jog_Fwd");
    B(start + 14, rescuer, "release", -1, victim, "Interact");
    B(start + 15, victim, "leave", -1, -1, "Jog_Fwd");
    B(start + 16, rescuer, "leave", -1, -1, "Jog_Fwd");
  } else {
    B(start + 60, victim, "fall", -1, -1, "Death01");
  }
  // the village wakes to the drums: the nearest dozen come, and stand back appalled (outer slots, after the ring)
  const onlookers = V.people.filter((p) => p.alive && p.present && p.ancestor === undefined && p.id !== victim && p.id !== rescuer && ageOf(V, p) >= 14)
    .map((p) => p.id).sort((a, b) => a - b).slice(0, 12);
  onlookers.forEach((id, i) => { B(start + 15 + i, id, "walk_to", ring.length + i, -1, "Jog_Fwd"); B(start + 35 + i, id, "stand", ring.length + i, -1, "Idle_No"); });
  const end = start + 90;
  ring.forEach((id, i) => B(end + i, id, "leave", -1, -1, "Walk"));
  onlookers.forEach((id, i) => B(end + 5 + i, id, "leave", -1, -1, "Walk"));
  B(end, leader, "leave", -1, -1, "Walk");
  beats.forEach((b, i) => { b.seq = i; });
  beats.sort((a, b) => a.at - b.at || a.who - b.who || a.seq - b.seq);
  for (const b of beats) delete b.seq;
  const ids = [victim, leader, ...ring, ...onlookers, ...(rescuer >= 0 ? [rescuer] : [])];
  const staging = {
    id: V.stagingCount++, kind: "sacrifice", place: "stake", start, end: end + ring.length + onlookers.length + 10,
    phases: [{ name: "night", from: start - 480, to: start, rescue: true }, { name: "rite", from: start, to: start + 60, rescue: true }, { name: "end", from: start + 60, to: end + ring.length + onlookers.length + 10, rescue: false }],
    roles: { victim, accuser: leader, authority: leader, crowd: [...ring, ...onlookers] },
    beats, outcome, cause: [`rite: ${V.events[ev].cue}`], cue: V.events[ev].cue, day: V.day, people: ids.map((id) => personEntry(V, id)),
  };
  V.stagings.push(staging);
  if (V.stagings.length > 300) V.stagings.shift();
  return staging;
}
