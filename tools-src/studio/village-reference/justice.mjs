// Justice: trials (witnesses, the confession trade, ordeals, trial by combat), the law choosing a public
// act, the director's veto on bloodshed, the crowd as a threshold cascade (Granovetter) that decides how
// far pelting goes and whether the crowd turns, the aftermath (marks, exile, feuds, funerals), the guilty
// conscience that can make a saint of the wrongly hanged, and the stagings the stage plays.
import { key, ppm, pick, chance, clamp, idiv } from "./rng.mjs";
import * as C from "./content.mjs";
import { logEvent, nameOf, fullName } from "./events.mjs";
import { P, YEAR, ageOf, opinion, setOpinion, isKin, die, living } from "./village.mjs";
import { giveBelief } from "./crime.mjs";
import { lethalAllowed, noteAct } from "./director.mjs";

export function authorityCapacity(V) {
  if (V.authority < 0) return 0;
  const e = V.people[V.authority];
  if (!e.alive || !e.present) return 0;
  let sum = 0, n = 0;
  for (const q of V.people) {
    if (!q.alive || !q.present || q.id === e.id || ageOf(V, q) < 16) continue;
    sum += opinion(V, q.id, e.id); n++;
  }
  const respect = n ? idiv(sum * 10 + 1000 * n, 2 * n) : 500; // opinion -100..100 -> 0..1000
  return clamp(idiv(respect * 3 + e.traits[C.BOLD] * 10, 4), 0, 1000);
}

export function scheduleTrial(V, cs) {
  V.schedule.push({ day: V.day + 1, kind: "trial", case: cs.id, causes: [cs.event] });
}
export function scheduleMob(V, cs) {
  V.stats.mobs++;
  V.schedule.push({ day: V.day, kind: "public", act: "mob", case: cs.id, causes: [cs.event], minute: 1200 });
}

// ---------- today's scheduled events ----------
export function runScheduled(V) {
  // due today or overdue (a mob raised after today's schedule ran gathers the next day)
  const today = V.schedule.filter((s) => s.day <= V.day);
  V.schedule = V.schedule.filter((s) => s.day > V.day);
  // (the final tie-break is the order they were scheduled in: ports must not rely on a stable sort)
  const seq = new Map(today.map((s, i) => [s, i]));
  today.sort((a, b) => ORDER.indexOf(a.kind) - ORDER.indexOf(b.kind) || (a.case ?? a.who ?? 0) - (b.case ?? b.who ?? 0) || seq.get(a) - seq.get(b));
  for (const s of today) {
    if (s.kind === "trial") trial(V, s);
    else if (s.kind === "public") publicAct(V, s);
    else if (s.kind === "funeral") funeral(V, s);
    else if (s.kind === "wedding") gathering(V, "wedding", s);
    else if (s.kind === "festival") gathering(V, "festival", s);
    else if (s.kind === "unlock") { const p = V.people[s.who]; p.locked = false; }
    else if (s.kind === "return") comeHome(V, s);
  }
}
const ORDER = ["unlock", "funeral", "trial", "public", "wedding", "festival"];

