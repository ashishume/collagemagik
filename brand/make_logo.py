"""CollageMagik logo: one SVG source, every raster size generated from it.

Concept: a collage grid of three rounded tiles (a tall photo tile + two stacked tiles) on a violet-to-pink gradient.
The tiles say what the app does: photos (sun and hills), video (play), magic (sparkle).

Run from collagemagik-web/:   python3 brand/make_logo.py
Needs: pip install cairosvg pillow
Outputs: brand/logo-icon.svg (full-bleed square), brand/logo-rounded.svg (favicon), brand/logo-mark.svg (tiles only),
         and PNGs into the iOS asset catalog, public/ (PWA, favicon) and the landing page.
"""
from __future__ import annotations

import io
from pathlib import Path

import cairosvg
from PIL import Image, ImageCms

HERE = Path(__file__).resolve().parent
WEB = HERE.parent                                   # collagemagik-web/
APPS = WEB.parent                                   # Axpo-Apps/
LANDING_PUBLIC = APPS / "axpo-creations-apps" / "landing-page" / "public"
IOS_ASSETS = WEB / "ios" / "CollageMagik" / "CollageMagik" / "Assets.xcassets"

# ---- geometry (1024 grid) ---------------------------------------------------------------------------------------------
M, GAP, R = 176, 40, 68                      # outer margin, gap between tiles, tile corner radius
INNER = 1024 - 2 * M                         # 672
LEFT_W = 316
RIGHT_X = M + LEFT_W + GAP                   # 532
RIGHT_W = 1024 - M - RIGHT_X                 # 316
TOP_H = 300
BOT_Y = M + TOP_H + GAP                      # 516
BOT_H = 1024 - M - BOT_Y                     # 332

TILES = {
    "photo": (M, M, LEFT_W, INNER),
    "magic": (RIGHT_X, M, RIGHT_W, TOP_H),
    "video": (RIGHT_X, BOT_Y, RIGHT_W, BOT_H),
}


def star(cx, cy, r, pinch=0.16):
    """4-point sparkle with concave sides."""
    k = r * pinch
    return (f"M{cx},{cy - r} Q{cx + k},{cy - k} {cx + r},{cy} Q{cx + k},{cy + k} {cx},{cy + r} "
            f"Q{cx - k},{cy + k} {cx - r},{cy} Q{cx - k},{cy - k} {cx},{cy - r}Z")


def shadow_stack(x, y, w, h, r):
    """Soft drop shadow built from stacked translucent rects (cairosvg has no blur filter)."""
    out = []
    for i, (grow, dy, op) in enumerate([(26, 30, 0.035), (20, 26, 0.04), (14, 22, 0.05), (9, 18, 0.06), (5, 14, 0.07), (2, 10, 0.08)]):
        out.append(f'<rect x="{x - grow}" y="{y - grow + dy}" width="{w + 2 * grow}" height="{h + 2 * grow}" '
                   f'rx="{r + grow}" fill="#2a0d6b" opacity="{op}"/>')
    return "".join(out)


def tiles_svg() -> str:
    px, py, pw, ph = TILES["photo"]
    mx, my, mw, mh = TILES["magic"]
    vx, vy, vw, vh = TILES["video"]

    # photo tile: sun + two layered hills, clipped to the tile
    sun_cx, sun_cy = px + pw * 0.64, py + ph * 0.30
    hill_back = (f"M{px},{py + ph * 0.80} C{px + pw * 0.25},{py + ph * 0.58} {px + pw * 0.55},{py + ph * 0.60} {px + pw},{py + ph * 0.76} "
                 f"L{px + pw},{py + ph} L{px},{py + ph}Z")
    hill_front = (f"M{px},{py + ph * 0.90} C{px + pw * 0.30},{py + ph * 0.70} {px + pw * 0.70},{py + ph * 0.86} {px + pw},{py + ph * 0.80} "
                  f"L{px + pw},{py + ph} L{px},{py + ph}Z")

    # play triangle (rounded via stroke), optically centred in the video tile
    pcx, pcy = vx + vw / 2 + 10, vy + vh / 2
    s = 74
    tri = f"{pcx - s * 0.72},{pcy - s} {pcx - s * 0.72},{pcy + s} {pcx + s * 1.05},{pcy}"

    return f"""
  <g id="tiles">
    {shadow_stack(px, py, pw, ph, R)}{shadow_stack(mx, my, mw, mh, R)}{shadow_stack(vx, vy, vw, vh, R)}
    <!-- photo tile -->
    <clipPath id="clipPhoto"><rect x="{px}" y="{py}" width="{pw}" height="{ph}" rx="{R}"/></clipPath>
    <rect x="{px}" y="{py}" width="{pw}" height="{ph}" rx="{R}" fill="url(#tileSky)"/>
    <g clip-path="url(#clipPhoto)">
      <circle cx="{sun_cx}" cy="{sun_cy}" r="{pw * 0.30}" fill="url(#sunGlow)"/>
      <circle cx="{sun_cx}" cy="{sun_cy}" r="{pw * 0.135}" fill="url(#sun)"/>
      <path d="{hill_back}" fill="url(#hillBack)"/>
      <path d="{hill_front}" fill="url(#hillFront)"/>
    </g>
    <!-- magic tile -->
    <rect x="{mx}" y="{my}" width="{mw}" height="{mh}" rx="{R}" fill="url(#tileWhite)"/>
    <path d="{star(mx + mw * 0.5, my + mh * 0.5, 98)}" fill="url(#ink)"/>
    <path d="{star(mx + mw * 0.78, my + mh * 0.27, 34, 0.2)}" fill="url(#ink)"/>
    <path d="{star(mx + mw * 0.24, my + mh * 0.74, 26, 0.2)}" fill="url(#ink)" opacity="0.85"/>
    <!-- video tile -->
    <rect x="{vx}" y="{vy}" width="{vw}" height="{vh}" rx="{R}" fill="url(#tileWhite)"/>
    <polygon points="{tri}" fill="url(#ink)" stroke="url(#ink)" stroke-width="44" stroke-linejoin="round"/>
  </g>"""


