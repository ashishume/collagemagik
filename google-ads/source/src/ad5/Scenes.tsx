import React from "react";
import { AbsoluteFill, Easing, Img, interpolate, staticFile, useCurrentFrame } from "remotion";
import { Air, AppBadge, Sticker, StoreButton } from "../ad/bits";
import type { PhotoKind } from "../ad/TripPhoto";
import { C, clamp, fontFamily, SOFT, useLayout } from "../ad/theme";
import { Collage, Moving } from "./Collage";
import { T } from "./cues";
import { EditorPhone, editorPhoneHeight } from "./Screen";
import { ip, POP, pulse, steps, win } from "./kit";

const P: React.FC<{ c: string; children: React.ReactNode }> = ({ c, children }) => <span style={{ color: c }}>{children}</span>;

/** Where the editor phone sits in each format. */
export const usePhoneSpot = () => {
  const { portrait, u, width, height, L } = useLayout();
  const w = portrait ? 600 * u : L.phoneW * 1.05;
  const h = editorPhoneHeight(w);
  const cx = portrait ? width / 2 : L.phoneCx;
  const top = portrait ? 330 * u : height / 2 - h / 2 - 10 * u;
  return { w, h, cx, top };
};

// ---------------------------------------------------------------- floating bits (always on)

const BITS = ["📷", "🎬", "✨", "♪", "▶", "🌊", "☀️", "🎞️", "💜", "📸"];
/** Little icons drifting up behind everything, so the frame never sits still. */
export const FloatingBits: React.FC = () => {
  const f = useCurrentFrame();
  const { width, height, u } = useLayout();
  return (
    <AbsoluteFill style={{ pointerEvents: "none" }}>
      {Array.from({ length: 14 }).map((_, i) => {
        const speed = 0.6 + (i % 4) * 0.25;
        const life = ((f * speed + i * 137) % (height + 300 * u)) / (height + 300 * u);
        const x = ((i * 0.618) % 1) * width + Math.sin(f / 50 + i) * 30 * u;
        const y = height + 120 * u - life * (height + 300 * u);
        return (
          <div key={i} style={{ position: "absolute", left: x, top: y, fontSize: (34 + (i % 3) * 14) * u, opacity: 0.22 + 0.18 * Math.sin(life * Math.PI), rotate: `${Math.sin(f / 40 + i) * 18}deg`, filter: `blur(${(i % 3) * 0.8 * u}px)` }}>
            {BITS[i % BITS.length]}
          </div>
        );
      })}
    </AbsoluteFill>
  );
};

// ---------------------------------------------------------------- hook: the camera roll

const ROLL: { k: PhotoKind; v?: boolean }[] = [
  { k: "santorini-domes" },
  { k: "golden-wave", v: true },
  { k: "pizza" },
  { k: "positano" },
  { k: "venice-canal", v: true },
  { k: "balloons" },
  { k: "aurora-reine", v: true },
  { k: "breakfast" },
  { k: "turquoise", v: true },
  { k: "dinner-fira" },
  { k: "alpine-lake" },
  { k: "beach-sunset", v: true },
];

const Tile: React.FC<{ k: PhotoKind; v?: boolean; size: number; glow: number; play: number; seed: number }> = ({ k, v, size, glow, play, seed }) => {
  const f = useCurrentFrame();
  const { u } = useLayout();
  const col = v ? C.pink : C.purple;
  return (
    <div style={{ position: "relative", width: size, height: size, borderRadius: 18 * u, overflow: "hidden", boxShadow: `0 0 0 ${5 * u * glow}px ${col}, 0 ${10 * u}px ${24 * u}px rgba(43,20,92,0.25)`, scale: String(1 + 0.05 * glow) }}>
      {v ? <Moving kind={k} f={f} seed={seed} playing={play} /> : <Img src={staticFile(`travel/thumb/${k}.jpg`)} style={{ width: "100%", height: "100%", objectFit: "cover" }} />}
      {v ? (
        <div style={{ position: "absolute", right: 8 * u, bottom: 8 * u, padding: `${3 * u}px ${9 * u}px`, borderRadius: 20 * u, background: "rgba(0,0,0,0.6)", color: "#fff", fontFamily, fontWeight: 800, fontSize: 18 * u }}>▶ 0:{12 + seed}</div>
      ) : null}
      <div style={{ position: "absolute", left: 8 * u, top: 8 * u, padding: `${3 * u}px ${10 * u}px`, borderRadius: 20 * u, background: col, color: "#fff", fontFamily, fontWeight: 800, fontSize: 16 * u, opacity: glow }}>{v ? "VIDEO" : "PHOTO"}</div>
    </div>
  );
};

