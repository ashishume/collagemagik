#!/usr/bin/env python3
"""HTML5 display ads for Google Ads (Display campaigns, "Upload display ads").

One animated banner per size, telling the v4 story in about 10 seconds: a pile of trip photos drops into a collage,
a photo lands on top in an instant frame and twists straight (yellow guides, as in the app), a caption appears, then
"Same trip. Way better post." with the CTA. It plays twice (20 s, under Google's 30 s limit) and stops on the last frame.

Usage, from google-ads/source:
    python3 scripts/build-html5.py v4

Writes google-ads/html5/<version>/<name>/ (index.html + images, for previewing) and
google-ads/html5/<version>/zips/<name>.zip (what you upload). Every zip must stay at or under 150 KB.
Needs ImageMagick (`magick`) and `zip`.
"""
import math
import os
import shutil
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.dirname(HERE)
PUBLIC = os.path.join(SRC, "public")

SIZES = [
    (300, 250), (336, 280), (728, 90), (300, 600), (320, 50), (320, 100), (468, 60),
    (970, 90), (970, 250), (250, 250), (200, 200), (160, 600), (300, 1050),
]

# Unsplash photos (see public/travel/credits.json). Cells fill in this order; the last one is the photo laid on top.
CELL_PHOTOS = ["santorini-domes", "amalfi", "overwater", "balloons", "venice-canal", "alpine-lake"]
TOP_PHOTO = "positano"

# Placeholder only: Google Ads replaces clickTag with the ad's final URL when you upload.
CLICK_URL = "https://apps.apple.com/"

LIMIT = 150 * 1024
CYCLE = 10  # seconds per play
PLAYS = 2

C = {
    "ink": "#1E1438", "purple": "#6D4FD6", "pink": "#E0457B", "sub": "#5B5375",
    "lilac": "#F6F1FD", "rose": "#FDF1F6", "gold": "#F4C430",
}

LONG = ["Back from your trip?", "Make it a collage.", "Same trip. Way better post."]
SHORT = ["Back from a trip?", "Make it a collage.", "Way better posts."]
TWO_LINE = ["Back from<br>your trip?", "Make it<br>a collage.", "Same trip.<br>Way better post."]
CTA_LONG = "Free on the App Store"
CTA_SHORT = "Get it free"

# rough width of one bold system-font character, in ems (errs wide so text never spills)
EM = 0.6


def text_w(s, font):
    return len(s) * font * EM


def pick_headlines(width, font_cap, min_font=12):
    """The long lines when they fit at a readable size, otherwise the short ones."""
    f = min(font_cap, width / (max(len(x) for x in LONG) * EM))
    if f >= min_font:
        return LONG, f
    return SHORT, min(font_cap, width / (max(len(x) for x in SHORT) * EM))


def cta_for(width, height, prefer_long=True):
    """CTA text and font that fit a button `width` wide."""
    for text in ([CTA_LONG, CTA_SHORT] if prefer_long else [CTA_SHORT]):
        f = min(height * 0.4, (width - height * 0.8) / (len(text) * EM))
        if f >= 11 or text == CTA_SHORT:
            return text, f
    return CTA_SHORT, 11


