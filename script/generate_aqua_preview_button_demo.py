#!/usr/bin/env python3
"""Draw a standard Aqua push-button study; does not modify application assets."""

import base64
from pathlib import Path
import shutil
import subprocess
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parent.parent
NS = 'http://www.w3.org/2000/svg'
XLINK = 'http://www.w3.org/1999/xlink'
FONT = 'Lucida Grande, STXihei, STHeiti, sans-serif'
ET.register_namespace('', NS)
ET.register_namespace('xlink', XLINK)


def node(parent, tag, **attrs):
    return ET.SubElement(parent, f'{{{NS}}}{tag}',
                         {key.replace('_', '-'): str(value) for key, value in attrs.items()})


def text(parent, x, y, value, size=12, color='#282b2e', **attrs):
    result = node(parent, 'text', x=x, y=y, font_family=FONT, font_size=size,
                  font_weight='normal', fill=color, **attrs)
    result.text = value
    return result


def use(parent, name, **attrs):
    result = node(parent, 'use', **attrs)
    result.set(f'{{{XLINK}}}href', '#' + name)
    return result


def gradient(defs, name, stops):
    # Use the same vertical coordinate for the lower body and clipped reflection.
    result = node(defs, 'linearGradient', id=name, gradientUnits='userSpaceOnUse',
                  x1=0, y1=0, x2=0, y2=20)
    for offset, color in stops:
        node(result, 'stop', offset=offset, stop_color=color)


def definitions(defs):
    stripes = node(defs, 'pattern', id='settingsStripes', patternUnits='userSpaceOnUse', width=2, height=2)
    node(stripes, 'rect', width=2, height=2, fill='#efefef')
    node(stripes, 'rect', width=2, height=1, fill='#e9e9e9')
    clip = node(defs, 'clipPath', id='pushFaceClip')
    node(clip, 'rect', x='.4', y='.4', width='67.2', height='19.2', rx='9.6')

    gradient(defs, 'clearBody', [(0, '#bec1c4'), ('.435', '#d9dbe0'), ('.68', '#eff0f3'),
                               ('.84', '#fafafa'), ('.90', '#fefdfe'), (1, '#fefdfe')])
    gradient(defs, 'blueBody', [(0, '#657fa5'), ('.435', '#78b3dd'), ('.55', '#81c1e7'),
                              ('.78', '#a2d8ef'), ('.94', '#b7e4f0'), (1, '#b7e4f0')])
    gradient(defs, 'disabledBody', [(0, '#d9dadd'), ('.43', '#dfe0e2'), (1, '#f3f3f4')])
    # The HIG examples show a pale upper face and a short step in brightness
    # near mid-height, with the reflected light gathering again toward the base.
    gradient(defs, 'clearCrown', [(0, '#e5e6e8'), ('.075', '#fafafb'), ('.24', '#eff0f2'),
                                ('.34', '#ededf0'), ('.43', '#eeeff1')])
    gradient(defs, 'blueCrown', [(0, '#8da4c4'), ('.075', '#bdd2ee'), ('.24', '#abccea'),
                               ('.42', '#92c5e9')])
    gradient(defs, 'disabledCrown', [(0, '#e7e8e9'), ('.14', '#f3f3f4'), ('.48', '#ebeced')])
    # A single contour, darker at the top and bottom and softer at mid-height.
    gradient(defs, 'clearEdge', [(0, '#687078'), ('.23', '#9299a2'), ('.47', '#8d959f'),
                               ('.75', '#9aa0a6'), (1, '#6c737a')])
    gradient(defs, 'blueEdge', [(0, '#475477'), ('.38', '#628dbb'), ('.61', '#638fb9'),
                              ('.86', '#799aa9'), (1, '#677b80')])

    end_tint = node(defs, 'linearGradient', id='blueEndTint', x1='0%', y1='0%', x2='100%', y2='0%')
    for offset, opacity in [(0, '.42'), ('.085', '.12'), ('.2', '0'),
                            ('.8', '0'), ('.915', '.12'), (1, '.42')]:
        node(end_tint, 'stop', offset=offset, stop_color='#337bb5', stop_opacity=opacity)

    for name, spread in [('contactShadow', '.6'), ('keyboardGlow', '.65')]:
        blur = node(defs, 'filter', id=name, x='-15%', y='-40%', width='130%', height='190%',
                    color_interpolation_filters='sRGB')
        node(blur, 'feGaussianBlur', stdDeviation=spread)

    for state in ['normal', 'pressed', 'focus', 'disabled']:
        group = node(defs, 'g', id='AquaPreview' + state.title())
        button(group, state)


