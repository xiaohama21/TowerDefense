# -*- coding: utf-8 -*-
"""docs/ui_concept/src/icons_hud —— 通用 HUD 图徽「白底」生成脚本（PIL，非 HTML/Chrome 流程）。

口径（2026-09-14 用户拍板「全部图标要都用白底」，出图规范见 ART_PROMPTS §2.2 v0.13）：
  整册图徽统一 **纯白圆角方底板 `#ffffff`** —— 160×160 画布、底板圆角 30px、符号按最长边缩到 116px 居中；
  不再输出「透明底 / 深藏青底板」件（2026-09-14 之前的历史件在 git 中可回溯）。

输入（本地素材；第 1 项为个人机器路径、非仓库基线）：
  1) F:\\godotProject\\leonardo.ai\\通用HUD\\png\\*.png —— 网格图切分好的 16 枚单符号（伤害 3 / 属性 7 / 状态 6，原图带深藏青底板）；
  2) docs/ui_concept/src/icons_battle/{coin,base_hp,wave_flag}.png —— 立绘级原图（金币 / 基地生命 / 波次旗帜）。
输出：docs/ui_concept/src/icons_hud/*.png —— 18 枚 160×160 白底图徽（coin 符号 108px / base_hp 112px 略小留边）。

处理链（与历史两段脚本等效、逐字节可复现）：剥离深藏青底板 → 归一化到方画布 → 合成到白底板上。
运行：python prep_icons_hud.py（本机素材缺失即中止，不动仓库文件）。
"""
import os
import sys
from collections import deque
from PIL import Image, ImageDraw, ImageFilter

LOCAL = r"F:\godotProject\leonardo.ai\通用HUD\png"   # 16 枚单符号（个人机器路径）
BATTLE = r"docs\ui_concept\src\icons_battle"          # 立绘级原图（仓库内）
DST = r"docs\ui_concept\src\icons_hud"                # 输出目录（仓库内）

PLATE, RADIUS, MARGIN = 160, 30, 0.06
GLYPH_BOX = 116                                       # 通用符号最长边
CORE_PASSES = 3
SPECK_AREA, SPECK_DARK = 60, 140                      # 孤立暗色小碎点清理阈值

FLAT = ["dmg_physical", "dmg_magic", "dmg_true",
        "stat_attack_speed", "stat_range", "stat_armor", "stat_exp", "stat_tenacity",
        "stat_armor_pen", "stat_move_speed",
        "status_slow", "status_burn", "status_vulnerable", "status_stun", "status_fear", "status_knockback"]
RES = {"coin": ("coin.png", 108), "base_hp": ("base_hp.png", 112), "wave_flag": ("wave_flag.png", 116)}


def navy(r, g, b, a):
    return a > 0 and (b - g) >= 14 and (b - r) >= 18 and b <= 135


def strip(im):
    """剥离深藏青底板：与画布边缘连通的底板整片移除、被符号包裹的厚底块同去、细窄同色描线保留、孤立碎点清理。"""
    im = im.convert("RGBA")
    w, h = im.size
    px = im.load()
    mp = [[navy(*px[x, y]) for x in range(w)] for y in range(h)]
    mask = Image.new("L", (w, h), 0)
    mk = mask.load()
    for y in range(h):
        for x in range(w):
            if mp[y][x]:
                mk[x, y] = 255
    core = mask
    for _ in range(CORE_PASSES):
        core = core.filter(ImageFilter.MinFilter(3))
    cp = core.load()

    seen = [[False] * w for _ in range(h)]
    q = deque()
    for y in range(h):
        for x in range(w):
            if cp[x, y] > 128 or px[x, y][3] < 250:
                q.append((x, y))
                seen[y][x] = True
    while q:
        x, y = q.popleft()
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = x + dx, y + dy
            if 0 <= nx < w and 0 <= ny < h and not seen[ny][nx] and mp[ny][nx]:
                seen[ny][nx] = True
                q.append((nx, ny))

    alpha = Image.new("L", (w, h))
    ap = alpha.load()
    for y in range(h):
        for x in range(w):
            ap[x, y] = 0 if (seen[y][x] and mp[y][x]) else px[x, y][3]

    vis = [[False] * w for _ in range(h)]
    for y in range(h):
        for x in range(w):
            if ap[x, y] > 60 and not vis[y][x]:
                comp, qq, sumv = [], deque([(x, y)]), 0
                vis[y][x] = True
                while qq:
                    a, b = qq.popleft()
                    comp.append((a, b))
                    r, g, bl, _ = px[a, b]
                    sumv += max(r, g, bl)
                    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                        nx, ny = a + dx, b + dy
                        if 0 <= nx < w and 0 <= ny < h and not vis[ny][nx] and ap[nx, ny] > 60:
                            vis[ny][nx] = True
                            qq.append((nx, ny))
                if len(comp) < SPECK_AREA and sumv / len(comp) < SPECK_DARK:
                    for a, b in comp:
                        ap[a, b] = 0

    alpha = alpha.filter(ImageFilter.GaussianBlur(0.5))
    im.putalpha(alpha)
    return im


def fit_square(im):
    """裁边 + 归一化到 160 方画布（符号占内框 88%，四周等距留白）。"""
    bbox = im.getbbox()
    if bbox:
        im = im.crop(bbox)
    side = max(im.size)
    canvas = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    canvas.alpha_composite(im, ((side - im.width) // 2, (side - im.height) // 2))
    inner = int(PLATE * (1 - 2 * MARGIN))
    canvas = canvas.resize((inner, inner), Image.LANCZOS)
    out = Image.new("RGBA", (PLATE, PLATE), (0, 0, 0, 0))
    off = (PLATE - inner) // 2
    out.alpha_composite(canvas, (off, off))
    return out


def plate_layer():
    """纯白圆角方底板（整册同一形状语言）。"""
    layer = Image.new("RGBA", (PLATE, PLATE), (0, 0, 0, 0))
    ImageDraw.Draw(layer).rounded_rectangle([0, 0, PLATE - 1, PLATE - 1], radius=RADIUS, fill=(255, 255, 255, 255))
    return layer


def compose(glyph, box=GLYPH_BOX):
    """符号按最长边缩到 box 像素后居中合成到白底板上。"""
    g = glyph.convert("RGBA")
    bbox = g.getbbox()
    if bbox:
        g = g.crop(bbox)
    scale = box / max(g.size)
    g = g.resize((max(1, round(g.width * scale)), max(1, round(g.height * scale))), Image.LANCZOS)
    out = plate_layer()
    out.alpha_composite(g, ((PLATE - g.width) // 2, (PLATE - g.height) // 2))
    return out


def main():
    if not os.path.isdir(LOCAL):
        sys.exit("本地素材目录不存在：%s（白底合成需该目录；仓库文件未改动）" % LOCAL)
    missing = [n for n in FLAT if not os.path.isfile(os.path.join(LOCAL, n + ".png"))]
    missing += [f for f, _ in RES.values() if not os.path.isfile(os.path.join(BATTLE, f))]
    if missing:
        sys.exit("素材缺件：%s（未写任何文件）" % ", ".join(missing))
    os.makedirs(DST, exist_ok=True)
    for n in FLAT:
        compose(fit_square(strip(Image.open(os.path.join(LOCAL, n + ".png"))))).save(os.path.join(DST, n + ".png"))
    for n, (f, box) in sorted(RES.items()):
        compose(Image.open(os.path.join(BATTLE, f)), box).save(os.path.join(DST, n + ".png"))
    print("done", len(FLAT) + len(RES))


main()
