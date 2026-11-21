#!/usr/bin/env python3
"""Export the approved text-field chrome, with room for the complete focus glow."""

import copy
import json
from pathlib import Path
import shutil
import subprocess
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parent.parent
NS = 'http://www.w3.org/2000/svg'
XLINK = 'http://www.w3.org/1999/xlink'
CATALOG = ROOT / 'AquaTimer/Resources/InputFields.xcassets'
LAYERS = {
    'AquaInputNormal': 'inputBezel',
    'AquaInputDisabled': 'inputDisabledBezel',
    'AquaInputFocus': 'inputFocusRing',
}


def write_json(path, value):
    path.write_text(json.dumps(value, indent=2) + '\n')


def main():
    renderer = shutil.which('rsvg-convert')
    if renderer is None:
        raise SystemExit('Regenerating input assets requires rsvg-convert (Homebrew: librsvg).')
    ET.register_namespace('', NS)
    ET.register_namespace('xlink', XLINK)
    source = ET.parse(ROOT / 'design/aqua-input-fields.svg').getroot()
    all_definitions = source.find(f'{{{NS}}}defs')
    if all_definitions is None:
        raise SystemExit('Missing text-field SVG definitions.')
    # Only these definitions participate in the field chrome, without the demo's metal/LCD layers.
    definitions = ET.Element(f'{{{NS}}}defs')
    for item in all_definitions:
        if (item.get('id') or '').startswith('input'):
            definitions.append(copy.deepcopy(item))
    ids = {item.get('id') for item in definitions.iter()}
    if not set(LAYERS.values()) <= ids:
        raise SystemExit('Missing approved text-field layers.')
    scratch = ROOT / '.build/input-field-assets'
    scratch.mkdir(parents=True, exist_ok=True)
    CATALOG.mkdir(parents=True, exist_ok=True)
    write_json(CATALOG / 'Contents.json', {'info': {'author': 'xcode', 'version': 1}})
    for name, layer in LAYERS.items():
        document = ET.Element(f'{{{NS}}}svg', {
            'width': '58', 'height': '30', 'viewBox': '-4 -4 58 30',
        })
        document.append(copy.deepcopy(definitions))
        ET.SubElement(document, f'{{{NS}}}use', {f'{{{XLINK}}}href': '#' + layer})
        svg_path = scratch / (name + '.svg')
        ET.ElementTree(document).write(svg_path, encoding='utf-8', xml_declaration=True)
        output = CATALOG / (name + '.imageset')
        output.mkdir(exist_ok=True)
        images = []
        for scale in (1, 2, 3):
            filename = f'{name}@{scale}x.png'
            subprocess.run([renderer, '-w', str(58 * scale), '-h', str(30 * scale),
                            str(svg_path), '-o', str(output / filename)], check=True)
            images.append({'filename': filename, 'idiom': 'universal', 'scale': f'{scale}x'})
        write_json(output / 'Contents.json', {
            'images': images, 'info': {'author': 'xcode', 'version': 1},
            'properties': {'template-rendering-intent': 'original'},
        })
    print(f'Exported {len(LAYERS)} input layers at 1x, 2x and 3x to {CATALOG}.')


if __name__ == '__main__':
    main()
