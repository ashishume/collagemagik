import React from "react";
import { AbsoluteFill, Easing, Img, interpolate, staticFile, useCurrentFrame } from "remotion";
import { Air, AppBadge, Sticker, StoreButton } from "../ad/bits";
import { PHOTO_KINDS, PhotoKind, TripPhoto } from "../ad/TripPhoto";
import { AIR, APP_SUBTITLE, C, clamp, fontFamily, useLayout } from "../ad/theme";
import { WORDS, VOICE_START } from "./cues";
import { EditorPhone, editorPhoneHeight, FramedPhoto, ip, PHOTOS, POP, steps, StripContent, TOP_PHOTO, win } from "./Editor";
import { F } from "./fonts";
import { T } from "./timeline";

const P: React.FC<{ c: string; children: React.ReactNode; ff?: string }> = ({ c, children, ff }) => (
  <span style={{ color: c, fontFamily: ff ?? undefined, fontWeight: ff ? 400 : undefined }}>{children}</span>
);

/** Where the editor phone sits in each format. */
export const usePhoneSpot = () => {
  const { portrait, u, width, height, L } = useLayout();
  const w = portrait ? 620 * u : L.phoneW * 1.05;
  const h = editorPhoneHeight(w);
  const cx = portrait ? width / 2 : L.phoneCx;
  const top = portrait ? 300 * u : height / 2 - h / 2 - 16 * u;
  return { w, h, cx, top, cy: top + h / 2 };
};

// ---------------------------------------------------------------- hook

const PILE: { k: PhotoKind; x: number; y: number; r: number }[] = [
  { k: "santorini-sunset", x: -0.22, y: -0.12, r: -12 },
  { k: "palm-beach", x: 0.2, y: -0.16, r: 9 },
  { k: "aurora-reine", x: -0.16, y: 0.14, r: 7 },
  { k: "pizza", x: 0.22, y: 0.12, r: -8 },
  { k: "balloons", x: 0.0, y: -0.02, r: -4 },
  { k: "overwater", x: -0.04, y: 0.2, r: 13 },
  { k: "positano", x: 0.06, y: -0.22, r: -15 },
];

/** "Just got back from my trip!" Trip photos slam down one after another, and the words punch in. */
export const HookScene: React.FC = () => {
  const f = useCurrentFrame();
  const { portrait, square, u, width, height, L } = useLayout();
  const end = T.but + 10;
  if (f > end + 16) return null;
  const cx = portrait ? width / 2 : L.storyCx;
  const cy = portrait ? height * 0.56 : height / 2 + 30 * u;
  const spread = portrait ? 900 * u : 820 * u;
  const card = (portrait ? 440 : square ? 330 : 380) * u;
  const out = ip(f, end, end + 14, 0, 1, Easing.in(Easing.cubic));
  // a little camera shake on each slam
  const lastSlam = Math.max(...PILE.map((_, i) => (f >= 3 + i * 9 ? 3 + i * 9 : -99)));
  const shake = Math.max(0, 1 - (f - lastSlam) / 7) * 10 * u;
  const words = WORDS.slice(0, 6);
  const head = portrait ? { left: 60 * u, right: 60 * u, top: 150 * u, textAlign: "center" as const } : { left: L.leftX, top: (square ? 330 : 360) * u, width: square ? L.colW : 700 * u };
  return (
    <AbsoluteFill style={{ translate: `${Math.sin(f * 2.3) * shake}px ${Math.cos(f * 1.7) * shake}px` }}>
      {PILE.map((p, i) => {
        const at = 3 + i * 9;
        if (f < at) return null;
        const s = interpolate(f, [at, at + 7], [1.9, 1], { ...clamp, easing: Easing.out(Easing.cubic) });
        const o = ip(f, at, at + 3);
        return (
          <div
            key={p.k}
            style={{
              position: "absolute",
              left: cx + p.x * spread - card / 2 - out * (cx + p.x * spread - cx) * 0.6,
              top: cy + p.y * spread * (portrait ? 0.9 : 0.7) - card * 0.6 + out * 200 * u,
              rotate: `${p.r + (1 - s) * 20}deg`,
              scale: String(s * (1 - out * 0.4)),
              opacity: o * (1 - out),
              filter: `blur(${out * 10 * u}px)`,
            }}
          >
            <div style={{ background: "#fff", padding: `${12 * u}px ${12 * u}px ${44 * u}px`, borderRadius: 6 * u, boxShadow: `0 ${24 * u}px ${50 * u}px rgba(43,20,92,0.35)` }}>
              <TripPhoto kind={p.k} hd style={{ width: card, height: card }} />
            </div>
          </div>
        );
      })}
      {/* a flash on the first slams */}
      <AbsoluteFill style={{ background: "#fff", opacity: Math.max(0, 0.5 - (f - 3) / 10) * (f >= 3 ? 1 : 0), pointerEvents: "none" }} />
      <div style={{ position: "absolute", ...head, opacity: 1 - out, filter: `blur(${out * 12 * u}px)` }}>
        <div
          style={{
            display: "inline-block",
            fontFamily,
            fontWeight: 800,
            fontSize: (portrait ? 108 : square ? 84 : 110) * u,
            lineHeight: 1.0,
            color: C.ink,
            letterSpacing: -2 * u,
            padding: `${18 * u}px ${30 * u}px`,
            borderRadius: 34 * u,
            background: "rgba(255,255,255,0.88)",
            boxShadow: `0 ${20 * u}px ${50 * u}px rgba(43,20,92,0.22)`,
            textAlign: portrait ? "center" : "left",
          }}
        >
          {words.map((w, i) => {
            const at = VOICE_START + Math.round((w.startMs / 1000) * 30) - 2;
            const p = ip(f, at, at + 8, 0, 1, POP);
            const last = i === words.length - 1;
            return (
              <span key={i} style={{ display: "inline-block", marginRight: 22 * u, scale: String(p), opacity: Math.min(1, p * 2), color: last ? C.pink : C.ink }}>
                {w.text.replace("!", "")}
                {last ? " ✈️" : ""}
              </span>
            );
          })}
        </div>
      </div>
    </AbsoluteFill>
  );
};