// ---------- the trial ----------
function trial(V, s) {
  const cs = V.cases[s.case];
  const c = V.crimes[cs.crime];
  const accused = V.people[cs.accused];
  if (!accused.alive || !accused.present) { c.closed = true; return; }
  const k = key(key(V.base, P.TRIAL), cs.id);
  V.stats.trials++;
  const guilty = cs.accused === c.culprit && !c.falseAccusation;
  const judge = V.authority !== cs.accused ? V.authority : V.priest !== cs.accused ? V.priest : -1;
  const bench = judge >= 0 && judge === V.priest && judge !== V.authority ? "priest" : "elder";
  const trialEv = logEvent(V, "trial", judge, cs.accused, { case: cs.id, act: c.act, bench }, [cs.event], `the ${bench}'s bench carried into the square`);
  const causes = [trialEv];
  let verdict = "guilty", confessed = false, via = "witnesses";
  // the confession trade (Salem): confess and be spared the worst; the guilty and the terrified confess
  const pressure = idiv(cs.evidence, 20) + idiv(V.fear, 20);
  const confessOdds = guilty
    ? (accused.traits[C.HONESTY] + accused.traits[C.PIETY]) * 1500 + pressure * 2000
    : (V.fear > 600 && accused.traits[C.BOLD] < 30 ? (100 - accused.traits[C.BOLD]) * 1200 : 0);
  if (chance(key(k, 1), confessOdds)) {
    confessed = true; via = "confession";
    causes.push(logEvent(V, "confession", cs.accused, V.authority, { case: cs.id, true: guilty }, [trialEv],
      `${nameOf(V, cs.accused)} on their knees before the elder`));
    earn(V, cs.accused, "confessed");
  } else if (V.age === C.VILLAGE && (c.act === "sorcery" || cs.evidence < 1000) && c.act !== "murder") {
    // the ordeal: the millpond. Most who went in came out 'innocent' (Várad: 62.5%)
    via = "ordeal";
    const acquit = chance(key(k, 2), 600000);
    causes.push(logEvent(V, "ordeal", cs.accused, V.authority, { case: cs.id, acquit }, [trialEv],
      acquit ? `${nameOf(V, cs.accused)} sinking, then hauled out: innocent` : `${nameOf(V, cs.accused)} floating on the millpond: guilty`));
    if (acquit) verdict = "acquitted";
  } else if (V.age === C.VILLAGE && c.act === "murder" && accused.traits[C.BOLD] >= 60) {
    // trial by combat: the accused against the accuser's champion (the player can be a champion)
    via = "combat";
    const champ = champion(V, cs.accuser, cs.accused);
    const might = (id) => V.people[id].traits[C.BOLD] + (C.ROLES[V.people[id].role]?.strong ? 40 : 0) + pick(key(k, 3 + id), 60);
    const won = might(cs.accused) > might(champ);
    causes.push(logEvent(V, "ordeal", cs.accused, champ, { case: cs.id, combat: true, won }, [trialEv],
      `steel in the square: ${nameOf(V, cs.accused)} against ${nameOf(V, champ)}`));
    if (won) verdict = "acquitted";
    else {
      noteAct(V, "trial_by_combat");
      finishCase(V, cs, c, "trial_by_combat", "carried_out", causes, false);
      const dv = die(V, cs.accused, "combat", causes, "a body carried from the ring");
      earn(V, champ, "champion");
      return;
    }
  } else {
    // judged on the witnesses: a law-minded elder needs more
    const need = 500 + (V.people[judge]?.values.law ?? 60) * 8;
    if (cs.evidence < need) verdict = "acquitted";
  }
  if (verdict === "acquitted") {
    V.stats.outcomes.acquitted = (V.stats.outcomes.acquitted ?? 0) + 1;
    logEvent(V, "verdict", V.authority, cs.accused, { case: cs.id, verdict, via }, causes, `${nameOf(V, cs.accused)} walking free, the accuser staring after`);
    setOpinion(V, cs.accused, cs.accuser, opinion(V, cs.accused, cs.accuser) - 40);
    c.closed = true;
    return;
  }
  // the law's list for this act and age, lenient to harsh
  const list = C.LAW[c.act][V.age];
  if (!list.length) { c.closed = true; return; }
  const elder = V.people[V.authority];
  let idx = idiv(C.ACTS[c.act].severity, 3) + accused.offences + idiv(V.hardship + V.fear, 450)
    - idiv(elder?.values.mercy ?? 40, 45) - (confessed ? 1 : 0);
  idx = clamp(idx, 0, list.length - 1);
  let act = list[idx];
  // variety (no act twice in a row) and the director's veto on blood
  if (V.director.last[V.director.last.length - 1] === act && idx > 0 && chance(key(k, 9), 500000)) act = list[--idx];
  let vetoed = false;
  const asked = act;
  // the gravest crimes are not commuted for pacing: the condemned is held until the director allows blood
  const hold = C.PUBLIC[act].lethal && C.ACTS[c.act].severity >= 8;
  while (!hold && C.PUBLIC[act].lethal && !lethalAllowed(V) && idx > 0) { act = list[--idx]; vetoed = true; }
  if (!hold && C.PUBLIC[act].lethal && !lethalAllowed(V)) { act = "exile"; vetoed = true; }
  const vEv = logEvent(V, "verdict", V.authority, cs.accused, { case: cs.id, verdict, via, act, vetoed, asked: vetoed ? asked : "" }, causes,
    vetoed ? "the elder, weary of blood, names a lesser sentence" : `the elder naming the sentence: ${act.replace("_", " ")}`);
  if (vetoed) earn(V, V.authority, "merciful");
  accused.offences++;
  // a kinsman may try a rescue the night before a killing (headless stand-in for the player's rescue window)
  V.schedule.push({ day: V.day + 1, kind: "public", act, case: cs.id, causes: [vEv], confessed, vetoed, hold, waited: 0 });
  if (hold) { accused.locked = true; accused.lockedAt = "pillory"; }
}

