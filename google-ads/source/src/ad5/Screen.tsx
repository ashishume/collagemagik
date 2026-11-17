import React from "react";
import { Easing, Img, staticFile, useCurrentFrame } from "remotion";
import type { PhotoKind } from "../ad/TripPhoto";
import { C, fontFamily, SOFT } from "../ad/theme";
import { F } from "../ad4/fonts";
import { CAPTION, CELLS, Collage, PORTRAIT } from "./Collage";
import { T } from "./cues";
import { ip, POP, pulse, steps, tapAt, Touch, TouchP, win } from "./kit";

/**
 * The CollageMagik editor as it looks in v5, drawn live in screen units (400 wide, the phone's aspect): photos and two
 * videos dropped into one collage, the clips playing next to still photos, trimming, choosing the part, sound and music,
 * the new Resize tool fitting a portrait photo with blurred sides, a caption and a smooth video export.
 */
export const SW = 400;
export const SH = (400 * 2868) / 1320;

const CV = { x: 24, y: 118, w: 352, h: 440 };
const PANEL = { x: 12, y: 590, w: 376, h: 206 };

const TRAY: { k: PhotoKind; video?: boolean }[] = [
  { k: "santorini-sunset" },
  { k: "positano" },
  { k: "golden-wave", video: true },
  { k: "venice-canal", video: true },
  { k: "pizza" },
];
/** Which tray tile fills each cell. */
const FROM_TRAY = [0, 2, 3, 1];
const thumb = (i: number) => ({ x: 107 + i * 56, y: 659 });
/** When each cell's picture flies in: photos on "photos", the two videos on "two videos". */
const flyAt = (i: number) => [T.photos1 - 4, T.two1 - 2, T.videos1 + 4, T.photos1 + 6][i];

const cellRect = (i: number) => {
  const c = CELLS[i];
  const g = 5;
  return {
    x: CV.x + g + c.x * (CV.w - g),
    y: CV.y + g + c.y * (CV.h - g),
    w: c.w * (CV.w - g) - g,
    h: c.h * (CV.h - g) - g,
  };
};
const mid = (r: { x: number; y: number; w: number; h: number }) => ({ x: r.x + r.w / 2, y: r.y + r.h / 2 });

type Panel = "media" | "timeline" | "sound" | "picture" | "text";
const panelAt = (f: number): Panel =>
  f < T.trim - 6 ? "media" : f < T.keep - 6 ? "timeline" : f < T.shot - 4 ? "sound" : f < T.add - 6 ? "picture" : "text";

const Txt: React.FC<{ x: number; y: number; size?: number; color?: string; weight?: number; children: React.ReactNode; style?: React.CSSProperties }> = ({
  x,
  y,
  size = 12,
  color = "rgba(255,255,255,0.72)",
  weight = 600,
  children,
  style,
}) => <div style={{ position: "absolute", left: x, top: y, fontSize: size, color, fontWeight: weight, whiteSpace: "nowrap", ...style }}>{children}</div>;

const Glass: React.FC<{ style: React.CSSProperties; on?: number; children?: React.ReactNode }> = ({ style, on = 0, children }) => (
  <div
    style={{
      position: "absolute",
      background: on > 0 ? `rgba(139,108,255,${0.35 + 0.5 * on})` : "rgba(255,255,255,0.09)",
      border: "1px solid rgba(255,255,255,0.16)",
      boxShadow: "inset 0 1px 0 rgba(255,255,255,0.12)",
      ...style,
    }}
  >
    {children}
  </div>
);

// ---------------------------------------------------------------- panels

