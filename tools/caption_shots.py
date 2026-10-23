"""Adds a short caption above each App Store screenshot. Output keeps the exact pixel size of the
simulator shot (Apple checks it). Raw shots stay in <set>/raw/. Run: python3 tools/caption_shots.py store"""
import glob, os, sys
from PIL import Image, ImageDraw, ImageFont

CAPTIONS = {
    "shaping":  ("Shaping math, done for you", "Live stitch count beside your rows"),
    "gauge":    ("Match any pattern’s gauge", "Convert counts and estimate yarn"),
    "eyesfree": ("Count without looking", "Tap anywhere. Feel every 5th and 10th row"),
    "journal":  ("Your project’s story", "Sessions, pace, photos and a finish card"),
    "counter":  ("A calm, ad-free row counter", "Big buttons, undo and full history"),
    "pattern":  ("Your pattern, right there", "PDFs and photos with a row highlighter"),
    "markup":   ("Mark up your chart", "Pen, highlighter and eraser"),
    "voice":    ("Count by voice", "On-device only. Nothing is recorded"),
    "dusk":     ("Calm, low-contrast themes", "Including a soft dark mode"),
    "pro":      ("Pro is a one-time purchase", "No subscription, no account"),
}
CALM = ((0xEC, 0xE7, 0xDF), (0x45, 0x40, 0x3B), (0x67, 0x5F, 0x57))
DUSK = ((0x2A, 0x27, 0x24), (0xD3, 0xCB, 0xC1), (0xA5, 0x9C, 0x91))
FONTS = ["/System/Library/Fonts/SFNSRounded.ttf", "/System/Library/Fonts/SFNS.ttf",
         "/System/Library/Fonts/Supplemental/Arial Bold.ttf", "/System/Library/Fonts/Helvetica.ttc",
         "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"]

def font(size, bold=True):
    for f in FONTS:
        if os.path.exists(f):
            try:
                ft = ImageFont.truetype(f, size)
                try: ft.set_variation_by_name("Bold" if bold else "Regular")
                except Exception: pass
                return ft
            except Exception: continue
    return ImageFont.load_default()

def fit(draw, text, size, maxw, bold):
    while size > 20:
        f = font(size, bold)
        if draw.textlength(text, font=f) <= maxw: return f
        size -= 4
    return font(size, bold)

def caption(src, dst, key):
    raw = Image.open(src).convert("RGB")
    W, H = raw.size
    bg, fg, muted = DUSK if key == "dusk" else CALM
    out = Image.new("RGB", (W, H), bg)
    band = int(H * 0.17)
    scale = (H - band - int(H * 0.02)) / H
    shot = raw.resize((int(W * scale), int(H * scale)), Image.LANCZOS)
    mask = Image.new("L", shot.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, shot.size[0] - 1, shot.size[1] - 1], radius=int(W * 0.07), fill=255)
    out.paste(shot, ((W - shot.size[0]) // 2, band), mask)
    d = ImageDraw.Draw(out)
    title, sub = CAPTIONS[key]
    tf = fit(d, title, int(W * 0.072), W * 0.9, True)
    sf = fit(d, sub, int(W * 0.042), W * 0.9, False)
    d.text((W / 2, band * 0.42), title, font=tf, fill=fg, anchor="mm")
    d.text((W / 2, band * 0.74), sub, font=sf, fill=muted, anchor="mm")
    out.save(dst, "PNG")

if __name__ == "__main__":
    root = sys.argv[1] if len(sys.argv) > 1 else "store"
    for src in sorted(glob.glob(os.path.join(root, "*", "raw", "*.png"))):
        name = os.path.basename(src)
        key = name.split("-", 1)[1].rsplit(".", 1)[0]
        if key not in CAPTIONS: continue
        dst = os.path.join(os.path.dirname(os.path.dirname(src)), name)
        caption(src, dst, key)
        print("captioned", dst)