function champion(V, accuser, accused) {
  let best = accuser, s = -1;
  for (const q of V.people) {
    if (!q.alive || !q.present || q.id === accused || !isKin(V, q.id, accuser) || ageOf(V, q) < 18) continue;
    const m = q.traits[C.BOLD] + (C.ROLES[q.role]?.strong ? 40 : 0);
    if (m > s) { s = m; best = q.id; }
  }
  return best;
}

// close kin: household, spouse, parents and children, siblings (not the whole lineage)
const closeKin = (V, a, b) => {
  const pa = V.people[a], pb = V.people[b];
  return pa.household === pb.household || pa.spouse === b || pa.father === b || pa.mother === b || pb.father === a || pb.mother === a
    || (pa.father >= 0 && pa.father === pb.father) || (pa.mother >= 0 && pa.mother === pb.mother);
};
// a grudge remembers the event that made it (the tales follow it; revenge cites it); at most 4 kept
export function remember(p, o, ev) {
  p.grudges.delete(o);
  p.grudges.set(o, ev);
  if (p.grudges.size > 4) p.grudges.delete(p.grudges.keys().next().value);
}

const def0 = (kind) => C.PUBLIC[kind];

// ---------- the public act and its crowd ----------
function publicAct(V, s) {
  const cs = V.cases[s.case];
  const c = V.crimes[cs.crime];
  const victim = V.people[cs.accused];
  const kind = s.act;
  if (!victim.alive || !victim.present) { c.closed = true; return; }
  // held for the day the director allows (at most two months; then the sentence is commuted to exile)
  if (s.hold && def0(kind).lethal && !lethalAllowed(V)) {
    if (s.waited < 60) { V.schedule.push({ ...s, day: V.day + 1, waited: s.waited + 1 }); return; }
    s = { ...s, act: "exile", vetoed: true, hold: false };
    return publicAct(V, s);
  }
  if (s.hold) victim.locked = false;
  const k = key(key(V.base, P.CROWD), cs.id * 31 + V.day);
  const def = C.PUBLIC[kind];
  const causes = [...s.causes];
  // a kinsman's rescue by night before a killing (the player's window, taken by the simulation when no
  // player is there): bold, loving kin try it sometimes
  if ((def.lethal || kind === "branding") && kind !== "mob") {
    for (const q of V.people) {
      if (!q.alive || !q.present || !isKin(V, q.id, victim.id) || q.id === victim.id || ageOf(V, q) < 16) continue;
      const nerve = q.traits[C.BOLD] + q.traits[C.COMPASSION] - 85;
      if (nerve > 0 && chance(key(k, 700 + q.id), nerve * (closeKin(V, q.id, victim.id) ? 6000 : 2500))) {
        const ev = logEvent(V, "public_act", victim.id, q.id, { kind, outcome: "rescued", case: cs.id }, causes,
          `an empty cell at dawn, a rope cut, ${nameOf(V, q.id)} missing from their bed`);
        earn(V, q.id, "rescuer");
        exile(V, victim.id, [ev], true, c.id);
        finishCase(V, cs, c, kind, "rescued", [ev], false);
        return;
      }
    }
  }
  // the crowd: everyone old enough comes, except kin who cannot bear to watch
  const attend = [];
  for (const q of V.people) {
    if (!q.alive || !q.present || q.id === victim.id || q.locked) continue;
    if (V.tier === "store" && ageOf(V, q) < 12 && def.lethal) continue;
    if (isKin(V, q.id, victim.id) && q.traits[C.COMPASSION] > 70) continue;
    attend.push(q.id);
  }
  const n = attend.length;
  const anger = new Map(), sympathy = new Map();
  for (const id of attend) {
    const q = V.people[id];
    const rating = C.ACTS[c.act].norms[q.era];
    let a = [-200, -100, 0, 120, 280, 450][rating] + Math.max(0, -opinion(V, id, victim.id)) * 3 + idiv(V.hardship + V.fear, 6) + q.traits[C.TEMPER];
    let sy = Math.max(0, opinion(V, id, victim.id)) * 4 + q.traits[C.COMPASSION] * 2 + (isKin(V, id, victim.id) ? 500 : 0) + (cs.evidence < 1000 ? 150 : 0);
    if (q.secret.includes(c.id)) sy += 400; // the real culprit, watching someone else pay
    sy += Math.max(0, def.shame * 50 - C.ACTS[c.act].severity * 70); // too much for too little (a brand for a goose)
    if (victim.clearedDay >= 0) sy += 150; // wronged once before
    if (!s.confessed && cs.evidence < 1200) sy += 120; // they never admitted it, and the case was thin
    if (isKin(V, id, cs.accuser)) a += 150;
    anger.set(id, a); sympathy.set(id, sy);
  }
  let totalA = 0, totalS = 0;
  for (const id of attend) { totalA += anger.get(id); totalS += sympathy.get(id); }
  const turned = n > 0 && totalS * 10 > totalA * 11 && !(kind === "mob" && V.fear > 800);
  // the cascade: each joins once enough others already throw (threshold from their own balance)
  const wants = attend.filter((id) => anger.get(id) > sympathy.get(id));
  const thr = new Map(wants.map((id) => [id, clamp(idiv((sympathy.get(id) - anger.get(id) + 700) * n, 1400), 0, n)]));
  let throwing = [];
  for (let round = 0; round < n + 1; round++) {
    const next = wants.filter((id) => thr.get(id) <= throwing.length);
    if (next.length === throwing.length) break;
    throwing = next;
  }
  const meanA = n ? idiv(totalA, n) : 0;
  let level = throwing.length === 0 ? 0 : throwing.length * 100 >= 50 * n && meanA > 550 ? 3 : throwing.length * 100 >= 30 * n && meanA > 350 ? 2 : 1;
  if (!["pillory", "stocks", "stoning", "mob", "exile", "branding", "scapegoat"].includes(kind) && level > 1) level = 1;
  // outcome
  // the ending: the crowd can turn; a confession or the director's veto is a spared or commuted ending
  let outcome = s.confessed ? "confessed_spared" : s.vetoed ? "commuted" : "carried_out";
  if (turned && kind !== "fine") outcome = "crowd_turned";
  const lethalByStones = (kind === "pillory" || kind === "stocks") && level === 3 && lethalAllowed(V) && chance(key(k, 5), 250000);
  const staging = makeStaging(V, cs, c, kind, attend, throwing, level, outcome, lethalByStones, anger, sympathy, k);
  const ev = logEvent(V, "public_act", victim.id, cs.accuser, { kind, outcome, case: cs.id, level, throwers: throwing.length, crowd: n, staging: staging.id },
    causes, staging.cue);
  V.stats.acts[kind] = (V.stats.acts[kind] ?? 0) + 1;
  V.stats.outcomes[outcome] = (V.stats.outcomes[outcome] ?? 0) + 1;
  noteAct(V, kind);
  if (throwing.length && (def.lethal || lethalByStones)) earn(V, throwing[0], "mob_leader");
  if (outcome === "crowd_turned") {
    logEvent(V, "crowd_turned", victim.id, cs.accuser, { case: cs.id }, [ev], "the crowd closing round the condemned instead of the stones");
    for (const id of attend) if (sympathy.get(id) > anger.get(id)) setOpinion(V, id, cs.accuser, opinion(V, id, cs.accuser) - 25);
    finishCase(V, cs, c, kind, outcome, [ev], false);
    return;
  }
  // the effects of each act
  const shame = C.PUBLIC[kind].shame;
  for (const id of attend) setOpinion(V, id, victim.id, opinion(V, id, victim.id) - shame * 3);
  if (kind === "fine") V.households[victim.household].food -= 10;
  if (kind === "pillory" || kind === "stocks") {
    victim.stress = clamp(victim.stress + 120, 0, 400);
    victim.marks.pilloried = (victim.marks.pilloried ?? 0) + 1;
    if (victim.marks.pilloried >= 2) earn(V, victim.id, "pilloried");
    if (level === 3 && !lethalByStones) earn(V, victim.id, "survivor");
  }
  if (kind === "branding") { victim.marks.branded = 1; earn(V, victim.id, "branded"); }
  if (kind === "exile" || kind === "scapegoat") exile(V, victim.id, [ev], false, c.id);
  // the punished's close kin never forgive the accuser (and blame the elder): the root of revenge
  if (!["fine", "ordeal"].includes(kind)) {
    for (const q of V.people) {
      if (!q.alive || !q.present || q.id === victim.id || ageOf(V, q) < 14 || !closeKin(V, q.id, victim.id)) continue;
      if (cs.accuser !== q.id) { setOpinion(V, q.id, cs.accuser, opinion(V, q.id, cs.accuser) - shame * 9); remember(q, cs.accuser, ev); }
      if (V.authority >= 0 && V.authority !== q.id) setOpinion(V, q.id, V.authority, opinion(V, q.id, V.authority) - shame * 4);
    }
  }
  const killing = { hanging: "hanged", bonfire: "burned", stoning: "stoned", mob: "stoned", sacrifice: "sacrificed" }[kind];
  if (killing || lethalByStones) {
    die(V, victim.id, killing ?? "stoned", [ev], kind === "bonfire" ? "smoke over the field at dusk" : kind === "hanging" ? "a shape turning on the gallows" : "stones in the dust");
    if (killing === "hanged") earn(V, victim.id, "hanged");
    if (killing === "burned") earn(V, victim.id, "burned");
  }
  finishCase(V, cs, c, kind, outcome, [ev], Boolean(killing || lethalByStones || kind === "exile" || kind === "branding"));
}

