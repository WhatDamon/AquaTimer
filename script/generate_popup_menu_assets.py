#!/usr/bin/env python3
"""Export the approved Aqua pop-up faces and the shared selection check."""
import shutil
import xml.etree.ElementTree as ET

from generate_action_button_assets import NS, ROOT, XLINK, export, write_json


def main():
    renderer = shutil.which('rsvg-convert')
    if renderer is None:
        raise SystemExit('Regenerating pop-up artwork requires rsvg-convert (Homebrew: librsvg).')

    ET.register_namespace('', NS)
    ET.register_namespace('xlink', XLINK)
    catalog = ROOT / 'AquaTimer/Resources/PopupMenus.xcassets'
    scratch = ROOT / '.build/popup-menu-assets'
    catalog.mkdir(parents=True, exist_ok=True)
    scratch.mkdir(parents=True, exist_ok=True)
    write_json(catalog / 'Contents.json', {'info': {'author': 'xcode', 'version': 1}})

    popup = ET.parse(ROOT / 'design/controls/aqua-popup-menu.svg').getroot()
    definitions = {node.get('id'): node for node in popup.find(f'{{{NS}}}defs') if node.get('id')}
    for state in ('closed', 'disabled'):
        export(renderer, definitions, scratch, 'AquaPopup' + state.title(), 190, 24, '0 -2 190 24',
               [definitions[state]], catalog=catalog)

    checkbox = ET.parse(ROOT / 'design/controls/aqua-selection-controls.svg').getroot()
    tick = checkbox.find(f"{{{NS}}}defs/{{{NS}}}path[@id='tick']")
    for suffix, color in (('Dark', '#23262b'), ('Light', '#fff')):
        tick.set('fill', color)
        export(renderer, {}, scratch, 'AquaPopupCheck' + suffix, 11, 10, '2 -2 17 15.45', [tick], catalog=catalog)


if __name__ == '__main__':
    main()
