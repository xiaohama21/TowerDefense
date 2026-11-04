# 0.9.4.3界面运行验收

2026-11-04，Godot 4.7.1 / Windows / OpenGL，53张1280×720原生窗口截图。隔离测试存档，界面来自实际运行节点，截图不作修改。

技能页左右16px、上下14px、卡间12px；物品名称和短用途/效果覆盖装备、背包、编队遗物、信物、军需和奖励详情。地图卡尾两行名称数量摘要，完整说明在可滚动详情查看。

- [养成技能首屏](skills_guan_yu.png)、[大招滚动](ultimate_guan_yu.png)：技能名称、简介、升级与数值标签保留，边框有留白。
- [百科技能首屏](encyclopedia_skill_spacing.png)、[百科技能底部](encyclopedia_skill_bottom_spacing.png)：页签内边距与卡间距统一。
- [养成装备](develop_equipment_icons.png)、[百科装备](encyclopedia_equipment_icons.png)、[背包装备详情](inventory_equipment_description.png)：名称、职业、两词条中文简介与持有/可用数量常显。
- [背包全部](inventory_all_descriptions.png)、[遗物](inventory_relic_descriptions.png)、[养成信物](develop_relic_descriptions.png)：名称、描述与获取信息可读。
- [编队遗物](squad_relic_descriptions.png)、[确认出战](squad_confirm_relic_descriptions.png)：名称和效果副行可见，横向滚动与选择状态正常。
- [军需处](supply_depot_descriptions.png)、[局内军需](battle_supply_descriptions.png)：名称、当前等级中文摘要，军需带和状态同步。
- [标准s08地图](map_economy.png)、[困难s08地图](map_economy_hard.png)：八关一屏，物品摘要限制两行，详情奖励独立滚动，出征按钮保持在面板内。
- [胜利经济升级](victory_economy_levelup.png)、[多项物品奖励](victory_item_descriptions.png)：物品名称数量和说明直接显示，多项奖励可滚动。

11项相关回归全部通过：PackVerify、SmokeRunner、FlowRunner、ExitFlowRunner、RankRunner、SupplyStateRunner、DevelopRefreshRunner、ShopRunner（461）、SkillKitRunner、GearRunner（446）、ItemUiRunner（91）。119项Windows包内检查通过，独立启动、真实Spine DLL与PE0.9.4.3验证通过。

原始结果见regression_results.json、release_results.json，截图SHA256见window_capture_hashes.json。总纲v0.37.79 / UI_LAYOUT v0.20.81 / BUGS v0.76 B-143~B-144。程序和schema v10的机制/数值不变；旧概念图和包保留。
