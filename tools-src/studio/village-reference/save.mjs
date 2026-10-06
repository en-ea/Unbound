// Saving and loading a village: the whole state as JSON (the only non-JSON parts are each person's feelings
// and grudges, which are insertion-ordered maps and are saved as ordered pairs, so their order survives).
// A loaded village must go on exactly as if it had never stopped (save-test.mjs checks it).
export function saveVillage(V) {
  return JSON.stringify(V, (k, v) => (v instanceof Map ? { __map: [...v.entries()] } : v));
}

export function loadVillage(json) {
  return JSON.parse(json, (k, v) => (v && typeof v === "object" && Array.isArray(v.__map) ? new Map(v.__map) : v));
}
