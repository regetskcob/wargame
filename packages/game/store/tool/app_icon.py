"""Draws the app icon: the tank from above on the ground of the battle map.

    python3 store/tool/app_icon.py

Writes store/ios/icon/AppIcon-1024.png, the iOS app icon set and the web
icons. android_icons.py and compose.py take the layers from here. Needs
Pillow.
"""

import json
import random
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "store" / "ios" / "icon" / "AppIcon-1024.png"
IOS_SET = ROOT / "ios" / "Runner" / "Assets.xcassets" / "AppIcon.appiconset"
WEB = ROOT / "web"

SIZE = 1024
# Drawn at four times the size and scaled down for smooth edges.
SS = 4

# Ground of the Gefechtsplatz map (lib/src/game/map_theme.dart), lifted a
# little so the darker tank outline stands out against it.
GROUND = (0x5E, 0x6B, 0x3A)
PATCHES = [(0x66, 0x76, 0x3F), (0x55, 0x62, 0x34), (0x74, 0x6B, 0x48),
           (0x6C, 0x7A, 0x42)]
DIRT = (0x8F, 0x7E, 0x55)
DIRT_DARK = (0x7A, 0x6A, 0x46)
TREE_OUTER = (0x2E, 0x4A, 0x22)
TREE_INNER = (0x3C, 0x5C, 0x2C)
TREE_EDGE = (0x1F, 0x33, 0x18)
GRASS = (0x47, 0x58, 0x2B)
STONE = (0x9C, 0x8E, 0x70)

OUTLINE = (0x1B, 0x26, 0x16)
TRACK = (0x3D, 0x3D, 0x3D)
TRACK_MARK = (0x2C, 0x2C, 0x2C)
HULL = (0x6B, 0x8F, 0x3B)
TURRET = (0x7F, 0xA7, 0x44)
BARREL = (0x4E, 0x6B, 0x29)
MUZZLE = (0x39, 0x4F, 0x1E)


def _box(*v):
    return [round(x * SS) for x in v]


def terrain(seed=7):
    """The ground layer at SIZE x SIZE, without the tank."""
    s = SIZE * SS
    img = Image.new("RGB", (s, s), GROUND)
    rnd = random.Random(seed)

    patches = Image.new("RGB", (s, s), GROUND)
    pd = ImageDraw.Draw(patches)
    for _ in range(26):
        x, y = rnd.uniform(-100, SIZE + 100), rnd.uniform(-100, SIZE + 100)
        r = rnd.uniform(70, 190)
        pd.ellipse(_box(x - r, y - r * 0.8, x + r, y + r * 0.8),
                   fill=rnd.choice(PATCHES))
    img = patches.filter(ImageFilter.GaussianBlur(40 * SS))

    # Sunlit hill top left, shaded dip bottom right, as on the map.
    light = Image.new("L", (s, s), 0)
    ImageDraw.Draw(light).ellipse(_box(-260, -260, 520, 520), fill=60)
    light = light.filter(ImageFilter.GaussianBlur(120 * SS))
    img = Image.composite(Image.new("RGB", (s, s), (0xF4, 0xEC, 0xC8)), img, light)
    shade = Image.new("L", (s, s), 0)
    ImageDraw.Draw(shade).ellipse(_box(620, 640, 1300, 1320), fill=70)
    shade = shade.filter(ImageFilter.GaussianBlur(120 * SS))
    img = Image.composite(Image.new("RGB", (s, s), (0, 0, 0)), img, shade)

    d = ImageDraw.Draw(img)
    # Churned dirt lane the tank drives along.
    lane = Image.new("L", (s, s), 0)
    ImageDraw.Draw(lane).rounded_rectangle(_box(-60, 360, SIZE + 60, 664),
                                           radius=120 * SS, fill=190)
    lane = lane.filter(ImageFilter.GaussianBlur(22 * SS))
    img = Image.composite(Image.new("RGB", (s, s), DIRT), img, lane)
    d = ImageDraw.Draw(img)
    # Tread marks behind the tank.
    for y in (350, 634):
        for x in range(-20, 260, 34):
            d.rectangle(_box(x, y + 6, x + 18, y + 34), fill=DIRT_DARK)

    # Grass tufts and stones on the meadow, kept off the lane.
    for _ in range(70):
        x, y = rnd.uniform(20, SIZE - 20), rnd.uniform(20, SIZE - 20)
        if 330 < y < 700:
            continue
        if rnd.random() < 0.25:
            r = rnd.uniform(5, 10)
            d.ellipse(_box(x - r, y - r, x + r, y + r), fill=STONE)
        else:
            for dx in (-7, 0, 7):
                d.line(_box(x, y, x + dx, y - rnd.uniform(14, 22)),
                       fill=GRASS, width=4 * SS)

    # Clumps of trees in the corners, cut by the icon mask on the edge.
    for cx, cy, r in ((90, 120, 130), (210, 40, 90), (960, 930, 150),
                      (820, 1010, 100), (1000, 140, 80)):
        d.ellipse(_box(cx - r - 8, cy - r - 8, cx + r + 8, cy + r + 8),
                  fill=TREE_EDGE)
        d.ellipse(_box(cx - r, cy - r, cx + r, cy + r), fill=TREE_OUTER)
        ir = r * 0.55
        d.ellipse(_box(cx - ir - r * 0.15, cy - ir - r * 0.15,
                       cx + ir - r * 0.15, cy + ir - r * 0.15), fill=TREE_INNER)
    return img.resize((SIZE, SIZE), Image.LANCZOS)


