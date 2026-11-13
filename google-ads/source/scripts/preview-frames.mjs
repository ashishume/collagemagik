// Renders a few frames of a composition as JPEGs for a quick visual check (bundles once).
// Usage: node scripts/preview-frames.mjs AdVertical 60,135,225 [outDir] [scale]
import path from "path";
import fs from "fs";
import { bundle } from "@remotion/bundler";
import { renderStill, selectComposition } from "@remotion/renderer";

const [id = "AdVertical", framesArg = "60", outDir = "out/preview", scale = "0.4"] = process.argv.slice(2);
const serveUrl = await bundle({ entryPoint: path.resolve("src/index.ts") });
const composition = await selectComposition({ serveUrl, id });
fs.mkdirSync(outDir, { recursive: true });
for (const frame of framesArg.split(",").map(Number)) {
  const output = path.join(outDir, `${id}-${String(frame).padStart(4, "0")}.jpg`);
  await renderStill({ serveUrl, composition, frame, output, imageFormat: "jpeg", jpegQuality: 80, scale: Number(scale) });
  console.log(output);
}
