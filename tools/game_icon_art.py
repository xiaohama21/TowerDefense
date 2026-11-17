"""Original Three Kingdoms game emblem: bright stone walls, red eaves and a military standard."""
from game_icon_fortress_art import build_fortress_crest

DESCRIPTION = "明亮青瓷底、暖砂石城与赭瓦，单面军旗；无火焰的中式城防游戏徽章"


def build_game_ico_frames(crest):
    """Keep the outer corner pixels transparent after small-size resampling."""
    from PIL import Image
    frames = []
    for size in (16, 24, 32, 48, 64, 128, 256):
        frame = crest.convert('RGBA').resize((size, size), Image.Resampling.LANCZOS)
        for corner in ((0, 0), (size - 1, 0), (0, size - 1), (size - 1, size - 1)):
            frame.putpixel(corner, (0, 0, 0, 0))
        frames.append(frame)
    return frames


def build_game_crest() -> str:
    return build_fortress_crest()