/** The app badge across the story part, so the brand is on screen from the first second. */
export const IntroBadge: React.FC = () => {
  const { portrait, square, u, L } = useLayout();
  const f = useCurrentFrame();
  if (f > T.so + 20) return null;
  return (
    <div style={{ position: "absolute", left: 0, right: 0, top: (portrait ? 70 : 50) * u, display: "flex", justifyContent: portrait ? "center" : "flex-start", paddingLeft: portrait ? 0 : L.leftX }}>
      <AppBadge at={20} out={T.so} scale={portrait ? 1.0 : square ? 0.7 : 0.85} style={{ position: "relative" }} sub="Your trip, in one post" />
    </div>
  );
};

// ---------------------------------------------------------------- reveal

/** "So I made a collage in CollageMagik." Photos fly together into a collage, which becomes the app icon. */
export const RevealScene: React.FC = () => {
  const f = useCurrentFrame();
  const { u, width, height, portrait } = useLayout();
  const s = T.so;
  const snap = T.collage + 2;
  const name = T.name1;
  const leave = T.pick - 20;
  if (f < s - 4 || f > leave + 20) return null;
  const cx = width / 2;
  const cy = portrait ? height * 0.42 : height * 0.44;
  const W = (portrait ? 560 : 440) * u;
  const H = W * 1.25;
  const g = 10 * u;
  const cells = [
    { x: 0, y: 0, w: 0.6, h: 0.45 },
    { x: 0.6, y: 0, w: 0.4, h: 0.45 },
    { x: 0, y: 0.45, w: 0.4, h: 0.55 },
    { x: 0.4, y: 0.45, w: 0.6, h: 0.55 },
  ];
  const starts = [
    { x: -1.2, y: -0.9, r: -40 },
    { x: 1.3, y: -0.7, r: 35 },
    { x: -1.3, y: 0.9, r: 30 },
    { x: 1.2, y: 1.0, r: -30 },
  ];
  // the collage shrinks into the icon on the app name
  const toIcon = ip(f, name - 4, name + 10, 0, 1, Easing.inOut(Easing.cubic));
  const iconPop = interpolate(f, [name + 2, name + 14], [0.6, 1], { ...clamp, easing: POP });
  const up = ip(f, leave, leave + 12, 0, 1, Easing.in(Easing.cubic));
  const iconSize = 300 * u;
  const flash = Math.max(0, 1 - Math.abs(f - snap) / 5);
  const ring = ip(f, name + 4, name + 30);
  return (
    <AbsoluteFill style={{ opacity: 1 - up, translate: `0px ${-up * 260 * u}px`, filter: `blur(${up * 12 * u}px)` }}>
      <div style={{ position: "absolute", left: cx - W / 2, top: cy - H / 2, width: W, height: H, scale: String(1 - toIcon * (1 - iconSize / W)), opacity: 1 - ip(f, name + 4, name + 10) }}>
        <div style={{ position: "absolute", inset: 0, borderRadius: 24 * u + toIcon * 60 * u, background: "#fff", boxShadow: `0 ${30 * u}px ${70 * u}px rgba(43,20,92,0.3)`, opacity: ip(f, snap - 6, snap) }} />
        {cells.map((c, i) => {
          const at = T.made - 6 + i * 4;
          const t = ip(f, at, snap, 0, 1, Easing.inOut(Easing.cubic));
          const st = starts[i];
          const x = g + c.x * (W - g);
          const y = g + c.y * (H - g);
          return (
            <TripPhoto
              key={i}
              kind={PHOTOS[i]}
              hd
              style={{
                position: "absolute",
                left: x + (1 - t) * st.x * width * 0.5,
                top: y + (1 - t) * st.y * height * 0.4,
                width: c.w * (W - g) - g,
                height: c.h * (H - g) - g,
                borderRadius: 12 * u,
                rotate: `${(1 - t) * st.r}deg`,
                opacity: ip(f, at - 4, at + 2),
                boxShadow: t < 1 ? `0 ${20 * u}px ${40 * u}px rgba(43,20,92,0.35)` : undefined,
              }}
            />
          );
        })}
        <div style={{ position: "absolute", inset: 0, borderRadius: 24 * u, background: "#fff", opacity: flash * 0.8 }} />
      </div>
      {f >= name - 2 ? (
        <div style={{ position: "absolute", left: cx - iconSize / 2, top: cy - iconSize / 2 - ip(f, name + 10, leave) * 140 * u, width: iconSize, height: iconSize, scale: String(iconPop), opacity: ip(f, name - 2, name + 6) }}>
          <div style={{ position: "absolute", inset: -80 * u * ring, borderRadius: "50%", border: `${6 * u}px solid ${C.purple}`, opacity: (1 - ring) * 0.7 }} />
          <Img src={staticFile("brand/icon.png")} style={{ width: "100%", height: "100%", borderRadius: 70 * u, boxShadow: `0 ${30 * u}px ${70 * u}px rgba(109,79,214,0.5)` }} />
        </div>
      ) : null}
      <div style={{ position: "absolute", left: 0, right: 0, top: cy + iconSize / 2 + 30 * u - ip(f, name + 10, leave) * 140 * u, textAlign: "center" }}>
        <div style={{ display: "inline-block", fontFamily, fontWeight: 800, fontSize: 130 * u, color: C.ink, letterSpacing: interpolate(f, [name, name + 14], [30, -2], { ...clamp, easing: AIR }) * u, opacity: ip(f, name, name + 8), scale: String(interpolate(f, [name, name + 12], [1.3, 1], { ...clamp, easing: AIR })) }}>
          Collage<P c={C.purple}>Magik</P>
        </div>
      </div>
    </AbsoluteFill>
  );
};

