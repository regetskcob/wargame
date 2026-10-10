"""Builds the store screenshots: a caption over a framed simulator shot.

    python3 store/tool/compose.py <raw dir>

Reads the raw simulator screenshots named in SHOTS from <raw dir>/de-DE and
<raw dir>/en-US and writes the finished images for each language to
store/ios/screenshots/<lang>/ for the App Store and to
store/android/metadata/android/<lang>/images/ for Google Play, plus the Play
feature graphic, the Mac and Apple TV shots (store/ios/mac|tv/<lang>/) and
the App Store header artwork (store/ios/header/<lang>/). The raw shots come
from tool/store_shots.sh. The Apple Watch shots in store/ios/watch/<lang>/
go up as the simulator took them (422 x 514) and are kept as they are; the
header takes its watch from there. Needs Pillow.
"""

import random
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

import app_icon

ROOT = Path(__file__).resolve().parents[2]
FONTS = ROOT / "assets" / "fonts"
LANGS = ("de-DE", "en-US")


def ios_dir(lang):
    return ROOT / "store" / "ios" / "screenshots" / lang


def play_dir(lang):
    return ROOT / "store" / "android" / "metadata" / "android" / lang / "images"


BACKGROUND = (22, 28, 15)
BLOB = (42, 53, 32)
EDGE = (138, 154, 91)
SAND = (194, 168, 120)
AMBER = (255, 179, 0)

# (output name, raw file, canvas size, {lang: (headline, subline)})
IPHONE = (1320, 2868)
IPAD = (2752, 2064)
IOS_SHOTS = [
    ("iphone-01-gefecht", "i_battle", IPHONE, {
        "de-DE": ("PANZERGEFECHT", "Links fahren, rechts zielen, der Letzte gewinnt"),
        "en-US": ("TANK BATTLE", "Drive left, aim right, last tank wins"),
    }),
    ("iphone-02-verteidigung", "i_defense", IPHONE, {
        "de-DE": ("VERTEIDIGUNG", "Geschütze bauen, 8 Wellen halten"),
        "en-US": ("DEFENSE", "Build guns, hold off 8 waves"),
    }),
    ("iphone-03-fahrzeuge", "i_lobby", IPHONE, {
        "de-DE": ("8 FAHRZEUGE", "Mit jedem Rang ein neues freigespielt"),
        "en-US": ("8 VEHICLES", "A new one with every rank"),
    }),
    ("iphone-04-modi", "i_menu", IPHONE, {
        "de-DE": ("VIER SPIELARTEN", "Allein, gegeneinander, im Trupp, Fahnenraub"),
        "en-US": ("4 WAYS TO PLAY", "Solo, versus, as a squad, capture the flag"),
    }),
    ("ipad-01-gefecht", "p_battle", IPAD, {
        "de-DE": ("PANZERGEFECHT",
                  "Gegen CPU-Panzer oder andere, in Stadt, Wüste und Winter"),
        "en-US": ("TANK BATTLE",
                  "Against CPU tanks or others, in town, desert and snow"),
    }),
    ("ipad-02-verteidigung", "p_defense", IPAD, {
        "de-DE": ("VERTEIDIGUNG",
                  "Kameraden, Geschütze und ein Stützpunkt, der wächst"),
        "en-US": ("DEFENSE", "Comrades, guns and a base that grows"),
    }),
    ("ipad-03-warteraum", "p_room", IPAD, {
        "de-DE": ("DEIN EINSATZ",
                  "Freunde per Code oder QR-Code einladen, Fahrzeug wählen"),
        "en-US": ("YOUR MISSION",
                  "Invite friends by code or QR code, pick your vehicle"),
    }),
]

