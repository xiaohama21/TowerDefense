# 0.9.3.1 技能面板窗口验收

2026-11-03，1280×720原生Godot窗口；SkillPreviewRunner使用隔离档案生成截图。名称常显，副行显示被动Ⅰ/Ⅱ或大招及独立等级；中文简介交代作用对象与效果，图徽辅助，两列数值包含文字标签，触发规则、解锁品阶和升级耗书直接可读。

20张截图包括：九名武将各一张被动页和一张滚动至大招的窗口（skills_*、ultimate_*）；关羽大招升级至2级（develop_skill_upgrade）；诸葛亮百科锁定预览（encyclopedia_skills）。张飞紫阶未解锁状态包含于skills_zhang_fei。已目视检查文本换行、完整数值、升级按钮、锁定提示和滚动，大招卡可以完整显示；技能机制、数值、费用与schema v9保持原样。

复现：Godot --path . res://tests/SkillPreviewRunner.tscn -- --skills-only --capture-dir=res://build/verify_0.9.3.1

SkillKitRunner、GearRunner（449项）、FlowRunner通过。Windows release导出与独立启动通过，PE文件/产品版本0.9.3.1；交付Spine DLL实际加载，84项包内检查通过，含养成和百科各27技能的名称、描述、数值标签及装备、只读预览、奖励、schema v9、战斗配装与首波。
