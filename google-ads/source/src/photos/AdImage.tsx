import React from "react";
import { AbsoluteFill, Img, staticFile } from "remotion";
import { Phone, phoneHeight } from "../ad/Phone";
import { APP_NAME, C, fontFamily } from "../ad/theme";
import { PHOTO_KINDS, TripPhoto } from "../ad/TripPhoto";

export type Theme = "trip" | "carousel" | "features";

export type AdImageProps = {
  theme: Theme;
  /** false = no headline on the image (for responsive / App campaign image assets, where less text delivers better). */
  withText: boolean;
};

const THEMES: Record<Theme, { title: [string, string]; sub: string; shots: string[]; bg: string; accent: string }> = {
  trip: {
    title: ["Your whole trip.", "One post."],
    sub: "Photo & video collages in seconds",
    shots: ["03-resize.png", "05-timeline.png"],
    bg: "#F6F1FD",
    accent: C.purple,
  },
  carousel: {
    title: ["Carousels", "that flow."],
    sub: "Photos cross every slide, so people keep swiping",
    shots: ["01-carousel.png", "02-carousel-next.png"],
    bg: "#EEF4FD",
    accent: C.blue,
  },
  features: {
    title: ["Photos, videos", "& captions."],
    sub: "Trim clips, add music, export in HD",
    shots: ["07-captions.png", "06-choose-part.png"],
    bg: "#FDF1F6",
    accent: C.pink,
  },
};

const Wash: React.FC<{ bg: string; accent: string; w: number; h: number }> = ({ bg, accent, w, h }) => {
  const m = Math.max(w, h);
  return (
    <AbsoluteFill style={{ background: bg, overflow: "hidden" }}>
      <div style={{ position: "absolute", width: m * 0.7, height: m * 0.7, left: -m * 0.15, top: -m * 0.2, borderRadius: "50%", background: `${accent}22`, filter: `blur(${m * 0.05}px)` }} />
      <div style={{ position: "absolute", width: m * 0.6, height: m * 0.6, right: -m * 0.15, bottom: -m * 0.2, borderRadius: "50%", background: "#FBD9E655", filter: `blur(${m * 0.05}px)` }} />
      <div style={{ position: "absolute", width: m * 0.4, height: m * 0.4, right: m * 0.1, top: -m * 0.1, borderRadius: "50%", background: "#FFE9C777", filter: `blur(${m * 0.05}px)` }} />
    </AbsoluteFill>
  );
};

const Icon: React.FC<{ size: number }> = ({ size }) => (
  <Img src={staticFile("brand/icon.png")} style={{ width: size, height: size, borderRadius: size * 0.225, boxShadow: `0 ${size * 0.1}px ${size * 0.25}px rgba(109,79,214,0.35)` }} />
);

const Cta: React.FC<{ s: number; label?: string }> = ({ s, label = "Download free" }) => (
  <div
    style={{
      display: "inline-block",
      padding: `${s * 0.42}px ${s * 0.95}px`,
      borderRadius: 999,
      background: `linear-gradient(135deg, ${C.purple}, ${C.pink})`,
      color: "#fff",
      fontFamily,
      fontWeight: 800,
      fontSize: s,
      whiteSpace: "nowrap",
      boxShadow: `0 ${s * 0.3}px ${s * 0.8}px rgba(109,79,214,0.35)`,
    }}
  >
    {label}
  </div>
);

/** Two phones, one tilted behind the other, plus a few floating trip photos. */
const Phones: React.FC<{ shots: string[]; width: number; tiles?: boolean }> = ({ shots, width, tiles = true }) => {
  const h = phoneHeight(width);
  return (
    <div style={{ position: "relative", width: width * 1.75, height: h * 1.02 }}>
      <Phone shot={shots[1]} width={width * 0.88} style={{ position: "absolute", right: 0, top: h * 0.07, rotate: "8deg", opacity: 0.97 }} />
      <Phone shot={shots[0]} width={width} style={{ position: "absolute", left: 0, top: 0, rotate: "-4deg" }} />
      {tiles
        ? [0, 1, 2].map((i) => (
            <TripPhoto
              key={i}
              kind={PHOTO_KINDS[(i * 3 + 1) % PHOTO_KINDS.length]}
              style={{
                position: "absolute",
                width: width * 0.3,
                height: width * 0.3,
                left: [width * -0.18, width * 1.45, width * 0.7][i],
                top: [h * 0.62, h * 0.2, h * 0.86][i],
                borderRadius: width * 0.05,
                border: `${width * 0.012}px solid #fff`,
                rotate: `${[-12, 10, -6][i]}deg`,
                boxShadow: `0 ${width * 0.03}px ${width * 0.07}px rgba(43,20,92,0.25)`,
              }}
            />
          ))
        : null}
    </div>
  );
};

