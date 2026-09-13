extends Resource

class_name RelicData

## 信物（GDD modules/CHARACTERS.md 4.8，✅ 0.8.14 双槽重构）：
## **专属信物槽** = 绑定武将（本版锁住占位、不参与计算）；
## **可选信物槽** = Boss 签名信物（通用件，装入谁的可选槽即作用于谁）。
## 维持"固定效果、无词条"口径——效果键固定为伤害 / 术法伤害 / 等级成长 / 射程 / 攻速。

## 槽位取值（GDD 4.8：装配映射 characters[id].relic_exclusive / relic_optional）。
const SLOT_EXCLUSIVE: StringName = &"exclusive"
const SLOT_OPTIONAL: StringName = &"optional"

@export var relic_id: StringName
@export var display_name: String = ""
@export_multiline var description: String = ""
## 槽位：exclusive = 专属槽（绑定武将，本版锁住占位）/ optional = 可选槽（通用件）。
@export var slot: StringName = SLOT_EXCLUSIVE
## 绑定武将（专属槽必填；可选槽留空 = 通用件）。
@export var character_id: StringName
## 获取途径文案（可选槽列表展示；空 = 不显示获取行，如已取消获取的专属占位）。
@export var acquisition_hint: String = ""
## 全伤害加成（0.12 = +12%）。
@export_range(0.0, 1.0, 0.01) var damage_bonus: float = 0.0
## 术法伤害加成（0.12 = +12%；仅魔法类型伤害生效，NUMBERS 10.13 天公雷诏）。
@export_range(0.0, 1.0, 0.01) var magic_damage_bonus: float = 0.0
## 等级成长等效（5 = 装备武将按等级 +5 计算成长项，不写入存档等级；
## 突破 30 级上限、等效上限 35，NUMBERS 10.13 太平要术·残卷）。
@export_range(0, 30, 1) var level_bonus: int = 0
## 射程加成（0.15 = +15%）。
@export_range(0.0, 1.0, 0.01) var range_bonus: float = 0.0
## 攻速倍率（0.9 = 快 10%）。
@export_range(0.1, 2.0, 0.01) var attack_interval_factor: float = 1.0


func is_optional_slot() -> bool:
	return slot == SLOT_OPTIONAL


func is_valid() -> bool:
	if relic_id.is_empty() or display_name.is_empty():
		return false
	# 专属槽必须绑定武将；可选槽（Boss 签名信物）为通用件、不绑武将。
	if not is_optional_slot() and character_id.is_empty():
		return false
	return true


## 效果摘要（养成面板 / 图鉴共用唯一文案源，禁止两处各写一份）。
func effect_lines() -> Array[String]:
	var lines: Array[String] = []
	if damage_bonus > 0.0:
		lines.append("全伤害 +%d%%" % int(round(damage_bonus * 100.0)))
	if magic_damage_bonus > 0.0:
		lines.append("术法伤害 +%d%%（仅魔法类型）" % int(round(magic_damage_bonus * 100.0)))
	if level_bonus != 0:
		lines.append("等级成长等效 +%d 级（等效上限 %d）" % [level_bonus, LevelCurve.max_level() + level_bonus])
	if range_bonus > 0.0:
		lines.append("射程 +%d%%" % int(round(range_bonus * 100.0)))
	if not is_equal_approx(attack_interval_factor, 1.0):
		lines.append("攻速 %s%d%%" % [
			"+" if attack_interval_factor < 1.0 else "-",
			int(abs(round((1.0 - attack_interval_factor) * 100.0))),
		])
	return lines


## 效果摘要单行文案（空效果回退"无"）。
func effect_summary() -> String:
	var lines := effect_lines()
	return "；".join(lines) if not lines.is_empty() else "无"
