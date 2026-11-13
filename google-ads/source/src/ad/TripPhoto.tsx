import React from "react";
import { Img, staticFile } from "remotion";

/**
 * Real travel photos from Unsplash (Unsplash License: free for commercial use, no attribution required).
 * Files live in public/travel/ (full size, 1600 px wide) and public/travel/thumb/ (480 px, for small tiles).
 * Who took each one: public/travel/credits.json. All are scenery, food or places, with no identifiable people.
 *
 * Ordered so neighbouring tiles (camera roll, photo pile) mix places and colours.
 */
export const PHOTO_KINDS = [
  "santorini-sunset",
  "palm-beach",
  "aurora-reine",
  "positano",
  "balloons",
  "turquoise",
  "venice-rialto",
  "pizza",
  "alpine-lake",
  "overwater",
  "golden-wave",
  "santorini-domes",
  "diamond-beach",
  "desert-road",
  "breakfast",
  "balloons-valley",
  "leaning-palm",
  "amalfi",
  "aurora-beach",
  "dinner-fira",
  "mountain-lake",
  "dock",
  "bali-temple",
  "beach-sunset",
  "santorini-windmills",
  "venice-canal",
  "golden-palms",
  "swiss-house",
  "aerial-shore",
  "balcony",
  "forest-road",
  "palm-sand",
  "santorini-rooftops",
] as const;
export type PhotoKind = (typeof PHOTO_KINDS)[number];

export const TripPhoto: React.FC<{
  kind: PhotoKind;
  style?: React.CSSProperties;
  video?: boolean;
  u?: number;
  /** Use the full-size file (for anything bigger than a small tile). */
  hd?: boolean;
}> = ({ kind, style, video, u = 1, hd }) => (
  <div style={{ position: "relative", overflow: "hidden", background: "#2a2440", ...style }}>
    <Img
      src={staticFile(hd ? `travel/${kind}.jpg` : `travel/thumb/${kind}.jpg`)}
      style={{ position: "absolute", inset: 0, width: "100%", height: "100%", objectFit: "cover" }}
    />
    {video ? (
      <div
        style={{
          position: "absolute",
          right: 8 * u,
          bottom: 8 * u,
          padding: `${3 * u}px ${8 * u}px`,
          borderRadius: 20 * u,
          background: "rgba(0,0,0,0.55)",
          color: "#fff",
          fontSize: 16 * u,
          fontWeight: 700,
        }}
      >
        ▶ 0:12
      </div>
    ) : null}
  </div>
);
