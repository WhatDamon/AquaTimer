#!/usr/bin/env python3
"""Export the approved action-button surfaces and foreground icons for AppKit."""

import copy
import json
from pathlib import Path
import re
import shutil
import subprocess
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parent.parent
NS = 'http://www.w3.org/2000/svg'
XLINK = 'http://www.w3.org/1999/xlink'
CATALOG = ROOT / 'AquaTimer/Resources/ActionButtons.xcassets'


def write_json(path, value):
    path.write_text(json.dumps(value, indent=2) + '\n')


def dependencies(elements, definitions):
    needed = set()

    def visit(element):
        for node in element.iter():
            for key, value in node.attrib.items():
                refs = re.findall(r'url\(#([^\)]+)\)', value)
                if key in ('href', f'{{{XLINK}}}href') and value.startswith('#'):
                    refs.append(value[1:])
                for ref in refs:
                    if ref in needed:
                        continue
                    if ref not in definitions:
                        raise SystemExit(f'Missing SVG definition: {ref}')
                    needed.add(ref)
                    visit(definitions[ref])

    for element in elements:
        visit(element)
    return needed


def export(renderer, definitions, scratch, name, width, height, viewbox, elements, *, catalog=CATALOG):
    document = ET.Element(f'{{{NS}}}svg', {
        'width': str(width), 'height': str(height), 'viewBox': viewbox,
    })
    defs = ET.SubElement(document, f'{{{NS}}}defs')
    for ref in sorted(dependencies(elements, definitions)):
        defs.append(copy.deepcopy(definitions[ref]))
    for element in elements:
        document.append(copy.deepcopy(element))
    source = scratch / (name + '.svg')
    ET.ElementTree(document).write(source, encoding='utf-8', xml_declaration=True)
    output = catalog / (name + '.imageset')
    output.mkdir(parents=True, exist_ok=True)
    images = []
    for scale in (1, 2, 3):
        filename = f'{name}@{scale}x.png'
        subprocess.run([renderer, '-w', str(width * scale), '-h', str(height * scale),
                        str(source), '-o', str(output / filename)], check=True)
        images.append({'filename': filename, 'idiom': 'universal', 'scale': f'{scale}x'})
    write_json(output / 'Contents.json', {
        'images': images, 'info': {'author': 'xcode', 'version': 1},
        'properties': {'template-rendering-intent': 'original'},
    })


def main():
    renderer = shutil.which('rsvg-convert')
    if renderer is None:
        raise SystemExit('Regenerating action buttons requires rsvg-convert (Homebrew: librsvg).')
    ET.register_namespace('', NS)
    ET.register_namespace('xlink', XLINK)
    root = ET.parse(ROOT / 'design/aqua-action-buttons.svg').getroot()
    source_defs = root.find(f'{{{NS}}}defs')
    if source_defs is None:
        raise SystemExit('Missing action-button SVG definitions.')
    definitions = {node.get('id'): node for node in source_defs if node.get('id')}
    scratch = ROOT / '.build/action-button-assets'
    scratch.mkdir(parents=True, exist_ok=True)
    CATALOG.mkdir(parents=True, exist_ok=True)
    write_json(CATALOG / 'Contents.json', {'info': {'author': 'xcode', 'version': 1}})
    count = 0
    for role, prefix in [('Primary', 'buttonPrimaryBezel'), ('Reset', 'buttonBezel')]:
        body_width = int(definitions[prefix + 'Normal'].get('data-body-width'))
        for state in ('Normal', 'Hover', 'Pressed', 'Disabled', 'Focus'):
            if state == 'Focus':
                # The first two shapes are the independent ring, before the normal bezel.
                group = definitions[prefix + 'Keyboard'].find(f'{{{NS}}}g')
                elements = list(group)[:2]
                if len(elements) != 2 or any(element.get('fill') != 'none' for element in elements):
                    raise SystemExit('The approved keyboard-focus layer changed structure.')
            else:
                elements = [definitions[prefix + state]]
            export(renderer, definitions, scratch, f'AquaAction{role}{state}', body_width + 8, 36,
                   f'-4 -4 {body_width + 8} 36', elements)
            count += 1
    for icon in ('Play', 'Pause', 'Reset'):
        for disabled in (False, True):
            element = ET.Element(f'{{{NS}}}use', {
                f'{{{XLINK}}}href': '#buttonIcon' + icon,
                'color': '#aaaaaa' if disabled else '#414141',
            })
            if not disabled:
                element.set('filter', 'url(#buttonIconShadow)')
            name = f'AquaActionIcon{icon}' + ('Disabled' if disabled else '')
            export(renderer, definitions, scratch, name, 18, 18, '-2 -2 18 18', [element])
            count += 1
    print(f'Exported {count} action-button layers at 1x, 2x and 3x to {CATALOG}.')


if __name__ == '__main__':
    main()
