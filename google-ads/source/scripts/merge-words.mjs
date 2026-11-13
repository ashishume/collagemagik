// Whisper returns sub-word tokens ("Inst", "a", "Coll", "age"). Merge them into whole words with punctuation attached.
// Run after transcribe.mjs: node scripts/merge-words.mjs
import fs from "fs";
const tokens = JSON.parse(fs.readFileSync("src/data/voiceover-captions.json", "utf8"));
const words = [];
for (const t of tokens) {
  const startsWord = /^\s/.test(t.text) || words.length === 0;
  const isPunct = /^[.,?!;:]+$/.test(t.text.trim());
  if (startsWord && !isPunct) words.push({ ...t, text: t.text.trim() });
  else { const w = words[words.length - 1]; w.text += t.text.trim(); w.endMs = Math.max(w.endMs, t.endMs); }
}
for (const w of words) w.text = w.text.replace(/^InstaCollage/, "Insta Collage");
fs.writeFileSync("src/data/voiceover-words.json", JSON.stringify(words, null, 2));
console.log(words.map((w) => `${(w.startMs / 1000).toFixed(2)} ${w.text}`).join(" | "));