const MediaPanel: React.FC<{ f: number }> = ({ f }) => {
  const used = [0, 1, 2, 3].filter((c) => f >= flyAt(c) + 8).map((c) => FROM_TRAY[c]);
  const vids = used.filter((t) => TRAY[t].video).length;
  return (
    <>
      <Txt x={14} y={14} size={11.5}>
        {TRAY.length} in tray · {used.length} of 9 in collage · <span style={{ color: vids ? "#fff" : undefined, fontWeight: vids ? 800 : 600 }}>{vids} of 2 videos</span>
      </Txt>
      <Glass style={{ left: 12, top: 44, width: 52, height: 52, borderRadius: 14, background: "rgba(139,108,255,0.6)" }}>
        <div style={{ textAlign: "center", color: "#fff", fontWeight: 800, fontSize: 22, marginTop: 6 }}>+</div>
        <div style={{ textAlign: "center", color: "#fff", fontWeight: 700, fontSize: 9, marginTop: -4 }}>Add</div>
      </Glass>
      {TRAY.map((t, i) => {
        const p = thumb(i);
        const on = used.includes(i);
        return (
          <div key={i} style={{ position: "absolute", left: p.x - 25 - PANEL.x, top: 44, width: 50, height: 50, borderRadius: 14, overflow: "hidden", border: on ? `2.5px solid ${C.purple}` : "1px solid rgba(255,255,255,0.15)", boxSizing: "border-box" }}>
            <Img src={staticFile(`travel/thumb/${t.k}.jpg`)} style={{ width: "100%", height: "100%", objectFit: "cover" }} />
            {t.video ? (
              <div style={{ position: "absolute", left: 3, bottom: 3, padding: "1px 4px", borderRadius: 6, background: "rgba(0,0,0,0.6)", color: "#fff", fontSize: 8, fontWeight: 800 }}>🎬 0:12</div>
            ) : null}
          </div>
        );
      })}
      <Txt x={14} y={110} size={10.5} color="rgba(255,255,255,0.55)">
        Photos and videos go in the same collage
      </Txt>
      <Glass style={{ left: 14, top: 140, width: 348, height: 44, borderRadius: 22 }}>
        <Txt x={16} y={14} size={12} color="rgba(255,255,255,0.8)">
          ▶ Tap a video to trim it and pick its sound
        </Txt>
      </Glass>
    </>
  );
};

const lanes = [
  { name: "Beach clip", kind: "golden-wave" as PhotoKind, color: C.pink },
  { name: "Canal clip", kind: "venice-canal" as PhotoKind, color: "#4CC3FF" },
];

const TimelinePanel: React.FC<{ f: number }> = ({ f }) => {
  const a = ip(f, T.trim + 2, T.trim + 14, 0, 0.18, SOFT);
  const b = ip(f, T.trim + 8, T.trim + 20, 1, 0.78, SOFT);
  const pick = ip(f, T.pick - 2, T.moment + 4, 0.15, 0.62, Easing.inOut(Easing.quad));
  const chosen = ip(f, T.moment, T.moment + 8, 0, 1, POP);
  return (
    <>
      <Glass style={{ left: 12, top: 10, width: 180, height: 30, borderRadius: 15 }} on={1}>
        <Txt x={0} y={8} size={11.5} color="#fff" weight={800} style={{ width: 180, textAlign: "center" }}>
          ✂ Timeline
        </Txt>
      </Glass>
      <Glass style={{ left: 196, top: 10, width: 168, height: 30, borderRadius: 15 }}>
        <Txt x={0} y={8} size={11.5} style={{ width: 168, textAlign: "center" }}>
          🔊 Sound
        </Txt>
      </Glass>
      {lanes.map((l, i) => {
        const y = 52 + i * 40;
        const L = i === 0 ? a : 0.05;
        const R = i === 0 ? b : 0.92;
        const x0 = 76;
        const W = 286;
        return (
          <div key={i}>
            <Txt x={14} y={y + 9} size={10.5} color="rgba(255,255,255,0.75)">
              {l.name}
            </Txt>
            <div style={{ position: "absolute", left: x0, top: y, width: W, height: 32, borderRadius: 8, background: "rgba(255,255,255,0.06)" }} />
            <div style={{ position: "absolute", left: x0 + L * W, top: y, width: (R - L) * W, height: 32, borderRadius: 8, overflow: "hidden", border: `2px solid ${l.color}`, boxSizing: "border-box", display: "flex" }}>
              {Array.from({ length: 7 }).map((_, k) => (
                <Img key={k} src={staticFile(`travel/thumb/${l.kind}.jpg`)} style={{ flex: 1, height: "100%", objectFit: "cover", objectPosition: `${k * 15}% 50%`, opacity: 0.85 }} />
              ))}
              {i === 0 ? (
                <>
                  <div style={{ position: "absolute", left: 0, top: 0, bottom: 0, width: 9, background: l.color }} />
                  <div style={{ position: "absolute", right: 0, top: 0, bottom: 0, width: 9, background: l.color }} />
                </>
              ) : null}
            </div>
          </div>
        );
      })}
      {/* choose part: the playhead scrubs, then the moment is chosen */}
      <div style={{ opacity: win(f, T.pick - 6, T.keep, 6) }}>
        <div style={{ position: "absolute", left: 76 + pick * 286, top: 46, width: 3, height: 84, borderRadius: 2, background: C.gold, boxShadow: `0 0 10px ${C.gold}` }} />
        <div style={{ position: "absolute", left: 76 + pick * 286 - 36, top: 140, width: 72, height: 48, borderRadius: 10, overflow: "hidden", border: `2.5px solid ${C.gold}`, scale: String(0.85 + 0.15 * chosen) }}>
          <Img src={staticFile("travel/thumb/golden-wave.jpg")} style={{ width: "100%", height: "100%", objectFit: "cover", objectPosition: `${pick * 100}% 50%` }} />
        </div>
        <Txt x={14} y={152} size={11} color="#fff" weight={800} style={{ opacity: chosen }}>
          ✓ This moment
        </Txt>
      </div>
    </>
  );
};

