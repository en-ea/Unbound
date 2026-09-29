// The Book of Tales: the best stories a village made, told from its event log. A tale starts at a notable
// event (a public act, a burning, an exoneration, a feud), follows the causes back (the famine, the theft,
// the rumour, the accusation) and the consequences forward (the confession years later, the shrine), and is
// scored for what makes a story worth telling: stakes, reversal, a wrong done, kin against kin. Nothing is
// written by hand except the sentence patterns; every name, cause and turn comes from the simulation.
import { key, pick } from "./rng.mjs";
import * as C from "./content.mjs";
import { fullName, nameOf } from "./events.mjs";
import { YEAR } from "./village.mjs";

const yearOf = (d) => Math.floor(d / YEAR) + 1;
const RITE_SEQUEL = new Set(["accusation", "trial", "verdict", "public_act", "ordeal", "confession", "exile", "violent_death", "crowd_turned", "feud"]);
const SEQUEL = new Set(["confession", "exoneration", "veneration", "return", "feud", "crowd_turned", "violent_death", "exile", "epithet"]);

export function extractTales(V, perCentury = 3) {
  const children = new Map();
  for (const e of V.events) for (const c of e.causes) { if (!children.has(c)) children.set(c, []); children.get(c).push(e.id); }
  const roots = V.events.filter((e) => ["public_act", "exoneration", "mob", "crowd_turned"].includes(e.type) || (e.type === "ordeal" && e.data.combat)
    || (e.type === "rite" && e.data.rite === "sacrifice"));
  const told = new Map(); // person -> years of their tales: one tale per person per 8 years
  const tales = [];
  const used = new Set();
  for (const r of roots) {
    const back = walk(V, r.id, (e) => e.causes, 30);
    // consequences: the truth, the shrine, the return, the feud, and a killing done for it; not every later
    // quarrel that an old grudge fed (those are their own tales)
    // (after an offering, the village's justice on the forebears is the sequel)
    const seq = r.type === "rite" ? RITE_SEQUEL : SEQUEL;
    const fwd = walk(V, r.id, (e) => e.type === "crime" && e.id !== r.id ? [] : (children.get(e.id) ?? []).filter((c) => seq.has(V.events[c].type) || (V.events[c].type === "crime" && V.events[c].data.act === "murder")), 14);
    const ids = [...new Set([...back, ...fwd])].sort((a, b) => a - b);
    tales.push({ root: r.id, ids, score: score(V, r, ids), year: yearOf(r.day) });
  }
  // the best few per century, no two tales telling the same events, and variety of kinds
  const kindOf = (t) => { const r = V.events[t.root]; return r.type === "public_act" ? (r.data.outcome === "crowd_turned" ? "turned" : r.data.kind) : r.type; };
  const out = [];
  const perC = new Map();
  const kindsIn = new Map();
  const kindUses = new Map(); // a kind already told is worth less the next time (the book needs range)
  const pool = [...tales];
  while (pool.length) {
    let bi = 0, bs = -1e9;
    for (let i = 0; i < pool.length; i++) {
      const a = pool[i].score - 25 * (kindUses.get(kindOf(pool[i])) ?? 0);
      if (a > bs || (a === bs && pool[i].root < pool[bi].root)) { bs = a; bi = i; }
    }
    const t = pool.splice(bi, 1)[0];
    const century = Math.floor((t.year - 1) / 100);
    if ((perC.get(century) ?? 0) >= perCentury) continue;
    const overlap = t.ids.filter((id) => used.has(id)).length;
    if (overlap * 10 >= t.ids.length * 4) continue; // mostly told already
    if (t.score < 40) continue;
    const r = V.events[t.root];
    if ((told.get(r.who) ?? []).some((y) => Math.abs(y - t.year) < 8)) continue;
    const kind = kindOf(t);
    const ck = century + ":" + kind;
    if (kindsIn.has(ck)) continue; // one tale of a kind per century: variety
    kindsIn.set(ck, true);
    told.set(r.who, [...(told.get(r.who) ?? []), t.year]);
    kindUses.set(kind, (kindUses.get(kind) ?? 0) + 1);
    out.push(t);
    perC.set(century, (perC.get(century) ?? 0) + 1);
    for (const id of t.ids) used.add(id);
  }
  out.sort((a, b) => a.root - b.root);
  return out;
}

// The story behind one public act (for a staging's notice board and the witness's printout).
export function storyOf(V, eventId) {
  const ids = walk(V, eventId, (e) => e.causes, 30).sort((a, b) => a - b);
  return tellTale(V, { root: eventId, ids, score: 0, year: yearOf(V.events[eventId].day) });
}

