import React from "react";
import { Img, staticFile } from "remotion";

/** Aspect of the raw simulator screenshots (1320 x 2868). */
export const SCREEN_RATIO = 1320 / 2868;

type Props = {
  /** File in public/shots, e.g. "05-timeline.png". */
  shot: string;
  /** Outer width of the phone in px. */
  width: number;
  /** Zoom into the screen: 1 = whole screen. */
  zoom?: number;
  /** Point of the screen to zoom towards, 0..1 (x, y). */
  focus?: [number, number];
  style?: React.CSSProperties;
  children?: React.ReactNode;
};

/** An iPhone-style frame around a real app screenshot. Children are drawn on top of the screen. */
export const Phone: React.FC<Props> = ({ shot, width, zoom = 1, focus = [0.5, 0.5], style, children }) => {
  const bezel = width * 0.035;
  const screenW = width - bezel * 2;
  const screenH = screenW / SCREEN_RATIO;
  const height = screenH + bezel * 2;
  const radius = width * 0.16;
  return (
    <div
      style={{
        position: "relative",
        width,
        height,
        borderRadius: radius,
        background: "linear-gradient(145deg,#3a3446,#121016 45%,#2a2533)",
        padding: bezel,
        boxSizing: "border-box",
        boxShadow: `0 ${width * 0.08}px ${width * 0.2}px rgba(43,20,92,0.35), 0 ${width * 0.02}px ${width * 0.05}px rgba(0,0,0,0.25), inset 0 0 0 ${width * 0.006}px rgba(255,255,255,0.18)`,
        ...style,
      }}
    >
      <div
        style={{
          position: "relative",
          width: screenW,
          height: screenH,
          borderRadius: radius - bezel,
          overflow: "hidden",
          background: "#0d0a18",
        }}
      >
        <Img
          src={staticFile(`shots/${shot}`)}
          style={{
            width: "100%",
            height: "100%",
            objectFit: "cover",
            scale: String(zoom),
            transformOrigin: `${focus[0] * 100}% ${focus[1] * 100}%`,
          }}
        />
        {children}
      </div>
    </div>
  );
};

export const phoneHeight = (width: number) => {
  const bezel = width * 0.035;
  return (width - bezel * 2) / SCREEN_RATIO + bezel * 2;
};
