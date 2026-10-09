extends RefCounted

class_name Difficulty

## 难度设定（GDD modules/NUMBERS.md 10.7，v0.14；v0.31.2 起数据驱动）。
## 档位定义收敛到 BalanceData.difficulty_presets（resources/balance/game_balance.tres），
## 追加一项即扩展新难度；解锁规则见 GameFlow.is_difficulty_unlocked
## （首档恒解锁、后续档需通关上一档）。

enum { NORMAL = 0, HARD = 1 }

static func _presets() -> Array:
	return GameBalance.get_balance().difficulty_presets


static func count() -> int:
	return _presets().size()


static func _preset(difficulty: int) -> Dictionary:
	var presets := _presets()
	if presets.is_empty():
		return {}
	return presets[clampi(difficulty, 0, presets.size() - 1)]


## 难度显示名（档位缺失时回退"标准"）。
static func name(difficulty: int) -> String:
	return str(_preset(difficulty).get("name", "标准"))


## 难度存档键（v0.14.1）：通关记录按难度分键写入 stage_progress.difficulties。
static func key_name(difficulty: int) -> String:
	return str(_preset(difficulty).get("key", "normal"))


## 敌人 HP/伤害倍率。
static func enemy_hp_mult(difficulty: int) -> float:
	return float(_preset(difficulty).get("enemy_hp_mult", 1.0))


## 击杀奖励/经验倍率。
static func reward_mult(difficulty: int) -> float:
	return float(_preset(difficulty).get("reward_mult", 1.0))


## 军功倍率（✅ 0.8.16 / NUMBERS 10.15）：困难 ×1.5，与击杀经验 reward_mult ×1.6 分账。
static func merit_mult(difficulty: int) -> float:
	return float(_preset(difficulty).get("merit_mult", 1.0))


## 材料/科技点倍率。
static func material_mult(difficulty: int) -> float:
	return float(_preset(difficulty).get("material_mult", 1.0))


## 机制行为间隔倍率（✅ 0.8.13.5 / NUMBERS 10.23）：<1 = 机制兵施放更快
## （困难 ×0.85：召唤 / 治疗 / 甲光环 / 术法压制更频繁）。缺省 1.0 = 不缩放。
static func mechanic_interval_mult(difficulty: int) -> float:
	return float(_preset(difficulty).get("mechanic_interval_mult", 1.0))


## 机制行为效果倍率（✅ 0.8.13.5 / NUMBERS 10.23）：治疗量 / 甲光环加成 / 术法压制幅度
## （困难 ×1.25）。半径不随该倍率变化——空间覆盖保持可预期；缺省 1.0 = 不缩放。
static func mechanic_effect_mult(difficulty: int) -> float:
	return float(_preset(difficulty).get("mechanic_effect_mult", 1.0))