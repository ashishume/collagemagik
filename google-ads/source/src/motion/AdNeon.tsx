import React from "react";
import { Audio } from "@remotion/media";
import { AbsoluteFill, Img, interpolate, Sequence, staticFile, useCurrentFrame } from "remotion";
import type { Caption } from "@remotion/captions";
import { clamp, fontFamily, SOFT } from "../ad/theme";
import { F } from "../ad4/fonts";
import { ZoomCaptions } from "../ad5/Captions";
import { ip, POP, pulse, tapAt, Touch, type TouchP, win } from "../ad5/kit";
import raw from "../data/motion-a-words.json";
import { AppIcon, IPhone, NAME, popIn, StoreBadge } from "./kit";
import { NEON } from "./MotionStage";
import { ADD_BTN, cardPos, EditorScreen, HomeScreen, PickerSheet, tilePos } from "./Screens";

/**
 * Ad A, "Make it move" (voiceover: public/audio/vo-motion-a.mp3, the "Hope" voice). Neon night theme.
 * Still photos shatter, then the Neon nights motion template plays in an iPhone: zoom, slide, pop on the spoken words,
 * with the two video clips playing inside the collage.
 */
const WORDS = raw as Caption[];
const VS = 6;
const at = (s: number) => VS + Math.round(s * 30);
export const NEON_TOTAL = at(16.12) + 36;

// beats, from the voiceover's word timings (src/data/motion-a-words.json)
const B = {
  your: at(0.07),
  kinda: at(1.27),
  still: at(2.54),
  not: at(3.04),
  pick: at(4.46),
  template: at(5.17),
  drop: at(5.96),
  photos: at(6.51),
  videos: at(7.12),
  boom: at(7.64),
  zoom: at(9.17),
  slide: at(9.98),
  pop: at(10.94),
  clips: at(11.73),
  name: at(13.14),
  make: at(14.73),
};
const EDITOR = B.boom;
const PICKER = B.template + 12;
const PICKS = [
  { i: 0, at: B.photos - 14 },
  { i: 2, at: B.photos - 6 },
  { i: 4, at: B.photos + 2 },
  { i: 1, at: B.videos - 4 },
  { i: 3, at: B.videos + 4 },
];
const ADD_AT = B.boom - 6;

const PINK = "#FF3D8B";
const VIOLET = "#8B5CFF";
const CYAN = "#3DE0FF";
const neon = (c: string, u: number) => `0 0 ${10 * u}px ${c}, 0 0 ${30 * u}px ${c}, 0 0 ${70 * u}px ${c}`;

const BEATS = [B.not, B.boom, B.zoom, B.slide, B.pop, B.name];

