#!/usr/bin/env python3
"""Export the approved selection glyphs with room for the overshooting check mark."""
import shutil
import xml.etree.ElementTree as ET

from generate_action_button_assets import NS, ROOT, XLINK, export, write_json


def main():
    renderer = shutil.which('rsvg-convert')
    if renderer is None:
        raise SystemExit('Regenerating selection controls requires rsvg-convert (Homebrew: librsvg).')

    ET.register_namespace('', NS)
    ET.register_namespace('xlink', XLINK)
    document = ET.parse(ROOT / 'design/controls/aqua-selection-controls.svg').getroot()
    definitions = {node.get('id'): node for node in document.find(f'{{{NS}}}defs') if node.get('id')}
    scratch = ROOT / '.build/selection-control-assets'
    scratch.mkdir(parents=True, exist_ok=True)
    catalog = ROOT / 'AquaTimer/Resources/SelectionControls.xcassets'
    catalog.mkdir(parents=True, exist_ok=True)
    write_json(catalog / 'Contents.json', {'info': {'author': 'xcode', 'version': 1}})
    for prefix, name in [('radio', 'AquaSelectionRadio'), ('check', 'AquaSelectionCheck')]:
        for state in ('Off', 'On', 'Pressed', 'DisabledOff', 'DisabledOn'):
            # The 18 pt design lives in a 22 pt canvas. The extra transparent
            # space keeps the check tip and drop shadow clear of its edges.
            export(renderer, definitions, scratch, name + state, 22, 22, '-2 -2 22 22',
                   [definitions[prefix + state]], catalog=catalog)
    print(f'Exported selection controls at 1x, 2x, and 3x to {catalog}.')


if __name__ == '__main__':
    main()
