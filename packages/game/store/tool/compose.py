"""Builds the store screenshots: a caption over a framed simulator shot.

    python3 store/tool/compose.py <raw dir>

Reads the raw simulator screenshots named in SHOTS from <raw dir> and writes
the finished images to store/ios/screenshots/de-DE/ for the App Store and to
store/android/metadata/android/de-DE/images/ for Google Play, plus the Play
feature graphic. Needs Pillow.
"""

import random
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parents[2]
FONTS = ROOT / "assets" / "fonts"
IOS = ROOT / "store" / "ios" / "screenshots" / "de-DE"
PLAY = ROOT / "store" / "android" / "metadata" / "android" / "de-DE" / "images"

BACKGROUND = (22, 28, 15)
BLOB = (42, 53, 32)
EDGE = (138, 154, 91)
SAND = (194, 168, 120)
AMBER = (255, 179, 0)

# (output name, raw file, canvas size, headline, subline)
IPHONE = (1320, 2868)
IPAD = (2752, 2064)
IOS_SHOTS = [
    ("iphone-01-gefecht", "i_b6", IPHONE, "PANZERGEFECHT",
     "Der letzte Panzer im Feld gewinnt"),
    ("iphone-02-verteidigung", "i_d4", IPHONE, "VERTEIDIGUNG",
     "Haltet den Stützpunkt gegen 8 Wellen"),
    ("iphone-03-geschuetze", "i_d6", IPHONE, "GESCHÜTZE BAUEN",
     "Kanone, Flak und Mörser an der Straße"),
    ("iphone-04-fahrzeuge", "i_lobby2", IPHONE, "8 FAHRZEUGE",
     "Mit jedem Rang ein neues freigespielt"),
    ("iphone-05-steuerung", "i_tut4", IPHONE, "ZWEI DAUMEN",
     "Links fahren, rechts zielen, Zielhilfe an"),
    ("iphone-06-modi", "i_menu", IPHONE, "DREI SPIELARTEN",
     "Allein, gegeneinander oder gemeinsam"),
    ("ipad-01-start", "p_1", IPAD, "DREI SPIELARTEN",
     "Gegen CPU-Panzer, gegen andere oder gemeinsam gegen Wellen"),
    ("ipad-02-verteidigung", "p_d6", IPAD, "VERTEIDIGUNG",
     "Kameraden, Geschütze und Wetter, das die Sicht nimmt"),
    ("ipad-03-warteraum", "p_2b", IPAD, "DEIN EINSATZ",
     "Gelände, Tageszeit, Schwierigkeit und Fahrzeug wählen"),
]

# Google Play wants no side longer than twice the other, which rules out the
# 6.9" iPhone canvas. Phones get 9:16, tablets 16:10, from the same raw shots.
PHONE = (1080, 1920)
TABLET = (2560, 1600)
SMALL_TABLET = (1920, 1200)


PLAY_SHOTS = [
    ("phoneScreenshots/" + name.removeprefix("iphone-"), raw, PHONE, head, sub)
    if size == IPHONE else
    ("tenInchScreenshots/" + name.removeprefix("ipad-"), raw, TABLET, head, sub)
    for name, raw, size, head, sub in IOS_SHOTS
] + [
    ("sevenInchScreenshots/" + name.removeprefix("ipad-"), raw, SMALL_TABLET,
     head, sub)
    for name, raw, size, head, sub in IOS_SHOTS
    if size == IPAD
]

SHOTS = [(IOS / name, *rest) for name, *rest in IOS_SHOTS] + [
    (PLAY / name, *rest) for name, *rest in PLAY_SHOTS
]


def font(name, size):
    return ImageFont.truetype(str(FONTS / name), size)


def spaced(draw, xy, text, fnt, fill, spacing):
    """Draws [text] centred on xy[0] with extra space between the letters."""
    widths = [draw.textlength(c, font=fnt) for c in text]
    total = sum(widths) + spacing * (len(text) - 1)
    x = xy[0] - total / 2
    for c, w in zip(text, widths):
        draw.text((x, xy[1]), c, font=fnt, fill=fill)
        x += w + spacing


