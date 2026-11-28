import React from "react";
import { Audio } from "@remotion/media";
import { AbsoluteFill, Easing, interpolate, Sequence, staticFile, useCurrentFrame } from "remotion";
import type { Caption } from "@remotion/captions";
import { loadFont as unbounded } from "@remotion/google-fonts/Unbounded";
import type { PhotoKind } from "../ad/TripPhoto";
import { C, clamp, fontFamily } from "../ad/theme";
import { ip, POP, pulse } from "../ad5/kit";
import { AppIcon, Clip, NAME, Still, StoreBadge } from "../motion/kit";
import raw from "../data/motion-v6-words.json";

/**
 * v6 motion-template ad, "Every vibe, in motion" (~16 s, voice: public/audio/vo-motion-v6.mp3, ElevenLabs "Kristen").
 * No phone: every theme gets its own colour world and a floating collage whose pictures arrive with the motion the
 * voice names (bounce, glide, pop), then a rapid flip through trips (zoom), birthdays (spin), weddings (rise) and pets
 * (drop), a wall of real template names for "70+", photos and videos flying into one design, and the end card.
 * Scenes open with an iris wipe from the collage.
 */
const WORDS = raw as Caption[];
const DISPLAY = unbounded("normal", { weights: ["600", "800", "900"], subsets: ["latin"] }).fontFamily;

const VS = 6;
const at = (s: number) => VS + Math.round(s * 30);
const B = {
  bounce: at(1.47),
  beach: at(2.16),
  glide: at(3.17),
  date: at(3.94),
  pop: at(5.19),
  trips: at(5.87),
  birthdays: at(6.24),
  weddings: at(6.96),
  pets: at(7.61),
  n70: at(8.83),
  drop: at(10.56),
  photos: at(10.84),
  videos: at(11.31),
  done: at(11.92),
  name: at(12.71),
  every: at(14.08),
  motion: at(14.97),
};
export const VIBES_TOTAL = at(15.7) + 21;

// ------------------------------------------------------------------ collage card

type Entrance = "slam" | "slide" | "pop" | "zoom" | "spin" | "rise" | "drop";
type Cell = { x: number; y: number; w: number; h: number; kind: PhotoKind; video?: boolean };

const CARD_W = 820;
const CARD_H = 1010;
const CARD_TOP = 420;

const grid4 = (k: PhotoKind[], v: number[] = []): Cell[] =>
  [
    [0, 0, 0.5, 0.55],
    [0.5, 0, 0.5, 0.42],
    [0, 0.55, 0.5, 0.45],
    [0.5, 0.42, 0.5, 0.58],
  ].map(([x, y, w, h], i) => ({ x, y, w, h, kind: k[i], video: v.includes(i) }));
const hero3 = (k: PhotoKind[], v: number[] = []): Cell[] =>
  [
    [0, 0, 1, 0.58],
    [0, 0.58, 0.5, 0.42],
    [0.5, 0.58, 0.5, 0.42],
  ].map(([x, y, w, h], i) => ({ x, y, w, h, kind: k[i], video: v.includes(i) }));
const col3 = (k: PhotoKind[], v: number[] = []): Cell[] =>
  [
    [0, 0, 0.58, 1],
    [0.58, 0, 0.42, 0.5],
    [0.58, 0.5, 0.42, 0.5],
  ].map(([x, y, w, h], i) => ({ x, y, w, h, kind: k[i], video: v.includes(i) }));
const five = (k: PhotoKind[], v: number[] = []): Cell[] =>
  [
    [0, 0, 0.6, 0.4],
    [0.6, 0, 0.4, 0.4],
    [0, 0.4, 0.4, 0.6],
    [0.4, 0.4, 0.6, 0.32],
    [0.4, 0.72, 0.6, 0.28],
  ].map(([x, y, w, h], i) => ({ x, y, w, h, kind: k[i], video: v.includes(i) }));

const BOUNCE = Easing.bezier(0.22, 1.9, 0.5, 1);

