import { loadFont as anton } from "@remotion/google-fonts/Anton";
import { loadFont as caveat } from "@remotion/google-fonts/Caveat";
import { loadFont as greatVibes } from "@remotion/google-fonts/GreatVibes";
import { loadFont as sacramento } from "@remotion/google-fonts/Sacramento";
import { loadFont as specialElite } from "@remotion/google-fonts/SpecialElite";
import { fontFamily } from "../ad/theme";

/** Caption fonts, matching the app's own (Great Vibes, Sacramento and Caveat ship inside the app). */
export const F = {
  classic: fontFamily,
  poster: anton("normal", { weights: ["400"], subsets: ["latin"] }).fontFamily,
  type: specialElite("normal", { weights: ["400"], subsets: ["latin"] }).fontFamily,
  hand: caveat("normal", { weights: ["700"], subsets: ["latin"] }).fontFamily,
  script: greatVibes("normal", { weights: ["400"], subsets: ["latin"] }).fontFamily,
  dreamy: sacramento("normal", { weights: ["400"], subsets: ["latin"] }).fontFamily,
};