function finishCase(V, cs, c, kind, outcome, causes, grave) {
  c.closed = true;
  c.punished = cs.accused;
  c.punishEvent = causes[0];
  const wrongful = cs.accused !== c.culprit || c.falseAccusation;
  // the real culprit carries it if someone else paid (guilt grows; it can break them)
  if (wrongful && !c.falseAccusation && outcome !== "crowd_turned" && outcome !== "rescued") {
    const real = V.people[c.culprit];
    if (real.alive && real.present) real.guilt = Math.max(real.guilt, 1);
    c.wrongfulPunishment = true;
  }
  if (c.falseAccusation && outcome !== "crowd_turned" && outcome !== "rescued") {
    c.wrongfulPunishment = true;
    // no one did it: the accuser may come to doubt what they 'saw' (Ann Putnam's apology, 1706)
    const acc = V.people[cs.accuser];
    if (acc.alive && acc.present && acc.traits[C.COMPASSION] >= 55) { acc.guilt = Math.max(acc.guilt, 1); acc.secret.push(c.id); }
  }
  // kin resent a grave punishment: a feud between the lineages, passed down
  if (grave) {
    const a = V.people[cs.accused].lineage, b = V.people[cs.accuser].lineage;
    if (a !== b && a >= 0 && b >= 0) {
      const f = V.lineages[a].feuds;
      f[b] = (f[b] ?? 0) + C.PUBLIC[kind].shame;
      if (f[b] >= 12 && !f["_logged" + b]) {
        f["_logged" + b] = 1;
        logEvent(V, "feud", a, b, { lineages: [a, b] }, causes, `the ${V.lineages[a].name} turning their backs on the ${V.lineages[b].name} at the well`);
      }
      for (const q of V.people) if (q.alive && q.lineage === a) for (const r of V.people) if (r.alive && r.lineage === b) setOpinion(V, q.id, r.id, opinion(V, q.id, r.id) - 12);
    }
  }
}