export const HookScene: React.FC = () => {
  const f = useCurrentFrame();
  const { portrait, square, u, width, height, L } = useLayout();
  const end = T.that + 4;
  if (f > end + 20) return null;
  const out = ip(f, end, end + 16, 0, 1, Easing.in(Easing.cubic));
  const cols = 3;
  const size = (portrait ? 270 : square ? 190 : 210) * u;
  const gap = 18 * u;
  const gw = cols * size + (cols - 1) * gap;
  const cx = portrait ? width / 2 : L.storyCx + (square ? 0 : 60 * u);
  const cy = portrait ? height * 0.58 : height / 2 + 20 * u;
  const scroll = interpolate(f, [0, end], [0, -size * 0.9], clamp);
  const photosOn = ip(f, T.photos0 - 4, T.photos0 + 6, 0, 1, POP);
  const videosOn = ip(f, T.videos0 - 4, T.videos0 + 6, 0, 1, POP);
  const head = portrait
    ? { left: 50 * u, right: 50 * u, top: 130 * u, textAlign: "center" as const }
    : { left: L.leftX, top: (square ? 250 : 300) * u, width: square ? L.colW : 760 * u };
  const tripIn = ip(f, 0, 10, 0, 1, POP);
  return (
    <AbsoluteFill style={{ opacity: 1 - out, filter: `blur(${out * 14 * u}px)` }}>
      <div style={{ position: "absolute", left: cx - gw / 2, top: cy - (size * 2 + gap * 1.5), width: gw, height: size * 4 + gap * 3, perspective: 2000 * u }}>
        <div style={{ transform: `rotateX(${14 - 6 * ip(f, 0, 40)}deg) rotateZ(${-4 + Math.sin(f / 40) * 1.5}deg)`, translate: `0px ${scroll}px`, display: "grid", gridTemplateColumns: `repeat(${cols}, ${size}px)`, gap }}>
          {ROLL.map((r, i) => {
            const at = i * 2;
            const o = ip(f, at, at + 10);
            return (
              <div key={i} style={{ opacity: o, scale: String(0.7 + 0.3 * o) }}>
                <Tile k={r.k} v={r.v} size={size} seed={i} glow={r.v ? videosOn : photosOn} play={r.v ? 0.3 + 0.7 * videosOn : 0} />
              </div>
            );
          })}
        </div>
      </div>
      <div style={{ position: "absolute", ...head, fontFamily, fontWeight: 800, color: C.ink, letterSpacing: -1.5 * u }}>
        <div style={{ fontSize: (portrait ? 118 : square ? 84 : 120) * u, lineHeight: 1, scale: String(tripIn), transformOrigin: portrait ? "50% 50%" : "0% 50%" }}>Trip&rsquo;s over!</div>
        <div style={{ fontSize: (portrait ? 64 : square ? 46 : 62) * u, lineHeight: 1.15, marginTop: 18 * u, color: "#5B5375" }}>
          <span style={{ opacity: ip(f, T.half1 - 4, T.half1 + 4) }}>Half </span>
          <span style={{ opacity: photosOn, display: "inline-block", scale: String(0.6 + 0.4 * photosOn) }}>
            <P c={C.purple}>photos</P>,
          </span>{" "}
          <span style={{ opacity: ip(f, T.half2 - 4, T.half2 + 4) }}>half </span>
          <span style={{ opacity: videosOn, display: "inline-block", scale: String(0.6 + 0.4 * videosOn), rotate: `${Math.sin(f / 3) * 3 * videosOn}deg` }}>
            <P c={C.pink}>videos</P>
          </span>
        </div>
      </div>
    </AbsoluteFill>
  );
};

// ---------------------------------------------------------------- two separate posts -> not anymore

