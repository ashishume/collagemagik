import React from "react";
import { Img, staticFile } from "remotion";
import type { PhotoKind } from "../ad/TripPhoto";
import { C, fontFamily } from "../ad/theme";
import { ip, POP } from "../ad5/kit";

/** The phone screen is drawn in these units (iPhone 17 Pro proportions), then scaled into the frame. */
export const SW = 400;
export const SH = (400 * 2868) / 1320;

/** The app's name as the voiceover says it and as the App Store listing will show it. */
export const NAME = "Collage Magic";

const RIM = 0.014;
const BEZEL = 0.026;

/** Full height of the iPhone frame for a given width. */
export const phoneHeight = (width: number) => {
  const pad = width * (RIM + BEZEL);
  return ((width - pad * 2) / SW) * SH + pad * 2;
};

/**
 * An iPhone 17 Pro style frame: brushed titanium rim, black bezel, side buttons, Dynamic Island and a soft glass glare.
 * Children are drawn in screen units (SW x SH).
 */
export const IPhone: React.FC<{ width: number; glow?: string; children: React.ReactNode; style?: React.CSSProperties }> = ({ width, glow = "rgba(43,20,92,0.45)", children, style }) => {
  const rim = width * RIM;
  const bezel = width * BEZEL;
  const sw = width - (rim + bezel) * 2;
  const k = sw / SW;
  const h = phoneHeight(width);
  const btn = (side: "l" | "r", top: number, len: number) => (
    <div
      style={{
        position: "absolute",
        [side === "l" ? "left" : "right"]: -width * 0.008,
        top: h * top,
        width: width * 0.012,
        height: h * len,
        borderRadius: width * 0.01,
        background: "linear-gradient(90deg,#6d6775,#2e2b33)",
      }}
    />
  );
  return (
    <div style={{ position: "relative", width, height: h, ...style }}>
      {btn("l", 0.17, 0.04)}
      {btn("l", 0.235, 0.07)}
      {btn("l", 0.32, 0.07)}
      {btn("r", 0.26, 0.11)}
      {btn("r", 0.56, 0.06)}
      <div
        style={{
          position: "absolute",
          inset: 0,
          borderRadius: width * 0.165,
          background: "linear-gradient(135deg,#7d7787 0%,#2c2931 22%,#9a94a3 48%,#2c2931 74%,#5d5866 100%)",
          padding: rim,
          boxSizing: "border-box",
          boxShadow: `0 ${width * 0.07}px ${width * 0.18}px ${glow}, 0 ${width * 0.02}px ${width * 0.04}px rgba(0,0,0,0.35)`,
        }}
      >
        <div style={{ width: "100%", height: "100%", borderRadius: width * 0.152, background: "#050507", padding: bezel, boxSizing: "border-box" }}>
          <div style={{ position: "relative", width: sw, height: SH * k, borderRadius: width * 0.125, overflow: "hidden", background: "#000" }}>
            <div style={{ position: "absolute", left: 0, top: 0, width: SW, height: SH, scale: String(k), transformOrigin: "0 0", fontFamily }}>
              {children}
              {/* Dynamic Island */}
              <div style={{ position: "absolute", left: SW / 2 - 56, top: 11, width: 112, height: 33, borderRadius: 17, background: "#000", zIndex: 90 }} />
            </div>
            <div style={{ position: "absolute", inset: 0, background: "linear-gradient(125deg, rgba(255,255,255,0.10) 0%, rgba(255,255,255,0) 32%, rgba(255,255,255,0) 70%, rgba(255,255,255,0.05) 100%)", pointerEvents: "none" }} />
          </div>
        </div>
      </div>
    </div>
  );
};

/** iOS status bar (time, signal, battery) in screen units. */
export const StatusBar: React.FC<{ dark?: boolean }> = ({ dark = true }) => {
  const col = dark ? "#fff" : "#111";
  return (
    <>
      <div style={{ position: "absolute", left: 40, top: 18, fontSize: 15, fontWeight: 700, color: col, zIndex: 91 }}>9:41</div>
      <div style={{ position: "absolute", right: 34, top: 20, display: "flex", gap: 5, alignItems: "center", zIndex: 91 }}>
        <div style={{ display: "flex", gap: 1.5, alignItems: "flex-end" }}>
          {[5, 7, 9, 11].map((x) => (
            <div key={x} style={{ width: 3, height: x, borderRadius: 1, background: col }} />
          ))}
        </div>
        <div style={{ width: 24, height: 11, borderRadius: 3.5, border: `1.2px solid ${col}`, padding: 1.3, boxSizing: "border-box", opacity: 0.9 }}>
          <div style={{ width: "80%", height: "100%", borderRadius: 1.5, background: col }} />
        </div>
      </div>
    </>
  );
};

