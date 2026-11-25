import React from "react";
import { Easing } from "remotion";
import type { PhotoKind } from "../ad/TripPhoto";
import { AIR, SOFT } from "../ad/theme";
import { ip, POP } from "../ad5/kit";
import { Clip, Still } from "./kit";

/**
 * A motion design, played the way the app plays one (ios/.../Model/Motion.swift): a list of scenes, each with its
 * layout, transition, camera move and entrance. A picture that is in two scenes in a row glides and resizes from its old
 * place to its new one; pictures new to a scene come in with the scene's transition (or one after another with its
 * entrance), and pictures leaving go out with it.
 */
export type Pic = { k: PhotoKind; v?: boolean };
export type Rect = [number, number, number, number];
export type Slot = { p: number; r: Rect; rot?: number };
export type Tr = "cut" | "fade" | "slideLeft" | "slideUp" | "zoom";
export type Move = "none" | "zoomIn" | "zoomOut" | "drift";
export type Ent = "none" | "pop" | "drop" | "rise";
export type Scene = { at: number; slots: Slot[]; tr?: Tr; move?: Move; ent?: Ent; print?: boolean };
export type Design = { pics: Pic[]; scenes: Scene[]; bg: string; gap?: number; radius?: number };

const TR = 10;
const GLIDE = 15;

const lerp = (a: number, b: number, t: number) => a + (b - a) * t;

type Look = { r: Rect; rot: number; a: number; s: number; dx: number; dy: number; zoom: number; pan: number; print: number; z: number };

const lookAt = (d: Design, p: number, f: number): Look | null => {
  const sc = d.scenes;
  let i = -1;
  for (let k = 0; k < sc.length; k++) if (f >= sc[k].at) i = k;
  if (i < 0) return null;
  const S = sc[i];
  const cur = S.slots.find((s) => s.p === p);
  const prevS = i > 0 ? sc[i - 1] : null;
  const prev = prevS?.slots.find((s) => s.p === p);
  const e = i === 0 ? 1 : ip(f, S.at, S.at + TR, 0, 1, AIR);
  const len = (sc[i + 1]?.at ?? S.at + 150) - S.at;
  const q = Math.min(1.3, (f - S.at) / len);
  const move = (m: Move | undefined, qq: number) =>
    m === "zoomIn" ? { zoom: 1 + 0.16 * qq, pan: 0 } : m === "zoomOut" ? { zoom: 1.16 - 0.16 * Math.min(1, qq), pan: 0 } : m === "drift" ? { zoom: 1.14, pan: -0.8 + 1.6 * Math.min(1, qq) } : { zoom: 1, pan: 0 };
  const printOf = (s: Scene | null) => (s?.print ? 1 : 0);

  if (cur) {
    const mv = move(S.move, q);
    if (prev) {
      const g = ip(f, S.at, S.at + GLIDE, 0, 1, SOFT);
      const r = prev.r.map((v, j) => lerp(v, cur.r[j], g)) as Rect;
      return { r, rot: lerp(prev.rot ?? 0, cur.rot ?? 0, g), a: 1, s: 1, dx: 0, dy: 0, ...mv, print: lerp(printOf(prevS), printOf(S), g), z: 2 };
    }
    const base: Look = { r: cur.r, rot: cur.rot ?? 0, a: 1, s: 1, dx: 0, dy: 0, ...mv, print: printOf(S), z: 3 };
    const ent = S.ent ?? "none";
    if (ent !== "none") {
      const fresh = S.slots.filter((s) => !prevS?.slots.some((x) => x.p === s.p));
      const order = Math.max(0, fresh.findIndex((s) => s.p === p));
      const st = S.at + order * 5;
      const t = ip(f, st, st + 13, 0, 1, Easing.linear);
      const a = Math.min(1, t * 2.2);
      if (ent === "pop") return { ...base, a, s: 0.55 + 0.45 * POP(t) };
      if (ent === "drop") return { ...base, a, dy: -(1 - AIR(t)) * 0.35, rot: base.rot + (1 - t) * 8 };
      return { ...base, a, dy: (1 - AIR(t)) * 0.25 };
    }
    const tr = S.tr ?? "fade";
    if (i === 0 || tr === "cut") return base;
    if (tr === "fade") return { ...base, a: e };
    if (tr === "slideLeft") return { ...base, dx: 1 - e };
    if (tr === "slideUp") return { ...base, dy: 1 - e };
    return { ...base, a: e, s: 0.8 + 0.2 * e };
  }
  if (prev && prevS && f < S.at + TR) {
    const tr = S.tr ?? "fade";
    const mv = move(prevS.move, (f - prevS.at) / (S.at - prevS.at));
    const base: Look = { r: prev.r, rot: prev.rot ?? 0, a: 1, s: 1, dx: 0, dy: 0, ...mv, print: printOf(prevS), z: 1 };
    if (tr === "cut") return null;
    if (tr === "fade") return { ...base, a: 1 - e };
    if (tr === "slideLeft") return { ...base, dx: -e };
    if (tr === "slideUp") return { ...base, dy: -e };
    return { ...base, a: 1 - e, s: 1 + 0.35 * e };
  }
  return null;
};

