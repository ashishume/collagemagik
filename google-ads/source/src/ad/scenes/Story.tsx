import React from "react";
import { AbsoluteFill, Easing, Img, interpolate, staticFile, useCurrentFrame } from "remotion";
import { Air, AppBadge, Sticker, useFloat } from "../bits";
import { phoneHeight } from "../Phone";
import { PHOTO_KINDS, TripPhoto } from "../TripPhoto";
import { AIR, C, clamp, fontFamily, useLayout } from "../theme";

/** A phone-shaped card holding a fast-scrolling "camera roll" of trip photos and videos. */
const CameraRoll: React.FC<{ width: number }> = ({ width }) => {
  const f = useCurrentFrame();
  const { u } = useLayout();
  const h = phoneHeight(width);
  const cols = 4;
  const gap = 4 * u;
  const inner = width * 0.93;
  const cell = (inner - gap * (cols - 1)) / cols;
  // scroll fast, then ease off (like flicking through hundreds of photos)
  const scroll = interpolate(f, [0, 150], [0, cell * 22], { ...clamp, easing: Easing.out(Easing.cubic) });
  const rows = 34;
  return (
    <div
      style={{
        width,
        height: h,
        borderRadius: width * 0.16,
        background: "linear-gradient(145deg,#3a3446,#121016 45%,#2a2533)",
        padding: width * 0.035,
        boxSizing: "border-box",
        boxShadow: `0 ${width * 0.08}px ${width * 0.2}px rgba(43,20,92,0.35)`,
      }}
    >
      <div style={{ position: "relative", width: "100%", height: "100%", borderRadius: width * 0.125, overflow: "hidden", background: "#fff" }}>
        <div
          style={{
            position: "absolute",
            left: 0,
            right: 0,
            top: 0,
            padding: `${70 * u}px ${24 * u}px ${18 * u}px`,
            zIndex: 2,
            background: "linear-gradient(#fff 70%, rgba(255,255,255,0))",
            fontFamily,
            fontWeight: 800,
            fontSize: 42 * u,
            color: C.ink,
          }}
        >
          Recents
          <div style={{ fontSize: 22 * u, fontWeight: 600, color: "#8A83A0" }}>Trip · 412 items</div>
        </div>
        <div
          style={{
            position: "absolute",
            left: 0,
            top: 150 * u - scroll,
            display: "grid",
            gridTemplateColumns: `repeat(${cols}, ${cell}px)`,
            gap,
          }}
        >
          {Array.from({ length: rows * cols }).map((_, i) => (
            <TripPhoto
              key={i}
              u={u * 0.7}
              kind={PHOTO_KINDS[(i * 7 + Math.floor(i / 4)) % PHOTO_KINDS.length]}
              video={i % 5 === 2}
              style={{ width: cell, height: cell }}
            />
          ))}
        </div>
      </div>
    </div>
  );
};

/** "Just got back from the best trip ever... four hundred photos and videos." */
export const IntroScene: React.FC<{ dur: number }> = ({ dur }) => {
  const f = useCurrentFrame();
  const { portrait, u, width, height } = useLayout();
  const bob = useFloat(10, 35);
  const count = Math.round(interpolate(f, [20, 130], [0, 412], { ...clamp, easing: Easing.out(Easing.quad) }));
  const phoneW = (portrait ? 540 : 380) * u;
  const ph = phoneHeight(phoneW);
  const phoneX = portrait ? width / 2 - phoneW / 2 : width * 0.62 - phoneW / 2;
  const phoneY = portrait ? 300 * u : (height - ph) / 2;
  const centered = { left: 0, right: 0, marginLeft: "auto", marginRight: "auto", width: "fit-content" } as const;
  return (
    <AbsoluteFill>
      <Air dur={22} from={[0, 120]} outAt={dur - 12} style={{ position: "absolute", left: phoneX, top: phoneY + bob }}>
        <div style={{ rotate: `${interpolate(f, [0, 40], [-6, -2], { ...clamp, easing: AIR })}deg` }}>
          <CameraRoll width={phoneW} />
        </div>
      </Air>
      <Sticker at={14} out={dur - 10} text="✈️ Back from the trip!" bg={C.white} tilt={-6}
        style={portrait ? { ...centered, top: 250 * u } : { left: width * 0.62 - 560 * u, top: 110 * u }} />
      <Sticker at={34} out={dur - 10} text={`📸 ${count} photos & videos`} bg={C.gold} tilt={4} size={52}
        style={portrait ? { ...centered, top: 1320 * u } : { left: width * 0.62 + 60 * u, top: 800 * u }} />
      {!portrait ? (
        <Air inAt={8} outAt={dur - 12} from={[-60, 0]} style={{ position: "absolute", left: 140 * u, top: 360 * u, width: 640 * u }}>
          <div style={{ fontFamily, fontWeight: 800, fontSize: 92 * u, lineHeight: 1.02, color: C.ink }}>
            Too many <span style={{ color: C.purple }}>trip pics?</span>
          </div>
        </Air>
      ) : null}
    </AbsoluteFill>
  );
};

