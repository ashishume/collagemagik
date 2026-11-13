import type { Caption } from "@remotion/captions";
import raw from "../data/v4-words.json";
import { FPS, makeCue } from "../ad/cues";

/** Word timings of the v4 voiceover (public/audio/voiceover-v4.mp3, transcribed by scripts/transcribe.mjs). */
export const WORDS = raw as Caption[];

export const VOICE_START = 6;
/** Length of the v4 voiceover file (40.83 s) in frames. */
export const VOICE_FRAMES = Math.ceil(40.83 * FPS);
export const TAIL = 45;
export const TOTAL = VOICE_START + VOICE_FRAMES + TAIL;

/** Frame at which a word of the v4 voiceover is spoken. Throws if the word is missing, so new audio can't desync. */
export const cue = makeCue(WORDS, VOICE_START);
