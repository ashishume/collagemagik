import React from "react";
import { Audio } from "@remotion/media";
import { AbsoluteFill, Easing, interpolate, Sequence, staticFile, useCurrentFrame } from "remotion";
import type { Caption } from "@remotion/captions";
import { C, clamp, fontFamily, SOFT } from "../ad/theme";
import { F } from "../ad4/fonts";
import { ZoomCaptions } from "../ad5/Captions";
import { ip, POP, pulse, tapAt, Touch, type TouchP, win } from "../ad5/kit";
import raw from "../data/motion-b-words.json";
import { AppIcon, IPhone, NAME, popIn, StoreBadge } from "./kit";
import { DUMP } from "./MotionStage";
import { ADD_BTN, CameraRoll, cardPos, EditorScreen, HomeScreen, PickerSheet, tilePos } from "./Screens";

/**
 * Ad B, "Your weekend, in motion" (voiceover: public/audio/vo-motion-b.mp3, the "Sunny" voice). Warm, sunny theme.
 * A camera roll of 300 weekend photos, then the Photo dump motion template: photos and videos picked together drop in
 * as prints and glide into a neat collage by themselves, the clips still playing inside; exported to Photos.
 */
const WORDS = raw as Caption[];
const VS = 6;
const at = (s: number) => VS + Math.round(s * 30);
export const SUNNY_TOTAL = at(21.79) + 36;

const B = {
  n300: at(0.18),
  from: at(1.37),
  weekend: at(2.0),
  same: at(3.9),
  here: at(5.0),
  tap: at(6.3),
  template: at(7.09),
  mix: at(7.96),
  photos: at(8.34),
  videos: at(9.0),
  watch: at(9.77),
  glide: at(10.47),
  themselves: at(12.01),
  yourVideos: at(13.18),
  no: at(15.38),
  stress: at(16.9),
  name: at(18.18),
  your: at(19.68),
  weekend2: at(20.06),
  in: at(20.86),
  motion: at(20.93),
};
const HOME = B.here - 4;
const PICKER = B.template + 10;
const PICKS = [
  { i: 5, at: B.photos - 8 },
  { i: 6, at: B.photos },
  { i: 8, at: B.photos + 8 },
  { i: 1, at: B.videos },
  { i: 7, at: B.videos + 8 },
];
const ADD_AT = B.watch - 9;
const EDITOR = B.watch - 7;
const EXPORT_AT = B.no + 22;
const END = B.name;

const CORAL = "#FF7A59";
const SUN = "#FFC23D";

const SunnyBackground: React.FC = () => {
  const f = useCurrentFrame();
  const beat = Math.max(pulse(f, B.same, 14), pulse(f, B.glide, 14), pulse(f, B.name, 14));
  return (
    <AbsoluteFill style={{ background: "linear-gradient(170deg, #FFF1D6 0%, #FFE0EA 52%, #E8DEFF 100%)", overflow: "hidden" }}>
      {/* the sun */}
      <div style={{ position: "absolute", right: -220, top: -240, width: 760, height: 760, rotate: `${f * 0.4}deg` }}>
        {Array.from({ length: 16 }).map((_, i) => (
          <div key={i} style={{ position: "absolute", left: 370, top: 0, width: 20, height: 380, transformOrigin: "50% 100%", rotate: `${i * 22.5}deg`, background: "linear-gradient(0deg, rgba(255,194,61,0.35), transparent)", borderRadius: 10 }} />
        ))}
      </div>
      <div style={{ position: "absolute", right: 0, top: -20, width: 280 + 30 * beat, height: 280 + 30 * beat, borderRadius: "50%", background: `radial-gradient(circle, #FFE08A, ${SUN})`, boxShadow: "0 0 120px rgba(255,194,61,0.8)", translate: `${80 - 15 * beat}px ${-60 - 15 * beat}px` }} />
      {/* soft blobs */}
      {[
        { c: "#FFC7D9", x: 0.1, y: 0.55, r: 700 },
        { c: "#CDE8FF", x: 0.9, y: 0.8, r: 760 },
        { c: "#FFE2B0", x: 0.2, y: 0.95, r: 600 },
      ].map((b, i) => (
        <div key={i} style={{ position: "absolute", left: b.x * 1080 - b.r / 2 + Math.sin(f / 40 + i) * 60, top: b.y * 1920 - b.r / 2 + Math.cos(f / 50 + i) * 70, width: b.r, height: b.r, borderRadius: "50%", background: b.c, filter: "blur(90px)", opacity: 0.8 }} />
      ))}
      {/* confetti */}
      {Array.from({ length: 18 }).map((_, i) => {
        const x = (i * 211) % 1080;
        const y = ((i * 389 + f * (2 + (i % 3))) % 2100) - 100;
        const col = [CORAL, C.purple, SUN, C.teal, C.pink][i % 5];
        return <div key={i} style={{ position: "absolute", left: x + Math.sin(f / 20 + i) * 30, top: y, width: i % 3 ? 16 : 22, height: i % 3 ? 26 : 22, borderRadius: i % 3 ? 4 : 11, background: col, opacity: 0.55, rotate: `${f * (2 + (i % 4)) + i * 30}deg` }} />;
      })}
    </AbsoluteFill>
  );
};

