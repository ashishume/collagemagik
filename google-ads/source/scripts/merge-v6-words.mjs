// Whisper tokens (src/data/motion-v6-captions.json) -> whole words for the v6 motion ad (src/data/motion-v6-words.json).
// Joins sub-word pieces, glues punctuation on, writes "70 plus" as "70+" and puts back the script's question marks.
// Run: node scripts/merge-v6-words.mjs
import fs from "fs";
const toks = JSON.parse(fs.readFileSync("src/data/motion-v6-captions.json", "utf8"));
const w = [];
for (const t of toks) {
  const s = t.text;
  const last = w[w.length - 1];
  if (last && (/^[.,?!]/.test(s.trim()) || !s.startsWith(" "))) { last.text += s.trim(); last.endMs = t.endMs; continue; }
  w.push({ text: s.trim(), startMs: t.startMs, endMs: t.endMs, timestampMs: null, confidence: 1 });
}
const out = [];
for (const x of w) {
  const p = out[out.length - 1];
  if (p && /^collage$/i.test(p.text) && /^magic/i.test(x.text)) { p.text = "Collage Magic" + x.text.replace(/^magic/i, ""); p.endMs = x.endMs; continue; }
  if (p && p.text === "70" && /^plus/i.test(x.text)) { p.text = "70+"; p.endMs = x.endMs; continue; }
  out.push(x);
}
out.forEach((x, i) => {
  if (/^(night|day),$/.test(x.text)) x.text = x.text.replace(",", "?");
  if (/^(make|let|done)/.test(x.text)) x.text = x.text[0].toUpperCase() + x.text.slice(1);
  if (x.text === "videos,") x.text = "videos.";
  if (x.text === "Done.") x.text = "Done!";
  if (x.text === "bounce.") x.text = "bounce!";
  if (x.text === "pets.") x.text = "pets!";
  if (i && x.startMs < out[i - 1].startMs + 80) x.startMs = out[i - 1].startMs + 80;
  x.endMs = Math.max(x.endMs, x.startMs + 180);
});
fs.writeFileSync("src/data/motion-v6-words.json", JSON.stringify(out, null, 2));
console.log(out.map((x) => `${(x.startMs / 1000).toFixed(2)}:${x.text}`).join(" "));
