import React from "react";
import { Easing, Img, staticFile } from "remotion";
import { PHOTO_KINDS, type PhotoKind } from "../ad/TripPhoto";
import { C } from "../ad/theme";
import { ip, POP, pulse } from "../ad5/kit";
import { SH, SW, StatusBar } from "./kit";
import { DUMP, NEON, MotionStage, type Design } from "./MotionStage";

/**
 * The app's screens as they appear in the Motion template ads, drawn in screen units (SW x SH): the Collage home with
 * its Motion row, the photo and video picker, the editor playing a motion design, and (Ad B) the camera roll.
 */

const theme = (light: boolean) =>
  light
    ? { bg: "#F6F3FB", card: "#FFFFFF", text: "#16121f", sub: "rgba(22,18,31,0.55)", glass: "rgba(255,255,255,0.75)", line: "rgba(22,18,31,0.08)" }
    : { bg: "#0f0b18", card: "#1d1730", text: "#ffffff", sub: "rgba(255,255,255,0.6)", glass: "rgba(255,255,255,0.1)", line: "rgba(255,255,255,0.1)" };

const Txt: React.FC<{ x: number; y: number; size?: number; color: string; weight?: number; children: React.ReactNode; style?: React.CSSProperties }> = ({ x, y, size = 12, color, weight = 700, children, style }) => (
  <div style={{ position: "absolute", left: x, top: y, fontSize: size, color, fontWeight: weight, whiteSpace: "nowrap", ...style }}>{children}</div>
);

// ------------------------------------------------------------------ home

export type Card = { name: string; d: Design };
export const CARDS: Card[] = [
  { name: "Neon nights", d: NEON },
  { name: "Photo dump", d: DUMP },
  { name: "Spotlight", d: { ...NEON, bg: "#1b1030", pics: [{ k: "positano" }, { k: "turquoise", v: true }, { k: "amalfi" }, { k: "dock", v: true }, { k: "breakfast" }] } },
  { name: "Print drop", d: { ...DUMP, pics: [{ k: "venice-rialto" }, { k: "beach-sunset", v: true }, { k: "dinner-fira" }, { k: "palm-beach", v: true }, { k: "alpine-lake" }] } },
];
const LOOP = 150;

const TRENDING: { k: PhotoKind[]; layout: [number, number, number, number][] }[] = [
  { k: ["santorini-windmills", "pizza", "overwater"], layout: [[0, 0, 1, 0.6], [0, 0.6, 0.5, 0.4], [0.5, 0.6, 0.5, 0.4]] },
  { k: ["mountain-lake", "golden-palms", "balloons-valley", "leaning-palm"], layout: [[0, 0, 0.5, 0.5], [0.5, 0, 0.5, 0.5], [0, 0.5, 0.5, 0.5], [0.5, 0.5, 0.5, 0.5]] },
];

const TABS = ["Collage", "Carousel", "Templates", "Library"];
const TAB_ICONS = ["▦", "▤", "✦", "▣"];

export const cardPos = (i: number, scroll = 0) => ({ x: 20 + i * 128 - scroll, y: 154, w: 118, h: 158 });