const NeonBackground: React.FC = () => {
  const f = useCurrentFrame();
  const beat = Math.max(...BEATS.map((b) => pulse(f, b, 16)));
  const t = f / 30;
  const blobs = [
    { c: VIOLET, x: 0.2, y: 0.25, r: 0.9, sp: 0.5 },
    { c: PINK, x: 0.85, y: 0.55, r: 0.8, sp: 0.4 },
    { c: "#2a4bff", x: 0.3, y: 0.9, r: 0.8, sp: 0.35 },
  ];
  return (
    <AbsoluteFill style={{ background: "radial-gradient(ellipse at 50% 40%, #1a0b33 0%, #08040f 70%)", overflow: "hidden" }}>
      {blobs.map((b, i) => (
        <div
          key={i}
          style={{
            position: "absolute",
            width: 1080 * b.r,
            height: 1080 * b.r,
            left: 1080 * b.x - 540 * b.r + Math.sin(t * b.sp + i * 2) * 120,
            top: 1920 * b.y - 540 * b.r + Math.cos(t * b.sp * 1.2 + i) * 160,
            borderRadius: "50%",
            background: b.c,
            filter: "blur(160px)",
            opacity: 0.32 + 0.25 * beat,
          }}
        />
      ))}
      {/* perspective grid floor */}
      <div style={{ position: "absolute", left: -540, right: -540, bottom: -200, height: 900, transform: "perspective(600px) rotateX(62deg)", transformOrigin: "50% 100%", opacity: 0.35 + 0.3 * beat }}>
        <div
          style={{
            position: "absolute",
            inset: 0,
            backgroundImage: `linear-gradient(${VIOLET} 2px, transparent 2px), linear-gradient(90deg, ${VIOLET} 2px, transparent 2px)`,
            backgroundSize: "90px 90px",
            backgroundPosition: `0 ${(f * 4) % 90}px`,
            maskImage: "linear-gradient(0deg, black 30%, transparent 100%)",
          }}
        />
      </div>
      {/* light streaks */}
      {[0, 1, 2, 3].map((i) => {
        const x = ((f * (9 + i * 3) + i * 400) % 2200) - 600;
        return <div key={i} style={{ position: "absolute", left: x, top: 200 + i * 430, width: 420, height: 3, background: `linear-gradient(90deg, transparent, ${i % 2 ? CYAN : PINK}, transparent)`, opacity: 0.6, rotate: "-18deg" }} />;
      })}
      {/* sparkles */}
      {Array.from({ length: 14 }).map((_, i) => {
        const x = (i * 263) % 1080;
        const y = (i * 557 + f * (1 + (i % 3))) % 1920;
        return <div key={i} style={{ position: "absolute", left: x, top: 1920 - y, fontSize: 18 + (i % 3) * 10, color: [PINK, CYAN, "#fff", VIOLET][i % 4], opacity: 0.4 + 0.4 * Math.sin(f / 9 + i) }}>✦</div>;
      })}
      <AbsoluteFill style={{ background: "#fff", opacity: Math.max(pulse(f, B.not, 8), pulse(f, B.boom, 8)) * 0.55 }} />
    </AbsoluteFill>
  );
};

const NeonText: React.FC<{ children: React.ReactNode; size: number; color?: string; glow?: string; style?: React.CSSProperties }> = ({ children, size, color = "#fff", glow = PINK, style }) => (
  <div style={{ fontFamily: F.poster, fontSize: size, color, textShadow: neon(glow, 1), letterSpacing: 2, lineHeight: 1, textTransform: "uppercase", whiteSpace: "nowrap", ...style }}>{children}</div>
);

// ------------------------------------------------------------------ hook: still photos, then they shatter

const STILLS = ["santorini-sunset", "aurora-reine", "positano", "balloons", "venice-rialto", "turquoise"] as const;

const Hook: React.FC = () => {
  const f = useCurrentFrame();
  const grey = ip(f, B.still - 4, B.still + 6);
  const shatter = ip(f, B.not, B.not + 22, 0, 1, SOFT);
  const show = 1 - ip(f, B.not + 14, B.not + 24);
  const appear = ip(f, 0, 12);
  const W = 780;
  const H = 975;
  const cells: [number, number, number, number][] = [
    [0, 0, 0.5, 0.4],
    [0.5, 0, 0.5, 0.4],
    [0, 0.4, 0.34, 0.3],
    [0.34, 0.4, 0.66, 0.3],
    [0, 0.7, 0.6, 0.3],
    [0.6, 0.7, 0.4, 0.3],
  ];
  const l1 = popIn(f, B.your, B.kinda - 4);
  const l2 = popIn(f, B.kinda, B.not - 2);
  const stillW = popIn(f, B.still, B.not - 2);
  return (
    <AbsoluteFill>
      <div style={{ position: "absolute", left: 540 - W / 2, top: 560, width: W, height: H, opacity: show * appear, scale: String(0.94 + 0.06 * appear) }}>
        {cells.map((c, i) => {
          const dx = (c[0] + c[2] / 2 - 0.5) * 2;
          const dy = (c[1] + c[3] / 2 - 0.5) * 2;
          return (
            <div
              key={i}
              style={{
                position: "absolute",
                left: c[0] * W + 6,
                top: c[1] * H + 6,
                width: c[2] * W - 12,
                height: c[3] * H - 12,
                borderRadius: 14,
                overflow: "hidden",
                translate: `${dx * 900 * shatter}px ${dy * 1100 * shatter}px`,
                rotate: `${(i % 2 ? 1 : -1) * 70 * shatter}deg`,
                scale: String(1 + 0.4 * shatter),
              }}
            >
              <Img src={staticFile(`travel/${STILLS[i]}.jpg`)} style={{ width: "100%", height: "100%", objectFit: "cover", filter: `grayscale(${0.35 + 0.65 * grey}) brightness(${1 - 0.25 * grey})` }} />
            </div>
          );
        })}
        <div style={{ position: "absolute", left: W / 2 - 70, top: H / 2 - 70, width: 140, height: 140, borderRadius: 70, background: "rgba(0,0,0,0.6)", color: "#fff", fontSize: 60, textAlign: "center", lineHeight: "140px", opacity: grey * (1 - shatter), scale: String(ip(f, B.still - 2, B.still + 10, 0.5, 1, POP)) }}>
          ❚❚
        </div>
      </div>
      <div style={{ position: "absolute", top: 210, left: 0, right: 0, display: "flex", flexDirection: "column", alignItems: "center", gap: 20 }}>
        <div style={{ opacity: l1.o, scale: String(l1.s), fontFamily, fontWeight: 800, fontSize: 96, color: "#fff" }}>Your photos?</div>
        <div style={{ position: "absolute", top: 0, opacity: l2.o, scale: String(l2.s), fontFamily, fontWeight: 800, fontSize: 96, color: "rgba(255,255,255,0.75)" }}>
          Kinda… <span style={{ opacity: stillW.o, color: "#9a95a8", fontStyle: "italic" }}>still.</span>
        </div>
      </div>
      <NotAnymore />
    </AbsoluteFill>
  );
};