const SoundPanel: React.FC<{ f: number }> = ({ f }) => {
  const mute = ip(f, T.mute, T.mute + 10, 0.75, 0, SOFT);
  const music = ip(f, T.song - 4, T.song + 10, 0, 1, POP);
  const wave = (n: number, k: number, amp: number, color: string) => (
    <div style={{ display: "flex", alignItems: "center", gap: 2, height: 22 }}>
      {Array.from({ length: n }).map((_, i) => (
        <div key={i} style={{ width: 3, borderRadius: 2, background: color, height: 3 + Math.abs(Math.sin(i * 0.9 + f / (k + 3))) * amp }} />
      ))}
    </div>
  );
  const row = (y: number, icon: string, name: string, v: number, color: string, extra?: React.ReactNode) => (
    <div style={{ position: "absolute", left: 14, top: y, width: 348, height: 36 }}>
      <Txt x={0} y={9} size={14}>
        {icon}
      </Txt>
      <Txt x={26} y={10} size={11} color="rgba(255,255,255,0.8)">
        {name}
      </Txt>
      <div style={{ position: "absolute", left: 120, top: 7 }}>{wave(16, 4, 16 * v + 1, color)}</div>
      <div style={{ position: "absolute", left: 236, top: 16, width: 90, height: 4, borderRadius: 2, background: "rgba(255,255,255,0.2)" }}>
        <div style={{ width: `${v * 100}%`, height: "100%", borderRadius: 2, background: color }} />
        <div style={{ position: "absolute", left: v * 90 - 8, top: -6, width: 16, height: 16, borderRadius: 8, background: "#fff" }} />
      </div>
      {extra}
    </div>
  );
  return (
    <>
      <Glass style={{ left: 12, top: 10, width: 180, height: 30, borderRadius: 15 }}>
        <Txt x={0} y={8} size={11.5} style={{ width: 180, textAlign: "center" }}>
          ✂ Timeline
        </Txt>
      </Glass>
      <Glass style={{ left: 196, top: 10, width: 168, height: 30, borderRadius: 15 }} on={1}>
        <Txt x={0} y={8} size={11.5} color="#fff" weight={800} style={{ width: 168, textAlign: "center" }}>
          🔊 Sound
        </Txt>
      </Glass>
      {row(50, "🌊", "Beach · waves", 1, C.pink, <Txt x={334} y={9} size={13}>🔊</Txt>)}
      {row(90, "💨", "Canal · wind", mute, "#4CC3FF", <Txt x={334} y={9} size={13}>{mute < 0.05 ? "🔇" : "🔉"}</Txt>)}
      {music > 0.02 ? (
        <div style={{ scale: String(music), transformOrigin: "20% 50%" }}>{row(130, "♪", "Golden hour", 0.7, C.teal, <Txt x={334} y={9} size={13}>🎵</Txt>)}</div>
      ) : (
        <Glass style={{ left: 14, top: 134, width: 140, height: 32, borderRadius: 16 }}>
          <Txt x={18} y={9} size={11.5} color="#fff" weight={700}>
            ♪ Add music
          </Txt>
        </Glass>
      )}
    </>
  );
};