const PostCard: React.FC<{ w: number; handle: string; children: React.ReactNode; foot: string }> = ({ w, handle, children, foot }) => {
  const { u } = useLayout();
  return (
    <div style={{ width: w, borderRadius: 28 * u, background: "#fff", overflow: "hidden", boxShadow: `0 ${30 * u}px ${70 * u}px rgba(43,20,92,0.28)`, fontFamily }}>
      <div style={{ display: "flex", alignItems: "center", gap: 12 * u, padding: `${14 * u}px ${18 * u}px` }}>
        <div style={{ width: 40 * u, height: 40 * u, borderRadius: "50%", background: `linear-gradient(135deg, ${C.coral}, ${C.pink}, ${C.purple})` }} />
        <div style={{ fontWeight: 800, fontSize: 22 * u, color: C.ink }}>{handle}</div>
      </div>
      {children}
      <div style={{ padding: `${12 * u}px ${18 * u}px ${16 * u}px`, fontWeight: 800, fontSize: 22 * u, color: "#8a8399" }}>{foot}</div>
    </div>
  );
};

export const SplitScene: React.FC = () => {
  const f = useCurrentFrame();
  const { portrait, square, u, width, height } = useLayout();
  const a = T.that - 4;
  const crash = T.not;
  const end = T.cm1 - 4;
  if (f < a - 2 || f > end + 16) return null;
  const inP = ip(f, a, a + 18);
  const c = ip(f, crash - 4, crash + 6, 0, 1, Easing.in(Easing.cubic));
  const out = ip(f, end, end + 14, 0, 1, Easing.in(Easing.cubic));
  const w = (portrait ? 430 : square ? 330 : 380) * u;
  const cy = portrait ? height * 0.5 : height / 2 + 40 * u;
  const spread = (portrait ? 30 : square ? 40 : 120) * u * (1 - c);
  const shake = pulse(f, crash + 4, 10) * 18 * u;
  const stamp = ip(f, crash, crash + 10, 0, 1, POP);
  const burst = ip(f, T.anymore, T.anymore + 24);
  const cardH = w * 1.25 + 130 * u;
  return (
    <AbsoluteFill style={{ opacity: 1 - out, translate: `${Math.sin(f * 2.1) * shake}px ${Math.cos(f * 1.7) * shake}px` }}>
      <div style={{ position: "absolute", left: 0, right: 0, top: (portrait ? 170 : square ? 70 : 80) * u, textAlign: "center", fontFamily, fontWeight: 800, fontSize: (portrait ? 76 : square ? 60 : 76) * u, color: C.ink, letterSpacing: -1.5 * u, opacity: inP * (1 - c) }}>
        <P c={C.coral}>Two</P> separate posts&nbsp;😩
      </div>
      <div style={{ position: "absolute", left: width / 2 - w - spread + w * 0.5 * c, top: cy - cardH / 2, opacity: inP, translate: `${(1 - inP) * -260 * u}px 0px`, rotate: `${-5 + c * 5}deg`, scale: String(1 - c * 0.2) }}>
        <PostCard w={w} handle="📷 photo.dump" foot="1 / 14 · 3 likes">
          <div style={{ width: w, height: w * 1.25, position: "relative" }}>
            <Img src={staticFile("travel/santorini-domes.jpg")} style={{ width: "100%", height: "100%", objectFit: "cover" }} />
          </div>
        </PostCard>
      </div>
      <div style={{ position: "absolute", left: width / 2 + spread - w * 0.5 * c, top: cy - cardH / 2, opacity: inP, translate: `${(1 - inP) * 260 * u}px 0px`, rotate: `${5 - c * 5}deg`, scale: String(1 - c * 0.2) }}>
        <PostCard w={w} handle="🎬 video.reel" foot="▶ 0:48 · 5 likes">
          <div style={{ width: w, height: w * 1.25, position: "relative", overflow: "hidden" }}>
            <Moving kind="golden-wave" f={f} seed={2} playing={1} />
          </div>
        </PostCard>
      </div>
      <Sticker at={T.separate} out={crash - 4} text="+ another post…" bg={C.gold} tilt={-6} size={44} style={{ left: width / 2 - 170 * u, top: cy + cardH / 2 - 10 * u }} />
      {/* NOT ANYMORE stamp */}
      <div style={{ position: "absolute", left: 0, right: 0, top: cy - 110 * u, display: "flex", justifyContent: "center", opacity: stamp, scale: String(2.2 - 1.2 * stamp), rotate: "-7deg" }}>
        <div style={{ padding: `${18 * u}px ${44 * u}px`, borderRadius: 30 * u, background: `linear-gradient(135deg, ${C.purple}, ${C.pink})`, color: "#fff", fontFamily, fontWeight: 800, fontSize: (portrait ? 120 : 110) * u, letterSpacing: -2 * u, boxShadow: `0 ${24 * u}px ${60 * u}px rgba(109,79,214,0.5)`, whiteSpace: "nowrap" }}>
          Not anymore!
        </div>
      </div>
      {burst > 0 && burst < 1
        ? Array.from({ length: 18 }).map((_, i) => {
            const ang = (i / 18) * Math.PI * 2;
            const r = burst * (portrait ? 620 : 560) * u;
            return (
              <div key={i} style={{ position: "absolute", left: width / 2 + Math.cos(ang) * r, top: cy + Math.sin(ang) * r * 0.8, fontSize: (30 + (i % 3) * 12) * u, opacity: 1 - burst, rotate: `${i * 40 + burst * 200}deg` }}>
                {["✦", "📷", "🎬", "✨"][i % 4]}
              </div>
            );
          })
        : null}
    </AbsoluteFill>
  );
};