/** "But dumping them all at once? Nobody's swiping through that." */
export const DumpScene: React.FC<{ dur: number }> = ({ dur }) => {
  const f = useCurrentFrame();
  const { portrait, u, width, height } = useLayout();
  const cardW = (portrait ? 640 : 420) * u;
  const cardH = cardW * 1.25;
  const cx = portrait ? width / 2 : width * 0.62;
  const cy = portrait ? 290 * u + cardH / 2 + 70 * u : height / 2 + 20 * u;
  // swipes start quick and slow down, as the viewer loses interest
  const progress = interpolate(f, [4, dur * 0.85], [0, 7.3], { ...clamp, easing: Easing.out(Easing.cubic) });
  const slide = Math.floor(progress);
  const frac = progress - slide;
  const kinds = PHOTO_KINDS;
  const bored = interpolate(f, [dur * 0.45, dur * 0.6], [0, 1], { ...clamp, easing: AIR });
  return (
    <AbsoluteFill>
      <Air dur={18} from={[0, 80]} outAt={dur - 10} style={{ position: "absolute", left: cx - cardW / 2, top: cy - cardH / 2 - 70 * u }}>
        <div
          style={{
            width: cardW,
            borderRadius: 36 * u,
            background: "#fff",
            overflow: "hidden",
            boxShadow: `0 ${30 * u}px ${70 * u}px rgba(43,20,92,0.25)`,
            filter: `grayscale(${bored * 0.6})`,
          }}
        >
          <div style={{ display: "flex", alignItems: "center", gap: 14 * u, padding: `${18 * u}px ${22 * u}px`, fontFamily }}>
            <div style={{ width: 54 * u, height: 54 * u, borderRadius: "50%", background: `linear-gradient(135deg, ${C.coral}, ${C.pink})` }} />
            <div style={{ fontWeight: 800, fontSize: 28 * u, color: C.ink }}>your.travel.dump</div>
            <div style={{ marginLeft: "auto", fontWeight: 800, fontSize: 26 * u, color: "#fff", background: "rgba(30,20,56,0.75)", borderRadius: 30 * u, padding: `${4 * u}px ${16 * u}px` }}>
              {Math.min(slide + 1, 20)}/20
            </div>
          </div>
          <div style={{ position: "relative", width: cardW, height: cardH, overflow: "hidden" }}>
            {[0, 1].map((k) => (
              <TripPhoto
                key={k}
                kind={kinds[(slide + k) % kinds.length]}
                style={{ position: "absolute", inset: 0, translate: `${(k - frac) * cardW}px 0px` }}
              />
            ))}
          </div>
          <div style={{ display: "flex", justifyContent: "center", gap: 8 * u, padding: 16 * u }}>
            {Array.from({ length: 20 }).map((_, i) => (
              <div key={i} style={{ width: 9 * u, height: 9 * u, borderRadius: "50%", background: i === slide ? C.purple : "#D9D3E8" }} />
            ))}
          </div>
        </div>
      </Air>
      <Sticker at={Math.round(dur * 0.45)} out={dur - 8} text="Photo dump = 😴" bg={C.ink} color="#fff" tilt={-5} size={60}
        style={portrait ? { right: 40 * u, top: 1190 * u } : { left: 140 * u, top: 300 * u }} />
      <Sticker at={Math.round(dur * 0.6)} out={dur - 8} text="zzz…" bg={C.lilac} color={C.purple} tilt={8} size={44}
        style={portrait ? { right: 140 * u, top: 250 * u } : { left: cx + cardW / 2 - 40 * u, top: cy - cardH / 2 - 60 * u }} />
      {!portrait ? (
        <Air inAt={6} outAt={dur - 10} from={[-60, 0]} style={{ position: "absolute", left: 140 * u, top: 470 * u, width: 640 * u }}>
          <div style={{ fontFamily, fontWeight: 800, fontSize: 80 * u, lineHeight: 1.05, color: C.ink }}>
            Nobody swipes to <span style={{ color: C.pink }}>slide 20.</span>
          </div>
        </Air>
      ) : null}
    </AbsoluteFill>
  );
};

