// Renders every Google Ads image into ../photos/<version>/ (bundles once).
// Usage (from google-ads/source): node scripts/render-photos.mjs v1 [idFilter]
//   image-assets/   App, Demand Gen and Responsive Display images (1.91:1, 1:1, 4:5, 9:16), with and without text
//   display-banners Fixed-size uploaded image ads, each kept at or under Google's 150 KB limit
//   logos/          Square 1:1 and landscape 4:1 logos (PNG)
import path from "path";
import fs from "fs";
import { bundle } from "@remotion/bundler";
import { getCompositions, renderStill } from "@remotion/renderer";

const [version = "v1", filter = ""] = process.argv.slice(2);
const root = path.resolve("..", "photos", version);
const BANNER_MAX = 150 * 1024;

const serveUrl = await bundle({ entryPoint: path.resolve("src/index.ts") });
const comps = (await getCompositions(serveUrl)).filter((c) => c.durationInFrames === 1 && c.id.includes(filter));

for (const composition of comps) {
  const { id } = composition;
  if (id.startsWith("logo-")) {
    const output = path.join(root, "logos", `insta-collage-${id}-${composition.width}x${composition.height}.png`);
    fs.mkdirSync(path.dirname(output), { recursive: true });
    await renderStill({ serveUrl, composition, output, imageFormat: "png" });
    console.log(output);
    continue;
  }
  const isBanner = id.startsWith("banner-");
  const dir = isBanner ? "display-banners" : "image-assets";
  const name = isBanner ? id.replace(/^banner-/, "") : `${id.replace(/^asset-/, "")}-${composition.width}x${composition.height}`;
  const output = path.join(root, dir, `insta-collage-${name}.jpg`);
  fs.mkdirSync(path.dirname(output), { recursive: true });
  let q = 92;
  for (;;) {
    await renderStill({ serveUrl, composition, output, imageFormat: "jpeg", jpegQuality: q });
    const size = fs.statSync(output).size;
    if (!isBanner || size <= BANNER_MAX || q <= 40) {
      console.log(`${output} ${(size / 1024).toFixed(0)} KB q${q}${isBanner && size > BANNER_MAX ? " OVER 150KB" : ""}`);
      break;
    }
    q -= 8;
  }
}