// ---------------------------------------------------------------- the editor phone

export const PhoneStage: React.FC = () => {
  const f = useCurrentFrame();
  const { u } = useLayout();
  const spot = usePhoneSpot();
  const enter = T.cm1 - 6;
  const exit = T.reels - 6;
  if (f < enter || f > exit + 24) return null;
  const rise = ip(f, enter, enter + 26);
  const leave = ip(f, exit, exit + 18, 0, 1, Easing.in(Easing.cubic));
  // lean in on the collage while clips play, back for the panels
  const zoom = steps(f, 1, [[T.plays - 6, 1.12], [T.trim - 8, 1.04], [T.shot - 6, 1.1], [T.add - 6, 1.02], [T.exp - 4, 1.06]], 16, SOFT);
  const oy = steps(f, 30, [[T.trim - 8, 78], [T.shot - 6, 40], [T.add - 6, 30], [T.exp - 4, 70]], 16, SOFT);
  const bob = Math.sin(f / 40) * 6 * u;
  return (
    <div style={{ position: "absolute", left: spot.cx - spot.w / 2, top: spot.top + bob + (1 - rise) * 800 * u - leave * 160 * u, perspective: 2400 * u, opacity: rise * (1 - leave), filter: `blur(${leave * 14 * u}px)` }}>
      <div style={{ transform: `rotateX(${(1 - rise) * 30}deg) rotateY(${Math.sin(f / 90) * 4}deg) rotateZ(${(1 - rise) * -8}deg)`, scale: String(zoom * (0.82 + 0.18 * rise) * (1 - leave * 0.3)), transformOrigin: `50% ${oy}%` }}>
        <EditorPhone width={spot.w} />
      </div>
    </div>
  );
};

const Headline: React.FC<{ at: number; out: number; children: React.ReactNode; sub?: React.ReactNode }> = ({ at, out, children, sub }) => {
  const f = useCurrentFrame();
  const { portrait, square, u, L } = useLayout();
  if (f < at - 2 || f > out + 16) return null;
  return (
    <Air
      inAt={at}
      outAt={out - 6}
      dur={14}
      from={portrait ? [0, 40] : [-60, 0]}
      style={portrait ? { position: "absolute", left: 40 * u, right: 40 * u, top: 110 * u, textAlign: "center" } : { position: "absolute", left: L.leftX, top: (square ? 200 : 270) * u, width: L.colW }}
    >
      <div style={{ fontFamily, fontWeight: 800, fontSize: (portrait ? 78 : square ? 64 : 94) * u, lineHeight: 1.04, color: C.ink, letterSpacing: -1.5 * u }}>{children}</div>
      {sub ? <div style={{ fontFamily, fontWeight: 600, fontSize: (portrait ? 36 : square ? 30 : 40) * u, color: "#5B5375", marginTop: 14 * u }}>{sub}</div> : null}
    </Air>
  );
};