/** How one cell looks `p` (0..1) into its entrance. */
const enter = (e: Entrance, p: number, i: number): React.CSSProperties => {
  const q = Math.min(1, p * 2.2);
  switch (e) {
    case "slam":
      return { scale: String(interpolate(p, [0, 0.55, 0.75, 1], [2.1, 0.9, 1.04, 1])), opacity: q, rotate: `${(1 - p) * (i % 2 ? 9 : -9)}deg` };
    case "slide":
      return { translate: `${(1 - p) * (i % 2 ? 130 : -130)}% 0`, opacity: q };
    case "pop":
      return { scale: String(0.2 + 0.8 * p), opacity: q };
    case "zoom":
      return { scale: String(1.6 - 0.6 * p), opacity: q, filter: `blur(${(1 - p) * 14}px)` };
    case "spin":
      return { rotate: `${(1 - p) * 200}deg`, scale: String(0.2 + 0.8 * p), opacity: q };
    case "rise":
      return { translate: `0 ${(1 - p) * 60}%`, opacity: q };
    case "drop":
      return { translate: `0 ${(1 - p) * -160}%`, opacity: q };
  }
};

const EASE: Record<Entrance, (t: number) => number> = {
  slam: (t) => t,
  slide: Easing.bezier(0.16, 1, 0.3, 1),
  pop: POP,
  zoom: Easing.bezier(0.16, 1, 0.3, 1),
  spin: Easing.bezier(0.2, 1.2, 0.4, 1),
  rise: Easing.bezier(0.16, 1, 0.3, 1),
  drop: BOUNCE,
};

const Collage: React.FC<{
  cells: Cell[];
  entrance: Entrance;
  start: number;
  gap?: number;
  frame: string;
  stagger?: number;
  len?: number;
  scale?: number;
  top?: number;
  tilt?: number;
  shadow?: string;
}> = ({ cells, entrance, start, gap = 14, frame, stagger = 4, len = 14, scale = 1, top = CARD_TOP, tilt = 0, shadow = "rgba(0,0,0,0.35)" }) => {
  const f = useCurrentFrame();
  const inner = { w: CARD_W - gap * 2, h: CARD_H - gap * 2 };
  // the card itself lands first, with a slight swing
  const land = ip(f, start - 8, start + 6, 0, 1, POP);
  // slams shake the whole card on impact
  const shake = entrance === "slam" ? cells.reduce((s, _, i) => s + pulse(f, start + i * stagger + 8, 6), 0) : 0;
  return (
    <div
      style={{
        position: "absolute",
        left: 540 - CARD_W / 2,
        top,
        width: CARD_W,
        height: CARD_H,
        borderRadius: 46,
        background: frame,
        boxShadow: `0 40px 90px ${shadow}`,
        scale: String((0.86 + 0.14 * land) * scale),
        rotate: `${tilt + (1 - land) * -6 + Math.sin(f * 2.1) * shake * 1.4}deg`,
        translate: `${Math.sin(f * 3.3) * shake * 10}px ${(1 - land) * 140}px`,
        opacity: Math.min(1, land * 3),
      }}
    >
      {cells.map((c, i) => {
        const t0 = start + i * stagger;
        const p = EASE[entrance](ip(f, t0, t0 + len, 0, 1, (x) => x));
        const L = gap + c.x * inner.w + (c.x > 0 ? gap / 2 : 0);
        const T = gap + c.y * inner.h + (c.y > 0 ? gap / 2 : 0);
        const W = c.w * inner.w - (c.x > 0 ? gap / 2 : 0) - (c.x + c.w < 0.999 ? gap / 2 : 0);
        const H = c.h * inner.h - (c.y > 0 ? gap / 2 : 0) - (c.y + c.h < 0.999 ? gap / 2 : 0);
        // after arriving, stills keep moving (zoom in / drift), like the app's photo moves
        const live = Math.max(0, f - t0 - len);
        return (
          <div key={i} style={{ position: "absolute", left: L, top: T, width: W, height: H, borderRadius: 30, overflow: "hidden", background: "rgba(0,0,0,0.15)", ...enter(entrance, p, i) }}>
            {c.video ? <Clip kind={c.kind} f={f} seed={i} u={2.6} /> : <Still kind={c.kind} zoom={1.04 + live * 0.0022} pan={entrance === "slide" ? Math.sin(live / 40) * 0.6 : 0} />}
          </div>
        );
      })}
    </div>
  );
};

// ------------------------------------------------------------------ scene shell

