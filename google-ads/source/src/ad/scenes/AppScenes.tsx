import React from "react";
import { AbsoluteFill, Easing, Img, interpolate, staticFile, useCurrentFrame } from "remotion";
import { Air, StoreButton, Sticker } from "../bits";
import { cue } from "../cues";
import { PHOTO_KINDS, TripPhoto } from "../TripPhoto";
import { AIR, C, clamp, fontFamily, useLayout } from "../theme";

/** Big scene title: top centre in vertical, left column in landscape. `at`/`out` are absolute frames. */
const Headline: React.FC<{ at: number; out: number; children: React.ReactNode; size?: number }> = ({ at, out, children, size = 1 }) => {
  const { portrait, u } = useLayout();
  return (
    <AbsoluteFill style={{ pointerEvents: "none" }}>
      <Air
        inAt={at}
        outAt={out - 10}
        from={portrait ? [0, 50] : [-70, 0]}
        style={
          portrait
            ? { position: "absolute", left: 70 * u, right: 70 * u, top: 120 * u, textAlign: "center" }
            : { position: "absolute", left: 140 * u, top: 290 * u, width: 820 * u }
        }
      >
        <div style={{ fontFamily, fontWeight: 800, fontSize: (portrait ? 84 : 96) * u * size, lineHeight: 1.04, color: C.ink, letterSpacing: -1 * u }}>
          {children}
        </div>
      </Air>
    </AbsoluteFill>
  );
};

const P: React.FC<{ c: string; children: React.ReactNode }> = ({ c, children }) => <span style={{ color: c }}>{children}</span>;

/** Side positions for stickers around the phone. */
const useSpots = () => {
  const { portrait, u, width } = useLayout();
  const px = width * 0.68; // landscape phone centre
  return {
    leftHigh: portrait ? { left: 50 * u, top: 470 * u } : { left: px - 400 * u, top: 130 * u },
    // right-anchored so long stickers grow over the phone instead of off the frame
    rightHigh: portrait ? { right: 50 * u, top: 640 * u } : { right: 60 * u, top: 300 * u },
    leftLow: portrait ? { left: 50 * u, top: 980 * u } : { left: px - 450 * u, top: 640 * u },
    rightLow: portrait ? { right: 50 * u, top: 1150 * u } : { right: 60 * u, top: 720 * u },
  };
};

/** "So I put it all in Insta Collage." Trip photos fly into the app icon, which then names itself. */
export const RevealScene: React.FC = () => {
  const f = useCurrentFrame();
  const { u, width, height, portrait } = useLayout();
  const s = cue("so");
  const named = cue("instacollage");
  const next = cue("photos", 1);
  const cx = width / 2;
  const cy = portrait ? height * 0.42 : height * 0.45;
  const pull = interpolate(f, [s, s + 26], [0, 1], { ...clamp, easing: Easing.in(Easing.cubic) });
  const icon = interpolate(f, [s + 14, s + 34], [0, 1], { ...clamp, easing: Easing.bezier(0.34, 1.56, 0.64, 1) });
  const settle = interpolate(f, [named + 18, next], [0, 1], { ...clamp, easing: AIR });
  const ring = interpolate(f, [s + 20, s + 50], [0, 1], { ...clamp, easing: AIR });
  if (f < s - 10 || f > next + 12) return null;
  const tilesIn = interpolate(f, [s - 10, s], [0, 1], clamp);
  return (
    <AbsoluteFill>
      {Array.from({ length: 14 }).map((_, i) => {
        const a = (i / 14) * Math.PI * 2;
        const r = (portrait ? 620 : 760) * u;
        const x = cx + Math.cos(a) * r * (1 - pull) - 70 * u;
        const y = cy + Math.sin(a) * r * 0.8 * (1 - pull) - 70 * u;
        return (
          <TripPhoto
            key={i}
            kind={PHOTO_KINDS[i % PHOTO_KINDS.length]}
            style={{
              position: "absolute",
              left: x,
              top: y,
              width: 140 * u,
              height: 140 * u,
              borderRadius: 22 * u,
              border: `${5 * u}px solid #fff`,
              rotate: `${(i % 2 ? 1 : -1) * 14 + pull * 180}deg`,
              scale: String(1 - pull * 0.8),
              opacity: tilesIn * (1 - interpolate(f, [s + 20, s + 28], [0, 1], clamp)),
              boxShadow: `0 ${10 * u}px ${24 * u}px rgba(43,20,92,0.25)`,
            }}
          />
        );
      })}
      <div
        style={{
          position: "absolute",
          left: cx - 160 * u,
          top: cy - 160 * u - settle * (portrait ? 420 * u : 300 * u),
          width: 320 * u,
          height: 320 * u,
          scale: String(icon * (1 - settle * 0.55)),
          opacity: 1 - interpolate(f, [next - 6, next + 10], [0, 1], clamp),
        }}
      >
        <div style={{ position: "absolute", inset: -60 * u * ring, borderRadius: "50%", border: `${6 * u}px solid ${C.purple}`, opacity: (1 - ring) * 0.6 }} />
        <Img src={staticFile("brand/icon.png")} style={{ width: "100%", height: "100%", borderRadius: 72 * u, boxShadow: `0 ${30 * u}px ${70 * u}px rgba(109,79,214,0.45)` }} />
      </div>
      <Air
        inAt={named - 4}
        outAt={next - 4}
        from={[0, 40]}
        style={{ position: "absolute", left: 0, right: 0, top: cy + 190 * u - settle * 340 * u, textAlign: "center" }}
      >
        <div style={{ fontFamily, fontWeight: 800, fontSize: 120 * u, color: C.ink, letterSpacing: -2 * u }}>
          Insta <P c={C.purple}>Collage</P>
        </div>
      </Air>
    </AbsoluteFill>
  );
};