export function walk(V, start, next, limit) {
  const seen = new Set([start]);
  const q = [start];
  while (q.length && seen.size < limit) {
    const id = q.shift();
    for (const n of next(V.events[id])) if (!seen.has(n)) { seen.add(n); q.push(n); }
  }
  return [...seen];
}

function score(V, r, ids) {
  let s = 0;
  const kinds = ids.map((id) => V.events[id]);
  const act = r.type === "public_act" ? r.data.kind : r.type;
  if (r.type === "rite") s += 55;
  s += { bonfire: 70, hanging: 65, stoning: 70, mob: 70, sacrifice: 70, trial_by_combat: 55, exile: 35, branding: 30, pillory: 20, stocks: 15, fine: 2, ordeal: 25, scapegoat: 40, exoneration: 60, crowd_turned: 60 }[act] ?? 10;
  if (r.data.level >= 2) s += 10 * r.data.level;
  for (const e of kinds) {
    if (e.type === "crowd_turned") s += 40;
    if (e.type === "exoneration") s += 50;
    if (e.type === "veneration") s += 40;
    if (e.type === "return") s += 45;
    if (e.type === "confession") s += e.data.late ? 35 : 10;
    if (e.type === "ordeal") s += e.data.acquit ? 25 : 15;
    if (e.type === "accusation" && e.data.wrongful) s += 30;
    if (e.type === "famine" || e.type === "omen") s += 12;
    if (e.type === "feud") s += 20;
    if (e.type === "rumour" && e.data.via === 3) s += 8;
  }
  s += Math.min(30, ids.length * 3);
  return s;
}

// ---------- telling ----------
const PLACE_WORDS = { road: "on the south road", far_woods: "in the far woods", woods: "in the woods", field: "in the field", mill: "by the mill",
  pasture: "in the pasture", well: "by the well", square: "in the square", forge: "by the forge", shrine: "at the shrine" };

// why a quarrel came to blood: the old wrong the grudge remembers
function grudgeLine(V, e, n) {
  for (const c of e.causes) {
    const x = V.events[c];
    if (x.type === "public_act" && x.who !== e.who) return `${n(e.who)} had never forgiven ${n(e.other)} for what was done to ${n(x.who)}. `;
    if (x.type === "rivalry") return `${n(e.who)} had never forgiven ${n(e.other)} for marrying ${n(x.data.bride)}. `;
  }
  return "";
}
function later(V, e) {
  const c = V.crimes[e.data.crime];
  const from = c?.punishEvent !== undefined ? V.events[c.punishEvent].day : c?.day ?? e.day;
  const gap = e.day - from;
  return gap < 20 ? "Before the month was out" : gap < YEAR ? "Before the year was out" : gap < 2 * YEAR ? "The next year" : gap < 6 * YEAR ? "A few years later" : "Years later";
}
const variant = (V, e, n) => pick(key(V.base, 0x7a1e + e.id), n);

