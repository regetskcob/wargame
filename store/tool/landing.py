"""Builds the device artwork at the top of the landing page (site/).

    python3 store/tool/landing.py <raw dir>

Unlike the App Store header it shows every platform the game runs on or
is about to, all alike: the page says below what is out today, the picture
sells the idea of one room on every screen. Three small scenes on one
table: the desk (Android tablet, iPad, the browser on a MacBook), the
living room (the TV, an iPhone at its edge, a phone as its controller in
front of its foot) and pocket and wrist (Android phone, Wear OS, Apple
Watch). Devices on the back line of the table stand a little smaller and
darker than those in front. Reads the raw shots of tool/store_shots.sh and
the Apple Watch shots in store/ios/watch/, writes
site/assets/header/<lang>/devices.png and, two tables high for phones,
devices-narrow.png. Needs Pillow.
"""

import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageEnhance, ImageFilter

from compose import EDGE, LANGS, ROOT, backdrop, device, font

WEB_ADDRESS = "regetskcob.de/wargame/play"


def shot(raw_dir, lang, name):
    return Image.open(raw_dir / lang / f"{name}.png").convert("RGB")


def watch_shot(lang, name):
    return Image.open(ROOT / "store" / "ios" / "watch" / lang /
                      f"{name}.png").convert("RGB")


def browser(page):
    """[page] under a plain browser bar: three dots and the address."""
    bar = round(page.height * 0.045)
    out = Image.new("RGB", (page.width, page.height + bar), (30, 33, 26))
    d = ImageDraw.Draw(out)
    r = bar // 7
    for i in range(3):
        cx = bar * 0.6 + i * r * 3.4
        d.ellipse((cx - r, bar / 2 - r, cx + r, bar / 2 + r), fill=(84, 90, 72))
    pill_w = round(page.width * 0.42)
    px = (page.width - pill_w) // 2
    d.rounded_rectangle((px, round(bar * 0.2), px + pill_w, round(bar * 0.8)),
                        round(bar * 0.3), fill=(20, 22, 17))
    d.text((page.width / 2, bar / 2), WEB_ADDRESS,
           font=font("Roboto-Medium.ttf", round(bar * 0.36)),
           fill=(150, 156, 132), anchor="mm")
    out.paste(page, (0, bar))
    return out


def round_face(img):
    """The middle square of a watch shot, for the round Wear OS face."""
    side = min(img.size)
    left, top = (img.width - side) // 2, (img.height - side) // 2
    return img.crop((left, top, left + side, top + side))