/** Headlines and stickers that ride along with the persistent phone, from "Photos and videos" to "export". */
export const FeatureOverlays: React.FC = () => {
  const spots = useSpots();
  const { portrait } = useLayout();
  return (
    <AbsoluteFill>
      {/* Photos and videos, side by side */}
      <Headline at={cue("photos", 1)} out={cue("trim") - 6} size={portrait ? 0.86 : 1}>
        Photos <P c={C.pink}>+</P> videos,{portrait ? <br /> : " "}<P c={C.purple}>together</P>
      </Headline>
      <Sticker at={cue("photos", 1) + 6} out={cue("trim") - 8} text="📸 Photo" tilt={-6} style={spots.leftHigh} />
      <Sticker at={cue("videos", 1)} out={cue("trim") - 8} text="🎥 Video" bg={C.purple} color="#fff" tilt={5} style={spots.rightHigh} />
      <Sticker at={cue("side")} out={cue("trim") - 8} text="▶ playing together" bg={C.gold} tilt={-3} size={46} style={spots.leftLow} />

      {/* trim, moment, song */}
      <Headline at={cue("trim") - 4} out={cue("drop")}>
        Edit every <P c={C.teal}>clip</P>
      </Headline>
      <Sticker at={cue("trim")} out={cue("drop") - 6} text="✂️ Trim" bg={C.white} tilt={-6} style={spots.leftHigh} />
      <Sticker at={cue("pick")} out={cue("drop") - 6} text="🎯 Pick the moment" bg={C.coral} color="#fff" tilt={4} style={spots.rightHigh} />
      <Sticker at={cue("add")} out={cue("drop") - 6} text="🎵 Add your song" bg={C.teal} color="#fff" tilt={-4} style={spots.leftLow} />
      <MusicNotes from={cue("add")} to={cue("drop")} />

      {/* captions */}
      <Headline at={cue("drop") - 4} out={cue("want")}>
        Captions that <P c={C.pink}>pop</P>
      </Headline>
      <DragCaption />
      <Sticker at={cue("done")} out={cue("want") - 4} text="✅ Done" bg={C.white} tilt={5} style={spots.rightLow} />

      {/* carousel */}
      <Headline at={cue("want") - 4} out={cue("then")}>
        Carousels that <P c={C.blue}>flow</P>
      </Headline>
      <Sticker at={cue("carousel")} out={cue("then") - 6} text="1 ➜ 2 ➜ 3" bg={C.blue} color="#fff" tilt={-5} style={spots.leftHigh} />
      <Sticker at={cue("flows")} out={cue("then") - 6} text="✨ photos cross the slides" bg={C.white} tilt={4} size={46} style={spots.rightHigh} />
      <Sticker at={cue("so", 1)} out={cue("then") - 6} text="👆 keep swiping" bg={C.gold} tilt={-4} style={spots.leftLow} />
      {!portrait ? <PanoramaStrip from={cue("so", 1) - 20} to={cue("then")} /> : null}

      {/* export */}
      <Headline at={cue("then") - 4} out={cue("same")}>
        Export in <P c={C.purple}>crisp HD</P>
      </Headline>
      <Sticker at={cue("crisp")} out={cue("same") - 6} text="🔥 HD" bg={C.pink} color="#fff" tilt={-6} size={64} style={spots.leftHigh} />
      <SharpVsBlurry at={cue("no")} out={cue("same") - 4} />
    </AbsoluteFill>
  );
};

