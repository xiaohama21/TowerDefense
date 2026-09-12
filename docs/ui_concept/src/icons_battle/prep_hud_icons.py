"""局内 HUD 图标预处理（概念稿用，PIL 生成，非 Chrome 流程）。

源：F:/godotProject/leonardo.ai/通用HUD/*.jpg（1024x1024，白底 + 深藏青圆角底板 + 图形）
出：
  coin.png             金币（去白底、保留深藏青底板）
  base_hp.png          基地生命（同）
  wave_flag_plate.png  波次旗帜 · 带底板版（顶栏胶囊用）
  wave_flag.png        波次旗帜 · 仅旗帜（敌人出口按钮用，去白底 + 去底板）

运行：python prep_hud_icons.py
"""
from __future__ import annotations

import os

from PIL import Image, ImageChops, ImageFilter

SRC_DIR = r"F:/godotProject/leonardo.ai/通用HUD"
OUT_DIR = os.path.dirname(os.path.abspath(__file__))

WHITE_MIN = 225


def _mask_white(image):
    r, g, b = image.split()[:3]
    darkest = ImageChops.darker(ImageChops.darker(r, g), b)
    return darkest.point(lambda v: 255 if v >= WHITE_MIN else 0)


def _mask_navy(image):
    r, g, b = image.split()[:3]
    more_blue = ImageChops.subtract(b, r, scale=1.0).point(lambda v: 255 if v > 8 else 0)
    dark_r = r.point(lambda v: 255 if v < 80 else 0)
    dark_g = g.point(lambda v: 255 if v < 90 else 0)
    dark_b = b.point(lambda v: 255 if v < 110 else 0)
    mask = ImageChops.multiply(more_blue, dark_r)
    mask = ImageChops.multiply(mask, dark_g)
    return ImageChops.multiply(mask, dark_b)


def _key_out(image, background):
    alpha = ImageChops.invert(background.filter(ImageFilter.MaxFilter(3)))
    alpha = alpha.filter(ImageFilter.GaussianBlur(0.6))
    out = image.convert("RGBA")
    out.putalpha(alpha)
    return out


def _save_trimmed(image, name, pad=2, bbox_alpha=70):
    alpha = image.getchannel("A").point(lambda v: 255 if v > bbox_alpha else 0)
    box = alpha.getbbox()
    if box is not None:
        left, top, right, bottom = box
        image = image.crop((
            max(left - pad, 0),
            max(top - pad, 0),
            min(right + pad, image.width),
            min(bottom + pad, image.height),
        ))
    image.save(os.path.join(OUT_DIR, name))
    print("%-22s %s" % (name, image.size))


def main():
    coin = Image.open(os.path.join(SRC_DIR, "铜币图片.jpg")).convert("RGB")
    _save_trimmed(_key_out(coin, _mask_white(coin)), "coin.png")

    hp = Image.open(os.path.join(SRC_DIR, "基地血量图片.jpg")).convert("RGB")
    _save_trimmed(_key_out(hp, _mask_white(hp)), "base_hp.png")

    flag = Image.open(os.path.join(SRC_DIR, "波次旗帜.jpg")).convert("RGB")
    _save_trimmed(_key_out(flag, _mask_white(flag)), "wave_flag_plate.png")

    inner = ImageChops.lighter(_mask_white(flag), _mask_navy(flag))
    _save_trimmed(_key_out(flag, inner), "wave_flag.png")


if __name__ == "__main__":
    main()
