import React from "react";
import { Img, staticFile, useCurrentFrame } from "remotion";
import type { PhotoKind } from "../ad/TripPhoto";
import { C, fontFamily } from "../ad/theme";
import { F } from "../ad4/fonts";
import { ip, POP } from "./kit";

/**
 * The v5 collage: two photos and two videos in one design. Videos really move (a slow drift, light sweeping across,
 * a running progress bar); photos stay perfectly still. The portrait photo can be shown filled (cropped) or fitted
 * whole with blurred sides, as the app's new Resize tool does.
 */
export type Cell = { kind: PhotoKind; video?: boolean; x: number; y: number; w: number; h: number; label: string };

export const CELLS: Cell[] = [
  { kind: "santorini-sunset", x: 0, y: 0, w: 0.5, h: 0.5, label: "sunset photo" },
  { kind: "golden-wave", video: true, x: 0.5, y: 0, w: 0.5, h: 0.5, label: "beach clip" },
  { kind: "venice-canal", video: true, x: 0, y: 0.5, w: 0.36, h: 0.5, label: "canal clip" },
  { kind: "positano", x: 0.36, y: 0.5, w: 0.64, h: 0.5, label: "portrait photo" },
];
/** Index of the portrait photo that gets fitted. */
export const PORTRAIT = 3;
/** Width / height of each photo file (public/travel), for fitting. */
const ASPECT: Partial<Record<PhotoKind, number>> = { positano: 1600 / 2400, "aerial-shore": 1600 / 2848 };

export type CollageState = {
  /** 0..1 per cell: how far its picture has landed (0 = empty slot). */
  filled?: number[];
  /** 0..1: the portrait photo fitted whole (1) instead of filling its cell (0). */
  fit?: number;
  /** 0..1: blurred sides fade in. */
  sides?: number;
  /** Characters of the caption typed so far (-1 = no caption). */
  caption?: number;
  /** "MOVING" / "STILL" tags over the cells. */
  tags?: number;
  /** Highlight ring per cell (0..1). */
  rings?: number[];
  /** Video playback on (1) or paused (0). */
  playing?: number;
  /** Show ▶ badges on video cells. */
  badges?: boolean;
  gap?: number;
  radius?: number;
  background?: string;
};

export const CAPTION = "summer, unfiltered";

/** A video cell's picture: drifting, with light sweeping over it, like a clip playing. */
export const Moving: React.FC<{ kind: PhotoKind; f: number; seed: number; playing: number }> = ({ kind, f, seed, playing }) => {
  const t = (f + seed * 40) / 30;
  const s = 1.18 + 0.06 * Math.sin(t * 0.9) * playing;
  const x = Math.sin(t * 0.7) * 5 * playing;
  const y = Math.cos(t * 0.55) * 4 * playing;
  const sweep = ((f * 1.6 + seed * 70) % 260) - 80;
  return (
    <>
      <Img
        src={staticFile(`travel/${kind}.jpg`)}
        style={{ position: "absolute", inset: 0, width: "100%", height: "100%", objectFit: "cover", scale: String(s), translate: `${x}% ${y}%` }}
      />
      <div
        style={{
          position: "absolute",
          inset: 0,
          background: `linear-gradient(105deg, transparent ${sweep}%, rgba(255,255,255,${0.22 * playing}) ${sweep + 12}%, transparent ${sweep + 26}%)`,
          mixBlendMode: "screen",
        }}
      />
    </>
  );
};

