import React from "react";
import { Easing, interpolate, useCurrentFrame } from "remotion";
import { PhotoKind, TripPhoto } from "../ad/TripPhoto";
import { AIR, C, clamp, fontFamily, SOFT } from "../ad/theme";
import { F } from "./fonts";
import { T } from "./timeline";

/**
 * A live, animated copy of the CollageMagik editor, drawn in "screen units" (400 wide, the phone's aspect), so every
 * gesture in the voiceover really happens: layouts morph, photos fly in from the tray, borders slide, cells swap,
 * a photo lands on top, changes frame, is twisted and locks straight, captions change font, the design turns into a
 * carousel, changes size and exports.
 */
export const SW = 400;
export const SH = (400 * 2868) / 1320;

export const POP = Easing.bezier(0.34, 1.56, 0.64, 1);
export const ip = (f: number, a: number, b: number, from = 0, to = 1, easing = AIR) =>
  interpolate(f, [a, b], [from, to], { ...clamp, easing });
/** A value that eases to each new target in turn. */
export const steps = (f: number, init: number, list: [number, number][], dur = 12, easing = AIR) => {
  let v = init;
  for (const [at, to] of list) v += (to - v) * ip(f, at, at + dur, 0, 1, easing);
  return v;
};
/** 0 -> 1 -> 0 visibility window with short fades. */
export const win = (f: number, from: number, to: number, fade = 6) => ip(f, from, from + fade) * (1 - ip(f, to, to + fade));

type R = { x: number; y: number; w: number; h: number };
const mix = (a: R, b: R, t: number): R => ({ x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t, w: a.w + (b.w - a.w) * t, h: a.h + (b.h - a.h) * t });
const mixAll = (a: R[], b: R[], t: number) => a.map((r, i) => mix(r, b[i], t));
const grid = (sx: number, sy: number): R[] => [
  { x: 0, y: 0, w: sx, h: sy },
  { x: sx, y: 0, w: 1 - sx, h: sy },
  { x: 0, y: sy, w: sx, h: 1 - sy },
  { x: sx, y: sy, w: 1 - sx, h: 1 - sy },
];
const BIG_TOP: R[] = [
  { x: 0, y: 0, w: 1, h: 0.58 },
  { x: 0, y: 0.58, w: 1 / 3, h: 0.42 },
  { x: 1 / 3, y: 0.58, w: 1 / 3, h: 0.42 },
  { x: 2 / 3, y: 0.58, w: 1 / 3, h: 0.42 },
];
const BIG_LEFT: R[] = [
  { x: 0, y: 0, w: 0.6, h: 1 },
  { x: 0.6, y: 0, w: 0.4, h: 1 / 3 },
  { x: 0.6, y: 1 / 3, w: 0.4, h: 1 / 3 },
  { x: 0.6, y: 2 / 3, w: 0.4, h: 1 / 3 },
];

export const PHOTOS: PhotoKind[] = ["palm-beach", "overwater", "turquoise", "dock"];
export const TOP_PHOTO: PhotoKind = "santorini-domes";
const TRAY: PhotoKind[] = [...PHOTOS, TOP_PHOTO, "venice-canal"];
const thumbAt = (i: number) => ({ x: 51 + 60 * i, y: 717 });

const BOX = { x: 24, y: 106, w: 352, h: 532 };
const G = 5;

/** Where everything is at frame f, in screen units. */
const geom = (f: number) => {
  const aspect = steps(f, 0.8, [[T.story - 3, 9 / 16], [T.instagram - 1, 1], [T.tiktok - 3, 9 / 16], [T.exp - 14, 0.8]], 12);
  const cw = Math.min(BOX.w, BOX.h * aspect);
  const ch = cw / aspect;
  const cx = 200 - cw / 2;
  const cy = BOX.y + BOX.h / 2 - ch / 2;
  const sx = steps(f, 0.5, [[T.drag2 + 8, 0.64]], 16, SOFT);
  const sy = steps(f, 0.5, [[T.drag2 + 28, 0.42]], 14, SOFT);
  let rects = mixAll(BIG_TOP, BIG_LEFT, ip(f, T.pick + 4, T.pick + 14));
  rects = mixAll(rects, grid(sx, sy), ip(f, T.pick + 17, T.pick + 27));
  const px = (r: R): R => ({ x: cx + G + r.x * (cw - G), y: cy + G + r.y * (ch - G), w: r.w * (cw - G) - G, h: r.h * (ch - G) - G });
  const cells = rects.map(px);
  const ow = 0.46 * Math.min(cw, ch * 0.8);
  return { aspect, cw, ch, cx, cy, sx, sy, cells, ow, oh: ow * 1.2, ocx: cx + cw / 2, ocy: cy + ch * 0.4, capX: cx + cw / 2, capY: cy + ch * 0.8 };
};
type Geom = ReturnType<typeof geom>;

const center = (r: R) => ({ x: r.x + r.w / 2, y: r.y + r.h / 2 });

/** When each drag-in photo flies from the tray to its cell. */
const flyIn = (i: number) => T.drag1 + 2 + i * 9;
const LAND_OVERLAY = () => T.drop + 22;

const frameStyle = (f: number): "none" | "instant" | "torn" => (f < T.white - 2 ? "none" : f < T.torn - 2 ? "instant" : "torn");

/** Rotation of the photo on top, in degrees: twisted by two fingers, then it clicks onto straight. */
export const angleAt = (f: number) => {
  if (f >= T.click) return 0;
  if (f < T.twist - 6) return -8;
  return interpolate(f, [T.twist - 6, T.twist + 10, T.twist + 22, T.click - 8, T.click - 1], [-8, 27, 15, 3.5, 3], { ...clamp, easing: SOFT });
};

const FONT_STYLES = [
  { name: "Classic", ff: F.classic, size: 26, weight: 800 },
  { name: "Poster", ff: F.poster, size: 32, weight: 400, upper: true },
  { name: "Type", ff: F.type, size: 23, weight: 400 },
  { name: "Hand", ff: F.hand, size: 38, weight: 700 },
  { name: "Script", ff: F.script, size: 46, weight: 400 },
  { name: "Dreamy", ff: F.dreamy, size: 52, weight: 400 },
];
const fontChanges = () => [T.add, T.dreamy - 8, T.dreamy, T.dreamy + 8, T.script - 2];
const fontIdx = (f: number) => {
  const ch = fontChanges();
  let k = 0;
  ch.forEach((at, i) => {
    if (f >= at) k = i;
  });
  return k;
};