const Wobble: React.FC<{ c: string; children: React.ReactNode }> = ({ c, children }) => {
  const f = useCurrentFrame();
  return <span style={{ color: c, display: "inline-block", rotate: `${Math.sin(f / 2.5) * 4}deg`, translate: `0px ${Math.sin(f / 3) * 3}px` }}>{children}</span>;
};

export const Headlines: React.FC = () => {
  const f = useCurrentFrame();
  return (
    <AbsoluteFill>
      <Headline at={T.same - 4} out={T.drop - 4} sub="Photos and videos, together">
        One <P c={C.purple}>collage</P>.
      </Headline>
      <Headline at={T.drop - 4} out={T.beach - 4} sub={<span style={{ opacity: ip(f, T.two1 - 4, T.two1 + 4) }}>…and up to 2 videos 🎬</span>}>
        Drop in <P c={C.purple}>photos</P>
      </Headline>
      <Headline at={T.beach - 4} out={T.moving - 4}>
        Clips <P c={C.pink}>play</P>. Photos stay <P c={C.purple}>still</P>.
      </Headline>
      <Headline at={T.moving - 4} out={T.trim - 4} sub="side by side">
        <Wobble c={C.pink}>Moving</Wobble> &amp; <P c={C.purple}>still</P>
      </Headline>
      <Headline at={T.trim - 4} out={T.pick - 4}>
        <P c={C.pink}>Trim</P> each clip ✂️
      </Headline>
      <Headline at={T.pick - 4} out={T.keep - 4}>
        Pick the <P c={C.gold}>exact moment</P>
      </Headline>
      <Headline at={T.keep - 4} out={T.shot - 4} sub="Keep the waves · mute the wind">
        Mix the <P c={C.teal}>sound</P> + music
      </Headline>
      <Headline at={T.shot - 4} out={T.fit - 4}>
        Shot in <P c={C.coral}>portrait</P>?
      </Headline>
      <Headline at={T.fit - 4} out={T.add - 4} sub="Soft blurred sides · nothing cut off">
        <P c={C.purple}>Fit</P> the whole picture
      </Headline>
      <Headline at={T.add - 4} out={T.exp - 4}>
        Add a <P c={C.pink}>caption</P>
      </Headline>
      <Headline at={T.exp - 4} out={T.reels - 4} sub="HD · 60 fps">
        Export a <P c={C.purple}>smooth video</P>
      </Headline>
    </AbsoluteFill>
  );
};

/** Feature stickers that pop around the phone as the voice names them. */
export const Callouts: React.FC = () => {
  const { portrait, square, u, width } = useLayout();
  const spot = usePhoneSpot();
  const leftOf = (y: number) => (portrait ? { left: 24 * u, top: spot.top + y * spot.h } : { right: width - (spot.cx - spot.w / 2) + (square ? -60 : 10) * u, top: spot.top + y * spot.h });
  const rightOf = (y: number) => (portrait ? { right: 24 * u, top: spot.top + y * spot.h } : { left: spot.cx + spot.w / 2 + (square ? -80 : 10) * u, top: spot.top + y * spot.h });
  const size = portrait ? 40 : square ? 30 : 38;
  return (
    <AbsoluteFill style={{ zIndex: 5 }}>
      <Sticker at={T.videos1} out={T.moving - 4} text="🎬 2 videos" bg={C.pink} color="#fff" tilt={5} size={size} style={rightOf(0.12)} />
      <Sticker at={T.photos1} out={T.moving - 4} text="📷 photos" bg="#fff" tilt={-5} size={size} style={leftOf(0.36)} />
      <Sticker at={T.plays} out={T.trim - 6} text="▶ plays live" bg={C.purple} color="#fff" tilt={-4} size={size} style={leftOf(0.16)} />
      <Sticker at={T.waves} out={T.shot - 6} text="🌊 keep the waves" bg="#fff" tilt={-5} size={size} style={leftOf(0.58)} />
      <Sticker at={T.mute} out={T.shot - 6} text="🔇 mute the wind" bg={C.ink} color="#fff" tilt={4} size={size} style={rightOf(0.66)} />
      <Sticker at={T.song} out={T.shot - 6} text="♪ add a song" bg={C.teal} color="#fff" tilt={-3} size={size} style={leftOf(0.76)} />
      <Sticker at={T.fit + 2} out={T.add - 6} text="✨ NEW: Fit + blur" bg={C.gold} tilt={-6} size={size} style={rightOf(0.2)} />
      <Sticker at={T.smooth} out={T.reels - 6} text="60 fps ⚡" bg={C.purple} color="#fff" tilt={5} size={size} style={rightOf(0.5)} />
    </AbsoluteFill>
  );
};