// ---------------------------------------------------------------- editor phone + headlines

export const PhoneStage: React.FC = () => {
  const f = useCurrentFrame();
  const { u } = useLayout();
  const spot = usePhoneSpot();
  const enter = T.pick - 8;
  const exit = T.same;
  if (f < enter || f > exit + 24) return null;
  const rise = ip(f, enter, enter + 24);
  const leave = ip(f, exit, exit + 20, 0, 1, Easing.in(Easing.cubic));
  const zoom = steps(f, 1, [[T.drag1 - 4, 1.05], [T.drop - 4, 1.0], [T.twist - 8, 1.1], [T.add - 4, 1.03], [T.carousel - 4, 1.0], [T.exp - 6, 1.05]], 16);
  const burst = win(f, T.flows - 6, T.post - 8, 10);
  const bob = Math.sin(f / 40) * 6 * u;
  return (
    <div
      style={{
        position: "absolute",
        left: spot.cx - spot.w / 2,
        top: spot.top + bob + (1 - rise) * 700 * u - leave * 120 * u,
        perspective: 2400 * u,
        opacity: rise * (1 - leave) * (1 - burst * 0.55),
        filter: `blur(${burst * 5 * u + leave * 14 * u}px)`,
      }}
    >
      <div
        style={{
          transform: `rotateX(${(1 - rise) * 28}deg) rotateZ(${(1 - rise) * 6 + Math.sin(f / 70) * 0.8}deg)`,
          scale: String(zoom * (0.85 + 0.15 * rise) * (1 - burst * 0.08) * (1 - leave * 0.3)),
          transformOrigin: "50% 45%",
        }}
      >
        <EditorPhone width={spot.w} />
      </div>
    </div>
  );
};