/** A full-screen scene that opens with a circle growing from the collage's centre. */
const Iris: React.FC<{ from: number; bg: string; children: React.ReactNode; first?: boolean }> = ({ from, bg, children, first }) => {
  const f = useCurrentFrame();
  const r = first ? 150 : ip(f, from, from + 9, 0, 150, Easing.bezier(0.6, 0, 0.3, 1));
  return (
    <AbsoluteFill style={{ background: bg, clipPath: `circle(${r}% at 50% 46%)`, overflow: "hidden" }}>
      {children}
    </AbsoluteFill>
  );
};

/** The theme chip at the top: "🎉 Party night?" */
const Chip: React.FC<{ at: number; children: React.ReactNode; bg: string; color: string; top?: number }> = ({ at: t, children, bg, color, top = 150 }) => {
  const f = useCurrentFrame();
  const a = ip(f, t, t + 10, 0, 1, POP);
  return (
    <div style={{ position: "absolute", top, left: 0, right: 0, display: "flex", justifyContent: "center" }}>
      <div style={{ padding: "18px 40px", borderRadius: 60, background: bg, color, fontFamily: DISPLAY, fontWeight: 800, fontSize: 56, letterSpacing: -1, scale: String(0.6 + 0.4 * a), opacity: Math.min(1, a * 2), translate: `0 ${(1 - a) * -40}px` }}>
        {children}
      </div>
    </div>
  );
};

/** The motion verb, stamped across the collage; its letters move the way the verb says. */
const Verb: React.FC<{ at: number; word: string; style: Entrance; color: string; stroke: string; top?: number; size?: number; tilt?: number }> = ({ at: t, word, style, color, stroke, top = 300, size = 150, tilt = -6 }) => {
  const f = useCurrentFrame();
  return (
    <div style={{ position: "absolute", top, left: 0, right: 0, display: "flex", justifyContent: "center", rotate: `${tilt}deg`, zIndex: 5 }}>
      {word.split("").map((ch, i) => {
        const p = EASE[style](ip(f, t + i * 1.5, t + i * 1.5 + 11, 0, 1, (x) => x));
        const look = enter(style, p, i);
        const bob = style === "slam" ? -Math.abs(Math.sin((f - t) / 5 + i * 0.7)) * 16 * ip(f, t + 14, t + 20) : 0;
        return (
          <span
            key={i}
            style={{
              display: "inline-block",
              fontFamily: DISPLAY,
              fontWeight: 900,
              fontSize: size,
              color,
              WebkitTextStroke: `${size * 0.05}px ${stroke}`,
              paintOrder: "stroke fill",
              textShadow: `0 ${size * 0.08}px 0 ${stroke}`,
              lineHeight: 1,
              ...look,
              translate: `${look.translate ?? "0 0"}`,
              marginTop: bob,
            }}
          >
            {ch}
          </span>
        );
      })}
    </div>
  );
};

// ------------------------------------------------------------------ decorations

const Confetti: React.FC<{ from: number; colors: string[] }> = ({ from, colors }) => {
  const f = useCurrentFrame();
  const t = f - from;
  return (
    <>
      {Array.from({ length: 46 }).map((_, i) => {
        const x = (i * 197) % 1080;
        const sp = 9 + (i % 5) * 3;
        const y = -80 + ((t * sp + i * 131) % 2100);
        return <div key={i} style={{ position: "absolute", left: x + Math.sin(t / 8 + i) * 40, top: y, width: 18 + (i % 3) * 8, height: 34, borderRadius: 5, background: colors[i % colors.length], rotate: `${t * (6 + (i % 4)) + i * 40}deg` }} />;
      })}
    </>
  );
};

const Waves: React.FC = () => {
  const f = useCurrentFrame();
  return (
    <>
      {[0, 1, 2].map((i) => (
        <svg key={i} width={2400} height={220} viewBox="0 0 2400 220" style={{ position: "absolute", left: -((f * (4 + i * 2) + i * 300) % 600), bottom: 40 + i * 120, opacity: 0.25 + i * 0.12 }}>
          <path d={`M0 110 ${Array.from({ length: 8 }).map((_, k) => `Q ${k * 300 + 150} ${k % 2 ? 30 : 190} ${k * 300 + 300} 110`).join(" ")} V220 H0Z`} fill="#fff" />
        </svg>
      ))}
    </>
  );
};