export const HomeScreen: React.FC<{ f: number; light?: boolean; tap?: { i: number; at: number }; scroll?: number }> = ({ f, light = false, tap, scroll = 0 }) => {
  const t = theme(light);
  return (
    <div style={{ position: "absolute", inset: 0, background: t.bg, overflow: "hidden" }}>
      <StatusBar dark={!light} />
      <Txt x={22} y={62} size={32} color={t.text} weight={800}>
        Collage
      </Txt>
      <div style={{ position: "absolute", right: 22, top: 66, width: 36, height: 36, borderRadius: 18, background: C.purple, color: "#fff", fontSize: 22, fontWeight: 700, textAlign: "center", lineHeight: "34px" }}>+</div>
      <Txt x={22} y={122} size={17} color={t.text} weight={800}>
        ✨ Motion
      </Txt>
      <div style={{ position: "absolute", left: 122, top: 123, padding: "2px 8px", borderRadius: 9, background: C.gold, color: C.ink, fontSize: 10, fontWeight: 800 }}>18 FREE</div>
      <Txt x={318} y={124} size={13} color={C.purple} weight={700}>
        See all
      </Txt>
      {CARDS.map((c, i) => {
        const p = cardPos(i, scroll);
        const press = tap && tap.i === i ? pulse(f, tap.at - 3, 12) : 0;
        const sel = tap && tap.i === i ? ip(f, tap.at, tap.at + 6) : 0;
        return (
          <div key={c.name} style={{ position: "absolute", left: p.x, top: p.y, width: p.w, scale: String(1 - 0.07 * press) }}>
            <div style={{ position: "relative", width: p.w, height: p.h, borderRadius: 16, overflow: "hidden", boxShadow: sel > 0 ? `0 0 0 ${3 * sel}px ${C.purple}, 0 0 ${18 * sel}px rgba(109,79,214,0.8)` : light ? "0 6px 16px rgba(40,20,80,0.12)" : undefined }}>
              <MotionStage d={c.d} f={(f + i * 37) % LOOP} w={p.w} h={p.h} />
              <div style={{ position: "absolute", right: 6, top: 6, width: 22, height: 22, borderRadius: 11, background: "rgba(0,0,0,0.45)", color: "#fff", fontSize: 12, textAlign: "center", lineHeight: "22px" }}>✨</div>
            </div>
            <Txt x={2} y={p.h + 7} size={12.5} color={t.text}>
              {c.name}
            </Txt>
          </div>
        );
      })}
      <Txt x={22} y={364} size={17} color={t.text} weight={800}>
        Trending
      </Txt>
      {TRENDING.map((tr, i) => (
        <div key={i} style={{ position: "absolute", left: 20 + i * 184, top: 398, width: 176, height: 220, borderRadius: 16, background: t.card, overflow: "hidden" }}>
          {tr.layout.map((r, j) => (
            <div key={j} style={{ position: "absolute", left: 4 + r[0] * 168, top: 4 + r[1] * 212, width: r[2] * 168 - 4, height: r[3] * 212 - 4, borderRadius: 8, overflow: "hidden" }}>
              <Img src={staticFile(`travel/thumb/${tr.k[j]}.jpg`)} style={{ width: "100%", height: "100%", objectFit: "cover" }} />
            </div>
          ))}
        </div>
      ))}
      <div style={{ position: "absolute", left: 20, top: 634, width: 360, height: 120, borderRadius: 16, background: t.card, opacity: 0.8 }} />
      <TabBar light={light} />
    </div>
  );
};

const TabBar: React.FC<{ light: boolean }> = ({ light }) => {
  const t = theme(light);
  return (
    <div style={{ position: "absolute", left: 18, top: SH - 92, width: SW - 36, height: 62, borderRadius: 31, background: t.glass, border: `1px solid ${t.line}`, boxShadow: "0 8px 24px rgba(0,0,0,0.18)", backdropFilter: "blur(10px)" }}>
      <div style={{ position: "absolute", left: 5, top: 5, width: 86, height: 52, borderRadius: 26, background: light ? "rgba(109,79,214,0.14)" : "rgba(255,255,255,0.14)" }} />
      {TABS.map((n, i) => (
        <div key={n} style={{ position: "absolute", left: 5 + i * 89, top: 9, width: 86, textAlign: "center", color: i === 0 ? C.purple : t.sub }}>
          <div style={{ fontSize: 17, lineHeight: "20px" }}>{TAB_ICONS[i]}</div>
          <div style={{ fontSize: 10, fontWeight: 700 }}>{n}</div>
        </div>
      ))}
    </div>
  );
};

// ------------------------------------------------------------------ picker

export type Tile = { k: PhotoKind; v?: boolean };
export const TILES: Tile[] = [
  { k: "aurora-reine" },
  { k: "golden-wave", v: true },
  { k: "santorini-sunset" },
  { k: "venice-canal", v: true },
  { k: "balloons" },
  { k: "santorini-domes" },
  { k: "pizza" },
  { k: "turquoise", v: true },
  { k: "positano" },
  { k: "amalfi" },
  { k: "dock", v: true },
  { k: "breakfast" },
  { k: "desert-road" },
  { k: "aurora-beach", v: true },
  { k: "venice-rialto" },
];
export const tilePos = (i: number) => ({ x: 12 + (i % 3) * 126, y: 168 + Math.floor(i / 3) * 126, s: 122 });
export const ADD_BTN = { x: SW / 2, y: SH - 74 };