/** Plays a motion design at frame `f` (frames since the design started), `w` x `h` pixels. */
export const MotionStage: React.FC<{ d: Design; f: number; w: number; h: number; ring?: (p: number) => number; empty?: boolean }> = ({ d, f, w, h, ring, empty }) => {
  const g = (d.gap ?? 4) * (w / 360);
  const rad = (d.radius ?? 6) * (w / 360);
  const u = w / 360;
  const looks = d.pics.map((_, p) => ({ p, l: lookAt(d, p, f) })).filter((x) => x.l) as { p: number; l: Look }[];
  looks.sort((a, b) => a.l.z - b.l.z);
  return (
    <div style={{ position: "relative", width: w, height: h, background: d.bg, overflow: "hidden", borderRadius: rad * 1.4 }}>
      {empty && looks.length === 0
        ? d.scenes[d.scenes.length - 1].slots.map((s, i) => (
            <div
              key={i}
              style={{
                position: "absolute",
                left: g + s.r[0] * (w - g),
                top: g + s.r[1] * (h - g),
                width: s.r[2] * (w - g) - g,
                height: s.r[3] * (h - g) - g,
                borderRadius: rad,
                border: `${1.5 * u}px dashed rgba(255,255,255,0.3)`,
                display: "flex",
                alignItems: "center",
                justifyContent: "center",
                color: "rgba(255,255,255,0.45)",
                fontSize: 26 * u,
              }}
            >
              +
            </div>
          ))
        : null}
      {looks.map(({ p, l }) => {
        const pic = d.pics[p];
        const pr = l.print;
        const bx = g * (1 - pr) + l.r[0] * (w - g * (1 - pr));
        const by = g * (1 - pr) + l.r[1] * (h - g * (1 - pr));
        const bw = l.r[2] * (w - g * (1 - pr)) - g * (1 - pr);
        const bh = l.r[3] * (h - g * (1 - pr)) - g * (1 - pr);
        const border = pr * Math.min(bw, bh) * 0.05;
        const rg = ring ? ring(p) : 0;
        return (
          <div
            key={p}
            style={{
              position: "absolute",
              left: bx + l.dx * w,
              top: by + l.dy * h,
              width: bw,
              height: bh,
              opacity: l.a,
              scale: String(l.s),
              rotate: `${l.rot}deg`,
              background: pr > 0.01 ? `rgba(255,253,248,${pr})` : undefined,
              padding: `${border}px ${border}px ${border * 2.6}px`,
              boxSizing: "border-box",
              borderRadius: rad * (1 - pr) + 2 * u * pr,
              boxShadow: pr > 0.01 ? `0 ${6 * u * pr}px ${16 * u * pr}px rgba(60,30,10,${0.28 * pr})` : undefined,
            }}
          >
            <div style={{ position: "relative", width: "100%", height: "100%", overflow: "hidden", borderRadius: rad * (1 - pr) + u * pr }}>
              {pic.v ? <Clip kind={pic.k} f={f} seed={p} zoom={l.zoom} u={u} /> : <Still kind={pic.k} zoom={l.zoom} pan={l.pan} />}
            </div>
            {rg > 0.01 ? (
              <div style={{ position: "absolute", inset: -3 * u, borderRadius: rad + 3 * u, border: `${3 * u}px solid #F4B23C`, boxShadow: `0 0 ${16 * u}px rgba(244,178,60,0.8)`, opacity: rg }} />
            ) : null}
          </div>
        );
      })}
    </div>
  );
};

// ------------------------------------------------------------------ the two templates in the ads

/** "Neon nights": full-screen beats that zoom, slide and pop, then everything settles into one collage. */
export const NEON: Design = {
  bg: "#0d0818",
  gap: 5,
  pics: [{ k: "aurora-reine" }, { k: "golden-wave", v: true }, { k: "santorini-sunset" }, { k: "venice-canal", v: true }, { k: "balloons" }],
  scenes: [
    { at: 0, slots: [{ p: 0, r: [0, 0, 1, 1] }], move: "zoomIn", tr: "cut" },
    { at: 46, slots: [{ p: 1, r: [0, 0, 1, 1] }], move: "zoomIn", tr: "zoom" },
    { at: 70, slots: [{ p: 2, r: [0, 0, 1, 1] }], move: "zoomIn", tr: "slideUp" },
    {
      at: 99,
      ent: "pop",
      slots: [
        { p: 1, r: [0, 0, 0.62, 0.55] },
        { p: 0, r: [0.62, 0, 0.38, 0.3] },
        { p: 4, r: [0.62, 0.3, 0.38, 0.25] },
        { p: 3, r: [0, 0.55, 0.4, 0.45] },
        { p: 2, r: [0.4, 0.55, 0.6, 0.45] },
      ],
    },
  ],
};

/** "Photo dump": prints drop in, pile up, then glide into a neat grid by themselves. */
export const DUMP: Design = {
  bg: "#F4ECDF",
  gap: 5,
  pics: [{ k: "santorini-domes" }, { k: "golden-wave", v: true }, { k: "pizza" }, { k: "turquoise", v: true }, { k: "positano" }],
  scenes: [
    { at: 0, print: true, ent: "drop", move: "zoomIn", slots: [{ p: 0, r: [0.16, 0.14, 0.68, 0.62], rot: -4 }] },
    {
      at: 28,
      print: true,
      ent: "drop",
      slots: [
        { p: 0, r: [0.04, 0.05, 0.52, 0.42], rot: -7 },
        { p: 1, r: [0.46, 0.1, 0.5, 0.42], rot: 6 },
        { p: 2, r: [0.18, 0.5, 0.56, 0.44], rot: -2 },
      ],
    },
    {
      at: 56,
      ent: "rise",
      slots: [
        { p: 1, r: [0, 0, 0.6, 0.52] },
        { p: 0, r: [0.6, 0, 0.4, 0.52] },
        { p: 2, r: [0, 0.52, 0.36, 0.48] },
        { p: 3, r: [0.36, 0.52, 0.64, 0.28] },
        { p: 4, r: [0.36, 0.8, 0.64, 0.2] },
      ],
    },
  ],
};