/** A caption that gets dragged, then twisted, on "drag it, twist it". */
const DragCaption: React.FC = () => {
  const f = useCurrentFrame();
  const { u, portrait, width } = useLayout();
  const a = cue("drop");
  const drag = cue("drag");
  const twist = cue("twist");
  const gone = cue("want") - 8;
  if (f < a || f > gone + 12) return null;
  const p = interpolate(f, [a + 4, a + 18], [0, 1], { ...clamp, easing: Easing.bezier(0.34, 1.56, 0.64, 1) });
  const dx = interpolate(f, [drag, drag + 16], [0, 1], { ...clamp, easing: AIR });
  const rot = interpolate(f, [twist, twist + 14], [0, 1], { ...clamp, easing: Easing.bezier(0.34, 1.56, 0.64, 1) });
  const out = interpolate(f, [gone, gone + 10], [0, 1], clamp);
  const cx = portrait ? width / 2 : width * 0.68;
  const baseY = portrait ? 790 * u : 470 * u; // below the app's own title caption
  return (
    <div
      style={{
        position: "absolute",
        left: cx - 230 * u + dx * 70 * u,
        top: baseY + dx * 170 * u,
        width: 460 * u,
        textAlign: "center",
        scale: String(p * (1 - out)),
        rotate: `${-2 - rot * 10}deg`,
        fontFamily,
        fontWeight: 800,
        fontSize: 58 * u,
        color: "#fff",
        background: C.pink,
        borderRadius: 18 * u,
        padding: `${12 * u}px ${18 * u}px`,
        boxShadow: `0 ${14 * u}px ${34 * u}px rgba(224,69,123,0.45)`,
        outline: `${4 * u}px dashed rgba(255,255,255,0.85)`,
        outlineOffset: 8 * u,
      }}
    >
      best trip ever ✨
      {f >= drag - 6 && f < twist + 20 ? (
        <div style={{ position: "absolute", right: -40 * u, bottom: -50 * u, fontSize: 70 * u, fontStyle: "normal", rotate: "12deg" }}>👆</div>
      ) : null}
    </div>
  );
};

const MusicNotes: React.FC<{ from: number; to: number }> = ({ from, to }) => {
  const f = useCurrentFrame();
  const { u, portrait, width } = useLayout();
  if (f < from || f > to) return null;
  const cx = portrait ? width / 2 : width * 0.68;
  return (
    <>
      {Array.from({ length: 6 }).map((_, i) => {
        const life = (f - from - i * 6) / 40;
        if (life < 0 || life > 1) return null;
        return (
          <div
            key={i}
            style={{
              position: "absolute",
              left: cx + (i % 2 ? 1 : -1) * (120 + i * 30) * u + Math.sin(life * 6) * 20 * u,
              top: (portrait ? 1150 : 820) * u - life * 380 * u,
              fontSize: (60 + i * 6) * u,
              opacity: Math.sin(life * Math.PI),
              color: [C.purple, C.pink, C.teal][i % 3],
              rotate: `${(i % 2 ? 1 : -1) * 15}deg`,
            }}
          >
            {i % 2 ? "♪" : "♫"}
          </div>
        );
      })}
    </>
  );
};