def strapless_bottom(img):
    """A watch standing on its band: cut the band where it would fade into
    the floor line, so it rests on it instead of hovering above."""
    alpha = img.getchannel("A")
    column = [alpha.getpixel((img.width // 2, y)) for y in range(img.height)]
    bottom = max(y for y, a in enumerate(column) if a > 200)
    return img.crop((0, 0, img.width, bottom + 1))


def contact_shadow(canvas, x, width, floor):
    """A soft dark oval under a device where it touches the floor."""
    w, h = width, max(8, width // 9)
    layer = Image.new("RGBA", (w + 120, h + 120))
    ImageDraw.Draw(layer).ellipse((60, 60, 60 + w, 60 + h),
                                  fill=(0, 0, 0, 150))
    layer = layer.filter(ImageFilter.GaussianBlur(h // 2 + 6))
    canvas.alpha_composite(layer, (x - 60, floor - h // 2 - 60))


def landscape(img):
    """A phone held sideways: the upright device drawn, then turned."""
    return img.rotate(90, expand=True)


def pictures(raw_dir, lang):
    """The device for each key, drawn at a nominal height of 1000."""
    h = 1000
    return {
        "atablet": device(shot(raw_dir, lang, "p_battle"), h, "atablet"),
        "ipad": device(shot(raw_dir, lang, "p_defense"), h, "tablet"),
        "tv": device(shot(raw_dir, lang, "tv_defense"), h, "tv"),
        "wear": strapless_bottom(device(round_face(watch_shot(
            lang, "watch-04-verteidigung")), h, "wear")),
        "android": device(shot(raw_dir, lang, "i_defense"), h, "android"),
        "iphone": device(shot(raw_dir, lang, "i_battle"), h, "phone"),
        "browser": device(browser(shot(raw_dir, lang, "m_battle")), h, "laptop"),
        "pad": landscape(device(shot(raw_dir, lang, "i_pad").rotate(-90, expand=True),
                                h, "phone")),
        "watch": strapless_bottom(device(shot(raw_dir, lang, "w_battle"), h,
                                         "watch")),
    }


# Each entry: (key, table, back or front line, centre x as a share of the
# width, height as a share of the canvas height). Drawn in this order, so a
# later device stands in front of an earlier one.
WIDE = [
    # The desk: the Android tablet a step behind, iPad and MacBook side by
    # side.
    ("atablet", 0, "back", 0.08, 0.30),
    ("ipad", 0, "front", 0.10, 0.31),
    ("browser", 0, "front", 0.30, 0.37),
    # The living room: the TV, the phone as its controller right in front
    # of its foot, and an iPhone between it and the MacBook, in front of
    # the MacBook's edge.
    ("tv", 0, "back", 0.615, 0.64),
    ("pad", 0, "front", 0.635, 0.16),
    ("iphone", 0, "front", 0.40, 0.38),
    # Pocket and wrist.
    ("android", 0, "front", 0.835, 0.34),
    ("wear", 0, "front", 0.905, 0.16),
    ("watch", 0, "front", 0.965, 0.20),
]
# For phones: the living room on the upper table, desk, pocket and wrist on
# the lower one.
NARROW = [
    ("tv", 0, "back", 0.58, 0.36),
    ("iphone", 0, "front", 0.24, 0.24),
    ("pad", 0, "front", 0.61, 0.10),
    ("atablet", 1, "back", 0.13, 0.17),
    ("ipad", 1, "front", 0.14, 0.18),
    ("browser", 1, "front", 0.405, 0.20),
    ("android", 1, "front", 0.645, 0.20),
    ("wear", 1, "front", 0.775, 0.09),
    ("watch", 1, "front", 0.895, 0.12),
]

# How much smaller and darker the back line stands.
DEPTH = {"back": (0.92, 0.85), "front": (1.0, 1.0)}


def table(canvas, back, bottom):
    """A table top from the back line down to [bottom]: a plane a shade
    lighter than the wall behind, its edges fading out at the sides."""
    w = canvas.width
    h = bottom - back
    plane = Image.new("RGBA", (w, h))
    d = ImageDraw.Draw(plane)
    for y in range(h):
        # A little lighter towards the front, gone again at the bottom, so
        # a table above another one ends without an edge.
        t = y / max(1, h)
        fall = min(1.0, (1 - t) / 0.35)
        d.line((0, y, w, y), fill=(*EDGE, round((26 + 20 * t) * fall)))
    d.line((0, 0, w, 0), fill=(*EDGE, 90), width=3)
    fade = Image.new("L", (w, 1))
    for x in range(w):
        fade.putpixel((x, 0), round(255 * min(1.0, min(x, w - 1 - x) / (w * 0.12))))
    alpha = Image.composite(plane.getchannel("A"), Image.new("L", (w, h)),
                            fade.resize((w, h)))
    plane.putalpha(alpha)
    canvas.alpha_composite(plane, (0, back))


def scene(lang, raw_dir, layout, size, tables, name):
    """Draws [layout] on [tables], each a (back line, front line, bottom of
    its top) in pixels, and saves it as [name]."""
    w, h = size
    canvas = backdrop(size, f"landing-{w}x{h}").convert("RGBA")
    for back, _, bottom in tables:
        table(canvas, back, bottom)
    art = pictures(raw_dir, lang)
    for key, index, line, cx, height in layout:
        scale, light = DEPTH[line]
        img = art[key]
        target = round(h * height * scale)
        img = img.resize((round(img.width * target / img.height), target),
                         Image.LANCZOS)
        if light < 1:
            alpha = img.getchannel("A")
            img = ImageEnhance.Brightness(img.convert("RGB")).enhance(light)
            img = img.convert("RGBA")
            img.putalpha(alpha)
        back, front, _ = tables[index]
        floor = back if line == "back" else front
        x = round(w * cx - img.width / 2)
        contact_shadow(canvas, x + img.width // 10, img.width * 8 // 10, floor)
        canvas.alpha_composite(img, (x, floor - img.height))
    path = ROOT / "site" / "assets" / "header" / lang / f"{name}.png"
    path.parent.mkdir(parents=True, exist_ok=True)
    canvas.convert("RGB").save(path, optimize=True)
    print(f"{path.relative_to(ROOT)} {w}x{h}")


def wide(lang, raw_dir):
    w, h = 3840, 1300
    scene(lang, raw_dir, WIDE, (w, h),
          [(round(h * 0.80), round(h * 0.90), h)], "devices")


def narrow(lang, raw_dir):
    w, h = 1800, 1600
    scene(lang, raw_dir, NARROW, (w, h),
          [(round(h * 0.43), round(h * 0.51), round(h * 0.57)),
           (round(h * 0.85), round(h * 0.93), h)], "devices-narrow")


if __name__ == "__main__":
    source = Path(sys.argv[1])
    for lang in LANGS:
        wide(lang, source)
        narrow(lang, source)
