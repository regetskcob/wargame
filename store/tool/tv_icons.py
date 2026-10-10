"""Builds the TV icons, top shelf and launch image from the app icon layers.

    python3 store/tool/tv_icons.py

The tvOS icon is a stack of layers that tilt against each other while it
has the focus: the ground of the app icon at the back, its tank in front.
The top shelf shows the tank and the name on the same ground, the launch
screen the tank alone. Writes into tvos/Runner/Assets.xcassets, and the
banner of the Android TV home screen, drawn like the icon, into
android/app/src/main/res. Needs Pillow.
"""

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

import app_icon

ROOT = Path(__file__).resolve().parents[2]
ASSETS = ROOT / "tvos" / "Runner" / "Assets.xcassets"
BRAND = ASSETS / "AppIcon.brandassets"
ANDROID_RES = ROOT / "android" / "app" / "src" / "main" / "res"
FONT = ROOT / "assets" / "fonts" / "Roboto-Black.ttf"

SAND = (232, 220, 180)
SHADOW = (27, 38, 22)

# The tank with its shadow on the 1024 layer of app_icon.tank().
TANK_BOX = (128, 280, 912, 772)


def cover(image, size):
    """image scaled to fill size and cut to it, around its middle."""
    scale = max(size[0] / image.width, size[1] / image.height)
    image = image.resize(
        (round(image.width * scale), round(image.height * scale)), Image.LANCZOS
    )
    left = (image.width - size[0]) // 2
    top = (image.height - size[1]) // 2
    return image.crop((left, top, left + size[0], top + size[1]))


def placed(tank, size, height, x):
    """The tank scaled to height (share of size) with its middle at x."""
    h = round(size[1] * height)
    w = round(tank.width * h / tank.height)
    layer = Image.new("RGBA", size, (0, 0, 0, 0))
    small = tank.resize((w, h), Image.LANCZOS)
    layer.paste(small, (round(size[0] * x - w / 2), (size[1] - h) // 2), small)
    return layer


def icon_stack(ground, tank, name, base):
    stack = BRAND / f"App Icon - {name.title()}.imagestack"
    for suffix, factor in (("", 1), ("@2x", 2)):
        size = (base[0] * factor, base[1] * factor)

        def layer(kind):
            return stack / f"{kind}.imagestacklayer" / "Content.imageset" / (
                f"{name}_{kind.lower()}{suffix}.png"
            )

        cover(ground, size).save(layer("Back"), optimize=True)
        Image.new("RGBA", size, (0, 0, 0, 0)).save(layer("Middle"))
        placed(tank, size, 0.66, 0.5).save(layer("Front"), optimize=True)


def top_shelf(ground, tank, folder, file, base):
    for suffix, factor in (("", 1), ("@2x", 2)):
        size = (base[0] * factor, base[1] * factor)
        image = cover(ground, size).convert("RGBA")
        image.alpha_composite(placed(tank, size, 0.55, 0.24))
        draw = ImageDraw.Draw(image)
        font = ImageFont.truetype(str(FONT), round(size[1] * 0.15))
        text = "PANZERGEFECHT"
        box = draw.textbbox((0, 0), text, font=font)
        x = round(size[0] * 0.43)
        y = (size[1] - (box[3] - box[1])) // 2 - box[1]
        offset = round(size[1] * 0.008)
        draw.text((x + offset, y + offset), text, font=font, fill=SHADOW)
        draw.text((x, y), text, font=font, fill=SAND)
        image.convert("RGB").save(
            BRAND / folder / f"{file}{suffix}.png", optimize=True
        )


def android_banner(ground, tank):
    """The banner Android TV, Google TV and Fire TV show for the app: 320 by
    180 dp, drawn like the Apple TV icon, the tank in the middle of the
    ground, without the name."""
    for folder, factor in (("drawable-xhdpi", 1), ("drawable-xxxhdpi", 2)):
        size = (320 * factor, 180 * factor)
        image = cover(ground, size).convert("RGBA")
        image.alpha_composite(placed(tank, size, 0.66, 0.5))
        out = ANDROID_RES / folder
        out.mkdir(exist_ok=True)
        image.convert("RGB").save(out / "tv_banner.png", optimize=True)


def launch_image(tank):
    """The tank on the dark launch screen, as large as on a phone held at
    arm's length: 360 points wide."""
    folder = ASSETS / "LaunchImage.imageset"
    folder.mkdir(exist_ok=True)
    for suffix, width in (("", 360), ("@2x", 720)):
        h = round(tank.height * width / tank.width)
        tank.resize((width, h), Image.LANCZOS).save(
            folder / f"LaunchImage{suffix}.png", optimize=True
        )
    (folder / "Contents.json").write_text(
        '{\n  "images" : [\n'
        '    { "idiom" : "tv", "filename" : "LaunchImage.png", "scale" : "1x" },\n'
        '    { "idiom" : "tv", "filename" : "LaunchImage@2x.png", "scale" : "2x" }\n'
        '  ],\n  "info" : { "version" : 1, "author" : "xcode" }\n}\n'
    )


def main():
    ground = app_icon.terrain().convert("RGBA")
    tank = app_icon.tank().crop(TANK_BOX)
    icon_stack(ground, tank, "small", (400, 240))
    icon_stack(ground, tank, "large", (1280, 768))
    top_shelf(ground, tank, "Top Shelf Image.imageset", "top_shelf", (1920, 720))
    top_shelf(
        ground, tank, "Top Shelf Image Wide.imageset", "top_shelf_wide", (2320, 720)
    )
    launch_image(tank)
    android_banner(ground, tank)
    print("tvOS icons and Android TV banner written")


if __name__ == "__main__":
    main()
