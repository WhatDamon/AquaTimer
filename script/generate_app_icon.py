#!/usr/bin/env python3
"""Generate aligned SVG/PNG icon elements for manual composition."""

import copy
import math
import json
from pathlib import Path
import random
import shutil
import subprocess
import xml.etree.ElementTree as ET
import zipfile

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / 'design/icon'
NS = 'http://www.w3.org/2000/svg'
ET.register_namespace('', NS)


def node(parent, tag, **attrs):
    return ET.SubElement(parent, f'{{{NS}}}{tag}', {
        k.replace('_', '-'): str(v) for k, v in attrs.items()
    })


def gradient(defs, name, stops, horizontal=False, radial=False):
    if radial:
        g = node(defs, 'radialGradient', id=name)
    else:
        g = node(defs, 'linearGradient', id=name, x1=0, y1=0,
                 x2=1 if horizontal else 0, y2=0 if horizontal else 1)
    for offset, color, *alpha in stops:
        node(g, 'stop', offset=offset, stop_color=color,
             stop_opacity=alpha[0] if alpha else 1)


def edge_gradient(defs, name, top, bottom, stops):
    """Light a closed contour in document coordinates, without visible path caps."""
    gradient(defs, name, stops)
    defs[-1].set('gradientUnits', 'userSpaceOnUse')
    defs[-1].set('x1', '0')
    defs[-1].set('x2', '0')
    defs[-1].set('y1', str(top))
    defs[-1].set('y2', str(bottom))


def contour(parent, x, y, width, height, radius, light, weight=1):
    return node(parent, 'rect', x=x, y=y, width=width, height=height,
                rx=radius, fill='none', stroke=f'url(#{light})', stroke_width=weight)


def document(defs, layers, path):
    root = ET.Element(f'{{{NS}}}svg', width='1024', height='1024', viewBox='0 0 1024 1024')
    node(root, 'title').text = 'AquaTimer — desktop electronic timer'
    root.append(copy.deepcopy(defs))
    for layer in layers:
        root.append(copy.deepcopy(layer))
    ET.indent(root)
    ET.ElementTree(root).write(path, encoding='utf-8', xml_declaration=True)


