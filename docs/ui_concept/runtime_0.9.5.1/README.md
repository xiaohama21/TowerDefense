# 0.9.5.1 天赋树弹窗原生窗口验收

2026-11-04，24张1280×720原生Godot截图。程序0.9.5.1 / GDD v0.37.81 / TALENTS v0.2 / UI_LAYOUT v0.20.83 / UI_CONCEPT v0.39 / ICONS v1.5。

属性卡“天赋”按钮打开1160×640弹窗，三类分叉树完整展示30节点；每节点名称/等级常显，点击另开详情查看当前/下级效果、完整机制、门槛与分配条件。节点使用独立图徽，等级描边与标记辅助区分状态。原四页签保留。

隔离临时档案验证30节点实际鼠标点击不写档、详情分配原子保存、保存失败回滚、免费重置确认、分层ESC返回、九将树归属、百科模拟与降级归一化。13项回归通过，389项天赋专项与1553项原生窗口检查通过；110枚专属图标及393枚总目录的透明度、边界、尺寸和独立图像验证通过。360项包内检查、Windows独立启动、实际Spine DLL加载与PE版本0.9.5.1验证通过。

| 截图 |
|---|
| [develop_node_allocated](develop_node_allocated.png) |
| [develop_node_available](develop_node_available.png) |
| [develop_node_locked](develop_node_locked.png) |
| [develop_node_save_failed](develop_node_save_failed.png) |
| [develop_node_ultimate](develop_node_ultimate.png) |
| [develop_reset_confirm](develop_reset_confirm.png) |
| [develop_talent_entry](develop_talent_entry.png) |
| [develop_tree_diao_chan](develop_tree_diao_chan.png) |
| [develop_tree_guan_yu](develop_tree_guan_yu.png) |
| [develop_tree_huang_fu_song](develop_tree_huang_fu_song.png) |
| [develop_tree_huang_zhong](develop_tree_huang_zhong.png) |
| [develop_tree_l1](develop_tree_l1.png) |
| [develop_tree_liu_bei](develop_tree_liu_bei.png) |
| [develop_tree_reset](develop_tree_reset.png) |
| [develop_tree_zhang_fei](develop_tree_zhang_fei.png) |
| [develop_tree_zhao_yun](develop_tree_zhao_yun.png) |
| [develop_tree_zhou_wei](develop_tree_zhou_wei.png) |
| [develop_tree_zhuge_liang](develop_tree_zhuge_liang.png) |
| [encyclopedia_node_locked_ultimate](encyclopedia_node_locked_ultimate.png) |
| [encyclopedia_node_sim](encyclopedia_node_sim.png) |
| [encyclopedia_talent_entry](encyclopedia_talent_entry.png) |
| [encyclopedia_tree_low_level](encyclopedia_tree_low_level.png) |
| [encyclopedia_tree_magic](encyclopedia_tree_magic.png) |
| [encyclopedia_tree_sim](encyclopedia_tree_sim.png) |

复现：`Godot --path . res://tests/TalentPreviewRunner.tscn`。截图名称覆盖属性入口、L1未分配、锁定/可分配/已分配/终极详情、保存失败、重置确认与完成、九将满点树及百科模拟。

[manifest.json](manifest.json)与[SHA256SUMS.txt](SHA256SUMS.txt)提供尺寸、回归结果和原图校验。
