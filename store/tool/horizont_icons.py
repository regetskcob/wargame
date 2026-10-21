"""Copies the app icons of the design system Horizont into every platform.

    python3 store/tool/horizont_icons.py [path/to/design-system]

Horizont draws the icon of each product and exports finished sets in
icons/export/panzergefecht/; the apps copy them and never draw or scale
icons themselves. The default checkout is ../design-system next to this
repository, at the tag the app follows (see its README, "App-Icons").

Writes the iOS app and the watch host app (one 1024 without alpha, Xcode
derives the other sizes), the watch app, the Mac icon set, the Android
launcher icons (adaptive with monochrome layer, plus the legacy icon), the
two Apple TV image stacks (back and front layer), the web icons, and the
store icons for the App Store and Google Play. Standard library only.

Not in the Horizont export, so still drawn by the older scripts: the Apple
TV top shelf and the Android TV banner (tv_icons.py), the wide icons of the
iMessage app (imessage.py) and the launch screens (launch_screen.py).
"""

import json
import shutil
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PRODUCT = "panzergefecht"


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
    for source, target in (
            ("favicon.svg", "favicon.svg"),
            ("favicon-32.png", "favicon-32.png"),
            ("apple-touch-icon.png", "icons/apple-touch-icon.png"),
            ("icon-192.png", "icons/Icon-192.png"),
            ("icon-512.png", "icons/Icon-512.png"),
            ("icon-512-maskable.png", "icons/Icon-maskable-512.png")):
        shutil.copyfile(src / source, out / target)
    (out / "icons/Icon-maskable-192.png").unlink(missing_ok=True)


def main():
    horizont = Path(sys.argv[1]) if len(sys.argv) > 1 else (
        ROOT.parent / "design-system")
    export = horizont / "icons" / "export" / PRODUCT
    if not export.is_dir():
        sys.exit(f"no Horizont export at {export}")
    apple(export)
    tvos(export)
    android(export)
    web(export)
    print(f"icons copied from {export}")


if __name__ == "__main__":
    main()