export const Collage: React.FC<{ w: number; h: number; s: CollageState }> = ({ w, h, s }) => {
  const f = useCurrentFrame();
  const gap = (s.gap ?? 5) * (w / 352);
  const radius = (s.radius ?? 8) * (w / 352);
  const unit = w / 352;
  const playing = s.playing ?? 1;
  return (
    <div style={{ position: "relative", width: w, height: h, background: s.background ?? "#16121f", borderRadius: radius * 1.4, overflow: "hidden" }}>
      {CELLS.map((c, i) => {
        const L = gap + c.x * (w - gap);
        const T = gap + c.y * (h - gap);
        const W = c.w * (w - gap) - gap;
        const H = c.h * (h - gap) - gap;
        const land = s.filled ? s.filled[i] : 1;
        const fit = i === PORTRAIT ? (s.fit ?? 0) : 0;
        const sides = i === PORTRAIT ? (s.sides ?? 0) : 0;
        const ring = s.rings?.[i] ?? 0;
        // fitted: the whole picture, as wide as the cell's height allows
        const a = ASPECT[c.kind] ?? 0.66;
        const fitW = Math.min(W, H * a);
        const imgW = W + (fitW - W) * fit;
        const prog = ((f + i * 23) % 150) / 150;
        return (
          <div key={i} style={{ position: "absolute", left: L, top: T, width: W, height: H }}>
            {/* empty slot */}
            <div
              style={{
                position: "absolute",
                inset: 0,
                borderRadius: radius,
                border: `${1.5 * unit}px dashed rgba(255,255,255,${0.3 * (1 - land)})`,
                background: `rgba(255,255,255,${0.05 * (1 - land)})`,
                display: "flex",
                alignItems: "center",
                justifyContent: "center",
                color: `rgba(255,255,255,${0.4 * (1 - land)})`,
                fontSize: 26 * unit,
                fontWeight: 300,
              }}
            >
              +
            </div>
            <div
              style={{
                position: "absolute",
                inset: 0,
                borderRadius: radius,
                overflow: "hidden",
                opacity: Math.min(1, land * 1.6),
                scale: String(0.6 + 0.4 * land),
                background: "#222",
              }}
            >
              {sides > 0 ? (
                <Img
                  src={staticFile(`travel/${c.kind}.jpg`)}
                  style={{ position: "absolute", inset: -20 * unit, width: W + 40 * unit, height: H + 40 * unit, objectFit: "cover", filter: `blur(${9 * unit}px) brightness(0.78) saturate(1.3)`, opacity: sides }}
                />
              ) : null}
              <div style={{ position: "absolute", top: 0, bottom: 0, left: (W - imgW) / 2, width: imgW, overflow: "hidden", boxShadow: fit > 0.05 ? `0 0 ${12 * unit}px rgba(0,0,0,${0.35 * fit})` : undefined }}>
                {c.video ? (
                  <Moving kind={c.kind} f={f} seed={i} playing={playing} />
                ) : (
                  <Img src={staticFile(`travel/${c.kind}.jpg`)} style={{ position: "absolute", inset: 0, width: "100%", height: "100%", objectFit: "cover" }} />
                )}
              </div>
              {c.video && s.badges !== false ? (
                <>
                  <div style={{ position: "absolute", left: 6 * unit, top: 6 * unit, padding: `${2 * unit}px ${6 * unit}px`, borderRadius: 10 * unit, background: "rgba(0,0,0,0.55)", color: "#fff", fontFamily, fontWeight: 700, fontSize: 10 * unit, opacity: land }}>
                    ▶ 0:{String(Math.floor(prog * 12) + 1).padStart(2, "0")}
                  </div>
                  <div style={{ position: "absolute", left: 6 * unit, right: 6 * unit, bottom: 6 * unit, height: 3 * unit, borderRadius: 2 * unit, background: "rgba(255,255,255,0.3)", opacity: land * playing }}>
                    <div style={{ width: `${prog * 100}%`, height: "100%", borderRadius: 2 * unit, background: "#fff" }} />
                  </div>
                </>
              ) : null}
            </div>
            {/* MOVING / STILL tags */}
            {(s.tags ?? 0) > 0 ? (
              <div
                style={{
                  position: "absolute",
                  left: "50%",
                  top: "50%",
                  translate: "-50% -50%",
                  padding: `${4 * unit}px ${10 * unit}px`,
                  borderRadius: 20 * unit,
                  background: c.video ? C.pink : C.purple,
                  color: "#fff",
                  fontFamily,
                  fontWeight: 800,
                  fontSize: 13 * unit,
                  letterSpacing: 1 * unit,
                  whiteSpace: "nowrap",
                  scale: String(s.tags ?? 0),
                  rotate: c.video ? `${Math.sin(f / 3 + i) * 4}deg` : "0deg",
                  boxShadow: "0 4px 12px rgba(0,0,0,0.35)",
                }}
              >
                {c.video ? "▶ MOVING" : "❚❚ STILL"}
              </div>
            ) : null}
            {ring > 0 ? (
              <div
                style={{
                  position: "absolute",
                  inset: -3 * unit,
                  borderRadius: radius + 3 * unit,
                  border: `${3 * unit}px solid ${c.video ? C.pink : C.gold}`,
                  boxShadow: `0 0 ${18 * unit}px ${c.video ? C.pink : C.gold}`,
                  opacity: ring,
                  scale: String(1 + 0.04 * (1 - ring)),
                }}
              />
            ) : null}
          </div>
        );
      })}
      {(s.caption ?? -1) >= 0 ? (
        <div
          style={{
            position: "absolute",
            left: 0,
            right: 0,
            top: h * 0.41,
            textAlign: "center",
            fontFamily: F.dreamy,
            fontSize: 40 * unit,
            color: "#fff",
            textShadow: "0 3px 12px rgba(0,0,0,0.55)",
            whiteSpace: "nowrap",
            scale: String(ip(s.caption ?? 0, 0, 3, 0.7, 1, POP)),
          }}
        >
          {CAPTION.slice(0, s.caption ?? 0)}
        </div>
      ) : null}
    </div>
  );
};