/** Shown across both story scenes: the app is on screen before the voice names it. */
export const StoryBadge: React.FC<{ dur: number; switchAt: number }> = ({ dur, switchAt }) => {
  const f = useCurrentFrame();
  const { portrait, u, width } = useLayout();
  const second = f >= switchAt;
  const pulse = 1 + Math.max(0, Math.sin((f - switchAt) / 6)) * 0.03 * (second ? 1 : 0);
  return (
    <div style={{ position: "absolute", inset: 0 }}>
      <div style={{ position: "absolute", left: 0, right: 0, top: (portrait ? 96 : 60) * u, display: "flex", justifyContent: portrait ? "center" : "flex-start", paddingLeft: portrait ? 0 : 140 * u, scale: String(pulse) }}>
        <AppBadge
          at={!second ? 18 : switchAt}
          out={!second ? switchAt - 14 : dur - 10}
          scale={portrait ? 1.15 : 0.9}
          style={{ position: "relative" }}
          sub={!second ? "Your trip, in one post" : "There's a better way →"}
        />
      </div>
      {/* a peek of the real app in the corner, so viewers see what's coming */}
      <AppPeek dur={dur} />
      <div style={{ display: "none" }}>{width}</div>
    </div>
  );
};

const AppPeek: React.FC<{ dur: number }> = ({ dur }) => {
  const f = useCurrentFrame();
  const { portrait, u, width, height } = useLayout();
  const p = interpolate(f, [40, 70], [0, 1], { ...clamp, easing: AIR });
  const out = interpolate(f, [dur - 14, dur], [0, 1], { ...clamp, easing: AIR });
  const w = (portrait ? 250 : 210) * u;
  const bob = Math.sin(f / 30) * 8 * u;
  const shots = ["04-layout.png", "05-timeline.png", "07-captions.png", "01-carousel.png"];
  const idx = Math.floor(Math.max(0, f - 40) / 45) % shots.length;
  return (
    <div
      style={{
        position: "absolute",
        ...(portrait ? { left: 40 * u, top: 880 * u } : { left: 140 * u, top: height - 420 * u }),
        width: portrait ? w : undefined,
        opacity: p * (1 - out),
        translate: `${(1 - p) * -80 * u}px ${bob}px`,
        rotate: "-8deg",
        filter: `blur(${(1 - p) * 8 * u}px)`,
      }}
    >
      {portrait ? (
        <div style={{ width: w * 0.8, height: (w * 0.8 * 2868) / 1320, borderRadius: 30 * u, overflow: "hidden", boxShadow: `0 ${18 * u}px ${40 * u}px rgba(43,20,92,0.3)`, border: `${6 * u}px solid #fff` }}>
          <Img src={staticFile(`shots/${shots[idx]}`)} style={{ width: "100%", height: "100%", objectFit: "contain" }} />
        </div>
      ) : (
        <div style={{ display: "flex", gap: 18 * u }}>
          {shots.slice(0, 3).map((s, i) => (
            <div key={s} style={{ width: 120 * u, height: (120 * 2868 * u) / 1320, borderRadius: 22 * u, overflow: "hidden", border: `${5 * u}px solid #fff`, boxShadow: `0 ${14 * u}px ${30 * u}px rgba(43,20,92,0.25)`, translate: `0px ${Math.sin(f / 25 + i) * 8 * u}px` }}>
              <Img src={staticFile(`shots/${s}`)} style={{ width: "100%", height: "100%", objectFit: "contain" }} />
            </div>
          ))}
        </div>
      )}
      <div style={{ display: "none" }}>{width}</div>
    </div>
  );
};
