// Keyed randomness for the village, the same hash chain as the world kernel (kernel-reference/kernel.mjs):
// a draw is mix(...mix(mix(seed ^ C) ^ k1) ^ k2 ...), everything mod 2^32, integers only. A draw never
// depends on the order other draws were made in, so a change only spreads along real causes.

export function mix(h) {
  h = Math.imul(h ^ (h >>> 16), 0x7feb352d);
  h = Math.imul(h ^ (h >>> 15), 0x846ca68b);
  return (h ^ (h >>> 16)) >>> 0;
}
export const key = (h, k) => mix((h ^ k) >>> 0);
const TWO32 = 4294967296;
export const ppm = (d) => Math.floor((d * 1000000) / TWO32); // 0..999999
export const pick = (d, n) => Math.floor((d * n) / TWO32); // 0..n-1

// A draw from a list of keys: draw(h, a, b, c) = key(key(key(h, a), b), c).
export function draw(h, ...keys) {
  for (const k of keys) h = key(h, k);
  return h;
}
export const chance = (h, ppmValue) => ppm(h) < ppmValue;

// Stable hash of a string (names in keys), FNV-1a then mixed.
export function strKey(s) {
  let h = 2166136261;
  for (let i = 0; i < s.length; i++) h = Math.imul(h ^ s.charCodeAt(i), 16777619) >>> 0;
  return mix(h);
}

export const clamp = (v, lo, hi) => (v < lo ? lo : v > hi ? hi : v);
export const idiv = (a, b) => Math.floor(a / b); // only ever used with non-negative a and positive b
