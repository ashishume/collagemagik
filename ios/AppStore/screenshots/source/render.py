"""Compose CollageMagik's real simulator captures into App Store posters (1320 x 2868, 6.9" iPhone slot).

Same layout as the Figureout and Mindstrike sets: rounded two-line headline, pastel field,
graphite phone frame. The raw captures are placed unmodified; the app's UI is never redrawn.

Requires Pillow and NumPy on macOS:  python3 AppStore/screenshots/source/render.py
"""

from __future__ import annotations

import hashlib
import io
import json
import math
from pathlib import Path

import numpy as np
from PIL import Image, ImageCms, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "png"
WIDTH, HEIGHT = 1320, 2868
SCALE = 2
SCREEN = (180, 680, 960, 2086)
BRAND = "CollageMagik"
INK, MUTED = "241A44", "645C7C"
FONT = "/System/Library/Fonts/SFNSRounded.ttf"
SRGB = ImageCms.ImageCmsProfile(ImageCms.createProfile("sRGB"))
ICC = SRGB.tobytes()
ASSETS = json.loads((ROOT / "source/screenshots.json").read_text())


def rgb(value):
    return tuple(int(value[i:i + 2], 16) for i in (0, 2, 4))


def font(size, weight="Heavy", scale=SCALE):
    result = ImageFont.truetype(FONT, round(size * scale))
    result.set_variation_by_name(weight)
    return result


def box(values):
    return tuple(round(v * SCALE) for v in values)


def round_rect(draw, values, radius, fill, outline=None, width=1):
    draw.rounded_rectangle(box(values), radius=round(radius * SCALE), fill=fill,
                           outline=outline, width=round(width * SCALE))


def centered(draw, text, y, size, color, weight="Heavy", max_width=1150):
    current = size
    chosen = font(current, weight)
    while draw.textlength(text, font=chosen) > max_width * SCALE:
        current -= 1
        chosen = font(current, weight)
    length = draw.textlength(text, font=chosen)
    assert current >= size - 12, (text, "unexpectedly small type")
    draw.text(((WIDTH * SCALE - length) / 2, y * SCALE), text, font=chosen,
              fill=color, anchor="lt")
    return current


def sparkle(draw, cx, cy, radius, color):
    points = []
    for angle in np.linspace(0, 2 * math.pi, 121):
        x = radius * math.copysign(abs(math.cos(angle)) ** 3, math.cos(angle))
        y = radius * math.copysign(abs(math.sin(angle)) ** 3, math.sin(angle))
        points.append(((cx + x) * SCALE, (cy + y) * SCALE))
    draw.polygon(points, fill=color)


def collage_mark(draw, cx, cy, kind, color):
    # Small marks in the margins echo CollageMagik's picture cells.
    if kind == "+":
        lines = [(cx - 19, cy, cx + 19, cy), (cx, cy - 19, cx, cy + 19)]
        for line in lines:
            draw.line(box(line), fill=color, width=6 * SCALE)
            for x, y in (line[:2], line[2:]):
                draw.ellipse(box((x - 3, y - 3, x + 3, y + 3)), fill=color)
    elif kind == "square":
        round_rect(draw, (cx - 17, cy - 17, cx + 17, cy + 17), 8, None, color, 6)
    else:
        draw.ellipse(box((cx - 17, cy - 17, cx + 17, cy + 17)), outline=color, width=6 * SCALE)


def backdrop(asset):
    canvas = Image.new("RGB", (WIDTH * SCALE, HEIGHT * SCALE), rgb(asset["background"]))
    draw = ImageDraw.Draw(canvas)
    draw.ellipse(box((-350, 900, 1680, 2960)), fill=rgb(asset["wash"]))
    for bounds in [(1040, 900, 1600, 1460), (-300, 1920, 250, 2470)]:
        draw.ellipse(box(bounds), outline=rgb(asset["background"]), width=5 * SCALE)
    accent = rgb(asset["accent"])
    sparkle(draw, 1184, 568, 30, accent)
    sparkle(draw, 1228, 524, 11, accent)
    collage_mark(draw, 83, 948, "+", accent)
    collage_mark(draw, 1225, 1745, "square", accent)
    collage_mark(draw, 85, 2530, "circle", accent)
    return canvas