const NotAnymore: React.FC = () => {
  const f = useCurrentFrame();
  const a = popIn(f, B.not, B.pick - 8, 8);
  const shake = f >= B.not && f < B.not + 14 ? Math.sin(f * 3.3) * 14 * (1 - (f - B.not) / 14) : 0;
  if (a.o <= 0) return null;
  const line = (txt: string, c: string, off: number) => (
    <div style={{ position: "absolute", left: 0, right: 0, top: 0, textAlign: "center" }}>
      <NeonText size={190} color={c} glow={c} style={{ translate: `${off}px 0`, opacity: off ? 0.55 : 1, mixBlendMode: off ? "screen" : undefined }}>
        {txt}
      </NeonText>
    </div>
  );
  return (
    <div style={{ position: "absolute", left: 0, right: 0, top: 120, height: 420, opacity: a.o, scale: String(0.6 + 0.4 * a.s), translate: `${shake}px 0` }}>
      <div style={{ position: "relative", height: 200 }}>
        {line("NOT", CYAN, -8 * pulse(f, B.not, 10))}
        {line("NOT", PINK, 8 * pulse(f, B.not, 10))}
        {line("NOT", "#fff", 0)}
      </div>
      <div style={{ position: "relative", height: 200 }}>
        {line("ANYMORE", "#fff", 0)}
      </div>
    </div>
  );
};

// ------------------------------------------------------------------ the phone

const PHONE_W = 600;
const PHONE_TOP = 300;
const END = B.name;

const PhoneStage: React.FC = () => {
  const f = useCurrentFrame();
  const enter = ip(f, B.not + 12, B.pick, 0, 1, POP);
  const endT = ip(f, END - 4, END + 18, 0, 1, SOFT);
  const w = PHONE_W - 180 * endT;
  const top = PHONE_TOP + (1 - enter) * 1500 + 520 * endT;
  const beat = Math.max(pulse(f, B.boom, 14), 0.6 * pulse(f, B.zoom, 12), 0.6 * pulse(f, B.slide, 12), 0.6 * pulse(f, B.pop, 12));
  const push = win(f, B.clips - 6, END - 6, 10);
  const shake = f >= B.boom && f < B.boom + 12 ? Math.sin(f * 2.7) * 10 * (1 - (f - B.boom) / 12) : 0;
  const rot = (1 - enter) * 12;

  const screen = f < PICKER - 4 ? "home" : f < EDITOR ? "picker" : "editor";
  const touches: TouchP[] = [];
  const push2 = (t: TouchP | null) => t && touches.push(t);
  const card = cardPos(0);
  push2(tapAt(f, B.template - 6, card.x + card.w / 2, card.y + card.h / 2));
  PICKS.forEach((p) => {
    const t = tilePos(p.i);
    push2(tapAt(f, p.at, t.x + t.s / 2, t.y + t.s / 2));
  });
  push2(tapAt(f, ADD_AT, ADD_BTN.x, ADD_BTN.y));
  const ring = (p: number) => (NEON.pics[p].v ? win(f, B.clips - 4, END - 4, 6) : 0);

  return (
    <div style={{ position: "absolute", left: 540 - w / 2 + shake, top, rotate: `${rot}deg`, scale: String(1 + 0.035 * beat + 0.08 * push), transformOrigin: "50% 40%" }}>
      <IPhone width={w} glow={`rgba(139,92,255,${0.45 + 0.35 * beat})`}>
        {screen === "home" || screen === "picker" ? <HomeScreen f={f} tap={{ i: 0, at: B.template - 6 }} /> : null}
        {screen === "picker" ? <PickerSheet f={f} at={PICKER} picks={PICKS} addAt={ADD_AT} /> : null}
        {screen === "editor" ? <EditorScreen f={f} d={NEON} name="Neon nights" playFrom={EDITOR} length={END - EDITOR + 30} ring={ring} /> : null}
        {touches.map((t, i) => (
          <Touch key={i} {...t} />
        ))}
      </IPhone>
    </div>
  );
};

