import type { Caption } from "@remotion/captions";
import raw from "../data/voiceover-words.json";

const captions = raw as Caption[];

export const FPS = 30;
/** The voiceover starts this many frames into the video. */
export const VOICE_START = 6;
/** Length of the voiceover file (40.75 s) in frames. */
export const VOICE_FRAMES = Math.ceil(40.75 * FPS);
/** Extra frames after the voice so the end card can breathe. */
export const TAIL = 45;
export const TOTAL = VOICE_START + VOICE_FRAMES + TAIL;

const norm = (s: string) => s.toLowerCase().replace(/[^a-z0-9']/g, "");

/** How the voiceover spells the app name once merged (scripts/merge-words.mjs joins "Collage Magic" into one word). */
export const APP_WORD = "collagemagik";

/**
 * Frame (from the start of the video) at which `word` is spoken. `nth` picks a later occurrence (0 = first).
 * Throws if the word isn't in the transcript, so a changed voiceover can't silently desync the visuals.
 */
export const makeCue =
  (words: Caption[], voiceStart: number) =>
  (word: string, nth = 0, offsetMs = 0): number => {
    // the v1-v3 voiceover said "Insta Collage"; accept it for the app name so older audio still lines up
    const names = norm(word) === APP_WORD ? [APP_WORD, "instacollage"] : [norm(word)];
    const hits = words.filter((c) => names.includes(norm(c.text)));
    const hit = nth < 0 ? hits[hits.length + nth] : hits[nth];
    if (!hit) throw new Error(`Word "${word}" (#${nth}) not found in voiceover transcript`);
    return voiceStart + Math.round(((hit.startMs + offsetMs) / 1000) * FPS);
  };

export const cue = makeCue(captions, VOICE_START);
