"""Generate scenic stand-in photos and short video clips for CollageMagik App Store screenshots.

Everything here is procedurally drawn (no third-party imagery), so it is safe to publish.
Usage: make_media.py OUT_DIR
"""
import math
import subprocess
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageFilter

OUT = Path(sys.argv[1])
OUT.mkdir(parents=True, exist_ok=True)
rng = np.random.default_rng(7)


def hexc(h):
    h = h.lstrip("#")
    return np.array([int(h[i:i + 2], 16) for i in (0, 2, 4)], dtype=np.float32)


def vgrad(w, h, stops):
    """Vertical gradient through (position 0..1, colour) stops."""
    ys = np.linspace(0, 1, h, dtype=np.float32)
    pos = [s[0] for s in stops]
    cols = np.stack([hexc(s[1]) for s in stops])
    out = np.stack([np.interp(ys, pos, cols[:, c]) for c in range(3)], axis=1)
    return np.repeat(out[:, None, :], w, axis=1)


def ridge(w, h, base, amp, freq, seed, octaves=4):
    r = np.random.default_rng(seed)
    x = np.linspace(0, 1, w, dtype=np.float32)
    y = np.zeros(w, dtype=np.float32)
    a, f = 1.0, freq
    for _ in range(octaves):
        y += a * np.sin(2 * math.pi * (x * f + r.random()))
        a *= 0.5
        f *= 2.1
    y = base + amp * y / 1.8
    return y  # y-pixel of the ridge line per column


def fill_below(img, line, colour, haze=0.0, haze_colour=None):
    h, w, _ = img.shape
    rows = np.arange(h, dtype=np.float32)[:, None]
    mask = (rows >= line[None, :]).astype(np.float32)[:, :, None]
    col = np.broadcast_to(hexc(colour), img.shape).copy()
    if haze and haze_colour:
        depth = np.clip((rows - line[None, :]) / (h * 0.35), 0, 1)[:, :, None]
        col = col * (1 - (1 - depth) * haze) + hexc(haze_colour) * (1 - depth) * haze
    return img * (1 - mask) + col * mask


def _window(img, cx, cy, reach):
    h, w, _ = img.shape
    x0, x1 = max(0, int(cx - reach)), min(w, int(cx + reach) + 1)
    y0, y1 = max(0, int(cy - reach)), min(h, int(cy + reach) + 1)
    return x0, x1, y0, y1


def glow(img, cx, cy, radius, colour, strength):
    # Gaussian falloff is ~0 beyond 2.2 radii, so only touch that window (in place).
    x0, x1, y0, y1 = _window(img, cx, cy, radius * 2.2)
    if x1 <= x0 or y1 <= y0:
        return img
    yy, xx = np.mgrid[y0:y1, x0:x1].astype(np.float32)
    d = np.sqrt((xx - cx) ** 2 + (yy - cy) ** 2) / radius
    k = np.exp(-(d ** 2) * 2.2)[:, :, None] * strength
    img[y0:y1, x0:x1] = img[y0:y1, x0:x1] * (1 - k) + hexc(colour) * k
    return img


def disc(img, cx, cy, r, colour):
    x0, x1, y0, y1 = _window(img, cx, cy, r + 4)
    if x1 <= x0 or y1 <= y0:
        return img
    yy, xx = np.mgrid[y0:y1, x0:x1].astype(np.float32)
    d = np.sqrt((xx - cx) ** 2 + (yy - cy) ** 2)
    k = np.clip((r - d) / 3, 0, 1)[:, :, None]
    img[y0:y1, x0:x1] = img[y0:y1, x0:x1] * (1 - k) + hexc(colour) * k
    return img


def finish(img, name, grain=7, blur=0.8, size=None):
    im = Image.fromarray(np.clip(img, 0, 255).astype(np.uint8))
    if blur:
        im = im.filter(ImageFilter.GaussianBlur(blur))
    a = np.asarray(im).astype(np.float32)
    a += np.random.default_rng(3).normal(0, grain, a.shape[:2])[:, :, None]
    # soft vignette
    h, w, _ = a.shape
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    v = 1 - 0.28 * (((xx - w / 2) / (w / 2)) ** 2 + ((yy - h / 2) / (h / 2)) ** 2) / 2
    a *= v[:, :, None]
    im = Image.fromarray(np.clip(a, 0, 255).astype(np.uint8))
    if size:
        im = im.resize(size, Image.Resampling.LANCZOS)
    im.save(OUT / name, quality=92)
    print("wrote", name, im.size)