export const PickerSheet: React.FC<{ f: number; at: number; picks: { i: number; at: number }[]; addAt: number; light?: boolean }> = ({ f, at, picks, addAt, light = false }) => {
  const t = theme(light);
  const up = ip(f, at, at + 12);
  const n = picks.filter((p) => f >= p.at).length;
  const vids = picks.filter((p) => f >= p.at && TILES[p.i].v).length;
  return (
    <div style={{ position: "absolute", left: 0, right: 0, top: 58 + (SH - 58) * (1 - up), height: SH - 58, borderRadius: "26px 26px 0 0", background: light ? "#fff" : "#1a1426", boxShadow: "0 -10px 30px rgba(0,0,0,0.35)", overflow: "hidden" }}>
      <div style={{ position: "absolute", left: SW / 2 - 20, top: 8, width: 40, height: 5, borderRadius: 3, background: t.line }} />
      <Txt x={20} y={26} size={14} color={C.purple} weight={600}>
        Cancel
      </Txt>
      <Txt x={0} y={24} size={16} color={t.text} weight={800} style={{ width: SW, textAlign: "center" }}>
        Recents
      </Txt>
      <div style={{ position: "absolute", left: 20, top: 62, width: 360, height: 34, borderRadius: 17, background: light ? "rgba(22,18,31,0.06)" : "rgba(255,255,255,0.08)", display: "flex" }}>
        {["All", "Photos", "Videos"].map((x, i) => (
          <div key={x} style={{ flex: 1, textAlign: "center", paddingTop: 8, fontSize: 12.5, fontWeight: 800, color: i === 0 ? "#fff" : t.sub, background: i === 0 ? C.purple : undefined, borderRadius: 17 }}>
            {x}
          </div>
        ))}
      </div>
      <Txt x={20} y={108} size={11.5} color={t.sub} weight={700}>
        {n} selected{vids ? ` · ${n - vids} photos + ${vids} videos` : ""}
      </Txt>
      {TILES.map((tile, i) => {
        const p = tilePos(i);
        const pk = picks.findIndex((x) => x.i === i);
        const on = pk >= 0 ? ip(f, picks[pk].at, picks[pk].at + 8, 0, 1, POP) : 0;
        return (
          <div key={i} style={{ position: "absolute", left: p.x, top: p.y - 58, width: p.s, height: p.s, borderRadius: 6, overflow: "hidden", scale: String(1 - 0.06 * (pk >= 0 ? pulse(f, picks[pk].at - 3, 10) : 0)) }}>
            <Img src={staticFile(`travel/thumb/${tile.k}.jpg`)} style={{ width: "100%", height: "100%", objectFit: "cover" }} />
            {tile.v ? (
              <div style={{ position: "absolute", left: 6, bottom: 6, padding: "2px 6px", borderRadius: 6, background: "rgba(0,0,0,0.6)", color: "#fff", fontSize: 10, fontWeight: 800 }}>▶ 0:{10 + i}</div>
            ) : null}
            <div style={{ position: "absolute", inset: 0, background: `rgba(109,79,214,${0.28 * on})`, border: on > 0.05 ? `3px solid ${C.purple}` : undefined, borderRadius: 6 }} />
            <div
              style={{
                position: "absolute",
                right: 6,
                top: 6,
                width: 24,
                height: 24,
                borderRadius: 12,
                border: "2px solid #fff",
                background: on > 0.05 ? C.purple : "rgba(0,0,0,0.2)",
                color: "#fff",
                fontSize: 12,
                fontWeight: 800,
                textAlign: "center",
                lineHeight: "21px",
                scale: String(0.7 + 0.3 * Math.max(on, 0.3)),
              }}
            >
              {on > 0.05 ? pk + 1 : ""}
            </div>
          </div>
        );
      })}
      <div
        style={{
          position: "absolute",
          left: ADD_BTN.x - 110,
          top: ADD_BTN.y - 58 - 25,
          width: 220,
          height: 50,
          borderRadius: 25,
          background: n ? `linear-gradient(90deg, ${C.purple}, ${C.pink})` : "rgba(128,128,128,0.4)",
          color: "#fff",
          fontSize: 16,
          fontWeight: 800,
          textAlign: "center",
          lineHeight: "50px",
          scale: String(1 - 0.08 * pulse(f, addAt - 3, 10)),
          boxShadow: n ? "0 8px 22px rgba(224,69,123,0.45)" : undefined,
        }}
      >
        Add {n || ""}
      </div>
    </div>
  );
};