const Headline: React.FC<{ at: number; out: number; children: React.ReactNode; center?: boolean }> = ({ at, out, children, center }) => {
  const f = useCurrentFrame();
  const { portrait, square, u, L } = useLayout();
  if (f < at - 2 || f > out + 16) return null;
  return (
    <Air
      inAt={at}
      outAt={out - 6}
      dur={14}
      from={portrait ? [0, 40] : [-60, 0]}
      style={
        portrait || center
          ? { position: "absolute", left: 50 * u, right: 50 * u, top: (portrait ? 120 : 70) * u, textAlign: "center" }
          : { position: "absolute", left: L.leftX, top: (square ? 190 : 250) * u, width: L.colW }
      }
    >
      <div style={{ fontFamily, fontWeight: 800, fontSize: (portrait ? 80 : center ? (square ? 64 : 84) : square ? 66 : 96) * u, lineHeight: 1.04, color: C.ink, letterSpacing: -1.5 * u }}>{children}</div>
    </Air>
  );
};

export const Headlines: React.FC = () => (
  <AbsoluteFill>
    <Headline at={T.pick - 8} out={T.drag1 - 4}>
      Pick a <P c={C.purple}>layout</P>
    </Headline>
    <Headline at={T.drag1 - 4} out={T.drag2 - 4}>
      Drag photos <P c={C.pink}>in</P>
    </Headline>
    <Headline at={T.drag2 - 4} out={T.hold - 4}>
      Drag borders to <P c={C.teal}>resize</P>
    </Headline>
    <Headline at={T.hold - 4} out={T.drop - 4}>
      Hold &amp; drag to <P c={C.coral}>swap</P>
    </Headline>
    <Headline at={T.drop - 4} out={T.give - 4}>
      Photo <P c={C.purple}>on top</P> of photo
    </Headline>
    <Headline at={T.give - 4} out={T.torn - 4}>
      Instant-photo <P c={C.pink}>frame</P>
    </Headline>
    <Headline at={T.torn - 4} out={T.twist - 6}>
      Torn <P c={C.coral}>paper</P> edge
    </Headline>
    <Headline at={T.twist - 6} out={T.click - 2}>
      Twist to <P c={C.blue}>rotate</P>
    </Headline>
    <Headline at={T.click - 2} out={T.add - 4}>
      <P c={C.pink}>Click.</P> Perfectly straight.
    </Headline>
    <Headline at={T.add - 4} out={T.carousel - 6}>
      <P c={C.purple} ff={F.dreamy}>Dreamy</P> <P c={C.pink} ff={F.script}>script</P> fonts
    </Headline>
    <Headline at={T.carousel - 6} out={T.flows - 6}>
      Carousels that <P c={C.blue}>flow</P>
    </Headline>
    <Headline at={T.flows - 6} out={T.keep - 4} center>
      One photo, <P c={C.blue}>across the slides</P>
    </Headline>
    <Headline at={T.keep - 4} out={T.post - 4} center>
      They keep <P c={C.pink}>swiping</P>
    </Headline>
    <Headline at={T.post - 4} out={T.exp - 4}>
      Fits every <P c={C.purple}>feed</P>
    </Headline>
    <Headline at={T.exp - 4} out={T.same - 2}>
      Export in <P c={C.purple}>crisp HD</P>
    </Headline>
  </AbsoluteFill>
);

/** Stickers that call out the best moments around the phone. */
export const Callouts: React.FC = () => {
  const { portrait, square, u, L } = useLayout();
  const spot = usePhoneSpot();
  const left = portrait ? { left: 30 * u } : { left: spot.cx - spot.w / 2 - (square ? 230 : 300) * u };
  const right = portrait ? { right: 30 * u } : { right: L.edge };
  const yA = portrait ? 520 * u : (square ? 470 : 520) * u;
  const yB = portrait ? 1080 * u : (square ? 700 : 760) * u;
  const s = portrait ? 46 : square ? 36 : 44;
  return (
    <AbsoluteFill>
      <Sticker at={T.pick + 2} out={T.drag1 - 4} text="▦ 1 tap layouts" bg={C.white} tilt={-6} size={s} style={{ ...left, top: yA }} />
      <Sticker at={T.drag1 + 10} out={T.drag2 - 4} text="👆 drag & drop" bg={C.pink} color="#fff" tilt={5} size={s} style={{ ...right, top: yB }} />
      <Sticker at={T.drag2 + 10} out={T.hold - 4} text="↔ any size" bg={C.teal} color="#fff" tilt={-4} size={s} style={{ ...left, top: yB }} />
      <Sticker at={T.swap} out={T.drop - 4} text="🔄 swapped!" bg={C.coral} color="#fff" tilt={5} size={s} style={{ ...right, top: yA }} />
      <Sticker at={T.top} out={T.give - 4} text="🖼️ layer photos" bg={C.purple} color="#fff" tilt={-5} size={s} style={{ ...left, top: yA }} />
      <Sticker at={T.click} out={T.add - 4} text="🔒 locked at 0°" bg="#FFD60A" color={C.ink} tilt={-5} size={s * 1.1} style={{ ...right, top: yA }} />
      <Sticker at={T.click + 6} out={T.add - 4} text="also 45° · 90° · 180°" bg={C.white} tilt={4} size={s * 0.8} style={{ ...left, top: yB }} />
      <Sticker at={T.script} out={T.carousel - 6} text="✍️ 14 caption fonts" bg={C.white} tilt={-4} size={s} style={{ ...right, top: yB }} />
      <Sticker at={T.crisp} out={T.same - 4} text="🔥 HD" bg={C.pink} color="#fff" tilt={-7} size={s * 1.3} style={{ ...left, top: yA }} />
      <Sticker at={T.hd + 3} out={T.same - 4} text="✓ saved" bg="#34C759" color="#fff" tilt={5} size={s} style={{ ...right, top: yB }} />
    </AbsoluteFill>
  );
};