/** Jagged outline for the torn-paper frame (deterministic). */
const tornPath = (w: number, h: number) => {
  const pts: string[] = [];
  const n = (i: number) => (Math.sin(i * 12.9898) * 43758.5453) % 1;
  const j = (i: number) => Math.abs(n(i)) * 4;
  const step = 7;
  let i = 0;
  for (let x = 0; x <= w; x += step) pts.push(`${x}px ${j(i++)}px`);
  for (let y = 0; y <= h; y += step) pts.push(`${w - j(i++)}px ${y}px`);
  for (let x = w; x >= 0; x -= step) pts.push(`${x}px ${h - j(i++)}px`);
  for (let y = h; y >= 0; y -= step) pts.push(`${j(i++)}px ${y}px`);
  return `polygon(${pts.join(",")})`;
};

/** A photo in its frame: none, a white instant-photo frame, or torn paper. */
export const FramedPhoto: React.FC<{ kind: PhotoKind; w: number; h: number; frame: "none" | "instant" | "torn"; hd?: boolean }> = ({ kind, w, h, frame, hd }) => {
  const pad = frame === "instant" ? { t: 7, s: 7, b: 28 } : frame === "torn" ? { t: 9, s: 9, b: 9 } : { t: 0, s: 0, b: 0 };
  const W = w + pad.s * 2;
  const H = h + pad.t + pad.b;
  return (
    <div style={{ width: W, height: H, filter: "drop-shadow(0 8px 14px rgba(0,0,0,0.5))" }}>
      <div
        style={{
          position: "relative",
          width: W,
          height: H,
          background: frame === "none" ? "transparent" : frame === "torn" ? "#FBF7EE" : "#FFFFFF",
          clipPath: frame === "torn" ? tornPath(W, H) : undefined,
          borderRadius: frame === "instant" ? 3 : 0,
        }}
      >
        <TripPhoto kind={kind} hd={hd} style={{ position: "absolute", left: pad.s, top: pad.t, width: w, height: h, borderRadius: frame === "none" ? 4 : 1 }} />
      </div>
    </div>
  );
};

/** The carousel: three slides side by side, with one photo crossing from slide 1 into slide 2. */
export const STRIP: { k: PhotoKind; r: R; hd?: boolean; cross?: boolean }[] = [
  { k: "palm-beach", r: { x: 0, y: 0, w: 0.5, h: 0.5 } },
  { k: "pizza", r: { x: 0, y: 0.5, w: 0.5, h: 0.5 } },
  { k: "santorini-sunset", r: { x: 0.5, y: 0.1, w: 1.1, h: 0.8 }, hd: true, cross: true },
  { k: "dinner-fira", r: { x: 1.6, y: 0, w: 0.4, h: 0.55 } },
  { k: "santorini-domes", r: { x: 1.6, y: 0.55, w: 0.4, h: 0.45 } },
  { k: "overwater", r: { x: 2, y: 0, w: 1, h: 0.6 }, hd: true },
  { k: "dock", r: { x: 2, y: 0.6, w: 0.5, h: 0.4 } },
  { k: "turquoise", r: { x: 2.5, y: 0.6, w: 0.5, h: 0.4 } },
];

/** All three slides of the carousel, drawn `slideW` wide each. `glow` outlines the photo that crosses the seam. */
export const StripContent: React.FC<{ slideW: number; slideH: number; gap: number; glow?: number; radius?: number }> = ({ slideW, slideH, gap, glow = 0, radius = 3 }) => {
  const W = slideW * 3;
  return (
    <div style={{ position: "absolute", left: 0, top: 0, width: W, height: slideH, background: "#120d22" }}>
      {STRIP.map((p, i) => {
        const x = gap + (p.r.x / 3) * (W - gap);
        const y = gap + p.r.y * (slideH - gap);
        const w = (p.r.w / 3) * (W - gap) - gap;
        const h = p.r.h * (slideH - gap) - gap;
        return (
          <div key={i} style={{ position: "absolute", left: x, top: y, width: w, height: h }}>
            <TripPhoto kind={p.k} hd={p.hd} style={{ width: "100%", height: "100%", borderRadius: radius }} />
            {p.cross && glow > 0 ? (
              <div
                style={{
                  position: "absolute",
                  inset: -gap * 0.6,
                  borderRadius: radius + 3,
                  border: `${Math.max(2, gap * 0.7)}px solid #FFD25E`,
                  boxShadow: `0 0 ${gap * 4}px ${gap}px rgba(255,210,94,0.6)`,
                  opacity: glow,
                }}
              />
            ) : null}
          </div>
        );
      })}
    </div>
  );
};

/** A finger on the glass. */
const Touch: React.FC<{ x: number; y: number; o?: number; down?: boolean }> = ({ x, y, o = 1, down = true }) => (
  <div
    style={{
      position: "absolute",
      left: x - 17,
      top: y - 17,
      width: 34,
      height: 34,
      borderRadius: "50%",
      background: "rgba(255,255,255,0.78)",
      border: "2.5px solid rgba(255,255,255,0.95)",
      boxShadow: "0 0 0 6px rgba(255,255,255,0.22), 0 6px 16px rgba(0,0,0,0.35)",
      opacity: o,
      scale: String(down ? 0.86 : 1),
    }}
  />
);

/** A tap: the finger arrives, presses, lifts. */
const tapAt = (f: number, at: number, x: number, y: number) => {
  if (f < at - 6 || f > at + 6) return null;
  return { x, y, o: win(f, at - 6, at + 2, 4), down: f >= at - 1 && f <= at + 3 };
};

const Glass: React.FC<{ style: React.CSSProperties; children?: React.ReactNode }> = ({ style, children }) => (
  <div
    style={{
      position: "absolute",
      background: "rgba(255,255,255,0.09)",
      border: "1px solid rgba(255,255,255,0.16)",
      boxShadow: "inset 0 1px 0 rgba(255,255,255,0.12)",
      ...style,
    }}
  >
    {children}
  </div>
);

const Label: React.FC<{ x: number; y: number; children: React.ReactNode; size?: number; color?: string; weight?: number }> = ({ x, y, children, size = 12, color = "rgba(255,255,255,0.7)", weight = 600 }) => (
  <div style={{ position: "absolute", left: x, top: y, fontSize: size, color, fontWeight: weight, whiteSpace: "nowrap" }}>{children}</div>
);

// ---- bottom panel contents ----

const LAYOUT_TILES: { name: string; rects: R[] }[] = [
  { name: "Grid", rects: grid(0.5, 0.5) },
  { name: "Big on top", rects: BIG_TOP },
  { name: "Big left", rects: BIG_LEFT },
  { name: "Middle", rects: [{ x: 0, y: 0, w: 1, h: 0.3 }, { x: 0, y: 0.3, w: 0.5, h: 0.4 }, { x: 0.5, y: 0.3, w: 0.5, h: 0.4 }, { x: 0, y: 0.7, w: 1, h: 0.3 }] },
  { name: "Columns", rects: [0, 1, 2, 3].map((i) => ({ x: i / 4, y: 0, w: 0.25, h: 1 })) },
];
const tileCenter = (i: number) => ({ x: 55 + 72 * i, y: 726 });

