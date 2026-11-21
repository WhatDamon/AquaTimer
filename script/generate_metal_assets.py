#!/usr/bin/env python3
"""Separate approved metal lighting from grain so resizing never stretches the scratches."""

import copy
import json
from pathlib import Path
import shutil
import subprocess
import xml.etree.ElementTree as ET


ROOT = Path(__file__).resolve().parent.parent
SVG = "http://www.w3.org/2000/svg"
XLINK = "http://www.w3.org/1999/xlink"
CATALOG = ROOT / "AquaTimer/Resources/Metal.xcassets"


def export(renderer, definitions, name, width, height, elements):
    document = ET.Element(f"{{{SVG}}}svg", {
        "width": str(width), "height": str(height), "viewBox": f"0 0 {width} {height}"
    })
    document.append(copy.deepcopy(definitions))
    for element in elements:
        document.append(copy.deepcopy(element))
    scratch = ROOT / ".build/metal-assets"
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


def rect(**attributes):
    return ET.Element(f"{{{SVG}}}rect", {key: str(value) for key, value in attributes.items()})


def main():
    renderer = shutil.which("rsvg-convert")
    if renderer is None:
        raise SystemExit("Regenerating metal assets requires rsvg-convert (Homebrew: librsvg).")
    ET.register_namespace("", SVG)
    ET.register_namespace("xlink", XLINK)
    source = ET.parse(ROOT / "design/window/brushed-metal.svg").getroot()
    definitions = source.find(f"{{{SVG}}}defs")
    if definitions is None:
        raise SystemExit("Missing metal material definitions.")
    CATALOG.mkdir(parents=True, exist_ok=True)
    (CATALOG / "Contents.json").write_text('{"info":{"author":"xcode","version":1}}\n')

    lighting = [rect(width=480, height=488, fill=f"url(#{name})")
                for name in ("metalBase", "broadReflection")]
    export(renderer, definitions, "BrushedMetalLighting", 480, 488, lighting)

    # Keep the fixed point depths in sync with the canonical material gradients.
    gradients = {node.get("id"): node for node in definitions.findall(f"{{{SVG}}}linearGradient")}
    top_height = int(gradients["topReflection"].get("y2"))
    bottom_y = int(gradients["bottomRoll"].get("y1"))
    bottom_height = int(gradients["bottomRoll"].get("y2")) - bottom_y
    export(renderer, definitions, "BrushedMetalTopEdge", 480, top_height,
           [rect(width=480, height=top_height, fill="url(#topReflection)")])
    lower_edge = ET.Element(f"{{{SVG}}}g", {"transform": f"translate(0 -{bottom_y})"})
    lower_edge.append(rect(y=bottom_y, width=480, height=bottom_height, fill="url(#bottomRoll)"))
    export(renderer, definitions, "BrushedMetalBottomEdge", 480, bottom_height, [lower_edge])

    grain = [rect(width=1024, height=128, fill="#808080", filter="url(#brushedGrain)"),
             rect(width=1024, height=128, fill="url(#microScratches)")]
    export(renderer, definitions, "BrushedMetalGrain", 1024, 128, grain)
    print(f"Exported independent metal lighting and grain at 1x, 2x and 3x to {CATALOG}.")


if __name__ == "__main__":
    main()