// ---------------------------------------------------------------- carousel burst

/** "One photo flows across the slides": the three slides fly out of the phone, joined, then pull apart at the seams. */
export const CarouselBurst: React.FC = () => {
  const f = useCurrentFrame();
  const { portrait, square, u, width, height } = useLayout();
  const spot = usePhoneSpot();
  const a = T.flows - 4;
  const end = T.post - 6;
  if (f < a || f > end + 16) return null;
  const cw = (portrait ? 320 : square ? 290 : 370) * u;
  const ch = cw * 1.25;
  const cy = portrait ? height * 0.46 : height / 2 + (square ? 50 : 40) * u;
  const fly = ip(f, a, a + 16);
  const open = ip(f, T.slides - 2, T.slides + 12, 0, 1, Easing.inOut(Easing.cubic));
  const gap = open * 34 * u;
  const out = ip(f, end, end + 14, 0, 1, Easing.in(Easing.cubic));
  // keep swiping: the row slides along one slide
  const swipe = ip(f, T.keep, T.keep + 14, 0, 1, SOFT_);
  const rowW = cw * 3 + gap * 2;
  const shift = swipe * (cw + gap) * (portrait || square ? 1 : 0.6);
  const glow = win(f, T.flows, T.slides + 20, 6);
  const focus = 1 + (swipe > 0.5 ? 1 : 0);
  return (
    <AbsoluteFill style={{ opacity: 1 - out, filter: `blur(${out * 12 * u}px)` }}>
      <div style={{ position: "absolute", left: width / 2 - rowW / 2 - shift + (1 - fly) * (spot.cx - width / 2), top: cy - ch / 2 + (1 - fly) * 40 * u, width: rowW, height: ch, scale: String(0.4 + 0.6 * fly) }}>
        {[0, 1, 2].map((i) => {
          const dim = swipe > 0 && i !== focus ? 0.5 : 0;
          return (
            <div
              key={i}
              style={{
                position: "absolute",
                left: i * (cw + gap),
                top: 0,
                width: cw,
                height: ch,
                overflow: "hidden",
                borderRadius: 18 * u * open,
                boxShadow: `0 ${24 * u}px ${50 * u}px rgba(43,20,92,0.35)`,
                filter: `brightness(${1 - dim * 0.5})`,
              }}
            >
              <div style={{ position: "absolute", left: -i * cw, top: 0 }}>
                <StripContent slideW={cw} slideH={ch} gap={8 * u} glow={glow} radius={6 * u} />
              </div>
              <div style={{ position: "absolute", left: 14 * u, top: 14 * u, padding: `${4 * u}px ${14 * u}px`, borderRadius: 20 * u, background: "rgba(30,20,56,0.7)", color: "#fff", fontFamily, fontWeight: 800, fontSize: 24 * u }}>
                {i + 1}/3
              </div>
            </div>
          );
        })}
      </div>
      {/* dots */}
      <div style={{ position: "absolute", left: 0, right: 0, top: cy + ch / 2 + 30 * u, display: "flex", justifyContent: "center", gap: 14 * u, opacity: fly }}>
        {[0, 1, 2].map((i) => (
          <div key={i} style={{ width: 16 * u, height: 16 * u, borderRadius: 8 * u, background: i === (swipe > 0.5 ? 2 : 1) ? C.purple : "#CFC6E6" }} />
        ))}
      </div>
      {/* a swipe finger */}
      {f >= T.keep - 6 && f < T.keep + 18 ? (
        <div style={{ position: "absolute", left: width / 2 + cw * 0.4 - swipe * cw * 0.9, top: cy + ch * 0.2, width: 70 * u, height: 70 * u, borderRadius: "50%", background: "rgba(255,255,255,0.85)", border: `${4 * u}px solid #fff`, boxShadow: `0 0 0 ${12 * u}px rgba(255,255,255,0.3), 0 ${10 * u}px ${24 * u}px rgba(0,0,0,0.3)`, opacity: win(f, T.keep - 6, T.keep + 12, 4) }} />
      ) : null}
    </AbsoluteFill>
  );
};
const SOFT_ = Easing.bezier(0.45, 0, 0.25, 1);

