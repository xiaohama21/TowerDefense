# -*- coding: utf-8 -*-
"""docs/ui_concept/src/icons_hud —— 通用 HUD 图徽「出图 -> 抠图」脚本（PIL，非 HTML/Chrome 流程）。

口径（2026-09-14 用户校正「用白底是为了好抠图，不是让你直接用白底，图是要融入当前背景的」）：
  出图白底 = **抠图原料**（便于一键去背），**不是交付底**；
  交付 / 入库件 = **透明底符号**，界面里靠所在面板自身的背景（深色顶栏 / 浅色卡片）自然融合；
  **不给图标加白底 / 黑底 / 深藏青底板，也不在图标外画底框**（出图规范见 ART_PROMPTS 2.2）。

输入（第 1 项为个人机器路径、非仓库基线）：
  1) F:\\godotProject\\leonardo.ai\\通用HUD\\png\\*.png —— 网格图切分好的 16 枚单符号（白底已去、仍带出图时的深藏青底板）；
  2) docs/ui_concept/src/icons_battle/{coin,base_hp,wave_flag}.png —— 立绘级原图（已是透明件，无底板）。
输出：docs/ui_concept/src/icons_hud/*.png —— 19 枚 160x160 **透明底**符号
  （伤害 3 / 属性 7 / 状态 6 / 金币 / 基地生命 / 波次旗帜）。

处理链：去白底残边 -> 剥离深藏青底板（含被符号包裹的厚底块；细窄同色描线保留为细节线）-> 孤立碎点清理 -> 归一化 160 透明画布。
运行：python prep_icons_hud.py（本机素材缺失即中止，不动仓库文件）。
"""
import os
import sys
from collections import deque
from PIL import Image, ImageFilter

LOCAL = r"F:\godotProject\leonardo.ai\通用HUD\png"   # 16 枚单符号（个人机器路径）
BATTLE = r"docs\ui_concept\src\icons_battle"           # 立绘级原图（仓库内）
DST = r"docs\ui_concept\src\icons_hud"                 # 输出目录（仓库内）

OUT, MARGIN = 160, 0.06
CORE_PASSES = 3
SPECK_AREA, SPECK_DARK = 60, 140        # 孤立暗色小碎点清理阈值
WHITE_MIN = 232                         # 白底判定（仅清与画布边缘连通的近白）

FLAT = ["dmg_physical", "dmg_magic", "dmg_true",
        "stat_attack_speed", "stat_range", "stat_armor", "stat_exp", "stat_tenacity",
        "stat_armor_pen", "stat_move_speed",
        "status_slow", "status_burn", "status_vulnerable", "status_stun", "status_fear", "status_knockback"]
RES = ["coin", "base_hp", "wave_flag"]


def navy(r, g, b, a):
    return a > 0 and (b - g) >= 14 and (b - r) >= 18 and b <= 135


def key_white(im):
    """去白底：与画布边缘连通的近白像素 -> 透明（白底只是抠图原料）。"""
    im = im.convert("RGBA")
    w, h = im.size
    px = im.load()
    white = [[(px[x, y][3] > 0 and min(px[x, y][:3]) >= WHITE_MIN) for x in range(w)] for y in range(h)]
    seen = [[False] * w for _ in range(h)]
    q = deque()
    for y in range(h):
        for x in (0, w - 1):
            if white[y][x] and not seen[y][x]:
                seen[y][x] = True
                q.append((x, y))
    for x in range(w):
        for y in (0, h - 1):
            if white[y][x] and not seen[y][x]:
                seen[y][x] = True
                q.append((x, y))
    while q:
        x, y = q.popleft()
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = x + dx, y + dy
            if 0 <= nx < w and 0 <= ny < h and not seen[ny][nx] and white[ny][nx]:
                seen[ny][nx] = True
                q.append((nx, ny))
    alpha = im.getchannel("A")
    ap = alpha.load()
    for y in range(h):
        for x in range(w):
            if seen[y][x]:
                ap[x, y] = 0
    im.putalpha(alpha)
    return im


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

    A = Image.new("L", (w, h))
    ap = A.load()
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

    A = A.filter(ImageFilter.GaussianBlur(0.5))
    im.putalpha(A)
    return im


def fit_square(im):
    """裁边 + 归一化到 160 方画布（符号占内框 88%，四周等距留白）——透明底，不合成任何底板。"""
    im = im.convert("RGBA")
    bbox = im.getbbox()
    if bbox:
        im = im.crop(bbox)
    side = max(im.size)
    canvas = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    canvas.alpha_composite(im, ((side - im.width) // 2, (side - im.height) // 2))
    inner = int(OUT * (1 - 2 * MARGIN))
    canvas = canvas.resize((inner, inner), Image.LANCZOS)
    out = Image.new("RGBA", (OUT, OUT), (0, 0, 0, 0))
    off = (OUT - inner) // 2
    out.alpha_composite(canvas, (off, off))
    return out


def main():
    if not os.path.isdir(LOCAL):
        sys.exit("本地素材目录不存在：%s（抠图需该目录；仓库文件未改动）" % LOCAL)
    missing = [n for n in FLAT if not os.path.isfile(os.path.join(LOCAL, n + ".png"))]
    missing += [os.path.join(BATTLE, n + ".png") for n in RES if not os.path.isfile(os.path.join(BATTLE, n + ".png"))]
    if missing:
        sys.exit("素材缺件：%s（未写任何文件）" % ", ".join(missing))
    os.makedirs(DST, exist_ok=True)
    for n in FLAT:
        fit_square(strip(key_white(Image.open(os.path.join(LOCAL, n + ".png"))))).save(os.path.join(DST, n + ".png"))
    for n in RES:
        fit_square(Image.open(os.path.join(BATTLE, n + ".png"))).save(os.path.join(DST, n + ".png"))
    print("done", len(FLAT) + len(RES))


main()
