// A compact bridge to the existing world kernel, not a second clock. The epoch is derived from
// the village's persisted storm cycle. Only ordinary round/hill districts are eligible locally.
import { History, A, E, hashWorld } from '../kernel-reference/kernel.mjs';
export function stormTransition(seed, cycle) {
  const epoch = 20 + cycle;
  const action = { year:epoch, player:0, seq:cycle, kind:A.STORM, target:0, a:333, b:0 };
  const world = new History(seed,[action]).run(epoch+1);
  const i = world.ev.type.lastIndexOf(E.STORM);
  return i < 0 ? null : { epoch, source:world.ev.other[i], enclave:world.ev.sub[i],
    displaced:world.ev.a[i], past:world.ev.b[i], hash:hashWorld(world) };
}