const Headline: React.FC<{ from: number; to: number; children: React.ReactNode; top?: number; size?: number; tilt?: number }> = ({ from, to, children, top = 130, size = 76, tilt = 0 }) => {
  const f = useCurrentFrame();
  const a = popIn(f, from, to, 10);
  if (a.o <= 0) return null;
  return (
    <div style={{ position: "absolute", left: 0, right: 0, top, display: "flex", justifyContent: "center", opacity: a.o, scale: String(0.6 + 0.4 * a.s), rotate: `${tilt}deg` }}>
      <div style={{ fontFamily, fontWeight: 800, fontSize: size, color: C.ink, letterSpacing: -1.5, textAlign: "center", lineHeight: 1.05 }}>{children}</div>
    </div>
  );
};

const Sticker: React.FC<{ from: number; to: number; children: React.ReactNode; top: number; bg?: string; color?: string; tilt?: number; size?: number }> = ({ from, to, children, top, bg = "#fff", color = C.ink, tilt = -3, size = 58 }) => {
  const f = useCurrentFrame();
  const a = popIn(f, from, to, 11);
  if (a.o <= 0) return null;
  const wob = Math.sin((f - from) / 6) * 2 * (1 - ip(f, from, from + 30));
  return (
    <div style={{ position: "absolute", left: 0, right: 0, top, display: "flex", justifyContent: "center", opacity: a.o, scale: String(0.4 + 0.6 * a.s), rotate: `${tilt + wob}deg` }}>
      <div style={{ padding: "20px 42px", borderRadius: 50, background: bg, color, fontFamily, fontWeight: 800, fontSize: size, boxShadow: "0 14px 34px rgba(120,60,40,0.22)", border: "4px solid #fff", whiteSpace: "nowrap" }}>{children}</div>
    </div>
  );
};

const grad = (a: string, b: string): React.CSSProperties => ({ background: `linear-gradient(90deg, ${a}, ${b})`, WebkitBackgroundClip: "text", backgroundClip: "text", color: "transparent" });

// ------------------------------------------------------------------ the phone

const PHONE_W = 600;
const PHONE_TOP = 330;

