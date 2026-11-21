#!/usr/bin/env python3
"""Render the user-reference glazed buttons without changing the app."""

import copy
import shutil
import subprocess
import xml.etree.ElementTree as ET
from generate_input_field_demo import ROOT, NS, XLINK, node, text, use, material

ET.register_namespace('', NS)
ET.register_namespace('xlink', XLINK)


def vertical_gradient(defs, name, stops):
    group = node(defs, 'linearGradient', id=name, x1='0%', y1='0%', x2='0%', y2='100%')
    for offset, color in stops:
        node(group, 'stop', offset=offset, stop_color=color)


def bezel(parent, width, state='normal', primary=False):
    group = node(parent, 'g')
    if state == 'keyboard':
        node(group, 'rect', x=-1.2, y=-1.2, width=width + 2.4, height=30.4, rx=6,
             fill='none', stroke='#69acd5', stroke_width='2', opacity='.7', filter='url(#buttonFocusGlow)')
        node(group, 'rect', x=-.9, y=-.9, width=width + 1.8, height=29.8, rx=5.7,
             fill='none', stroke='#83bcdf', stroke_width='1.5', opacity='.95')
    disabled = state == 'disabled'
    pressed = state == 'pressed'
    face = 'buttonFaceDisabled' if disabled else 'buttonFacePressed' if pressed else 'buttonPrimaryFace' if primary else 'buttonFace'
    shadow = 'buttonContactShadowDisabled' if disabled else 'buttonContactShadowPressed' if pressed else 'buttonContactShadow'
    node(group, 'rect', x='.45', y='.45', width=width - .9, height=27.1, rx=4.6,
         fill=f'url(#{face})', stroke='#a1a1a1' if disabled else '#686868', stroke_width='.85',
         filter=f'url(#{shadow})')
    face_layers = node(group, 'g', clip_path=f'url(#buttonFaceClip{width})')
    reflection(face_layers, width, state, primary=primary)
    # The source has a thin dark contour and a light seat below it, not a white inner outline.
    node(group, 'path', d=f'M.5 23 Q.5 28.05 5.1 28.05 H{width - 5.1} Q{width - .5} 28.05 {width - .5} 23',
         fill='none', stroke='#fff', stroke_width='.4',
         stroke_opacity='.24' if disabled else '.53', stroke_linecap='round')
    if state == 'hover':
        node(face_layers, 'rect', width=width, height=28, fill='#fff', opacity='.035')
    return group


def upper_pane_path(width):
    # Measured against native Finder PNGs: a single crest, with a low left end and a high right end.
    return (f'M1 24.6 C{width * .10:.3f} 13.7 {width * .29:.3f} 14.5 {width * .55:.3f} 14.5 '
            f'C{width * .81:.3f} 14.5 {width - 5:.3f} 11 {width - 1:.3f} 3 V1 H1 Z')


def reflection(parent, width, state='normal', primary=False):
    pane = 'buttonUpperDisabled' if state == 'disabled' else 'buttonUpperPressed' if state == 'pressed' else 'buttonPrimaryUpper' if primary else 'buttonUpper'
    node(parent, 'path', d=upper_pane_path(width), fill=f'url(#{pane})')


def content(parent, width, label, icon, state):
    group = node(parent, 'g', transform='translate(0 .3)' if state == 'pressed' else 'translate(0 0)')
    color = '#aaaaaa' if state == 'disabled' else '#414141'
    text_width = len(label) * 13
    total = 14 + 6 + text_width
    left = (width - total) / 2
    use(group, 'buttonIcon' + icon, transform=f'translate({left:.3f} 7)', color=color,
        filter='url(#buttonIconShadow)' if state != 'disabled' else 'none')
    text(group, left + 20, 18.5, label, 13, color)


def button(parent, x, y, width=96, label='开始', icon='Play', state='normal', identifier=None, primary=False):
    attrs = {'transform': f'translate({x} {y})'}
    if identifier:
        attrs['id'] = identifier
    group = node(parent, 'g', **attrs)
    bezel(group, width, state, primary=primary)
    content(group, width, label, icon, state)
    return group