const Title: React.FC<{ t: (typeof THEMES)[Theme]; size: number; align?: "left" | "center"; sub?: boolean }> = ({ t, size, align = "left", sub = true }) => (
  <div style={{ fontFamily, textAlign: align, color: C.ink }}>
    <div style={{ fontWeight: 800, fontSize: size, lineHeight: 1.02, letterSpacing: -size * 0.02 }}>
      {t.title[0]}
      <br />
      <span style={{ color: t.accent }}>{t.title[1]}</span>
    </div>
    {sub ? <div style={{ fontWeight: 600, fontSize: size * 0.36, color: "#5B5375", marginTop: size * 0.28, lineHeight: 1.25 }}>{t.sub}</div> : null}
  </div>
);

const Brand: React.FC<{ s: number }> = ({ s }) => (
  <div style={{ display: "flex", alignItems: "center", gap: s * 0.4, fontFamily, fontWeight: 800, fontSize: s, color: C.ink, whiteSpace: "nowrap" }}>
    <Icon size={s * 1.7} />
    {APP_NAME}
  </div>
);

/**
 * One component for every Google Ads image size: the layout is chosen from the aspect ratio
 * (strip banners, landscape, square, portrait / skyscraper).
 */
export const AdImage: React.FC<AdImageProps & { w: number; h: number }> = ({ theme, withText, w, h }) => {
  const t = THEMES[theme];
  const r = w / h;
  const m = Math.min(w, h);

  // Thin strips: 728x90, 970x90, 468x60, 320x50, 320x100
  if (r >= 3 && h <= 120) {
    const twoLines = h >= 90 && w < 500;
    const s = h;
    return (
      <AbsoluteFill>
        <Wash bg={t.bg} accent={t.accent} w={w} h={h} />
        <AbsoluteFill style={{ display: "flex", flexDirection: "row", alignItems: "center", padding: `0 ${s * 0.18}px`, gap: s * 0.18 }}>
          <Icon size={s * 0.7} />
          <div style={{ flex: 1, minWidth: 0, fontFamily, color: C.ink }}>
            <div style={{ fontWeight: 800, fontSize: s * (twoLines ? 0.22 : r > 6 ? 0.3 : 0.27), lineHeight: 1.05, whiteSpace: "nowrap" }}>
              {t.title[0]}
              {twoLines ? <br /> : " "}
              <span style={{ color: t.accent }}>{t.title[1]}</span>
            </div>
            {w >= 468 && !twoLines ? <div style={{ fontWeight: 600, fontSize: s * 0.17, color: "#5B5375", whiteSpace: "nowrap", marginTop: s * 0.04 }}>{APP_NAME} · Free on iPhone</div> : null}
          </div>
          {w >= 400 ? <Cta s={s * 0.2} /> : null}
        </AbsoluteFill>
      </AbsoluteFill>
    );
  }

  // Landscape: 1200x628, 970x250
  if (r >= 1.4) {
    const phoneW = h * 0.42;
    return (
      <AbsoluteFill>
        <Wash bg={t.bg} accent={t.accent} w={w} h={h} />
        <div style={withText ? { position: "absolute", right: w * 0.04, top: h * 0.12 } : { position: "absolute", left: (w - phoneW * 1.75) / 2, top: h * 0.1 }}>
          <Phones shots={t.shots} width={phoneW} />
        </div>
        <div style={{ position: "absolute", left: w * 0.06, top: 0, bottom: 0, width: w * 0.5, display: "flex", flexDirection: "column", justifyContent: "center", gap: m * 0.06 }}>
          {withText ? <Brand s={m * 0.07} /> : null}
          {withText ? <Title t={t} size={m * (r > 2.5 ? 0.17 : 0.12)} sub={r < 2.5 && m >= 250} /> : null}
          {withText ? <div><Cta s={m * 0.055} /></div> : null}
        </div>
        {!withText ? (
          <div style={{ position: "absolute", left: w * 0.04, top: h * 0.06 }}>
            <Brand s={m * 0.05} />
          </div>
        ) : null}
      </AbsoluteFill>
    );
  }

  // Square-ish: 1200x1200, 1200x1500 (4:5), 336x280, 300x250, 250x250, 200x200
  if (r >= 0.8) {
    const phoneW = w * (withText ? 0.34 : 0.31);
    const isBanner = w < 1000;
    const tall = r < 0.9; // 4:5 has room for the subtitle
    return (
      <AbsoluteFill>
        <Wash bg={t.bg} accent={t.accent} w={w} h={h} />
        <div style={{ position: "absolute", left: (w - phoneW * 1.75) / 2, top: withText ? h * (tall ? 0.4 : 0.42) : h * 0.18 }}>
          <Phones shots={t.shots} width={phoneW} />
        </div>
        <div style={{ position: "absolute", left: 0, right: 0, top: h * 0.06, display: "flex", flexDirection: "column", alignItems: "center", gap: m * 0.03 }}>
          <Brand s={m * 0.045} />
          {withText ? <Title t={t} size={m * 0.1} align="center" sub={tall && m >= 600} /> : null}
        </div>
        {withText && isBanner && w >= 300 ? (
          <div style={{ position: "absolute", left: 0, right: 0, bottom: h * 0.05, display: "flex", justifyContent: "center" }}>
            <Cta s={m * 0.065} />
          </div>
        ) : null}
      </AbsoluteFill>
    );
  }

  // Portrait / skyscraper: 1200x1500, 1080x1920, 300x600, 160x600, 300x1050
  const narrow = w < 200;
  const banner = w < 600;
  const phoneW = banner ? Math.min(w * 0.5, h * 0.27) : Math.min(w * 0.46, h * 0.24);
  const phonesTop = banner ? h * 0.55 - phoneHeight(phoneW) * 0.5 : h * 0.36;
  return (
    <AbsoluteFill>
      <Wash bg={t.bg} accent={t.accent} w={w} h={h} />
      <div style={{ position: "absolute", left: 0, right: 0, top: h * 0.05, display: "flex", flexDirection: "column", alignItems: "center", gap: w * 0.04, padding: `0 ${w * 0.06}px` }}>
        {narrow ? <Icon size={w * 0.4} /> : <Brand s={w * 0.05} />}
        {withText ? <Title t={t} size={w * (narrow ? 0.13 : 0.1)} align="center" sub={!narrow && w >= 600} /> : null}
      </div>
      <div style={{ position: "absolute", left: (w - phoneW * 1.75) / 2, top: withText ? phonesTop : h * 0.2 }}>
        <Phones shots={t.shots} width={phoneW} tiles={!narrow} />
      </div>
      {withText ? (
        <div style={{ position: "absolute", left: 0, right: 0, bottom: h * 0.04, display: "flex", justifyContent: "center" }}>
          <Cta s={w * (narrow ? 0.085 : 0.055)} label={narrow ? "Get it free" : "Download free"} />
        </div>
      ) : null}
    </AbsoluteFill>
  );
};

/** Square logo (1:1) and landscape logo (4:1). */
export const Logo: React.FC<{ w: number; h: number }> = ({ w, h }) => {
  if (w === h) {
    return (
      <AbsoluteFill style={{ background: "#fff", alignItems: "center", justifyContent: "center" }}>
        <Img src={staticFile("brand/icon.png")} style={{ width: w * 0.8, height: w * 0.8, borderRadius: w * 0.18 }} />
      </AbsoluteFill>
    );
  }
  return (
    <AbsoluteFill style={{ background: "#fff", alignItems: "center", justifyContent: "center" }}>
      <Brand s={h * 0.36} />
    </AbsoluteFill>
  );
};
