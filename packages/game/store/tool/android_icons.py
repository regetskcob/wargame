"""Builds the Android launcher icons and the Play icon from the App Store icon.

    python3 store/tool/android_icons.py

Writes the legacy ic_launcher.png in every density, the adaptive icon
(terrain background and tank foreground PNGs) for Android 8 and later, and
the 512 x 512 icon for Google Play. Needs Pillow.
"""

from pathlib import Path

from PIL import Image

import app_icon

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "store" / "ios" / "icon" / "AppIcon-1024.png"
RES = ROOT / "android" / "app" / "src" / "main" / "res"
PLAY = ROOT / "store" / "android" / "metadata" / "android" / "de-DE" / "images"

# Legacy icon edge and the adaptive layer edge (108 dp) per density.
DENSITIES = {
    "mdpi": (48, 108),
    "hdpi": (72, 162),
    "xhdpi": (96, 216),
    "xxhdpi": (144, 324),
    "xxxhdpi": (192, 432),
}

# The tank reaches at most 430 px from the centre of the 1024 source (the
# barrel tip). Launchers may cut the adaptive layer down to a circle of
# 66 of its 108 dp, so the tank is scaled into that circle.
REACH = 430
SAFE = 33 / 108


def main():
    icon = Image.open(SOURCE).convert("RGB")
    terrain = app_icon.terrain()
    tank = app_icon.tank()

    for density, (legacy, layer) in DENSITIES.items():
        folder = RES / f"mipmap-{density}"
        folder.mkdir(parents=True, exist_ok=True)
        icon.resize((legacy, legacy), Image.LANCZOS).save(
            folder / "ic_launcher.png", optimize=True)

        # The terrain fills the whole background layer, the tank is
        # scaled into the safe circle on its own transparent layer.
        terrain.resize((layer, layer), Image.LANCZOS).save(
            folder / "ic_launcher_background.png", optimize=True)
        edge = round(icon.width * layer * SAFE / REACH)
        foreground = Image.new("RGBA", (layer, layer), (0, 0, 0, 0))
        offset = (layer - edge) // 2
        foreground.paste(tank.resize((edge, edge), Image.LANCZOS), (offset, offset))
        foreground.save(folder / "ic_launcher_foreground.png", optimize=True)

    anydpi = RES / "mipmap-anydpi-v26"
    anydpi.mkdir(parents=True, exist_ok=True)
    (anydpi / "ic_launcher.xml").write_text(
        '<?xml version="1.0" encoding="utf-8"?>\n'
        '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
        '    <background android:drawable="@mipmap/ic_launcher_background" />\n'
        '    <foreground android:drawable="@mipmap/ic_launcher_foreground" />\n'
        "</adaptive-icon>\n")
    (RES / "values" / "ic_launcher_background.xml").unlink(missing_ok=True)

    PLAY.mkdir(parents=True, exist_ok=True)
    icon.resize((512, 512), Image.LANCZOS).save(PLAY / "icon.png", optimize=True)
    print("icons written")


if __name__ == "__main__":
    main()