def joined_buttons(parent, x, y):
    group = node(parent, 'g', transform=f'translate({x} {y})')
    bezel(group, 348)
    face = node(group, 'g', clip_path='url(#buttonFaceClip348)')
    active = node(face, 'g', clip_path='url(#buttonJoinedPressedClip)')
    node(active, 'rect', x=252, y=1, width=96, height=26, fill='url(#buttonFacePressed)')
    reflection(active, 348, 'pressed')
    node(group, 'path', d='M252 .9 V27.1', fill='none', stroke='#5a9dcd', stroke_width='.9')
    node(group, 'path', d='M251 .9 V27.1', fill='none', stroke='#fff', stroke_width='.6', stroke_opacity='.75')
    content(group, 252, '开始', 'Play', 'normal')
    right = node(group, 'g', transform='translate(252 0)')
    content(right, 96, '重置', 'Reset', 'pressed')
    return group


def main():
    root = ET.Element(f'{{{NS}}}svg', {
        'width': '1120', 'height': '1000', 'viewBox': '0 0 1120 1000',
        'role': 'img', 'aria-labelledby': 'title description',
    })
    node(root, 'title', id='title').text = 'AquaTimer：Finder 玻璃亮面按钮设计样稿'
    node(root, 'desc', id='description').text = (
        '根据原始尺寸 Finder 截图与用户参考，重建深灰凹边、单一曲线亮面与下半部回亮，按下时使用蓝色反馈。'
        '展示三倍细节、原尺寸窗口、常态、悬停、按下、禁用、键盘焦点，'
        '以及开始、暂停、继续、再次开始和重置图形。可见高度 28 点，按钮间距 12 点。')
    defs = node(root, 'defs')
    input_board = ET.parse(ROOT / 'design/controls/aqua-input-fields.svg').getroot()
    for item in input_board.find(f'{{{NS}}}defs'):
        defs.append(copy.deepcopy(item))

    vertical_gradient(defs, 'buttonFace', [
        ('0', '#bfbfbf'), ('.45', '#d1d1d1'), ('.55', '#dcdcdc'), ('1', '#f3f3f3'),
    ])
    vertical_gradient(defs, 'buttonFacePressed', [
        ('0', '#559bd0'), ('.45', '#66b7e2'), ('.70', '#7ccbed'), ('1', '#95ddf7'),
    ])
    vertical_gradient(defs, 'buttonPrimaryFace', [
        ('0', '#8daac4'), ('.45', '#a3bfd5'), ('.55', '#b6cfdf'), ('1', '#e0edf6'),
    ])
    vertical_gradient(defs, 'buttonFaceDisabled', [
        ('0', '#d5d5d5'), ('.5', '#e3e3e3'), ('1', '#f0f0f0'),
    ])
    # User-space Y keeps the optical ramp identical even where the crest's height changes.
    for name, top, bottom in [('buttonUpper', '#e8e8e8', '#fafafa'),
                               ('buttonPrimaryUpper', '#c2d9ef', '#e3f1fb'),
                               ('buttonUpperPressed', '#82ace1', '#95dff6'),
                               ('buttonUpperDisabled', '#e8e8e8', '#f4f4f4')]:
        pane = node(defs, 'linearGradient', id=name, gradientUnits='userSpaceOnUse', x1=0, y1=0, x2=0, y2=28)
        node(pane, 'stop', offset=0, stop_color=top)
        node(pane, 'stop', offset=1, stop_color=bottom)
    for width in (96, 136, 168, 348):
        clip = node(defs, 'clipPath', id=f'buttonFaceClip{width}')
        node(clip, 'rect', x=.9, y=.9, width=width - 1.8, height=26.2, rx=4.05)
    joined_clip = node(defs, 'clipPath', id='buttonJoinedPressedClip')
    node(joined_clip, 'rect', x=252, y=1, width=96, height=26)
    shadow = node(defs, 'filter', id='buttonContactShadow', x='-10%', y='-25%', width='120%', height='160%',
                  color_interpolation_filters='sRGB')
    node(shadow, 'feDropShadow', dx=0, dy='-.45', stdDeviation='.45', flood_color='#303030', flood_opacity='.22')
    for name, dy, blur, opacity in [('Pressed', '-.3', '.45', '.26'), ('Disabled', '-.25', '.45', '.10')]:
        shadow = node(defs, 'filter', id='buttonContactShadow' + name,
                      x='-10%', y='-25%', width='120%', height='160%', color_interpolation_filters='sRGB')
        node(shadow, 'feDropShadow', dx=0, dy=dy, stdDeviation=blur,
             flood_color='#303030', flood_opacity=opacity)
    focus = node(defs, 'filter', id='buttonFocusGlow', x='-12%', y='-35%', width='124%', height='170%',
                 color_interpolation_filters='sRGB')
    node(focus, 'feGaussianBlur', stdDeviation='.65')
    icon_shadow = node(defs, 'filter', id='buttonIconShadow', x='-25%', y='-20%', width='150%', height='160%',
                       color_interpolation_filters='sRGB')
    node(icon_shadow, 'feDropShadow', dx=0, dy='.7', stdDeviation='.55', flood_color='#000', flood_opacity='.23')
    play = node(defs, 'g', id='buttonIconPlay', fill='currentColor')
    node(play, 'path', d='M3.1 1.55 Q2.2 1.05 2.2 2.1 V11.9 Q2.2 12.95 3.1 12.45 L11.5 7.6 Q12.5 7 11.5 6.4 Z')
    pause = node(defs, 'g', id='buttonIconPause', fill='currentColor')
    node(pause, 'rect', x=2.1, y=1.5, width=3.6, height=11, rx='.3')
    node(pause, 'rect', x=8.3, y=1.5, width=3.6, height=11, rx='.3')
    reset = node(defs, 'g', id='buttonIconReset')
    node(reset, 'path', d='M2.8 4.1 C4.7 1.2 9.1 1.3 11.1 4.3 C13.3 7.7 10.9 12.4 7 12.4 C4.7 12.4 2.8 11 2.1 9',
         fill='none', stroke='currentColor', stroke_width='1.7', stroke_linecap='round')
    node(reset, 'path', d='M1.1 5.5 L1.65 .8 L5.65 4.65 Z', fill='currentColor')

    states = [('normal', '常态'), ('hover', '指针经过'), ('pressed', '按下'),
              ('disabled', '禁用'), ('keyboard', '键盘焦点')]
    for state, _ in states:
        group = node(defs, 'g', id='buttonBezel' + state.title(), data_body_width=168)
        bezel(group, 168, state)
        group = node(defs, 'g', id='buttonPrimaryBezel' + state.title(), data_body_width=168)
        bezel(group, 168, state, primary=True)
    for name, label, icon in [('Start', '开始', 'Play'), ('Pause', '暂停', 'Pause'),
                               ('Resume', '继续', 'Play'), ('Restart', '再次开始', 'Reset'),
                               ('Reset', '重置', 'Reset')]:
        button(defs, 0, 0, label=label, icon=icon, identifier='button' + name, primary=name != 'Reset')

    node(root, 'rect', width=1120, height=1000, fill='#f1f1ef')
    text(root, 48, 49, '操作按钮', 26)
    text(root, 48, 77, '单一曲线亮面 · 下半部回亮 · 深灰细边', 13, '#6b706d')
    text(root, 1072, 49, 'AquaTimer / 设计样稿', 11, '#858a85', text_anchor='end')
    text(root, 48, 112, '材质与按压 · 3×', 12, '#626960')
    _, hero = material(root, defs, 'buttonHero', 48, 132, 496, 338)
    text(hero, 44, 35, '主操作 · 浅 Aqua 蓝与连贯亮面', 12, '#535e53')
    g = node(hero, 'g', transform='translate(44 58) scale(3)')
    button(g, 0, 0, width=136, primary=True)
    text(hero, 44, 183, '按下 · 相同光学结构，蓝色底层', 12, '#535e53')
    g = node(hero, 'g', transform='translate(44 206) scale(3)')
    button(g, 0, 0, width=136, state='pressed', primary=True)
    text(root, 48, 503, '28 pt 可见高度 · 13 pt 常规文字 · 14 pt 图形', 12, '#626960')
    text(root, 48, 529, '两键等宽 168 pt；原生命中高度 44 pt，面盘高 28 pt。', 12, '#626960')
    text(root, 644, 112, '放入当前窗口 · 1×', 12, '#626960')
    node(root, 'rect', x=644, y=132, width=380, height=390, rx=7, fill='#999', filter='url(#dialWindowShadow)')
    # Reuse the approved context, replacing only its two placeholder action buttons.
    original = next(g for g in input_board.findall(f'{{{NS}}}g') if g.get('transform') == 'translate(644 132)')
    context = copy.deepcopy(next(g for g in original if g.tag == f'{{{NS}}}g'))
    for item in list(context):
        if item.tag == f'{{{NS}}}rect' and item.get('y') == '326':
            context.remove(item)
        elif item.tag == f'{{{NS}}}text' and item.get('y') == '345':
            context.remove(item)
    preview = node(root, 'g', transform='translate(644 132)')
    preview.append(context)
    button(context, 16, 326, width=168, primary=True)
    button(context, 196, 326, width=168, label='重置', icon='Reset', state='disabled')

    text(root, 48, 575, '原尺寸状态 · 1×', 12, '#626960')
    captions = ['上层亮面，下层由暗回亮', '表面略提亮', '蓝色渐变，保留同一曲线', '边缘与明暗差减弱', '独立蓝色焦点环']
    for i, ((state, title), caption) in enumerate(zip(states, captions)):
        _, panel = material(root, defs, 'buttonState' + str(i), 48 + 208 * i, 598, 192, 172)
        text(panel, 16, 28, title, 12, '#4d564a')
        button(panel, 12, 48, width=168, state=state, primary=True)
        button(panel, 12, 94, width=168, label='重置', icon='Reset', state=state)
        text(panel, 96, 150, caption, 10, '#646d5e', text_anchor='middle')

    text(root, 48, 817, '动作与图形 · 1×', 12, '#626960')
    actions = [('就绪', 'buttonStart'), ('计时中', 'buttonPause'),
               ('已暂停', 'buttonResume'), ('时间到', 'buttonRestart')]
    for i, (label, name) in enumerate(actions):
        x = 48 + i * 116
        text(root, x + 48, 851, label, 11, '#70776c', text_anchor='middle')
        use(root, name, transform=f'translate({x} 868)')
    text(root, 644, 851, '主次由样式区分；焦点环单独表达输入位置。', 11, '#70776c')
    text(root, 644, 878, 'Return 执行主动作，⌘R 重置。', 11, '#70776c')
    text(root, 48, 941, '依据：Guidebook 原尺寸 Finder PNG、Ars Technica Tiger 截图与用户参考；详见光学研究图。', 11, '#70776c')
    text(root, 48, 967, '应用已接入独立按钮；可见高度 28 pt，间距 12 pt，保留原生 NSButton 操作。', 11, '#858b80')
    ET.indent(root, space='  ')
    output = ROOT / 'design/controls/aqua-action-buttons.svg'
    ET.ElementTree(root).write(output, encoding='utf-8', xml_declaration=True)
    renderer = shutil.which('rsvg-convert')
    if renderer is None:
        raise SystemExit(f'Saved {output}; install librsvg to render the PNG preview.')
    subprocess.run([renderer, '-w', '2240', '-h', '2000', str(output), '-o',
                    str(ROOT / 'design/controls/aqua-action-buttons.png')], check=True)
    print(f'Generated {output} and its 2x PNG preview.')


if __name__ == '__main__':
    main()