function sentence(V, e, ctx) {
  const n = (id) => ctx.label.get(id) ?? nameOf(V, id);
  const d = e.data;
  switch (e.type) {
    case "storm": {
      const hh = V.households[d.household];
      const lin = V.lineages[hh.lineage]?.name ?? "";
      return d.phase === "recedes" ? `Then one morning the mist lifted and the strangers were gone, and the ${lin}s were home, remembering nothing.`
        : `That was the year the storm came down on the ${lin} house. When the air cleared, the family was gone, and in their place stood people in furs who spoke like the old songs - the ${lin}s' own forebears.`;
    }
    case "arrival": return d.storm !== undefined ? `Their leader was called ${n(e.who)}.` : "";
    case "rite": return d.rite === "seized" ? `The forebears read the strange world as their gods' anger. At dusk they took ${n(e.other)} to the stake, and the drums began.`
      : d.outcome === "rescued" ? `Before dawn ${n(d.rescuer)} crept to the stake and cut the ropes, and the two of them ran for the houses.`
      : `At dawn ${n(e.who)} made the offering, as their fathers had.${d.heart ? " They kept the heart for their fire." : ""}`;
    case "famine": return ["It was the year the grain rotted in the ear.", "The harvest failed that year, and the bread ran out before the spring.", "That was a hungry year."][variant(V, e, 3)];
    case "omen": return [`That season people saw ${d.omen}, and began to watch one another.`, `Then came ${d.omen}. The old women said it meant a curse among them.`][variant(V, e, 2)];
    case "crime": {
      const c = V.crimes[d.crime];
      const lin = c.household >= 0 ? V.lineages[V.households[c.household].lineage]?.name : "";
      const why = d.motive === "hunger" ? ["hungry", "with the children crying for bread", "half-starved"][variant(V, e, 3)] : d.motive === "greed" ? "who had always counted other people's geese" : d.motive === "grudge" ? "nursing an old grudge" : d.motive === "boldness" ? "bold as ever" : "";
      if (d.act === "theft") return `${n(e.who)}${why ? ", " + why + "," : ""} took ${d.item === "goose" ? "a goose" : "grain"} from the ${lin} house while they were at work.`;
      if (d.act === "sorcery") return `Whispers started that ${n(e.who)} had cursed the village - ${e.cue}.`;
      if (d.act === "poaching") return `${n(e.who)} set snares in the elder's woods.`;
      if (d.act === "assault") return grudgeLine(V, e, n) + `One evening old grudges came to blows: ${n(e.who)} struck ${n(e.other)}.`;
      if (d.act === "murder") return grudgeLine(V, e, n) + (e.cue.includes("brawl") ? `One evening a fight ${PLACE_WORDS[d.place] ?? "at the " + d.place} went too far: ${n(e.who)} struck ${n(e.other)}, and ${n(e.other)} did not get up.`
        : `${n(e.other)} was found dead ${PLACE_WORDS[d.place] ?? "at the " + d.place}.`);
      if (d.act === "cannibal_famine") return `In the worst of it, ${n(e.who)} did what no one would ever speak of: there were ${e.cue.replace("bones", "bones")}.`;
      if (d.act === "hoarding") return `While others starved, ${n(e.who)}'s barn stayed full - ${e.cue}.`;
      return `${n(e.who)} was accused of ${C.ACTS[d.act]?.noun ?? d.act}.`;
    }
    case "discovery": return e.who >= 0 ? `${n(e.who)} found ${e.cue}.` : "";
    case "rumour": {
      // the first telling is told; the rest are a murmur
      const heard = (ctx.rumours = (ctx.rumours ?? 0) + 1);
      if (heard === 2) return "Soon others were saying the same.";
      if (heard > 2) return "";
      return d.via === 3 ? `${n(e.other)} had never trusted ${n(d.culprit)}, and heard what they wanted to hear.` : `${n(e.who)} ${["came to", "whispered to", "went to"][variant(V, e, 3)]} ${n(e.other)}: it was ${n(d.culprit)}.`;
    }
    case "accusation": ctx.accuser = e.who; ctx.rumours = 0; return `${n(e.who)} named ${n(e.other)} before the elder.`;
    case "trial": { const bench = d.bench ?? "elder";
      return e.who < 0 ? "The village heard it in the square." : ctx.accuser === e.who ? `${n(e.who)}, the ${bench}, judged it too.` : `${n(e.who)}, the ${bench}, heard it in the square.`; }
    case "confession": if (d.recant) return `${later(V, e)}, ${n(e.who)} stood up in the shrine and took it all back: there had been no curse, only fear, and they had named ${n(e.other)} for it.`;
      return d.deathbed ? `${later(V, e)}, dying, ${n(e.who)} called for the priest and told him everything: it had been them all along.` : d.late ? `${later(V, e)}, ${n(e.who)} broke down at the shrine and told the priest everything: it had been them all along.` : `${n(e.who)} confessed, and was spared the worst.`;
    case "ordeal": return d.combat ? `${n(e.who)} fought ${n(e.other)} in a ring in the dust${d.won ? " - and won, and walked free" : " - and fell"}.`
      : `They put ${n(e.who)} in the millpond. ${d.acquit ? "They sank, and were hauled out innocent." : "They floated. Guilty."}`;
    case "verdict": return d.verdict === "acquitted" ? `${n(e.other)} was let go.` : d.vetoed && d.asked ? `The law asked for ${ACT_WORDS[d.asked] ?? d.asked}, but the elder, weary of blood, gave ${ACT_WORDS[d.act] ?? d.act}.` : `The sentence was ${ACT_WORDS[d.act] ?? d.act}.`;
    case "public_act": return actSentence(V, e, n);
    case "crowd_turned": return "But the crowd closed round the condemned instead of the stones, and the elder let them go.";
    case "exile": return d.fled ? `${n(e.who)} was gone by morning, into the woods.` : `${n(e.who)} walked out of the south gate with one bundle and did not look back.`;
    case "exoneration": return V.people[e.who].alive || V.events.some((x) => x.type === "return" && x.who === e.who && x.day > e.day) ? `The truth came out.` : `The truth came too late for ${n(e.who)}.`;
    case "veneration": return `Now there are candles on ${n(e.who)}'s grave, and strangers come to kneel.`;
    case "return": return `They sent riders after ${n(e.who)}, and ${n(e.who)} came home through the south gate, thinner and older; the village came out to meet them, ashamed.`;
    case "feud": return `From that day the ${V.lineages[e.who]?.name} and the ${V.lineages[e.other]?.name} would not share a well.`;
    case "violent_death": return "";
    case "funeral": return ctx.deathNamed.has(e.who) ? "" : `They buried ${n(e.who)} behind the shrine.`;
    default: return "";
  }
}
const ACT_WORDS = { fine: "a fine", pillory: "a day in the pillory", stocks: "the stocks", branding: "the brand", exile: "exile", hanging: "the rope", bonfire: "the fire", stoning: "stoning", trial_by_combat: "trial by combat", ordeal: "the ordeal", scapegoat: "the wilderness" };

