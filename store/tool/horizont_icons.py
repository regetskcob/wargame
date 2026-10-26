"""Copies the app icons of the design system Horizont into every platform.

    python3 store/tool/horizont_icons.py [path/to/horizont]

Horizont draws the icon of each product and exports finished sets in
icons/export/panzergefecht/; the apps copy them and never draw or scale
icons themselves. The default checkout is ../horizont next to this
repository, at the tag the app follows (see its README, "App-Icons").

Writes the iOS app and the watch host app (one 1024 without alpha, Xcode
derives the other sizes), the watch app, the Mac icon set, the Android
launcher icons (adaptive with monochrome layer, plus the legacy icon), the
two Apple TV image stacks (back and front layer), the web icons, and the
store icons for the App Store and Google Play, and since Horizont 0.7.8
the wide pictures: the Apple TV top shelf and launch image, the Android TV
banner, the icons of the iMessage app and the launch screens of iOS,
Android and the web page. Needs Pillow, which cuts the export to the sizes
the asset catalogs and densities ask for.

Only the invitation bubbles of the iMessage app are still drawn here
(imessage.py): they are scenes of the game, not marks.
"""

import json
import shutil
import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
PRODUCT = "panzergefecht"
ANDROID_DENSITIES = {"mdpi": 1, "hdpi": 1.5, "xhdpi": 2, "xxhdpi": 3,
                     "xxxhdpi": 4}
# Width of the tank on the launch screens in points; LoadingView.tankWidth
# and the web page's #launch match it.
LAUNCH_TANK = 160
# Edge of the icon of the Android 12 splash screen, in dp.
SPLASH_ICON = 288


def fresh_set(folder, files, images):
    """Empties an asset catalog set of its pictures, copies files (name ->
    source) into it and writes its Contents.json."""
    folder.mkdir(parents=True, exist_ok=True)
    for old in folder.glob("*.png"):
        old.unlink()
    for name, source in files.items():
        shutil.copyfile(source, folder / name)
    contents = {"images": images, "info": {"author": "xcode", "version": 1}}
    (folder / "Contents.json").write_text(json.dumps(contents, indent=2) + "\n")


def single(folder, source, name, platform):
    fresh_set(folder, {name: source}, [{
        "filename": name, "idiom": "universal", "platform": platform,
        "size": "1024x1024"}])


def apple(export):
    ios = export / "ios" / "AppIcon.appiconset" / "AppIcon-1024.png"
    single(ROOT / "ios/Runner/Assets.xcassets/AppIcon.appiconset", ios,
           "AppIcon-1024.png", "ios")
    # The iOS app that carries the watch app on the phone.
    single(ROOT / "watchos/HostApp/Assets.xcassets/AppIcon.appiconset", ios,
           "AppIcon-1024.png", "ios")
    single(ROOT / "watchos/Runner/Assets.xcassets/AppIcon.appiconset",
           export / "watchos" / "AppIcon-1024.png", "AppIcon-1024.png",
           "watchos")
    store = ROOT / "store/ios/icon"
    store.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(ios, store / "AppIcon-1024.png")

    # macOS does not round icons itself; Horizont's set already sits on
    # Apple's plate with its shadow.
    iconset = export / "macos" / "AppIcon.iconset"
    files, images = {}, []
    for edge in (16, 32, 128, 256, 512):
        for scale in (1, 2):
            name = f"icon_{edge}x{edge}{'@2x' if scale == 2 else ''}.png"
            files[name] = iconset / name
            images.append({"filename": name, "idiom": "mac",
                           "scale": f"{scale}x", "size": f"{edge}x{edge}"})
    fresh_set(ROOT / "macos/Runner/Assets.xcassets/AppIcon.appiconset",
              files, images)


def tvos(export):
    """Two layers per stack, the ground behind and the tank in front; the
    App Store icon (Large) only needs 1x."""
    brand = ROOT / "tvos/Runner/Assets.xcassets/AppIcon.brandassets"
    for stack, name, sizes in (
            ("App Icon - Small", "small", {"1x": "400x240", "2x": "800x480"}),
            ("App Icon - Large", "large", {"1x": "1280x768"})):
        folder = brand / f"{stack}.imagestack"
        for old in folder.glob("*.imagestacklayer"):
            shutil.rmtree(old)
        for layer in ("Front", "Back"):
            files, images = {}, []
            for scale, size in sizes.items():
                file = f"{name}_{layer.lower()}{'' if scale == '1x' else '@2x'}.png"
                files[file] = export / "tvos" / f"{layer.lower()}-{size}.png"
                images.append({"filename": file, "idiom": "tv", "scale": scale})
            layer_dir = folder / f"{layer}.imagestacklayer"
            fresh_set(layer_dir / "Content.imageset", files, images)
            (layer_dir / "Contents.json").write_text(json.dumps(
                {"info": {"author": "xcode", "version": 1}}, indent=2) + "\n")
        (folder / "Contents.json").write_text(json.dumps({
            "info": {"author": "xcode", "version": 1},
            "layers": [{"filename": "Front.imagestacklayer"},
                       {"filename": "Back.imagestacklayer"}]}, indent=2) + "\n")