// ---------------------------------------------------------------- formats

/** "Post, story, Instagram, TikTok... it fits." */
export const FormatCallouts: React.FC = () => {
  const { portrait, square, u, L } = useLayout();
  const spot = usePhoneSpot();
  const s = portrait ? 46 : square ? 36 : 46;
  const items = [
    { at: T.post, text: "📱 Post 4:5", bg: C.white, color: C.ink },
    { at: T.story, text: "📲 Story 9:16", bg: C.purple, color: "#fff" },
    { at: T.instagram, text: "Instagram ✓", bg: C.pink, color: "#fff" },
    { at: T.tiktok, text: "TikTok ✓", bg: C.ink, color: "#fff" },
  ];
  const out = T.exp - 4;
  if (portrait) {
    const spots = [
      { left: 30 * u, top: 470 * u },
      { right: 30 * u, top: 640 * u },
      { left: 30 * u, top: 1010 * u },
      { right: 30 * u, top: 1180 * u },
    ];
    return (
      <AbsoluteFill>
        {items.map((it, i) => (
          <Sticker key={i} at={it.at} out={out} text={it.text} bg={it.bg} color={it.color} tilt={i % 2 ? 5 : -5} size={s} style={spots[i]} />
        ))}
        <Sticker at={T.fits} out={out} text="✅ it fits" bg="#34C759" color="#fff" tilt={-3} size={s * 1.2} style={{ left: 0, right: 0, marginLeft: "auto", marginRight: "auto", width: "fit-content", top: 1340 * u }} />
      </AbsoluteFill>
    );
  }
  const x = L.leftX;
  const top = (square ? 420 : 520) * u;
  const step = (square ? 92 : 110) * u;
  return (
    <AbsoluteFill>
      {items.map((it, i) => (
        <Sticker key={i} at={it.at} out={out} text={it.text} bg={it.bg} color={it.color} tilt={i % 2 ? 3 : -3} size={s} style={{ left: x + (i % 2) * 60 * u, top: top + i * step }} />
      ))}
      <Sticker at={T.fits} out={out} text="✅ it fits" bg="#34C759" color="#fff" tilt={-4} size={s * 1.15} style={{ left: spot.cx - spot.w / 2 - (square ? 140 : 200) * u, top: top - (square ? 150 : 170) * u }} />
    </AbsoluteFill>
  );
};

// ---------------------------------------------------------------- before / after

/** The finished collage (layout, photo on top, script caption), as a static picture. */
const FinalCollage: React.FC<{ w: number }> = ({ w }) => {
  const h = w * 1.25;
  const g = w * 0.014;
  const sx = 0.64;
  const sy = 0.42;
  const rects = [
    { x: 0, y: 0, w: sx, h: sy },
    { x: sx, y: 0, w: 1 - sx, h: sy },
    { x: 0, y: sy, w: sx, h: 1 - sy },
    { x: sx, y: sy, w: 1 - sx, h: 1 - sy },
  ];
  const order = [PHOTOS[3], PHOTOS[1], PHOTOS[2], PHOTOS[0]];
  const k = w / 352;
  return (
    <div style={{ position: "relative", width: w, height: h, background: "#120d22", overflow: "hidden" }}>
      {rects.map((r, i) => (
        <TripPhoto key={i} kind={order[i]} hd style={{ position: "absolute", left: g + r.x * (w - g), top: g + r.y * (h - g), width: r.w * (w - g) - g, height: r.h * (h - g) - g, borderRadius: 3 * k }} />
      ))}
      <div style={{ position: "absolute", left: w / 2, top: h * 0.4, width: 0, height: 0 }}>
        <div style={{ position: "absolute", translate: "-50% -50%", scale: String(k) }}>
          <FramedPhoto kind={TOP_PHOTO} w={162} h={194} frame="torn" />
        </div>
      </div>
      <div style={{ position: "absolute", left: 0, right: 0, top: h * 0.8 - 30 * k, textAlign: "center", fontFamily: F.script, fontSize: 46 * k, color: "#fff", textShadow: "0 2px 10px rgba(0,0,0,0.55)" }}>
        best trip ever
        <div style={{ fontFamily, fontSize: 15 * k, color: C.gold, marginTop: -6 * k }}>✦ ♡ ✦</div>
      </div>
    </div>
  );
};

