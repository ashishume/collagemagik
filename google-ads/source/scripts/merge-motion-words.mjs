// Turns whisper tokens (src/data/motion-{a,b}-captions.json) into whole words for the Motion template ads:
// joins sub-word pieces ("Coll" "age" "magic" -> "Collage Magic"), glues punctuation on, drops "(laughs)".
// Run: node scripts/merge-motion-words.mjs
import fs from "fs";
for (const x of ["a", "b"]) {
  const toks = JSON.parse(fs.readFileSync(`src/data/motion-${x}-captions.json`, "utf8"));
  const words = [];
  let skip = false;
  for (const t of toks) {
    const s = t.text;
    if (s.includes("(")) { skip = true; continue; }
    if (skip) { if (s.includes(")")) skip = false; continue; }
    const last = words[words.length - 1];
    if (last && (/^[.,?!]/.test(s.trim()) || !s.startsWith(" ")) && words.length) {
      last.text += s.trim(); last.endMs = t.endMs; continue;
    }
    words.push({ text: s.trim(), startMs: t.startMs, endMs: t.endMs, timestampMs: null, confidence: 1 });
  }
  const out = [];
  for (const w of words) {
    const prev = out[out.length - 1];
    if (prev && /^collage\.?$/i.test(prev.text.replace(/[^a-z.]/gi, "")) && /^magic/i.test(w.text)) {
      prev.text = "Collage Magic" + w.text.replace(/^magic/i, ""); prev.endMs = w.endMs; continue;
    }
    out.push(w);
  }
  // whisper gives some short words no length (or the same start as the word before); the captions need both
  out.forEach((w, i) => {
    if (i && w.startMs < out[i - 1].startMs + 80) w.startMs = out[i - 1].startMs + 80;
    w.endMs = Math.max(w.endMs, w.startMs + 180);
  });
  fs.writeFileSync(`src/data/motion-${x}-words.json`, JSON.stringify(out, null, 2));
  console.log(x, out.map((w) => `${(w.startMs / 1000).toFixed(2)}:${w.text}`).join(" "));
}
