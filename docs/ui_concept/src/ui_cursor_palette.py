# -*- coding: utf-8 -*-
"""docs/ui_concept/ui_cursor_palette.png 生成脚本（PIL，非 HTML/Chrome 流程）。

光标调色规范对照图：原版 + A/B/C 双色重着色 × 浅色底（大厅亮蓝 UI）/
深色底（战场）。图标来自同目录 kenney_cursor_pack/ 6 图子集（Kenney Cursor
Pack 1.1，CC0），标签字体优先 Windows msyh.ttc，缺失回退 fonts/ZCOOL-Kuaile.ttf
（字形略有差异）。输出 1280x780，与入库 PNG 同源。
"""
from PIL import Image, ImageDraw, ImageFont
import os

_HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(_HERE, "kenney_cursor_pack", "PNG", "Outline", "Default")
OUT = os.path.join(_HERE, "..", "ui_cursor_palette.png")

W, H = 1280, 780
LIGHT_BG = (242, 250, 255)
DARK_BG = (29, 58, 42)

PAL = {
    "A_blu_white":   ((255, 255, 255), (22, 125, 168)),
    "B_kenney_blue": ((205, 238, 251), (20, 83, 138)),
    "C_azure":       ((28, 159, 215), (10, 74, 117)),
}

def recolor(src_path, fill, outline):
    im = Image.open(src_path).convert("RGBA")
    px = im.load()
    w, h = im.size
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            v = min(1.0, (r + g + b) / 3.0 / 240.0)
            px[x, y] = (
                int(outline[0] + (fill[0] - outline[0]) * v + 0.5),
                int(outline[1] + (fill[1] - outline[1]) * v + 0.5),
                int(outline[2] + (fill[2] - outline[2]) * v + 0.5),
                a,
            )
    return im

def _font(size):
    for cand in (r"C:\Windows\Fonts\msyh.ttc",
                 os.path.join(_HERE, "fonts", "ZCOOL-Kuaile.ttf")):
        if os.path.exists(cand):
            return ImageFont.truetype(cand, size)
    raise RuntimeError("no font found: msyh.ttc / ZCOOL-Kuaile.ttf")

IMG = Image.new("RGB", (W, H))
d = ImageDraw.Draw(IMG)
d.rectangle([0, 0, 640, H], fill=LIGHT_BG)
d.rectangle([640, 0, W, H], fill=DARK_BG)

f_title = _font(17)
f_sub = _font(11)
f_head = _font(12)
f_lab = _font(11)

def _center(x, y, text, font, fill):
    tw = d.textlength(text, font=font)
    d.text((x - tw / 2.0, y), text, font=font, fill=fill)

CHIPS = [("原版", None, "白芯黑边"), ("A 蓝边白芯", "A_blu_white", None),
         ("B Kenney 浅蓝", "B_kenney_blue", None), ("C 亮蓝芯", "C_azure", None)]

ROWS = [
    ("Q 版指针", "pointer_toon_a", "全局默认（推荐）"),
    ("标准箭头", "pointer_a", "备选默认"),
    ("悬停手型", "hand_point", "按钮 / 卡片 hover"),
    ("拖拽握拳", "hand_closed", "建造拖拽"),
    ("战场准星", "cross_large", "战场 / 编辑器画布"),
    ("擦除笔刷", "drawing_eraser", "地图编辑器笔刷"),
]

def draw_col(x0, text_colors, sub_colors):
    head_y = 66
    cx = x0 + 12
    slot_w = (628 - 100) / 4.0
    for i, (name, key, note) in enumerate(CHIPS):
        c = cx + slot_w * i + slot_w / 2.0
        _center(c, head_y, name, f_head, text_colors[0])
        if note:
            _center(c, head_y + 16, note, f_sub, sub_colors[0])
    y = head_y + 36
    for rname, icon, usage in ROWS:
        yy = y + 2
        d.text((x0 + 12, yy), rname, font=f_lab, fill=text_colors[0]); yy += 17
        d.text((x0 + 12, yy), icon, font=f_sub, fill=sub_colors[0]); yy += 15
        d.text((x0 + 12, yy), usage, font=f_sub, fill=sub_colors[1])
        for i, (name, key, _note) in enumerate(CHIPS):
            if key is None:
                im = Image.open(os.path.join(SRC, icon + ".png")).convert("RGBA")
            else:
                im = recolor(os.path.join(SRC, icon + ".png"), *PAL[key])
            im = im.resize((64, 64), Image.NEAREST)
            c = cx + slot_w * i + (slot_w - 64) / 2.0
            IMG.paste(im, (int(c), int(y)), im)
        y += 100

draw_col(0, [(27, 77, 120)], [(125, 156, 180), (150, 175, 195)])
draw_col(640, [(207, 227, 242)], [(159, 192, 216), (120, 148, 168)])

legend = ("A = 白芯 #ffffff + 深蓝描边 #167da8（清爽）    "
          "B = 浅蓝芯 #cdeffb + 深蓝描边 #14538a（Kenney 蓝系，推荐）    "
          "C = 亮蓝芯 #1c9fd7 + 描边 #0a4a75（醒目）")
_center(W / 2.0, H - 28, legend, f_sub, (27, 77, 120))

os.makedirs(os.path.dirname(OUT), exist_ok=True)
IMG.save(OUT)
print("saved", os.path.abspath(OUT), IMG.size)