def android(export):
    res = ROOT / "android/app/src/main/res"
    for folder in (export / "android").glob("mipmap-*"):
        target = res / folder.name
        target.mkdir(parents=True, exist_ok=True)
        for file in folder.iterdir():
            shutil.copyfile(file, target / file.name)
    for lang in ("de-DE", "en-US"):
        images = ROOT / f"store/android/metadata/android/{lang}/images"
        images.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(export / "android/playstore-512.png", images / "icon.png")


def web(export):
    src, out = export / "web", ROOT / "web"
    # Horizont's favicon is the app icon since 0.8.9, the tank the player
    # installed; the PNG alone, since the SVG's blur and shadow do not hold
    # at tab size.
    (out / "favicon.svg").unlink(missing_ok=True)
    for source, target in (
            ("favicon-32.png", "favicon-32.png"),
            ("apple-touch-icon.png", "icons/apple-touch-icon.png"),
            ("icon-192.png", "icons/Icon-192.png"),
            ("icon-512.png", "icons/Icon-512.png"),
            ("icon-512-maskable.png", "icons/Icon-maskable-512.png")):
        shutil.copyfile(src / source, out / target)
    (out / "icons/Icon-maskable-192.png").unlink(missing_ok=True)


def resized(source, width, height=None):
    image = Image.open(source)
    height = height or round(image.height * width / image.width)
    return image.resize((width, height), Image.LANCZOS)


def wide(export):
    """The top shelf, the launch image and the banner of the televisions."""
    brand = ROOT / "tvos/Runner/Assets.xcassets/AppIcon.brandassets"
    for folder, name, sizes in (
            ("Top Shelf Image.imageset", "top_shelf", ("1920x720", "3840x1440")),
            ("Top Shelf Image Wide.imageset", "top_shelf_wide",
             ("2320x720", "4640x1440"))):
        for size, suffix in zip(sizes, ("", "@2x")):
            kind = "topshelf" if name == "top_shelf" else "topshelf-wide"
            shutil.copyfile(export / f"tvos/{kind}-{size}.png",
                            brand / folder / f"{name}{suffix}.png")
    launch = ROOT / "tvos/Runner/Assets.xcassets/LaunchImage.imageset"
    for width, suffix in ((360, ""), (720, "@2x")):
        shutil.copyfile(export / f"tvos/launch-tank-{width}.png",
                        launch / f"LaunchImage{suffix}.png")
    res = ROOT / "android/app/src/main/res"
    for folder, size in (("drawable-xhdpi", "320x180"),
                         ("drawable-xxxhdpi", "640x360")):
        shutil.copyfile(export / f"android/tv-banner-{size}.png",
                        res / folder / "tv_banner.png")


def imessage(export):
    """Square icons from the app icon, the 4:3 ones from Horizont's wide
    icon, at every size of the sticker icon set."""
    icons = ROOT / "ios/MessagesExtension/Assets.xcassets/iMessage App Icon.stickersiconset"
    square = export / "ios/AppIcon.appiconset/AppIcon-1024.png"
    four_three = export / "imessage/icon-1024x768.png"
    for entry in json.loads((icons / "Contents.json").read_text())["images"]:
        w, h = (float(v) for v in entry["size"].split("x"))
        scale = int(entry["scale"].rstrip("x"))
        size = (round(w * scale), round(h * scale))
        source = square if size[0] == size[1] else four_three
        resized(source, *size).convert("RGB").save(icons / entry["filename"],
                                                   optimize=True)


def launch(export):
    """The ground and the tank standing on it, for the native launch
    screens, the loading view and the web page, which all centre them."""
    ground = export / "launch/ground-1200.png"
    tank = export / "launch/tank-480.png"
    ios = ROOT / "ios/Runner/Assets.xcassets"
    for scale in (1, 2, 3):
        suffix = "" if scale == 1 else f"@{scale}x"
        resized(tank, LAUNCH_TANK * scale).save(
            ios / "LaunchImage.imageset" / f"LaunchImage{suffix}.png", optimize=True)
    shutil.copyfile(ground, ios / "LaunchBackground.imageset/LaunchBackground.png")
    images = ROOT / "assets/images"
    shutil.copyfile(tank, images / "launch_tank.png")
    Image.open(ground).convert("RGB").save(images / "launch_ground.jpg", quality=92)
    res = ROOT / "android/app/src/main/res"
    for density, factor in ANDROID_DENSITIES.items():
        small = resized(tank, round(LAUNCH_TANK * factor))
        small.save(res / f"drawable-{density}/launch_tank.png", optimize=True)
        edge = round(SPLASH_ICON * factor)
        icon = Image.new("RGBA", (edge, edge), (0, 0, 0, 0))
        icon.paste(small, ((edge - small.width) // 2, (edge - small.height) // 2), small)
        icon.save(res / f"drawable-{density}/launch_splash.png", optimize=True)


def main():
    horizont = Path(sys.argv[1]) if len(sys.argv) > 1 else (
        ROOT.parent / "horizont")
    export = horizont / "icons" / "export" / PRODUCT
    if not export.is_dir():
        sys.exit(f"no Horizont export at {export}")
    apple(export)
    tvos(export)
    android(export)
    web(export)
    wide(export)
    imessage(export)
    launch(export)
    print(f"icons copied from {export}")


if __name__ == "__main__":
    main()
