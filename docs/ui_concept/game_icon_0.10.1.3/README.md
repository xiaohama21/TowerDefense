# 应用图标重绘 · 0.10.1.3

用户方向：中式檐口、烽火台、军旗。GDD v0.37.110 / ICONS v1.10 / 程序0.10.1.3；最终赭瓦石城已细化、接入并完成Windows包验收。

[最终1024原生图](after_1024.png) / [窗口PNG256](after.png) / [SVG](after.svg) / [七档ICO](after.ico) / [最终尺寸对照](fortress_comparison.png) / [检查与哈希](verification.json) / [验收报告](../../reviews/GAME_ICON_2026-11-17.md)。

1. [形态对照](comparison.png)：旧图、A连营城楼、B烽火台。用户偏好A。
2. [配色对照](color_comparison.png)：A原青绿暖金、墨瓦朱墙、朱檐青石。用户相对偏好朱檐青石，随后明确城门/城楼和配色仍需进一步调整。
3. [城防结构对照](fortress_comparison.png)：中央高城楼＋两侧低厚墙/垛口，深门洞；用户确认赭瓦石城方向正确并要求继续细化。瓦缝、木梁、墙垛侧壁、石缝/门洞内壁、旗面折光和烽火亮芯已细化，最终稿为`after.*`。`fortress_warm_before_polish.svg/png`保存细化前稿，`fortress.*`保存暗色比较稿。

`before.svg/png/ico`逐字节保存0.10.1.2运行图标；`gate`和`beacon`保存第一轮A/B，`ink_vermilion`和`vermilion_stone`保存第二轮颜色。每稿具有256px PNG和1024px原生展示；`.gdignore`将开发比较稿排除在运行导入之外。

颜色复现：`python tools/preview_game_icon_colors.py --godot <Godot控制台可执行文件>`。以归档`gate.svg`为几何源，同工具的固定色表（亦存`palettes.json`）一次替换SVG色值；`tools/render_game_icon_previews.gd`使用Godot原生SVG解码，4倍渲染为1024px再Lanczos缩到256px。比较图的64/48/32/16px使用窗口PNG缩放。

原形态复现：A来自`tools/game_icon_art.py`第一轮母版（完整SVG已归档`gate.svg`），B来自`tools/game_icon_variant_art.py::build_beacon_variant()`。归档SVG可用`Godot --headless --path . --script tools/render_game_icon_previews.gd -- res://docs/ui_concept/game_icon_0.10.1.3/gate.svg res://docs/ui_concept/game_icon_0.10.1.3/beacon.svg`重渲，不必触碰其他394枚运行图标。

最终源为`tools/game_icon_fortress_art.py`，`game_icon_art.py`共用函数；`python tools/generate_game_icon.py --godot <Godot控制台可执行文件>`只生成运行game_crest，不重建其他394枚。`python tools/preview_game_icon_fortress.py --godot <Godot控制台可执行文件>`重渲最终结构/暗色稿及对照。PNG256与原生1024同源，ICO含16/24/32/48/64/128/256，EXE嵌入16/32/48/64/128/256六档且解码像素一致；395目录、598项包检查、独立启动、随包Spine DLL与PE0.10.1.3通过。