export function exile(V, id, causes, fled, crime) {
  const p = V.people[id];
  p.exiledFor = crime;
  p.present = false; p.locked = false;
  p.exiledDay = V.day;
  V.outlaws.push(id);
  earn(V, id, "exiled");
  logEvent(V, "exile", id, -1, { fled }, causes, fled ? "footprints leading into the woods" : `${nameOf(V, id)} walking out of the south gate with one bundle`);
}

// ---------- conscience: the real culprit breaks, and the wronged are honoured ----------
export function confessGuilt(V, pid, deathbed = false) {
  const p = V.people[pid];
  p.guilt = 0;
  for (const cid of p.secret) {
    const c = V.crimes[cid];
    if (!c.wrongfulPunishment || c.exonerated) continue;
    c.exonerated = true;
    V.stats.exonerations++;
    const recant = c.falseAccusation;
    const conf = logEvent(V, "confession", pid, c.punished, { crime: cid, late: true, deathbed, recant }, [c.event, c.punishEvent].filter((x) => x !== undefined),
      deathbed ? `the priest bending over ${nameOf(V, pid)}'s bed, then going white` : `${nameOf(V, pid)} weeping at the shrine, telling the priest everything`);
    const wronged = V.people[c.punished];
    // the village is ashamed: the wronged is no longer counted as an offender, and no one suspects them for years
    wronged.offences = Math.max(0, wronged.offences - 1);
    wronged.clearedDay = V.day;
    const ex = logEvent(V, "exoneration", c.punished, pid, { crime: cid }, [conf], `the elder striking ${nameOf(V, c.punished)}'s name from the reckoning`);
    // the truth wipes the wrong belief from every mind that held it
    for (const q of V.people) q.beliefs = q.beliefs.filter((b) => !(b.crime === cid && b.culprit !== pid));
    // the wrongly exiled are sent for and come home; the wrongly killed are honoured (Girard: made sacred)
    if (wronged.alive && !wronged.present && wronged.exiledFor === cid) V.schedule.push({ day: V.day + 7 + pick(key(V.base, 0x9e70 + cid), 20), kind: "return", who: wronged.id, causes: [ex] });
    if (!wronged.alive) {
      V.shrines.push({ person: wronged.id, day: V.day });
      earn(V, wronged.id, "venerated");
      logEvent(V, "veneration", wronged.id, -1, { crime: cid }, [ex], `flowers and candles at ${nameOf(V, wronged.id)}'s grave, strangers kneeling`);
      for (const q of V.people) if (q.alive) q.stress = clamp(q.stress - 20, 0, 400);
    }
    // the accuser who pressed it falls in everyone's eyes
    const cs = V.cases.find((x) => x.crime === cid && x.accused === c.punished);
    if (cs) {
      earn(V, cs.accuser, "false_accuser");
      for (const q of V.people) if (q.alive && q.id !== cs.accuser) setOpinion(V, q.id, cs.accuser, opinion(V, q.id, cs.accuser) - 20);
    }
    // the confessor is now tried for it: their own word, and the priest who heard it
    if (deathbed) continue;
    const hearer = V.authority >= 0 && V.authority !== pid ? V.authority : V.priest;
    if (hearer >= 0 && hearer !== pid) {
      giveBelief(V, hearer, cid, pid, 1000, pid, 0, pid);
      giveBelief(V, hearer, cid, pid, 800, V.priest >= 0 ? V.priest : hearer, 1, V.priest);
      if (c.household < 0 || !V.households[c.household].members.includes(hearer)) c.household = V.people[hearer].household;
    }
    c.caseOpen = false; c.closed = false; c.falseAccusation = false; c.discovered = true;
  }
  p.secret = [];
}

