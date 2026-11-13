import React from "react";
import { Easing, Img, interpolate, staticFile, useCurrentFrame } from "remotion";
import { APP_WORD, cue } from "../cues";
import { phoneHeight, SCREEN_RATIO } from "../Phone";
import { AIR, clamp, useLayout } from "../theme";

/** Region of the screen to highlight, as fractions of the screen: [x, y, width, height]. */
type Box = [number, number, number, number];
type Seg = { at: number; shot: string; box?: Box; swap?: "fade" | "slide" };

/**
 * The real app screens, keyed to the words in the voiceover. Screens are always shown whole (never zoomed or cropped);
 * a glowing outline points at the part the voice is talking about. Screens dissolve (or slide, for the carousel).
 */
const segments = (): Seg[] => [
  // the phone rises once the app name has had its moment
  { at: cue("photos", 1) - 4, shot: "05-timeline.png", box: [0.155, 0.112, 0.69, 0.57] },
  { at: cue("trim"), shot: "05-timeline.png", box: [0.15, 0.785, 0.5, 0.085] },
  { at: cue("pick"), shot: "06-choose-part.png", box: [0.015, 0.788, 0.94, 0.075] },
  { at: cue("add"), shot: "05-timeline.png", box: [0.17, 0.866, 0.32, 0.04] },
  { at: cue("drop"), shot: "07-captions.png", box: [0.245, 0.162, 0.5, 0.148] },
  { at: cue("done"), shot: "07-captions.png" },
  { at: cue("want"), shot: "01-carousel.png" },
  { at: cue("flows"), shot: "02-carousel-next.png", swap: "slide" },
  { at: cue("so", 1), shot: "01-carousel.png", swap: "slide" },
  { at: cue("then"), shot: "09-export.png", box: [0.27, 0.16, 0.46, 0.375] },
  { at: cue("same"), shot: "03-resize.png" },
];

/** Glowing outline that pops onto a region of the screen and gently pulses. */
const Highlight: React.FC<{ box: Box; at: number; until: number; sw: number; sh: number; u: number }> = ({ box, at, until, sw, sh, u }) => {
  const f = useCurrentFrame();
  const pop = interpolate(f, [at + 4, at + 16], [0, 1], { ...clamp, easing: Easing.bezier(0.34, 1.56, 0.64, 1) });
  const out = interpolate(f, [until - 6, until + 2], [0, 1], clamp);
  const pulse = 0.5 + 0.5 * Math.sin((f - at) / 6);
  const [x, y, w, h] = box;
  const pad = 6 * u;
  return (
    <div
      style={{
        position: "absolute",
        left: x * sw - pad,
        top: y * sh - pad,
        width: w * sw + pad * 2,
        height: h * sh + pad * 2,
        borderRadius: 18 * u,
        border: `${5 * u}px solid #FFD25E`,
        boxShadow: `0 0 ${(18 + pulse * 18) * u}px ${(4 + pulse * 6) * u}px rgba(255,210,94,0.65), inset 0 0 ${14 * u}px rgba(255,210,94,0.35)`,
        opacity: pop * (1 - out),
        scale: String(0.85 + 0.15 * pop),
      }}
    />
  );
};

export const AppPhone: React.FC = () => {
  const f = useCurrentFrame();
  const { portrait, u, width, height } = useLayout();
  const segs = segments();
  const start = segs[0].at;
  const end = cue(APP_WORD, 1); // the end card takes over when the app is named the second time
  if (f < start - 2 || f > end + 24) return null;

  const i = Math.max(0, segs.findIndex((s, k) => f >= s.at && (!segs[k + 1] || f < segs[k + 1].at)));
  const cur = segs[i];
  const prev = segs[i - 1];
  const t = interpolate(f, [cur.at, cur.at + 22], [0, 1], { ...clamp, easing: AIR });
  const next = segs[i + 1];
  const swapped = prev && prev.shot !== cur.shot;

  // size and position
  const baseW = (portrait ? 540 : 380) * u;
  const h = phoneHeight(baseW);
  const homeX = portrait ? width / 2 : width * 0.68;
  const homeY = portrait ? 300 * u + h / 2 : height / 2 - 22 * u;
  // "Same trip. Way better post." moves the phone aside for the before/after
  const aside = interpolate(f, [cue("same"), cue("same") + 20], [0, 1], { ...clamp, easing: AIR });
  const x = homeX + aside * (portrait ? 190 * u : 40 * u);
  const sc = 1 - aside * (portrait ? 0.14 : 0.04);
  // rise in, fly out
  const rise = interpolate(f, [start, start + 26], [0, 1], { ...clamp, easing: AIR });
  const leave = interpolate(f, [end, end + 20], [0, 1], { ...clamp, easing: Easing.in(Easing.cubic) });
  const bob = Math.sin(f / 38) * 9 * u;
  const tilt = Math.sin(f / 70) * 1.6;

  const bezel = baseW * 0.035;
  const sw = baseW - bezel * 2;
  const shH = sw / SCREEN_RATIO;
  const screen = (shot: string, opacity: number, dx: number) => (
    <Img
      src={staticFile(`shots/${shot}`)}
      style={{
        position: "absolute",
        inset: 0,
        width: "100%",
        height: "100%",
        objectFit: "cover",
        opacity,
        translate: `${dx}px 0px`,
      }}
    />
  );
  const slide = cur.swap === "slide";
  return (
    <div
      style={{
        position: "absolute",
        left: x - baseW / 2,
        top: homeY - h / 2 + bob + (1 - rise) * 500 * u - leave * 300 * u,
        width: baseW,
        height: h,
        scale: String(sc * (0.9 + 0.1 * rise) * (1 - leave * 0.2)),
        rotate: `${tilt + (1 - rise) * 8}deg`,
        opacity: rise * (1 - leave),
        filter: `blur(${(1 - rise) * 12 * u + leave * 14 * u}px)`,
        borderRadius: baseW * 0.16,
        background: "linear-gradient(145deg,#3a3446,#121016 45%,#2a2533)",
        padding: bezel,
        boxSizing: "border-box",
        boxShadow: `0 ${baseW * 0.08}px ${baseW * 0.2}px rgba(43,20,92,0.35), inset 0 0 0 ${baseW * 0.006}px rgba(255,255,255,0.18)`,
      }}
    >
      <div style={{ position: "relative", width: sw, height: shH, borderRadius: baseW * 0.125, overflow: "hidden", background: "#0d0a18" }}>
        {swapped && t < 1
          ? screen(prev.shot, slide ? 1 : 1 - t, slide ? -t * sw : 0)
          : null}
        {screen(cur.shot, swapped && !slide ? t : 1, swapped && slide ? (1 - t) * sw : 0)}
        {cur.box ? <Highlight key={cur.at} box={cur.box} at={cur.at} until={next ? next.at : end} sw={sw} sh={shH} u={u} /> : null}
      </div>
    </div>
  );
};
