"""Draws the pictures of the iMessage app: its icons and the bubbles.

    python3 store/tool/imessage.py

The icons are the app icon in the wide formats of Messages, the tank stays
whole and the ground fills the sides. The bubbles show a scene of the mode
without any of the game's buttons: tanks of three colours fighting on the
olive ground of the battle map, and the red defence holding its base on a
sandy road against the blue waves. Writes into
ios/MessagesExtension/Assets.xcassets. Needs Pillow.
"""

import json
import math
import random
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

import app_icon

ROOT = Path(__file__).resolve().parents[2]
ASSETS = ROOT / "ios" / "MessagesExtension" / "Assets.xcassets"
ICONS = ASSETS / "iMessage App Icon.stickersiconset"

# Messages crops the bubble picture to about 3:2 in the transcript.
BUBBLE = (1200, 800)
SS = 2

# The side colours of GameConfig.teamColors, with a darker turret and gun.
RED = ((0xE5, 0x53, 0x3D), (0xF0, 0x6E, 0x58), (0x9C, 0x32, 0x24),
       (0x6E, 0x22, 0x18))
BLUE = ((0x4A, 0x90, 0xE2), (0x6A, 0xA8, 0xEE), (0x2C, 0x5C, 0x99),
        (0x1E, 0x40, 0x6C))
OLIVE = (app_icon.HULL, app_icon.TURRET, app_icon.BARREL, app_icon.MUZZLE)

# The desert map of lib/src/game/map_theme.dart, for the defence.
SAND = (0xC9, 0xA6, 0x6B)
SAND_PATCHES = [(0xD9, 0xB9, 0x7F), (0xB8, 0x93, 0x5A), (0xE0, 0xC5, 0x8F),
                (0xA9, 0x85, 0x4E)]
ROAD = (0x8C, 0x6C, 0x40)
WALL = (0xD8, 0xBE, 0x8E)
ROOF = (0xE6, 0xD0, 0xA4)
WALL_EDGE = (0x6B, 0x56, 0x36)
TREE = ((0x1F, 0x33, 0x18), (0x2E, 0x4A, 0x22))


def ground(size, base, patches, seed):
    """Soft patches of colour, lit from the top left like the icon."""
    w, h = size
    rnd = random.Random(seed)
    img = Image.new("RGB", size, base)
    d = ImageDraw.Draw(img)
    for _ in range(30):
        x, y = rnd.uniform(-100, w + 100), rnd.uniform(-100, h + 100)
        r = rnd.uniform(80, 200)
        d.ellipse((x - r, y - r * 0.8, x + r, y + r * 0.8),
                  fill=rnd.choice(patches))
    img = img.filter(ImageFilter.GaussianBlur(38))
    light = Image.new("L", size, 0)
    ImageDraw.Draw(light).ellipse((-300, -300, w * 0.55, h * 0.7), fill=45)
    light = light.filter(ImageFilter.GaussianBlur(140))
    img = Image.composite(Image.new("RGB", size, (0xF4, 0xEC, 0xC8)), img, light)
    shade = Image.new("L", size, 0)
    ImageDraw.Draw(shade).ellipse((w * 0.6, h * 0.55, w + 400, h + 400), fill=60)
    shade = shade.filter(ImageFilter.GaussianBlur(140))
    return Image.composite(Image.new("RGB", size, (0, 0, 0)), img, shade)


def put_tank(img, paint, centre, width, angle):
    """A tank of the icon in paint, width pixels from track to muzzle,
    its gun pointing angle degrees anticlockwise from the right."""
    layer = app_icon.tank(*paint).crop((140, 280, 960, 780))
    scale = width / layer.width
    layer = layer.resize((round(layer.width * scale),
                          round(layer.height * scale)), Image.LANCZOS)
    layer = layer.rotate(angle, resample=Image.BICUBIC, expand=True)
    img.alpha_composite(layer, (round(centre[0] - layer.width / 2),
                                round(centre[1] - layer.height / 2)))