const PhoneStage: React.FC = () => {
  const f = useCurrentFrame();
  const enter = ip(f, 0, 16, 0, 1, POP);
  const endT = ip(f, END - 4, END + 18, 0, 1, SOFT);
  const w = PHONE_W - 180 * endT;
  const top = PHONE_TOP + (1 - enter) * 900 + 490 * endT;
  const push = win(f, B.yourVideos - 6, B.no - 4, 12);
  const beat = Math.max(pulse(f, B.same, 12), 0.7 * pulse(f, B.glide, 14), 0.5 * pulse(f, B.themselves, 14));
  const scroll = interpolate(f, [0, B.n300, B.same - 6, B.same + 4], [0, 0, 5200, 5260], { ...clamp, easing: Easing.inOut(Easing.quad) });
  const count = Math.round(ip(f, B.n300, B.weekend + 6, 0, 300, Easing.out(Easing.cubic)));
  const blurRoll = ip(f, B.same, B.same + 6) * 6;

  const screen = f < HOME ? "roll" : f < PICKER - 4 ? "home" : f < EDITOR ? "picker" : "editor";
  const touches: TouchP[] = [];
  const add = (t: TouchP | null) => t && touches.push(t);
  const card = cardPos(1);
  // the finger drifts in on "the trick", then taps Photo dump
  if (f >= B.here + 10 && f < B.template - 12) touches.push({ x: 260 - 50 * ip(f, B.here + 10, B.template - 14), y: 420 - 160 * ip(f, B.here + 10, B.template - 14, 0, 1, SOFT), o: win(f, B.here + 10, B.template - 12, 6), down: false });
  add(tapAt(f, B.template - 6, card.x + card.w / 2, card.y + card.h / 2));
  PICKS.forEach((p) => {
    const t = tilePos(p.i);
    add(tapAt(f, p.at, t.x + t.s / 2, t.y + t.s / 2));
  });
  add(tapAt(f, ADD_AT, ADD_BTN.x, ADD_BTN.y));
  add(tapAt(f, EXPORT_AT - 4, 400 - 16 - 37, 76));
  const ring = (p: number) => (DUMP.pics[p].v ? win(f, B.yourVideos - 2, B.no - 2, 6) : 0);

  return (
    <div style={{ position: "absolute", left: 540 - w / 2, top, rotate: `${(1 - enter) * -10 + (screen === "roll" ? -2 * (1 - ip(f, B.same, B.here)) : 0)}deg`, scale: String(1 + 0.03 * beat + 0.09 * push), transformOrigin: "50% 38%" }}>
      <IPhone width={w} glow="rgba(160,70,60,0.32)">
        {screen === "roll" ? (
          <div style={{ position: "absolute", inset: 0, filter: `blur(${blurRoll}px)` }}>
            <CameraRoll scroll={scroll} count={count} />
          </div>
        ) : null}
        {screen === "home" || screen === "picker" ? <HomeScreen f={f} light tap={{ i: 1, at: B.template - 6 }} /> : null}
        {screen === "picker" ? <PickerSheet f={f} at={PICKER} picks={PICKS} addAt={ADD_AT} light /> : null}
        {screen === "editor" ? <EditorScreen f={f} d={DUMP} name="Photo dump" playFrom={EDITOR} length={110} ring={ring} exportAt={EXPORT_AT} /> : null}
        {touches.map((t, i) => (
          <Touch key={i} {...t} />
        ))}
      </IPhone>
    </div>
  );
};

// ------------------------------------------------------------------ end card

const EndCard: React.FC = () => {
  const f = useCurrentFrame();
  const icon = popIn(f, END, Infinity, 12);
  const name = popIn(f, END + 4, Infinity, 12);
  const badge = popIn(f, B.your + 10, Infinity, 12);
  const chip = popIn(f, B.your + 18, Infinity, 12);
  const words: [string, number][] = [
    ["Your", B.your],
    ["weekend,", B.weekend2],
    ["in", B.in],
    ["motion.", B.motion + 2],
  ];
  return (
    <AbsoluteFill>
      <div style={{ position: "absolute", left: 0, right: 0, top: 100, display: "flex", flexDirection: "column", alignItems: "center" }}>
        <div style={{ opacity: icon.o, scale: String(icon.s), rotate: `${(1 - icon.s) * 20}deg` }}>
          <AppIcon size={170} />
        </div>
        <div style={{ marginTop: 24, opacity: name.o, scale: String(0.7 + 0.3 * name.s), fontFamily, fontWeight: 800, fontSize: 104, color: C.ink, letterSpacing: -2 }}>{NAME}</div>
        <div style={{ marginTop: 0, display: "flex", gap: 20, alignItems: "baseline" }}>
          {words.map(([w, t], i) => {
            const a = popIn(f, t, Infinity, 9);
            return (
              <div key={w} style={{ opacity: a.o, scale: String(0.5 + 0.5 * a.s), translate: `0 ${(1 - a.s) * 30}px`, fontFamily: i === 3 ? F.hand : fontFamily, fontWeight: 800, fontSize: i === 3 ? 108 : 70, ...(i === 3 ? grad(CORAL, C.pink) : { color: C.ink }) }}>
                {w}
              </div>
            );
          })}
        </div>
        <div style={{ marginTop: 24, opacity: badge.o, scale: String(0.7 + 0.3 * badge.s) }}>
          <StoreBadge u={1.05} />
        </div>
      </div>
      <div style={{ position: "absolute", left: 0, right: 0, top: 1795, display: "flex", justifyContent: "center", opacity: chip.o, scale: String(0.7 + 0.3 * chip.s) }}>
        <div style={{ padding: "16px 34px", borderRadius: 40, background: "#fff", color: C.ink, fontFamily, fontWeight: 800, fontSize: 38, boxShadow: "0 10px 26px rgba(120,60,40,0.18)" }}>📷 Photos + 🎬 videos · free motion templates</div>
      </div>
    </AbsoluteFill>
  );
};

