"""Draws the Apple TV app icon layers and top shelf images from the phone icon.

The tvOS icon is a stack of layers that tilt against each other when it has
the focus: the camouflage at the back, the tank in front. The top shelf shows
the tank and the name over the same camouflage.

Run from the project root, needs Pillow:

    python3 tool/gen_tv_icons.py
"""

from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png"
BRAND = ROOT / "tvos/Runner/Assets.xcassets/AppIcon.brandassets"
FONT = ROOT / "assets/fonts/Roboto-Black.ttf"

# Where the tank sits on the 1024 pixel phone icon: hull with tracks, and the
# barrel that reaches out to the right.
HULL = (150, 298, 750, 724)
BARREL = (470, 474, 822, 550)
MUZZLE = (814, 457, 876, 567)


def tank_layer(icon: Image.Image) -> Image.Image:
    """The tank alone, on a transparent ground, cropped to its outline."""
    mask = Image.new("L", icon.size, 0)
    draw = ImageDraw.Draw(mask)
    draw.rounded_rectangle(HULL, radius=58, fill=255)
    draw.rectangle(BARREL, fill=255)
    draw.rounded_rectangle(MUZZLE, radius=8, fill=255)
    tank = Image.new("RGBA", icon.size, (0, 0, 0, 0))
    tank.paste(icon, mask=mask)
    return tank.crop((HULL[0], HULL[1], MUZZLE[2], HULL[3]))


def camouflage(icon: Image.Image, size: tuple[int, int]) -> Image.Image:
    """The blurred camouflage of the icon, without the tank, filling size."""
    ground = icon.convert("RGB").copy()
    # Cover the tank with the ground above it before blurring it away.
    strip = ground.crop((HULL[0] - 20, 0, MUZZLE[2] + 20, HULL[1] - 10))
    strip = strip.resize((strip.width, HULL[3] - HULL[1] + 40))
    ground.paste(strip, (HULL[0] - 20, HULL[1] - 20))
    ground = ground.filter(ImageFilter.GaussianBlur(40))
    scale = max(size[0] / ground.width, size[1] / ground.height)
    ground = ground.resize(
        (round(ground.width * scale), round(ground.height * scale)),
        Image.LANCZOS,
    )
    left = (ground.width - size[0]) // 2
    top = (ground.height - size[1]) // 2
    return ground.crop((left, top, left + size[0], top + size[1]))


def placed(tank: Image.Image, size: tuple[int, int], height: float, x: float):
    """The tank scaled to height (share of size) with its centre at x."""
    h = round(size[1] * height)
    w = round(tank.width * h / tank.height)
    layer = Image.new("RGBA", size, (0, 0, 0, 0))
    small = tank.resize((w, h), Image.LANCZOS)
    layer.paste(small, (round(size[0] * x - w / 2), (size[1] - h) // 2), small)
    return layer


def icon_stack(icon, tank, name: str, base: tuple[int, int]) -> None:
    for suffix, factor in (("", 1), ("@2x", 2)):
        size = (base[0] * factor, base[1] * factor)
        stack = BRAND / f"App Icon - {name.title()}.imagestack"
        layers = stack / "{}.imagestacklayer/Content.imageset"
        camouflage(icon, size).save(
            str(layers).format("Back") + f"/{name}_back{suffix}.png"
        )
        Image.new("RGBA", size, (0, 0, 0, 0)).save(
            str(layers).format("Middle") + f"/{name}_middle{suffix}.png"
        )
        placed(tank, size, 0.62, 0.5).save(
            str(layers).format("Front") + f"/{name}_front{suffix}.png"
        )


def top_shelf(icon, tank, folder: str, file: str, base: tuple[int, int]):
    for suffix, factor in (("", 1), ("@2x", 2)):
        size = (base[0] * factor, base[1] * factor)
        image = camouflage(icon, size).convert("RGBA")
        image.alpha_composite(placed(tank, size, 0.5, 0.25))
        draw = ImageDraw.Draw(image)
        font = ImageFont.truetype(str(FONT), round(size[1] * 0.15))
        text = "PANZERGEFECHT"
        box = draw.textbbox((0, 0), text, font=font)
        x = round(size[0] * 0.43)
        y = (size[1] - (box[3] - box[1])) // 2 - box[1]
        shadow = round(size[1] * 0.008)
        draw.text((x + shadow, y + shadow), text, font=font, fill=(20, 26, 16))
        draw.text((x, y), text, font=font, fill=(232, 220, 180))
        image.convert("RGB").save(BRAND / folder / f"{file}{suffix}.png")


def main() -> None:
    icon = Image.open(SOURCE).convert("RGBA")
    tank = tank_layer(icon)
    icon_stack(icon, tank, "small", (400, 240))
    icon_stack(icon, tank, "large", (1280, 768))
    top_shelf(icon, tank, "Top Shelf Image.imageset", "top_shelf", (1920, 720))
    top_shelf(
        icon, tank, "Top Shelf Image Wide.imageset", "top_shelf_wide", (2320, 720)
    )


if __name__ == "__main__":
    main()
