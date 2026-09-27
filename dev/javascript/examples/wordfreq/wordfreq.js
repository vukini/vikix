// wordfreq.js — the ten most common words in a text file.
//
// A word is a run of letters, compared in lower case. A regular
// expression finds them, a Map counts them, and sort with a two-part
// comparison puts the most common first.
//
//   node wordfreq.js text.txt
import { readFileSync } from "node:fs";

const path = process.argv[2];
if (!path) {
  console.error("usage: node wordfreq.js FILE");
  process.exit(2);
}

const counts = new Map();
for (const word of readFileSync(path, "utf8").toLowerCase().match(/[a-z]+/g) ?? []) {
  counts.set(word, (counts.get(word) ?? 0) + 1);
}

// The higher count first; the same count in alphabetical order.
const top = [...counts].sort(([w1, c1], [w2, c2]) => c2 - c1 || (w1 < w2 ? -1 : 1));
for (const [word, count] of top.slice(0, 10)) {
  console.log(`${String(count).padStart(4)} ${word}`);
}
