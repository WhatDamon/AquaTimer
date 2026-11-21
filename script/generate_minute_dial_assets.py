#!/usr/bin/env python3
"""Export fixed-lighting dial layers from the approved SVG for AppKit."""

import copy
import json
from pathlib import Path
import shutil
import subprocess
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parent.parent
SVG_NS = "http://www.w3.org/2000/svg"
XLINK_NS = "http://www.w3.org/1999/xlink"
CATALOG = ROOT / "AquaTimer/Resources/MinuteDial.xcassets"
LAYERS = {
    "AquaMinuteDialScale": "dialScale",
    "AquaMinuteDialNormal": "dialBodyNormal",
    "AquaMinuteDialTracking": "dialBodyTracking",
    "AquaMinuteDialDisabled": "dialBodyDisabled",
    "AquaMinuteDialPointer": "dialPointer",
}


def write_json(path, value):
    path.write_text(json.dumps(value, indent=2) + "\n")


def main():
    renderer = shutil.which("rsvg-convert")
    if renderer is None:
        raise SystemExit("Regenerating dial assets requires rsvg-convert (Homebrew: librsvg).")
    ET.register_namespace("", SVG_NS)
    ET.register_namespace("xlink", XLINK_NS)
    source = ET.parse(ROOT / "design/aqua-minute-dial.svg").getroot()
    definitions = source.find(f"{{{SVG_NS}}}defs")
    if definitions is None:
        raise SystemExit("The dial SVG does not contain definitions.")
    known_ids = {node.get("id") for node in definitions.iter()}
    if not set(LAYERS.values()) <= known_ids:
        raise SystemExit("The dial SVG is missing an expected layer.")

    scratch = ROOT / ".build/minute-dial-assets"
    scratch.mkdir(parents=True, exist_ok=True)
    CATALOG.mkdir(parents=True, exist_ok=True)
    write_json(CATALOG / "Contents.json", {"info": {"author": "xcode", "version": 1}})
    for name, layer in LAYERS.items():
        pointer = layer == "dialPointer"
        width, height = (14, 14) if pointer else (116, 108) if layer == "dialScale" else (108, 108)
        viewbox = "-7 -7 14 14" if pointer else "-4 0 116 108" if layer == "dialScale" else "0 0 108 108"
        document = ET.Element(f"{{{SVG_NS}}}svg", {
            "width": str(width), "height": str(height), "viewBox": viewbox,
        })
        document.append(copy.deepcopy(definitions))
        ET.SubElement(document, f"{{{SVG_NS}}}use", {f"{{{XLINK_NS}}}href": f"#{layer}"})
        svg_path = scratch / f"{name}.svg"
        ET.ElementTree(document).write(svg_path, encoding="utf-8", xml_declaration=True)
        image_set = CATALOG / f"{name}.imageset"
        image_set.mkdir(exist_ok=True)
        images = []
        for scale in (1, 2, 3):
            filename = f"{name}@{scale}x.png"
            subprocess.run([
                renderer, "--width", str(width * scale), "--height", str(height * scale),
                str(svg_path), "--output", str(image_set / filename),
            ], check=True)
            images.append({"filename": filename, "idiom": "universal", "scale": f"{scale}x"})
        write_json(image_set / "Contents.json", {
            "images": images, "info": {"author": "xcode", "version": 1},
            "properties": {"template-rendering-intent": "original"},
        })
    print(f"Exported {len(LAYERS)} dial layers at 1x, 2x and 3x to {CATALOG}.")


if __name__ == "__main__":
    main()