def sunset_beach(w=1800, h=2400, name="01-sunset-beach.jpg"):
    img = vgrad(w, h, [(0, "#2b1b5a"), (0.28, "#a8407a"), (0.46, "#ff7a59"), (0.56, "#ffc86b"), (0.6, "#ffe9a8")])
    img = glow(img, w * 0.62, h * 0.57, w * 0.55, "#ffd28a", 0.75)
    img = disc(img, w * 0.62, h * 0.56, w * 0.07, "#fff4cf")
    horizon = int(h * 0.6)
    sea = vgrad(w, h - horizon, [(0, "#f4a46a"), (0.25, "#b25a73"), (1, "#25204f")])
    img[horizon:] = sea
    # sun glitter on the water
    yy = np.arange(h - horizon, dtype=np.float32)[:, None]
    xx = np.arange(w, dtype=np.float32)[None, :]
    spread = 40 + yy * 0.7
    g = np.exp(-((xx - w * 0.62) ** 2) / (2 * spread ** 2)) * (0.55 + 0.45 * np.sin(yy * 0.55 + rng.random())) * np.exp(-yy / (h * 0.28))
    img[horizon:] += g[:, :, None] * np.array([255, 215, 150], dtype=np.float32) * 0.8
    # beach foreground
    line = ridge(w, h, h * 0.88, h * 0.025, 1.2, 4, 3)
    img = fill_below(img, line, "#3a2a3d")
    # palm silhouettes
    for px, scale in [(w * 0.14, 1.0), (w * 0.3, 0.7)]:
        top = h * 0.88 - 560 * scale
        for t in np.linspace(0, 1, 80):
            cx = px + 30 * math.sin(t * 1.3) * scale
            cy = h * 0.9 - t * 560 * scale
            img = disc(img, cx, cy, 11 * scale, "#1e1530")
        for ang in np.linspace(-2.7, -0.4, 9):
            for t in np.linspace(0, 1, 40):
                ex = px + 30 * scale + math.cos(ang) * t * 210 * scale
                ey = top + math.sin(ang) * t * 120 * scale + (t ** 2) * 150 * scale
                img = disc(img, ex, ey, 5.5 * scale * (1 - t * 0.6), "#1e1530")
    finish(img, name)


def mountain_lake(w=1800, h=2400, name="02-mountain-lake.jpg"):
    img = vgrad(w, h, [(0, "#4f86c6"), (0.35, "#9cc3e6"), (0.55, "#f2e3d2")])
    for (b, a, col, hz) in [(0.38, 0.09, "#6f8fb8", 0.5), (0.45, 0.1, "#46698f", 0.4), (0.52, 0.07, "#2b4a68", 0.25)]:
        line = ridge(w, h, h * b, h * a, 1.6 + b, int(b * 100), 5)
        img = fill_below(img, line, col, hz, "#dbe9f5")
    shore = int(h * 0.58)
    lake = vgrad(w, h - shore, [(0, "#7fa9c5"), (0.5, "#35607f"), (1, "#173247")])
    refl = img[:shore][::-1][: h - shore].copy()
    if refl.shape[0] < h - shore:
        refl = np.pad(refl, ((0, h - shore - refl.shape[0]), (0, 0), (0, 0)), mode="edge")
    ripple = np.sin(np.arange(h - shore, dtype=np.float32)[:, None] * 0.35 + np.arange(w, dtype=np.float32)[None, :] * 0.01) * 0.08
    img[shore:] = (lake * 0.55 + refl[: h - shore] * 0.45) * (1 + ripple[:, :, None])
    # pines
    for i in range(36):
        x = rng.uniform(0, w)
        base = h * 0.58 + rng.uniform(-8, 18)
        ht = rng.uniform(130, 330)
        for t in np.linspace(0, 1, 28):
            wd = (1 - t) * ht * 0.2
            img = disc(img, x, base - t * ht, max(wd, 2), "#10281f")
    line = ridge(w, h, h * 0.92, h * 0.02, 1.1, 8, 3)
    img = fill_below(img, line, "#102a22")
    finish(img, name)


