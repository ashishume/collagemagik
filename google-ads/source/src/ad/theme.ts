import { loadFont } from "@remotion/google-fonts/PlusJakartaSans";
import { Easing, useVideoConfig } from "remotion";

export const { fontFamily } = loadFont("normal", {
  weights: ["500", "700", "800"],
  subsets: ["latin"],
});

// Brand colours, taken from the App Store screenshots (ios/AppStore/screenshots/source/screenshots.json).
export const C = {
  ink: "#1E1438",
  purple: "#6D4FD6",
  purpleDeep: "#4B32B0",
  pink: "#E0457B",
  coral: "#F2795B",
  teal: "#1FA58F",
  blue: "#3F6DB5",
  gold: "#F4B23C",
  lilac: "#F6F1FD",
  wash: "#E3D8F6",
  white: "#FFFFFF",
};

/** The app's name everywhere in the ads (renamed from "Insta Collage": Meta treats "Insta" as its brand term). */
export const APP_NAME = "CollageMagik";
export const APP_SUBTITLE = "Collage Maker & Editor";

/** The "air" easing: a quick lift that settles very softly. Used for almost every entrance. */
export const AIR = Easing.bezier(0.16, 1, 0.3, 1);
export const SOFT = Easing.bezier(0.45, 0, 0.25, 1);

export const clamp = { extrapolateLeft: "clamp", extrapolateRight: "clamp" } as const;

/** Layout helper: the same scenes adapt to vertical (1080x1920) and landscape (1920x1080). */
export const useLayout = () => {
  const { width, height, fps } = useVideoConfig();
  const portrait = height > width;
  // u = 1 design unit; 1080 units across the short side.
  const u = Math.min(width, height) / 1080;
  return { width, height, fps, portrait, u };
};