def backdrop(size, seed):
    """Dark olive with soft camouflage patches, like the menus in the game."""
    random.seed(seed)
    img = Image.new("RGB", size, BACKGROUND)
    layer = Image.new("RGB", size, BACKGROUND)
    d = ImageDraw.Draw(layer)
    w, h = size
    for _ in range(14):
        rx, ry = random.randint(w // 8, w // 3), random.randint(h // 14, h // 6)
        cx, cy = random.randint(0, w), random.randint(0, h)
        d.ellipse((cx - rx, cy - ry, cx + rx, cy + ry), fill=BLOB)
    layer = layer.filter(ImageFilter.GaussianBlur(min(w, h) // 30))
    return Image.blend(img, layer, 0.55)


def frame(shot, height):
    """Scales [shot] to [height] with rounded corners and the sand edge."""
    width = round(shot.width * height / shot.height)
    shot = shot.convert("RGB").resize((width, height), Image.LANCZOS)
    radius = round(min(width, height) * 0.06)
    border = max(6, round(height * 0.004))
    mask = Image.new("L", (width, height), 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        (0, 0, width - 1, height - 1), radius, fill=255)
    out = Image.new("RGBA", (width + 2 * border, height + 2 * border))
    ImageDraw.Draw(out).rounded_rectangle(
        (0, 0, out.width - 1, out.height - 1), radius + border, fill=EDGE)
    out.paste(shot, (border, border), mask)
    return out


def compose(out, raw, size, headline, subline, raw_dir):
    w, h = size
    portrait = h > w
    canvas = backdrop(size, out.name)
    draw = ImageDraw.Draw(canvas)
    head = font("Roboto-Black.ttf", round(w * (0.085 if portrait else 0.04)))
    sub = font("Roboto-Medium.ttf", round(w * (0.042 if portrait else 0.02)))
    top = round(h * (0.055 if portrait else 0.05))
    spaced(draw, (w / 2, top), headline, head, SAND, round(head.size * 0.08))
    sub_y = top + head.size * 1.25
    draw.text((w / 2, sub_y), subline, font=sub, fill=AMBER, anchor="ma")

    shot = Image.open(raw_dir / f"{raw}.png")
    if shot.height > shot.width:
        # Drops the status strip with the cut-out of the Dynamic Island, the
        # game draws nothing there.
        shot = shot.crop((0, round(shot.height * 0.062), shot.width, shot.height))
    shot_top = round(sub_y + sub.size * 1.9)
    framed = frame(shot, h - shot_top - round(h * 0.03))
    if framed.width > w * 0.94:
        framed = frame(shot, round((w * 0.94) * shot.height / shot.width))
    canvas.paste(framed, ((w - framed.width) // 2, shot_top), framed)

    save(canvas, out)


def feature_graphic():
    """The 1024 x 500 banner Google Play shows above the screenshots."""
    w, h = 1024, 500
    canvas = backdrop((w, h), "feature")
    icon = Image.open(ROOT / "store" / "ios" / "icon" / "AppIcon-1024.png")
    # Only the tank, without the flat background of the icon.
    icon = icon.convert("RGB")
    flat = icon.getpixel((0, 0))
    mask = Image.eval(icon.convert("L"), lambda _: 0)
    mask.putdata([0 if sum(abs(a - b) for a, b in zip(p, flat)) < 12 else 255
                  for p in icon.getdata()])
    mask = mask.filter(ImageFilter.GaussianBlur(2))
    box = (200, 290, 944, 734)
    size = (round((box[2] - box[0]) * 0.46), round((box[3] - box[1]) * 0.46))
    tank = icon.crop(box).resize(size, Image.LANCZOS)
    mask = mask.crop(box).resize(size, Image.LANCZOS)
    canvas.paste(tank, (70, (h - tank.height) // 2), mask)
    draw = ImageDraw.Draw(canvas)
    head = font("Roboto-Black.ttf", 92)
    sub = font("Roboto-Medium.ttf", 34)
    centre = 70 + tank.width + (w - 70 - tank.width) / 2
    spaced(draw, (centre, 150), "WARGAME", head, SAND, 7)
    draw.text((centre, 270), "Panzerduelle und Verteidigung", font=sub,
              fill=AMBER, anchor="ma")
    draw.text((centre, 320), "Allein, gegeneinander, gemeinsam", font=sub,
              fill=EDGE, anchor="ma")
    save(canvas, PLAY / "featureGraphic")


def save(canvas, out):
    out.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(out.with_suffix(".png"), optimize=True)
    print(f"{out.name}.png {canvas.size[0]}x{canvas.size[1]}")


if __name__ == "__main__":
    source = Path(sys.argv[1])
    for entry in SHOTS:
        compose(*entry, source)
    feature_graphic()