def package_assets():
    files = [OUT / name for name in ('DSEG-LICENSE.txt', 'AquaTimer.svg')]
    files += sorted(OUT.glob('AquaTimer-*.png'))
    elements = OUT / 'elements'
    files += sorted(path for path in elements.iterdir() if path.suffix in {'.svg', '.png'})
    files.append(elements / 'layers.json')
    with zipfile.ZipFile(OUT / 'AquaTimer-elements.zip', 'w', zipfile.ZIP_DEFLATED) as archive:
        for path in files:
            archive.write(path, Path('AquaTimer-elements') / path.relative_to(OUT))


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    defs = ET.Element(f'{{{NS}}}defs')
    gradient(defs, 'metal', [(0, '#a3a8ac'), (.18, '#c5c9cc'), (.48, '#e1e3e3'),
                             (.57, '#d6d9da'), (.82, '#b9bec0'), (1, '#969da1')], True)
    gradient(defs, 'metalVertical', [(0, '#ffffff', .58), (.035, '#ffffff', .08),
                                    (.65, '#ffffff', 0), (1, '#262c30', .26)])
    gradient(defs, 'chassis', [(0, '#abb2b7'), (.6, '#666f75'), (1, '#343c42')])
    gradient(defs, 'foot', [(0, '#20262b'), (.7, '#353c42'), (1, '#171c20')])
    gradient(defs, 'ground', [(0, '#131b23', .4), (.48, '#131b23', .15), (1, '#131b23', 0)], radial=True)
    gradient(defs, 'socket', [(0, '#4d5552'), (.4, '#767c6e'), (1, '#d2d8c3')])
    gradient(defs, 'lcd', [(0, '#929e7d'), (.18, '#abb797'), (.65, '#bfc8ab'), (1, '#b5c09e')])
    gradient(defs, 'lcdTopShade', [(0, '#222b1e', .32), (.17, '#222b1e', .06), (.4, '#222b1e', 0), (1, '#222b1e', 0)])
    gradient(defs, 'glass', [(0, '#ffffff', .18), (.6, '#ffffff', .04), (1, '#ffffff', 0)])
    gradient(defs, 'rim', [(0, '#727b80'), (.18, '#d8dddf'), (.53, '#e9ebeb'), (1, '#6f787e')])
    gradient(defs, 'dial', [(0, '#ffffff'), (.25, '#f5f6f1'), (.55, '#e6e8e2'), (1, '#b5bcb6')])
    gradient(defs, 'dimple', [(0, '#56615a'), (.38, '#869187'), (1, '#d2d8ce')])
    gradient(defs, 'blueFace', [(0, '#6b91ae'), (.52, '#87adca'), (.68, '#b5d5eb'), (1, '#d7ebf8')])
    gradient(defs, 'bluePane', [(0, '#b8d9f4'), (.55, '#e1f2fe'), (1, '#e9f7ff')])
    gradient(defs, 'silverFace', [(0, '#9da7ad'), (.58, '#ccd1d4'), (1, '#f1f3f2')])
    gradient(defs, 'silverPane', [(0, '#f7f8f8'), (1, '#eceff0')])
    gradient(defs, 'grainLight', [(0, '#ffffff', 0), (.15, '#ffffff', 1),
                                (.85, '#ffffff', 1), (1, '#ffffff', 0)], True)
    gradient(defs, 'grainDark', [(0, '#344047', 0), (.15, '#344047', 1),
                               (.85, '#344047', 1), (1, '#344047', 0)], True)
    edge_gradient(defs, 'bodyTopEdge', 121, 245,
                  [(0, '#ffffff', .88), (.18, '#ffffff', .54),
                   (.65, '#ffffff', .13), (1, '#ffffff', 0)])
    edge_gradient(defs, 'bodyLowerEdge', 713, 842,
                  [(0, '#39444b', 0), (.5, '#39444b', .07), (1, '#39444b', .48)])
    edge_gradient(defs, 'lcdLowerEdge', 397, 476,
                  [(0, '#f1f3da', 0), (.5, '#f1f3da', .08), (1, '#f1f3da', .64)])
    edge_gradient(defs, 'dialEdge', 550, 768,
                  [(0, '#ffffff', .9), (.42, '#ffffff', .34),
                   (.7, '#69766e', .12), (1, '#69766e', .38)])
    edge_gradient(defs, 'dialSpecular', 554, 694,
                  [(0, '#ffffff', .72), (.36, '#ffffff', .48),
                   (.7, '#ffffff', .12), (1, '#ffffff', 0)])
    gradient(defs, 'slotBevel', [(0, '#59666d'), (.52, '#758087'),
                               (.75, '#8a9599'), (1, '#eef0ed')])
    for name, (x, y, w, h, r) in {
        'bodyClip': (116, 120, 792, 724, 72),
        'screenClip': (185, 215, 654, 262, 16),
    }.items():
        clip = node(defs, 'clipPath', id=name)
        node(clip, 'rect', x=x, y=y, width=w, height=h, rx=r)
    source = ET.parse(ROOT / 'design/display/lcd-display.svg').getroot()
    for element in source.find(f'{{{NS}}}defs'):
        if element.get('id', '').startswith('lcdGlyph'):
            defs.append(copy.deepcopy(element))

    housing = ET.Element(f'{{{NS}}}g', id='housing')
    node(housing, 'ellipse', cx=512, cy=903, rx=388, ry=47, fill='url(#ground)')
    for x in (222, 672):
        node(housing, 'rect', x=x, y=815, width=130, height=76, rx=24, fill='url(#foot)')
        node(housing, 'path', d=f'M{x+14} 876 H{x+115}', stroke='#7e878c', stroke_width=2, opacity='.4')
    node(housing, 'rect', x=116, y=142, width=792, height=730, rx=74, fill='url(#chassis)', stroke='#3d464c', stroke_width=2)
    node(housing, 'rect', x=116, y=120, width=792, height=724, rx=72, fill='url(#metal)', stroke='#858e94', stroke_width=2)
    brushed = node(housing, 'g', clip_path='url(#bodyClip)')
    rng = random.Random(47)
    for i in range(1080):
        y = 120 + i * .68
        x = rng.uniform(110, 460)
        # A thin filled strip has a nonzero gradient box; gradients on horizontal
        # stroked paths have zero-height boxes and disappear in some SVG renderers.
        width, thickness = rng.uniform(300, 760), rng.uniform(.25, .65)
        node(brushed, 'rect', x=f'{x:.2f}', y=f'{y:.2f}', width=f'{width:.2f}',
             height=f'{thickness:.3f}', rx=f'{thickness/2:.3f}',
             fill='url(#grainLight)' if i % 2 else 'url(#grainDark)',
             opacity=rng.uniform(.025, .085))
    node(brushed, 'rect', x=116, y=120, width=792, height=724, fill='url(#metalVertical)')
    # Exact 2 pt offset from the face's circular 72 pt corners. Closed contours
    # let the light fade on the sides without butt ends or mismatched quadratics.
    contour(housing, 118, 122, 788, 720, 70, 'bodyTopEdge', 2)
    contour(housing, 118, 122, 788, 720, 70, 'bodyLowerEdge', 1.6)

    screen = ET.Element(f'{{{NS}}}g', id='screen')
    node(screen, 'rect', x=174, y=204, width=676, height=284, rx=27, fill='url(#socket)', stroke='#838a81', stroke_width=2)
    # An 11 pt inset of the 27 pt socket radius has a 16 pt radius.
    node(screen, 'rect', x=185, y=215, width=654, height=262, rx=16, fill='url(#lcd)')
    node(screen, 'rect', x=185, y=215, width=654, height=262, rx=16, fill='url(#lcdTopShade)')
    contour(screen, 186, 216, 652, 260, 15, 'lcdLowerEdge', 1.2)

    electrodes = ET.Element(f'{{{NS}}}g', id='electrodes')
    # Font outlines copied from the project's DSEG source; no installed fonts needed.
    for ghost, value in ((True, '88:88'), (False, '25:00')):
        g = node(electrodes, 'g', transform='translate(255 421.1) scale(2.65 -2.65)',
                 fill='#34402c', opacity='.05' if ghost else '.98')
        for char, x in zip(value, (0, 44, 89, 103, 147)):
            path = next(p for p in defs if p.get('id') == 'lcdGlyph' + ('Colon' if char == ':' else char))
            node(g, 'path', d=path.get('d'), transform=f'translate({x} 0)')
    for i in range(24):
        node(electrodes, 'rect', x=218+i*24.5, y=438, width=18, height=8,
             fill='#34402c', opacity='.32' if i < 6 else '.065')
    node(electrodes, 'path', d='M772 243 L772 264 L790 253.5 Z', fill='#34402c', opacity='.75')
    # The protective glass is above the active and inactive electrodes.
    glass_layer = ET.Element(f'{{{NS}}}g', id='lcd-glass')
    node(glass_layer, 'path', d='M205 217 H819 Q837 217 837 235 V323 L187 429 V235 Q187 217 205 217 Z',
         fill='url(#glass)', clip_path='url(#screenClip)')

    controls = ET.Element(f'{{{NS}}}g', id='controls')
    dial = node(controls, 'g', id='minute-dial')
    for i in range(60):
        a = math.radians(i*6)
        outer, inner = 145, 131 if i % 5 == 0 else 139
        x1, y1 = 343+math.sin(a)*inner, 659-math.cos(a)*inner
        x2, y2 = 343+math.sin(a)*outer, 659-math.cos(a)*outer
        node(dial, 'path', d=f'M{x1:.3f} {y1:.3f} L{x2:.3f} {y2:.3f}',
             stroke='#5f696b', stroke_width=2 if i % 5 == 0 else 1.2,
             stroke_linecap='round', opacity='.8' if i % 5 == 0 else '.5')
    node(dial, 'circle', cx=343, cy=662, r=119, fill='#556067', opacity='.3')
    node(dial, 'circle', cx=343, cy=659, r=118, fill='url(#rim)', stroke='#7b8589', stroke_width=2)
    node(dial, 'circle', cx=343, cy=659, r=109, fill='url(#dial)', stroke='url(#dialEdge)', stroke_width=1.5)
    node(dial, 'circle', cx=343, cy=659, r=105.5, fill='none',
         stroke='url(#dialSpecular)', stroke_width=2.4)
    node(dial, 'circle', cx=384, cy=730, r=16, fill='url(#dimple)', stroke='#eef1e7', stroke_width=2)
    button_layers = []
    for y, h, blue in ((566, 92, True), (697, 64, False)):
        button = node(controls, 'g', id='start-key' if blue else 'reset-key')
        button_layers.append(button)
        x, w, r = 557, 233, 22 if blue else 18
        key = 'start' if blue else 'reset'
        clip = node(defs, 'clipPath', id=key + 'FaceClip')
        node(clip, 'rect', x=x+.8, y=y+.8, width=w-1.6, height=h-1.6, rx=r-.8)
        edge_gradient(defs, key+'Border', y, y+h,
                      [(0, '#60727f', .95), (.5, '#73838d', .82), (1, '#5e6d76', .95)])
        edge_gradient(defs, key+'Contact', y, y+h+2.5,
                      [(0, '#36444d', 0), (.55, '#36444d', 0), (1, '#36444d', .27)])
        edge_gradient(defs, key+'LowerLight', y+h*.58, y+h-1.4,
                      [(0, '#ffffff', 0), (.55, '#ffffff', .12), (1, '#ffffff', .76)])
        node(button, 'rect', x=x, y=y+2.5, width=w, height=h, rx=r, fill=f'url(#{key}Contact)')
        node(button, 'rect', x=x, y=y, width=w, height=h, rx=r,
             fill='url(#blueFace)' if blue else 'url(#silverFace)')
        optics = node(button, 'g', clip_path=f'url(#{key}FaceClip)')
        # The pane extends past the face; a shared rounded clip supplies every
        # corner instead of a second approximate outline fighting the bezel.
        node(optics, 'path', d=f'M{x-2} {y+h*.82} C{x+38} {y+h*.47} {x+w*.47} {y+h*.58} {x+w*.58} {y+h*.52} Q{x+w-8} {y+h*.46} {x+w+2} {y+h*.16} V{y-2} H{x-2} Z',
             fill='url(#bluePane)' if blue else 'url(#silverPane)')
        contour(optics, x+1.4, y+1.4, w-2.8, h-2.8, r-1.4, key+'LowerLight', 1.2)
        contour(button, x, y, w, h, r, key+'Border', 1.6)
    node(button_layers[0], 'path', d='M656 589 L656 637 L698 613 Z', fill='#344f63')
    reset_glyph = node(button_layers[1], 'g', transform='translate(650 704) scale(3.4)', color='#55636b')
    node(reset_glyph, 'path', d='M2.8 4.1 C4.7 1.2 9.1 1.3 11.1 4.3 C13.3 7.7 10.9 12.4 7 12.4 C4.7 12.4 2.8 11 2.1 9',
         fill='none', stroke='currentColor', stroke_width='1.7', stroke_linecap='round')
    node(reset_glyph, 'path', d='M1.1 5.5 L1.65 .8 L5.65 4.65 Z', fill='currentColor')
    speaker = node(controls, 'g', id='speaker-slots')
    for y, w in ((793, 106), (805, 84), (817, 58)):
        node(speaker, 'rect', x=674-w/2, y=y, width=w, height=3.5, rx=1.75, fill='url(#slotBevel)')

    layers = [housing, screen, electrodes, controls, glass_layer]
    document(defs, layers, OUT / 'AquaTimer.svg')
    renderer = shutil.which('rsvg-convert')
    if not renderer:
        raise SystemExit('Preview generation requires rsvg-convert.')
    for size in (1024, 256, 64, 32):
        subprocess.run([renderer, '-w', str(size), '-h', str(size), str(OUT / 'AquaTimer.svg'),
                        '-o', str(OUT / f'AquaTimer-{size}.png')], check=True)
    # Full-canvas assets preserve alignment when manually stacking in a design tool.
    elements = OUT / 'elements'
    elements.mkdir(exist_ok=True)
    ground = ET.Element(f'{{{NS}}}g', id='ground-shadow')
    ground.append(copy.deepcopy(housing[0]))
    shell = copy.deepcopy(housing)
    shell.remove(shell[0])
    names = ('01-Ground-Shadow', '02-Housing-and-Feet', '03-LCD-Socket',
             '04-LCD-Segments', '05-Minute-Dial', '06-Start-Key',
             '07-Reset-Key', '08-Speaker-Slots', '09-LCD-Glass')
    values = (ground, shell, screen, electrodes, dial, *button_layers, speaker, glass_layer)
    for name, layer in zip(names, values):
        svg = elements / (name + '.svg')
        document(defs, [layer], svg)
        subprocess.run([renderer, '-w', '1024', '-h', '1024', str(svg),
                        '-o', str(svg.with_suffix('.png'))], check=True)
    (elements / 'layers.json').write_text(json.dumps({
        'canvas': [1024, 1024], 'origin': 'top-left',
        'stacking': 'bottom-to-top', 'layers': list(names),
        'placement': {'scale': 1, 'offset': [0, 0]},
    }, indent=2) + '\n')
    license_text = (ROOT / 'AquaTimer/Resources/Fonts/DSEG-LICENSE.txt').read_text(encoding='utf-8')
    (OUT / 'DSEG-LICENSE.txt').write_text(
        '\n'.join(line.rstrip() for line in license_text.splitlines()) + '\n', encoding='utf-8')
    package_assets()
    print('Generated and packaged nine aligned SVG/PNG elements, standalone artwork and previews.')


if __name__ == '__main__':
    main()
