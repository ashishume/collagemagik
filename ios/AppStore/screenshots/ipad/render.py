"""Compose the 13-inch iPad simulator captures into App Store posters.

Run from the repository root with Pillow and NumPy installed:
    python3 ios/AppStore/screenshots/ipad/render.py
"""

from __future__ import annotations

import hashlib
import io
import json
import math
from pathlib import Path

import numpy as np
from PIL import Image, ImageCms, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parent
OUTPUT = ROOT / "png"
WIDTH, HEIGHT = 2064, 2752
SCALE = 2
SCREEN = (213, 465, 1638, 2184)
BRAND = "Collage Magic"
INK, MUTED = "241A44", "645C7C"
FONT = "/System/Library/Fonts/SFNSRounded.ttf"
SRGB = ImageCms.ImageCmsProfile(ImageCms.createProfile("sRGB"))
ICC = SRGB.tobytes()
ASSETS = json.loads((ROOT / "screenshots.json").read_text())
LOGO = (
    ROOT.parents[2]
    / "CollageMagik"
    / "CollageMagik"
    / "Assets.xcassets"
    / "Logo.imageset"
    / "logo.png"
)


def rgb(value):
    return tuple(int(value[i:i + 2], 16) for i in (0, 2, 4))


def font(size, weight="Heavy", scale=SCALE):
    result = ImageFont.truetype(FONT, round(size * scale))
    result.set_variation_by_name(weight)
    return result


def box(values):
    return tuple(round(v * SCALE) for v in values)


def round_rect(draw, values, radius, fill, outline=None, width=1):
    draw.rounded_rectangle(
        box(values),
        radius=round(radius * SCALE),
        fill=fill,
        outline=outline,
        width=round(width * SCALE),
    )


def centered(draw, text, y, size, color, weight="Heavy", max_width=1900):
    current = size
    chosen = font(current, weight)
    while draw.textlength(text, font=chosen) > max_width * SCALE:
        current -= 1
        chosen = font(current, weight)
    length = draw.textlength(text, font=chosen)
    assert current >= size - 12, (text, "unexpectedly small type")
    draw.text(
        ((WIDTH * SCALE - length) / 2, y * SCALE),
        text,
        font=chosen,
        fill=color,
        anchor="lt",
    )
    return current


def sparkle(draw, cx, cy, radius, color):
    points = []
    for angle in np.linspace(0, 2 * math.pi, 121):
        x = radius * math.copysign(abs(math.cos(angle)) ** 3, math.cos(angle))
        y = radius * math.copysign(abs(math.sin(angle)) ** 3, math.sin(angle))
        points.append(((cx + x) * SCALE, (cy + y) * SCALE))
    draw.polygon(points, fill=color)


def collage_mark(draw, cx, cy, kind, color):
    if kind == "+":
        lines = [(cx - 19, cy, cx + 19, cy), (cx, cy - 19, cx, cy + 19)]
        for line in lines:
            draw.line(box(line), fill=color, width=6 * SCALE)
            for x, y in (line[:2], line[2:]):
                draw.ellipse(box((x - 3, y - 3, x + 3, y + 3)), fill=color)
    elif kind == "square":
        round_rect(draw, (cx - 17, cy - 17, cx + 17, cy + 17), 8, None, color, 6)
    else:
        draw.ellipse(
            box((cx - 17, cy - 17, cx + 17, cy + 17)),
            outline=color,
            width=6 * SCALE,
        )


def backdrop(asset):
    canvas = Image.new("RGB", (WIDTH * SCALE, HEIGHT * SCALE), rgb(asset["background"]))
    draw = ImageDraw.Draw(canvas)
    draw.ellipse(box((-450, 1040, 1600, 3040)), fill=rgb(asset["wash"]))
    for bounds in [(1590, 950, 2100, 1460), (-250, 1900, 300, 2450)]:
        draw.ellipse(box(bounds), outline=rgb(asset["background"]), width=5 * SCALE)
    accent = rgb(asset["accent"])
    sparkle(draw, 1900, 398, 30, accent)
    sparkle(draw, 1944, 354, 11, accent)
    collage_mark(draw, 86, 1020, "+", accent)
    collage_mark(draw, 1970, 1770, "square", accent)
    collage_mark(draw, 88, 2545, "circle", accent)
    return canvas


