extends RefCounted

class_name Difficulty

## 难度设定（GDD modules/NUMBERS.md 10.7，v0.14）。

enum { EASY = 0, NORMAL = 1, HARD = 2 }

const NAMES := ["轻松", "标准", "困难"]

## 敌人 HP/伤害倍率。
static func enemy_hp_mult(difficulty: int) -> float:
	return GameBalance.get_balance().enemy_hp_mult[clampi(difficulty, 0, 2)]

static func enemy_damage_mult(difficulty: int) -> float:
	return enemy_hp_mult(difficulty)

## 击杀奖励/经验倍率。
static func reward_mult(difficulty: int) -> float:
	return GameBalance.get_balance().reward_mult[clampi(difficulty, 0, 2)]

## 材料/科技点倍率。
static func material_mult(difficulty: int) -> float:
	return GameBalance.get_balance().material_mult[clampi(difficulty, 0, 2)]

## 难度存档键（v0.14.1）：通关记录按难度分键写入 stage_progress.difficulties。
static func key_name(difficulty: int) -> String:
	return ["easy", "normal", "hard"][clampi(difficulty, 0, 2)]