# The Mac App Store takes 16:10 (2880 x 1800), the Apple TV 16:9
# (3840 x 2160). Both are uploaded by hand, so they live beside
# screenshots/ like the watch.
MAC = (2880, 1800)
TV = (3840, 2160)
MAC_SHOTS = [
    ("mac-01-gefecht", "m_battle", MAC, {
        "de-DE": ("PANZERGEFECHT",
                  "Tastatur, Maus oder Controller, im Vollbild"),
        "en-US": ("TANK BATTLE", "Keyboard, mouse or controller, full screen"),
    }),
    ("mac-02-verteidigung", "m_defense", MAC, {
        "de-DE": ("VERTEIDIGUNG", "Geschütze bauen, 8 Wellen halten"),
        "en-US": ("DEFENSE", "Build guns, hold off 8 waves"),
    }),
    ("mac-03-warteraum", "m_room", MAC, {
        "de-DE": ("DEIN EINSATZ",
                  "Freunde per Code oder QR-Code einladen, Fahrzeug wählen"),
        "en-US": ("YOUR MISSION",
                  "Invite friends by code or QR code, pick your vehicle"),
    }),
]
TV_SHOTS = [
    ("tv-01-gefecht", "tv_battle", TV, {
        "de-DE": ("PANZERGEFECHT", "Auf dem großen Bildschirm, mit Controller"),
        "en-US": ("TANK BATTLE", "On the big screen, with a controller"),
    }),
    ("tv-02-verteidigung", "tv_defense", TV, {
        "de-DE": ("VERTEIDIGUNG", "Den Stützpunkt halten, mit Kameraden und Geschützen"),
        "en-US": ("DEFENSE", "Hold the base with comrades and guns"),
    }),
]


def store_dir(kind, lang):
    return ROOT / "store" / "ios" / kind / lang


# Google Play wants no side longer than twice the other, which rules out the
# 6.9" iPhone canvas. Phones get 9:16, tablets 16:10, from the same raw shots.
PHONE = (1080, 1920)
TABLET = (2560, 1600)
SMALL_TABLET = (1920, 1200)


PLAY_SHOTS = [
    ("phoneScreenshots/" + name.removeprefix("iphone-"), raw, PHONE, text)
    if size == IPHONE else
    ("tenInchScreenshots/" + name.removeprefix("ipad-"), raw, TABLET, text)
    for name, raw, size, text in IOS_SHOTS
] + [
    ("sevenInchScreenshots/" + name.removeprefix("ipad-"), raw, SMALL_TABLET,
     text)
    for name, raw, size, text in IOS_SHOTS
    if size == IPAD
]

# App Store Connect asks for the 6.3" iPhone as its own required size and
# does not take the 6.9" shots there.
IPHONE_63 = (1206, 2622)
IOS_63_SHOTS = [
    (name.replace("iphone-", "iphone63-"), raw, IPHONE_63, text)
    for name, raw, size, text in IOS_SHOTS
    if size == IPHONE
]

SHOTS = [
    (lang, ios_dir(lang) / name, raw, size, *text[lang])
    for lang in LANGS
    for name, raw, size, text in IOS_SHOTS + IOS_63_SHOTS
] + [
    (lang, play_dir(lang) / name, raw, size, *text[lang])
    for lang in LANGS
    for name, raw, size, text in PLAY_SHOTS
] + [
    (lang, store_dir(kind, lang) / name, raw, size, *text[lang])
    for lang in LANGS
    for kind, shots in (("mac", MAC_SHOTS), ("tv", TV_SHOTS))
    for name, raw, size, text in shots
]

FEATURE = {
    "de-DE": ("Panzerduelle und Verteidigung",
              "Allein, gegeneinander, gemeinsam"),
    "en-US": ("Tank duels and tower defense",
              "Alone, against others, together"),
}


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


BODY = (24, 26, 22)
METAL = (120, 124, 112)
METAL_LIGHT = (196, 198, 186)


