import type { Theme } from "./AdImage";

/** Image assets for App, Demand Gen and Responsive Display campaigns (Google resizes/crops these per placement). */
export const ASSET_SIZES = [
  { name: "landscape-1.91x1", w: 1200, h: 628 },
  { name: "square-1x1", w: 1200, h: 1200 },
  { name: "portrait-4x5", w: 1200, h: 1500 },
  { name: "vertical-9x16", w: 1080, h: 1920 },
] as const;

/** Fixed-size uploaded image ads for Display campaigns (each file must be 150 KB or less). */
export const BANNER_SIZES = [
  [300, 250],
  [336, 280],
  [728, 90],
  [300, 600],
  [320, 50],
  [320, 100],
  [468, 60],
  [970, 90],
  [970, 250],
  [250, 250],
  [200, 200],
  [160, 600],
  [300, 1050],
] as const;

export const THEMES: Theme[] = ["trip", "carousel", "features"];
