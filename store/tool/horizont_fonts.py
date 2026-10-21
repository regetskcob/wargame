"""Where the fonts of the design system Horizont lie, for the store tools.

The game takes its fonts from the Horizont package, which `flutter pub get`
fetches into the pub cache; its path stands in .dart_tool/package_config.json.
Run `flutter pub get` first.
"""

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def fonts_dir():
    config = ROOT / ".dart_tool" / "package_config.json"
    packages = json.loads(config.read_text())["packages"]
    horizont = next(p for p in packages if p["name"] == "horizont")
    uri = horizont["rootUri"]
    if uri.startswith("file://"):
        root = Path(uri[len("file://"):])
    else:
        root = (config.parent / uri).resolve()
    return root / "fonts"


# Headlines in Mona Sans Display Expanded, as in the game; the rest in Mona
# Sans.
HEADLINE = "MonaSansDisplayExpanded-Black.ttf"
TEXT = "MonaSans-Medium.ttf"
