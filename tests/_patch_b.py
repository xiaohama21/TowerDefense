# -*- coding: utf-8 -*-
import io

def patch(path, pairs):
    s = io.open(path, encoding='utf-8').read()
    for old, new in pairs:
        assert old in s, 'MISSING in %s: %s' % (path, old[:70])
        s = s.replace(old, new)
    io.open(path, 'w', encoding='utf-8', newline='').write(s)
    print('OK', path)

# BuildManager: pending_loadout
patch('scripts/BuildManager.gd', [
    ('''var pending_slot: Node = null''',
     '''var pending_slot: Node = null
## 待确认建造的出场配置（等级/转职/星级/信物，v0.13）。
var pending_loadout: Dictionary = {}'''),
    ('''	if pending_slot == slot:
		return

	_set_pending_slot(slot)''',
     '''	if pending_slot == slot:
		return

	var profile := ProfileStore.get_profile()
	pending_loadout = GameFlow.get_battle_loadout(profile, str(selected_character.character_id))
	_set_pending_slot(slot)'''),
    ('''	if tower_manager.build_tower(slot.global_position, selected_character, slot):''',
     '''	if tower_manager.build_tower(slot.global_position, selected_character, slot, pending_loadout):'''),
])

# TowerManager: loadout param
patch('scripts/TowerManager.gd', [
    ('''func build_tower(
	pos: Vector2,
	character_data: CharacterData = null,
	slot: Node = null,
	level: int = 1,
	promotion: PromotionData = null
) -> Tower:
	var cost := character_data.build_cost if character_data != null else tower_cost
	if GameManager.gold < cost:
		return null

	GameManager.gold -= cost
	var tower := tower_scene.instantiate() as Tower
	add_child(tower)
	tower.global_position = pos
	if character_data != null:
		tower.apply_character(character_data, level, promotion)''',
     '''func build_tower(
	pos: Vector2,
	character_data: CharacterData = null,
	slot: Node = null,
	loadout: Dictionary = {}
) -> Tower:
	var cost := character_data.build_cost if character_data != null else tower_cost
	if GameManager.gold < cost:
		return null

	GameManager.gold -= cost
	var tower := tower_scene.instantiate() as Tower
	add_child(tower)
	tower.global_position = pos
	if character_data != null:
		tower.apply_character(character_data, loadout)'''),
])

# Tower: loadout-based apply_character + relic damage bonus
patch('scripts/Tower.gd', [
    ('''func apply_character(character_data: CharacterData, level: int = 1, promotion: PromotionData = null) -> void:
	character_id = character_data.character_id
	display_name = character_data.display_name
	var stats := character_data.compute_stats_at(level, promotion)
	damage = stats.damage
	_base_damage = damage
	range_radius = stats.range
	attack_cooldown = stats.attack_interval
	_min_range = stats.min_range
	bullet_speed = character_data.projectile_speed
	build_cost = character_data.build_cost''',
     '''func apply_character(character_data: CharacterData, loadout: Dictionary = {}) -> void:
	var level: int = int(loadout.get("level", 1))
	var promotion: PromotionData = loadout.get("promotion", null)
	var stars: int = int(loadout.get("stars", 0))
	var relic: RelicData = loadout.get("relic", null)
	character_id = character_data.character_id
	display_name = character_data.display_name
	var stats := character_data.compute_stats_at(level, promotion, stars, relic)
	damage = stats.damage
	_base_damage = damage
	range_radius = stats.range
	attack_cooldown = stats.attack_interval
	_min_range = stats.min_range
	# 信物全伤害加成（finalize_damage 管线使用，v0.13）
	_relic_damage_bonus = relic.damage_bonus if relic != null else 0.0
	bullet_speed = character_data.projectile_speed
	build_cost = character_data.build_cost'''),
    ('''var _trait_id: StringName = StringName()
var _trait_params: Dictionary = {}''',
     '''var _trait_id: StringName = StringName()
var _trait_params: Dictionary = {}
var _relic_damage_bonus: float = 0.0'''),
    ('''func finalize_damage(base: int, target: Enemy) -> int:
	var value := float(base) * damage_buff''',
     '''func finalize_damage(base: int, target: Enemy) -> int:
	var value := float(base) * damage_buff * (1.0 + _relic_damage_bonus)'''),
])
