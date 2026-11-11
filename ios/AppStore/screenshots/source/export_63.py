"""Export the 6.9" posters (1320x2868) as 6.3" posters (1206x2622) for App Store Connect's required iPhone slot.
Scales uniformly by height, then trims <1 px of decorative background from the sides. Run from collagemagik-web/ios."""
from pathlib import Path
from PIL import Image, ImageCms

ROOT = Path(__file__).resolve().parents[1]
SRC, OUT = ROOT / "png", ROOT / "png-6.3"
OUT.mkdir(exist_ok=True)
ICC = ImageCms.ImageCmsProfile(ImageCms.createProfile("sRGB")).tobytes()
for f in sorted(SRC.glob("*-1320x2868.png")):
    im = Image.open(f).convert("RGB")
    scaled = im.resize((round(1320 * 2622 / 2868), 2622), Image.Resampling.LANCZOS)  # 1207 x 2622
    left = (scaled.width - 1206) // 2
    out = scaled.crop((left, 0, left + 1206, 2622))
    assert out.size == (1206, 2622)
    out.save(OUT / f.name.replace("1320x2868", "1206x2622"), icc_profile=ICC, optimize=True)
    print("wrote", f.name.replace("1320x2868", "1206x2622"))