const LayoutPanel: React.FC<{ f: number }> = ({ f }) => {
  const active = f < T.pick + 3 ? 1 : f < T.pick + 16 ? 2 : 0;
  return (
    <>
      <Label x={28} y={664}>Cells</Label>
      {[1, 2, 3, 4, 5, 6, 7].map((n, i) => (
        <div key={n} style={{ position: "absolute", left: 76 + i * 40, top: 658, width: 28, height: 28, borderRadius: 14, display: "flex", alignItems: "center", justifyContent: "center", fontSize: 13, fontWeight: 700, color: "#fff", background: n === 4 ? C.purple : "transparent" }}>
          {n}
        </div>
      ))}
      {LAYOUT_TILES.map((t, i) => {
        const c = tileCenter(i);
        const on = i === active;
        return (
          <div key={t.name} style={{ position: "absolute", left: c.x - 31, top: c.y - 31, width: 62, height: 62, borderRadius: 12, background: on ? C.purple : "rgba(255,255,255,0.07)", scale: String(on ? 1.04 : 1) }}>
            {t.rects.map((r, k) => (
              <div key={k} style={{ position: "absolute", left: 14 + r.x * 34 + 1, top: 8 + r.y * 40 + 1, width: r.w * 34 - 2, height: r.h * 40 - 2, borderRadius: 2, background: on ? "rgba(255,255,255,0.92)" : "rgba(255,255,255,0.45)" }} />
            ))}
            <div style={{ position: "absolute", left: -6, right: -6, top: 66, textAlign: "center", fontSize: 10, color: "rgba(255,255,255,0.75)", fontWeight: 600 }}>{t.name}</div>
          </div>
        );
      })}
      <Label x={28} y={776} size={11} color="rgba(255,255,255,0.6)">↔ Drag the borders between pictures to resize them</Label>
    </>
  );
};

const MediaPanel: React.FC<{ f: number }> = ({ f }) => (
  <>
    <Label x={28} y={664} size={13} color="#fff" weight={700}>Your trip</Label>
    <Label x={300} y={665} size={12} color={C.purple}>412 items</Label>
    {TRAY.map((k, i) => {
      const c = thumbAt(i);
      const used = i < 4 ? f >= flyIn(i) : i === 4 ? f >= T.drop + 2 : false;
      return (
        <div key={k} style={{ position: "absolute", left: c.x - 27, top: c.y - 27, width: 54, height: 54 }}>
          <TripPhoto kind={k} style={{ width: 54, height: 54, borderRadius: 10, opacity: used ? 0.45 : 1 }} />
          {used ? (
            <div style={{ position: "absolute", right: -4, top: -4, width: 18, height: 18, borderRadius: 9, background: C.purple, color: "#fff", fontSize: 11, fontWeight: 800, display: "flex", alignItems: "center", justifyContent: "center", border: "2px solid #fff" }}>✓</div>
          ) : null}
        </div>
      );
    })}
    <Label x={28} y={762} size={11} color="rgba(255,255,255,0.6)">Drag a photo onto the design, or onto a picture to place it on top</Label>
  </>
);

const FRAMES = ["None", "Border", "Instant", "Torn", "Shadow"];
const frameChip = (i: number) => ({ x: 55 + 72 * i, y: 722 });
const FramePanel: React.FC<{ f: number }> = ({ f }) => {
  const st = frameStyle(f);
  const active = st === "none" ? 0 : st === "instant" ? 2 : 3;
  return (
    <>
      <Label x={28} y={664} size={13} color="#fff" weight={700}>Frame</Label>
      {FRAMES.map((n, i) => {
        const c = frameChip(i);
        const on = i === active;
        return (
          <div key={n} style={{ position: "absolute", left: c.x - 29, top: c.y - 29, width: 58, height: 58, borderRadius: 12, background: on ? C.purple : "rgba(255,255,255,0.07)" }}>
            <div
              style={{
                position: "absolute",
                left: 15,
                top: 10,
                width: 28,
                height: 34,
                background: i === 0 ? "transparent" : "#fff",
                borderRadius: i === 1 ? 2 : 1,
                clipPath: i === 3 ? tornPath(28, 34) : undefined,
                boxShadow: i === 4 ? "0 4px 8px rgba(0,0,0,0.6)" : undefined,
              }}
            >
              <div style={{ position: "absolute", left: i === 0 ? 0 : 3, top: i === 0 ? 0 : 3, right: i === 0 ? 0 : 3, bottom: i === 2 ? 10 : i === 0 ? 0 : 3, background: "linear-gradient(160deg,#79c7e8,#2a6fb0)", borderRadius: 1 }} />
            </div>
            <div style={{ position: "absolute", left: -8, right: -8, top: 62, textAlign: "center", fontSize: 10, color: "rgba(255,255,255,0.75)", fontWeight: 600 }}>{n}</div>
          </div>
        );
      })}
    </>
  );
};

const fontChip = (i: number) => ({ x: 52 + 59 * i, y: 706 });
const TextPanel: React.FC<{ f: number }> = ({ f }) => {
  const active = fontIdx(f);
  return (
    <>
      {FONT_STYLES.map((s, i) => {
        const c = fontChip(i);
        const on = i === active;
        return (
          <div key={s.name} style={{ position: "absolute", left: c.x - 26, top: c.y - 30, width: 52, height: 56, borderRadius: 12, background: on ? C.purple : "rgba(255,255,255,0.07)", textAlign: "center", color: "#fff" }}>
            <div style={{ fontFamily: s.ff, fontSize: s.size * 0.62, fontWeight: s.weight, lineHeight: "36px", textTransform: s.upper ? "uppercase" : undefined }}>Aa</div>
            <div style={{ fontSize: 9.5, fontWeight: 600, color: "rgba(255,255,255,0.8)" }}>{s.name}</div>
          </div>
        );
      })}
      {["#fff", "#1E1438", "#F4B23C", "#E0457B", "#F2795B", "#8F6BFF", "#5AC8FA", "#34C759"].map((c, i) => (
        <div key={c} style={{ position: "absolute", left: 28 + i * 40, top: 752, width: 26, height: 26, borderRadius: 13, background: c, border: i === 0 ? `3px solid ${C.purple}` : "2px solid rgba(255,255,255,0.3)", boxSizing: "border-box" }} />
      ))}
    </>
  );
};