/** A video clip that really looks like it's playing: drifting picture, light sweep, running progress bar. */
export const Clip: React.FC<{ kind: PhotoKind; f: number; seed?: number; zoom?: number; badge?: boolean; u?: number }> = ({ kind, f, seed = 0, zoom = 1, badge = true, u = 1 }) => {
  const t = (f + seed * 37) / 30;
  const s = (1.16 + 0.07 * Math.sin(t * 1.1)) * zoom;
  const x = Math.sin(t * 0.8) * 5;
  const y = Math.cos(t * 0.6) * 4;
  const sweep = ((f * 1.8 + seed * 70) % 280) - 90;
  const prog = ((f + seed * 41) % 240) / 240;
  return (
    <>
      <Img src={staticFile(`travel/${kind}.jpg`)} style={{ position: "absolute", inset: 0, width: "100%", height: "100%", objectFit: "cover", scale: String(s), translate: `${x}% ${y}%` }} />
      <div style={{ position: "absolute", inset: 0, background: `linear-gradient(105deg, transparent ${sweep}%, rgba(255,255,255,0.2) ${sweep + 12}%, transparent ${sweep + 26}%)`, mixBlendMode: "screen" }} />
      {badge ? (
        <>
          <div style={{ position: "absolute", left: 6 * u, top: 6 * u, padding: `${2 * u}px ${6 * u}px`, borderRadius: 8 * u, background: "rgba(0,0,0,0.55)", color: "#fff", fontSize: 9 * u, fontWeight: 800, display: "flex", gap: 3 * u, alignItems: "center" }}>
            <span style={{ color: "#ff5a7a" }}>●</span> 0:{String(Math.floor(prog * 12)).padStart(2, "0")}
          </div>
          <div style={{ position: "absolute", left: 6 * u, right: 6 * u, bottom: 6 * u, height: 3 * u, borderRadius: 2 * u, background: "rgba(255,255,255,0.3)" }}>
            <div style={{ width: `${prog * 100}%`, height: "100%", borderRadius: 2 * u, background: "#fff" }} />
          </div>
        </>
      ) : null}
    </>
  );
};

/** A still photo. */
export const Still: React.FC<{ kind: PhotoKind; zoom?: number; pan?: number; small?: boolean }> = ({ kind, zoom = 1, pan = 0, small }) => (
  <Img
    src={staticFile(small ? `travel/thumb/${kind}.jpg` : `travel/${kind}.jpg`)}
    style={{ position: "absolute", inset: 0, width: "100%", height: "100%", objectFit: "cover", scale: String(zoom), translate: `${pan * 6}% 0` }}
  />
);

/** "Download on the App Store" badge, drawn (no Apple artwork files needed). */
export const StoreBadge: React.FC<{ u: number; light?: boolean }> = ({ u, light }) => (
  <div
    style={{
      display: "inline-flex",
      alignItems: "center",
      gap: 16 * u,
      padding: `${16 * u}px ${34 * u}px`,
      borderRadius: 22 * u,
      background: light ? "#fff" : "#000",
      color: light ? "#000" : "#fff",
      border: `${2 * u}px solid ${light ? "rgba(0,0,0,0.12)" : "rgba(255,255,255,0.35)"}`,
      fontFamily,
    }}
  >
    <svg width={44 * u} height={52 * u} viewBox="0 0 170 200">
      <path
        fill="currentColor"
        d="M140 106c0-26 21-38 22-39-12-18-31-20-37-20-16-2-31 9-39 9s-21-9-34-9C34 47 18 57 9 73c-19 32-5 80 13 106 9 13 19 27 33 26 13 0 18-8 34-8s20 8 34 8 23-13 32-26c10-15 14-29 14-30 0 0-28-11-29-43zM114 28c7-9 12-21 11-33-10 0-23 7-30 16-7 8-13 20-11 32 11 1 23-6 30-15z"
      />
    </svg>
    <div>
      <div style={{ fontSize: 18 * u, fontWeight: 600, lineHeight: 1 }}>Download on the</div>
      <div style={{ fontSize: 40 * u, fontWeight: 700, lineHeight: 1.05, letterSpacing: -0.5 * u }}>App Store</div>
    </div>
  </div>
);

/** The app icon. */
export const AppIcon: React.FC<{ size: number }> = ({ size }) => (
  <Img src={staticFile("brand/icon.png")} style={{ width: size, height: size, borderRadius: size * 0.225, boxShadow: `0 ${size * 0.12}px ${size * 0.3}px rgba(0,0,0,0.3)` }} />
);

/** A word or line that pops in (overshoot) and leaves with a quick shrink. */
export const popIn = (f: number, at: number, out = Infinity, len = 10) => {
  const a = ip(f, at, at + len, 0, 1, POP);
  const b = Number.isFinite(out) ? ip(f, out, out + 7) : 0;
  return { o: Math.min(1, ip(f, at, at + 4)) * (1 - b), s: a * (1 - 0.3 * b) };
};

export { C };