// ---------------------------------------------------------------- reels, stories, tiktok

const PLATFORMS = [
  { name: "Reels", icon: "🎞️", at: () => T.reels, col: C.pink },
  { name: "Stories", icon: "⭕", at: () => T.stories, col: C.purple },
  { name: "TikTok", icon: "♪", at: () => T.tiktok, col: C.ink },
];

export const PlatformScene: React.FC = () => {
  const f = useCurrentFrame();
  const { portrait, square, u, width, height } = useLayout();
  const a = T.reels - 8;
  const end = T.photos2 - 6;
  if (f < a || f > end + 16) return null;
  const out = ip(f, end, end + 14, 0, 1, Easing.in(Easing.cubic));
  const fw = (portrait ? 300 : square ? 230 : 280) * u;
  const fh = (fw * 16) / 9;
  const gap = (portrait ? 30 : 60) * u;
  const total = 3 * fw + 2 * gap;
  const cy = portrait ? height * 0.52 : height / 2 + 20 * u;
  return (
    <AbsoluteFill style={{ opacity: 1 - out, filter: `blur(${out * 12 * u}px)` }}>
      <Air inAt={a} from={[0, 40]} style={{ position: "absolute", left: 0, right: 0, top: (portrait ? 170 : square ? 50 : 40) * u, textAlign: "center", fontFamily, fontWeight: 800, fontSize: (portrait ? 80 : square ? 60 : 78) * u, color: C.ink, letterSpacing: -1.5 * u }}>
        Ready for <P c={C.purple}>every feed</P>
      </Air>
      {PLATFORMS.map((p, i) => {
        const at = p.at() - 4;
        const pop = ip(f, at, at + 14, 0, 1, POP);
        const x = width / 2 - total / 2 + i * (fw + gap);
        const cw = fw * 0.9;
        const ch = cw * 1.25;
        return (
          <div key={p.name} style={{ position: "absolute", left: x, top: cy - fh / 2 + Math.sin(f / 25 + i) * 8 * u, width: fw, height: fh, opacity: pop, scale: String(0.5 + 0.5 * pop), rotate: `${(i - 1) * 4 * (2 - pop)}deg` }}>
            <div style={{ position: "absolute", inset: 0, borderRadius: 30 * u, background: "#0f0b18", border: `${6 * u}px solid #1d1726`, boxShadow: `0 ${24 * u}px ${50 * u}px rgba(43,20,92,0.3), 0 0 0 ${4 * u * pulse(f, at + 4, 16)}px ${p.col}`, overflow: "hidden" }}>
              <div style={{ position: "absolute", left: (fw - cw) / 2 - 6 * u, top: (fh - ch) / 2 - 6 * u }}>
                <Collage w={cw} h={ch} s={{ caption: 99, badges: false, fit: 1, sides: 1 }} />
              </div>
              <div style={{ position: "absolute", right: 10 * u, bottom: fh * 0.18, display: "flex", flexDirection: "column", gap: 14 * u, color: "#fff", fontSize: 26 * u, textAlign: "center" }}>
                <div>♥</div>
                <div>💬</div>
                <div>↗</div>
              </div>
            </div>
            <div style={{ position: "absolute", left: 0, right: 0, top: fh + 18 * u, display: "flex", justifyContent: "center" }}>
              <div style={{ padding: `${8 * u}px ${22 * u}px`, borderRadius: 30 * u, background: p.col, color: "#fff", fontFamily, fontWeight: 800, fontSize: 34 * u }}>
                {p.icon} {p.name}
              </div>
            </div>
          </div>
        );
      })}
    </AbsoluteFill>
  );
};

// ---------------------------------------------------------------- photos and videos, one collage

