// Word timings for the v5 voiceover. Whisper's times drifted up to a second on this voice, so each phrase is pinned to
// the speech between the pauses that ffmpeg's silencedetect found, and its words are spread over it by length.
// Run: node scripts/align-v5.mjs  (writes src/data/v5-words.json)
import fs from "fs";
const phrases = [
  [0.06, 4.56, "Trip's over! And my camera roll is half photos, half videos."],
  [5.08, 8.6, "That usually means two separate posts."],
  [9.07, 10.05, "Not anymore!"],
  [10.45, 13.11, "In CollageMagik, they go in the same collage."],
  [13.53, 16.92, "Drop in my photos, then two videos, right next to them."],
  [17.39, 20.28, "The beach clip plays while the sunset photo stays still."],
  [20.7, 21.93, "Moving and still,"],
  [22.24, 23.21, "side by side."],
  [23.68, 26.39, "Trim each video, pick the exact moment,"],
  [26.78, 29.82, "keep the waves, mute the wind, and add a song underneath."],
  [30.31, 31.21, "Shot it in portrait?"],
  [31.71, 34.59, "Fit the whole picture with soft blurred sides."],
  [35.04, 35.78, "Add a caption,"],
  [36.05, 39.69, "then export a smooth video for Reels, Stories, or TikTok."],
  [40.18, 41.57, "Photos and videos."],
  [41.83, 42.74, "One collage."],
  [43.11, 44.2, "CollageMagik."],
  [44.57, 45.7, "Free on the App Store."],
];
const words = [];
for (const [a, b, text] of phrases) {
  const parts = text.split(" ");
  // a word's share of the phrase: its letters, plus a little for the gap after it
  const weight = parts.map((w) => w.replace(/[^\w']/g, "").length + 1.5);
  const total = weight.reduce((s, x) => s + x, 0);
  let t = a;
  parts.forEach((w, i) => {
    const d = ((b - a) * weight[i]) / total;
    words.push({ text: w, startMs: Math.round(t * 1000), endMs: Math.round((t + d) * 1000), timestampMs: null, confidence: 1 });
    t += d;
  });
}
fs.writeFileSync("src/data/v5-words.json", JSON.stringify(words, null, 2));
console.log(words.length, "words");