// ------------------------------------------------------------------ editor

export const CANVAS = { x: 20, y: 112, w: 360, h: 450 };
const TR_NAME = { cut: "Cut", fade: "Fade", slideLeft: "Slide", slideUp: "Slide up", zoom: "Zoom" } as const;
const MOVE_NAME = { none: "Still", zoomIn: "Zoom in", zoomOut: "Zoom out", drift: "Drift" } as const;
const ENT_NAME = { none: "Together", pop: "Pop", drop: "Drop", rise: "Rise" } as const;
const DOCK = [
  ["Media", "▣"],
  ["Layout", "▦"],
  ["Style", "◐"],
  ["Text", "Aa"],
  ["Video", "▶"],
];

export const EditorScreen: React.FC<{
  f: number;
  d: Design;
  name: string;
  playFrom: number;
  length: number;
  ring?: (p: number) => number;
  exportAt?: number;
}> = ({ f, d, name, playFrom, length, ring, exportAt }) => {
  const lf = f - playFrom;
  let si = 0;
  d.scenes.forEach((s, i) => {
    if (lf >= s.at) si = i;
  });
  const S = d.scenes[si];
  const prog = Math.max(0, Math.min(1, lf / length));
  return (
    <div style={{ position: "absolute", inset: 0, background: "linear-gradient(180deg,#1d1530,#100b1a)", overflow: "hidden" }}>
      <StatusBar />
      <div style={{ position: "absolute", left: 16, top: 56, width: 40, height: 40, borderRadius: 20, background: "rgba(255,255,255,0.1)", color: "#fff", fontSize: 16, textAlign: "center", lineHeight: "40px" }}>✕</div>
      <div style={{ position: "absolute", left: 110, top: 56, width: 180, height: 40, borderRadius: 20, background: "rgba(255,255,255,0.1)", border: "1px solid rgba(255,255,255,0.16)", color: "#fff", fontSize: 14, fontWeight: 800, textAlign: "center", lineHeight: "38px" }}>
        ✨ {name}
      </div>
      <div style={{ position: "absolute", right: 16, top: 56, width: 74, height: 40, borderRadius: 20, background: C.purple, color: "#fff", fontSize: 13, fontWeight: 800, textAlign: "center", lineHeight: "40px", boxShadow: exportAt ? `0 0 0 ${pulse(f, exportAt - 4, 14) * 8}px rgba(109,79,214,0.45)` : undefined }}>
        Export
      </div>
      <div style={{ position: "absolute", left: CANVAS.x, top: CANVAS.y }}>
        <MotionStage d={d} f={lf} w={CANVAS.w} h={CANVAS.h} ring={ring} empty />
      </div>
      {/* play bar with scene marks */}
      <div style={{ position: "absolute", left: 20, top: 580, width: 360, height: 30 }}>
        <div style={{ position: "absolute", left: 0, top: 2, width: 26, height: 26, borderRadius: 13, background: "#fff", color: C.ink, fontSize: 11, textAlign: "center", lineHeight: "26px" }}>{lf >= 0 ? "❚❚" : "▶"}</div>
        <div style={{ position: "absolute", left: 38, top: 13, width: 280, height: 4, borderRadius: 2, background: "rgba(255,255,255,0.18)" }}>
          <div style={{ width: `${prog * 100}%`, height: "100%", borderRadius: 2, background: `linear-gradient(90deg, ${C.purple}, ${C.pink})` }} />
          {d.scenes.map((s, i) => (
            <div key={i} style={{ position: "absolute", left: (s.at / length) * 280 - 1, top: -4, width: 3, height: 12, borderRadius: 2, background: i <= si && lf >= 0 ? C.gold : "rgba(255,255,255,0.5)" }} />
          ))}
          <div style={{ position: "absolute", left: prog * 280 - 7, top: -5, width: 14, height: 14, borderRadius: 7, background: "#fff" }} />
        </div>
        <Txt x={326} y={7} size={11} color="rgba(255,255,255,0.7)">
          0:{String(Math.floor(Math.max(0, lf) / 30)).padStart(2, "0")}
        </Txt>
      </div>
      {/* scenes */}
      <Txt x={22} y={626} size={12} color="rgba(255,255,255,0.6)">
        SCENES
      </Txt>
      {d.scenes.map((s, i) => {
        const on = lf >= 0 && i === si;
        return (
          <div
            key={i}
            style={{
              position: "absolute",
              left: 20 + i * 74,
              top: 648,
              width: 68,
              height: 58,
              borderRadius: 12,
              background: on ? "rgba(109,79,214,0.85)" : "rgba(255,255,255,0.08)",
              border: on ? `2px solid ${C.gold}` : "1px solid rgba(255,255,255,0.14)",
              boxSizing: "border-box",
              scale: String(on ? 1 + 0.06 * pulse(f, playFrom + s.at, 10) : 1),
            }}
          >
            <div style={{ display: "flex", gap: 2, padding: 6, height: 28 }}>
              {s.slots.slice(0, 3).map((sl) => (
                <Img key={sl.p} src={staticFile(`travel/thumb/${d.pics[sl.p].k}.jpg`)} style={{ flex: 1, height: 26, objectFit: "cover", borderRadius: 4, minWidth: 0 }} />
              ))}
            </div>
            <div style={{ textAlign: "center", color: "#fff", fontSize: 9.5, fontWeight: 800, marginTop: 2 }}>Scene {i + 1}</div>
          </div>
        );
      })}
      <div style={{ position: "absolute", left: 20 + d.scenes.length * 74, top: 648, width: 50, height: 58, borderRadius: 12, border: "1.5px dashed rgba(255,255,255,0.3)", color: "rgba(255,255,255,0.6)", fontSize: 22, textAlign: "center", lineHeight: "56px" }}>+</div>
      {/* what this scene does */}
      <div style={{ position: "absolute", left: 20, top: 720, display: "flex", gap: 6 }}>
        {[
          ["Transition", TR_NAME[S.tr ?? "fade"]],
          ["Move", MOVE_NAME[S.move ?? "none"]],
          ["Entrance", ENT_NAME[S.ent ?? "none"]],
        ].map(([k, v]) => (
          <div key={k} style={{ padding: "6px 10px", borderRadius: 14, background: "rgba(255,255,255,0.08)", border: "1px solid rgba(255,255,255,0.14)", color: "#fff", fontSize: 10.5, fontWeight: 700, opacity: lf >= 0 ? 1 : 0.5 }}>
            <span style={{ color: "rgba(255,255,255,0.55)" }}>{k} </span>
            {lf >= 0 ? v : "–"}
          </div>
        ))}
      </div>
      {/* dock */}
      <div style={{ position: "absolute", left: 14, top: SH - 88, width: SW - 28, height: 58, borderRadius: 29, background: "rgba(255,255,255,0.09)", border: "1px solid rgba(255,255,255,0.15)" }}>
        <div style={{ position: "absolute", left: 4 + 1 * 74, top: 5, width: 68, height: 48, borderRadius: 24, background: C.purple }} />
        {DOCK.map(([n, ic], k) => (
          <div key={n} style={{ position: "absolute", left: 4 + k * 74, top: 9, width: 68, textAlign: "center", color: "#fff" }}>
            <div style={{ fontSize: 15 }}>{ic}</div>
            <div style={{ fontSize: 9.5, fontWeight: 700 }}>{n}</div>
          </div>
        ))}
      </div>
      {exportAt !== undefined && f >= exportAt ? <ExportSheet f={f} at={exportAt} /> : null}
    </div>
  );
};