// ------------------------------------------------------------------ words around the phone

const Beat: React.FC<{ from: number; to: number; text: string; color: string; size?: number; tilt?: number }> = ({ from, to, text, color, size = 170, tilt = -4 }) => {
  const f = useCurrentFrame();
  const a = popIn(f, from, to, 9);
  if (a.o <= 0) return null;
  return (
    <div style={{ position: "absolute", left: 0, right: 0, top: 95, textAlign: "center", opacity: a.o, scale: String(0.4 + 0.6 * a.s), rotate: `${tilt}deg` }}>
      <NeonText size={size} glow={color}>
        {text}
      </NeonText>
    </div>
  );
};

const Steps: React.FC = () => {
  const f = useCurrentFrame();
  const s1 = popIn(f, B.pick, B.drop - 4);
  const s2 = popIn(f, B.drop, B.boom - 2);
  const chip = (txt: React.ReactNode, a: { o: number; s: number }) => (
    <div style={{ position: "absolute", left: 0, right: 0, top: 150, display: "flex", justifyContent: "center", opacity: a.o, scale: String(0.7 + 0.3 * a.s) }}>
      <div style={{ padding: "22px 44px", borderRadius: 60, background: "rgba(255,255,255,0.08)", border: `3px solid ${VIOLET}`, boxShadow: `0 0 30px ${VIOLET}`, color: "#fff", fontFamily, fontWeight: 800, fontSize: 56 }}>{txt}</div>
    </div>
  );
  return (
    <>
      {chip(<>✨ Pick a motion template</>, s1)}
      {chip(
        <>
          📷 Photos <span style={{ color: PINK }}>+</span> 🎬 Videos
        </>,
        s2,
      )}
    </>
  );
};

const ClipsCallout: React.FC = () => {
  const f = useCurrentFrame();
  const a = popIn(f, B.clips - 6, END - 4);
  if (a.o <= 0) return null;
  return (
    <div style={{ position: "absolute", left: 0, right: 0, top: 120, display: "flex", justifyContent: "center", opacity: a.o, scale: String(0.6 + 0.4 * a.s) }}>
      <div style={{ padding: "24px 48px", borderRadius: 60, background: "#F4B23C", color: "#1E1438", fontFamily, fontWeight: 800, fontSize: 60, boxShadow: "0 0 50px rgba(244,178,60,0.8)", display: "flex", alignItems: "center", gap: 18 }}>
        <span style={{ color: "#E0457B" }}>●</span> Videos play inside
      </div>
    </div>
  );
};

// ------------------------------------------------------------------ end card

