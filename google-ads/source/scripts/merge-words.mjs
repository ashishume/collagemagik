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
// The app name: Whisper may hear "CollageMagik" as "Collage Magic" (two words) or "CollageMagic". Join it into one word.
for (let i = 0; i < words.length - 1; i++) {
  if (/^collage$/i.test(words[i].text) && /^magi[ck]\b/i.test(words[i + 1].text)) {
    const tail = words[i + 1].text.replace(/^magi[ck]/i, "");
    words[i] = { ...words[i], text: "CollageMagik" + tail, endMs: words[i + 1].endMs };
    words.splice(i + 1, 1);
  }
}
for (const w of words) w.text = w.text.replace(/^Collage ?Magi[ck]/i, "CollageMagik").replace(/^InstaCollage/, "Insta Collage");
fs.writeFileSync("src/data/voiceover-words.json", JSON.stringify(words, null, 2));
console.log(words.map((w) => `${(w.startMs / 1000).toFixed(2)} ${w.text}`).join(" | "));
