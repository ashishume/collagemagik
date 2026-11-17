import type { Caption } from "@remotion/captions";
import raw from "../data/v5-words.json";
import { APP_WORD, FPS, makeCue } from "../ad/cues";

/** Word timings of the v5 voiceover (public/audio/voiceover-v5.mp3), pinned to its pauses by scripts/align-v5.mjs. */
export const WORDS = raw as Caption[];

export const VOICE_START = 6;
/** Length of the v5 voiceover file (45.95 s) in frames. */
export const VOICE_FRAMES = Math.ceil(45.95 * FPS);
export const TAIL = 45;
export const TOTAL = VOICE_START + VOICE_FRAMES + TAIL;

/** Frame at which a word is spoken. Throws if the word is missing, so new audio can't desync. */
export const cue = makeCue(WORDS, VOICE_START);

/** Every beat of the v5 ad, as the frame its word is spoken. The picture follows the voice. */
export const T = {
  trips: cue("trip's"),
  half1: cue("half", 0),
  photos0: cue("photos", 0),
  half2: cue("half", 1),
  videos0: cue("videos", 0),
  that: cue("that"),
  two0: cue("two", 0),
  separate: cue("separate"),
  posts: cue("posts"),
  not: cue("not"),
  anymore: cue("anymore"),
  cm1: cue(APP_WORD, 0),
  same: cue("same"),
  collage0: cue("collage", 0),
  drop: cue("drop"),
  photos1: cue("photos", 1),
  two1: cue("two", 1),
  videos1: cue("videos", 1),
  next: cue("next"),
  beach: cue("beach"),
  plays: cue("plays"),
  sunset: cue("sunset"),
  still0: cue("still", 0),
  moving: cue("moving"),
  still1: cue("still", 1),
  side: cue("side", 0),
  trim: cue("trim"),
  pick: cue("pick"),
  moment: cue("moment"),
  keep: cue("keep"),
  waves: cue("waves"),
  mute: cue("mute"),
  song: cue("song"),
  shot: cue("shot"),
  portrait: cue("portrait"),
  fit: cue("fit"),
  blurred: cue("blurred"),
  add: cue("add", 1),
  caption: cue("caption"),
  exp: cue("export"),
  smooth: cue("smooth"),
  reels: cue("reels"),
  stories: cue("stories"),
  tiktok: cue("tiktok"),
  photos2: cue("photos", 2),
  videos2: cue("videos", 2),
  one: cue("one"),
  collage1: cue("collage", 1),
  cm2: cue(APP_WORD, 1),
  free: cue("free"),
  store: cue("store"),
};