const TOOLS = [
  ["Change", "⊕"],
  ["Swap", "⇄"],
  ["Resize", "⤢"],
  ["Rotate", "↻"],
  ["Flip", "⇋"],
  ["Crop", "⌗"],
  ["Delete", "✕"],
];
const toolX = (i: number) => 14 + i * 51.5;

const PicturePanel: React.FC<{ f: number }> = ({ f }) => {
  const resizeOn = f >= T.fit - 8;
  const fitOn = f >= T.fit;
  const sides = ip(f, T.blurred - 6, T.blurred + 6);
  return (
    <>
      {TOOLS.map(([n, i], k) => {
        const on = k === 2 && resizeOn ? 1 : 0;
        return (
          <Glass key={n} on={on} style={{ left: toolX(k), top: 10, width: 47, height: 46, borderRadius: 13 }}>
            <div style={{ textAlign: "center", color: k === 6 ? "#ff6b6b" : "#fff", fontSize: 16, marginTop: 6 }}>{i}</div>
            <div style={{ textAlign: "center", color: k === 6 ? "#ff6b6b" : "#fff", fontSize: 8.5, fontWeight: 700 }}>{n}</div>
          </Glass>
        );
      })}
      {k2(f, T.fit - 8)}
      <div style={{ opacity: ip(f, T.fit - 8, T.fit - 2) }}>
        <Glass on={fitOn ? 0 : 1} style={{ left: 14, top: 70, width: 110, height: 32, borderRadius: 16 }}>
          <Txt x={14} y={9} size={11.5} color="#fff" weight={700}>
            ▭ Fill cell
          </Txt>
        </Glass>
        <Glass on={fitOn ? 1 : 0} style={{ left: 130, top: 70, width: 160, height: 32, borderRadius: 16 }}>
          <Txt x={14} y={9} size={11.5} color="#fff" weight={700}>
            ▯ Fit whole picture
          </Txt>
        </Glass>
        <div style={{ position: "absolute", left: 300, top: 66, padding: "3px 8px", borderRadius: 10, background: C.gold, color: C.ink, fontSize: 10, fontWeight: 800, rotate: "6deg", scale: String(ip(f, T.fit + 2, T.fit + 12, 0, 1, POP)) }}>NEW</div>
      </div>
      <div style={{ opacity: ip(f, T.fit + 4, T.fit + 12) }}>
        <Txt x={14} y={128} size={11.5} color="rgba(255,255,255,0.6)">
          Sides
        </Txt>
        <div style={{ position: "absolute", left: 62, top: 120, width: 30, height: 30, borderRadius: 15, overflow: "hidden", boxShadow: `0 0 0 ${3 * sides}px ${C.purple}` }}>
          <Img src={staticFile("travel/thumb/positano.jpg")} style={{ width: "100%", height: "100%", objectFit: "cover", filter: "blur(3px)" }} />
        </div>
        {["#ffffff", "#101016", "#f4ecdc", "#ffd6e7", "#c9e4ff", "#d4f5dc"].map((c, i) => (
          <div key={c} style={{ position: "absolute", left: 104 + i * 38, top: 122, width: 26, height: 26, borderRadius: 13, background: c, border: "1px solid rgba(255,255,255,0.35)" }} />
        ))}
      </div>
    </>
  );
};
/** (keeps the tool row's Resize tile glowing for a moment after it is tapped) */
const k2 = (f: number, at: number) => (
  <div style={{ position: "absolute", left: toolX(2) - 4, top: 6, width: 55, height: 54, borderRadius: 16, border: `2px solid ${C.gold}`, opacity: pulse(f, at, 20), boxShadow: `0 0 14px ${C.gold}` }} />
);

