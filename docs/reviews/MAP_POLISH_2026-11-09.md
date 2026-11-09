# 首章地图结构与地形优化验收

程序0.9.8.3 / GDD v0.37.105 / schema12 / 分支0.9.8，main保持c7860ec。

按用户反馈，首章由重复折线路径改为入门双弯、不对称火场、十字回穿、双翼分流、双环汇流、逆向纵深、交叉双路和Boss援路综合关。共13条完整路线，普通分流按固定循环指派，交叉按既定方向通过，共享前后段自然形成一分二/二合一。第八关援路移到可见战场内，所有路线汇向同一基地；多出怪口、多逃逸出口与多基地生命/失守规则已登记STAGES §5.9为后续设计。

地形沿本轮14张160px原创素材，三主题共用连续路肩、自然地表与分层树石，夜战只保留火把局部光。编辑器可选择主路、支路或Boss援路编辑，保存/撤销保留其他路线，导出纯底图时隐藏网格。

| 验收 | 结果 |
|---|---|
| 回归 | 10项通过：MapVisual、MapRoute、MapEditor、Stage0、BattleVisual、HeroModel、Smoke、Flow、PackVerify、Progression |
| 地图与路线 | 1348项视觉/占路检查、660项路线检查；全部路线注册、真实波次分流/固定指派、共享基地、HUD可见性、推荐位与编辑保存往返 |
| 连续养成 | 4518项通过；两种真实新档策略均首章8关、0刷关、0失败；不建塔负例失败且不发奖励 |
| 原生画面 | 最终16张；8关、拖放/战斗、实际分流/交叉/Boss援军、缺图回退与编辑器/纯底图 |
| 资产与数据 | 145个哈希一致；117个非地图资产保持；8个关卡仅布局字段改变，波次、经济、奖励和角色数值保持 |
| Windows包 | 560项通过；1355个构建输入与当前源一致；独立启动、实际Spine release DLL与PE版本0.9.8.3通过 |

[图片与路线示意](../ui_concept/runtime_0.9.8.3/README.md) / [结构化结果](map_polish_2026-11-09/summary.json) / [连续通关](map_polish_2026-11-09/progression_results.json) / [资源检查](map_polish_2026-11-09/source_verification.json) / [发行包检查](map_polish_2026-11-09/release_results.json)。便携包：`build/FengHuoLianYing_v0.9.8.3_Windows.zip`，附EXE、Spine DLL、原D69声明与SHA256清单。

修复记录见BUGS v0.96（B-193～B-200）：主路地标、底部建造提示、编辑器测试释放、HUD遮路、波次path_id未生效、首关偏离格中心、编辑器假图外延长格、连续测试误把推荐位当硬限制。连续测试现按真实自由建造规则使用可见区域全部合法格，塔数上限、资源策略、金币与升阶消耗保持；第八关标准阵容为关羽、孙尚香（稳定ID huang_zhong）、皇甫嵩、诸葛亮，使用已合法解锁并培养的固有破隐者反制隐匿敌人。复验同时修正自由建造候选位与反隐阵容，未调整怪物、角色、奖励或经济数值。

Stage0保留历史基线的无效JSON/重复结算负例与退出资源告警；其他回归无错误，少数原有驱动仍有ObjectDB退出警告。包探针用编辑器打开发行包时出现3条预期编辑器库查找信息，随后必须成功加载随包release DLL；独立EXE无错误。归档日志仅规范换行、移除终端颜色和行尾空白，原始输出保留在build目录。

复现：先运行`python tools/generate_chapter_layouts.py`重建八关布局（不修改战斗字段），地图美术由`python tools/map_field_art.py`、`render_battle_visuals.gd -- --manifest=res://assets/battle_visuals/map_render_manifest.json`及`python tools/finalize_map_art.py`重建；Godot编辑器导入后运行表中10个测试场景。`MapVisualPreviewRunner.tscn`捕获16张原生图，自动化应隔离APPDATA/LOCALAPPDATA。按Windows预设导出，再用`tools/verify_gear_export.gd`对实际发行包验收。

0.9.8.2包和本轮仅美术阶段证据保留；交付提交推送0.9.8，下一个编号正式开发前不合并main。