const Shift: React.FC<{ by: number; children: React.ReactNode }> = ({ by, children }) => (
  <Sequence from={-by} layout="none">
    {children}
  </Sequence>
);

export const AdSunny: React.FC = () => (
  <AbsoluteFill style={{ fontFamily }}>
    <SunnyBackground />
    <Sequence name="iPhone: camera roll, template, picker, editor, export">
      <PhoneStage />
    </Sequence>
    <Sequence name="Headlines">
      <Headline from={B.n300} to={B.same - 4} top={88} size={150}>
        <Counter /> photos
      </Headline>
      <Headline from={B.from} to={B.same - 4} top={262} size={62}>
        from one weekend? 😵‍💫
      </Headline>
      <Sticker from={B.same} to={B.here - 2} top={150} bg={SUN} tilt={-5} size={96}>
        Same. 😅
      </Sticker>
      <Headline from={B.here} to={B.tap - 2} top={150}>
        Here's the trick <span style={grad(C.purple, C.pink)}>✨</span>
      </Headline>
      <Sticker from={B.tap} to={B.mix - 2} top={160}>
        👆 Tap a motion template
      </Sticker>
      <Sticker from={B.mix} to={EDITOR} top={160} tilt={2}>
        📷 Photos <span style={{ color: CORAL }}>+</span> 🎬 Videos
      </Sticker>
      <Headline from={EDITOR + 2} to={B.yourVideos - 4} top={130} size={80}>
        They <span style={grad(CORAL, C.purple)}>glide into place</span>
        <br />
        <span style={{ fontSize: 54, opacity: 0.75 }}>all by themselves</span>
      </Headline>
      <Sticker from={B.yourVideos} to={B.no - 2} top={160} bg={C.ink} color="#fff" tilt={-2}>
        <span style={{ color: "#ff5a7a" }}>●</span> Videos keep playing
      </Sticker>
      <Sticker from={B.no} to={END - 4} top={110} bg={C.teal} color="#fff" tilt={-3} size={54}>
        ✓ No editing skills
      </Sticker>
      <Sticker from={B.stress} to={END - 4} top={210} bg={CORAL} color="#fff" tilt={3} size={54}>
        ✓ No stress
      </Sticker>
    </Sequence>
    <Sequence from={END} name="End card">
      <Shift by={END}>
        <EndCard />
      </Shift>
    </Sequence>
    <Sequence durationInFrames={END} name="Subtitles">
      <ZoomCaptions voiceStart={VS} words={WORDS} />
    </Sequence>
    <Sequence from={VS} name="Voiceover">
      <Audio src={staticFile("audio/vo-motion-b.mp3")} volume={1} />
    </Sequence>
    <Audio src={staticFile("audio/music.mp3")} name="Music" volume={(f) => interpolate(f, [0, 8, END, SUNNY_TOTAL - 20, SUNNY_TOTAL], [0, 0.2, 0.22, 0.3, 0], clamp)} />
  </AbsoluteFill>
);

/** 0 -> 300 as the camera roll flies by. */
const Counter: React.FC = () => {
  const f = useCurrentFrame();
  return <span style={grad(CORAL, C.pink)}>{Math.round(ip(f, B.n300, B.weekend + 6, 0, 300, Easing.out(Easing.cubic)))}</span>;
};