const SlidesPanel: React.FC = () => (
  <>
    <Label x={28} y={666} size={13} color="#fff" weight={700}>Slides</Label>
    {[2, 3, 4, 5, 6].map((n, i) => (
      <div key={n} style={{ position: "absolute", left: 96 + i * 46, top: 660, width: 32, height: 32, borderRadius: 16, display: "flex", alignItems: "center", justifyContent: "center", fontSize: 14, fontWeight: 700, color: "#fff", background: n === 3 ? C.purple : "rgba(255,255,255,0.07)" }}>
        {n}
      </div>
    ))}
    <div style={{ position: "absolute", left: 28, top: 712, width: 344, height: 52, borderRadius: 14, background: "rgba(255,255,255,0.07)", display: "flex", alignItems: "center", gap: 10, padding: "0 14px", boxSizing: "border-box", color: "rgba(255,255,255,0.85)", fontSize: 12, fontWeight: 600 }}>
      <span style={{ fontSize: 18 }}>⇄</span> Pictures flow from one slide into the next
    </div>
  </>
);

const FORMATS = [
  { name: "Post", ratio: "4:5", a: 0.8 },
  { name: "Story", ratio: "9:16", a: 9 / 16 },
  { name: "Square", ratio: "1:1", a: 1 },
];
const formatChip = (i: number) => ({ x: 80 + 120 * i, y: 722 });
const FormatPanel: React.FC<{ g: Geom }> = ({ g }) => {
  const active = FORMATS.reduce((b, s, i) => (Math.abs(s.a - g.aspect) < Math.abs(FORMATS[b].a - g.aspect) ? i : b), 0);
  return (
    <>
      <Label x={28} y={664} size={13} color="#fff" weight={700}>Size</Label>
      {FORMATS.map((s, i) => {
        const c = formatChip(i);
        const on = i === active;
        const h = 34;
        const w = h * s.a;
        return (
          <div key={s.name} style={{ position: "absolute", left: c.x - 52, top: c.y - 36, width: 104, height: 76, borderRadius: 14, background: on ? C.purple : "rgba(255,255,255,0.07)", color: "#fff", textAlign: "center" }}>
            <div style={{ margin: "8px auto 4px", width: w, height: h, borderRadius: 3, border: "2px solid rgba(255,255,255,0.9)" }} />
            <div style={{ fontSize: 12, fontWeight: 700 }}>
              {s.name} <span style={{ opacity: 0.7, fontWeight: 600 }}>{s.ratio}</span>
            </div>
          </div>
        );
      })}
    </>
  );
};

type Mode = "layout" | "media" | "frame" | "text" | "slides" | "format";
const schedule = (): { mode: Mode; from: number; to: number; tab: number }[] => [
  { mode: "layout", from: -999, to: T.drag1 - 3, tab: 1 },
  { mode: "media", from: T.drag1 - 3, to: T.drag2 - 2, tab: 0 },
  { mode: "layout", from: T.drag2 - 2, to: T.drop - 6, tab: 1 },
  { mode: "media", from: T.drop - 6, to: T.give - 3, tab: 0 },
  { mode: "frame", from: T.give - 3, to: T.add - 4, tab: 2 },
  { mode: "text", from: T.add - 4, to: T.carousel - 6, tab: 3 },
  { mode: "slides", from: T.carousel - 6, to: T.post - 5, tab: 1 },
  { mode: "format", from: T.post - 5, to: 99999, tab: 2 },
];

const TABS = [
  { n: "Media", i: "▣" },
  { n: "Layout", i: "▦" },
  { n: "Style", i: "◐" },
  { n: "Text", i: "Aa" },
  { n: "Video", i: "▶" },
];

// ---- the screen ----