export const FinalScene: React.FC = () => {
  const f = useCurrentFrame();
  const { portrait, square, u, width, height } = useLayout();
  const a = T.photos2 - 8;
  const end = T.cm2 - 4;
  if (f < a || f > end + 16) return null;
  const inP = ip(f, a, a + 18, 0, 1, POP);
  const out = ip(f, end, end + 14, 0, 1, Easing.in(Easing.cubic));
  const cw = (portrait ? 700 : square ? 400 : 440) * u;
  const ch = cw * 1.25;
  const cx = width / 2;
  const cy = portrait ? height * 0.47 : height / 2 - 40 * u;
  const pIn = ip(f, T.photos2 - 4, T.photos2 + 10, 0, 1, POP);
  const vIn = ip(f, T.videos2 - 4, T.videos2 + 10, 0, 1, POP);
  const merge = ip(f, T.one - 4, T.one + 10, 0, 1, SOFT);
  const one = ip(f, T.one, T.one + 14, 0, 1, POP);
  const chipX = (portrait ? 230 : square ? 330 : 470) * u * (1 - merge);
  const chip = (text: string, bg: string, x: number, p: number, rot: number) => (
    <div style={{ position: "absolute", left: cx + x, top: cy - 30 * u, translate: "-50% 0", padding: `${14 * u}px ${30 * u}px`, borderRadius: 40 * u, background: bg, color: "#fff", fontFamily, fontWeight: 800, fontSize: 44 * u, whiteSpace: "nowrap", opacity: p * (1 - merge), scale: String(p), rotate: `${rot}deg`, boxShadow: `0 ${16 * u}px ${36 * u}px rgba(43,20,92,0.3)`, zIndex: 3 }}>
      {text}
    </div>
  );
  return (
    <AbsoluteFill style={{ opacity: 1 - out, filter: `blur(${out * 12 * u}px)` }}>
      <div style={{ position: "absolute", left: cx - cw / 2, top: cy - ch / 2, scale: String(0.6 + 0.4 * inP), rotate: `${(1 - inP) * -8 + Math.sin(f / 30) * 1}deg`, boxShadow: `0 ${40 * u}px ${90 * u}px rgba(43,20,92,0.35), 0 0 0 ${8 * u}px #fff`, borderRadius: 18 * u }}>
        <Collage w={cw} h={ch} s={{ caption: one > 0.1 ? 99 : -1, fit: 1, sides: 1, tags: win(f, T.photos2 - 2, T.one - 4, 6) }} />
      </div>
      {chip("📷 Photos", C.purple, -chipX, pIn, -6)}
      {chip("🎬 Videos", C.pink, chipX, vIn, 6)}
      <div style={{ position: "absolute", left: 0, right: 0, top: cy + ch / 2 + (portrait ? 40 : 18) * u, display: "flex", justifyContent: "center", opacity: one, scale: String(0.5 + 0.5 * one), zIndex: 4 }}>
        <div style={{ padding: `${16 * u}px ${44 * u}px`, borderRadius: 50 * u, background: `linear-gradient(135deg, ${C.purple}, ${C.pink})`, color: "#fff", fontFamily, fontWeight: 800, fontSize: (portrait ? 64 : 52) * u, boxShadow: `0 ${20 * u}px ${50 * u}px rgba(109,79,214,0.45)` }}>
          = One collage ✨
        </div>
      </div>
      {one > 0
        ? Array.from({ length: 22 }).map((_, i) => {
            const life = ip(f, T.one + (i % 5), T.one + 34 + (i % 5), 0, 1, Easing.out(Easing.quad));
            const ang = (i / 22) * Math.PI * 2;
            const r = life * (portrait ? 560 : 520) * u;
            return (
              <div key={i} style={{ position: "absolute", left: cx + Math.cos(ang) * r, top: cy + Math.sin(ang) * r - life * 60 * u, width: 16 * u, height: 26 * u, borderRadius: 4 * u, background: [C.pink, C.gold, C.purple, C.teal][i % 4], opacity: 1 - life, rotate: `${i * 47 + life * 300}deg` }} />
            );
          })
        : null}
    </AbsoluteFill>
  );
};

// ---------------------------------------------------------------- end card

const ORBIT: { k: PhotoKind; v?: boolean }[] = [
  { k: "golden-wave", v: true },
  { k: "santorini-sunset" },
  { k: "venice-canal", v: true },
  { k: "pizza" },
  { k: "aurora-reine", v: true },
  { k: "positano" },
  { k: "turquoise", v: true },
  { k: "balloons" },
];