// The wrongly exiled come home: thinner, older, owed something; the village makes amends.
function comeHome(V, s) {
  const p = V.people[s.who];
  if (!p.alive || p.present) return;
  p.present = true;
  V.outlaws = V.outlaws.filter((x) => x !== p.id);
  const hh = V.households[p.household];
  if (!hh.members.includes(p.id)) hh.members.push(p.id);
  hh.food += 20;
  for (const q of V.people) if (q.alive && q.present && q.id !== p.id) setOpinion(V, q.id, p.id, opinion(V, q.id, p.id) + 25);
  p.epithets = p.epithets.filter((e) => e !== C.EPITHETS.exiled);
  earn(V, p.id, "returned");
  logEvent(V, "return", p.id, -1, {}, s.causes, `${nameOf(V, p.id)} at the south gate, thinner and older, and the village coming out to meet them`);
}

// ---------- gatherings that are not punishments: funerals, weddings, festivals ----------
function funeral(V, s) {
  const dead = V.people[s.who];
  const mourners = V.people.filter((q) => q.alive && q.present && (isKin(V, q.id, s.who) || opinion(V, q.id, s.who) > 30));
  for (const q of mourners) q.stress = clamp(q.stress - 70, 0, 400);
  logEvent(V, "funeral", s.who, -1, { mourners: mourners.length }, s.causes, `a slow line of ${mourners.length} to the shrine behind ${nameOf(V, s.who)}`);
}

function gathering(V, kind, s) {
  const k = key(key(V.base, P.FESTIVAL), V.day);
  const folk = living(V).filter((q) => !q.locked);
  for (const q of folk) q.stress = clamp(q.stress - (kind === "festival" ? 60 : 30), 0, 400);
  if (kind === "festival") V.fear = clamp(V.fear - 120, 0, 1000);
  // a festival warms old grudges a little: pairs dance, drink, and some make peace
  for (let i = 0; i < folk.length; i++) {
    const a = folk[i].id, b = folk[pick(key(k, i), folk.length)].id;
    if (a !== b) { setOpinion(V, a, b, opinion(V, a, b) + 6); setOpinion(V, b, a, opinion(V, b, a) + 6); }
  }
  if (kind === "festival") V.stats.festivals++;
  logEvent(V, kind === "wedding" ? "wedding" : "festival", s.who ?? -1, s.other ?? -1, { name: s.name ?? "" }, s.causes ?? [],
    kind === "wedding" ? "fiddles and a ring of dancers in the square" : `garlands, a bonfire of the good kind, dancing for ${s.name ?? "the feast"}`);
  if (kind === "festival") makeFestivalStaging(V, folk, s.name ?? "the feast", k);
}

// ---------- stagings: what the stage plays (staging.gd contract) ----------
const PROP_BY_LEVEL = [[], ["cabbage", "turnip"], ["mud"], ["stone"]];
const STANCE_ANIM = (a, sy) => (a > sy + 200 ? "Idle_No" : sy > a + 200 ? "Idle_Talking" : "Idle_FoldArms");