def layout(w, h):
    r = w / h
    L = {"w": w, "h": h}
    if h <= 100 and h >= 90 and w < 500:
        # small banner (320x100): square collage | headline over the CTA
        p = max(3, round(h * 0.08))
        ch = h - 2 * p
        L["collage"] = (p, p, ch, ch)
        x = p + ch + p * 2
        col = w - x - p * 2
        lines, f = pick_headlines(col, h * 0.2, min_font=16)
        cta_h = round(h * 0.36)
        text, cf = cta_for(col, cta_h)
        cta_w = round(text_w(text, cf) + cta_h * 0.9)
        gap = p
        y = (h - (f * 1.2 + gap + cta_h)) / 2
        L["head"] = (x, y, col, f * 1.2, f, "left", lines)
        L["cta"] = (x, y + f * 1.2 + gap, cta_w, cta_h, cf, text)
    elif h <= 100:
        # strip: collage | (icon) headline (name) | CTA
        p = max(3, round(h * 0.08))
        ch = h - 2 * p
        cw = round(ch * 1.3)
        L["collage"] = (p, p, cw, ch)
        cta_h = min(40, round(h * 0.56))
        text = CTA_LONG if w >= 600 else CTA_SHORT
        cf = round(cta_h * 0.4)
        cta_w = round(text_w(text, cf) + cta_h * 0.9)
        L["cta"] = (w - p * 2 - cta_w, (h - cta_h) / 2, cta_w, cta_h, cf, text)
        # the headline needs room: drop the icon first, then narrow the collage to a square
        s = round(h * 0.5)
        with_icon = h >= 60
        for _ in range(3):
            x = p + cw + p * 2 + (s + p * 1.5 if with_icon else 0)
            area = L["cta"][0] - p * 2 - x
            if area >= max(120, w * 0.3):
                break
            if with_icon:
                with_icon = False
            else:
                cw = ch
                L["collage"] = (p, p, cw, ch)
        if with_icon:
            L["icon"] = (p + cw + p * 2, (h - s) / 2, s)
        lines, f = pick_headlines(area, h * (0.24 if h >= 80 else 0.3))
        name_f = f * 0.62 if h >= 80 else 0
        block = f * 1.2 + (name_f * 1.4 if name_f else 0)
        y = (h - block) / 2
        L["head"] = (x, y, area, f * 1.2, f, "left", lines)
        if name_f:
            L["name"] = (x, y + f * 1.25, name_f)
    elif r >= 1.6:
        # wide: collage | icon + name / headline / CTA
        p = round(h * 0.08)
        ch = h - 2 * p
        cw = round(ch * 1.45)
        L["collage"] = (p, p, cw, ch)
        x = p + cw + p * 2
        col = w - x - p
        s = round(h * 0.19)
        lines, f = pick_headlines(col, h * 0.15)
        cta_h = round(h * 0.2)
        text, cf = cta_for(min(col, 340), cta_h)
        cta_w = round(text_w(text, cf) + cta_h * 1.1)
        gap = p * 0.8
        total = s + gap + f * 1.2 + gap + cta_h
        y = (h - total) / 2
        L["icon"] = (x, y, s)
        L["name"] = (x + s + p * 0.6, y + s / 2 - s * 0.2, s * 0.4)
        L["head"] = (x, y + s + gap, col, f * 1.2, f, "left", lines)
        L["cta"] = (x, y + s + gap + f * 1.2 + gap, cta_w, cta_h, cf, text)
    elif r > 0.75:
        # box: headline / collage / icon + name ... CTA
        p = max(8, round(min(w, h) * 0.05))
        lines, f = pick_headlines(w - 2 * p, h * 0.085, min_font=14)
        hh = f * 1.3
        L["head"] = (p, p, w - 2 * p, hh, f, "center", lines)
        bb = round(h * 0.16)
        yb = h - p - bb
        L["icon"] = (p, yb, bb)
        x = p + bb + p * 0.6
        cta_h = round(bb * 0.82)
        # the app name sits by the icon only when the button still gets readable text beside it
        with_name = x + text_w("CollageMagik", bb * 0.36) + p
        text, cf = cta_for(w - p - with_name, cta_h)
        if w >= 250 and cf >= cta_h * 0.36:
            L["name"] = (x, yb + bb / 2 - bb * 0.19, bb * 0.36)
            x = with_name
        else:
            text, cf = cta_for(w - p - x, cta_h)
        cta_w = round(text_w(text, cf) + cta_h * 0.9)
        L["cta"] = (w - p - cta_w, yb + (bb - cta_h) / 2, cta_w, cta_h, cf, text)
        y = p + hh + p * 0.7
        L["collage"] = (p, y, w - 2 * p, yb - p * 0.7 - y)
    else:
        # tall: icon + name / headline (2 lines) / collage / CTA
        p = round(w * 0.07)
        s = round(min(w * 0.2, 60))
        L["icon"] = (p, p, s)
        L["name"] = (p + s + p * 0.5, p + s / 2 - s * 0.19, s * 0.36)
        f = min(w * 0.11, (w - 2 * p) / (16 * EM), 30)
        y = p + s + p
        L["head"] = (p, y, w - 2 * p, f * 1.15 * 2, f, "center", TWO_LINE)
        cta_h = round(min(52, w * 0.22))
        text, cf = cta_for(w - 2 * p, cta_h)
        L["cta"] = (p, h - p - cta_h, w - 2 * p, cta_h, cf, text)
        cy = y + f * 1.15 * 2 + p
        L["collage"] = (p, cy, w - 2 * p, h - p - cta_h - p - cy)
    return L