def brand_lockup(canvas, draw):
    icon, gap = 62, 16
    text_font = font(44, "Heavy")
    text_width = draw.textlength(BRAND, font=text_font)
    total = icon * SCALE + gap * SCALE + text_width
    x0 = (WIDTH * SCALE - total) / 2
    top = 36
    with Image.open(LOGO) as source:
        logo = source.convert("RGB").resize(
            (icon * SCALE, icon * SCALE), Image.Resampling.LANCZOS
        )
    mask = Image.new("L", logo.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        (0, 0, logo.width - 1, logo.height - 1),
        radius=round(icon * 0.225 * SCALE),
        fill=255,
    )
    canvas.paste(logo, (round(x0), top * SCALE), mask)
    draw.text(
        (x0 + (icon + gap) * SCALE, (top + icon / 2) * SCALE),
        BRAND,
        font=text_font,
        fill="#" + INK,
        anchor="lm",
    )


def device_frame(canvas):
    x, y, sw, sh = SCREEN
    outer = (x - 24, y - 24, x + sw + 24, y + sh + 24)
    for blur, opacity, dy in [(42, 30, 26), (12, 42, 8)]:
        shadow = Image.new("RGBA", canvas.size)
        round_rect(
            ImageDraw.Draw(shadow),
            (outer[0], outer[1] + dy, outer[2], outer[3] + dy),
            84,
            (30, 22, 60, opacity),
        )
        shadow = shadow.filter(ImageFilter.GaussianBlur(blur * SCALE))
        canvas.paste(shadow, (0, 0), shadow)
    draw = ImageDraw.Draw(canvas)
    round_rect(draw, outer, 84, "#3B3D40", "#74777A", 2)
    round_rect(
        draw,
        (outer[0] + 4, outer[1] + 4, outer[2] - 4, outer[3] - 4),
        81,
        "#A6A8AA",
        "#D4D5D5",
    )
    round_rect(
        draw,
        (outer[0] + 9, outer[1] + 9, outer[2] - 9, outer[3] - 9),
        76,
        "#111315",
        "#454749",
    )
    round_rect(draw, (x - 3, y - 3, x + sw + 3, y + sh + 3), 68, "#000000")


def load_screenshot(path):
    with Image.open(path) as image:
        assert image.size == (WIDTH, HEIGHT), (path, image.size)
        if image.info.get("icc_profile"):
            profile = ImageCms.ImageCmsProfile(io.BytesIO(image.info["icc_profile"]))
            return ImageCms.profileToProfile(image, profile, SRGB, outputMode="RGB")
        return image.convert("RGB")