const FONTS = [
  { n: "Classic", ff: fontFamily, w: 800 },
  { n: "Poster", ff: F.poster, w: 400 },
  { n: "Script", ff: F.script, w: 400 },
  { n: "Dreamy", ff: F.dreamy, w: 400 },
];
const TextPanel: React.FC<{ f: number }> = () => (
  <>
    <Glass on={1} style={{ left: 14, top: 12, width: 130, height: 32, borderRadius: 16 }}>
      <Txt x={16} y={9} size={11.5} color="#fff" weight={800}>
        + Add caption
      </Txt>
    </Glass>
    {FONTS.map((x, i) => (
      <Glass key={x.n} on={i === 3 ? 1 : 0} style={{ left: 14 + i * 88, top: 60, width: 82, height: 54, borderRadius: 14 }}>
        <div style={{ textAlign: "center", color: "#fff", fontFamily: x.ff, fontWeight: x.w, fontSize: i >= 2 ? 22 : 16, marginTop: 8 }}>Aa</div>
        <div style={{ textAlign: "center", color: "rgba(255,255,255,0.7)", fontSize: 9, fontWeight: 700 }}>{x.n}</div>
      </Glass>
    ))}
    <Txt x={14} y={134} size={10.5} color="rgba(255,255,255,0.55)">
      14 lettering styles · drag to place
    </Txt>
  </>
);

const ExportSheet: React.FC<{ f: number }> = ({ f }) => {
  const up = ip(f, T.exp - 2, T.exp + 12);
  const prog = ip(f, T.smooth - 4, T.reels - 6, 0, 1, Easing.inOut(Easing.quad));
  const saved = ip(f, T.reels - 6, T.reels + 4, 0, 1, POP);
  return (
    <div style={{ position: "absolute", left: 0, right: 0, top: SH - 330 * up, height: 330, borderRadius: "26px 26px 0 0", background: "#221b33", boxShadow: "0 -10px 30px rgba(0,0,0,0.45)", zIndex: 20 }}>
      <Txt x={0} y={18} size={15} color="#fff" weight={800} style={{ width: SW, textAlign: "center" }}>
        Export
      </Txt>
      <div style={{ position: "absolute", left: 40, top: 54, width: 320, height: 34, borderRadius: 17, background: "rgba(255,255,255,0.08)", display: "flex" }}>
        <div style={{ flex: 1, textAlign: "center", color: "rgba(255,255,255,0.6)", fontSize: 12, fontWeight: 700, paddingTop: 9 }}>Photo</div>
        <div style={{ flex: 1, textAlign: "center", color: "#fff", fontSize: 12, fontWeight: 800, paddingTop: 9, borderRadius: 17, background: C.purple }}>▶ Video</div>
      </div>
      <div style={{ position: "absolute", left: 40, top: 102, display: "flex", gap: 8 }}>
        {["HD", "60 fps", "Smooth"].map((x) => (
          <div key={x} style={{ padding: "5px 12px", borderRadius: 14, background: "rgba(255,255,255,0.1)", color: "#fff", fontSize: 11, fontWeight: 800 }}>
            {x}
          </div>
        ))}
      </div>
      <div style={{ position: "absolute", left: 40, top: 150, width: 320, height: 10, borderRadius: 5, background: "rgba(255,255,255,0.12)" }}>
        <div style={{ width: `${prog * 100}%`, height: "100%", borderRadius: 5, background: `linear-gradient(90deg, ${C.purple}, ${C.pink})` }} />
      </div>
      <Txt x={40} y={170} size={11} color="rgba(255,255,255,0.65)">
        {saved > 0.5 ? "" : `Making your video… ${Math.round(prog * 100)}%`}
      </Txt>
      <div style={{ position: "absolute", left: 0, right: 0, top: 196, textAlign: "center", color: C.teal, fontSize: 16, fontWeight: 800, scale: String(saved), opacity: saved }}>✓ Saved to Photos</div>
    </div>
  );
};

const TABS = [
  ["Media", "▣"],
  ["Layout", "▦"],
  ["Style", "◐"],
  ["Text", "Aa"],
  ["Video", "▶"],
];