def device(shot, height, kind):
    """Draws [shot] inside an illustrated [kind] ("phone", "tablet" or
    "watch"): a dark body with a metal edge, its buttons and a soft gloss on
    the glass, scaled so the whole device is [height] tall."""
    bezel = {"phone": 0.022, "tablet": 0.035, "watch": 0.075, "tv": 0.018,
             "laptop": 0.03}[kind]
    rounding = {"phone": 0.16, "tablet": 0.05, "watch": 0.30, "tv": 0.012,
                "laptop": 0.035}[kind]
    rim = max(4, round(height * 0.006))
    pad = round(height * bezel)
    screen_h = height - 2 * (pad + rim)
    screen_w = round(shot.width * screen_h / shot.height)
    body_w, body_h = screen_w + 2 * (pad + rim), height
    # Room beside the body for the buttons, above and below for the band.
    knob = {"watch": round(body_w * 0.05),
            "laptop": round(body_w * 0.07)}.get(kind, rim * 2)
    band = round(body_h * 0.18) if kind == "watch" else 0
    stand = {"tv": round(body_h * 0.10),
             "laptop": round(body_h * 0.05)}.get(kind, 0)
    out = Image.new("RGBA", (body_w + 2 * knob, body_h + 2 * band + stand))
    d = ImageDraw.Draw(out)
    ox, oy = knob, band
    radius = round(min(body_w, body_h) * rounding)

    if kind == "watch":
        # The band, fading out towards both ends.
        bw = round(body_w * 0.62)
        bx = ox + (body_w - bw) // 2
        strap = Image.new("RGBA", out.size)
        sd = ImageDraw.Draw(strap)
        sd.rectangle((bx, 0, bx + bw, out.height), fill=(46, 52, 38))
        for y in list(range(band // 4, band, max(8, band // 5))) + [
                out.height - y for y in range(band // 4, band, max(8, band // 5))]:
            sd.line((bx + bw * 0.2, y, bx + bw * 0.8, y), fill=(36, 41, 30),
                    width=max(2, rim // 2))
        fade = Image.new("L", (1, out.height))
        for y in range(out.height):
            edge = min(y, out.height - 1 - y)
            fade.putpixel((0, y), min(255, round(255 * edge / band)))
        fade = fade.resize(out.size)
        strap.putalpha(Image.composite(fade, Image.new("L", out.size, 0),
                                       strap.getchannel("A")))
        out.alpha_composite(strap)
        # Digital crown and side button.
        cy = oy + round(body_h * 0.30)
        ch = round(body_h * 0.16)
        d.rounded_rectangle((ox + body_w - knob, cy, ox + body_w + knob, cy + ch),
                            knob // 2, fill=METAL)
        for i in range(1, 6):
            yy = cy + ch * i // 6
            d.line((ox + body_w + knob // 3, yy, ox + body_w + knob, yy),
                   fill=METAL_LIGHT, width=max(2, rim // 2))
        sy = cy + ch + round(body_h * 0.08)
        d.rounded_rectangle(
            (ox + body_w - knob, sy, ox + body_w + knob // 2,
             sy + round(body_h * 0.22)), knob // 3, fill=METAL)
    elif kind == "tv":
        # A slim foot below the screen.
        fw, fx = round(body_w * 0.30), ox + round(body_w * 0.35)
        neck = round(body_w * 0.04)
        d.rectangle((ox + (body_w - neck) // 2, oy + body_h - rim,
                     ox + (body_w + neck) // 2, oy + body_h + stand - rim * 2),
                    fill=METAL)
        d.rounded_rectangle((fx, oy + body_h + stand - rim * 3, fx + fw,
                             oy + body_h + stand - 1), rim, fill=METAL)
    elif kind == "laptop":
        # The keyboard half seen edge on: a slab wider than the lid, with
        # the notch to open it in the middle of its front.
        top = oy + body_h - rim
        base_h = stand + rim
        d.rounded_rectangle((0, top, out.width - 1, top + base_h - 1),
                            base_h // 2, fill=METAL)
        d.rectangle((0, top, out.width - 1, top + base_h // 3), fill=METAL_LIGHT)
        nw = round(body_w * 0.14)
        d.rounded_rectangle((ox + (body_w - nw) // 2, top, ox + (body_w + nw) // 2,
                             top + base_h // 3), base_h // 6, fill=METAL)
    else:
        # Volume and power buttons on the edges.
        for x0, ys in (
            (ox - knob, (0.18, 0.27) if kind == "phone" else (0.08,)),
            (ox + body_w - knob // 2, (0.24,) if kind == "phone" else ()),
        ):
            for y in ys:
                top = oy + round(body_h * y)
                d.rounded_rectangle(
                    (x0, top, x0 + knob * 3 // 2, top + round(body_h * 0.07)),
                    knob // 2, fill=METAL)

    # Body: metal rim with a lighter inner line, then the black bezel.
    d.rounded_rectangle((ox, oy, ox + body_w - 1, oy + body_h - 1), radius,
                        fill=METAL)
    d.rounded_rectangle((ox + rim // 3, oy + rim // 3, ox + body_w - 1 - rim // 3,
                         oy + body_h - 1 - rim // 3), radius - rim // 3,
                        fill=METAL_LIGHT)
    d.rounded_rectangle((ox + rim, oy + rim, ox + body_w - 1 - rim,
                         oy + body_h - 1 - rim), radius - rim, fill=BODY)

    screen = shot.convert("RGB").resize((screen_w, screen_h), Image.LANCZOS)
    screen_radius = max(0, radius - rim - pad)
    if kind == "watch":
        screen_radius = round(min(screen_w, screen_h) * 0.22)
    mask = Image.new("L", (screen_w, screen_h), 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        (0, 0, screen_w - 1, screen_h - 1), screen_radius, fill=255)
    sx, sy = ox + rim + pad, oy + rim + pad
    out.paste(screen, (sx, sy), mask)

    # Gloss: a faint light falling from the top left across the glass.
    gloss = Image.new("L", (screen_w, screen_h), 0)
    ImageDraw.Draw(gloss).polygon(
        [(0, 0), (round(screen_w * 0.55), 0), (0, round(screen_h * 0.45))],
        fill=34)
    gloss = gloss.filter(ImageFilter.GaussianBlur(max(4, screen_w // 40)))
    gloss = Image.composite(gloss, Image.new("L", gloss.size, 0), mask)
    out.paste(Image.new("RGB", (screen_w, screen_h), (255, 255, 255)),
              (sx, sy), gloss)

    if kind == "phone":
        iw, ih = round(screen_w * 0.30), round(screen_w * 0.085)
        ix, iy = sx + (screen_w - iw) // 2, sy + round(screen_w * 0.03)
        d.rounded_rectangle((ix, iy, ix + iw, iy + ih), ih // 2, fill=(0, 0, 0))
    elif kind == "tablet":
        r = max(3, pad // 6)
        cx, cy = ox + body_w // 2, oy + rim + pad // 2
        d.ellipse((cx - r, cy - r, cx + r, cy + r), fill=(10, 12, 16))
    return out


def compose(lang, out, raw, size, headline, subline, raw_dir):
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

    # The whole screen in a drawn iPhone or iPad, which reads cleaner in the
    # store than a bare cut-out; the frame brings its own Dynamic Island, so
    # the shot keeps its full height.
    shot = Image.open(raw_dir / lang / f"{raw}.png")
    kind = {"i": "phone", "p": "tablet", "m": "laptop",
            "tv": "tv"}[raw.split("_")[0]]
    shot_top = round(sub_y + sub.size * 1.9)
    room = h - shot_top - round(h * 0.035)
    framed = device(shot, room, kind)
    if framed.width > w * 0.92:
        framed = device(shot, round(room * w * 0.92 / framed.width), kind)
    x = (w - framed.width) // 2
    drop_shadow(canvas, framed, x, shot_top)
    canvas.paste(framed, (x, shot_top), framed)

    save(canvas, out)


def feature_graphic(lang):
    """The 1024 x 500 banner Google Play shows above the screenshots."""
    w, h = 1024, 500
    canvas = backdrop((w, h), "feature")
    # Only the tank with its shadow, without the terrain of the icon.
    layer = app_icon.tank()
    box = (138, 290, 898, 760)
    size = (round((box[2] - box[0]) * 0.46), round((box[3] - box[1]) * 0.46))
    tank = layer.crop(box).resize(size, Image.LANCZOS)
    canvas.paste(tank, (70, (h - tank.height) // 2), tank)
    draw = ImageDraw.Draw(canvas)
    head = font("Roboto-Black.ttf", 60)
    sub = font("Roboto-Medium.ttf", 34)
    centre = 70 + tank.width + (w - 70 - tank.width) / 2
    spaced(draw, (centre, 150), "PANZERGEFECHT", head, SAND, 5)
    line1, line2 = FEATURE[lang]
    draw.text((centre, 270), line1, font=sub, fill=AMBER, anchor="ma")
    draw.text((centre, 320), line2, font=sub, fill=EDGE, anchor="ma")
    save(canvas, play_dir(lang) / "featureGraphic")


# App Store header artwork ("Kopfzeile"): gameplay without captions, as the
# store lays the app's name and icon over it. The interesting part stays in
# the middle, where every crop of the header keeps it.
HEADERS = [(5244, 2950), (3840, 1646)]


def load_shot(raw_dir, lang, name):
    # The game saves its own frame (tool/store_shots.sh), so there is no
    # status bar to cut off.
    return Image.open(raw_dir / lang / f"{name}.png")


def drop_shadow(canvas, img, x, top):
    """A soft shadow below [img] at x, top. It follows the device itself,
    not its bounding box, so a watch band fading out leaves no dark box."""
    shadow = Image.new("RGBA", (img.width + 80, img.height + 80))
    alpha = img.getchannel("A").point(lambda a: a * 150 // 255)
    shadow.paste(Image.new("RGBA", img.size, (0, 0, 0, 255)), (40, 40), alpha)
    shadow = shadow.filter(ImageFilter.GaussianBlur(30))
    canvas.paste(shadow, (x - 40, top - 20), shadow)


def row(canvas, framed, offsets):
    """Lays [framed] side by side, centred, each moved down by its offset."""
    w, h = canvas.size
    gap = round(h * 0.04)
    total = sum(img.width for img in framed) + gap * (len(framed) - 1)
    if total > w * 0.76:
        # Too wide: shrink everything alike, so the store's crop for smaller
        # screens and the name it lays over the art keep the devices whole.
        scale = (w * 0.76 - gap * (len(framed) - 1)) / (total - gap * (len(framed) - 1))
        framed = [img.resize((round(img.width * scale), round(img.height * scale)),
                             Image.LANCZOS) for img in framed]
        offsets = [round(o * scale) for o in offsets]
        total = sum(img.width for img in framed) + gap * (len(framed) - 1)
    x = (w - total) // 2
    boxes = []
    for img, offset in zip(framed, offsets):
        top = (h - img.height) // 2 + offset
        # The shadow follows the device itself, not its bounding box, so a
        # watch band fading out leaves no dark box behind.
        drop_shadow(canvas, img, x, top)
        canvas.paste(img, (x, top), img)
        boxes.append((x, top, img.width, img.height))
        x += img.width + gap
    return boxes


def search_header(lang, size, raw_dir):
    """The header in the search results: iPhone, iPad and watch side by side,
    to show at a glance on which devices the game runs."""
    w, h = size
    canvas = backdrop(size, f"search-{w}")
    row(canvas, [
        device(load_shot(raw_dir, lang, "i_battle"), round(h * 0.68), "phone"),
        device(load_shot(raw_dir, lang, "p_defense"), round(h * 0.72), "tablet"),
        device(load_shot(raw_dir, lang, "w_battle"), round(h * 0.40), "watch"),
    ], [0, 0, 0])
    save(canvas, ROOT / "store" / "ios" / "header" / lang / f"search-{w}x{h}")


def header(lang, size, raw_dir):
    """The product page header, every screen the game runs on: the iPhone in
    front of the iPad, the Mac, the Apple TV and the watch."""
    w, h = size
    canvas = backdrop(size, f"header-{w}")
    # The iPad is drawn as one with the iPhone, which stands in front of
    # its left edge, so the row treats the pair as one piece.
    iphone = device(load_shot(raw_dir, lang, "i_battle"), round(h * 0.52), "phone")
    ipad = device(load_shot(raw_dir, lang, "p_defense"), round(h * 0.58), "tablet")
    overlap = round(iphone.width * 0.35)
    lift = round(h * 0.13)
    pair = Image.new("RGBA", (iphone.width + ipad.width - overlap,
                              max(ipad.height, iphone.height + lift)))
    pair.alpha_composite(ipad, (iphone.width - overlap, 0))
    shade = Image.new("RGBA", pair.size)
    drop_shadow(shade, iphone, 0, lift)
    pair.alpha_composite(shade)
    pair.alpha_composite(iphone, (0, lift))
    # Likewise the MacBook stands in front of the television's right foot.
    tv = device(load_shot(raw_dir, lang, "tv_battle"), round(h * 0.62), "tv")
    mac = device(load_shot(raw_dir, lang, "m_defense"), round(h * 0.40), "laptop")
    drop = round(h * 0.22)
    screens = Image.new("RGBA", (tv.width + round(mac.width * 0.55),
                                 max(tv.height, mac.height + drop)))
    screens.alpha_composite(tv, (0, 0))
    shade = Image.new("RGBA", screens.size)
    mx = screens.width - mac.width
    drop_shadow(shade, mac, mx, drop)
    screens.alpha_composite(shade)
    screens.alpha_composite(mac, (mx, drop))
    row(canvas, [
        pair,
        screens,
        device(load_shot(raw_dir, lang, "w_battle"), round(h * 0.36), "watch"),
    ], [round(h * 0.06), -round(h * 0.02), round(h * 0.08)])
    save(canvas, ROOT / "store" / "ios" / "header" / lang / f"header-{w}x{h}")


def save(canvas, out):
    out.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(out.with_suffix(".png"), optimize=True)
    print(f"{out.name}.png {canvas.size[0]}x{canvas.size[1]}")


if __name__ == "__main__":
    source = Path(sys.argv[1])
    for entry in SHOTS:
        compose(*entry, source)
    for lang in LANGS:
        feature_graphic(lang)
        for size in HEADERS:
            header(lang, size, source)
            search_header(lang, size, source)