def grid(cw, ch):
    cols = 3 if cw / ch > 1.8 else 2
    rows = 3 if ch / cw > 1.5 else 2
    return cols, rows


def px(v):
    return f"{v:.1f}px".replace(".0px", "px")


def crop(src, dst, w, h):
    subprocess.run([
        "magick", os.path.join(PUBLIC, "travel", src + ".jpg"),
        "-resize", f"{w}x{h}^", "-gravity", "center", "-extent", f"{w}x{h}",
        "-strip", "-sampling-factor", "4:2:0", "-interlace", "JPEG", "-quality", "66", dst,
    ], check=True)


def build(w, h, out_dir):
    L = layout(w, h)
    name = f"collagemagik-editor-html5-{w}x{h}"
    d = os.path.join(out_dir, name)
    shutil.rmtree(d, ignore_errors=True)
    os.makedirs(d)

    cx, cy, cw, ch = L["collage"]
    cols, rows = grid(cw, ch)
    g = max(2, round(min(cw, ch) * 0.025))
    rad = max(3, round(min(cw, ch) * 0.045))
    cell_w = (cw - g * (cols - 1)) / cols
    cell_h = (ch - g * (rows - 1)) / rows
    scale = 2  # sharp on high-density (2x) screens; still well inside the 150 KB budget

    css = []
    html_cells = []
    n = cols * rows
    for i in range(n):
        c, r_ = i % cols, i // cols
        x = c * (cell_w + g)
        y = r_ * (cell_h + g)
        img = f"p{i + 1}.jpg"
        crop(CELL_PHOTOS[i % len(CELL_PHOTOS)], os.path.join(d, img), math.ceil(cell_w * scale), math.ceil(cell_h * scale))
        # every photo starts in a loose pile in the middle, then drops into its cell
        dx = cw / 2 - (x + cell_w / 2) + [-0.12, 0.1, -0.06, 0.14, -0.1, 0.08][i % 6] * cw
        dy = ch / 2 - (y + cell_h / 2) + [0.06, -0.08, 0.1, -0.04, 0.02, -0.1][i % 6] * ch
        rot = [-14, 9, -6, 12, -9, 6][i % 6]
        a, b = 10 + 3 * i, 20 + 3 * i
        css.append(
            f"#c{i}{{left:{px(x)};top:{px(y)};width:{px(cell_w)};height:{px(cell_h)};background-image:url({img});"
            f"animation-name:k{i}}}\n"
            f"@keyframes k{i}{{0%{{opacity:0;transform:translate({px(dx)},{px(dy)}) rotate({rot}deg) scale(.82)}}"
            f"4%,{a}%{{opacity:1;transform:translate({px(dx)},{px(dy)}) rotate({rot}deg) scale(.82)}}"
            f"{b}%,100%{{opacity:1;transform:none}}}}"
        )
        html_cells.append(f'<div class="cell" id="c{i}"></div>')

    # the photo laid on top, in an instant frame
    show_top = min(cw, ch) >= 70
    top_html = ""
    if show_top:
        ow = min(cw, ch) * 0.5
        fp = max(2, ow * 0.06)
        iw = ow - 2 * fp
        oh = fp + iw + max(4, ow * 0.2)
        ox, oy = (cw - ow) / 2 + cw * 0.08, (ch - oh) / 2 - ch * 0.02
        crop(TOP_PHOTO, os.path.join(d, "top.jpg"), math.ceil(iw * scale), math.ceil(iw * scale))
        css.append(
            f"#top{{left:{px(ox)};top:{px(oy)};width:{px(ow)};height:{px(oh)};padding:{px(fp)};border-radius:{px(max(2, ow * 0.03))}}}"
            f"#top i{{width:{px(iw)};height:{px(iw)}}}"
            f"#guideH{{top:{px(oy + oh / 2)}}}#guideV{{left:{px(ox + ow / 2)}}}"
            f"#deg{{left:{px(ox + ow / 2)};top:{px(oy - max(10, ow * 0.16))};font-size:{px(max(8, ow * 0.11))}}}"
        )
        top_html = ('<div id="guideH" class="guide"></div><div id="guideV" class="guide"></div>'
                    '<div id="top"><i></i></div><div id="deg">0°</div>')
    show_cap = cw >= 140 and ch >= 110
    cap_html = ""
    if show_cap:
        cf = max(12, min(cw, ch * 1.4) * 0.1)
        css.append(f"#cap{{font-size:{px(cf)};bottom:{px(ch * 0.07)}}}")
        cap_html = '<div id="cap">golden hour</div>'

    hx, hy, hw, hh, hf, align, lines = L["head"]
    heads = "".join(f'<span id="h{k}">{t}</span>' for k, t in enumerate(lines))
    ctx, cty, ctw, cth, ctf, ctext = L["cta"]
    icon_html = ""
    if "icon" in L:
        ix, iy, isz = L["icon"]
        icon_html = f'<img id="icon" src="icon.svg" alt="" style="left:{px(ix)};top:{px(iy)};width:{px(isz)};height:{px(isz)};border-radius:{px(isz * 0.225)}">'
        shutil.copy(os.path.join(PUBLIC, "brand", "logo-rounded.svg"), os.path.join(d, "icon.svg"))
    name_html = ""
    if "name" in L:
        nx, ny, nf = L["name"]
        name_html = f'<div id="name" style="left:{px(nx)};top:{px(ny)};font-size:{px(nf)}">CollageMagik</div>'

    page = f"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="ad.size" content="width={w},height={h}">
