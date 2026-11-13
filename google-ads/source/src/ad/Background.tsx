import React from "react";
import { AbsoluteFill, useCurrentFrame } from "remotion";
import { C, useLayout } from "./theme";

/** Soft pastel wash with slowly drifting colour blobs and floating sparkles, like air moving behind the content. */
export const Background: React.FC<{ tint?: string }> = ({ tint = C.wash }) => {
  const frame = useCurrentFrame();
  const { width, height } = useLayout();
  const t = frame / 30;
  const blobs = [
    { c: tint, x: 0.15, y: 0.2, r: 0.55, sp: 0.21, ph: 0 },
    { c: "#FBD9E6", x: 0.85, y: 0.3, r: 0.5, sp: 0.17, ph: 2 },
    { c: "#D6E6FB", x: 0.25, y: 0.85, r: 0.6, sp: 0.13, ph: 4 },
    { c: "#FFE9C7", x: 0.8, y: 0.85, r: 0.45, sp: 0.19, ph: 1 },
  ];
  const big = Math.max(width, height);
  return (
    <AbsoluteFill style={{ background: C.lilac, overflow: "hidden" }}>
      {blobs.map((b, i) => (
        <div
          key={i}
          style={{
            position: "absolute",
            width: big * b.r,
            height: big * b.r,
            left: width * b.x - (big * b.r) / 2 + Math.sin(t * b.sp + b.ph) * width * 0.08,
            top: height * b.y - (big * b.r) / 2 + Math.cos(t * b.sp * 1.3 + b.ph) * height * 0.06,
            borderRadius: "50%",
            background: b.c,
            filter: `blur(${big * 0.06}px)`,
            opacity: 0.85,
          }}
        />
      ))}
      <Sparkles />
    </AbsoluteFill>
  );
};

const Sparkles: React.FC = () => {
  const frame = useCurrentFrame();
  const { width, height, u } = useLayout();
  const pts = [
    [0.08, 0.12, "✦", C.purple],
    [0.92, 0.18, "+", C.pink],
    [0.06, 0.62, "○", C.teal],
    [0.94, 0.7, "✦", C.gold],
    [0.5, 0.05, "·", C.purple],
    [0.12, 0.9, "+", C.blue],
    [0.88, 0.94, "○", C.coral],
  ] as const;
  return (
    <>
      {pts.map(([x, y, ch, col], i) => {
        const bob = Math.sin(frame / 22 + i * 1.7) * 14 * u;
        const tw = 0.45 + 0.35 * Math.sin(frame / 15 + i);
        return (
          <div
            key={i}
            style={{
              position: "absolute",
              left: x * width,
              top: y * height + bob,
              fontSize: 46 * u,
              color: col,
              opacity: tw,
              rotate: `${frame * 0.6 + i * 40}deg`,
              fontWeight: 800,
            }}
          >
            {ch}
          </div>
        );
      })}
    </>
  );
};