def render(asset):
    source = (ROOT / asset["source"]).resolve()
    screenshot = load_screenshot(source)
    canvas = backdrop(asset)
    draw = ImageDraw.Draw(canvas)
    brand_lockup(canvas, draw)
    sizes = [
        centered(draw, asset["title"][0], 116, 100, "#" + INK),
        centered(draw, asset["title"][1], 222, 100, "#" + asset["accent"]),
    ]
    centered(draw, asset["subtitle"], 344, 36, "#" + MUTED, "Medium")
    device_frame(canvas)

    x, y, sw, sh = SCREEN
    assert abs(sw / screenshot.width - sh / screenshot.height) < 0.0001
    resized = screenshot.resize((sw, sh), Image.Resampling.LANCZOS)
    canvas = canvas.resize((WIDTH, HEIGHT), Image.Resampling.LANCZOS)
    mask_large = Image.new("L", (sw * SCALE, sh * SCALE), 0)
    ImageDraw.Draw(mask_large).rounded_rectangle(
        (0, 0, sw * SCALE - 1, sh * SCALE - 1),
        radius=66 * SCALE,
        fill=255,
    )
    mask = mask_large.resize((sw, sh), Image.Resampling.LANCZOS)
    canvas.paste(resized, (x, y), mask)
    output = OUTPUT / f"{asset['id']}-{WIDTH}x{HEIGHT}.png"
    canvas.save(output, icc_profile=ICC, optimize=True)

    rendered = Image.open(output).convert("RGB")
    actual = np.asarray(rendered.crop((x, y, x + sw, y + sh)))
    opaque = np.asarray(mask) == 255
    assert np.array_equal(actual[opaque], np.asarray(resized)[opaque]), (
        "screen content changed"
    )
    assert rendered.size == (WIDTH, HEIGHT) and rendered.mode == "RGB"
    return {
        "file": str(output.relative_to(ROOT)),
        "source": str(source.relative_to(ROOT)),
        "feature": asset["feature"],
        "title": " ".join(asset["title"]),
        "subtitle": asset["subtitle"],
        "width": WIDTH,
        "height": HEIGHT,
        "mode": "RGB",
        "color_profile": "sRGB",
        "source_sha256": hashlib.sha256(source.read_bytes()).hexdigest(),
        "sha256": hashlib.sha256(output.read_bytes()).hexdigest(),
        "screen_opaque_pixels_match_resized_source": True,
        "headline_font_sizes": sizes,
    }


def contact_sheet(records):
    thumb_w, thumb_h, gap, margin, header = 330, 440, 26, 32, 132
    columns = 3
    rows = math.ceil(len(records) / columns)
    row_height = thumb_h + 68
    sheet = Image.new(
        "RGB",
        (
            2 * margin + columns * thumb_w + (columns - 1) * gap,
            header + rows * row_height,
        ),
        "#FAFAF7",
    )
    draw = ImageDraw.Draw(sheet)
    draw.text(
        (margin, 27),
        f"{BRAND} / iPad App Store screenshots",
        font=font(35, scale=1),
        fill="#" + INK,
    )
    draw.text(
        (margin, 80),
        f"{len(records)} PNGs · {WIDTH} × {HEIGHT} px · Actual iPad screens",
        font=font(22, "Medium", scale=1),
        fill="#" + MUTED,
    )
    label_font = font(15, "Semibold", scale=1)
    for i, record in enumerate(records):
        x = margin + (i % columns) * (thumb_w + gap)
        y = header + (i // columns) * row_height
        with Image.open(ROOT / record["file"]) as image:
            sheet.paste(image.resize((thumb_w, thumb_h), Image.Resampling.LANCZOS), (x, y))
        label = f"{i + 1:02d} / {record['feature'].lower()}"
        lines, line = [], ""
        for word in label.split():
            candidate = f"{line} {word}".strip()
            if line and draw.textlength(candidate, font=label_font) > thumb_w:
                lines.append(line)
                line = word
            else:
                line = candidate
        if line:
            lines.append(line)
        draw.multiline_text(
            (x, y + thumb_h + 12),
            "\n".join(lines),
            font=label_font,
            fill="#" + INK,
            spacing=3,
        )
    sheet.save(ROOT / "overview.jpg", quality=95, subsampling=0, icc_profile=ICC)


if __name__ == "__main__":
    OUTPUT.mkdir(parents=True, exist_ok=True)
    records = []
    for asset in ASSETS:
        records.append(render(asset))
        print("Rendered and verified:", records[-1]["file"], flush=True)
    (ROOT / "manifest.json").write_text(
        json.dumps(
            {
                "design_reference": "App Store iPhone 6.3-inch poster set",
                "method": "Local composition of 13-inch iPad simulator captures",
                "device": "iPad 13-inch",
                "screen_rect": dict(
                    zip(("x", "y", "width", "height"), SCREEN)
                ),
                "assets": records,
            },
            indent=2,
        )
        + "\n"
    )
    contact_sheet(records)
    print(f"Finished: {len(records)} PNGs, overview and verification manifest.")
