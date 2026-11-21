#!/usr/bin/env python3
"""Export the Aqua titlebar toolbar switch from the approved SVG."""

import shutil
import xml.etree.ElementTree as ET

from generate_action_button_assets import NS, ROOT, XLINK, export, write_json


def main():
    renderer = shutil.which('rsvg-convert')
    if renderer is None:
        raise SystemExit('Regenerating toolbar switch artwork requires rsvg-convert (Homebrew: librsvg).')

    ET.register_namespace('', NS)
    ET.register_namespace('xlink', XLINK)
    root = ET.parse(ROOT / 'design/aqua-toolbar-toggle.svg').getroot()
    definitions = {node.get('id'): node for node in root.find(f'{{{NS}}}defs') if node.get('id')}
    catalog = ROOT / 'AquaTimer/Resources/SettingsToolbar.xcassets'
    scratch = ROOT / '.build/toolbar-toggle-assets'
    scratch.mkdir(parents=True, exist_ok=True)
    catalog.mkdir(parents=True, exist_ok=True)
    write_json(catalog / 'Contents.json', {'info': {'author': 'xcode', 'version': 1}})
    for state in ('Expanded', 'Pressed', 'Collapsed'):
        export(renderer, definitions, scratch, 'AquaToolbarToggle' + state, 20, 10, '0 0 20 10',
               [definitions['toggle' + state]], catalog=catalog)


if __name__ == '__main__':
    main()
