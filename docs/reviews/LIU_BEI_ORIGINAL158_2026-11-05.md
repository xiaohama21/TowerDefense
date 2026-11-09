# 原版158替换刘备验收

程序0.9.8.1 / GDD v0.37.97 / 分支0.9.8，main保持c7860ec。

用户最终选择直接使用原158（Hero_LiBai_A）。原PNG/atlas逐字节保留，46骨骼/36槽位和原动画内容保持；仅迁移Spine3.8→4.3格式。原始JSON/贴图/图集/声明及来源哈希在assets/battle_visuals/liu_bei/source/d69_158和provenance.json。A/B试作均停止采用，作为历史记录保留并排除导出。

刘备待机完整轮廓69×80px，关羽80×87px；原生朝左，右向镜像。头像由同一Idle骨架渲染。源普攻0.5333s按倍速对齐原战斗0.110s；真实暴击后切原Critical0.300s，不额外抽样。原素材无XX，施法使用原Appear，辅助效果仍即时；空Active_A不播放，光环机制保持。

| 验收 | 结果 |
|---|---|
| 原文件与主资产 | 原PNG/atlas一致；105个主资产哈希一致，候选不混入 |
| 本轮相关回归 | LiuVisual/BattleVisual/Smoke/SkillKit/PackVerify/Flow，6项通过 |
| 刘备专项 | 18项通过，含朝向、普攻时点、真实暴击/随机顺序、光环与即时大招 |
| 战场视觉 | 63项通过，含原生及程序化回退时标 |
| 原生捕获 | 六身份74帧，306项通过，精确帧时间检查 |
| 真实首关 | 25项通过，Lv1合法部署/6波/结算/重载 |
| Windows包 | 482项通过，独立启动、实际Spine DLL、PE0.9.8.1 |

[证据目录](liu_original158_2026-11-05/) / [最终原生图片](../ui_concept/runtime_0.9.8.1/README.md)。首次包检查曾按原PNG文件哈希读取导入纹理而误报，修正为ResourceLoader加载后全部通过；首次日志保留，BUGS B-184。

本轮未重复旧稿的22项全量长回归；上述数字均来自最终原158模型的专项和集成运行。伤害、技能基础/成长/收益数据未改，旧0.9.8.0及A/B证据不冒充本轮结果。

复现：tools/import_liu_bei_158.py → Godot导入 → tests/LiuVisualRunner.tscn、tests/BattleVisualRunner.tscn → tools/capture_battle_visuals.tscn → tools/finalize_battle_visuals.py（--frames-dir指定本次目录）。Windows导出后由tools/verify_gear_export.gd使用实际Spine DLL核验。

归档日志仅归一化换行，原始输出保留在build对应目录。