// ---------------------------------------------------------------- the screen

export const EditorScreen: React.FC = () => {
  const f = useCurrentFrame();
  const panel = panelAt(f);

  // collage state
  const filled = [0, 1, 2, 3].map((i) => ip(f, flyAt(i) + 6, flyAt(i) + 14, 0, 1, POP));
  const playing = ip(f, T.plays - 4, T.plays + 6, 0.08, 1);
  const rings = [
    win(f, T.sunset - 2, T.moving - 4, 6),
    win(f, T.beach - 2, T.sunset - 4, 6),
    0,
    win(f, T.shot - 2, T.add - 8, 6),
  ];
  const tags = ip(f, T.moving - 2, T.moving + 8, 0, 1, POP) * (1 - ip(f, T.trim - 8, T.trim));
  const fit = ip(f, T.fit, T.fit + 14, 0, 1, SOFT);
  const sides = ip(f, T.fit + 4, T.blurred + 8);
  const typed = f >= T.add ? Math.ceil(ip(f, T.add + 2, T.caption + 12, 0, 1, Easing.linear) * CAPTION.length) : -1;

  // the portrait photo, filled: its hidden top and bottom shown as a ghost before it's fitted
  const pr = cellRect(PORTRAIT);
  const ghost = win(f, T.portrait - 6, T.fit + 4, 6);
  const ghostH = pr.w / (1600 / 2400);

  // touches
  const touches: TouchP[] = [];
  const push = (t: TouchP | null) => t && touches.push(t);
  for (let i = 0; i < 4; i++) {
    const s = flyAt(i);
    if (f >= s - 4 && f <= s + 12) {
      const t = ip(f, s - 2, s + 8, 0, 1, SOFT);
      const a = thumb(FROM_TRAY[i]);
      const b = mid(cellRect(i));
      touches.push({ x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t, o: win(f, s - 4, s + 8, 3), down: true });
    }
  }
  if (f >= T.trim && f <= T.trim + 24) {
    const t = ip(f, T.trim + 2, T.trim + 20, 0, 1, SOFT);
    touches.push({ x: PANEL.x + 76 + (t < 0.5 ? 0.18 * t * 2 : 0.78 + 0.22 * (1 - (t - 0.5) * 2)) * 286 + 4, y: PANEL.y + 68, o: win(f, T.trim, T.trim + 20, 4), down: true });
  }
  if (f >= T.pick - 4 && f <= T.moment + 8) {
    const x = PANEL.x + 76 + ip(f, T.pick - 2, T.moment + 4, 0.15, 0.62, Easing.inOut(Easing.quad)) * 286;
    touches.push({ x, y: PANEL.y + 120, o: win(f, T.pick - 4, T.moment + 4, 4), down: true });
  }
  if (f >= T.mute - 6 && f <= T.mute + 14) {
    touches.push({ x: PANEL.x + 14 + 236 + ip(f, T.mute, T.mute + 10, 0.75, 0, SOFT) * 90, y: PANEL.y + 90 + 18, o: win(f, T.mute - 6, T.mute + 10, 4), down: true });
  }
  push(tapAt(f, T.song - 6, PANEL.x + 80, PANEL.y + 150));
  push(tapAt(f, T.shot, mid(pr).x, mid(pr).y));
  push(tapAt(f, T.fit - 8, PANEL.x + toolX(2) + 23, PANEL.y + 33));
  push(tapAt(f, T.fit, PANEL.x + 210, PANEL.y + 86));
  push(tapAt(f, T.blurred - 4, PANEL.x + 77, PANEL.y + 135));
  push(tapAt(f, T.add - 2, PANEL.x + 80, PANEL.y + 28));
  push(tapAt(f, T.exp - 4, 330, 72));

  const tabX = steps(f, 0, [[T.trim - 6, 4], [T.add - 6, 3]], 8);
  const dockOn = 1 - win(f, T.shot - 4, T.add - 6, 6);

  return (
    <div style={{ position: "absolute", inset: 0, background: "linear-gradient(180deg,#1d1530,#120d1d)", fontFamily, overflow: "hidden" }}>
      {/* status + top bar */}
      <Txt x={34} y={16} size={14} color="#fff" weight={700}>
        9:41
      </Txt>
      <div style={{ position: "absolute", left: 150, top: 10, width: 100, height: 28, borderRadius: 14, background: "#000" }} />
      <Glass style={{ left: 14, top: 54, width: 86, height: 40, borderRadius: 20 }}>
        <Txt x={16} y={11} size={15} color="#fff">
          ↶ ↷
        </Txt>
      </Glass>
      <Glass on={1} style={{ left: 130, top: 54, width: 140, height: 40, borderRadius: 20 }}>
        <Txt x={0} y={12} size={13} color="#fff" weight={800} style={{ width: 140, textAlign: "center" }}>
          ▦ Collage
        </Txt>
      </Glass>
      <div style={{ position: "absolute", left: 306, top: 54, width: 48, height: 40, borderRadius: 20, background: C.purple, boxShadow: `0 0 0 ${pulse(f, T.exp - 4, 16) * 8}px rgba(139,108,255,0.4)` }}>
        <Txt x={0} y={10} size={15} color="#fff" weight={800} style={{ width: 48, textAlign: "center" }}>
          ⇪
        </Txt>
      </div>

      {/* the collage */}
      <div style={{ position: "absolute", left: CV.x, top: CV.y }}>
        <Collage w={CV.w} h={CV.h} s={{ filled, playing, rings, tags, fit, sides, caption: typed }} />
      </div>
      {ghost > 0 ? (
        <div
          style={{
            position: "absolute",
            left: pr.x,
            top: pr.y + pr.h / 2 - ghostH / 2,
            width: pr.w,
            height: ghostH,
            border: `2px dashed ${C.gold}`,
            borderRadius: 6,
            opacity: ghost * (1 - fit),
            background: "rgba(244,178,60,0.08)",
          }}
        >
          <div style={{ position: "absolute", left: 6, top: 6, padding: "2px 7px", borderRadius: 8, background: C.gold, color: C.ink, fontSize: 9.5, fontWeight: 800 }}>✂ cut off</div>
          <div style={{ position: "absolute", left: 6, bottom: 6, padding: "2px 7px", borderRadius: 8, background: C.gold, color: C.ink, fontSize: 9.5, fontWeight: 800 }}>✂ cut off</div>
        </div>
      ) : null}

      {/* bottom panel */}
      <Glass style={{ left: PANEL.x, top: PANEL.y, width: PANEL.w, height: PANEL.h, borderRadius: 24, background: "rgba(255,255,255,0.07)" }}>
        {panel === "media" ? <MediaPanel f={f} /> : null}
        {panel === "timeline" ? <TimelinePanel f={f} /> : null}
        {panel === "sound" ? <SoundPanel f={f} /> : null}
        {panel === "picture" ? <PicturePanel f={f} /> : null}
        {panel === "text" ? <TextPanel f={f} /> : null}
      </Glass>

      {/* dock */}
      <Glass style={{ left: 12, top: 808, width: 376, height: 50, borderRadius: 25, opacity: dockOn }}>
        <div style={{ position: "absolute", left: 4 + tabX * 73.6, top: 4, width: 70, height: 40, borderRadius: 20, background: C.purple }} />
        {TABS.map(([n, i], k) => (
          <div key={n} style={{ position: "absolute", left: 4 + k * 73.6, top: 6, width: 70, textAlign: "center", color: "#fff" }}>
            <div style={{ fontSize: 13 }}>{i}</div>
            <div style={{ fontSize: 8.5, fontWeight: 700 }}>{n}</div>
          </div>
        ))}
      </Glass>

      {f >= T.exp - 2 ? <ExportSheet f={f} /> : null}
      {touches.map((t, i) => (
        <Touch key={i} {...t} />
      ))}
    </div>
  );
};

/** The editor inside a phone. */
export const EditorPhone: React.FC<{ width: number }> = ({ width }) => {
  const bezel = width * 0.035;
  const sw = width - bezel * 2;
  const k = sw / SW;
  return (
    <div
      style={{
        position: "relative",
        width,
        height: SH * k + bezel * 2,
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
