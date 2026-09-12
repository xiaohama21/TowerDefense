#!/usr/bin/env python3
"""Kenney Cursor Pack 光标素材生成（重着色 + 热点标定 + 与代码一致性校验）。

输入：docs/ui_concept/src/kenney_cursor_pack/PNG/Outline/{Default(32px),Double(64px)}
输出：assets/ui/cursors/<icon>.png（32px）+ <icon>_2x.png（64px，高 DPI 备用）

定稿配色 B（Kenney 浅蓝，UI_LAYOUT §15）：芯 #cdeffb / 描边 #14538a，
按原图灰度明度线性映射双色（v = (r+g+b)/3/240，clamp 0..1，outline→fill 插值），
形状 / 描边结构 / 透明度逐像素保留。

热点不硬编码，按几何规则逐尺寸标定（Double 套非 Default 等比放大，不能 ×2）：
尖端类取瞄准方向上的极值实心像素簇质心（alpha >= 200），准星 / 手掌类取几何中心。
标定结果与 scripts/services/CursorService.gd 不一致时脚本报 FAIL（防文档/代码漂移）。

用法：
    python tools/prep_cursors.py                      # 生成 + 校验
    python tools/prep_cursors.py --montage out.png    # 额外输出热点校验图
"""
import os
import re
import sys
from PIL import Image, ImageDraw

_HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(_HERE)
SRC = os.path.join(ROOT, "docs", "ui_concept", "src", "kenney_cursor_pack", "PNG", "Outline")
DST = os.path.join(ROOT, "assets", "ui", "cursors")
GD = os.path.join(ROOT, "scripts", "services", "CursorService.gd")

FILL = (205, 238, 251)      # #cdeffb
OUTLINE = (20, 83, 138)     # #14538a
ALPHA_SOLID = 200

# 热点标定规则（尖端起见 UI_LAYOUT §15）
TIP_RULES = {
    "pointer_toon_a": "top_left",
    "pointer_a": "top_left",
    "cursor_disabled": "top_left",
    "hand_point": "top",
    "drawing_pen": "top_left",
    "drawing_brush": "bottom_right",
    "hand_closed": "center",
    "cross_large": "center",
    "drawing_eraser": "center",
}

_SCORE = {
    "top": lambda x, y: float(y),
    "top_left": lambda x, y: float(x + y),
    "bottom_right": lambda x, y: float(-(x + y)),
}


def recolor(src_path):
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
                int(OUTLINE[0] + (FILL[0] - OUTLINE[0]) * v + 0.5),
                int(OUTLINE[1] + (FILL[1] - OUTLINE[1]) * v + 0.5),
                int(OUTLINE[2] + (FILL[2] - OUTLINE[2]) * v + 0.5),
                a,
            )
    return im


def calibrate(im, rule):
    px = im.load()
    w, h = im.size
    if rule == "center":
        return (w // 2, h // 2)
    score = _SCORE[rule]
    solid = [(x, y) for y in range(h) for x in range(w) if px[x, y][3] >= ALPHA_SOLID]
    if not solid:
        return None
    best = min(score(x, y) for x, y in solid)
    sel = [(x, y) for x, y in solid if score(x, y) <= best + 1.0]
    cx = sum(p[0] for p in sel) / float(len(sel))
    cy = sum(p[1] for p in sel) / float(len(sel))
    # 吸附到最近的实心像素，保证热点落在可见笔画上
    return min(solid, key=lambda p: (p[0] - cx) ** 2 + (p[1] - cy) ** 2)


def read_gd_hotspots():
    if not os.path.exists(GD):
        return None
    text = open(GD, encoding="utf-8").read()
    found = {}
    for name, x, y in re.findall(r'"([a-z_0-9]+)":\s*Vector2\(\s*(\d+)\s*,\s*(\d+)\s*\)', text):
        found.setdefault(name, []).append((int(x), int(y)))
    return found


def build(montage_path=None, scale=8):
    os.makedirs(DST, exist_ok=True)
    names = sorted(TIP_RULES.keys())
    failures = []
    tiles = []
    table = {}
    for name in names:
        hits = []
        for sub, suffix, _label in (("Default", "", "32px"), ("Double", "_2x", "64px")):
            src = os.path.join(SRC, sub, name + ".png")
            if not os.path.exists(src):
                failures.append("missing source: %s" % src)
                continue
            im = recolor(src)
            out = os.path.join(DST, name + suffix + ".png")
            im.save(out)
            hot = calibrate(im, TIP_RULES[name])
            if hot is None or im.load()[hot][3] < ALPHA_SOLID:
                failures.append("%s: hotspot %s not solid" % (out, hot))
            hits.append(hot)
            if suffix == "":
                tiles.append((name, im, hot))
            print("  %-22s %-5s hotspot %-9s rule=%s" % (name + suffix + ".png", _label, hot, TIP_RULES[name]))
        table[name] = hits
    gd = read_gd_hotspots()
    if gd is None:
        print("\nCursorService.gd not found - skip cross-check")
    else:
        print("\nGDScript cross-check (scripts/services/CursorService.gd):")
        for name, hits in sorted(table.items()):
            got = gd.get(name)
            want32 = hits[0]
            if got is None:
                failures.append("%s: not registered in CursorService.gd" % name)
                print("  %-18s MISSING" % name)
            elif tuple(got[0]) != tuple(want32):
                failures.append("%s: gd=%s script=%s" % (name, tuple(got[0]), tuple(want32)))
                print("  %-18s MISMATCH gd=%s script=%s" % (name, tuple(got[0]), tuple(want32)))
            else:
                print("  %-18s ok %s" % (name, tuple(got[0])))
    if montage_path:
        _montage(tiles, montage_path, scale)
    print("\nhotspot table (32px, GDScript ready):")
    for name in names:
        print('    "%s": Vector2(%d, %d),' % (name, table[name][0][0], table[name][0][1]))
    return failures


def _montage(tiles, path, scale):
    cell = 32 * scale
    pad = 46
    cols = 5
    rows = (len(tiles) + cols - 1) // cols
    img = Image.new("RGB", (cols * (cell + pad), rows * (cell + pad)), (242, 250, 255))
    d = ImageDraw.Draw(img)
    for i, (name, im, (hx, hy)) in enumerate(tiles):
        cx = (i % cols) * (cell + pad) + pad // 2
        cy = (i // cols) * (cell + pad) + pad // 2
        big = im.resize((cell, cell), Image.Dither.NONE)
        img.paste(big, (cx, cy), big)
        px, py = cx + hx * scale + scale / 2.0, cy + hy * scale + scale / 2.0
        d.line([px - 14, py, px + 14, py], fill=(220, 0, 0), width=2)
        d.line([px, py - 14, px, py + 14], fill=(220, 0, 0), width=2)
        d.text((cx, cy + cell + 4), "%s (%d,%d)" % (name, hx, hy), fill=(27, 77, 120))
    img.save(path)
    print("montage:", os.path.abspath(path))


def main():
    argv = sys.argv[1:]
    montage = argv[argv.index("--montage") + 1] if "--montage" in argv else None
    print("recolor fill=%s outline=%s" % (FILL, OUTLINE))
    failures = build(montage)
    if failures:
        print("\nFAIL:")
        for f in failures:
            print("  " + f)
        return 1
    print("\nOK: %d icons x 2 sizes, hotspots calibrated + cross-checked" % len(TIP_RULES))
    return 0


if __name__ == "__main__":
    sys.exit(main())