const ExportSheet: React.FC<{ f: number; at: number }> = ({ f, at }) => {
  const up = ip(f, at, at + 12) * (1 - ip(f, at + 58, at + 70));
  const prog = ip(f, at + 8, at + 34, 0, 1, Easing.inOut(Easing.quad));
  const saved = ip(f, at + 34, at + 44, 0, 1, POP);
  return (
    <div style={{ position: "absolute", left: 0, right: 0, top: SH - 300 * up, height: 300, borderRadius: "26px 26px 0 0", background: "#241c38", boxShadow: "0 -10px 30px rgba(0,0,0,0.45)", zIndex: 20 }}>
      <Txt x={0} y={20} size={16} color="#fff" weight={800} style={{ width: SW, textAlign: "center" }}>
        Export video
      </Txt>
      <div style={{ position: "absolute", left: 40, top: 60, display: "flex", gap: 8 }}>
        {["HD", "60 fps", "MP4"].map((x) => (
          <div key={x} style={{ padding: "5px 12px", borderRadius: 14, background: "rgba(255,255,255,0.1)", color: "#fff", fontSize: 11, fontWeight: 800 }}>
            {x}
          </div>
        ))}
      </div>
      <div style={{ position: "absolute", left: 40, top: 110, width: 320, height: 10, borderRadius: 5, background: "rgba(255,255,255,0.12)" }}>
        <div style={{ width: `${prog * 100}%`, height: "100%", borderRadius: 5, background: `linear-gradient(90deg, ${C.purple}, ${C.pink})` }} />
      </div>
      <div style={{ position: "absolute", left: 0, right: 0, top: 146, textAlign: "center", color: C.teal, fontSize: 19, fontWeight: 800, scale: String(saved), opacity: saved }}>✓ Saved to Photos</div>
    </div>
  );
};