const EndCard: React.FC = () => {
  const f = useCurrentFrame();
  const icon = popIn(f, END, Infinity, 12);
  const name = popIn(f, END + 4, Infinity, 12);
  const words = ["Make", "your", "memories", "move."];
  const wordAt = [B.make, B.make + 3, at(15.06), at(15.56)];
  const badge = popIn(f, B.make + 6, Infinity, 12);
  const chip = popIn(f, B.make + 14, Infinity, 12);
  return (
    <AbsoluteFill>
      <div style={{ position: "absolute", left: 0, right: 0, top: 110, display: "flex", flexDirection: "column", alignItems: "center" }}>
        <div style={{ opacity: icon.o, scale: String(icon.s), rotate: `${(1 - icon.s) * -20}deg` }}>
          <AppIcon size={170} />
        </div>
        <div style={{ marginTop: 26, opacity: name.o, scale: String(0.7 + 0.3 * name.s), fontFamily, fontWeight: 800, fontSize: 104, color: "#fff", letterSpacing: -2, textShadow: neon(VIOLET, 0.7) }}>{NAME}</div>
        <div style={{ marginTop: 6, display: "flex", gap: 22 }}>
          {words.map((w, i) => {
            const a = popIn(f, wordAt[i], Infinity, 8);
            return (
              <div key={w} style={{ opacity: a.o, scale: String(0.5 + 0.5 * a.s), translate: `0 ${(1 - a.s) * 30}px` }}>
                <NeonText size={84} glow={i === 3 ? PINK : VIOLET} color={i === 3 ? "#FFD3E6" : "#fff"}>
                  {w}
                </NeonText>
              </div>
            );
          })}
        </div>
        <div style={{ marginTop: 34, opacity: badge.o, scale: String(0.7 + 0.3 * badge.s) }}>
          <StoreBadge u={1.05} />
        </div>
      </div>
      <div style={{ position: "absolute", left: 0, right: 0, top: 1795, display: "flex", justifyContent: "center", opacity: chip.o, scale: String(0.7 + 0.3 * chip.s) }}>
        <div style={{ padding: "16px 34px", borderRadius: 40, background: "rgba(255,255,255,0.1)", border: `2px solid ${CYAN}`, color: "#fff", fontFamily, fontWeight: 800, fontSize: 38 }}>Photos + videos · 18 free motion templates</div>
      </div>
    </AbsoluteFill>
  );
};

export const AdNeon: React.FC = () => (
  <AbsoluteFill style={{ fontFamily, background: "#08040f" }}>
    <NeonBackground />
    <Sequence durationInFrames={B.pick + 4} name="Hook: still photos -> not anymore">
      <Hook />
    </Sequence>
    <Sequence from={B.not} name="iPhone: template, picker, editor">
      <PhoneStageAt from={B.not} />
    </Sequence>
    <Sequence name="Step chips">
      <Steps />
    </Sequence>
    <Beat from={B.boom} to={B.zoom - 4} text="Boom!" color={PINK} size={200} tilt={-5} />
    <Beat from={B.zoom} to={B.slide - 3} text="Zoom" color={CYAN} tilt={4} />
    <Beat from={B.slide} to={B.pop - 3} text="Slide" color={VIOLET} tilt={-3} />
    <Beat from={B.pop} to={B.clips - 8} text="Pop!" color={PINK} size={200} tilt={5} />
    <ClipsCallout />
    <Sequence from={END} name="End card">
      <EndCardAt from={END} />
    </Sequence>
    <Sequence durationInFrames={END} name="Subtitles">
      <ZoomCaptions voiceStart={VS} words={WORDS} />
    </Sequence>
    <Sequence from={VS} name="Voiceover">
      <Audio src={staticFile("audio/vo-motion-a.mp3")} volume={1} />
    </Sequence>
    <Audio src={staticFile("audio/music.mp3")} name="Music" volume={(f) => interpolate(f, [0, 8, B.boom - 2, B.boom + 4, END, NEON_TOTAL - 20, NEON_TOTAL], [0, 0.2, 0.2, 0.3, 0.26, 0.3, 0], clamp)} />
  </AbsoluteFill>
);

/** Sequences reset the frame; these wrappers give the components the ad's own frame back. */
const PhoneStageAt: React.FC<{ from: number }> = ({ from }) => <Shift by={from}><PhoneStage /></Shift>;
const EndCardAt: React.FC<{ from: number }> = ({ from }) => <Shift by={from}><EndCard /></Shift>;
const Shift: React.FC<{ by: number; children: React.ReactNode }> = ({ by, children }) => <Sequence from={-by} layout="none">{children}</Sequence>;
