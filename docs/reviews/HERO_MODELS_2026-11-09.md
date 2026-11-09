# 三将原模型与五将头像验收

程序0.9.8.2 / GDD v0.37.103 / schema12 / 分支0.9.8，main保持c7860ec。

按用户指定接入D69原版072貂蝉、312赵云、314诸葛亮，保留原服饰、武器、贴图和动画；骨架仅迁移Spine3.8→4.3格式。赵云根骨相对初始位移在运行时乘0.08，三将显式选择default皮肤以激活其依赖骨骼。貂蝉头像单独隐藏武器槽位、赵云脸部居中，关羽也改为同源脸部/头冠圆形头像。

| 验收 | 结果 |
|---|---|
| 来源与重建 | 133个资产哈希一致；三将原PNG/atlas逐字节一致，转换骨架按归档JSON精确重建 |
| 相关回归 | HeroModel、LiuVisual、BattleVisual、Smoke、SkillKit、PackVerify、Flow共7项通过 |
| 三将动作专项 | 131项通过：皮肤激活、朝向、原攻击时点、实际暴击与随机抽样、大招优先级、回待机 |
| 原样板回归 | 刘备18项、战场视觉63项通过，包含原角色时标与敌人表现 |
| 无Spine运行库 | 独立副本中19项通过：三将程序化表现、同源头像、实际辅助/近战/弹道及大招 |
| 动画采样 | 676帧无裁切；116张原生关键帧、477项检查通过 |
| 实际界面与战斗 | 50项通过；16张1280×720截图覆盖养成、百科、编队、拖放、普通/暴击/辅助/大招 |
| Windows发行包 | 516项通过；独立启动、实际发行Spine DLL、PE与项目版本0.9.8.2 |

待机完整轮廓（1280×720实际像素，含武器）：关羽80×87、刘备69×80、貂蝉81×77、赵云104×82、诸葛亮87×78。诸葛亮仍即时生成法球并在命中结算；貂蝉普通辅助与三将大招保持即时效果；赵云源普攻0.6333s按倍速对齐原近战0.110s。伤害数值、技能倍率、成长曲线与抽样顺序未改。

[最终实机图片](../ui_concept/runtime_0.9.8.2/README.md) / [结构化结果与日志](hero_models_2026-11-09/summary.json) / [包检查](hero_models_2026-11-09/release_results.json) / [来源校验](hero_models_2026-11-09/source_verification.json)。Windows包位于build/FengHuoLianYing_v0.9.8.2_Windows.zip，EXE与Spine DLL同目录，无需安装Godot；附原素材声明与文件SHA256清单。

原生测试使用独立存档和明确的视觉夹具，不作为本轮关卡/养成平衡证据；本轮不重跑全章长期平衡。动作帧沿用2026-11-06最终皮肤修复后的676帧，2026-11-09重验最终代码、头像界面、拖放与发行包。关羽头像首次PackVerify在导入前失败，最终导入后通过；B-191修正截图鼠标位置，B-192修正包验证读取已导入骨架的方式，失败日志保留。包探针使用编辑器装载发行包时先出现3条编辑器库查找信息，随后显式加载随包发行DLL并通过全部检查；实际EXE独立启动无错误。

复现顺序（Godot4.7.1及仓库内Windows Spine扩展，Python需要Pillow）：

1. `python tools/import_d69_heroes.py`，从各角色source/d69_编号归档重建；`godot --headless --path . --editor --quit`导入。
2. `godot --path . res://tools/capture_hero_expansion.tscn`捕获676帧；`godot --path . res://tools/capture_hero_portraits.tscn`捕获貂蝉头像专用帧；`godot --path . res://tools/capture_battle_visuals.tscn -- --capture-dir=res://build/hero_frames_skin_0.9.8.2`捕获116张关键帧。
3. `python tools/finalize_battle_visuals.py --frames-dir build/hero_frames_skin_0.9.8.2`重建头像/测量清单，再执行编辑器导入。
4. `godot --headless --path . res://tests/HeroModelRunner.tscn`，以及上述6项相关回归；`godot --path . res://tests/HeroModelPreviewRunner.tscn`捕获实际界面。回退测试在不含bin及GDExtension列表的独立副本中运行同一HeroModelRunner，保留导入纹理与脚本类缓存并使用独立APPDATA。
5. 导出Windows预设；独立启动EXE。通过`--main-pack`加载发行EXE、`--script tools/verify_gear_export.gd`运行包探针；必要时以`--release-extension=<临时gdextension>`指向随包release DLL。全部运行日志和结构化结果见证据目录。

原0.9.8.1包与A/B试作证据保留；版本分支提交推送，下一编号正式开发前不合并main。
