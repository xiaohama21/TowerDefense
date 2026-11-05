# 0.9.7原生新档验收

2026-11-05，程序0.9.7.0，Godot4.7.1原生窗口1280×720，20项检查通过。隔离新档初始刘备/关羽Lv1白阶，无调试金币/清怪/通关；自动化只执行合法拖放建造、升阶和开波，战斗按引擎计时，采样时暂停以冻结当前画面。实际首关六波胜利、生命20、元宝30、主公经验80、池314；首通武器与技能书发放、真实升级/购买及重载通过。

| 截图 | 内容 |
|---|---|
| [new_save_start.png](new_save_start.png) | 新档首关起始状态 |
| [new_save_battle.png](new_save_battle.png) | 第三波实际战场采样 |
| [new_save_victory.png](new_save_victory.png) | 真实六波胜利与奖励 |
| [new_save_map.png](new_save_map.png) | 首通后关卡解锁及奖励预告 |
| [new_save_develop.png](new_save_develop.png) | 经验池与技能书升级后养成 |
| [new_save_inventory.png](new_save_inventory.png) | 首通武器及材料 |
| [new_save_shop.png](new_save_shop.png) | 真实扣8元宝购买精铁后商店 |

复现：`Godot --path . res://tests/ProgressionPreviewRunner.tscn`，APPDATA/LOCALAPPDATA指向隔离目录。截图哈希见[manifest.json](manifest.json)，实际结算见[native_result.json](native_result.json)。连续全章与天赋测量分别见[实施报告](../../reviews/PROGRESSION_BALANCE_IMPLEMENTATION_2026-11-05.md)。