def button(group, state):
    disabled = state == 'disabled'
    pressed = state == 'pressed'
    material, outline, ink = {
        'normal': ('clear', 'url(#clearEdge)', '#202226'),
        'focus': ('clear', 'url(#clearEdge)', '#202226'),
        'pressed': ('blue', 'url(#blueEdge)', '#203247'),
        'disabled': ('disabled', '#b9bec3', '#91979d'),
    }[state]
    if state == 'focus':
        node(group, 'rect', x='-1.7', y='-1.7', width='71.4', height='23.4', rx='11.7', fill='none',
             stroke='#69acd5', stroke_width='2.6', opacity='.65', filter='url(#keyboardGlow)')
        node(group, 'rect', x='-1.3', y='-1.3', width='70.6', height='22.6', rx='11.3', fill='none',
             stroke='#83bcdf', stroke_width='1.4')
    node(group, 'rect', x='1.2', y='2.0' if pressed else '1.8', width='65.6', height='19.25', rx='9.625',
         fill='#39424a', opacity='.07' if disabled else '.31', filter='url(#contactShadow)')
    node(group, 'rect', x='.4', y='.4', width='67.2', height='19.2', rx='9.6',
         fill=f'url(#{material}Body)')
    # A shallow, nearly level reflection rolls into both rounded ends.
    node(group, 'path', d='M0 7.35 C3.5 8.35 7.5 8.52 14 8.55 '
         'C26 8.6 42 8.6 54 8.55 C60.5 8.52 64.5 8.35 68 7.35 V0 H0 Z',
         fill=f'url(#{material}Crown)', clip_path='url(#pushFaceClip)')
    if pressed:
        node(group, 'rect', x='.4', y='.4', width='67.2', height='19.2', rx='9.6',
             fill='url(#blueEndTint)')
    node(group, 'rect', x='.5', y='.5', width=67, height=19, rx='9.5',
         fill='none', stroke=outline, stroke_width=1)
    text(group, 34, '14.55' if pressed else '14.3', '试听', 13, ink, text_anchor='middle')


def stripe_panel(parent, x, y, width, height):
    node(parent, 'rect', x=x, y=y, width=width, height=height, fill='url(#settingsStripes)')


def embed_png(parent, path, x, y, width, height):
    encoded = base64.b64encode(path.read_bytes()).decode()
    result = node(parent, 'image', x=x, y=y, width=width, height=height)
    result.set(f'{{{XLINK}}}href', 'data:image/png;base64,' + encoded)


def main():
    root = ET.Element(f'{{{NS}}}svg', {'width': '840', 'height': '548', 'viewBox': '0 0 840 548',
                                    'role': 'img', 'aria-labelledby': 'title description'})
    node(root, 'title', id='title').text = 'AquaTimer「试听」按钮样稿'
    node(root, 'desc', id='description').text = (
        '68 × 20 pt 的普通 Aqua 按钮。上方反光中段平缓，两端随圆角收起，'
        '常态为灰白，按下为淡蓝。包含常态、按下、聚焦和禁用，'
        '以及声音设置局部和已接入的重置按钮素材。')
    defs = node(root, 'defs')
    definitions(defs)
    node(root, 'rect', width=840, height=548, fill='#fafafa')
    text(root, 32, 43, '「试听」按钮', 24)
    text(root, 808, 41, '68 × 20 pt', 12, '#646b72', text_anchor='end')

    stripe_panel(root, 32, 70, 776, 172)
    for x, state, title in [(90, 'normal', '常态 · 4×'), (478, 'pressed', '按下 · 4×')]:
        use(root, 'AquaPreview' + state.title(), transform=f'translate({x} 110) scale(4)')
        text(root, x + 136, 218, title, 12, '#515963', text_anchor='middle')

    stripe_panel(root, 32, 257, 776, 76)
    for x, state, label in [(95, 'normal', '常态 · 1×'), (289, 'pressed', '按下'),
                            (483, 'focus', '键盘聚焦'), (677, 'disabled', '禁用')]:
        use(root, 'AquaPreview' + state.title(), transform=f'translate({x} 275)')
        text(root, x + 34, 316, label, 11, '#515963', text_anchor='middle')

    text(root, 32, 368, '声音设置中的试听按钮 · 1×', 12, '#515963')
    stripe_panel(root, 32, 382, 520, 122)
    text(root, 62, 415, '声音：', 13)
    node(root, 'rect', x=162, y=402, width=13, height=13, rx=3, fill='#547db3')
    node(root, 'path', d='M165 408.5 l2.5 2.5 4.5 -5', fill='none', stroke='#ffffff',
         stroke_width='1.3', stroke_linecap='round', stroke_linejoin='round')
    text(root, 182, 414, '到时播放提示音', 13)
    node(root, 'rect', x=184, y=430, width=190, height=22, rx=4,
         fill='#e1e3e6', stroke='#c0c5cb', stroke_width='.6')
    text(root, 195, 445, '玻璃音（Glass）', 13, '#4f5660')
    node(root, 'path', d='M361 439 l3 3 3 -3', fill='none', stroke='#77818b', stroke_width='1.2')
    use(root, 'AquaPreviewNormal', transform='translate(382 431)')
    node(root, 'path', d='M184 477 H394', fill='none', stroke='#c6cbd0', stroke_width=3)
    node(root, 'circle', cx=331, cy=477, r=7, fill='#e0e4e8', stroke='#b4bcc4', stroke_width='.6')
    text(root, 412, 481, '70%', 12, '#515963')

    text(root, 584, 368, '主窗口「重置」按钮材质', 12, '#515963')
    reset = (ROOT / 'AquaTimer/Resources/ActionButtons.xcassets/AquaActionResetNormal.imageset'
             / 'AquaActionResetNormal@3x.png')
    node(root, 'rect', x=584, y=382, width=176, height=36, fill='#b0b0b0')
    embed_png(root, reset, 584, 382, 176, 36)

    output = ROOT / 'design/controls/aqua-preview-button.svg'
    ET.indent(root, space='  ')
    ET.ElementTree(root).write(output, encoding='utf-8', xml_declaration=True)
    renderer = shutil.which('rsvg-convert')
    if not renderer:
        raise SystemExit(f'SVG generated: {output}; rsvg-convert is required for the PNG preview.')
    subprocess.run([renderer, str(output), '-o', str(output.with_suffix('.png'))], check=True)
    print(output)
    print(output.with_suffix('.png'))


if __name__ == '__main__':
    main()