export const EditorScreen: React.FC = () => {
  const f = useCurrentFrame();
  const g = geom(f);
  const sched = schedule();
  const cur = sched.find((s) => f >= s.from && f < s.to) ?? sched[0];
  const tabX = steps(
    f,
    sched[0].tab,
    sched.slice(1).map((s) => [s.from, s.tab] as [number, number]),
    8,
  );

  // collage view vs carousel view
  const carouselOn = win(f, T.carousel - 4, T.post - 6, 8);
  const collageOn = 1 - carouselOn;

  // swap
  const ts = ip(f, T.swap + 4, T.swap + 16, 0, 1, SOFT);
  const itemRect = (i: number) => (i === 0 ? mix(g.cells[0], g.cells[3], ts) : i === 3 ? mix(g.cells[3], g.cells[0], ts) : g.cells[i]);
  const lifting = f >= T.hold + 2 && f < T.swap + 6;
  const liftP = ip(f, T.hold, T.hold + 10);
  const ghostT = ip(f, T.drag3 - 6, T.swap + 2, 0, 1, SOFT);
  const ghostFrom = center(g.cells[0]);
  const ghostTo = center(g.cells[3]);
  const ghost = { x: ghostFrom.x + (ghostTo.x - ghostFrom.x) * ghostT, y: ghostFrom.y + (ghostTo.y - ghostFrom.y) * ghostT };

  // photo on top
  const land = LAND_OVERLAY();
  const dragT = ip(f, T.drop, land, 0, 1, SOFT);
  const landed = f >= land;
  const landScale = interpolate(f, [land, land + 12], [1.14, 1], { ...clamp, easing: POP });
  const st = frameStyle(f);
  const frameChange = st === "instant" ? T.white - 2 : st === "torn" ? T.torn - 2 : -999;
  const framePop = 1 + 0.1 * (1 - ip(f, frameChange, frameChange + 10, 0, 1, POP)) * (frameChange > 0 ? 1 : 0);
  const angle = angleAt(f);
  const locked = f >= T.click;
  const clickPulse = 1 + 0.06 * Math.max(0, 1 - (f - T.click) / 8) * (locked ? 1 : 0);
  const twistOn = win(f, T.twist - 8, T.add - 8, 6);

  // caption
  const capOn = f >= T.add;
  const fi = fontIdx(f);
  const fs = FONT_STYLES[fi];
  const lastChange = fontChanges()[fi];
  const fontPop = 1 + 0.14 * (1 - ip(f, lastChange, lastChange + 8, 0, 1, POP));
  const text = "best trip ever";
  const typed = Math.ceil(ip(f, T.add + 2, T.add + 16, 0, 1, Easing.linear) * text.length);
  const capScale = g.cw / 352;

  // carousel
  const slideW = 270;
  const slideH = slideW * 1.25;
  const offset = steps(f, 0, [[T.carousel + 6, 0.3], [T.flows - 6, 0.8], [T.keep, 1.6]], 16, SOFT);
  const glow = win(f, T.flows, T.slides + 12, 6);

  // export
  const sheet = ip(f, T.exp, T.exp + 12);
  const prog = ip(f, T.crisp - 6, T.hd + 2, 0, 1, Easing.inOut(Easing.quad));
  const saved = f >= T.hd + 3;
  const savedPop = ip(f, T.hd + 3, T.hd + 15, 0, 1, POP);

  // touches
  const touches: { x: number; y: number; o: number; down: boolean }[] = [];
  const push = (t: { x: number; y: number; o: number; down: boolean } | null) => t && touches.push(t);
  push(tapAt(f, T.pick + 2, tileCenter(2).x, tileCenter(2).y));
  push(tapAt(f, T.pick + 15, tileCenter(0).x, tileCenter(0).y));
  for (let i = 0; i < 4; i++) {
    const s = flyIn(i);
    if (f >= s - 2 && f <= s + 10) {
      const t = ip(f, s, s + 9, 0, 1, SOFT);
      const a = thumbAt(i);
      const b = center(g.cells[i]);
      touches.push({ x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t, o: win(f, s - 2, s + 8, 2), down: true });
    }
  }
  if (f >= T.drag2 && f <= T.drag2 + 26) {
    touches.push({ x: g.cx + G / 2 + g.sx * (g.cw - G), y: g.cy + g.sy * g.ch * 0.5, o: win(f, T.drag2, T.drag2 + 24, 4), down: f >= T.drag2 + 5 });
  }
  if (f >= T.drag2 + 24 && f <= T.drag2 + 48) {
    touches.push({ x: g.cx + g.sx * g.cw + (1 - g.sx) * g.cw * 0.5, y: g.cy + G / 2 + g.sy * (g.ch - G), o: win(f, T.drag2 + 24, T.drag2 + 46, 4), down: f >= T.drag2 + 27 });
  }
  if (f >= T.hold - 6 && f <= T.swap + 6) {
    touches.push({ x: ghost.x, y: ghost.y, o: win(f, T.hold - 6, T.swap + 2, 4), down: f >= T.hold - 1 });
  }
  const ovFrom = thumbAt(4);
  const ovPos = { x: ovFrom.x + (g.ocx - ovFrom.x) * dragT, y: ovFrom.y + (g.ocy - ovFrom.y) * dragT };
  if (f >= T.drop - 4 && f <= land + 4) touches.push({ ...ovPos, o: win(f, T.drop - 4, land, 4), down: f >= T.drop - 1 && f < land });
  push(tapAt(f, T.white - 2, frameChip(2).x, frameChip(2).y));
  push(tapAt(f, T.torn - 2, frameChip(3).x, frameChip(3).y));
  if (f >= T.twist - 8 && f <= T.click + 10) {
    const a = ((angle + 40) * Math.PI) / 180;
    const r = g.ow * 0.42;
    const o = win(f, T.twist - 8, T.click + 4, 4);
    touches.push({ x: g.ocx + Math.cos(a) * r, y: g.ocy + Math.sin(a) * r, o, down: true });
    touches.push({ x: g.ocx - Math.cos(a) * r, y: g.ocy - Math.sin(a) * r, o, down: true });
  }
  fontChanges()
    .slice(1)
    .forEach((at, i) => push(tapAt(f, at, fontChip(i + 1).x, fontChip(i + 1).y)));
  push(tapAt(f, T.carousel - 5, 244, 71));
  if (f >= T.keep - 6 && f <= T.keep + 16) {
    const t = ip(f, T.keep - 2, T.keep + 14, 0, 1, SOFT);
    touches.push({ x: 320 - t * 220, y: 380, o: win(f, T.keep - 6, T.keep + 12, 4), down: true });
  }
  push(tapAt(f, T.story - 3, formatChip(1).x, formatChip(1).y));
  push(tapAt(f, T.instagram - 1, formatChip(2).x, formatChip(2).y));
  push(tapAt(f, T.tiktok - 3, formatChip(1).x, formatChip(1).y));
  push(tapAt(f, T.exp - 14, formatChip(0).x, formatChip(0).y));
  push(tapAt(f, T.exp - 2, 330, 71));

  const toggleX = steps(f, 0, [[T.carousel - 4, 1], [T.post - 6, 0]], 10);

  return (
    <div style={{ position: "absolute", left: 0, top: 0, width: SW, height: SH, overflow: "hidden", fontFamily, color: "#fff", background: "linear-gradient(165deg,#3a1d70 0%,#1b1038 42%,#170c2c 60%,#4a1645 100%)" }}>
      {/* status bar */}
      <Label x={40} y={18} size={15} color="#fff" weight={700}>9:41</Label>
      <div style={{ position: "absolute", left: 145, top: 11, width: 110, height: 32, borderRadius: 16, background: "#000" }} />
      <div style={{ position: "absolute", right: 34, top: 21, display: "flex", gap: 6, alignItems: "center" }}>
        <div style={{ display: "flex", gap: 2, alignItems: "flex-end" }}>
          {[5, 7, 9, 11].map((h) => (
            <div key={h} style={{ width: 3, height: h, background: "#fff", borderRadius: 1 }} />
          ))}
        </div>
        <div style={{ width: 24, height: 12, borderRadius: 3, border: "1.5px solid #fff", padding: 1.5, boxSizing: "border-box" }}>
          <div style={{ width: "100%", height: "100%", background: "#34C759", borderRadius: 1 }} />
        </div>
      </div>

      {/* top bar */}
      <Glass style={{ left: 14, top: 52, width: 82, height: 38, borderRadius: 19, display: "flex", alignItems: "center", justifyContent: "space-around", fontSize: 17 }}>
        <span>▣</span>
        <span style={{ fontSize: 22, fontWeight: 400 }}>+</span>
      </Glass>
      <Glass style={{ left: 135, top: 52, width: 130, height: 38, borderRadius: 19 }}>
        <div style={{ position: "absolute", top: 4, left: 4 + toggleX * 88, width: toggleX > 0.5 ? 34 : 84, height: 28, borderRadius: 14, background: C.purple }} />
        <div style={{ position: "absolute", left: 4, top: 4, width: 84, height: 28, display: "flex", alignItems: "center", justifyContent: "center", fontSize: 13, fontWeight: 700 }}>▦ Collage</div>
        <div style={{ position: "absolute", left: 92, top: 4, width: 34, height: 28, display: "flex", alignItems: "center", justifyContent: "center", fontSize: 14 }}>▭▭</div>
      </Glass>
      <Glass style={{ left: 280, top: 52, width: 106, height: 38, borderRadius: 19 }}>
        <span style={{ position: "absolute", left: 10, top: 8, fontSize: 16 }}>⤢</span>
        <div
          style={{
            position: "absolute",
            left: 33,
            top: 2,
            width: 34,
            height: 34,
            borderRadius: 17,
            background: C.purple,
            display: "flex",
            alignItems: "center",
            justifyContent: "center",
            fontSize: 16,
            boxShadow: f >= T.exp - 4 && f < T.exp + 14 ? `0 0 0 ${6 * (1 - ip(f, T.exp - 2, T.exp + 12))}px rgba(143,107,255,0.6)` : undefined,
          }}
        >
          ⇪
        </div>
        <span style={{ position: "absolute", left: 78, top: 6, fontSize: 18, letterSpacing: 1 }}>•••</span>
      </Glass>

      {/* collage view */}
      <div style={{ position: "absolute", inset: 0, opacity: collageOn }}>
        <div style={{ position: "absolute", left: g.cx, top: g.cy, width: g.cw, height: g.ch, background: "#120d22", borderRadius: 4, boxShadow: "0 18px 40px rgba(0,0,0,0.45)" }} />
        {g.cells.map((r, i) =>
          f < flyIn(i) + 9 ? (
            <div key={`e${i}`} style={{ position: "absolute", left: r.x, top: r.y, width: r.w, height: r.h, borderRadius: 4, background: "rgba(255,255,255,0.06)", border: "1.5px dashed rgba(255,255,255,0.3)", boxSizing: "border-box", display: "flex", alignItems: "center", justifyContent: "center" }}>
              <div style={{ width: 34, height: 34, borderRadius: 17, background: "rgba(255,255,255,0.12)", display: "flex", alignItems: "center", justifyContent: "center", fontSize: 22, color: "rgba(255,255,255,0.85)" }}>+</div>
            </div>
          ) : null,
        )}
        {PHOTOS.map((k, i) => {
          if (f < flyIn(i) + 9) return null;
          const r = itemRect(i);
          const pop = interpolate(f, [flyIn(i) + 9, flyIn(i) + 17], [1.06, 1], { ...clamp, easing: POP });
          const moving = ts > 0 && ts < 1 && (i === 0 || i === 3);
          return (
            <div key={k} style={{ position: "absolute", left: r.x, top: r.y, width: r.w, height: r.h, scale: String(pop * (moving ? 1 + Math.sin(ts * Math.PI) * 0.08 : 1)), zIndex: moving ? 2 : 1 }}>
              <TripPhoto kind={k} style={{ width: "100%", height: "100%", borderRadius: 4, boxShadow: moving ? "0 12px 26px rgba(0,0,0,0.5)" : undefined }} />
              {i === 0 && lifting && ts === 0 ? <div style={{ position: "absolute", inset: 0, borderRadius: 4, background: `rgba(0,0,0,${0.55 * liftP})` }} /> : null}
            </div>
          );
        })}
        {/* long-press ring, swap target */}
        {f >= T.hold - 2 && f < T.hold + 14 ? (
          <div style={{ position: "absolute", left: ghostFrom.x - 30, top: ghostFrom.y - 30, width: 60, height: 60, borderRadius: 30, border: `3px solid ${C.pink}`, opacity: 1 - ip(f, T.hold + 4, T.hold + 14), scale: String(0.6 + ip(f, T.hold - 2, T.hold + 12) * 1.2) }} />
        ) : null}
        {f >= T.drag3 && f < T.swap + 6 ? (
          <div style={{ position: "absolute", left: g.cells[3].x - 1, top: g.cells[3].y - 1, width: g.cells[3].w + 2, height: g.cells[3].h + 2, borderRadius: 5, border: `3px solid ${C.pink}`, boxShadow: `0 0 16px rgba(224,69,123,0.7)`, opacity: ip(f, T.swap - 8, T.swap - 2) }} />
        ) : null}
        {/* border grips while resizing */}
        {f >= T.drag2 - 4 && f < T.hold - 2 ? <Dividers f={f} g={g} /> : null}
        {/* drop target */}
        {f >= T.drop + 8 && f < land + 6 ? (
          <>
            <div style={{ position: "absolute", left: g.cx - 2, top: g.cy - 2, width: g.cw + 4, height: g.ch + 4, borderRadius: 6, border: `3px solid ${C.purple}`, boxShadow: `0 0 22px rgba(143,107,255,0.7)`, opacity: win(f, T.drop + 8, land, 4), boxSizing: "border-box" }} />
            <div style={{ position: "absolute", left: 200 - 92, top: g.cy + g.ch - 52, width: 184, height: 32, borderRadius: 16, background: "rgba(109,79,214,0.85)", fontSize: 13, fontWeight: 700, display: "flex", alignItems: "center", justifyContent: "center", opacity: win(f, T.drop + 8, land, 4) }}>
              ⧉ Drop to place on top
            </div>
          </>
        ) : null}
        {/* photo on top */}
        {landed ? (
          <div
            style={{
              position: "absolute",
              left: g.ocx,
              top: g.ocy,
              width: 0,
              height: 0,
              rotate: `${angle}deg`,
              scale: String(landScale * framePop * clickPulse),
              zIndex: 3,
            }}
          >
            <div style={{ position: "absolute", translate: "-50% -50%" }}>
              <FramedPhoto kind={TOP_PHOTO} w={g.ow} h={g.oh} frame={st} />
            </div>
            {f >= land && f < T.add - 4 ? (
              <div style={{ position: "absolute", left: -(g.ow / 2) - 18, top: -(g.oh / 2) - 18, width: g.ow + 36, height: g.oh + 36 + (st === "instant" ? 20 : 0), borderRadius: 6, border: "1.5px dashed rgba(255,255,255,0.85)", boxSizing: "border-box", opacity: ip(f, land + 4, land + 10) * (1 - ip(f, T.add - 10, T.add - 4)) }} />
            ) : null}
          </div>
        ) : null}
        {/* straight guides and the angle */}
        {twistOn > 0 ? <TwistGuides f={f} g={g} angle={angle} locked={locked} o={twistOn} /> : null}
        {/* caption */}
        {capOn ? (
          <div style={{ position: "absolute", left: g.capX, top: g.capY, width: 0, height: 0, zIndex: 4 }}>
            <div
              style={{
                position: "absolute",
                translate: "-50% -50%",
                whiteSpace: "nowrap",
                fontFamily: fs.ff,
                fontWeight: fs.weight,
                fontSize: fs.size * capScale,
                textTransform: fs.upper ? "uppercase" : undefined,
                letterSpacing: fs.upper ? 1 : 0,
                color: "#fff",
                textShadow: "0 2px 10px rgba(0,0,0,0.55)",
                scale: String(fontPop),
                padding: "2px 12px",
                outline: f < T.carousel - 6 ? "1.5px dashed rgba(255,255,255,0.8)" : undefined,
                outlineOffset: 4,
                borderRadius: 6,
              }}
            >
              {text.slice(0, typed)}
              {typed < text.length && Math.floor(f / 4) % 2 === 0 ? "|" : ""}
              {f >= T.font ? (
                <div style={{ position: "absolute", left: 0, right: 0, top: "100%", textAlign: "center", fontFamily, fontSize: 15 * capScale, color: C.gold, scale: String(ip(f, T.font, T.font + 12, 0, 1, POP)), marginTop: -4 }}>
                  ✦ ♡ ✦
                </div>
              ) : null}
            </div>
          </div>
        ) : null}
      </div>

      {/* carousel view */}
      {carouselOn > 0 ? (
        <div style={{ position: "absolute", left: BOX.x, top: 372 - slideH / 2, width: BOX.w, height: slideH, overflow: "hidden", opacity: carouselOn, borderRadius: 4 }}>
          <div style={{ position: "absolute", left: -offset * slideW, top: 0 }}>
            <StripContent slideW={slideW} slideH={slideH} gap={G} glow={glow} />
            {[1, 2].map((k) => (
              <div key={k} style={{ position: "absolute", left: k * slideW - 1, top: 0, width: 0, height: slideH, borderLeft: "2px dashed rgba(255,255,255,0.7)" }} />
            ))}
            {[0, 1, 2].map((k) => (
              <div key={k} style={{ position: "absolute", left: k * slideW + 8, top: 8, padding: "2px 9px", borderRadius: 12, fontSize: 12, fontWeight: 800, background: "rgba(255,255,255,0.22)" }}>
                {k + 1}
              </div>
            ))}
          </div>
        </div>
      ) : null}

      {/* flying photos: tray -> cells */}
      {PHOTOS.map((k, i) => {
        const s = flyIn(i);
        if (f < s || f >= s + 9) return null;
        const t = ip(f, s, s + 9, 0, 1, SOFT);
        const a = thumbAt(i);
        const r = mix({ x: a.x - 27, y: a.y - 27, w: 54, h: 54 }, g.cells[i], t);
        return (
          <TripPhoto key={k} kind={k} style={{ position: "absolute", left: r.x, top: r.y, width: r.w, height: r.h, borderRadius: 6, boxShadow: "0 14px 30px rgba(0,0,0,0.55)", scale: String(1 + Math.sin(t * Math.PI) * 0.12), zIndex: 5 }} />
        );
      })}
      {/* the lifted picture following the finger */}
      {lifting && ts === 0 && f >= T.hold + 4 ? (
        <TripPhoto kind={PHOTOS[0]} style={{ position: "absolute", left: ghost.x - 46, top: ghost.y - 34, width: 92, height: 68, borderRadius: 10, border: "2.5px solid #fff", boxShadow: "0 14px 30px rgba(0,0,0,0.55)", opacity: 0.95 * ip(f, T.hold + 4, T.hold + 10), scale: String(0.7 + 0.3 * ip(f, T.hold + 4, T.hold + 12, 0, 1, POP)), zIndex: 6 }} />
      ) : null}
      {/* the photo dragged from the tray onto the design */}
      {f >= T.drop && f < land ? (
        <div style={{ position: "absolute", left: ovPos.x, top: ovPos.y, width: 0, height: 0, zIndex: 6, rotate: `${-8 * dragT}deg` }}>
          <TripPhoto
            kind={TOP_PHOTO}
            style={{
              position: "absolute",
              left: -(54 + (g.ow - 54) * dragT) / 2,
              top: -(54 + (g.oh - 54) * dragT) / 2,
              width: 54 + (g.ow - 54) * dragT,
              height: 54 + (g.oh - 54) * dragT,
              borderRadius: 6,
              boxShadow: "0 20px 40px rgba(0,0,0,0.6)",
              opacity: 0.96,
            }}
          />
        </div>
      ) : null}

      {/* bottom panel */}
      <Glass style={{ left: 12, top: 648, width: 376, height: 150, borderRadius: 26, background: "rgba(24,16,48,0.62)" }} />
      {sched.map((s, i) => {
        const o = win(f, s.from, s.to, 6);
        if (o <= 0) return null;
        return (
          <div key={i} style={{ position: "absolute", inset: 0, opacity: o, translate: `0px ${(1 - o) * 10}px` }}>
            {s.mode === "layout" ? <LayoutPanel f={f} /> : s.mode === "media" ? <MediaPanel f={f} /> : s.mode === "frame" ? <FramePanel f={f} /> : s.mode === "text" ? <TextPanel f={f} /> : s.mode === "slides" ? <SlidesPanel /> : <FormatPanel g={g} />}
          </div>
        );
      })}
      <div style={{ display: "none" }}>{cur.mode}</div>

      {/* tab bar */}
      <Glass style={{ left: 12, top: 806, width: 376, height: 54, borderRadius: 27, background: "rgba(24,16,48,0.62)" }}>
        <div style={{ position: "absolute", left: 4 + tabX * 73.6, top: 4, width: 72, height: 44, borderRadius: 22, background: C.purple }} />
        {TABS.map((t, i) => (
          <div key={t.n} style={{ position: "absolute", left: 4 + i * 73.6, top: 6, width: 72, textAlign: "center", fontSize: 10.5, fontWeight: 700, lineHeight: 1.25 }}>
            <div style={{ fontSize: 15 }}>{t.i}</div>
            {t.n}
          </div>
        ))}
      </Glass>

      {/* export sheet */}
      {sheet > 0 ? (
        <>
          <div style={{ position: "absolute", inset: 0, background: `rgba(0,0,0,${0.35 * sheet})` }} />
          <div style={{ position: "absolute", left: 8, right: 8, top: 560 + (1 - sheet) * 330, height: 320, borderRadius: 30, background: "rgba(36,26,66,0.97)", border: "1px solid rgba(255,255,255,0.15)", padding: "16px 22px", boxSizing: "border-box" }}>
            <div style={{ width: 40, height: 5, borderRadius: 3, background: "rgba(255,255,255,0.3)", margin: "0 auto 14px" }} />
            <div style={{ fontSize: 22, fontWeight: 800 }}>Export</div>
            <div style={{ display: "flex", gap: 8, marginTop: 14 }}>
              {["Standard", "HD"].map((q) => (
                <div key={q} style={{ flex: 1, height: 40, borderRadius: 12, display: "flex", alignItems: "center", justifyContent: "center", fontSize: 15, fontWeight: 800, background: q === "HD" ? C.purple : "rgba(255,255,255,0.08)", boxShadow: q === "HD" && f >= T.crisp ? `0 0 ${14 * win(f, T.crisp, T.hd + 4, 4)}px rgba(143,107,255,0.9)` : undefined }}>
                  {q === "HD" ? "✦ HD" : q}
                </div>
              ))}
            </div>
            <div style={{ marginTop: 22, height: 10, borderRadius: 5, background: "rgba(255,255,255,0.12)", overflow: "hidden" }}>
              <div style={{ width: `${prog * 100}%`, height: "100%", borderRadius: 5, background: `linear-gradient(90deg, ${C.purple}, ${C.pink})` }} />
            </div>
            <div style={{ marginTop: 12, fontSize: 14, fontWeight: 700, color: saved ? "#5BE38A" : "rgba(255,255,255,0.8)" }}>
              {saved ? "✓ Saved to Photos" : `Saving in HD… ${Math.round(prog * 100)}%`}
            </div>
            {saved ? (
              <div style={{ position: "absolute", right: 26, top: 70, width: 64, height: 64, borderRadius: 32, background: "#34C759", display: "flex", alignItems: "center", justifyContent: "center", fontSize: 36, fontWeight: 800, scale: String(savedPop) }}>✓</div>
            ) : null}
          </div>
        </>
      ) : null}

      {touches.map((t, i) => (
        <Touch key={i} {...t} />
      ))}
    </div>
  );
};