<title>CollageMagik</title>
<script>var clickTag = "{CLICK_URL}";</script>
<style>
*{{margin:0;padding:0;box-sizing:border-box}}
html,body{{width:{w}px;height:{h}px;overflow:hidden;background:#fff}}
#ad{{position:relative;width:{w}px;height:{h}px;overflow:hidden;cursor:pointer;
  font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,Helvetica,Arial,sans-serif;color:{C["ink"]};
  background:radial-gradient(circle at 92% 108%,#FBD9E6 0,rgba(251,217,230,0) 55%),
    radial-gradient(circle at 6% -8%,#E3D8F6 0,rgba(227,216,246,0) 50%),linear-gradient(135deg,{C["lilac"]},{C["rose"]})}}
#ad:after{{content:"";position:absolute;inset:0;border:1px solid rgba(30,20,56,.16);pointer-events:none}}
#collage{{position:absolute;left:{px(cx)};top:{px(cy)};width:{px(cw)};height:{px(ch)}}}
.cell,#top,.guide,#deg,#cap,#heads span{{position:absolute;animation-duration:{CYCLE}s;animation-iteration-count:{PLAYS};
  animation-fill-mode:both;animation-timing-function:cubic-bezier(.16,1,.3,1)}}
.cell{{border-radius:{rad}px;background-size:cover;background-position:center;box-shadow:0 2px 6px rgba(30,20,56,.18)}}
#top{{background:#fff;box-shadow:0 6px 16px rgba(30,20,56,.35);animation-name:top}}
#top i{{display:block;background:url(top.jpg) center/cover}}
@keyframes top{{0%,30%{{opacity:0;transform:translateY(-60%) rotate(-24deg) scale(1.35)}}
  38%,45%{{opacity:1;transform:rotate(-14deg)}}52%,100%{{opacity:1;transform:none}}}}
.guide{{background:{C["gold"]};animation-name:guide;opacity:0}}
#guideH{{left:-4%;width:108%;height:1.5px;margin-top:-.75px}}#guideV{{top:-4%;height:108%;width:1.5px;margin-left:-.75px}}
@keyframes guide{{0%,50%{{opacity:0}}53%,58%{{opacity:1}}64%,100%{{opacity:0}}}}
#deg{{transform:translateX(-50%);background:{C["gold"]};color:{C["ink"]};font-weight:800;padding:1px 5px;border-radius:9px;
  animation-name:deg}}
@keyframes deg{{0%,50%{{opacity:0;transform:translateX(-50%) scale(.6)}}53%,58%{{opacity:1;transform:translateX(-50%)}}64%,100%{{opacity:0}}}}
#cap{{left:0;right:0;text-align:center;color:#fff;font-family:"Snell Roundhand","Segoe Script","Brush Script MT",Georgia,cursive;
  font-style:italic;font-weight:700;text-shadow:0 1px 4px rgba(0,0,0,.55);animation-name:cap}}
