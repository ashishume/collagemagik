import React from "react";
import { AbsoluteFill, Easing, Img, interpolate, staticFile, useCurrentFrame, useVideoConfig } from "remotion";

/**
 * A short "travel video" made from one photo with a slow push-in and drift. Used only as input media for the app when
 * recapturing its screens (the timeline and Choose part screens need real video files).
 */
export const PanClip: React.FC<{ photo: string }> = ({ photo }) => {
  const f = useCurrentFrame();
  const { durationInFrames } = useVideoConfig();
  const p = interpolate(f, [0, durationInFrames], [0, 1], { easing: Easing.inOut(Easing.sin) });
  return (
    <AbsoluteFill style={{ background: "#000", overflow: "hidden" }}>
      <Img
        src={staticFile(`travel/${photo}.jpg`)}
        style={{
          width: "100%",
          height: "100%",
          objectFit: "cover",
          scale: String(1.04 + 0.14 * p),
          translate: `${-30 + 60 * p}px ${20 - 40 * p}px`,
        }}
      />
    </AbsoluteFill>
  );
};
