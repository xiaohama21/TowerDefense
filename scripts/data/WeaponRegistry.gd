extends RefCounted
class_name WeaponRegistry

const MAX_COUNT := 3
const OVERFLOW_SEALS := 2
const IDS := ["equipment_ring_blade_1", "equipment_long_spear_1", "equipment_horn_bow_1", "equipment_silk_bells_1", "equipment_thunder_cart_1", "equipment_ritual_staff_1", "equipment_horse_sword_1", "equipment_mulberry_bow_1", "equipment_bamboo_banner_1", "equipment_bone_mace_1", "equipment_clay_flute_1", "equipment_wood_mortar_1"]
const ICONS := {"physical_attack_flat":"dmg_physical", "magic_attack_flat":"dmg_magic", "crit_rate":"stat_crit_rate", "crit_damage":"stat_crit_damage", "skill_amp":"stat_skill_amp", "range_pct":"stat_range", "range_flat":"stat_range", "splash_pct":"stat_splash", "projectile_flat":"stat_projectile_speed", "magic_damage_pct":"dmg_magic", "armor_pen_pct":"stat_armor_pen", "rage_pct":"stat_rage_gain", "hit_rage_flat":"rage"}
const HINTS := {"physical_attack_flat":"物理基础攻击", "magic_attack_flat":"魔法基础攻击", "crit_rate":"暴击率", "crit_damage":"暴击伤害", "skill_amp":"技能增幅", "range_pct":"射程百分比", "range_flat":"固定射程（px）", "splash_pct":"溅射半径", "projectile_flat":"弹道速度（px/s）", "magic_damage_pct":"魔法伤害", "armor_pen_pct":"独立来源百分比穿甲", "rage_pct":"怒气获取", "hit_rage_flat":"真实普攻命中额外怒气（AOE每发一次）"}
static var _cache: Dictionary = {}

static func get_weapon(id: String) -> WeaponData:
	if not IDS.has(id): return null
	if not _cache.has(id): _cache[id] = load("res://resources/weapons/%s.tres" % id) as WeaponData
	return _cache[id]

static func for_character(character: CharacterData) -> Array[WeaponData]:
	var result: Array[WeaponData] = []
	for id in IDS:
		var weapon := get_weapon(id)
		if weapon != null and weapon.fits(character): result.append(weapon)
	return result

static func bonuses(weapon: WeaponData, character: CharacterData) -> Dictionary:
	return weapon.affixes.duplicate() if weapon != null and weapon.fits(character) else {}

static func normalize_inventory(raw) -> Dictionary:
	var result := {}
	if raw is Dictionary:
		for id in IDS:
			var amount = raw.get(id, 0)
			var count := 0
			if typeof(amount) == TYPE_INT or typeof(amount) == TYPE_FLOAT:
				if is_finite(float(amount)): count = int(clampf(float(amount), 0, MAX_COUNT))
			elif amount is String and amount.is_valid_int(): count = int(clampf(float(amount), 0, MAX_COUNT))
			if count > 0: result[id] = count
	return result

static func normalize_equipped(characters: Dictionary, weapons: Dictionary) -> void:
	var assigned := {}
	var ids := characters.keys()
	ids.sort()
	for id in ids:
		if not characters[id] is Dictionary: continue
		var weapon_id := str(characters[id].get("weapon_id", "")).strip_edges()
		var weapon := get_weapon(weapon_id)
		var path := "res://resources/characters/%s.tres" % id
		var character := load(path) as CharacterData if ResourceLoader.exists(path) else null
		if weapon == null or not weapon.fits(character) or int(assigned.get(weapon_id, 0)) >= int(weapons.get(weapon_id, 0)):
			weapon_id = ""
		else: assigned[weapon_id] = int(assigned.get(weapon_id, 0)) + 1
		characters[id]["weapon_id"] = weapon_id

static func effect_rows(weapon: WeaponData) -> Array:
	var rows := []
	for key in weapon.affixes:
		var value := float(weapon.affixes[key])
		var percent: bool = str(key).ends_with("_pct") or key in ["crit_rate", "crit_damage", "skill_amp"]
		var text := "+" + String.num(value * 100.0 if percent else value, 2).trim_suffix(".00").trim_suffix(".0") + ("%" if percent else "")
		rows.append([str(ICONS.get(key, "")), text, str(HINTS.get(key, ""))])
	return rows

static func acquisition_text(weapon: WeaponData) -> String:
	var path := "res://resources/stages/chapter_01/%s.tres" % weapon.unlock_stage_id
	var stage := load(path) as StageData if ResourceLoader.exists(path) else null
	return "通关「%s」首通必得并上架；重复通关30%%补件，商店%d元宝可购复件。每款最多3件，超额掉落转将印×2。" % [stage.display_name if stage != null else "对应关卡", weapon.shop_price]