@keyframes cap{{0%,60%{{opacity:0;transform:scale(.7)}}67%,100%{{opacity:1;transform:none}}}}
#heads{{position:absolute;left:{px(hx)};top:{px(hy)};width:{px(hw)};height:{px(hh)}}}
#heads span{{inset:0;display:flex;align-items:center;justify-content:{"center" if align == "center" else "flex-start"};
  text-align:{align};font-size:{px(hf)};font-weight:800;line-height:1.12;letter-spacing:-.01em;white-space:nowrap;opacity:0}}
#h0{{animation-name:h0}}#h1{{animation-name:h1}}#h2{{animation-name:h2}}
@keyframes h0{{0%{{opacity:0;transform:translateY(30%)}}3%,24%{{opacity:1;transform:none}}28%,100%{{opacity:0;transform:translateY(-30%)}}}}
@keyframes h1{{0%,27%{{opacity:0;transform:translateY(30%)}}31%,64%{{opacity:1;transform:none}}68%,100%{{opacity:0;transform:translateY(-30%)}}}}
@keyframes h2{{0%,67%{{opacity:0;transform:translateY(30%)}}72%,100%{{opacity:1;transform:none}}}}
#h2{{color:{C["purple"]}}}
#icon{{position:absolute;box-shadow:0 2px 8px rgba(109,79,214,.35)}}
#name{{position:absolute;font-weight:800;white-space:nowrap;line-height:1}}
#cta{{position:absolute;left:{px(ctx)};top:{px(cty)};width:{px(ctw)};height:{px(cth)};border-radius:{px(cth / 2)};
  display:flex;align-items:center;justify-content:center;color:#fff;font-weight:800;font-size:{px(ctf)};white-space:nowrap;
  background:linear-gradient(135deg,{C["purple"]},{C["pink"]});box-shadow:0 3px 10px rgba(224,69,123,.35);
  animation:cta {CYCLE}s ease-in-out {PLAYS} both}}
@keyframes cta{{0%,76%,86%,100%{{transform:none}}81%{{transform:scale(1.07)}}}}
{chr(10).join(css)}
</style>
</head>
<body>
<div id="ad" onclick="window.open(window.clickTag,'_blank')" role="link" aria-label="CollageMagik: {ctext}">
<div id="collage">{"".join(html_cells)}{top_html}{cap_html}</div>
<div id="heads">{heads}</div>
{icon_html}{name_html}
<div id="cta">{ctext}</div>
</div>
</body>
</html>
"""
    with open(os.path.join(d, "index.html"), "w") as fh:
        fh.write(page)
    return name, d


def main():
    version = sys.argv[1] if len(sys.argv) > 1 else "v4"
    out_dir = os.path.join(os.path.dirname(SRC), "html5", version)
    zips = os.path.join(out_dir, "zips")
    os.makedirs(zips, exist_ok=True)
    failed = []
    rows = []
    for w, h in SIZES:
        name, d = build(w, h, out_dir)
        z = os.path.join(zips, name + ".zip")
        if os.path.exists(z):
            os.remove(z)
        files = sorted(os.listdir(d))
        subprocess.run(["zip", "-q", "-X", "-9", z] + files, cwd=d, check=True)
        size = os.path.getsize(z)
        rows.append((name, size, len(files)))
        if size > LIMIT:
            failed.append(name)
    # a page that shows every size, for checking them side by side
    with open(os.path.join(out_dir, "preview.html"), "w") as fh:
        fh.write('<!DOCTYPE html><meta charset="utf-8"><title>HTML5 ads</title>'
                 '<body style="font:13px system-ui;background:#eee;padding:16px;display:flex;flex-wrap:wrap;gap:20px;align-items:flex-start">')
        for (w, h) in SIZES:
            n = f"collagemagik-editor-html5-{w}x{h}"
            fh.write(f'<figure style="margin:0"><figcaption>{w}x{h}</figcaption>'
                     f'<iframe src="{n}/index.html" width="{w}" height="{h}" style="border:0;display:block;background:#fff"></iframe></figure>')
    for name, size, count in rows:
        print(f"{name}.zip  {size / 1024:6.1f} KB  {count} files{'  OVER 150 KB' if size > LIMIT else ''}")
    if failed:
        sys.exit("Over the 150 KB limit: " + ", ".join(failed))


if __name__ == "__main__":
    main()
