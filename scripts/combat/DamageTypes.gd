class_name DamageTypes
extends RefCounted

## 伤害类型（NUMBERS 10.12，2026-09-09 拍板 / ✅ 0.8.13.0 落地）：
## 护甲结算的类型分流与显示名唯一来源；塔 / 技能 / 军需 / 图鉴只引用这里，
## 不硬编码类型字符串，也不自行抄护甲公式（公式唯一落点 = Enemy.take_damage）。
##
## 类型系数 f_type 决定「算多少护甲」：物理 1.0 / 魔法 0.5 / 真实 0（无视护甲与全部减伤）。

const PHYSICAL: StringName = &"physical"
const MAGIC: StringName = &"magic"
const TRUE: StringName = &"true"

## 单来源百分比穿甲上限（NUMBERS 10.12：单源 ≤30%）。
const MAX_PENETRATION_RATIO: float = 0.30

const _DISPLAY_NAMES := {
	&"physical": "物理",
	&"magic": "魔法",
	&"true": "真实",
}

const _ARMOR_FACTORS := {
	&"physical": 1.0,
	&"magic": 0.5,
	&"true": 0.0,
}


## 类型系数：armor_eff = max(armor × f_type, 0)（NUMBERS 10.12 第 1 步）。
static func armor_factor(damage_type: StringName) -> float:
	return float(_ARMOR_FACTORS.get(damage_type, 1.0))


## 显示名（物理 / 魔法 / 真实）：伤害描述文案统一经此标注。
static func display_name(damage_type: StringName) -> String:
	return str(_DISPLAY_NAMES.get(damage_type, "物理"))


static func is_valid(damage_type: StringName) -> bool:
	return _ARMOR_FACTORS.has(damage_type)