def phone(canvas):
    x, y, sw, sh = SCREEN
    outer = (x - 23, y - 23, x + sw + 23, y + sh + 23)
    for blur, opacity, dy in [(38, 32, 25), (10, 45, 7)]:
        shadow = Image.new("RGBA", canvas.size)
        round_rect(ImageDraw.Draw(shadow),
                   (outer[0], outer[1] + dy, outer[2], outer[3] + dy),
                   134, (30, 22, 60, opacity))
        shadow = shadow.filter(ImageFilter.GaussianBlur(blur * SCALE))
        canvas.paste(shadow, (0, 0), shadow)
    draw = ImageDraw.Draw(canvas)
    for button in [(x - 30, y + 230, x - 18, y + 292),
                   (x - 30, y + 357, x - 18, y + 462),
                   (x - 30, y + 495, x - 18, y + 600),
                   (x + sw + 18, y + 402, x + sw + 30, y + 568)]:
        round_rect(draw, button, 5, "#56595C", "#AAAEB0")
    round_rect(draw, outer, 134, "#3B3D40", "#74777A", 2)
    round_rect(draw, (outer[0] + 4, outer[1] + 4, outer[2] - 4, outer[3] - 4),
               131, "#A6A8AA", "#D4D5D5")
    round_rect(draw, (outer[0] + 9, outer[1] + 9, outer[2] - 9, outer[3] - 9),
               126, "#111315", "#454749")
    round_rect(draw, (x - 3, y - 3, x + sw + 3, y + sh + 3), 115, "#000000")
    for sy in (y + 172, y + sh - 172):
        draw.line(box((outer[0] + 2, sy, outer[0] + 8, sy)), fill="#424446", width=6 * SCALE)
        draw.line(box((outer[2] - 8, sy, outer[2] - 2, sy)), fill="#424446", width=6 * SCALE)


def load_screenshot(path):
    with Image.open(path) as image:
        assert image.size == (WIDTH, HEIGHT), (path, image.size)
        if image.info.get("icc_profile"):
            profile = ImageCms.ImageCmsProfile(io.BytesIO(image.info["icc_profile"]))
            return ImageCms.profileToProfile(image, profile, SRGB, outputMode="RGB")
        return image.convert("RGB")


LOGO = ROOT.parents[1] / "CollageMagik" / "CollageMagik" / "Assets.xcassets" / "Logo.imageset" / "logo.png"


def brand_lockup(canvas, draw):
    """Logo + wordmark, centred as one group at the top of the poster."""
    icon = 66
    gap = 18
    text_font = font(48, "Heavy")
    text_w = draw.textlength(BRAND, font=text_font)
    total = icon * SCALE + gap * SCALE + text_w
    x0 = (WIDTH * SCALE - total) / 2
    top = 88
    with Image.open(LOGO) as src:
        logo = src.convert("RGB").resize((icon * SCALE, icon * SCALE), Image.Resampling.LANCZOS)
    mask = Image.new("L", logo.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, logo.width - 1, logo.height - 1),
                                           radius=round(icon * 0.225 * SCALE), fill=255)
    canvas.paste(logo, (round(x0), top * SCALE), mask)
    draw.text((x0 + (icon + gap) * SCALE, (top + icon / 2) * SCALE), BRAND, font=text_font,
              fill="#" + INK, anchor="lm")