def misty_forest(w=1800, h=2400, name="03-misty-forest.jpg"):
    img = vgrad(w, h, [(0, "#cfe3d6"), (0.5, "#9cc0a6"), (1, "#3a6a50")])
    for layer in range(6):
        depth = layer / 5
        col = (hexc("#c4dccb") * (1 - depth) + hexc("#12372a") * depth)
        for i in range(24 - layer * 2):
            x = rng.uniform(-50, w + 50)
            ht = rng.uniform(0.45, 0.85) * h * (0.7 + depth * 0.4)
            base = h * (0.55 + depth * 0.42)
            for t in np.linspace(0, 1, 40):
                img = disc(img, x, base - t * ht, 6 + (1 - t) * 14 * (0.5 + depth), "#%02x%02x%02x" % tuple(int(c) for c in col))
        img = glow(img, w * rng.uniform(0.2, 0.8), h * (0.5 + depth * 0.2), w * 0.9, "#e9f2e6", 0.22)
    finish(img, name, blur=1.4)


def city_dusk(w=1800, h=2400, name="04-city-dusk.jpg"):
    img = vgrad(w, h, [(0, "#1a1f4d"), (0.4, "#6a4c93"), (0.62, "#f08a5d"), (0.7, "#ffd0a0")])
    img = glow(img, w * 0.3, h * 0.66, w * 0.7, "#ffb27a", 0.5)
    for layer, (col, ht_scale) in enumerate([("#493a66", 0.30), ("#2d2549", 0.38), ("#171330", 0.46)]):
        x = 0
        while x < w:
            bw = rng.uniform(70, 190)
            bh = rng.uniform(0.25, 1.0) * h * ht_scale
            top = h * 0.82 - bh
            x0, x1 = int(x), int(min(w, x + bw))
            img[int(top):int(h * 0.9), x0:x1] = hexc(col)
            if layer == 2:
                for wy in np.arange(top + 22, h * 0.88, 34):
                    for wx in np.arange(x0 + 12, x1 - 12, 26):
                        if rng.random() < 0.45:
                            img[int(wy):int(wy) + 14, int(wx):int(wx) + 10] = hexc("#ffd98a")
            x += bw + rng.uniform(0, 18)
    road = vgrad(w, int(h * 0.1), [(0, "#14112a"), (1, "#0a0818")])
    img[int(h * 0.9):int(h * 0.9) + road.shape[0]] = road[: h - int(h * 0.9)]
    for i in range(30):
        img = glow(img, rng.uniform(0, w), h * rng.uniform(0.91, 0.97), 40, "#ffb36b", 0.8)
    finish(img, name)


def flower_field(w=1800, h=2400, name="05-flower-field.jpg"):
    img = vgrad(w, h, [(0, "#bfe2f5"), (0.38, "#f7eedd"), (0.4, "#8cc063"), (1, "#2d6a3a")])
    line = ridge(w, h, h * 0.4, h * 0.015, 1.4, 21, 3)
    img = fill_below(img, line, "#79ad58", 0.6, "#cfe6c5")
    cols = ["#ff5d8f", "#ffd23f", "#ffffff", "#a56bff", "#ff8a3d"]
    for i in range(1600):
        t = rng.random() ** 1.7
        y = h * 0.42 + t * h * 0.58
        x = rng.uniform(-20, w + 20)
        r = 3 + t * 34
        img = disc(img, x, y, r, cols[rng.integers(len(cols))])
        img = disc(img, x, y, r * 0.35, "#ffe27a")
    finish(img, name, blur=1.0)


def desert_dunes(w=1800, h=2400, name="06-desert-dunes.jpg"):
    img = vgrad(w, h, [(0, "#f6c58c"), (0.45, "#fbe3b9"), (0.5, "#f7d6a2")])
    img = disc(img, w * 0.78, h * 0.2, 90, "#fffaf0")
    for i, (b, col) in enumerate([(0.5, "#e0a15f"), (0.6, "#c67b3c"), (0.72, "#a65a2a"), (0.86, "#7a3b1d")]):
        line = ridge(w, h, h * b, h * 0.045, 0.7 + i * 0.25, 40 + i, 3)
        base = img.copy()
        img = fill_below(img, line, col, 0.0, None)
        # lit edge
        rows = np.arange(h, dtype=np.float32)[:, None]
        edge = np.exp(-((rows - line[None, :]) ** 2) / 60)[:, :, None] * 0.35
        img = img * (1 - edge) + hexc("#ffe1b3") * edge
    finish(img, name)


