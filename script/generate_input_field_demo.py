#!/usr/bin/env python3
"""Build the self-contained Aqua text-field design board; does not change app assets."""

import copy
from pathlib import Path
import shutil
import subprocess
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parent.parent
NS = 'http://www.w3.org/2000/svg'
XLINK = 'http://www.w3.org/1999/xlink'
ET.register_namespace('', NS)
ET.register_namespace('xlink', XLINK)
FONT = 'Lucida Grande, STXihei, STHeiti, sans-serif'


def node(parent, tag, **attrs):
    return ET.SubElement(parent, f'{{{NS}}}{tag}', {k.replace('_', '-'): str(v) for k, v in attrs.items()})


def text(parent, x, y, value, size=12, color='#343735', **attrs):
    n = node(parent, 'text', x=x, y=y, font_family=FONT, font_size=size, fill=color, **attrs)
    n.text = value
    return n


def use(parent, name, **attrs):
    n = node(parent, 'use', **attrs)
    n.set(f'{{{XLINK}}}href', '#' + name)
    return n


def gradient(defs, name, stops):
    g = node(defs, 'linearGradient', id=name, x1=0, y1=0, x2=0, y2=1,
             gradientUnits='objectBoundingBox')
    for offset, color, opacity in stops:
        node(g, 'stop', offset=offset, stop_color=color, stop_opacity=opacity)


def material(parent, defs, name, x, y, width, height, radius=3):
    clip = node(defs, 'clipPath', id=name + 'Clip')
    node(clip, 'rect', width=width, height=height, rx=radius)
    outer = node(parent, 'g', transform=f'translate({x} {y})')
    g = node(outer, 'g', clip_path=f'url(#{name}Clip)')
    light = node(g, 'g', transform=f'scale({width / 480} {height / 488})')
    node(light, 'rect', width=480, height=488, fill='url(#metalBase)')
    node(light, 'rect', width=480, height=488, fill='url(#broadReflection)')
    node(g, 'rect', width=width, height=height, fill='#808080', filter='url(#brushedGrain)',
         style='mix-blend-mode:overlay')
    node(g, 'rect', width=width, height=height, fill='url(#microScratches)', opacity='.6')
    return outer, g


def field(parent, value='25', state='normal', x=0, y=0):
    g = node(parent, 'g', transform=f'translate({x} {y})')
    if state in ('focus', 'selection', 'invalid'):
        use(g, 'inputFocusRing')
    use(g, 'inputDisabledBezel' if state == 'disabled' else 'inputBezel')
    if state == 'selection':
        node(g, 'rect', x=16.2, y=2.5, width=17.6, height=17, fill='#8ac2e1')
    text(g, 25, 15.6, value, size=13, color='#8a8a8a' if state == 'disabled' else '#171a1d',
         text_anchor='middle')
    if state == 'focus':
        node(g, 'path', d='M34 3.2 V18.5', fill='none', stroke='#13171b', stroke_width='.8')
    return g


