import React from "react";
import { interpolate, useCurrentFrame, useVideoConfig } from "remotion";
import type { Caption } from "@remotion/captions";
import { C, clamp, fontFamily, useLayout } from "../ad/theme";
import { POP } from "./kit";

/** Short pages of 2-4 words, broken at punctuation and pauses. */
const toPages = (words: Caption[]): Caption[][] => {
  const out: Caption[][] = [];
  let cur: Caption[] = [];
  words.forEach((c, i) => {
    cur.push(c);
    const next = words[i + 1];
    const ends = /[.?!,]$/.test(c.text.trim());
    const pause = next ? next.startMs - c.endMs > 250 : true;
    if (cur.length >= 4 || ends || pause || !next) {
      out.push(cur);
      cur = [];
    }
  });
  return out;
};

/**
 * Subtitles that zoom: each page pops in from a little smaller, and the spoken word grows (about 18%) and turns gold.
 * Zoomed enough to feel alive, not so much that it jumps around.
 */
export const ZoomCaptions: React.FC<{ voiceStart: number; words: Caption[] }> = ({ voiceStart, words }) => {
  const pages = React.useMemo(() => toPages(words), [words]);
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
  const enter = interpolate(frame, [pStart, pStart + 9], [0, 1], { ...clamp, easing: POP });
  const size = (portrait ? 66 : 56) * u;
  return (
    <div style={{ position: "absolute", left: 0, right: 0, top: portrait ? height * 0.862 : height * 0.855, display: "flex", justifyContent: "center", padding: `0 ${70 * u}px`, zIndex: 20 }}>
      <div
        style={{
          display: "flex",
          flexWrap: "wrap",
          justifyContent: "center",
          alignItems: "center",
          gap: `${4 * u}px ${18 * u}px`,
          padding: `${14 * u}px ${32 * u}px`,
          borderRadius: 30 * u,
          background: "rgba(30,20,56,0.85)",
          boxShadow: `0 ${14 * u}px ${34 * u}px rgba(30,20,56,0.3)`,
          fontFamily,
          fontWeight: 800,
          fontSize: size,
          lineHeight: 1.15,
          maxWidth: portrait ? 960 * u : Math.min(1400 * u, width - 160 * u),
          opacity: Math.min(1, enter * 1.5),
          scale: String(0.82 + 0.18 * enter),
        }}
      >
        {page.map((w, i) => {
          const s = ((w.startMs - 40) / 1000) * fps + voiceStart;
          const e = ((w.endMs + 60) / 1000) * fps + voiceStart;
          const grow = interpolate(frame, [s, s + 4, e, e + 5], [0, 1, 1, 0], clamp);
          const said = frame >= s;
          const zoom = 1 + 0.16 * grow;
          // the spoken word makes room for its own zoom, so it never runs into its neighbours
          const room = size * 0.16 * grow * Math.min(2.4, w.text.trim().length * 0.32);
          return (
            <span
              key={i}
              style={{
                color: grow > 0.5 ? C.gold : said ? "#fff" : "rgba(255,255,255,0.5)",
                scale: String(zoom),
                transformOrigin: "50% 60%",
                margin: `0 ${room}px`,
                display: "inline-block",
                whiteSpace: "nowrap",
                textShadow: grow > 0.5 ? `0 0 ${18 * u}px rgba(244,178,60,0.45)` : undefined,
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