def aurora_night(w=1800, h=2400, name="07-aurora-night.jpg"):
    img = vgrad(w, h, [(0, "#050816"), (0.5, "#0d1b3d"), (1, "#0a2a3a")])
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    for k, col in enumerate(["#3dffb0", "#6a8bff", "#c06bff"]):
        centre = h * (0.28 + 0.07 * k) + 140 * np.sin(xx / w * 5 + k * 1.7) + 60 * np.sin(xx / w * 13 + k)
        band = np.exp(-((yy - centre) ** 2) / (2 * (120 + 30 * k) ** 2))[:, :, None] * (0.55 - 0.1 * k)
        img = img * (1 - band) + hexc(col) * band
    for i in range(900):
        img = disc(img, rng.uniform(0, w), rng.uniform(0, h * 0.7), rng.uniform(0.8, 2.6), "#ffffff")
    for i, (b, col) in enumerate([(0.82, "#0b1a2b"), (0.9, "#050b14")]):
        line = ridge(w, h, h * b, h * 0.03, 1.3 + i, 60 + i, 4)
        img = fill_below(img, line, col)
    for i in range(18):
        x = rng.uniform(0, w)
        for t in np.linspace(0, 1, 24):
            img = disc(img, x, h * 0.92 - t * 210, max((1 - t) * 34, 2), "#03070d")
    finish(img, name, blur=0.9)


def autumn_road(w=2400, h=1800, name="08-autumn-road.jpg"):
    img = vgrad(w, h, [(0, "#f3e0bd"), (0.4, "#f0b66b"), (0.55, "#d98a3a")])
    vx, vy = w * 0.5, h * 0.52
    road = np.zeros((h, w), dtype=np.float32)
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    half = np.clip((yy - vy) / (h - vy), 0, 1) * w * 0.32
    road = (np.abs(xx - vx) < half) & (yy > vy)
    img[road] = hexc("#4a3a33")
    for t in np.linspace(0.05, 1, 12):
        y = vy + (h - vy) * t ** 1.8
        ww = 6 + 40 * t ** 1.8
        img[int(y):int(y + 40 * t ** 1.8 + 4), int(vx - ww / 2):int(vx + ww / 2)] = hexc("#f2d36b")
    cols = ["#d9482b", "#f08a24", "#f2c230", "#b5301f", "#e56b1f"]
    for side in (-1, 1):
        for i in range(70):
            t = rng.random() ** 1.5
            y = vy + (h - vy) * t
            x = vx + side * (w * 0.2 + t * w * 0.5 + rng.uniform(0, w * 0.1))
            ht = 80 + t * 900
            for s in np.linspace(0, 1, 22):
                img = disc(img, x, y - s * ht, 5 + 26 * t * (1 - s * 0.5), "#3a2417")
            for k in range(10):
                img = disc(img, x + rng.normal(0, 60 * t + 12), y - ht * (0.8 + rng.random() * 0.4), 40 * t + 18, cols[rng.integers(len(cols))])
    finish(img, name, blur=1.2)


def pastel_hills(w=1800, h=2400, name="09-pastel-hills.jpg"):
    img = vgrad(w, h, [(0, "#ffd6e0"), (0.4, "#ffe9c9"), (0.6, "#fff6e3")])
    img = disc(img, w * 0.3, h * 0.22, 140, "#fff7e6")
    for i, col in enumerate(["#f7b2c3", "#e69bb6", "#b98bc8", "#8a74c4", "#5d5fa8"]):
        line = ridge(w, h, h * (0.5 + i * 0.1), h * 0.04, 0.8 + i * 0.2, 80 + i, 3)
        img = fill_below(img, line, col, 0.35, "#ffe5ef")
    finish(img, name)


