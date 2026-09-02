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
## 难度档位预设（v0.31.2 数据驱动，轻松已移除）：首档恒解锁，后续档需通关上一档解锁
## （GameFlow.is_difficulty_unlocked）。拓展新难度 = 在此追加一项（key/name/三倍率），无需改代码。
@export var difficulty_presets: Array[Dictionary] = [
	{"key": "normal", "name": "标准", "enemy_hp_mult": 1.0, "reward_mult": 1.0, "material_mult": 1.0},
	{"key": "hard", "name": "困难", "enemy_hp_mult": 1.4, "reward_mult": 1.6, "material_mult": 2.0},
]

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
	if max_level <= 0 or difficulty_presets.size() < 2:
		return false
	for preset in difficulty_presets:
		if not preset is Dictionary:
			return false
		for key in ["key", "name", "enemy_hp_mult", "reward_mult", "material_mult"]:
			if not preset.has(key):
				return false
	return true