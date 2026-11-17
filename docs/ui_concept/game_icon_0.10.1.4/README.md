# 应用图标迭代 · 0.10.1.4明亮无火城楼

用户本轮要求：删除顶部火焰，整体更亮、不要阴暗。GDD v0.37.112 / ICONS v1.11 / ART_ASSETS v0.50 / ART_PROMPTS v0.30 / UI_CONCEPT v0.60；程序0.10.1.4，版本分支0.10.1，schema13。

当前运行源资产已更新为明亮无火版本，Windows发行验收已通过。删除火焰与火盆，保留中式城楼、赭瓦木梁、低厚石墙/墙垛、深门洞与单面军旗；底板改为明亮青瓷色，暖砂石及檐口提亮。sRGB亮度均值由87.06提高到179.71。

| 文件 | 内容 |
|---|---|
| [before_1024.png](before_1024.png) / `before.svg/png/ico` | 0.10.1.3最终稿；SVG/PNG/ICO与旧稿逐字节一致 |
| [after_1024.png](after_1024.png) / [after.png](after.png) / `after.svg/ico` | 本轮运行稿快照，明亮青瓷底与暖砂石城，无火焰、无火盆 |
| [bright_1024.png](bright_1024.png) / `bright.svg/png` | 当前母版的原生展示与256px预览，可由预览工具重渲 |
| [comparison.png](comparison.png) | 上一版与明亮无火版；大图及64/48/32/16px实际尺寸对照 |
| [verification.json](verification.json) | 源图尺寸、七档ICO、透明角、同源配方、亮度及去火检查 |

源资产验证已通过：256×256 PNG、1024×1024原生展示、16/24/32/48/64/128/256七档ICO同源，四角透明；目录395枚，其他394枚及290份旧素材（其中168份已跟踪）保持。Windows PE六档16/32/48/64/128/256解码像素与源ICO一致，文件/产品版本均为0.10.1.4；隔离导入/导出、独立启动、实际随包Spine release DLL及598项包内检查通过，ZIP CRC通过。主城/玩法源码与schema13保持，main保持`e1d8ab24af841920d05aade8583061b80732f8e9`。

[验收报告](../../reviews/GAME_ICON_BRIGHT_2026-11-17.md) / [发行汇总](../../reviews/game_icon_bright_2026-11-17/summary.json) / [Windows便携包](../../../build/FengHuoLianYing_v0.10.1.4_Windows.zip)。

## 复现

在仓库根目录运行：

```powershell
python tools/generate_game_icon.py --godot "<Godot控制台可执行文件>"
python tools/preview_game_icon_bright.py --godot "<Godot控制台可执行文件>"
```

`generate_game_icon.py`调用`game_icon_art.py`当前母版，只更新运行`game_crest.svg/png/ico`及该条目的描述。`preview_game_icon_bright.py`生成本目录`bright.svg/png`、`bright_1024.png`和`comparison.png`，以已归档`before`与当前母版比较；`after`保留本轮运行资产快照。预览使用Godot 4.7.1 ThorVG原生SVG解码，1024px展示经Lanczos缩放到256px，实际尺寸对照从256px图缩放。

[0.10.1.3历史索引](../game_icon_0.10.1.3/README.md)及其全部资产保留。旧形态/配色预览工具按已归档SVG重渲，历史稿不跟随当前母版变化；本目录`.gdignore`将比较稿排除在运行导入之外。