const Floaters: React.FC<{ from: number; glyph: string; color: string; n?: number }> = ({ from, glyph, color, n = 16 }) => {
  const f = useCurrentFrame();
  const t = f - from;
  return (
    <>
      {Array.from({ length: n }).map((_, i) => {
        const x = (i * 271) % 1040;
        const y = 1980 - ((t * (5 + (i % 4) * 2) + i * 173) % 2200);
        return <div key={i} style={{ position: "absolute", left: x, top: y, fontSize: 40 + (i % 3) * 26, color, opacity: 0.55, rotate: `${Math.sin(t / 10 + i) * 18}deg` }}>{glyph}</div>;
      })}
    </>
  );
};

/** Big outlined word sliding behind the collage, like a poster. */
const BackWord: React.FC<{ text: string; color: string; top: number; speed?: number }> = ({ text, color, top, speed = 6 }) => {
  const f = useCurrentFrame();
  return (
    <div style={{ position: "absolute", top, left: 0, whiteSpace: "nowrap", translate: `${-((f * speed) % 1400)}px 0`, fontFamily: DISPLAY, fontWeight: 900, fontSize: 300, color: "transparent", WebkitTextStroke: `4px ${color}`, lineHeight: 1 }}>
      {`${text} ${text} ${text} ${text}`}
    </div>
  );
};

// ------------------------------------------------------------------ scenes

const Party: React.FC = () => (
  <Iris from={0} bg="radial-gradient(circle at 50% 45%, #FF4FA0 0%, #E01F72 60%, #A3104F 100%)" first>
    <BackWord text="PARTY" color="rgba(255,225,77,0.35)" top={1480} />
    <Confetti from={0} colors={["#FFE14D", "#fff", "#5BE7FF", "#7B4DFF"]} />
    <Chip at={2} bg="#FFE14D" color="#7A0A3C">🎉 Party night?</Chip>
    <Collage cells={grid4(["santorini-sunset", "aurora-beach", "dinner-fira", "balloons"], [1])} entrance="slam" start={14} stagger={5} len={13} frame="#FFE14D" shadow="rgba(90,0,40,0.5)" tilt={-2} />
    <Verb at={B.bounce - 2} word="BOUNCE!" style="slam" color="#FFE14D" stroke="#7A0A3C" top={1290} size={140} />
  </Iris>
);

const Beach: React.FC = () => (
  <Iris from={B.beach - 4} bg="linear-gradient(180deg, #19C6D1 0%, #2FA8E0 55%, #F7D9A8 100%)">
    <Waves />
    <BackWord text="BEACH" color="rgba(255,255,255,0.45)" top={120} speed={-5} />
    <Chip at={B.beach} bg="#fff" color="#0B6E86">🌊 Beach day?</Chip>
    <Collage cells={hero3(["turquoise", "palm-beach", "overwater"], [0])} entrance="slide" start={B.beach + 4} stagger={5} len={16} frame="#fff" shadow="rgba(0,70,100,0.4)" tilt={2} />
    <Verb at={B.glide - 2} word="GLIDE" style="slide" color="#fff" stroke="#0B6E86" top={1290} size={150} tilt={-4} />
  </Iris>
);

const DateNight: React.FC = () => (
  <Iris from={B.date - 4} bg="radial-gradient(circle at 50% 40%, #8C1A44 0%, #4A0A24 75%)">
    <Floaters from={B.date} glyph="♥" color="#FF6B8B" />
    <Chip at={B.date} bg="#FF6B8B" color="#fff">🌹 Date night?</Chip>
    <Collage cells={col3(["venice-canal", "pizza", "santorini-domes"], [0])} entrance="pop" start={B.date + 4} stagger={5} len={12} frame="#FFD3DC" shadow="rgba(0,0,0,0.5)" tilt={-1.5} />
    <Verb at={B.pop - 2} word="POP!" style="pop" color="#FFD3DC" stroke="#C2185B" top={1290} size={170} tilt={5} />
  </Iris>
);

