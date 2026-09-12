# -*- coding: utf-8 -*-
"""docs/ui_concept/src/icons_hud —— 通用 HUD 图徽抠图脚本（PIL，非 HTML/Chrome 流程）。

输入：本地 leonardo.ai 通用HUD 网格图切分出的透明 PNG（个人机器路径，非仓库基线）。
输出：docs/ui_concept/src/icons_hud/*.png —— 160x160 透明底符号（与金币图标同款）。

剥离规则：
  1) 与透明边缘连通的外侧深藏青底板 -> 整片移除（含低 alpha 柔边残留）；
  2) 被符号包裹的“厚”底板块（如眩晕轨道环之间）-> 一并移除；
  3) 细窄的同色描线（护甲接缝 / 拳头指缝等）-> 保留为深色细节线；
  4) 孤立深色小碎点（JPEG 边缘噪点）-> 清理。
运行：python prep_icons_hud.py"""
import os
from collections import deque
from PIL import Image, ImageFilter

SRC = r"F:\godotProject\leonardo.ai\通用HUD\png"
DST = r"docs\ui_concept\src\icons_hud"
OUT, MARGIN = 160, 0.06
CORE_PASSES = 3
SPECK_AREA, SPECK_DARK = 60, 140      # 孤立暗色小碎点清理阈值
os.makedirs(DST, exist_ok=True)

def navy(r, g, b, a):
    return a > 0 and (b - g) >= 14 and (b - r) >= 18 and b <= 135

def strip(im):
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

    # 碎点清理：孤立的深色小连通块 = 抠图残留噪点
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

for n in [n for n in sorted(os.listdir(SRC)) if n.endswith(".png")]:
    fit_square(strip(Image.open(os.path.join(SRC, n)))).save(os.path.join(DST, n))
print("done")