export const EndScene: React.FC = () => {
  const f = useCurrentFrame();
  const { u, portrait, square, width, height, L } = useLayout();
  const a = T.cm2 - 2;
  if (f < a - 2) return null;
  const p = interpolate(f, [a, a + 22], [0, 1], { ...clamp, easing: Easing.bezier(0.34, 1.4, 0.64, 1) });
  const bob = Math.sin(f / 30) * 10 * u;
  const cy = portrait ? height * 0.36 : height * 0.27;
  return (
    <AbsoluteFill>
      {ORBIT.map((o, i) => {
        const ang = (i / ORBIT.length) * Math.PI * 2 + f / 70;
        const r = (portrait ? 400 : square ? 400 : 560) * u;
        const s = 130 * u;
        return (
          <div key={i} style={{ position: "absolute", left: width / 2 + Math.cos(ang) * r * p - s / 2, top: cy + Math.sin(ang) * r * 0.34 * p - s / 2, width: s, height: s, borderRadius: 24 * u, overflow: "hidden", border: `${5 * u}px solid ${o.v ? C.pink : "#fff"}`, opacity: 0.95 * p, scale: String(p * (0.78 + 0.22 * Math.sin(ang))), zIndex: Math.sin(ang) > 0 ? 2 : 0, boxShadow: `0 ${12 * u}px ${26 * u}px rgba(43,20,92,0.25)` }}>
            {o.v ? <Moving kind={o.k} f={f} seed={i} playing={1} /> : <Img src={staticFile(`travel/thumb/${o.k}.jpg`)} style={{ width: "100%", height: "100%", objectFit: "cover" }} />}
            {o.v ? <div style={{ position: "absolute", left: 6 * u, bottom: 6 * u, color: "#fff", fontSize: 20 * u, fontWeight: 800 }}>▶</div> : null}
          </div>
        );
      })}
      <div style={{ position: "absolute", left: width / 2 - 150 * u, top: cy - 150 * u + bob, width: 300 * u, height: 300 * u, scale: String(p), zIndex: 1 }}>
        <Img src={staticFile("brand/icon.png")} style={{ width: "100%", height: "100%", borderRadius: 68 * u, boxShadow: `0 ${30 * u}px ${70 * u}px rgba(109,79,214,0.45)` }} />
      </div>
      <Air inAt={a + 6} from={[0, 40]} style={{ position: "absolute", left: 0, right: 0, top: cy + 220 * u, textAlign: "center", fontFamily, zIndex: 3 }}>
        <div style={{ fontWeight: 800, fontSize: 124 * u, color: C.ink, letterSpacing: -2 * u, lineHeight: 1 }}>
          Collage<P c={C.purple}>Magik</P>
        </div>
        <div style={{ fontWeight: 600, fontSize: 40 * u, color: "#5B5375", marginTop: 16 * u }}>Photos + videos in one collage</div>
      </Air>
      <Sticker
        at={T.free}
        text="Free 🎉"
        bg={C.gold}
        tilt={-8}
        size={58}
        style={portrait ? { left: 90 * u, top: cy - 280 * u, zIndex: 3 } : square ? { right: L.edge + 40 * u, top: cy - 270 * u, zIndex: 3 } : { left: width / 2 + 210 * u, top: cy - 240 * u, zIndex: 3 }}
      />
      <Air inAt={T.free - 6} from={[0, 50]} style={{ position: "absolute", left: 0, right: 0, top: cy + (portrait ? 480 : 440) * u, display: "flex", justifyContent: "center", zIndex: 3 }}>
        <div style={{ scale: String(1 + Math.max(0, Math.sin((f - T.store) / 7)) * 0.05 * (f >= T.store ? 1 : 0)) }}>
          <StoreButton s={u * (portrait ? 1 : 0.95)} />
        </div>
      </Air>
    </AbsoluteFill>
  );
};

/** App name pill as the app is first named. */
export const IntroBadge: React.FC = () => {
  const { portrait, u, width, L } = useLayout();
  return <AppBadge at={T.cm1 - 4} out={T.same - 10} scale={portrait ? 1 : 0.9} sub="Photos + videos, one collage" style={portrait ? { left: width / 2 - 300 * u, top: 120 * u } : { left: L.leftX, top: 110 * u }} />;
};