/** One fast card of the montage: theme word, real template name, the motion it uses. */
const Flash: React.FC<{ from: number; bg: string; ink: string; label: string; tpl: string; move: string; cells: Cell[]; entrance: Entrance; frame: string; glyph: string }> = ({ from, bg, ink, label, tpl, move, cells, entrance, frame, glyph }) => {
  const f = useCurrentFrame();
  const a = ip(f, from, from + 8, 0, 1, POP);
  return (
    <Iris from={from - 3} bg={bg}>
      <Floaters from={from} glyph={glyph} color={ink} n={10} />
      <div style={{ position: "absolute", top: 120, left: 0, right: 0, textAlign: "center", fontFamily: DISPLAY, fontWeight: 900, fontSize: 132, color: ink, letterSpacing: -4, scale: String(0.7 + 0.3 * a), opacity: Math.min(1, a * 2) }}>{label}</div>
      <Collage cells={cells} entrance={entrance} start={from} stagger={2} len={10} frame={frame} scale={0.9} top={400} shadow="rgba(0,0,0,0.3)" />
      <div style={{ position: "absolute", top: 1440, left: 0, right: 0, display: "flex", justifyContent: "center", gap: 18, opacity: Math.min(1, a * 2), translate: `0 ${(1 - a) * 40}px` }}>
        <div style={{ padding: "14px 30px", borderRadius: 40, background: ink, color: bg.startsWith("#") ? bg : "#fff", fontFamily, fontWeight: 800, fontSize: 40 }}>✨ {tpl}</div>
        <div style={{ padding: "14px 30px", borderRadius: 40, border: `4px solid ${ink}`, color: ink, fontFamily: DISPLAY, fontWeight: 800, fontSize: 36 }}>{move}</div>
      </div>
    </Iris>
  );
};

const NAMES = [
  "Party starter", "Beach day", "Date night", "Wanderlust", "Birthday bash", "Just married", "Zoomies", "Disco fever", "Salt water",
  "Love letter", "Road trip", "Make a wish", "First dance", "Paw prints", "Confetti pop", "Island time", "Heartbeat", "Snow days",
  "Besties", "Brunch club", "Film reel", "Spooky season", "Grad day", "Little one", "Beast mode", "Coffee date", "Countdown",
  "Surf club", "Rose petals", "City lights", "Festival", "Squad goals", "Lookbook", "Then & now", "Ever after", "Poolside",
];
const WALL_PICS: PhotoKind[] = ["amalfi", "golden-wave", "aurora-reine", "breakfast", "desert-road", "positano", "leaning-palm", "venice-rialto", "balloons-valley", "mountain-lake", "beach-sunset", "swiss-house"];
const TINTS = ["#FF4FA0", "#19C6D1", "#8C1A44", "#2E8B57", "#FFC23C", "#F5EDE1", "#FF8A3D", "#7B4DFF"];

const Wall: React.FC = () => {
  const f = useCurrentFrame();
  const t = f - B.n70;
  const n = Math.round(ip(f, B.n70, B.n70 + 26, 0, 70, Easing.out(Easing.cubic)));
  const zoomOut = ip(f, B.n70 - 2, B.n70 + 30, 1.9, 1, Easing.bezier(0.16, 1, 0.3, 1));
  const big = ip(f, B.n70, B.n70 + 10, 0, 1, POP);
  return (
    <Iris from={B.n70 - 4} bg={C.purpleDeep}>
      <div style={{ position: "absolute", inset: -300, rotate: "-12deg", scale: String(zoomOut) }}>
        {Array.from({ length: 7 }).map((_, col) => (
          <div key={col} style={{ position: "absolute", left: 40 + col * 250, top: ((col % 2 ? -1 : 1) * t * 7) % 330 - 330, display: "flex", flexDirection: "column", gap: 24 }}>
            {Array.from({ length: 10 }).map((__, r) => {
              const k = col * 10 + r;
              return (
                <div key={r} style={{ width: 226, height: 306, borderRadius: 26, background: TINTS[k % TINTS.length], padding: 10, boxSizing: "border-box", display: "flex", flexDirection: "column", gap: 8 }}>
                  <div style={{ position: "relative", flex: 1, borderRadius: 18, overflow: "hidden" }}>
                    <Still kind={WALL_PICS[k % WALL_PICS.length]} small zoom={1 + 0.06 * Math.sin((f + k * 9) / 12)} />
                  </div>
                  <div style={{ fontFamily, fontWeight: 800, fontSize: 22, color: k % TINTS.length === 5 || k % TINTS.length === 4 ? C.ink : "#fff", textAlign: "center", whiteSpace: "nowrap" }}>{NAMES[k % NAMES.length]}</div>
                </div>
              );
            })}
          </div>
        ))}
      </div>
      <AbsoluteFill style={{ background: "radial-gradient(circle at 50% 46%, rgba(30,20,56,0.88) 0%, rgba(30,20,56,0.55) 40%, rgba(30,20,56,0.1) 75%)" }} />
      <div style={{ position: "absolute", top: 560, left: 0, right: 0, textAlign: "center", scale: String(0.4 + 0.6 * big), opacity: Math.min(1, big * 2) }}>
        <div style={{ fontFamily: DISPLAY, fontWeight: 900, fontSize: 330, lineHeight: 1, color: "#FFE14D", letterSpacing: -14, textShadow: "0 18px 0 #E01F72" }}>{n}+</div>
        <div style={{ marginTop: 30, fontFamily: DISPLAY, fontWeight: 800, fontSize: 76, color: "#fff", lineHeight: 1.05 }}>
          motion
          <br />
          templates
        </div>
      </div>
    </Iris>
  );
};