def muzzle(centre, width, angle):
    """Where the shell leaves the gun of a tank put by put_tank."""
    reach = width * 0.47
    a = math.radians(angle)
    return centre[0] + math.cos(a) * reach, centre[1] - math.sin(a) * reach


def tracer(img, start, end):
    d = ImageDraw.Draw(img)
    steps = 14
    for i in range(steps):
        t0, t1 = i / steps, (i + 0.6) / steps
        alpha = round(60 + 180 * i / steps)
        d.line([(start[0] + (end[0] - start[0]) * t0,
                 start[1] + (end[1] - start[1]) * t0),
                (start[0] + (end[0] - start[0]) * t1,
                 start[1] + (end[1] - start[1]) * t1)],
               fill=(0xFF, 0xD8, 0x6A, alpha), width=6)
    d.ellipse((end[0] - 9, end[1] - 9, end[0] + 9, end[1] + 9),
              fill=(0xFF, 0xF2, 0xB0, 255))


def blast(img, centre, radius):
    """A burst of fire and smoke, as a hit shows it."""
    x, y = centre
    glow = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(glow)
    rnd = random.Random(int(x * 7 + y))
    for _ in range(9):
        dx, dy = rnd.uniform(-0.5, 0.5) * radius, rnd.uniform(-0.5, 0.5) * radius
        r = rnd.uniform(0.35, 0.6) * radius
        d.ellipse((x + dx - r, y + dy - r, x + dx + r, y + dy + r),
                  fill=(0x3A, 0x34, 0x2C, 150))
    glow = glow.filter(ImageFilter.GaussianBlur(radius * 0.15))
    img.alpha_composite(glow)
    fire = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(fire)
    for r, colour in ((0.75, (0xF2, 0x7A, 0x1F, 230)),
                      (0.5, (0xFF, 0xB3, 0x00, 240)),
                      (0.28, (0xFF, 0xF0, 0xB8, 255))):
        d.ellipse((x - r * radius, y - r * radius, x + r * radius,
                   y + r * radius), fill=colour)
    img.alpha_composite(fire.filter(ImageFilter.GaussianBlur(radius * 0.08)))


def tree(img, centre, radius):
    x, y = centre
    shadow = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ImageDraw.Draw(shadow).ellipse(
        (x - radius + 10, y - radius + 14, x + radius + 10, y + radius + 14),
        fill=(0, 0, 0, 110))
    img.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(10)))
    d = ImageDraw.Draw(img)
    d.ellipse((x - radius, y - radius, x + radius, y + radius), fill=TREE[0])
    r = radius * 0.72
    d.ellipse((x - r - radius * 0.1, y - r - radius * 0.12,
               x + r - radius * 0.1, y + r - radius * 0.12), fill=TREE[1])


def battle():
    w, h = BUBBLE
    img = ground(BUBBLE, app_icon.GROUND, app_icon.PATCHES, 5).convert("RGBA")
    # The churned lane of the icon, crossing the field.
    lane = Image.new("L", BUBBLE, 0)
    ImageDraw.Draw(lane).rounded_rectangle((-60, 330, w + 60, 520),
                                           radius=90, fill=170)
    lane = lane.filter(ImageFilter.GaussianBlur(20))
    img = Image.composite(Image.new("RGBA", BUBBLE, app_icon.DIRT + (255,)),
                          img, lane)
    for centre, radius in (((150, 130), 70), ((1080, 160), 85),
                           ((1110, 690), 60), ((330, 700), 55)):
        tree(img, centre, radius)

    red, blue, olive = ((300, 430), 300, 8), ((900, 400), 300, 186), \
        ((620, 640), 250, 112)
    put_tank(img, OLIVE, *olive)
    put_tank(img, BLUE, *blue)
    put_tank(img, RED, *red)
    hit = (835, 380)
    tracer(img, muzzle(*red), hit)
    blast(img, hit, 90)
    return img.convert("RGB")


