"""Draws the launch screen of the phone apps and the web page.

    python3 store/tool/launch_screen.py

The tank of the app icon on a calm version of its ground: soft patches,
without the dirt lane. The native launch screen, the loading
view that follows it (lib/src/ui/loading_view.dart) and the web page before
Flutter starts all show these two images in the same place, so the change
from one to the next is not seen. Writes the iOS image sets, the Android
drawables and assets/images; web/index.html shows the latter from the built
assets, so the loading view finds them in the browser cache. Needs Pillow.

Android draws no picture behind its launch screen, only a colour
(@color/launch_ground, the middle of the ground). Since Android 12 the
system splash shows an icon of 288 dp cut to a circle of 192 dp; the tank
at 160 dp fits inside it.
"""

import json
import random
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

import app_icon

ROOT = Path(__file__).resolve().parents[2]
IOS = ROOT / "ios" / "Runner" / "Assets.xcassets"
FLUTTER = ROOT / "assets" / "images"
ANDROID = ROOT / "android" / "app" / "src" / "main" / "res"
ANDROID_DENSITIES = {"mdpi": 1, "hdpi": 1.5, "xhdpi": 2, "xxhdpi": 3,
                     "xxxhdpi": 4}
# Edge of the icon of the Android 12 splash screen, in dp.
SPLASH_ICON = 288

# The tank with its shadow on the 1024 layer of app_icon.tank().
TANK_BOX = (128, 280, 912, 772)
# Width in points on the screen; LoadingView.tankWidth must match.
TANK_WIDTH = 160

# Edge of the square ground. Every screen shows it scaled to cover, the
# texture is soft enough to be stretched.
GROUND_SIZE = 1200


def ground(seed=11):
    s = GROUND_SIZE
    rnd = random.Random(seed)
    img = Image.new("RGB", (s, s), app_icon.GROUND)
    d = ImageDraw.Draw(img)
    for _ in range(24):
        x, y = rnd.uniform(-100, s + 100), rnd.uniform(-100, s + 100)
        r = rnd.uniform(110, 260)
        d.ellipse((x - r, y - r * 0.8, x + r, y + r * 0.8),
                  fill=rnd.choice(app_icon.PATCHES))
    img = img.filter(ImageFilter.GaussianBlur(45))

    # Light from the top left, a little shade bottom right, as on the icon.
    light = Image.new("L", (s, s), 0)
    ImageDraw.Draw(light).ellipse((-400, -400, 700, 700), fill=50)
    light = light.filter(ImageFilter.GaussianBlur(220))
    img = Image.composite(Image.new("RGB", (s, s), (0xF4, 0xEC, 0xC8)), img,
                          light)
    shade = Image.new("L", (s, s), 0)
    ImageDraw.Draw(shade).ellipse((700, 700, 1700, 1700), fill=60)
    shade = shade.filter(ImageFilter.GaussianBlur(220))
    # No grain: stretched to a phone screen it showed as noise.
    return Image.composite(Image.new("RGB", (s, s), (0, 0, 0)), img, shade)


def save_set(folder, name, image, base_width, scales=(1, 2, 3)):
    folder.mkdir(exist_ok=True)
    images = []
    for scale in scales:
        suffix = "" if scale == 1 else f"@{scale}x"
        width = base_width * scale
        height = round(image.height * width / image.width)
        file = f"{name}{suffix}.png"
        image.resize((width, height), Image.LANCZOS).save(folder / file,
                                                          optimize=True)
        images.append({"idiom": "universal", "filename": file,
                       "scale": f"{scale}x"})
    (folder / "Contents.json").write_text(json.dumps(
        {"images": images, "info": {"version": 1, "author": "xcode"}},
        indent=2) + "\n")


def main():
    tank = app_icon.tank().crop(TANK_BOX)
    back = ground()

    save_set(IOS / "LaunchImage.imageset", "LaunchImage", tank, TANK_WIDTH)
    # One size: the launch screen stretches it to cover anyway.
    save_set(IOS / "LaunchBackground.imageset", "LaunchBackground", back,
             GROUND_SIZE, scales=(1,))

    FLUTTER.mkdir(parents=True, exist_ok=True)
    tank_3x = tank.resize((TANK_WIDTH * 3,
                           round(tank.height * TANK_WIDTH * 3 / tank.width)),
                          Image.LANCZOS)
    tank_3x.save(FLUTTER / "launch_tank.png", optimize=True)
    back.save(FLUTTER / "launch_ground.jpg", quality=92)
    for density, factor in ANDROID_DENSITIES.items():
        folder = ANDROID / f"drawable-{density}"
        folder.mkdir(exist_ok=True)
        width = round(TANK_WIDTH * factor)
        small = tank.resize((width, round(tank.height * width / tank.width)),
                            Image.LANCZOS)
        small.save(folder / "launch_tank.png", optimize=True)
        edge = round(SPLASH_ICON * factor)
        icon = Image.new("RGBA", (edge, edge), (0, 0, 0, 0))
        icon.paste(small, ((edge - small.width) // 2,
                           (edge - small.height) // 2), small)
        icon.save(folder / "launch_splash.png", optimize=True)
    print("launch screen written")


if __name__ == "__main__":
    main()