const PostCard: React.FC<{ w: number; handle: string; children: React.ReactNode; likes: string; grey?: number }> = ({ w, handle, children, likes, grey = 0 }) => {
  const { u } = useLayout();
  return (
    <div style={{ width: w, borderRadius: 28 * u, background: "#fff", overflow: "hidden", boxShadow: `0 ${30 * u}px ${70 * u}px rgba(43,20,92,0.28)`, filter: `grayscale(${grey})`, fontFamily }}>
      <div style={{ display: "flex", alignItems: "center", gap: 12 * u, padding: `${14 * u}px ${18 * u}px` }}>
        <div style={{ width: 44 * u, height: 44 * u, borderRadius: "50%", background: `linear-gradient(135deg, ${C.coral}, ${C.pink}, ${C.purple})` }} />
        <div style={{ fontWeight: 800, fontSize: 24 * u, color: C.ink }}>{handle}</div>
      </div>
      {children}
      <div style={{ padding: `${12 * u}px ${18 * u}px ${16 * u}px`, fontWeight: 800, fontSize: 24 * u, color: C.ink }}>{likes}</div>
    </div>
  );
};

/** "Same trip, way better post." The dull photo dump next to the collage, which wins the likes. */
export const BeforeAfterScene: React.FC = () => {
  const f = useCurrentFrame();
  const { portrait, square, u, width, height } = useLayout();
  const a = T.same;
  const b = T.way;
  const end = T.name2;
  if (f < a - 2 || f > end + 16) return null;
  const p = ip(f, a, a + 18);
  const win2 = ip(f, b, b + 16, 0, 1, POP);
  const out = ip(f, end - 4, end + 12, 0, 1, Easing.in(Easing.cubic));
  const w = (portrait ? 430 : square ? 360 : 400) * u;
  const cy = portrait ? height * 0.45 : height / 2 + 10 * u;
  const likes = Math.round(interpolate(f, [b, end], [12, 2481], { ...clamp, easing: Easing.out(Easing.cubic) }));
  const leftX = portrait ? width / 2 - w - 20 * u : width / 2 - w - 50 * u;
  const rightX = portrait ? width / 2 + 20 * u : width / 2 + 50 * u;
  const cardH = w * 1.25 + 150 * u;
  return (
    <AbsoluteFill style={{ opacity: 1 - out, filter: `blur(${out * 12 * u}px)` }}>
      <div style={{ position: "absolute", left: 0, right: 0, top: (portrait ? 150 : square ? 60 : 70) * u, textAlign: "center", fontFamily, fontWeight: 800, fontSize: (portrait ? 86 : square ? 70 : 90) * u, color: C.ink, letterSpacing: -1.5 * u, opacity: p, translate: `0px ${(1 - p) * 40 * u}px` }}>
        Same trip. <P c={C.purple}>{f >= b - 2 ? "Way better post." : ""}</P>
      </div>
      <div style={{ position: "absolute", left: leftX, top: cy - cardH / 2, opacity: p, translate: `${(1 - p) * -200 * u}px 0px`, rotate: `${-4 - win2 * 3}deg`, scale: String(1 - win2 * 0.12) }}>
        <PostCard w={w} handle="photo.dump" likes="♡ 3 likes" grey={0.4 + win2 * 0.5}>
          <div style={{ position: "relative", width: w, height: w * 1.25 }}>
            <TripPhoto kind={PHOTO_KINDS[(Math.floor(Math.max(0, f - a) / 6) * 5) % PHOTO_KINDS.length]} hd style={{ width: "100%", height: "100%" }} />
            <div style={{ position: "absolute", right: 14 * u, top: 14 * u, padding: `${4 * u}px ${14 * u}px`, borderRadius: 20 * u, background: "rgba(30,20,56,0.7)", color: "#fff", fontWeight: 800, fontSize: 22 * u }}>1/20</div>
          </div>
        </PostCard>
        <div style={{ position: "absolute", right: -20 * u, top: -30 * u, fontSize: 80 * u, scale: String(ip(f, a + 10, a + 20, 0, 1, POP)) }}>😴</div>
      </div>
      <div style={{ position: "absolute", left: rightX, top: cy - cardH / 2, opacity: p, translate: `${(1 - p) * 200 * u}px 0px`, rotate: `${3 - win2 * 3}deg`, scale: String(1 + win2 * 0.1), zIndex: 2 }}>
        <div style={{ position: "absolute", inset: -16 * u, borderRadius: 40 * u, boxShadow: `0 0 ${80 * u * win2}px ${20 * u * win2}px rgba(224,69,123,0.45)` }} />
        <PostCard w={w} handle="your.trip" likes={`♥ ${likes.toLocaleString("en-US")} likes`}>
          <FinalCollage w={w} />
        </PostCard>
        {/* hearts float up */}
        {Array.from({ length: 12 }).map((_, i) => {
          const life = (f - b - i * 3) / 30;
          if (life < 0 || life > 1) return null;
          return (
            <div key={i} style={{ position: "absolute", left: w * (0.15 + ((i * 37) % 70) / 100), top: w * 1.2 - life * w * 1.1, fontSize: (40 + (i % 3) * 14) * u, opacity: Math.sin(life * Math.PI), color: [C.pink, "#FF4D6D", C.purple][i % 3], rotate: `${(i % 2 ? 1 : -1) * 14}deg` }}>
              ♥
            </div>
          );
        })}
      </div>
    </AbsoluteFill>
  );
};