def tank():
    """The tank with its shadow on a transparent SIZE x SIZE layer."""
    s = SIZE * SS
    shadow = Image.new("L", (s, s), 0)
    sd = ImageDraw.Draw(shadow)
    sd.rounded_rectangle(_box(232, 322, 832, 746), radius=60 * SS, fill=140)
    sd.rectangle(_box(530, 498, 950, 584), fill=140)
    shadow = shadow.filter(ImageFilter.GaussianBlur(14 * SS))
    img = Image.new("RGBA", (s, s), (0, 0, 0, 255))
    img.putalpha(shadow)

    d = ImageDraw.Draw(img)
    d.rounded_rectangle(_box(212, 300, 812, 724), radius=60 * SS, fill=OUTLINE)
    for top in (320, 604):
        d.rounded_rectangle(_box(232, top, 792, top + 100), radius=50 * SS,
                            fill=TRACK)
        for x in range(262, 780, 40):
            d.rectangle(_box(x, top + 8, x + 14, top + 92), fill=TRACK_MARK)
    d.rounded_rectangle(_box(272, 400, 752, 624), radius=40 * SS, fill=HULL)
    d.rectangle(_box(510, 476, 882, 548), fill=OUTLINE)
    d.rectangle(_box(510, 480, 880, 544), fill=BARREL)
    d.rounded_rectangle(_box(876, 458, 936, 566), radius=10 * SS, fill=OUTLINE)
    d.rounded_rectangle(_box(880, 462, 932, 562), radius=8 * SS, fill=MUZZLE)
    d.ellipse(_box(338, 410, 542, 614), fill=OUTLINE)
    d.ellipse(_box(344, 416, 536, 608), fill=TURRET)
    d.ellipse(_box(400, 472, 480, 552), fill=BARREL)
    return img.resize((SIZE, SIZE), Image.LANCZOS)


def icon():
    base = terrain().convert("RGBA")
    base.alpha_composite(tank())
    return base.convert("RGB")


def main():
    img = icon()
    SOURCE.parent.mkdir(parents=True, exist_ok=True)
    img.save(SOURCE, optimize=True)

    contents = json.loads((IOS_SET / "Contents.json").read_text())
    for entry in contents["images"]:
        if "filename" not in entry:
            continue
        edge = round(float(entry["size"].split("x")[0])
                     * int(entry["scale"].rstrip("x")))
        img.resize((edge, edge), Image.LANCZOS).save(
            IOS_SET / entry["filename"], optimize=True)

    # Maskable icons get cut to a circle of 80 %, the tank fits inside.
    for name, edge in (("favicon.png", 16), ("favicon-32.png", 32),
                       ("icons/Icon-192.png", 192), ("icons/Icon-512.png", 512),
                       ("icons/Icon-maskable-192.png", 192),
                       ("icons/Icon-maskable-512.png", 512),
                       ("icons/apple-touch-icon.png", 180)):
        img.resize((edge, edge), Image.LANCZOS).save(WEB / name, optimize=True)
    print("icons written")


if __name__ == "__main__":
    main()
