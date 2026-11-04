# 0.9.4.2 图标与技能动作运行验收

2026-11-04，42张1280×720原生Godot窗口截图，独立临时档案，不触碰玩家存档。生成入口：`tests/ShopPreviewRunner.tscn -- --capture-dir=res://build/verify_0.9.4.2`。

本版三枚经济图徽（暖金元宝/冠印等级/进度冠印经验）、五档独立装备品质与周卫两技能补缺；全部27技能按小人＋武器/器物＋动作重绘。名称、描述和等级保持常显，技能机制、价格、存档schema v10不变。

- `skills_*` / `ultimate_*`：九将各两张，覆盖27技能人物动作主图、被动/大招与中文信息。
- `develop_zhou_wei_skills` / `encyclopedia_zhou_wei_skills`：新增周卫陷阵/麦城死战图徽及百科全解锁。
- `develop_equipment_icons` / `encyclopedia_equipment_icons` / `inventory_equipment_icons`：三处装备凡品菱形徽记。
- `shop_*`：金元宝余额、价格和刷新，两列物资/装备、三列遗物，限购/不足/保存失败/购买滚动等状态。
- `map_economy*` / `victory_economy_levelup`：经济奖励、难度预告与主公升级图徽。

图集：[27技能人物动作](../skill_icons_v2_preview.png)、[技能亮暗底56/38/20px](../skill_icons_v2.png)、[十枚补缺15~56px](../icons_v2_additions.png)、[完整283目录](../icons_v2.html)。高四档装备品质仅备图，不增加玩法。

9项相关回归（商店461项）、283图标透明度/裁切/覆盖与27技能独立PNG/名称检查、Windows独立启动/实际Spine DLL/PE0.9.4.2及115项包内检查通过。增量中断恢复验证通过。GDD v0.37.78 / ICONS v1.4 / UI_LAYOUT v0.20.80 / UI_CONCEPT v0.36 / BUGS v0.75 B-140~B-142。

截图由`get_viewport().get_texture().get_image()`取得，界面内未加后期文字或改图；SHA256验收留在本地build/verify_0.9.4.2。旧运行截图与旧包继续保留。