DEFS = """
  <defs>
    <linearGradient id="bg" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="#6A3DF2"/>
      <stop offset="0.52" stop-color="#B83FD0"/>
      <stop offset="1" stop-color="#FF5C9A"/>
    </linearGradient>
    <radialGradient id="bgGlowTL" cx="0.12" cy="0.06" r="0.7">
      <stop offset="0" stop-color="#ffffff" stop-opacity="0.30"/>
      <stop offset="1" stop-color="#ffffff" stop-opacity="0"/>
    </radialGradient>
    <radialGradient id="bgGlowBR" cx="0.95" cy="1" r="0.6">
      <stop offset="0" stop-color="#FFB36B" stop-opacity="0.45"/>
      <stop offset="1" stop-color="#FFB36B" stop-opacity="0"/>
    </radialGradient>
    <linearGradient id="tileWhite" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="#FFFFFF"/>
      <stop offset="1" stop-color="#F3EAFF"/>
    </linearGradient>
    <linearGradient id="tileSky" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="#FFE9F3"/>
      <stop offset="0.55" stop-color="#FFF6E8"/>
      <stop offset="1" stop-color="#FFE3EE"/>
    </linearGradient>
    <radialGradient id="sunGlow"><stop offset="0" stop-color="#FFC266" stop-opacity="0.55"/><stop offset="1" stop-color="#FFC266" stop-opacity="0"/></radialGradient>
    <linearGradient id="sun" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#FFD36B"/><stop offset="1" stop-color="#FF9A4D"/></linearGradient>
    <linearGradient id="hillBack" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#C38BFF"/><stop offset="1" stop-color="#8A5CF6"/></linearGradient>
    <linearGradient id="hillFront" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#7A4BF0"/><stop offset="1" stop-color="#5A2FD0"/></linearGradient>
    <linearGradient id="ink" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#7B4DF6"/><stop offset="1" stop-color="#E24A98"/></linearGradient>
  </defs>"""


def svg(background: str, rx: int = 0) -> str:
    bg = ""
    if background == "full":
        bg = (f'<rect width="1024" height="1024" rx="{rx}" fill="url(#bg)"/>'
              f'<rect width="1024" height="1024" rx="{rx}" fill="url(#bgGlowBR)"/>'
              f'<rect width="1024" height="1024" rx="{rx}" fill="url(#bgGlowTL)"/>')
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024" width="1024" height="1024">'
            f'{DEFS}{bg}{tiles_svg()}</svg>')


def to_png(svg_text: str, size: int) -> Image.Image:
    data = cairosvg.svg2png(bytestring=svg_text.encode(), output_width=size, output_height=size)
    return Image.open(io.BytesIO(data)).convert("RGBA")


SRGB = ImageCms.ImageCmsProfile(ImageCms.createProfile("sRGB")).tobytes()


def save_opaque(img: Image.Image, path: Path):
    """8-bit RGB, sRGB profile, NO alpha channel (App Store icons with alpha are rejected)."""
    path.parent.mkdir(parents=True, exist_ok=True)
    img.convert("RGB").save(path, icc_profile=SRGB, optimize=True)
    print("wrote", path.relative_to(APPS))


def save_rgba(img: Image.Image, path: Path):
    path.parent.mkdir(parents=True, exist_ok=True)
    img.save(path, icc_profile=SRGB, optimize=True)
    print("wrote", path.relative_to(APPS))


if __name__ == "__main__":
    full = svg("full")                       # full-bleed square: iOS, PWA (maskable-safe), landing page
    rounded = svg("full", rx=232)            # favicon / social use
    mark = svg("none")                       # tiles only, transparent
    (HERE / "logo-icon.svg").write_text(full)
    (HERE / "logo-rounded.svg").write_text(rounded)
    (HERE / "logo-mark.svg").write_text(mark)

    big = to_png(full, 1024)
    # iOS: the 1024 marketing/app icon (opaque), plus an in-app logo for the About screen
    save_opaque(big, IOS_ASSETS / "AppIcon.appiconset" / "icon-1024.png")
    save_opaque(to_png(full, 512), IOS_ASSETS / "Logo.imageset" / "logo.png")
    # Web app (PWA)
    save_opaque(to_png(full, 192), WEB / "public" / "icon-192.png")
    save_opaque(to_png(full, 512), WEB / "public" / "icon-512.png")
    save_opaque(to_png(full, 180), WEB / "public" / "apple-touch-icon.png")
    (WEB / "public" / "favicon.svg").write_text(rounded)
    save_rgba(to_png(rounded, 64), WEB / "public" / "favicon-64.png")
    # Landing page (axpocreation.com)
    save_opaque(to_png(full, 512), LANDING_PUBLIC / "collagemagik" / "icon.png")
    save_opaque(to_png(full, 180), LANDING_PUBLIC / "collagemagik" / "apple-touch-icon.png")
    (LANDING_PUBLIC / "collagemagik" / "icon.svg").write_text(rounded)
    # preview sheet at several sizes (for eyeballing small-size legibility)
    sheet = Image.new("RGB", (1180, 420), "#f4f1fa")
    x = 20
    for size in (360, 180, 120, 80, 60, 40, 29):
        sheet.paste(to_png(rounded, size), (x, 20), to_png(rounded, size))
        x += size + 24
    sheet.save(HERE / "preview.png")
    print("wrote brand/preview.png")
