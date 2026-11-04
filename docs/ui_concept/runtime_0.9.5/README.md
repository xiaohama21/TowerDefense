# 0.9.5 天赋系统原生窗口验收

2026-11-04，20张1280×720原生Godot窗口截图。程序0.9.5.0 / GDD v0.37.80 / TALENTS v0.1 / UI_LAYOUT v0.20.82 / UI_CONCEPT v0.38。

TalentPreviewRunner使用独立临时档案，结束后清理；百科天赋仅在模拟器内分配，不写入玩家档案。截图采用最终三列等宽树、16/14px外边距、12px列距、8px层距/节点距、12px树内边距，节点中文名称、等级、效果与动作常显。同层同位节点保持等高，终极卡对齐。

| 截图 | 验收内容 |
|---|---|
| [develop_talent_l1](develop_talent_l1.png) | L1无点，三树及点数不足状态完整 |
| [develop_talent_l5](develop_talent_l5.png) | L5获得2点，第一层可分配 |
| [develop_talent_allocated](develop_talent_allocated.png) | 实际分配后节点等级与余额更新 |
| [develop_talent_save_failed](develop_talent_save_failed.png) | 保存受阻时点数与节点不变，错误提示可读 |
| [develop_talent_reset_confirm](develop_talent_reset_confirm.png) | 免费重置二次确认，武将与返还点数正确 |
| [develop_talent_reset_done](develop_talent_reset_done.png) | 重置后节点清空、点数返还 |
| [develop_talent_guan_yu](develop_talent_guan_yu.png) | 关羽：破军 / 破防 / 怒气 |
| [develop_talent_zhang_fei](develop_talent_zhang_fei.png) | 张飞：镇军 / 控场 / 鼓舞 |
| [develop_talent_liu_bei](develop_talent_liu_bei.png) | 刘备：同袍 / 鼓舞 / 筹谋 |
| [develop_talent_huang_zhong](develop_talent_huang_zhong.png) | 黄忠：破军 / 破防 / 控场 |
| [develop_talent_diao_chan](develop_talent_diao_chan.png) | 貂蝉：同袍 / 鼓舞 / 怒气 |
| [develop_talent_huang_fu_song](develop_talent_huang_fu_song.png) | 皇甫嵩：火阵 / 破防 / 筹谋 |
| [develop_talent_zhao_yun](develop_talent_zhao_yun.png) | 赵云：破军 / 怒气 / 破防 |
| [develop_talent_zhou_wei](develop_talent_zhou_wei.png) | 周仓：破军 / 破防 / 控场 |
| [develop_talent_zhuge_liang](develop_talent_zhuge_liang.png) | 诸葛亮：天火 / 鼓舞 / 控场 |
| [develop_talent_ultimate](develop_talent_ultimate.png) | 养成滚动末层，终极卡名称、效果与动作完整对齐 |
| [encyclopedia_talent_sim](encyclopedia_talent_sim.png) | 百科独立模拟分配，属性同步且不写档 |
| [encyclopedia_talent_ultimate](encyclopedia_talent_ultimate.png) | 百科末层三张终极卡完整可达 |
| [encyclopedia_talent_scroll_kept](encyclopedia_talent_scroll_kept.png) | 同武将重新分配保留滚动位置 |
| [encyclopedia_talent_magic](encyclopedia_talent_magic.png) | 魔法定位武将三树与中文长描述 |

13项回归全部通过：TalentRunner、Stage0Runner、PackVerify、SmokeRunner、FlowRunner、ExitFlowRunner、RankRunner、DevelopRefreshRunner、SupplyStateRunner、ShopRunner、SkillKitRunner、GearRunner、ItemUiRunner。

天赋专项271项、布局750项、包内249项检查通过；11棵树/110节点、schema11迁移与失败回滚、真实塔loadout、免费重置、百科模拟和首波验证完整。Windows独立EXE启动、实际Spine DLL加载及PE版本0.9.5.0通过。BUGS v0.77 B-145~B-148已登记。

复现：`Godot --path . res://tests/TalentPreviewRunner.tscn`。完整Windows包：`build/FengHuoLianYing_v0.9.5.0_Windows.zip`。

[manifest.json](manifest.json)记录截图用途、尺寸、SHA256和回归结果；[SHA256SUMS.txt](SHA256SUMS.txt)用于核对原图。