const Dividers: React.FC<{ f: number; g: Geom }> = ({ f, g }) => {
  const vx = g.cx + G / 2 + g.sx * (g.cw - G);
  const hy = g.cy + G / 2 + g.sy * (g.ch - G);
  const vActive = f >= T.drag2 + 4 && f < T.drag2 + 26;
  const hActive = f >= T.drag2 + 26 && f < T.drag2 + 48;
  const o = win(f, T.drag2 - 4, T.hold - 8, 5);
  const grip = (active: boolean, vertical: boolean, x: number, y: number) => (
    <div style={{ position: "absolute", left: x - (vertical ? 3.5 : 16), top: y - (vertical ? 16 : 3.5), width: vertical ? 7 : 32, height: vertical ? 32 : 7, borderRadius: 4, background: active ? C.purple : "#fff", boxShadow: "0 2px 6px rgba(0,0,0,0.5)" }} />
  );
  return (
    <div style={{ position: "absolute", inset: 0, opacity: o }}>
      {vActive ? <div style={{ position: "absolute", left: vx - 2, top: g.cy + G, width: 4, height: g.ch - 2 * G, background: C.purple, borderRadius: 2, boxShadow: `0 0 10px ${C.purple}` }} /> : null}
      {hActive ? <div style={{ position: "absolute", left: g.cx + G, top: hy - 2, width: g.cw - 2 * G, height: 4, background: C.purple, borderRadius: 2, boxShadow: `0 0 10px ${C.purple}` }} /> : null}
      {grip(vActive, true, vx, g.cy + g.sy * g.ch * 0.5)}
      {grip(vActive, true, vx, hy + (g.ch - (hy - g.cy)) * 0.5)}
      {grip(hActive, false, g.cx + g.sx * g.cw * 0.5, hy)}
      {grip(hActive, false, g.cx + g.sx * g.cw + (1 - g.sx) * g.cw * 0.5, hy)}
    </div>
  );
};

