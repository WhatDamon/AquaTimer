#!/usr/bin/env python3
"""Export the approved Aqua volume slider artwork at AppKit display scales."""

import shutil
import xml.etree.ElementTree as ET

from generate_action_button_assets import NS, ROOT, XLINK, export, write_json


def main():
    renderer = shutil.which('rsvg-convert')
    if renderer is None:
        raise SystemExit('Regenerating slider artwork requires rsvg-convert (Homebrew: librsvg).')

    ET.register_namespace('', NS)
    ET.register_namespace('xlink', XLINK)
    root = ET.parse(ROOT / 'design/aqua-volume-slider.svg').getroot()
    definitions = {node.get('id'): node for node in root.find(f'{{{NS}}}defs') if node.get('id')}
    catalog = ROOT / 'AquaTimer/Resources/Sliders.xcassets'
    scratch = ROOT / '.build/slider-assets'
    catalog.mkdir(parents=True, exist_ok=True)
    scratch.mkdir(parents=True, exist_ok=True)
    write_json(catalog / 'Contents.json', {'info': {'author': 'xcode', 'version': 1}})

    for name, element in [('Track', 'track'), ('TrackDisabled', 'trackDisabled')]:
        export(renderer, definitions, scratch, 'AquaSlider' + name, 210, 8, '0 7.15 210 8',
               [definitions[element]], catalog=catalog)

    for name, element in [('Normal', 'thumbNormal'), ('Dragging', 'thumbDragging'),
                          ('Disabled', 'thumbDisabled')]:
        export(renderer, definitions, scratch, 'AquaSliderThumb' + name, 19, 19, '-2 -2 19 19',
               [definitions[element]], catalog=catalog)


if __name__ == '__main__':
    main()
