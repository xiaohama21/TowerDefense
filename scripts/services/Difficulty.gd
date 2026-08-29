extends RefCounted

class_name Difficulty

## 难度设定（GDD modules/NUMBERS.md 10.7，v0.14）。

enum { EASY = 0, NORMAL = 1, HARD = 2 }

const NAMES := ["轻松", "标准", "困难"]

## 敌人 HP/伤害倍率。
static func enemy_hp_mult(difficulty: int) -> float:
	return [0.8, 1.0, 1.4][clampi(difficulty, 0, 2)]

static func enemy_damage_mult(difficulty: int) -> float:
	return enemy_hp_mult(difficulty)

## 击杀奖励/经验倍率。
static func reward_mult(difficulty: int) -> float:
	return [0.8, 1.0, 1.6][clampi(difficulty, 0, 2)]

## 材料/科技点倍率。
static func material_mult(difficulty: int) -> float:
	return [0.8, 1.0, 2.0][clampi(difficulty, 0, 2)]
