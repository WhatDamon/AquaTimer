#!/usr/bin/env python3
"""Export LCD background, fixed-scale grain and glass separately from the approved SVG."""

import copy
import json
from pathlib import Path
import shutil
import subprocess
import xml.etree.ElementTree as ET


ROOT = Path(__file__).resolve().parent.parent
SVG = "http://www.w3.org/2000/svg"
XLINK = "http://www.w3.org/1999/xlink"
CATALOG = ROOT / "AquaTimer/Resources/LCD.xcassets"


def export(renderer, definitions, name, width, height, elements):
    document = ET.Element(f"{{{SVG}}}svg", {
        "width": str(width), "height": str(height), "viewBox": f"0 0 {width} {height}"
    })
    document.append(copy.deepcopy(definitions))
    for element in elements:
        document.append(copy.deepcopy(element))
    scratch = ROOT / ".build/lcd-assets"
    scratch.mkdir(parents=True, exist_ok=True)
    source = scratch / f"{name}.svg"
    ET.ElementTree(document).write(source, encoding="utf-8", xml_declaration=True)
    output = CATALOG / f"{name}.imageset"
    output.mkdir(parents=True, exist_ok=True)
    images = []
    for scale in (1, 2, 3):
        filename = f"{name}@{scale}x.png"
        subprocess.run([renderer, "-w", str(width * scale), "-h", str(height * scale),
                        str(source), "-o", str(output / filename)], check=True)
        images.append({"filename": filename, "idiom": "universal", "scale": f"{scale}x"})
    (output / "Contents.json").write_text(json.dumps({
        "images": images, "info": {"author": "xcode", "version": 1},
        "properties": {"template-rendering-intent": "original"}
    }, indent=2) + "\n")


def use(name):
    return ET.Element(f"{{{SVG}}}use", {f"{{{XLINK}}}href": f"#{name}"})


def main():
    renderer = shutil.which("rsvg-convert")
    if renderer is None:
        raise SystemExit("Regenerating LCD assets requires rsvg-convert (Homebrew: librsvg).")
    ET.register_namespace("", SVG)
    ET.register_namespace("xlink", XLINK)
    source = ET.parse(ROOT / "design/lcd-display.svg").getroot()
    definitions = source.find(f"{{{SVG}}}defs")
    if definitions is None:
        raise SystemExit("Missing LCD definitions.")
    background = copy.deepcopy(definitions)
    for parent in background.iter():
        for child in list(parent):
            if child.get("filter") == "url(#lcdGrain)":
                del child.attrib["filter"]
    CATALOG.mkdir(parents=True, exist_ok=True)
    (CATALOG / "Contents.json").write_text('{"info":{"author":"xcode","version":1}}\n')
    export(renderer, background, "LCDBackground", 432, 142, [use("lcdBackground")])
    export(renderer, definitions, "LCDGlass", 432, 142, [use("lcdOptics")])
    grain = [ET.Element(f"{{{SVG}}}rect", {
        "width": "64", "height": "64", "fill": "#808080", "filter": "url(#lcdGrain)"
    })]
    export(renderer, definitions, "LCDGrain", 64, 64, grain)
    print(f"Exported LCD background, grain and glass at 1x, 2x and 3x to {CATALOG}.")


if __name__ == "__main__":
    main()