const FLY: { kind: PhotoKind; video?: boolean; from: [number, number]; at: number }[] = [
  { kind: "positano", from: [-700, -300], at: B.photos - 4 },
  { kind: "golden-wave", video: true, from: [700, -500], at: B.videos - 6 },
  { kind: "breakfast", from: [-700, 600], at: B.photos + 2 },
  { kind: "aurora-reine", video: true, from: [700, 500], at: B.videos },
];

const DropIn: React.FC = () => {
  const f = useCurrentFrame();
  const cells = grid4(FLY.map((x) => x.kind), [1, 3]);
  const gap = 14;
  const inner = { w: CARD_W - gap * 2, h: CARD_H - gap * 2 };
  const stamp = ip(f, B.done, B.done + 10, 0, 1, POP);
  const card = ip(f, B.drop - 4, B.drop + 8, 0, 1, POP);
  return (
    <Iris from={B.drop - 4} bg="linear-gradient(160deg, #F6F1FD 0%, #E3D8F6 100%)">
      <Chip at={B.drop} bg={C.ink} color="#fff">📷 Photos + 🎬 videos</Chip>
      <div style={{ position: "absolute", left: 540 - CARD_W / 2, top: CARD_TOP, width: CARD_W, height: CARD_H, borderRadius: 46, background: "#fff", boxShadow: "0 40px 90px rgba(75,50,176,0.3)", scale: String(0.9 + 0.1 * card), opacity: card }}>
        {cells.map((c, i) => {
          const fl = FLY[i];
          const p = ip(f, fl.at, fl.at + 12, 0, 1, Easing.bezier(0.2, 1.3, 0.4, 1));
          const L = gap + c.x * inner.w + (c.x > 0 ? gap / 2 : 0);
          const T = gap + c.y * inner.h + (c.y > 0 ? gap / 2 : 0);
          const W = c.w * inner.w - (c.x > 0 ? gap / 2 : 0) - (c.x + c.w < 0.999 ? gap / 2 : 0);
          const H = c.h * inner.h - (c.y > 0 ? gap / 2 : 0) - (c.y + c.h < 0.999 ? gap / 2 : 0);
          return (
            <React.Fragment key={i}>
              <div style={{ position: "absolute", left: L, top: T, width: W, height: H, borderRadius: 30, border: "4px dashed #CBBDF0", boxSizing: "border-box", opacity: 1 - p }} />
              <div style={{ position: "absolute", left: L, top: T, width: W, height: H, borderRadius: 30, overflow: "hidden", translate: `${(1 - p) * fl.from[0]}px ${(1 - p) * fl.from[1]}px`, rotate: `${(1 - p) * (i % 2 ? 25 : -25)}deg`, opacity: Math.min(1, p * 4) }}>
                {c.video ? <Clip kind={c.kind} f={f} seed={i} u={2.6} /> : <Still kind={c.kind} zoom={1.04 + Math.max(0, f - fl.at) * 0.002} />}
              </div>
            </React.Fragment>
          );
        })}
      </div>
      <div style={{ position: "absolute", top: 830, left: 0, right: 0, display: "flex", justifyContent: "center", zIndex: 6 }}>
        <div style={{ padding: "26px 60px", borderRadius: 30, background: C.teal, color: "#fff", fontFamily: DISPLAY, fontWeight: 900, fontSize: 120, rotate: `${-8 + (1 - stamp) * 20}deg`, scale: String(2.4 - 1.4 * stamp), opacity: Math.min(1, stamp * 3), boxShadow: "0 20px 50px rgba(0,0,0,0.3)", border: "8px solid #fff" }}>
          DONE ✓
        </div>
      </div>
    </Iris>
  );
};