def coast_cliffs(w=2400, h=1800, name="10-coast.jpg"):
    img = vgrad(w, h, [(0, "#5fb4e8"), (0.45, "#cfeaf7"), (0.5, "#9fd8ef")])
    sea = vgrad(w, int(h * 0.5), [(0, "#7cd0e6"), (0.5, "#1c96c2"), (1, "#0b5f8c")])
    img[int(h * 0.5):] = sea[: h - int(h * 0.5)]
    for i in range(90):
        y = h * 0.52 + rng.random() ** 1.4 * h * 0.46
        x = rng.uniform(0, w)
        img = glow(img, x, y, rng.uniform(60, 190), "#ffffff", 0.18)
    line = ridge(w, h, h * 0.6, h * 0.12, 0.5, 91, 4)
    line = np.where(np.arange(w) < w * 0.55, line, h * 1.2)
    img = fill_below(img, line, "#8a6a4a", 0.0, None)
    img = fill_below(img, line + 40, "#6e5238")
    img = fill_below(img, ridge(w, h, h * 0.52, h * 0.05, 0.7, 92, 3) + (np.arange(w) > w * 0.6) * 0, "#2f6f4a") if False else img
    finish(img, name)


# ---- photos ----------------------------------------------------------------
sunset_beach()
mountain_lake()
misty_forest()
city_dusk()
flower_field()
desert_dunes()
aurora_night()
autumn_road()
pastel_hills()
coast_cliffs()


# ---- videos (animated, 1080x1920, 30 fps, H.264) -----------------------------
def render_video(name, frame_fn, seconds=5, fps=30, w=1080, h=1920):
    path = OUT / name
    cmd = ["ffmpeg", "-y", "-loglevel", "error", "-f", "rawvideo", "-pix_fmt", "rgb24", "-s", f"{w}x{h}",
           "-r", str(fps), "-i", "-", "-c:v", "libx264", "-pix_fmt", "yuv420p", "-crf", "17", "-movflags", "+faststart", str(path)]
    p = subprocess.Popen(cmd, stdin=subprocess.PIPE)
    n = seconds * fps
    for i in range(n):
        t = i / n
        frame = frame_fn(t, w, h)
        p.stdin.write(np.clip(frame, 0, 255).astype(np.uint8).tobytes())
    p.stdin.close()
    p.wait()
    print("wrote", name)


def waves_frame(t, w, h):
    img = vgrad(w, h, [(0, "#2b1b5a"), (0.3, "#c24d7a"), (0.5, "#ff9a5c"), (0.58, "#ffe2a0")])
    sy = h * 0.55 - 30 * math.sin(t * 2 * math.pi)
    img = glow(img, w * 0.5, sy, w * 0.7, "#ffd28a", 0.7)
    img = disc(img, w * 0.5, sy, 70, "#fff4cf")
    horizon = int(h * 0.6)
    sea = vgrad(w, h - horizon, [(0, "#f4a46a"), (0.3, "#a64d70"), (1, "#1d1a45")])
    yy = np.arange(h - horizon, dtype=np.float32)[:, None]
    xx = np.arange(w, dtype=np.float32)[None, :]
    wave = np.sin(yy * 0.09 - t * 2 * math.pi * 2 + xx * 0.012) * 0.5 + 0.5
    glit = np.exp(-((xx - w * 0.5) ** 2) / (2 * (30 + yy * 0.6) ** 2)) * wave * np.exp(-yy / 380)
    sea = sea * (0.85 + 0.25 * wave[:, :, None]) + glit[:, :, None] * np.array([255, 220, 160], dtype=np.float32) * 0.9
    img[horizon:] = sea
    return img


def aurora_frame(t, w, h):
    img = vgrad(w, h, [(0, "#050816"), (0.55, "#0d1b3d"), (1, "#0a2a3a")])
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    for k, col in enumerate(["#3dffb0", "#6a8bff", "#c06bff"]):
        centre = h * (0.3 + 0.06 * k) + 110 * np.sin(xx / w * 5 + k * 1.7 + t * 2 * math.pi) + 45 * np.sin(xx / w * 12 + k - t * 4 * math.pi)
        band = np.exp(-((yy - centre) ** 2) / (2 * (110 + 25 * k) ** 2))[:, :, None] * (0.6 - 0.1 * k)
        img = img * (1 - band) + hexc(col) * band
    r = np.random.default_rng(5)
    for i in range(240):
        tw = 0.6 + 0.4 * math.sin(t * 2 * math.pi * 2 + i)
        img = disc(img, r.uniform(0, w), r.uniform(0, h * 0.65), r.uniform(1.0, 2.6) * tw, "#ffffff")
    line = ridge(w, h, h * 0.86, h * 0.03, 1.3, 61, 4)
    img = fill_below(img, line, "#050b14")
    return img


render_video("v1-sunset-waves.mp4", waves_frame, seconds=5)
render_video("v2-aurora.mp4", aurora_frame, seconds=5)
