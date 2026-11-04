# 0.9.6.1 原生界面验收（2026-11-04）

GDD v0.37.84 / FACTIONS v0.3 / CHARACTER_SKILLS v0.17 / UI_LAYOUT v0.20.86 / ICONS v1.8。

黄忠替换为吴国孙尚香，周仓替换为魏国典韦。技能名称与六枚动作图徽更新，技能ID、效果、数值、职业、解锁、天赋和旧档进度保持。鹊画弓与双铁戟直接显示名称、简述和未开放说明，不参与战斗。

全部25张截图由Godot原生1280×720窗口生成；902项窗口检查通过，孙尚香Lv100窄卡姓名按字体实际宽度验收，顶部被动及滚动后的大招分别截图。

| 截图 | 验收内容 |
|---|---|
| [encyclopedia_factions_all.png](encyclopedia_factions_all.png) | 全部九将，阵营人数与新身份常显 |
| [encyclopedia_factions_last_card.png](encyclopedia_factions_last_card.png) | 末卡诸葛亮完整滚入并真实点击选择 |
| [encyclopedia_factions_shu.png](encyclopedia_factions_shu.png) | 蜀5名，保留关羽与Lv35模拟 |
| [encyclopedia_factions_qun.png](encyclopedia_factions_qun.png) | 群2名，筛选与只读模拟 |
| [encyclopedia_factions_wei.png](encyclopedia_factions_wei.png) | 魏1名典韦，军旗与中文归属 |
| [encyclopedia_factions_wu.png](encyclopedia_factions_wu.png) | 吴1名孙尚香，三字姓名与中文归属 |
| [encyclopedia_factions_enemy.png](encyclopedia_factions_enemy.png) | 敌人图鉴独立，不受武将阵营筛选影响 |
| [encyclopedia_factions_return.png](encyclopedia_factions_return.png) | 返回武将图鉴保留群筛选 |
| [encyclopedia_factions_restored.png](encyclopedia_factions_restored.png) | 恢复全部九将，浏览不写档 |
| [develop_faction_badge.png](develop_faction_badge.png) | 属性军旗与中文阵营，天赋入口 |
| [huang_zhong_develop_skills.png](huang_zhong_develop_skills.png) | 孙尚香养成两被动，姓名在Lv100完整可见 |
| [huang_zhong_develop_ultimate.png](huang_zhong_develop_ultimate.png) | 孙尚香养成滚动至大招，专属人物动作图徽 |
| [huang_zhong_develop_relic.png](huang_zhong_develop_relic.png) | 孙尚香的鹊画弓名称、简述与未开放说明 |
| [huang_zhong_develop_talents.png](huang_zhong_develop_talents.png) | 孙尚香独立三大类天赋分叉树，原节点与效果保持 |
| [huang_zhong_encyclopedia_skills.png](huang_zhong_encyclopedia_skills.png) | 孙尚香百科技能，同源名称、图徽与效果 |
| [huang_zhong_encyclopedia_relic.png](huang_zhong_encyclopedia_relic.png) | 孙尚香百科鹊画弓，可选信物仍为原两件 |
| [zhou_wei_develop_skills.png](zhou_wei_develop_skills.png) | 典韦养成两被动，姓名在Lv100完整可见 |
| [zhou_wei_develop_ultimate.png](zhou_wei_develop_ultimate.png) | 典韦养成滚动至大招，专属人物动作图徽 |
| [zhou_wei_develop_relic.png](zhou_wei_develop_relic.png) | 典韦的双铁戟名称、简述与未开放说明 |
| [zhou_wei_develop_talents.png](zhou_wei_develop_talents.png) | 典韦独立三大类天赋分叉树，原节点与效果保持 |
| [zhou_wei_encyclopedia_skills.png](zhou_wei_encyclopedia_skills.png) | 典韦百科技能，同源名称、图徽与效果 |
| [zhou_wei_encyclopedia_relic.png](zhou_wei_encyclopedia_relic.png) | 典韦百科双铁戟，可选信物仍为原两件 |
| [squad_faction_badges.png](squad_faction_badges.png) | 九将编队卡的新身份和军旗归属 |
| [squad_faction_confirm.png](squad_faction_confirm.png) | 出战确认三将军旗与中文归属 |
| [squad_faction_rule_preview.png](squad_faction_rule_preview.png) | 隔离测试群阵营限制提示、记忆过滤与真实禁选 |

15项功能回归、83项身份专项、293项阵营专项、902项窗口检查与398项包内检查通过。395枚目录、27枚当前技能独立图像、110枚天赋独立图像通过；Windows独立启动、实际Spine DLL加载与PE版本0.9.6.1通过。

首通s03/s05仍使用旧兼容键；新开场对白和破隐提示同步当前人物。孙尚香不计入五虎，黄忠位改未来预留身份，原五虎6%和桃园5%不变。第一章正式关卡默认不限制阵营；编队门禁测试只修改隔离档案与内存规则。

复现：Godot运行`res://tests/FactionPreviewRunner.tscn`并传入`--capture-dir=res://build/verify_0.9.6.1`。Windows包：`build/FengHuoLianYing_v0.9.6.1_Windows.zip`。

[manifest.json](manifest.json)记录用途、尺寸、SHA256及验收结果；[SHA256SUMS.txt](SHA256SUMS.txt)用于核对截图。