const End: React.FC = () => {
  const f = useCurrentFrame();
  const icon = ip(f, B.name - 2, B.name + 10, 0, 1, POP);
  const name = ip(f, B.name + 2, B.name + 14, 0, 1, POP);
  const badge = ip(f, B.every + 6, B.every + 18, 0, 1, POP);
  const words: [string, number][] = [
    ["Every", B.every],
    ["vibe,", B.every + 8],
    ["in", B.motion - 2],
    ["motion.", B.motion + 2],
  ];
  const t = f - B.name;
  return (
    <Iris from={B.name - 4} bg={`linear-gradient(150deg, ${C.purple} 0%, ${C.purpleDeep} 45%, ${C.pink} 100%)`}>
      {/* the theme colours orbit the logo */}
      {TINTS.map((c, i) => {
        const a = (i / TINTS.length) * Math.PI * 2 + t / 28;
        const r = 380 + 30 * Math.sin(t / 9 + i);
        const s = ip(f, B.name + i * 2, B.name + i * 2 + 12, 0, 1, POP);
        return <div key={i} style={{ position: "absolute", left: 540 + Math.cos(a) * r - 60, top: 640 + Math.sin(a) * r * 0.75 - 75, width: 120, height: 150, borderRadius: 22, background: c, border: "6px solid #fff", rotate: `${Math.sin(a) * 18}deg`, scale: String(s), opacity: 0.9, boxShadow: "0 16px 30px rgba(0,0,0,0.25)", overflow: "hidden" }}><Still kind={WALL_PICS[i]} small /></div>;
      })}
      <div style={{ position: "absolute", top: 540, left: 0, right: 0, display: "flex", flexDirection: "column", alignItems: "center" }}>
        <div style={{ scale: String(icon), rotate: `${(1 - icon) * -30}deg` }}>
          <AppIcon size={210} />
        </div>
      </div>
      <div style={{ position: "absolute", top: 1000, left: 0, right: 0, display: "flex", flexDirection: "column", alignItems: "center" }}>
        <div style={{ fontFamily: DISPLAY, fontWeight: 900, fontSize: 104, color: "#fff", letterSpacing: -3, scale: String(0.6 + 0.4 * name), opacity: Math.min(1, name * 2) }}>{NAME}</div>
        <div style={{ display: "flex", gap: 22, marginTop: 18 }}>
          {words.map(([w, wt], i) => {
            const a = ip(f, wt, wt + 9, 0, 1, POP);
            return (
              <div key={w} style={{ fontFamily: DISPLAY, fontWeight: 800, fontSize: 62, color: i === 3 ? "#FFE14D" : "#fff", opacity: Math.min(1, a * 2), translate: `0 ${(1 - a) * 40}px`, scale: String(0.6 + 0.4 * a) }}>
                {w}
              </div>
            );
          })}
        </div>
        <div style={{ marginTop: 56, scale: String(0.6 + 0.4 * badge), opacity: Math.min(1, badge * 2) }}>
          <StoreBadge u={1.1} />
        </div>
      </div>
    </Iris>
  );
};

// ------------------------------------------------------------------ captions

