# 0.10.1.4明亮无火城楼图标验收

程序0.10.1.4 / GDD v0.37.112 / ICONS v1.11 / ART_ASSETS v0.50 / ART_PROMPTS v0.30 / UI_CONCEPT v0.60 / schema13 / 版本分支0.10.1。

用户本轮明确要求删除顶部火焰，并让整体更亮、避免阴暗。设计、源资产实施与Windows发行验收均已完成，最终EXE与随包检查通过。

## 设计变化与保留

在0.10.1.3「赭瓦石城」基础上，完整删除顶部火焰和火盆，保留中央高城楼、单层宽挑檐、木梁、低厚石墙/墙垛、深门洞侧壁与单面军旗。底板改为明亮青瓷色，城墙改为暖砂石，赭瓦及木梁相应提亮；深门洞继续提供纵深，外围材质不再大面积压暗。瓦缝、淡石缝、墙垛侧壁与军旗折光继续保留。

验证记录的sRGB亮度均值由87.06提高至179.71；SVG结构检查确认无火焰、无火盆。运行SVG、256px PNG、七档ICO与1024px原生展示同源，ICO四角透明检查通过。

0.10.1.3全部资产与历史证据保留，本目录`before.svg/png/ico`逐字节对应其最终运行稿。旧形态/配色预览工具改为重渲归档SVG，避免因当前母版提亮去火而改变历史稿；其他394枚图标保持。

## 验收状态

| 检查 | 结果 |
|---|---|
| 设计与源图 | 去除火焰及火盆；亮度均值87.06→179.71；256×256运行PNG与1024×1024原生展示同源 |
| 图标目录 | 395枚通过；其他394枚保持；290份旧素材及其中168份已跟踪旧素材保持 |
| 源ICO | 16/24/32/48/64/128/256七档完整，同源生成，四角透明通过 |
| Windows PE | 六档16/32/48/64/128/256解码像素与源ICO一致；FileVersion/ProductVersion均为0.10.1.4 |
| Windows发行 | 隔离导入/导出、独立EXE启动、实际随包Spine release DLL及598项包内检查通过 |
| 输入与边界 | 导出源图标哈希匹配；主城与玩法源码保持；schema13保持；ZIP CRC检查通过 |

Godot导出会重编码PE图标且不嵌入24px帧，因此EXE按六个实际尺寸的解码像素核对；源ICO七档仍完整。包探针记录三条既有编辑器扩展查找信息，随后实际加载随包Spine template_release DLL；独立启动、导入/导出与包检查的最终错误列表均为空。

## 复现与证据

在仓库根目录运行：

```powershell
python tools/generate_game_icon.py --godot "<Godot控制台可执行文件>"
python tools/preview_game_icon_bright.py --godot "<Godot控制台可执行文件>"
```

第一条只生成当前运行徽章及其目录描述；第二条生成明亮无火预览和64/48/32/16px对照，使用本轮归档的`before`作为上一版。PNG使用Godot 4.7.1 ThorVG原生SVG解码，预览1024px再缩放；`after`为本轮运行资产快照。

[预览索引](../ui_concept/game_icon_0.10.1.4/README.md) / [上一版原图](../ui_concept/game_icon_0.10.1.4/before_1024.png) / [明亮无火原图](../ui_concept/game_icon_0.10.1.4/after_1024.png) / [前后与实际尺寸对照](../ui_concept/game_icon_0.10.1.4/comparison.png) / [源资产验证](../ui_concept/game_icon_0.10.1.4/verification.json) / [发行汇总](game_icon_bright_2026-11-17/summary.json)。便携包：[FengHuoLianYing_v0.10.1.4_Windows.zip](../../build/FengHuoLianYing_v0.10.1.4_Windows.zip)。

本轮修订继续留在0.10.1版本分支；main保持`e1d8ab24af841920d05aade8583061b80732f8e9`，本轮收尾不合并main。
