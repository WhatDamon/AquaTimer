#!/usr/bin/env python3
"""Export the approved SVG button states as native-resolution AppKit image assets."""

import copy
import json
from pathlib import Path
import shutil
import subprocess
import xml.etree.ElementTree as ET


ROOT = Path(__file__).resolve().parent.parent
SVG_NS = "http://www.w3.org/2000/svg"
XLINK_NS = "http://www.w3.org/1999/xlink"
CATALOG = ROOT / "AquaTimer/Resources/WindowButtons.xcassets"
STATES = {
    "AquaWindowCloseNormal": "red",
    "AquaWindowCloseHover": "redHover",
    "AquaWindowClosePressed": "redPressed",
    "AquaWindowMinimizeNormal": "yellow",
    "AquaWindowMinimizeHover": "yellowHover",
    "AquaWindowMinimizePressed": "yellowPressed",
    "AquaWindowZoomNormal": "green",
    "AquaWindowZoomHover": "greenHover",
    "AquaWindowZoomPressed": "greenPressed",
    "AquaWindowZoomCollapseHover": "greenCollapseHover",
    "AquaWindowZoomCollapsePressed": "greenCollapsePressed",
    "AquaWindowInactive": "inactive",
}


def write_json(path, value):
    path.write_text(json.dumps(value, indent=2) + "\n")


def main():
    renderer = shutil.which("rsvg-convert")
    if renderer is None:
        raise SystemExit("Regenerating button assets requires rsvg-convert (Homebrew: librsvg).")

    ET.register_namespace("", SVG_NS)
    ET.register_namespace("xlink", XLINK_NS)
    source = ET.parse(ROOT / "design/window/aqua-window-buttons.svg").getroot()
    definitions = source.find(f"{{{SVG_NS}}}defs")
    if definitions is None:
        raise SystemExit("The button SVG does not contain definitions.")
    known_ids = {node.get("id") for node in definitions.iter()}
    if not set(STATES.values()) <= known_ids:
        raise SystemExit("The button SVG is missing an expected state.")

    scratch = ROOT / ".build/window-button-assets"
    scratch.mkdir(parents=True, exist_ok=True)
    CATALOG.mkdir(parents=True, exist_ok=True)
    write_json(CATALOG / "Contents.json", {"info": {"author": "xcode", "version": 1}})

    for name, state in STATES.items():
        # Export at 18 pt from the 16-unit padded artwork; the lens grows while the hit area stays 20 pt.
        document = ET.Element(f"{{{SVG_NS}}}svg", {
            "width": "18", "height": "18", "viewBox": "0 0 16 16"
        })
        document.append(copy.deepcopy(definitions))
        ET.SubElement(document, f"{{{SVG_NS}}}use", {
            f"{{{XLINK_NS}}}href": f"#{state}", "transform": "translate(1 1)"
        })
        svg_path = scratch / f"{name}.svg"
        ET.ElementTree(document).write(svg_path, encoding="utf-8", xml_declaration=True)

        image_set = CATALOG / f"{name}.imageset"
        image_set.mkdir(exist_ok=True)
        images = []
        for scale in (1, 2, 3):
            filename = f"{name}@{scale}x.png"
            subprocess.run([
                renderer, "--width", str(18 * scale), "--height", str(18 * scale),
                str(svg_path), "--output", str(image_set / filename)
            ], check=True)
            images.append({"filename": filename, "idiom": "universal", "scale": f"{scale}x"})
        write_json(image_set / "Contents.json", {
            "images": images,
            "info": {"author": "xcode", "version": 1},
            "properties": {"template-rendering-intent": "original"}
        })

    print(f"Exported {len(STATES)} button states at 1x, 2x and 3x to {CATALOG}.")


if __name__ == "__main__":
    main()