// ------------------------------------------------------------------ camera roll (Ad B hook)

export const CameraRoll: React.FC<{ scroll: number; count: number }> = ({ scroll, count }) => {
  const s = 97;
  const rows = 40;
  return (
    <div style={{ position: "absolute", inset: 0, background: "#fff", overflow: "hidden" }}>
      <div style={{ position: "absolute", left: 0, top: -(scroll % (s * 20)) + 110, width: SW }}>
        {Array.from({ length: rows * 4 }).map((_, i) => {
          const k = PHOTO_KINDS[(i * 7) % PHOTO_KINDS.length];
          const v = i % 5 === 2;
          return (
            <div key={i} style={{ position: "absolute", left: (i % 4) * (s + 2), top: Math.floor(i / 4) * (s + 2), width: s, height: s, overflow: "hidden" }}>
              <Img src={staticFile(`travel/thumb/${k}.jpg`)} style={{ width: "100%", height: "100%", objectFit: "cover" }} />
              {v ? <div style={{ position: "absolute", right: 4, bottom: 3, color: "#fff", fontSize: 10, fontWeight: 800, textShadow: "0 1px 3px rgba(0,0,0,0.7)" }}>0:{14 + (i % 40)}</div> : null}
            </div>
          );
        })}
      </div>
      <div style={{ position: "absolute", left: 0, right: 0, top: 0, height: 112, background: "linear-gradient(180deg, rgba(255,255,255,0.97) 70%, rgba(255,255,255,0))" }} />
      <StatusBar dark={false} />
      <Txt x={20} y={54} size={30} color="#111" weight={800}>
        Library
      </Txt>
      <Txt x={22} y={92} size={12} color="rgba(0,0,0,0.5)" weight={700}>
        {count} Items · this weekend
      </Txt>
      <div style={{ position: "absolute", left: 40, top: SH - 86, width: 320, height: 44, borderRadius: 22, background: "rgba(245,245,247,0.92)", boxShadow: "0 6px 20px rgba(0,0,0,0.15)", display: "flex", padding: 4, boxSizing: "border-box" }}>
        {["Years", "Months", "Days", "All"].map((x, i) => (
          <div key={x} style={{ flex: 1, textAlign: "center", fontSize: 12, fontWeight: 700, paddingTop: 9, borderRadius: 18, background: i === 3 ? "#fff" : undefined, color: "#111", boxShadow: i === 3 ? "0 1px 4px rgba(0,0,0,0.12)" : undefined }}>
            {x}
          </div>
        ))}
      </div>
    </div>
  );
};