def defense():
    w, h = BUBBLE
    img = ground(BUBBLE, SAND, SAND_PATCHES, 9).convert("RGBA")
    # The road the waves come down, from the top left to the base.
    road = Image.new("L", BUBBLE, 0)
    rd = ImageDraw.Draw(road)
    path = [(-80, 190), (430, 190), (430, 560), (980, 560)]
    rd.line(path, fill=235, width=150, joint="curve")
    for x, y in path[1:3]:
        rd.ellipse((x - 75, y - 75, x + 75, y + 75), fill=235)
    road = road.filter(ImageFilter.GaussianBlur(5))
    img = Image.composite(Image.new("RGBA", BUBBLE, ROAD + (255,)), img, road)

    # The base at the end of the road: walls around a roof, a red flag.
    d = ImageDraw.Draw(img)
    bx, by, half = 1040, 540, 120
    shadow = Image.new("RGBA", BUBBLE, (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle(
        (bx - half + 16, by - half + 20, bx + half + 16, by + half + 20),
        radius=24, fill=(0, 0, 0, 120))
    img.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(14)))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle((bx - half, by - half, bx + half, by + half),
                        radius=24, fill=WALL_EDGE)
    d.rounded_rectangle((bx - half + 10, by - half + 10, bx + half - 10,
                         by + half - 10), radius=18, fill=WALL)
    d.rounded_rectangle((bx - 62, by - 62, bx + 62, by + 62), radius=12,
                        fill=ROOF, outline=WALL_EDGE, width=6)
    d.line([(bx + 10, by - 40), (bx + 10, by - 150)], fill=WALL_EDGE, width=8)
    d.polygon([(bx + 14, by - 150), (bx + 92, by - 128), (bx + 14, by - 104)],
              fill=RED[0])

    # A gun beside the road, the red tank in front of the base.
    gx, gy = 640, 380
    d.ellipse((gx - 58, gy - 58, gx + 58, gy + 58), fill=WALL_EDGE)
    d.ellipse((gx - 48, gy - 48, gx + 48, gy + 48), fill=(0x8E, 0x8E, 0x86))
    d.line([(gx, gy), (gx - 26, gy + 92)], fill=(0x2E, 0x2E, 0x2A), width=22)
    d.ellipse((gx - 24, gy - 24, gx + 24, gy + 24), fill=RED[2])

    for centre, radius in (((120, 640), 75), ((760, 140), 60)):
        tree(img, centre, radius)
    first, second = ((560, 560), 210, 0), ((430, 300), 210, 270)
    put_tank(img, BLUE, *second)
    put_tank(img, BLUE, *first)
    defender = ((880, 380), 240, 210)
    put_tank(img, RED, *defender)
    hit = (650, 545)
    tracer(img, muzzle(*defender), hit)
    blast(img, hit, 85)
    return img.convert("RGB")


def wide_icon(width, height):
    """The app icon on a wider plate: the tank as big as on the square
    icon of the same height, the ground carried on to both sides."""
    square = app_icon.icon()
    plate = app_icon.terrain().resize((width, round(width * square.height
                                                    / square.width)),
                                      Image.LANCZOS)
    top = (plate.height - height) // 2
    plate = plate.crop((0, top, width, top + height)).convert("RGBA")
    tank = app_icon.tank().resize((height, height), Image.LANCZOS)
    plate.alpha_composite(tank, ((width - height) // 2, 0))
    return plate.convert("RGB")


def icons():
    contents = json.loads((ICONS / "Contents.json").read_text())
    for entry in contents["images"]:
        w, h = (float(v) for v in entry["size"].split("x"))
        scale = int(entry["scale"].rstrip("x"))
        size = (round(w * scale), round(h * scale))
        img = app_icon.icon().resize(size, Image.LANCZOS) \
            if size[0] == size[1] else wide_icon(*size)
        img.save(ICONS / entry["filename"], optimize=True)


def main():
    icons()
    for name, picture in (("InviteBattle", battle()),
                          ("InviteDefense", defense())):
        picture.save(ASSETS / f"{name}.imageset" / "invite.jpg", quality=86)
    print("iMessage pictures written")


if __name__ == "__main__":
    main()