// ---------------------------------------------------------------- end card

/** "CollageMagik, free on the App Store." */
export const EndScene: React.FC = () => {
  const f = useCurrentFrame();
  const { u, portrait, square, width, height, L } = useLayout();
  const a = T.name2;
  if (f < a - 2) return null;
  const p = interpolate(f, [a, a + 22], [0, 1], { ...clamp, easing: Easing.bezier(0.34, 1.4, 0.64, 1) });
  const bob = Math.sin(f / 30) * 10 * u;
  const cy = portrait ? height * 0.37 : height * 0.35;
  const store = T.store;
  return (
    <AbsoluteFill>
      {Array.from({ length: 10 }).map((_, i) => {
        const ang = (i / 10) * Math.PI * 2 + f / 80;
        const r = (portrait ? 420 : square ? 430 : 560) * u;
        return (
          <TripPhoto
            key={i}
            kind={PHOTO_KINDS[(i * 3 + 2) % PHOTO_KINDS.length]}
            style={{
              position: "absolute",
              left: width / 2 + Math.cos(ang) * r * p - 60 * u,
              top: cy + Math.sin(ang) * r * 0.32 * p - 60 * u,
              width: 120 * u,
              height: 120 * u,
              borderRadius: 20 * u,
              border: `${4 * u}px solid #fff`,
              opacity: 0.9 * p,
              scale: String(p * (0.8 + 0.2 * Math.sin(ang))),
              rotate: `${(i % 2 ? 1 : -1) * 10}deg`,
              zIndex: Math.sin(ang) > 0 ? 2 : 0,
            }}
          />
        );
      })}
      <div style={{ position: "absolute", left: width / 2 - 150 * u, top: cy - 150 * u + bob, width: 300 * u, height: 300 * u, scale: String(p), zIndex: 1 }}>
        <Img src={staticFile("brand/icon.png")} style={{ width: "100%", height: "100%", borderRadius: 68 * u, boxShadow: `0 ${30 * u}px ${70 * u}px rgba(109,79,214,0.45)` }} />
      </div>
      <Air inAt={a + 6} from={[0, 40]} style={{ position: "absolute", left: 0, right: 0, top: cy + 220 * u, textAlign: "center", fontFamily, zIndex: 3 }}>
        <div style={{ fontWeight: 800, fontSize: 124 * u, color: C.ink, letterSpacing: -2 * u, lineHeight: 1 }}>
          Collage<P c={C.purple}>Magik</P>
        </div>
        <div style={{ fontWeight: 600, fontSize: 42 * u, color: "#5B5375", marginTop: 16 * u }}>{APP_SUBTITLE}</div>
      </Air>
      <Sticker at={T.free} text="Everything free 🎉" bg={C.gold} tilt={-6} size={54}
        style={portrait ? { left: 70 * u, top: cy - 290 * u, zIndex: 3 } : square ? { right: L.edge, top: cy - 280 * u, zIndex: 3 } : { left: width / 2 + 200 * u, top: cy - 250 * u, zIndex: 3 }} />
      <Air inAt={T.free - 6} from={[0, 50]} style={{ position: "absolute", left: 0, right: 0, top: cy + (portrait ? 500 : 420) * u, display: "flex", justifyContent: "center", zIndex: 3 }}>
        <div style={{ scale: String(1 + Math.max(0, Math.sin((f - store) / 7)) * 0.04 * (f >= store ? 1 : 0)) }}>
          <StoreButton s={u * (portrait ? 1 : 0.95)} />
        </div>
      </Air>
    </AbsoluteFill>
  );
};