/** One short line at a time; the word being spoken gets a tilted highlighter block behind it. */
const Subs: React.FC = () => {
  const f = useCurrentFrame();
  const ms = ((f - VS) / 30) * 1000;
  const pages: Caption[][] = [];
  let cur: Caption[] = [];
  WORDS.forEach((w, i) => {
    cur.push(w);
    if (/[.?!,]$/.test(w.text) || cur.length >= 3 || i === WORDS.length - 1) {
      pages.push(cur);
      cur = [];
    }
  });
  const page = pages.find((p, i) => ms >= p[0].startMs - 60 && ms < (pages[i + 1] ? pages[i + 1][0].startMs - 60 : p[p.length - 1].endMs + 500));
  if (!page || f >= B.name - 4) return null;
  const p0 = VS + ((page[0].startMs - 60) / 1000) * 30;
  const a = ip(f, p0, p0 + 7, 0, 1, POP);
  return (
    <div style={{ position: "absolute", top: 1630, left: 0, right: 0, display: "flex", justifyContent: "center", scale: String(0.85 + 0.15 * a), opacity: Math.min(1, a * 2) }}>
    <div style={{ display: "flex", justifyContent: "center", flexWrap: "wrap", gap: 6, padding: "10px 18px", borderRadius: 28, background: "rgba(22,12,44,0.62)", backdropFilter: "blur(10px)", maxWidth: 1000 }}>
      {page.map((w) => {
        const on = ms >= w.startMs - 40 && ms < w.endMs + 120;
        return (
          <div key={w.startMs} style={{ position: "relative", isolation: "isolate", padding: "6px 16px", fontFamily: DISPLAY, fontWeight: 800, fontSize: 64, color: on ? C.ink : "#fff" }}>
            <div style={{ position: "absolute", inset: 0, borderRadius: 14, background: "#FFE14D", rotate: "-2deg", scale: on ? "1" : "0", transition: "none", zIndex: -1 }} />
            <span style={{ position: "relative" }}>{w.text}</span>
          </div>
        );
      })}
    </div>
    </div>
  );
};

// ------------------------------------------------------------------ the ad

const FLASHES: React.ComponentProps<typeof Flash>[] = [
  { from: B.trips, bg: "#2E8B57", ink: "#F7E9C8", label: "TRIPS", tpl: "Wanderlust", move: "ZOOM", entrance: "zoom", frame: "#F7E9C8", glyph: "✈", cells: hero3(["desert-road", "alpine-lake", "amalfi"], [0]) },
  { from: B.birthdays, bg: "#FFC23C", ink: "#3B1F00", label: "BIRTHDAYS", tpl: "Birthday bash", move: "SPIN", entrance: "spin", frame: "#fff", glyph: "🎈", cells: grid4(["balloons", "breakfast", "balloons-valley", "golden-palms"], [0]) },
  { from: B.weddings, bg: "#F5EDE1", ink: "#6B4E3D", label: "WEDDINGS", tpl: "Just married", move: "RISE", entrance: "rise", frame: "#fff", glyph: "♡", cells: col3(["santorini-windmills", "santorini-domes", "venice-rialto"], [0]) },
  { from: B.pets, bg: "#FF8A3D", ink: "#3B1600", label: "PETS!", tpl: "Zoomies", move: "DROP", entrance: "drop", frame: "#FFE3CC", glyph: "🐾", cells: five(["dock", "swiss-house", "mountain-lake", "leaning-palm", "bali-temple"], [0]) },
];

export const AdVibes: React.FC = () => (
  <AbsoluteFill style={{ fontFamily, background: "#000" }}>
    <Sequence durationInFrames={B.beach + 8} name="Party: bounce">
      <Party />
    </Sequence>
    <Sequence durationInFrames={B.date + 8} name="Beach: glide">
      <Beach />
    </Sequence>
    <Sequence durationInFrames={B.trips + 8} name="Date night: pop">
      <DateNight />
    </Sequence>
    {FLASHES.map((x, i) => (
      <Sequence key={x.label} durationInFrames={(FLASHES[i + 1]?.from ?? B.n70) + 8} name={`Flash: ${x.label}`}>
        <Flash {...x} />
      </Sequence>
    ))}
    <Sequence durationInFrames={B.drop + 8} name="70+ templates wall">
      <Wall />
    </Sequence>
    <Sequence durationInFrames={B.name + 8} name="Photos + videos drop in">
      <DropIn />
    </Sequence>
    <Sequence name="End card">
      <End />
    </Sequence>
    <Subs />
    <Sequence from={VS} name="Voiceover">
      <Audio src={staticFile("audio/vo-motion-v6.mp3")} volume={1} />
    </Sequence>
    <Audio src={staticFile("audio/music.mp3")} name="Music" volume={(f) => interpolate(f, [0, 6, B.name, VIBES_TOTAL - 18, VIBES_TOTAL], [0, 0.2, 0.22, 0.3, 0], clamp)} />
  </AbsoluteFill>
);
