import React from "react";

/**
 * Stylised "holiday photos" drawn in CSS (no stock photos, nothing to license): the same sunset / sea / mountain / city /
 * aurora / flower look as the sample media in the App Store screenshots.
 */
export const PHOTO_KINDS = ["sunset", "sea", "mountain", "city", "aurora", "flowers", "desert", "palm", "lake", "food"] as const;
export type PhotoKind = (typeof PHOTO_KINDS)[number];

const scenes: Record<PhotoKind, string> = {
  sunset:
    "radial-gradient(circle at 50% 58%, #FFE9A8 0 9%, transparent 10%), linear-gradient(180deg,#3B2A6B 0%,#B9467A 38%,#F59A5B 58%,#5A2E5C 60%,#24183F 100%)",
  sea: "radial-gradient(circle at 72% 30%, #FFF6D6 0 7%, transparent 8%), linear-gradient(180deg,#7FC8F2 0%,#BDE6F8 45%,#1F8FB8 46%,#0E5E85 100%)",
  mountain:
    "linear-gradient(135deg, transparent 52%, #2E4A3E 52%), linear-gradient(225deg, transparent 55%, #3E6A57 55%), linear-gradient(180deg,#9FC3E4 0%,#DCEAF4 70%,#2E4A3E 70%)",
  city: "repeating-linear-gradient(90deg, #1A1433 0 8%, #2A2150 8% 10%, #1A1433 10% 18%), radial-gradient(circle at 30% 70%, #F9C74F 0 1.5%, transparent 2%), linear-gradient(180deg,#120E2A 0%,#3B2A6B 55%,#151030 100%)",
  aurora:
    "radial-gradient(ellipse at 40% 40%, rgba(74,222,182,0.8) 0 20%, transparent 45%), radial-gradient(ellipse at 70% 30%, rgba(155,107,255,0.75) 0 18%, transparent 40%), linear-gradient(180deg,#0B0A22 0%,#16224A 70%,#0E1530 100%)",
  flowers:
    "radial-gradient(circle at 20% 70%, #FF7AA8 0 4%, transparent 5%), radial-gradient(circle at 55% 78%, #FFD166 0 4%, transparent 5%), radial-gradient(circle at 80% 68%, #F25C8A 0 4%, transparent 5%), linear-gradient(180deg,#BFE3FF 0%,#E8F6FF 50%,#7BC67B 50%,#3E8E4E 100%)",
  desert:
    "radial-gradient(ellipse at 30% 95%, #D9894A 0 40%, transparent 41%), radial-gradient(ellipse at 80% 100%, #C27138 0 45%, transparent 46%), linear-gradient(180deg,#F9D5A7 0%,#F6B27A 60%,#E9935A 100%)",
  palm: "radial-gradient(circle at 75% 25%, #FFF3C4 0 8%, transparent 9%), linear-gradient(180deg,#FF9E7A 0%,#FFC48A 50%,#5BC0BE 51%,#2A9D8F 100%)",
  lake: "linear-gradient(180deg,#A8C8F0 0%,#D7E7F7 45%,#6F8FB8 46%,#9DB8DC 70%,#4F6D96 100%)",
  food: "radial-gradient(circle at 50% 50%, #FFF4E6 0 30%, #F2D0A4 31% 34%, transparent 35%), radial-gradient(circle at 50% 50%, #E76F51 0 12%, transparent 13%), linear-gradient(135deg,#8C5A3C,#5E3A26)",
};

export const TripPhoto: React.FC<{ kind: PhotoKind; style?: React.CSSProperties; video?: boolean; u?: number }> = ({
  kind,
  style,
  video,
  u = 1,
}) => (
  <div style={{ position: "relative", background: scenes[kind], overflow: "hidden", ...style }}>
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