def render(asset):
    source = (ROOT / "source" / asset["source"]).resolve()
    screenshot = load_screenshot(source)
    canvas = backdrop(asset)
    draw = ImageDraw.Draw(canvas)
    brand_lockup(canvas, draw)
    sizes = [centered(draw, asset["title"][0], 218, 120, "#" + INK),
             centered(draw, asset["title"][1], 358, 120, "#" + asset["accent"])]
    centered(draw, asset["subtitle"], 518, 38, "#" + MUTED, "Medium")
    phone(canvas)
    canvas = canvas.resize((WIDTH, HEIGHT), Image.Resampling.LANCZOS)
    # The entire capture is scaled proportionally, with only the rounded corners masked.
    x, y, sw, sh = SCREEN
    assert abs(sw / screenshot.width - sh / screenshot.height) < 0.0001
    resized = screenshot.resize((sw, sh), Image.Resampling.LANCZOS)
    mask_large = Image.new("L", (sw * SCALE, sh * SCALE), 0)
    ImageDraw.Draw(mask_large).rounded_rectangle((0, 0, sw * SCALE - 1, sh * SCALE - 1),
                                                 radius=112 * SCALE, fill=255)
    mask = mask_large.resize((sw, sh), Image.Resampling.LANCZOS)
    canvas.paste(resized, (x, y), mask)
    path = OUTPUT / f"{asset['id']}-{WIDTH}x{HEIGHT}.png"
    canvas.save(path, icc_profile=ICC, optimize=True)
    actual = np.asarray(canvas.crop((x, y, x + sw, y + sh)))
    opaque = np.asarray(mask) == 255
    assert np.array_equal(actual[opaque], np.asarray(resized)[opaque]), "screen content changed"
    with Image.open(path) as check:
        assert check.size == (WIDTH, HEIGHT) and check.mode == "RGB"
        assert check.info.get("icc_profile"), "missing sRGB profile"
    return {
        "file": str(path.relative_to(ROOT)), "source": asset["source"], "feature": asset["feature"],
        "title": " ".join(asset["title"]), "subtitle": asset["subtitle"],
        "width": WIDTH, "height": HEIGHT, "mode": "RGB", "color_profile": "sRGB",
        "source_sha256": hashlib.sha256(source.read_bytes()).hexdigest(),
        "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
        "screen_opaque_pixels_match_resized_source": True, "headline_font_sizes": sizes,
    }


def contact_sheet(records):
    thumb_w, thumb_h, gap, margin, header = 330, 717, 26, 32, 134
    columns = min(4, len(records))
    rows = math.ceil(len(records) / columns)
    row_height = thumb_h + 68
    sheet = Image.new("RGB", (2 * margin + columns * thumb_w + (columns - 1) * gap,
                              header + rows * row_height), "#FAFAF7")
    draw = ImageDraw.Draw(sheet)
    draw.text((margin, 27), f"{BRAND} / App Store screenshots",
              font=font(35, scale=1), fill="#" + INK)
    draw.text((margin, 80), f"{len(records)} PNGs · 1320 × 2868 px · Actual app screens · iPhone frames",
              font=font(22, "Medium", scale=1), fill="#" + MUTED)
    for i, record in enumerate(records):
        x = margin + (i % columns) * (thumb_w + gap)
        y = header + (i // columns) * row_height
        with Image.open(ROOT / record["file"]) as image:
            sheet.paste(image.resize((thumb_w, thumb_h), Image.Resampling.LANCZOS), (x, y))
        draw.text((x, y + thumb_h + 17), f"{i + 1:02d} / {record['feature'].lower()}",
                  font=font(18, "Semibold", scale=1), fill="#" + INK)
    sheet.save(ROOT / "overview.jpg", quality=95, subsampling=0, icc_profile=ICC)


if __name__ == "__main__":
    OUTPUT.mkdir(parents=True, exist_ok=True)
    records = []
    for asset in ASSETS:
        records.append(render(asset))
        print("Rendered and verified:", records[-1]["file"], flush=True)
    (ROOT / "manifest.json").write_text(json.dumps({
        "design_reference": "Figureout / Mindstrike App Store iPhone sets",
        "method": "Local composition of simulator captures",
        "screen_rect": dict(zip(("x", "y", "width", "height"), SCREEN)), "assets": records,
    }, indent=2) + "\n")
    contact_sheet(records)
    print(f"Finished: {len(records)} upload PNGs, overview and verification manifest.", flush=True)
