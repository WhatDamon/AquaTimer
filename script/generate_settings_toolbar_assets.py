#!/usr/bin/env python3
"""Export the settings toolbar speaker from its SVG at AppKit display scales."""

import shutil
import subprocess

from generate_action_button_assets import ROOT, write_json


def main():
    renderer = shutil.which('rsvg-convert')
    if renderer is None:
        raise SystemExit('Regenerating settings toolbar artwork requires rsvg-convert (Homebrew: librsvg).')

    source = ROOT / 'design/settings/aqua-settings-speaker.svg'
    catalog = ROOT / 'AquaTimer/Resources/SettingsToolbar.xcassets'
    imageset = catalog / 'AquaSettingsSpeaker.imageset'
    imageset.mkdir(parents=True, exist_ok=True)
    info = {'author': 'xcode', 'version': 1}
    write_json(catalog / 'Contents.json', {'info': info})

    images = []
    for scale in (1, 2, 3):
        filename = f'AquaSettingsSpeaker@{scale}x.png'
        subprocess.run([renderer, '-z', str(scale), str(source), '-o', str(imageset / filename)], check=True)
        images.append({'filename': filename, 'idiom': 'universal', 'scale': f'{scale}x'})
    write_json(imageset / 'Contents.json', {
        'images': images, 'info': info,
        'properties': {'template-rendering-intent': 'original'},
    })


if __name__ == '__main__':
    main()
