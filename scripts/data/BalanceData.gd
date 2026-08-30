extends Resource

class_name BalanceData

## 全局平衡数值（GDD 阶段 6 · 提交 2，v0.18.0 数值配置中心化）：
## 唯一配置 `resources/balance/game_balance.tres`，代码经 GameBalance 只读引用。
## 修改数值只改配置，不改代码（同步更新 docs/modules/NUMBERS.md）。

@export_category("Level Curve (NUMBERS.md 10.1)")
@export_range(1, 9999, 1) var exp_base_per_level: int = 40
@export_range(1, 9999, 1) var exp_growth_per_level: int = 15
@export_range(1, 999, 1) var max_level: int = 30

@export_category("Difficulty (NUMBERS.md 10.7)")
## 三档倍率（轻松/标准/困难）。
@export var enemy_hp_mult: Array[float] = [0.8, 1.0, 1.4]
@export var reward_mult: Array[float] = [0.8, 1.0, 1.6]
@export var material_mult: Array[float] = [0.8, 1.0, 2.0]

@export_category("Battle (NUMBERS.md 10.3/10.5)")
## 局内塔升级伤害步进（+25%/级，STAGES.md 5.4）。
@export_range(0.0, 2.0, 0.01) var upgrade_damage_step: float = 0.25
## 大招局内倍率步进（10.5：与普攻升级同步）。
@export_range(0.0, 2.0, 0.01) var ultimate_battle_step: float = 0.25
## 怒气上限（CHARACTERS.md 4.6）。
@export_range(1.0, 500.0, 1.0) var max_rage: float = 100.0
## 输出职业默认积怒（命中 +N、每 10 点伤害 +1；职业配置可覆盖，10.5）。
@export_range(0, 999, 1) var rage_gain_per_hit: int = 4
@export_range(0.0, 10.0, 0.1) var rage_gain_per_damage: float = 0.1

@export_category("Enemy Special Behaviors (BEHAVIORS.md B.3.2)")
@export_range(0.0, 60.0, 0.1) var healer_interval: float = 2.0
@export_range(0, 9999, 1) var healer_amount: int = 15
@export_range(0.0, 9999.0, 1.0) var healer_radius: float = 120.0
@export_range(0.0, 120.0, 0.1) var summon_interval: float = 8.0
@export_range(1, 99, 1) var summon_count: int = 2


func is_valid() -> bool:
	return max_level > 0 and enemy_hp_mult.size() == 3 and reward_mult.size() == 3 and material_mult.size() == 3