#!/usr/bin/env python3
"""Draw the optical layers of the AquaTimer action buttons."""

import copy
import shutil
import subprocess
import xml.etree.ElementTree as ET
from generate_input_field_demo import ROOT, NS, XLINK, node, text, material
from generate_button_demo import button, reflection, content


def main():
    ET.register_namespace('', NS)
    ET.register_namespace('xlink', XLINK)
    root = ET.Element(f'{{{NS}}}svg', {'width': '1120', 'height': '348', 'viewBox': '0 0 1120 348',
                                    'role': 'img', 'aria-labelledby': 'title description'})
    node(root, 'title', id='title').text = 'AquaTimer 按钮反光与层级'
    node(root, 'desc', id='description').text = 'AquaTimer 主窗口按钮的五层材质示意。'
    defs = node(root, 'defs')
    source = ET.parse(ROOT / 'design/controls/aqua-action-buttons.svg').getroot()
    for item in source.find(f'{{{NS}}}defs'):
        defs.append(copy.deepcopy(item))
    node(root, 'rect', width=1120, height=348, fill='#f1f1ef')
    text(root, 48, 49, 'AquaTimer 按钮反光与层级', 26)
    text(root, 48, 94, '单一亮面与连续曲线', 13, '#3e493d')
    text(root, 48, 120, '曲线上方明亮，下方先暗、再逐渐回亮。', 12, '#626960')
    text(root, 644, 94, '图形在反光之上', 13, '#3e493d')
    text(root, 644, 120, '深色图形带柔和投影，底部浅边沿圆角衔接。', 12, '#626960')
    text(root, 48, 156, '叠放顺序 · 左到右 · 1.6×', 12, '#626960')
    layers = [('凹槽与细轮廓', 'slot'), ('下半部的回亮底层', 'lower'),
              ('单一上半亮面', 'upper'), ('图形、图形投影与文字', 'content'), ('完整按钮', 'all')]
    for i, (label, layer) in enumerate(layers):
        _, panel = material(root, defs, 'studyLayer' + str(i), 48 + i * 208, 176, 192, 156)
        text(panel, 12, 28, str(i + 1) + '  ' + label, 11, '#4d564a')
        g = node(panel, 'g', transform='translate(19.2 65) scale(1.6)')
        if layer == 'slot':
            node(g, 'rect', x='.45', y='.45', width=95.1, height=27.1, rx=4.6,
                 fill='none', stroke='#686868', stroke_width='.85', filter='url(#buttonContactShadow)')
        elif layer == 'lower':
            node(g, 'rect', x='.9', y='.9', width=94.2, height=26.2, rx=4.05, fill='url(#buttonFace)')
        elif layer == 'upper':
            clipped = node(g, 'g', clip_path='url(#buttonFaceClip96)')
            reflection(clipped, 96)
        elif layer == 'content':
            content(g, 96, '开始', 'Play', 'normal')
        else:
            button(g, 0, 0)
        text(panel, 96, 139, ['承接机身', '上部会被亮面覆盖', '曲线边界由轮廓抗锯齿', '深色标记不被反光盖白', '素材层次合成'][i],
             10, '#646d5e', text_anchor='middle')
    ET.indent(root, space='  ')
    path = ROOT / 'design/controls/button-optics-study.svg'
    ET.ElementTree(root).write(path, encoding='utf-8', xml_declaration=True)
    renderer = shutil.which('rsvg-convert')
    if renderer is None:
        raise SystemExit('PNG preview requires rsvg-convert.')
    subprocess.run([renderer, '-w', '2240', '-h', '696', str(path), '-o',
                    str(ROOT / 'design/controls/button-optics-study.png')], check=True)
    print(f'Generated {path} and the 2x PNG preview.')


if __name__ == '__main__':
    main()
