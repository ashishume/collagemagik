import React from "react";
import { Easing, interpolate } from "remotion";
import { AIR, clamp } from "../ad/theme";

export const POP = Easing.bezier(0.34, 1.56, 0.64, 1);
export const ip = (f: number, a: number, b: number, from = 0, to = 1, easing = AIR) => interpolate(f, [a, b], [from, to], { ...clamp, easing });
/** 0 -> 1 -> 0 visibility window with short fades. */
export const win = (f: number, from: number, to: number, fade = 6) => ip(f, from, from + fade) * (1 - ip(f, to, to + fade));
/** A value that eases to each new target in turn. */
export const steps = (f: number, init: number, list: [number, number][], dur = 12, easing = AIR) => {
  let v = init;
  for (const [at, to] of list) v += (to - v) * ip(f, at, at + dur, 0, 1, easing);
  return v;
};
/** A short pulse (0 -> 1 -> 0) right after `at`. */
export const pulse = (f: number, at: number, len = 14) => (f < at ? 0 : Math.max(0, Math.sin(Math.min(1, (f - at) / len) * Math.PI)));

/** A fingertip on the screen. */
export const Touch: React.FC<{ x: number; y: number; o?: number; down?: boolean }> = ({ x, y, o = 1, down = true }) => (
  <div
    style={{
      position: "absolute",
      left: x - 17,
      top: y - 17,
      width: 34,
      height: 34,
      borderRadius: "50%",
      background: "rgba(255,255,255,0.8)",
      border: "2.5px solid rgba(255,255,255,0.95)",
      boxShadow: "0 0 0 6px rgba(255,255,255,0.22), 0 6px 16px rgba(0,0,0,0.35)",
      opacity: o,
      scale: String(down ? 0.86 : 1),
      zIndex: 50,
    }}
  />
);
export type TouchP = { x: number; y: number; o: number; down: boolean };
/** A tap: the finger arrives, presses, lifts. */
export const tapAt = (f: number, at: number, x: number, y: number): TouchP | null => {
  if (f < at - 6 || f > at + 6) return null;
  return { x, y, o: win(f, at - 6, at + 2, 4), down: f >= at - 1 && f <= at + 3 };
};