function actSentence(V, e, n) {
  const d = e.data, v = n(e.who);
  if (d.outcome === "rescued") return `But on the night before, ${v}'s cell was found empty and the ropes cut. Everyone knew it was ${n(e.other)}, and no one said so.`;
  if (d.outcome === "crowd_turned") return `They put ${v} in the ${d.kind === "stocks" ? "stocks" : d.kind}.`;
  switch (d.kind) {
    case "pillory": case "stocks":
      return d.level >= 3 ? `In the ${d.kind}, the cabbages became mud, and the mud became stones. ${v} lived, but was never the same.`
        : d.level === 2 ? `They pelted ${v} with mud in the ${d.kind} until dusk.` : `${v} stood a day in the ${d.kind} while the village muttered.`;
    case "fine": return `${v} paid in grain.`;
    case "branding": return `They branded ${v} in the square, and everyone smelled it.`;
    case "exile": return "";
    case "hanging": return `They hanged ${v} at dawn from a gallows built by lantern light.`;
    case "bonfire": return `They burned ${v} at the stake at dusk; the smoke was seen from the next valley.`;
    case "stoning": case "mob": return `The stones were thrown before anyone could stop them. ${v} died in the dust of the square.`;
    case "sacrifice": return `At dawn they led ${v} to the stone.`;
    default: return "";
  }
}

