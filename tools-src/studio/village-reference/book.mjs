// Writes the Book of Tales for a village: node book.mjs [seed=1000] [years=300] [out=path]
import { createVillage, run, YEAR } from "./village.mjs";
import { book } from "./tales.mjs";
import { writeFileSync } from "node:fs";
const seed = Number(process.argv[2] ?? 1000), years = Number(process.argv[3] ?? 300);
const V = createVillage(seed);
run(V, years * YEAR);
const b = book(V, years, 3);
if (process.argv[4]) writeFileSync(process.argv[4], b.markdown + "\n");
console.log(b.markdown);
console.error(`${b.count} tales`);