def main():
    root = ET.Element(f'{{{NS}}}svg', {'width': '1120', 'height': '900', 'viewBox': '0 0 1120 900',
                                    'role': 'img', 'aria-labelledby': 'title description'})
    node(root, 'title', id='title').text = 'AquaTimer：Aqua 时间输入框设计样稿'
    node(root, 'desc', id='description').text = (
        '参照 Apple HIG 2005 第 260 至 262 页与图 14-43：矩形白底、内凹边缘、'
        '蓝色焦点与选择。画板展示放大细节、380 点窗口嵌入及常态、编辑、选择、禁用和无效输入。'
        '50×22 点宽高、10 点横向间距、居中数字与下方单位标签为 AquaTimer 的适配。')
    defs = node(root, 'defs')
    metal = ET.parse(ROOT / 'design/window/brushed-metal.svg').getroot().find(f'{{{NS}}}defs')
    for item in metal:
        defs.append(copy.deepcopy(item))
    dial = ET.parse(ROOT / 'design/controls/aqua-minute-dial.svg').getroot()
    for item in dial.find(f'{{{NS}}}defs'):
        if (item.get('id') or '').startswith(('dial', 'lcd')):
            defs.append(copy.deepcopy(item))

    gradient(defs, 'inputInnerTop', [(0, '#777e87', '.25'), ('.35', '#a9aeb5', '.12'),
                                    (1, '#ffffff', '0')])
    glow = node(defs, 'filter', id='inputFocusGlow', x='-15%', y='-30%', width='130%', height='160%',
                color_interpolation_filters='sRGB')
    node(glow, 'feGaussianBlur', stdDeviation='.65')
    ring = node(defs, 'g', id='inputFocusRing', fill='none')
    node(ring, 'rect', x=-1.25, y=-1.25, width=52.5, height=24.5, rx='1.2',
         stroke='#59a4cf', stroke_width='2.2', opacity='.65', filter='url(#inputFocusGlow)')
    node(ring, 'rect', x=-.9, y=-.9, width=51.8, height=23.8, rx='.7',
         stroke='#7bb7dc', stroke_width='1.6', opacity='.92')
    bezel = node(defs, 'g', id='inputBezel')
    node(bezel, 'rect', x='.5', y='.5', width=49, height=21, fill='#fff', stroke='#a1a6ad', stroke_width=1)
    node(bezel, 'rect', x=1, y=1, width=48, height=3.2, fill='url(#inputInnerTop)')
    node(bezel, 'path', d='M.5 21 V.5 H49.5', fill='none', stroke='#737c86', stroke_width='.65')
    node(bezel, 'path', d='M1 21.2 H49', fill='none', stroke='#f0f2f4', stroke_width='.6')
    node(bezel, 'path', d='M.4 22.35 H49.6', fill='none', stroke='#fff', stroke_opacity='.55', stroke_width='.65')
    disabled = node(defs, 'g', id='inputDisabledBezel')
    node(disabled, 'rect', x='.5', y='.5', width=49, height=21, fill='#e8e9ea', stroke='#afb2b5', stroke_width=1)
    node(disabled, 'rect', x=1, y=1, width=48, height=2, fill='url(#inputInnerTop)', opacity='.45')
    node(disabled, 'path', d='M.4 22.35 H49.6', fill='none', stroke='#fff', stroke_opacity='.4', stroke_width='.65')
    for name, state in [('inputNormal', 'normal'), ('inputEditing', 'focus'),
                        ('inputSelected', 'selection'), ('inputDisabled', 'disabled'), ('inputInvalid', 'invalid')]:
        group = node(defs, 'g', id=name)
        field(group, value='75' if state == 'invalid' else '25', state=state)

    node(root, 'rect', width=1120, height=900, fill='#f1f1ef')
    text(root, 48, 49, '时间输入框', 26)
    text(root, 48, 77, '矩形白底 · 内凹边缘 · Aqua 焦点与文本选择', 13, '#6b706d')
    text(root, 1072, 49, 'AquaTimer / 设计样稿', 11, '#858a85', text_anchor='end')
    text(root, 48, 112, '边缘与焦点 · 3×', 12, '#626960')
    _, hero = material(root, defs, 'inputHero', 48, 132, 496, 326)
    text(hero, 38, 35, '常态', 12, '#565e55')
    text(hero, 270, 35, '编辑中', 12, '#565e55')
    use(hero, 'inputNormal', transform='translate(38 66) scale(3)')
    use(hero, 'inputEditing', transform='translate(270 66) scale(3)')
    # Dimension marks are annotations, outside the control artwork.
    node(hero, 'path', d='M24 66 H18 V132 H24 M38 151 V157 H188 V151', fill='none',
         stroke='#596355', stroke_width='.6', opacity='.75')
    text(hero, 11, 104, '22', 9, '#596355', text_anchor='middle')
    text(hero, 113, 173, '50 pt', 10, '#596355', text_anchor='middle')
    text(hero, 38, 206, '白色内衬，上沿略深、下沿透亮。', 12, '#465044')
    text(hero, 38, 232, '蓝色光圈留在边缘之外，内容保持白底。', 12, '#465044')
    text(hero, 38, 282, 'Lucida Grande 13 pt  /  普通字重', 11, '#626b5e')
    text(root, 48, 493, '尺寸沿用 HIG 的标准高度；宽度适配两位数字。', 12, '#626960')
    text(root, 48, 519, '项目保留居中数值与下方单位标签，横向间距为 10 pt。', 12, '#626960')

    text(root, 644, 112, '放入当前窗口 · 1×', 12, '#626960')
    node(root, 'rect', x=644, y=132, width=380, height=390, rx=7, fill='#a7a7a7', filter='url(#dialWindowShadow)')
    _, window = material(root, defs, 'inputWindow', 644, 132, 380, 390, 7)
    node(window, 'rect', width=380, height=4, fill='url(#topReflection)')
    lower = node(window, 'g', transform='translate(0 -98)')
    node(lower, 'rect', y=479, width=380, height=9, fill='url(#bottomRoll)')
    for x, color in [(16, '#b96670'), (37.5, '#d6b657'), (59, '#89ab65')]:
        node(window, 'circle', cx=x, cy=14, r=6.6, fill=color, stroke='#7d8278', stroke_width='.5')
    text(window, 190, 20, 'AquaTimer', 13, '#fff', text_anchor='middle', opacity='.78')
    text(window, 190, 19, 'AquaTimer', 13, '#1f1f1f', text_anchor='middle')
    # Reuse the approved LCD group at the current window's actual dimensions.
    lcd_preview = next(g for g in dial.iter(f'{{{NS}}}g')
                       if g.get('transform') == 'translate(16 40)')
    window.append(copy.deepcopy(lcd_preview))
    use(window, 'dialNormal', transform='translate(20 184)')
    text(window, 74, 307, '调节分钟', 11, '#62685e', text_anchor='middle')
    text(window, 148, 222, '设置时长', 13, '#353a33')
    for x, value, unit, state in [(148, '0', '小时', 'normal'), (208, '25', '分钟', 'selection'),
                                  (268, '0', '秒', 'normal')]:
        field(window, value=value, state=state, x=x, y=237)
        text(window, x + 25, 274, unit, 11, '#62685e', text_anchor='middle')
    for x, width, label in [(16, 244, '开始'), (268, 96, '重置')]:
        node(window, 'rect', x=x, y=326, width=width, height=28, rx=5,
             fill='#b4b4b4', fill_opacity='.32', stroke='#777', stroke_opacity='.16', stroke_width='.5')
        text(window, x + width / 2, 345, label, 13, '#575c55' if x == 16 else '#888e85', text_anchor='middle')
    text(window, 190, 376, '关闭窗口后继续计时；退出应用停止。', 11, '#666d62', text_anchor='middle')

    text(root, 48, 575, '原尺寸状态 · 1×', 12, '#626960')
    states = [
        ('normal', '常态', '白底、灰色凹边', '25'),
        ('focus', '编辑', '焦点环与插入点', '25'),
        ('selection', '选择', '蓝色仅覆盖选中文字', '25'),
        ('disabled', '计时中锁定', '底色、边缘与文字减淡', '25'),
        ('invalid', '无效输入', '焦点仍为蓝色，提示在框外', '75'),
    ]
    for i, (state, title, description, value) in enumerate(states):
        _, panel = material(root, defs, 'inputState' + str(i), 48 + 208 * i, 598, 192, 160)
        text(panel, 16, 28, title, 12, '#4d564a')
        field(panel, value=value, state=state, x=71, y=51)
        text(panel, 96, 91, '分钟', 11, '#8a8e86' if state == 'disabled' else '#62685e', text_anchor='middle')
        if state == 'invalid':
            text(panel, 96, 112, '请输入 0–59', 11, '#963b32', text_anchor='middle')
        text(panel, 96, 141, description, 10, '#646d5e', text_anchor='middle')
    text(root, 48, 802, 'HIG 依据：Apple Human Interface Guidelines · 2005-12-06 · 第 260–262 页 · 图 14-43', 11, '#70776c')
    text(root, 48, 827, '项目适配：50 × 22 pt、居中数字、下方单位、禁用材质与字段外的范围提示。', 11, '#70776c')
    text(root, 48, 852, '本轮为 SVG 视觉样稿；其他组件沿用已有设计或以占位显示。', 11, '#858b80')
    ET.indent(root, space='  ')
    output = ROOT / 'design/controls/aqua-input-fields.svg'
    ET.ElementTree(root).write(output, encoding='utf-8', xml_declaration=True)
    renderer = shutil.which('rsvg-convert')
    if renderer is None:
        raise SystemExit(f'Saved {output}; install librsvg to render its PNG preview.')
    subprocess.run([renderer, '-w', '2240', '-h', '1800', str(output), '-o',
                    str(ROOT / 'design/controls/aqua-input-fields.png')], check=True)
    print(f'Generated {output} and its 2x PNG preview.')


if __name__ == '__main__':
    main()