function makeStaging(V, cs, c, kind, attend, throwing, level, outcome, lethalByStones, anger, sympathy, k) {
  const def = C.PUBLIC[kind];
  const place = def.place;
  const start = kind === "bonfire" ? 720 : kind === "mob" ? 1200 : 480;
  const victim = cs.accused;
  // walking takes time: 1.3 m/s is 2.6 m (26 dm) per game minute; each arrives, then takes a stance
  const walkMin = (id) => {
    const from = V.layout.pos[V.people[id].locked ? V.people[id].lockedAt ?? "pillory" : V.households[V.people[id].household].home] ?? [0, 0];
    const to = V.layout.pos[place] ?? [0, 0];
    return 2 + idiv(Math.abs(from[0] - to[0]) + Math.abs(from[1] - to[1]), 26);
  };
  const beats = [];
  const B = (at, who, d, slot = -1, target = -1, anim = "", prop = "") => beats.push({ at, who, do: d, slot, target, anim, prop });
  const elder = V.authority;
  // the elder escorts the condemned: both leave together from the condemned's door
  const vWalk = walkMin(victim);
  if (elder >= 0 && elder !== victim) B(start, elder, "walk_to", -1, victim, "Walk_Formal");
  B(start, victim, "walk_to", -1, -1, "Walk");
  let gatherEnd = start + vWalk + 2;
  if (["pillory", "stocks", "hanging", "bonfire", "sacrifice"].includes(kind)) B(start + vWalk + 2, victim, "lock", -1, -1, kind === "hanging" ? "Idle" : "Crouch_Idle");
  // the crowd leaves home one by one in id order, arrives at its slot and takes its stance
  const crowd = [...attend].sort((a, b) => a - b).filter((id) => id !== elder).slice(0, 40);
  crowd.forEach((id, i) => {
    const t0 = start + 5 + i, t1 = t0 + walkMin(id) + 1;
    B(t0, id, "walk_to", i, -1, "Walk");
    B(t1, id, "stand", i, -1, STANCE_ANIM(anger.get(id) ?? 0, sympathy.get(id) ?? 0));
    gatherEnd = Math.max(gatherEnd, t1);
  });
  // the act begins once the crowd has gathered, and runs its length
  const actStart = Math.max(start + 60, gatherEnd + 5);
  const end = actStart + def.minutes - 60;
  // the work of the act: wood carried to the stake, the gallows built, the priest's words
  if (kind === "bonfire") for (let i = 0; i < Math.min(4, crowd.length); i++) B(actStart - 20 + i * 20, crowd[i], "carry", i, -1, "Walk_Carry", "wood");
  if (kind === "hanging") for (let i = 0; i < Math.min(2, crowd.length); i++) B(actStart - 20 + i * 30, crowd[i], "gesture", i, -1, "Fixing_Kneeling");
  if (V.priest >= 0 && V.priest !== victim && (def.lethal || kind === "exile")) B(actStart, V.priest, "gesture", -1, -1, "Spell_Simple_Idle");
  // pelting, wave by wave; the first stone is thrown by the one with the lowest threshold (throwing[0])
  const slotOf = new Map(crowd.map((id, i) => [id, i]));
  const waves = Math.min(level, 3);
  for (let w = 1; w <= waves; w++) {
    const who = throwing.filter((id) => slotOf.has(id)).slice(0, 4 + w * 2);
    who.forEach((id, j) => {
      const at = actStart + (w - 1) * idiv(def.minutes - 90, 3) + j * 7;
      const props = PROP_BY_LEVEL[w];
      B(at, id, "throw", slotOf.get(id), victim, "OverhandThrow", props[j % props.length]);
      B(at + 1, victim, "react", -1, id, w === 3 ? "Hit_Head" : "Hit_Chest");
    });
  }
  if (kind === "bonfire") crowd.slice(0, 3).forEach((id, i) => B(end - 60 + i, id, "stand", slotOf.get(id), -1, "Idle_Torch", "torch"));
  const dies = outcome === "carried_out" && (def.lethal || lethalByStones);
  if (outcome === "crowd_turned") {
    B(end - 30, crowd[0] ?? elder, "release", -1, victim, "Interact");
    B(end - 25, victim, "leave", -1, -1, "Walk");
  } else if (dies) {
    B(end - 10, victim, "fall", -1, -1, "Death01");
  } else {
    if (["pillory", "stocks"].includes(kind)) B(end - 10, elder >= 0 ? elder : crowd[0], "release", -1, victim, "Interact");
    B(end - 5, victim, kind === "exile" || kind === "scapegoat" ? "walk_to" : "leave", -1, -1, "Walk");
  }
  crowd.forEach((id, i) => B(end + i, id, "leave", -1, -1, "Walk"));
  beats.forEach((b, i) => { b.seq = i; });
  beats.sort((a, b) => a.at - b.at || a.who - b.who || a.seq - b.seq);
  for (const b of beats) delete b.seq;
  const people = [victim, elder, V.priest, ...crowd].filter((id, i, arr) => id >= 0 && arr.indexOf(id) === i).map((id) => personEntry(V, id));
  const cue = {
    pillory: level >= 3 ? `stones in the square, ${nameOf(V, victim)} bleeding in the pillory` : level >= 2 ? `mud and jeers at ${nameOf(V, victim)} in the pillory` : `${nameOf(V, victim)} in the pillory, the crowd muttering`,
    stocks: `${nameOf(V, victim)} in the stocks`, fine: `coins counted out on the elder's bench`, branding: `the smell of burnt skin in the square`,
    exile: `${nameOf(V, victim)} led to the south gate`, hanging: `the gallows built by lantern light`, bonfire: `wood piled round the stake`,
    stoning: `a ring of villagers with stones in their hands`, mob: `torches in the lane, a door kicked in`, sacrifice: `a procession to the stone at dawn`,
    scapegoat: `a goat and a woman driven into the woods`, trial_by_combat: `a ring marked in the dust`, ordeal: `the millpond`,
  }[kind] ?? kind;
  const cause = [];
  for (const id of [c.event, cs.event]) if (id !== undefined) cause.push(`${V.events[id].type}: ${V.events[id].cue}`);
  const staging = {
    id: V.stagingCount++, kind: STAGE_KIND[kind] ?? kind, place, start, end: end + crowd.length + 5,
    phases: [
      { name: "gather", from: start, to: actStart, rescue: true },
      { name: kind, from: actStart, to: end - 10, rescue: !dies || kind !== "stoning" },
      { name: "end", from: end - 10, to: end + crowd.length + 5, rescue: false },
    ],
    roles: { victim, accuser: cs.accuser, authority: elder, crowd },
    beats, outcome: dies ? "carried_out" : outcome === "crowd_turned" ? "crowd_turned" : outcome, cause, cue, day: V.day, people,
  };
  V.stagings.push(staging);
  if (V.stagings.length > 300) V.stagings.shift();
  return staging;
}
const STAGE_KIND = { stocks: "pillory", fine: "trial", branding: "trial", ordeal: "trial", scapegoat: "exile" };