export function tellTale(V, t) {
  // people who share a given name within one tale are told apart by their family
  const label = new Map(), byName = new Map();
  for (const id of t.ids) {
    const e = V.events[id];
    for (const p of [e.who, e.other, e.data.culprit]) if (p >= 0 && typeof p === "number") {
      const nm = V.people[p].name;
      if (!byName.has(nm)) byName.set(nm, new Set());
      byName.get(nm).add(p);
    }
  }
  for (const [nm, ids] of byName) if (ids.size > 1) for (const p of ids) label.set(p, `${nm} ${V.lineages[V.people[p].lineage]?.name ?? ""}`.trim());
  const ctx = { deathNamed: new Set(), label };
  const root = V.events[t.root];
  const lines = [];
  for (const id of t.ids) {
    const e = V.events[id];
    if (e.type === "public_act" && ["hanging", "bonfire", "stoning", "mob"].includes(e.data.kind)) ctx.deathNamed.add(e.who);
    const s = sentence(V, e, ctx);
    if (s && lines[lines.length - 1] !== s) lines.push(s);
  }
  // who they were remembered as: the one the tale is about, and the one who truly did it
  const crimeEv = t.ids.map((id) => V.events[id]).find((e) => e.type === "crime");
  const culprit = crimeEv && crimeEv.data.act !== "sorcery" ? crimeEv.who : -1;
  const telling = [C.EPITHETS.returned, C.EPITHETS.false_accuser, C.EPITHETS.confessed, C.EPITHETS.branded, C.EPITHETS.hanged, C.EPITHETS.burned, C.EPITHETS.exiled, C.EPITHETS.pilloried];
  const people = [root.who, culprit >= 0 && V.people[culprit].epithets.some((x) => telling.includes(x)) ? culprit : -1, ...t.ids.map((id) => V.events[id]).filter((e) => e.data.outcome === "rescued").map((e) => e.other)];
  const lastDay = Math.max(...t.ids.map((id) => V.events[id].day));
  const firstDay = Math.min(...t.ids.map((id) => V.events[id].day));
  const epithetThen = (p) => { const log = (V.people[p].epithetLog ?? []).filter(([, d]) => d >= firstDay && d <= lastDay); return log.length ? log[log.length - 1][0] : ""; };
  // an epithet is only told if this tale shows how it was earned
  const evs = t.ids.map((id) => V.events[id]);
  const shown = (p, ep) => {
    const E = C.EPITHETS;
    const has = (f) => evs.some(f);
    if (ep === E.confessed) return has((e) => e.type === "confession" && e.who === p);
    if (ep === E.branded) return has((e) => e.type === "public_act" && e.who === p && e.data.kind === "branding");
    if (ep === E.hanged) return has((e) => e.type === "public_act" && e.who === p && e.data.kind === "hanging");
    if (ep === E.burned) return has((e) => e.type === "public_act" && e.who === p && e.data.kind === "bonfire");
    if (ep === E.exiled) return has((e) => e.type === "exile" && e.who === p);
    if (ep === E.returned) return has((e) => e.type === "return" && e.who === p);
    if (ep === E.venerated) return has((e) => e.type === "veneration" && e.who === p);
    if (ep === E.false_accuser) return has((e) => e.type === "exoneration") && has((e) => e.type === "accusation" && e.who === p);
    if (ep === E.pilloried || ep === E.survivor) return has((e) => e.type === "public_act" && e.who === p && ["pillory", "stocks"].includes(e.data.kind));
    if (ep === E.rescuer) return has((e) => e.data.outcome === "rescued" && e.other === p);
    return false;
  };
  const epithetShown = (p) => { const log = (V.people[p].epithetLog ?? []).filter(([ep, d]) => d >= firstDay && d <= lastDay && shown(p, ep)); return log.length ? log[log.length - 1][0] : ""; };
  const remembered = [...new Set(people)].filter((p) => p >= 0 && epithetShown(p)).map((p) => `${ctx.label.get(p) ?? V.people[p].name} ${epithetShown(p)}`);
  // a sentence on a forebear the storm took back before it could be carried out
  const lastVerdict = [...evs].reverse().find((e) => e.type === "verdict" && e.data.verdict === "guilty");
  if (lastVerdict && V.people[lastVerdict.other].faded && !evs.some((e) => e.type === "public_act" && e.data.case === lastVerdict.data.case)) {
    lines.push(`But before the day came, the mist rolled back over the ${V.households[V.people[lastVerdict.other].household].home} house, and ${ctx.label.get(lastVerdict.other) ?? nameOf(V, lastVerdict.other)} was gone with it, back to their own time.`);
  }
  if (remembered.length) lines.push(`They are remembered as ${remembered.join(" and ")}.`);
  return { title: title(V, root), year: t.year, text: lines.join(" ") };
}

function title(V, e) {
  const v = nameOf(V, e.who);
  if (e.type === "exoneration") return `The Late Truth About ${v}`;
  if (e.type === "crowd_turned") return `The Stones That Were Not Thrown`;
  if (e.type === "rite") return e.data.outcome === "rescued" ? `The Night at the Stone` : `The Offering of ${nameOf(V, e.other)}`;
  if (e.type === "mob") return `The Night of the Torches`;
  if (e.type === "ordeal" && e.data.combat) return `${v} in the Ring`;
  const d = e.data;
  if (d.outcome === "crowd_turned") return `The Stones That Were Not Thrown`;
  if (d.outcome === "rescued") return `The Empty Cell`;
  return {
    bonfire: `The Burning of ${v}`, hanging: `The Hanging of ${v}`, stoning: `The Stoning of ${v}`, mob: `The Night of the Torches`,
    pillory: d.level >= 3 ? `${v} and the Stones` : `${v} in the Pillory`, branding: `${v} the Branded`, exile: `${v} Walks Out`,
    fine: `${v}'s Fine`, sacrifice: `The Offering of ${v}`, trial_by_combat: `${v} in the Ring`,
  }[d.kind] ?? `The Tale of ${v}`;
}

export function book(V, years, perCentury = 3) {
  const tales = extractTales(V, perCentury).map((t) => tellTale(V, t));
  const out = [];
  out.push(`# The Tales of ${V.name}, years 1-${years}`);
  out.push("");
  out.push(`*Told from the village's own memory: every name, cause and turn below happened in the simulation (seed ${V.seed}); only the sentence patterns were written by hand.*`);
  out.push("");
  for (const t of tales) {
    out.push(`## Year ${t.year}: ${t.title}`);
    out.push("");
    out.push(t.text);
    out.push("");
  }
  return { markdown: out.join("\n"), count: tales.length };
}
