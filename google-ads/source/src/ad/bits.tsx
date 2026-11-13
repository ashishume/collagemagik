import React from "react";
import { Easing, Img, interpolate, staticFile, useCurrentFrame, useVideoConfig } from "remotion";
import { AIR, C, clamp, fontFamily, useLayout } from "./theme";

/** Fade, lift and un-blur in; drift and blur out. The "air" transition every scene uses. */
export const Air: React.FC<{
  inAt?: number;
  outAt?: number; // frame (local) when the exit starts; omit to stay
  dur?: number;
  from?: [number, number]; // entrance offset in px (x, y)
  style?: React.CSSProperties;
  children: React.ReactNode;
}> = ({ inAt = 0, outAt, dur = 18, from = [0, 60], style, children }) => {
  const f = useCurrentFrame();
  const { u } = useLayout();
  const enter = interpolate(f, [inAt, inAt + dur], [0, 1], { ...clamp, easing: AIR });
  const exit = outAt === undefined ? 0 : interpolate(f, [outAt, outAt + dur * 0.8], [0, 1], { ...clamp, easing: Easing.in(Easing.cubic) });
  return (
    <div
      style={{
        opacity: enter * (1 - exit),
        translate: `${(1 - enter) * from[0] * u - exit * from[0] * 0.5 * u}px ${(1 - enter) * from[1] * u - exit * 50 * u}px`,
        scale: String(0.94 + 0.06 * enter + exit * 0.04),
        filter: `blur(${(1 - enter) * 14 * u + exit * 16 * u}px)`,
        ...style,
      }}
    >
      {children}
    </div>
  );
};

/** A gentle hover so nothing is ever perfectly still. */
export const useFloat = (amp = 10, speed = 40, phase = 0) => {
  const f = useCurrentFrame();
  const { u } = useLayout();
  return Math.sin(f / speed + phase) * amp * u;
};

/** Springy pop for stickers: scale 0 -> overshoot -> 1. */
export const usePop = (at: number) => {
  const f = useCurrentFrame();
  const { fps } = useVideoConfig();
  return interpolate(f, [at, at + 0.45 * fps], [0, 1], {
    ...clamp,
    easing: Easing.bezier(0.34, 1.56, 0.64, 1),
  });
};

/** Rounded "sticker" label, like Reels text stickers. */
export const Sticker: React.FC<{
  at: number;
  out?: number;
  text: string;
  bg?: string;
  color?: string;
  tilt?: number;
  size?: number;
  style?: React.CSSProperties;
}> = ({ at, out, text, bg = C.white, color = C.ink, tilt = -4, size = 54, style }) => {
  const f = useCurrentFrame();
  const { u } = useLayout();
  const p = usePop(at);
  const gone = out === undefined ? 0 : interpolate(f, [out, out + 10], [0, 1], { ...clamp, easing: Easing.in(Easing.cubic) });
  const bob = Math.sin(f / 25 + at) * 6 * u;
  return (
    <div
      style={{
        position: "absolute",
        padding: `${size * 0.32 * u}px ${size * 0.6 * u}px`,
        borderRadius: size * 0.6 * u,
        background: bg,
        color,
        fontFamily,
        fontWeight: 800,
        fontSize: size * u,
        lineHeight: 1.05,
        whiteSpace: "nowrap",
        boxShadow: `0 ${14 * u}px ${36 * u}px rgba(43,20,92,0.22)`,
        scale: String(p * (1 - gone)),
        rotate: `${tilt + (1 - p) * -10}deg`,
        translate: `0px ${bob}px`,
        opacity: Math.min(1, p * 2) * (1 - gone),
        ...style,
      }}
    >
      {text}
    </div>
  );
};

/** App icon + name pill. Shown during the story intro so the app is on screen before it is named. */
export const AppBadge: React.FC<{ at: number; out?: number; scale?: number; style?: React.CSSProperties; sub?: string }> = ({
  at,
  out,
  scale = 1,
  style,
  sub = "Collage maker for iPhone",
}) => {
  const f = useCurrentFrame();
  const { u } = useLayout();
  const p = interpolate(f, [at, at + 20], [0, 1], { ...clamp, easing: AIR });
  const gone = out === undefined ? 0 : interpolate(f, [out, out + 14], [0, 1], { ...clamp, easing: AIR });
  const s = u * scale;
  return (
    <div
      style={{
        position: "absolute",
        display: "flex",
        alignItems: "center",
        gap: 18 * s,
        padding: `${14 * s}px ${30 * s}px ${14 * s}px ${14 * s}px`,
        borderRadius: 999,
        background: "rgba(255,255,255,0.86)",
        boxShadow: `0 ${16 * s}px ${40 * s}px rgba(43,20,92,0.18)`,
        opacity: p * (1 - gone),
        translate: `0px ${(1 - p) * -40 * s - gone * 30 * s}px`,
        filter: `blur(${(1 - p) * 10 * s}px)`,
        fontFamily,
        ...style,
      }}
    >
      <Img src={staticFile("brand/icon.png")} style={{ width: 84 * s, height: 84 * s, borderRadius: 20 * s }} />
      <div>
        <div style={{ fontWeight: 800, fontSize: 40 * s, color: C.ink, lineHeight: 1.1 }}>Insta Collage</div>
        <div style={{ fontWeight: 600, fontSize: 26 * s, color: C.purple }}>{sub}</div>
      </div>
    </div>
  );
};

/** "Free on the App Store" call-to-action button (our own design, not Apple's badge artwork). */
export const StoreButton: React.FC<{ s: number; style?: React.CSSProperties }> = ({ s, style }) => (
  <div
    style={{
      display: "inline-flex",
      alignItems: "center",
      gap: 18 * s,
      padding: `${22 * s}px ${48 * s}px`,
      borderRadius: 999,
      background: `linear-gradient(135deg, ${C.purple}, ${C.pink})`,
      color: "#fff",
      fontFamily,
      fontWeight: 800,
      fontSize: 46 * s,
      boxShadow: `0 ${18 * s}px ${44 * s}px rgba(109,79,214,0.45)`,
      ...style,
    }}
  >
    Download free on the App Store
  </div>
);
