// Transcribes the voiceover with whisper.cpp to get word-level timings (writes src/data/voiceover-captions.json).
// Run: node scripts/transcribe.mjs   (first run downloads whisper.cpp and the base.en model into .whisper/)
import path from "path";
import fs from "fs";
import {
  downloadWhisperModel,
  installWhisperCpp,
  transcribe,
  toCaptions,
} from "@remotion/install-whisper-cpp";

const to = path.join(process.cwd(), ".whisper");
const version = "1.5.5";
const model = "small.en";

await installWhisperCpp({ to, version });
await downloadWhisperModel({ model, folder: to });

const out = await transcribe({
  model,
  whisperPath: to,
  whisperCppVersion: version,
  inputPath: path.join(process.cwd(), process.argv[2] ?? "assets-raw/voiceover16k.wav"),
  tokenLevelTimestamps: true,
});

const { captions } = toCaptions({ whisperCppOutput: out });
fs.mkdirSync("src/data", { recursive: true });
fs.writeFileSync(process.argv[3] ?? "src/data/voiceover-captions.json", JSON.stringify(captions, null, 2));
console.log(captions.map((c) => `${(c.startMs / 1000).toFixed(2)} ${c.text}`).join("\n"));
