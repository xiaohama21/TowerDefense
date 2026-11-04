# 0.9.6 阵营系统原生窗口验收

2026-11-04，13张1280×720原生Godot截图。程序0.9.6.0 / GDD v0.37.83 / FACTIONS v0.2 / UI_LAYOUT v0.20.85 / ENCYCLOPEDIA v0.1.29 / UI_CONCEPT v0.41 / ICONS v1.7。

四阵营统一军旗＋常显魏/蜀/吴/群文字，蓝/绿/红/紫辅助。筛选附人数，归属在武将卡、详情、养成属性、编队及出战确认行显示；存在限制才显示限用/禁用。百科卡最小64px，末卡可滚动，身份标签折行且九将详情不撑宽大厅。

| 截图 | 验收内容 |
|---|---|
| [encyclopedia_factions_all](encyclopedia_factions_all.png) | 全部九将；军旗与中文归属、人数、默认张飞详情折行 |
| [encyclopedia_factions_last_card](encyclopedia_factions_last_card.png) | 末卡诸葛亮完整滚动可见并实际点击选择 |
| [encyclopedia_factions_shu](encyclopedia_factions_shu.png) | 蜀7名；保留关羽选中及Lv35模拟 |
| [encyclopedia_factions_qun](encyclopedia_factions_qun.png) | 群2名；切首名且重置模拟 |
| [encyclopedia_factions_wei](encyclopedia_factions_wei.png) | 魏0名；明确空态，无旧详情或天赋入口 |
| [encyclopedia_factions_wu](encyclopedia_factions_wu.png) | 吴0名；明确空态，无旧详情或模拟器 |
| [encyclopedia_factions_enemy](encyclopedia_factions_enemy.png) | 敌人图鉴独立，不显示武将阵营筛选 |
| [encyclopedia_factions_return](encyclopedia_factions_return.png) | 返回武将图鉴保留群筛选 |
| [encyclopedia_factions_restored](encyclopedia_factions_restored.png) | 恢复全部9名且浏览不写档 |
| [develop_faction_badge](develop_faction_badge.png) | 养成属性军旗＋中文归属与天赋入口 |
| [squad_faction_badges](squad_faction_badges.png) | 编队九将军旗与中文归属 |
| [squad_faction_confirm](squad_faction_confirm.png) | 确认出战三名武将的军旗与中文归属 |
| [squad_faction_rule_preview](squad_faction_rule_preview.png) | 测试限定群阵营的提示、记忆过滤与真实点击禁选（第一章正式规则不限） |

14项功能回归、294项阵营专项、856项原生窗口检查和388项包内检查通过；393枚目录、110枚独立天赋图像、四旗母版与运行可见像素一致检查通过。Windows独立启动、实际Spine DLL加载及PE版本0.9.6.0通过。

第一章八关、现有武器/信物/军需默认不限；阵营无直接属性加成，原两组羁绊及schema11保持。编队限制测试只在隔离临时档案及内存规则中运行，不修改正式关卡配置。

复现：`Godot --path . res://tests/FactionPreviewRunner.tscn`。完整Windows包：`build/FengHuoLianYing_v0.9.6.0_Windows.zip`。

[manifest.json](manifest.json)记录原图用途、尺寸、SHA256和回归结果；[SHA256SUMS.txt](SHA256SUMS.txt)用于核对原图。