/** Landscape only: a seamless panorama split across slides, swiping left. */
const PanoramaStrip: React.FC<{ from: number; to: number }> = ({ from, to }) => {
  const f = useCurrentFrame();
  const { u } = useLayout();
  if (f < from || f > to + 10) return null;
  const p = interpolate(f, [from, from + 18], [0, 1], { ...clamp, easing: AIR });
  const out = interpolate(f, [to - 8, to + 6], [0, 1], clamp);
  const pan = interpolate(f, [from, to], [0, -260], clamp) * u;
  const slideW = 230 * u;
  return (
    <div style={{ position: "absolute", left: 140 * u, top: 560 * u, width: 820 * u, height: 300 * u, overflow: "hidden", opacity: p * (1 - out), filter: `blur(${(1 - p) * 10 * u}px)` }}>
      <div style={{ position: "absolute", left: pan, top: 0, display: "flex", gap: 14 * u }}>
        {Array.from({ length: 5 }).map((_, i) => (
          <div key={i} style={{ width: slideW, height: 287 * u, borderRadius: 18 * u, overflow: "hidden", position: "relative", boxShadow: `0 ${10 * u}px ${24 * u}px rgba(43,20,92,0.2)` }}>
            <TripPhoto kind="santorini-sunset" hd style={{ position: "absolute", top: 0, left: -i * (slideW + 14 * u), width: 5 * slideW + 56 * u, height: "100%" }} />
          </div>
        ))}
      </div>
    </div>
  );
};

/** "No blurry mess": a blurry thumbnail crossed out next to a sharp one. */
const SharpVsBlurry: React.FC<{ at: number; out: number }> = ({ at, out }) => {
  const f = useCurrentFrame();
  const { u, portrait } = useLayout();
  const p = interpolate(f, [at, at + 14], [0, 1], { ...clamp, easing: Easing.bezier(0.34, 1.56, 0.64, 1) });
  const o = interpolate(f, [out, out + 10], [0, 1], clamp);
  if (f < at || f > out + 12) return null;
  const s = 170 * u;
  const pos = portrait ? { left: 40 * u, top: 1180 * u } : { left: 140 * u, top: 600 * u };
  const card = (blur: boolean) => (
    <div style={{ position: "relative" }}>
      <TripPhoto kind="alpine-lake" hd style={{ width: s, height: s, borderRadius: 22 * u, border: `${5 * u}px solid #fff`, filter: blur ? `blur(${7 * u}px)` : undefined, boxShadow: `0 ${10 * u}px ${24 * u}px rgba(43,20,92,0.25)` }} />
      <div style={{ position: "absolute", right: -16 * u, top: -16 * u, fontSize: 56 * u }}>{blur ? "❌" : "✅"}</div>
    </div>
  );
  return (
    <div style={{ position: "absolute", ...pos, display: "flex", flexDirection: portrait ? "column" : "row", gap: (portrait ? 28 : 40) * u, scale: String(p * (1 - o)), rotate: "-3deg" }}>
      {card(true)}
      {card(false)}
    </div>
  );
};

/** "Same trip. Way better post." A grey photo pile next to the finished collage. */
export const BeforeAfterScene: React.FC = () => {
  const f = useCurrentFrame();
  const { u, portrait } = useLayout();
  const a = cue("same");
  const b = cue("way");
  const end = cue("instacollage", 1);
  if (f < a - 2 || f > end + 14) return null;
  const p = interpolate(f, [a, a + 20], [0, 1], { ...clamp, easing: AIR });
  const out = interpolate(f, [end - 6, end + 10], [0, 1], { ...clamp, easing: AIR });
  const base = portrait ? { x: 70 * u, y: 640 * u } : { x: 180 * u, y: 540 * u };
  const tile = (portrait ? 230 : 170) * u;
  const step = (portrait ? 46 : 38) * u;
  return (
    <AbsoluteFill>
      <Headline at={a} out={end} size={portrait ? 0.84 : 1}>
        Same trip.{portrait ? " " : <br />}<P c={C.purple}>Way better post.</P>
      </Headline>
      <div style={{ position: "absolute", left: base.x, top: base.y, opacity: p * (1 - out), translate: `${(1 - p) * -80 * u}px 0px`, filter: `blur(${(1 - p) * 10 * u + out * 12 * u}px)` }}>
        {Array.from({ length: 6 }).map((_, i) => (
          <TripPhoto
            key={i}
            kind={PHOTO_KINDS[(i * 3) % PHOTO_KINDS.length]}
            style={{
              position: "absolute",
              left: (i % 3) * 34 * u,
              top: i * step,
              width: tile,
              height: tile,
              borderRadius: 18 * u,
              border: `${5 * u}px solid #fff`,
              rotate: `${[-12, 8, -5, 14, -9, 4][i]}deg`,
              filter: "grayscale(0.7)",
              boxShadow: `0 ${8 * u}px ${20 * u}px rgba(43,20,92,0.2)`,
            }}
          />
        ))}
      </div>
      <Sticker at={a + 6} out={end - 4} text="20-photo dump 😴" bg={C.ink} color="#fff" tilt={-6} size={44}
        style={portrait ? { left: 60 * u, top: 1170 * u } : { left: 470 * u, top: 640 * u }} />
      <Sticker at={b} out={end - 4} text="1 post everyone loves 💜" bg={C.white} tilt={4} size={44}
        style={portrait ? { right: 40 * u, top: 1240 * u } : { right: 60 * u, top: 760 * u }} />
    </AbsoluteFill>
  );
};