function makeFestivalStaging(V, folk, name, k) {
  const crowd = folk.map((q) => q.id).sort((a, b) => a - b).slice(0, 30);
  const beats = [];
  crowd.forEach((id, i) => {
    beats.push({ at: 1080 + i, who: id, do: "walk_to", slot: i, target: -1, anim: "Walk", prop: "" });
    beats.push({ at: 1110 + i, who: id, do: "stand", slot: i, target: -1, anim: i % 3 === 0 ? "Idle_Talking" : "Dance", prop: "" });
    beats.push({ at: 1300 + i, who: id, do: "leave", slot: -1, target: -1, anim: "Walk", prop: "" });
  });
  beats.forEach((b, i) => { b.seq = i; });
  beats.sort((a, b) => a.at - b.at || a.who - b.who || a.seq - b.seq);
  for (const b of beats) delete b.seq;
  V.stagings.push({ id: V.stagingCount++, kind: "festival", place: "square", start: 1080, end: 1340, phases: [{ name: "feast", from: 1080, to: 1300, rescue: false }],
    roles: { victim: -1, accuser: -1, authority: V.authority, crowd }, beats, outcome: "carried_out", cause: [name], cue: "dancing in the square", day: V.day,
    people: crowd.map((id) => personEntry(V, id)) });
}

function personEntry(V, id) {
  const p = V.people[id];
  return { id, name: p.name, outfit: key(key(V.base, 77), id) % 13, home: V.households[p.household].home, role: p.role, marks: Object.keys(p.marks).filter((m) => p.marks[m]) };
}

export function earn(V, id, epithetKey) {
  const p = V.people[id];
  const e = C.EPITHETS[epithetKey];
  if (!e || !p || p.epithets.includes(e)) return;
  p.epithets.push(e);
  (p.epithetLog ??= []).push([e, V.day]);
  logEvent(V, "epithet", id, -1, { epithet: e }, [], "");
}
