import React from "react";
import { interpolate, useCurrentFrame, useVideoConfig } from "remotion";
import type { Caption } from "@remotion/captions";
import raw from "../data/voiceover-words.json";
import { AIR, C, clamp, fontFamily, useLayout } from "./theme";

const captions = raw as Caption[];

/** Groups words into short pages (3-4 words), breaking at sentence ends and pauses. */
const toPages = (words: Caption[]): Caption[][] => {
  const out: Caption[][] = [];
  let cur: Caption[] = [];
  words.forEach((c, i) => {
    cur.push(c);
    const next = words[i + 1];
    const endsSentence = /[.?!,]$/.test(c.text.trim());
    const pause = next ? next.startMs - c.endMs > 250 : true;
    if (cur.length >= 4 || endsSentence || pause || !next) {
      out.push(cur);
      cur = [];
    }
  });
  return out;
};
const defaultPages = toPages(captions);
const pageCache = new WeakMap<Caption[], Caption[][]>();

/** Word-by-word captions with the spoken word highlighted, for people watching on mute. */
export const Captions: React.FC<{ voiceStart: number; words?: Caption[]; portraitTop?: number }> = ({ voiceStart, words, portraitTop = 0.775 }) => {
  if (words && !pageCache.has(words)) pageCache.set(words, toPages(words));
  const pages = words ? pageCache.get(words)! : defaultPages;
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();
  const { u, portrait, height, width } = useLayout();
  const ms = ((frame - voiceStart) / fps) * 1000;
  const page = pages.find((p, i) => {
    const end = pages[i + 1] ? pages[i + 1][0].startMs : p[p.length - 1].endMs + 600;
    return ms >= p[0].startMs - 80 && ms < end - 80;
  });
  if (!page) return null;
  const pStart = ((page[0].startMs - 80) / 1000) * fps + voiceStart;
  const enter = interpolate(frame, [pStart, pStart + 7], [0, 1], { ...clamp, easing: AIR });
  const size = (portrait ? 64 : 58) * u;
  return (
    <div
      style={{
        position: "absolute",
        left: 0,
        right: 0,
        top: portrait ? height * portraitTop : height * 0.86,
        display: "flex",
        justifyContent: "center",
        padding: `0 ${80 * u}px`,
        opacity: enter,
        translate: `0px ${(1 - enter) * 24 * u}px`,
      }}
    >
      <div
        style={{
          display: "flex",
          flexWrap: "wrap",
          justifyContent: "center",
          gap: `${4 * u}px ${22 * u}px`,
          padding: `${14 * u}px ${30 * u}px`,
          borderRadius: 28 * u,
          background: "rgba(30,20,56,0.82)",
          fontFamily,
          fontWeight: 800,
          fontSize: size,
          lineHeight: 1.15,
          maxWidth: portrait ? 960 * u : Math.min(1500 * u, width - 160 * u),
        }}
      >
        {page.map((w, i) => {
          const active = ms >= w.startMs - 40 && ms < w.endMs + 60;
          const said = ms >= w.startMs - 40;
          return (
            <span
              key={i}
              style={{
                color: active ? C.gold : said ? "#fff" : "rgba(255,255,255,0.55)",
                // long words (e.g. "CollageMagik.") grow less, so the pop doesn't swallow the gap to their neighbours
                scale: active ? String(1 + Math.min(0.08, 0.4 / w.text.trim().length)) : "1",
                transformOrigin: "50% 60%",
                display: "inline-block",
                whiteSpace: "nowrap",
              }}
            >
              {w.text.trim()}
            </span>
          );
        })}
      </div>
    </div>
  );
};