/** "Insta Collage. And yeah, everything is free. Download now on the App Store." */
export const EndScene: React.FC = () => {
  const f = useCurrentFrame();
  const { u, portrait, width, height } = useLayout();
  const a = cue("instacollage", 1);
  const free = cue("free");
  const dl = cue("download");
  if (f < a - 2) return null;
  const p = interpolate(f, [a, a + 24], [0, 1], { ...clamp, easing: Easing.bezier(0.34, 1.4, 0.64, 1) });
  const bob = Math.sin(f / 30) * 10 * u;
  const cy = portrait ? height * 0.37 : height * 0.36;
  return (
    <AbsoluteFill>
      {/* floating collage tiles orbiting the icon */}
      {Array.from({ length: 8 }).map((_, i) => {
        const ang = (i / 8) * Math.PI * 2 + f / 90;
        const r = (portrait ? 400 : 520) * u;
        return (
          <TripPhoto
            key={i}
            kind={PHOTO_KINDS[(i * 2 + 1) % PHOTO_KINDS.length]}
            style={{
              position: "absolute",
              left: width / 2 + Math.cos(ang) * r - 60 * u,
              top: cy + Math.sin(ang) * r * 0.3 - 60 * u,
              width: 120 * u,
              height: 120 * u,
              borderRadius: 20 * u,
              border: `${4 * u}px solid #fff`,
              opacity: 0.85 * p,
              scale: String(p),
              rotate: `${(i % 2 ? 1 : -1) * 10}deg`,
            }}
          />
        );
      })}
      <div style={{ position: "absolute", left: width / 2 - 150 * u, top: cy - 150 * u + bob, width: 300 * u, height: 300 * u, scale: String(p) }}>
        <Img src={staticFile("brand/icon.png")} style={{ width: "100%", height: "100%", borderRadius: 68 * u, boxShadow: `0 ${30 * u}px ${70 * u}px rgba(109,79,214,0.45)` }} />
      </div>
      <Air inAt={a + 8} from={[0, 40]} style={{ position: "absolute", left: 0, right: 0, top: cy + 230 * u, textAlign: "center", fontFamily }}>
        <div style={{ fontWeight: 800, fontSize: 124 * u, color: C.ink, letterSpacing: -2 * u, lineHeight: 1 }}>
          Insta <P c={C.purple}>Collage</P>
        </div>
        <div style={{ fontWeight: 600, fontSize: 42 * u, color: "#5B5375", marginTop: 18 * u }}>
          Collages · Carousels · Captions · Video
        </div>
      </Air>
      <Sticker at={free} text="Everything free 🎉" bg={C.gold} tilt={-6} size={56}
        style={portrait ? { left: 80 * u, top: cy - 300 * u } : { left: width / 2 + 200 * u, top: cy - 260 * u }} />
      <Air inAt={dl - 4} from={[0, 50]} style={{ position: "absolute", left: 0, right: 0, top: cy + (portrait ? 520 : 430) * u, display: "flex", justifyContent: "center" }}>
        <div style={{ scale: String(1 + Math.max(0, Math.sin((f - dl) / 7)) * 0.03) }}>
          <StoreButton s={u * (portrait ? 1 : 0.95)} />
        </div>
      </Air>
    </AbsoluteFill>
  );
};