const TwistGuides: React.FC<{ f: number; g: Geom; angle: number; locked: boolean; o: number }> = ({ f, g, angle, locked, o }) => {
  const shown = ((Math.round(angle) % 360) + 360) % 360;
  const ripple = ip(f, T.click, T.click + 16);
  return (
    <div style={{ position: "absolute", inset: 0, opacity: o, zIndex: 5 }}>
      {locked ? (
        <div style={{ position: "absolute", left: g.cx, top: g.cy, width: g.cw, height: g.ch, overflow: "hidden" }}>
          <div style={{ position: "absolute", left: 0, top: g.ocy - g.cy, width: g.cw * ip(f, T.click, T.click + 6), height: 0, borderTop: "2px dashed #FFD60A" }} />
          <div style={{ position: "absolute", left: g.ocx - g.cx, top: 0, width: 0, height: g.ch * ip(f, T.click, T.click + 6), borderLeft: "2px dashed #FFD60A" }} />
        </div>
      ) : null}
      {locked && ripple < 1 ? (
        <div style={{ position: "absolute", left: g.ocx - g.ow, top: g.ocy - g.ow, width: g.ow * 2, height: g.ow * 2, borderRadius: "50%", border: "4px solid #FFD60A", scale: String(0.4 + ripple * 0.9), opacity: 1 - ripple }} />
      ) : null}
      <div
        style={{
          position: "absolute",
          left: g.ocx - 40,
          top: g.ocy - g.oh / 2 - 58,
          width: 80,
          height: 30,
          borderRadius: 15,
          background: locked ? "#FFD60A" : "rgba(0,0,0,0.6)",
          color: locked ? "#1E1438" : "#fff",
          fontSize: 15,
          fontWeight: 800,
          display: "flex",
          alignItems: "center",
          justifyContent: "center",
          gap: 4,
          scale: String(locked ? 1 + 0.25 * Math.max(0, 1 - (f - T.click) / 8) : 1),
        }}
      >
        {locked ? "🔒 " : ""}
        {shown}°
      </div>
    </div>
  );
};

/** The phone frame around the live editor. */
export const EditorPhone: React.FC<{ width: number }> = ({ width }) => {
  const bezel = width * 0.035;
  const sw = width - bezel * 2;
  const k = sw / SW;
  const h = SH * k + bezel * 2;
  return (
    <div
      style={{
        position: "relative",
        width,
        height: h,
        borderRadius: width * 0.16,
        background: "linear-gradient(145deg,#3a3446,#121016 45%,#2a2533)",
        padding: bezel,
        boxSizing: "border-box",
        boxShadow: `0 ${width * 0.08}px ${width * 0.2}px rgba(43,20,92,0.38), inset 0 0 0 ${width * 0.006}px rgba(255,255,255,0.18)`,
      }}
    >
      <div style={{ position: "relative", width: sw, height: SH * k, borderRadius: width * 0.125, overflow: "hidden" }}>
        <div style={{ position: "absolute", left: 0, top: 0, width: SW, height: SH, scale: String(k), transformOrigin: "0 0" }}>
          <EditorScreen />
        </div>
      </div>
    </div>
  );
};

export const editorPhoneHeight = (width: number) => {
  const bezel = width * 0.035;
  return ((width - bezel * 2) / SW) * SH + bezel * 2;
};
