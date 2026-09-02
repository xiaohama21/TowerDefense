extends Node2D

signal tower_created(tower: Tower)

@export var tower_cost: int = 50

var tower_scene = preload("res://scenes/Tower.tscn")


## Build a tower for the given character. Character data drives both the cost
## and the tower's combat stats; level/promotion 来自养成存档。Returns the
## created tower (null on failure).
func build_tower(
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
		tower.apply_character(character_data, loadout)
	tower.record_build_investment(cost)
	tower.assigned_slot = slot
	tower_created.emit(tower)
	# 常驻光环伤害桶（提交 7）：建塔后立即刷新全员，避免等 0.25s 兜底扫描。
	_refresh_aura_all()
	return tower


## 局内升阶（GDD 5.4/阶段 8）：按职业步进提升伤害/攻速/射程/范围；局内临时状态。
func upgrade_tower(tower: Tower, stage_data: StageData) -> bool:
	if tower == null or stage_data == null:
		return false
	if tower.battle_rank >= stage_data.max_inbattle_upgrade_level:
		return false
	# 科技树将略分支（阶段 8 提交 3）：升阶费用折扣。
	var tech_bonuses := TechTree.get_tech_bonuses(ProfileStore.get_profile())
	var discount := float(tech_bonuses.get("upgrade_discount_pct", 0)) / 100.0
	var cost := maxi(ceili(tower.get_upgrade_cost(stage_data.upgrade_cost_factor) * (1.0 - discount)), 1)
	if GameManager.gold < cost:
		return false
	GameManager.gold -= cost
	tower.apply_battle_rank(cost)
	return true


## 回收（GDD 5.4）：返还总投入 × 比例，建造槽立即可复用，局内等级与怒气丢弃。
func sell_tower(tower: Tower, stage_data: StageData) -> bool:
	if tower == null:
		return false
	# 科技树将略分支（阶段 8 提交 3）：回收返还加成。
	var tech_bonuses := TechTree.get_tech_bonuses(ProfileStore.get_profile())
	var bonus := float(tech_bonuses.get("sell_refund_pct", 0)) / 100.0
	GameManager.gold += ceili(tower.get_sell_refund(stage_data.sell_refund_ratio) * (1.0 + bonus))
	if is_instance_valid(tower.assigned_slot) and tower.assigned_slot.has_method("reset_slot"):
		tower.assigned_slot.reset_slot()
	tower.assigned_slot = null
	tower.queue_free()
	# 常驻光环伤害桶（提交 7）：拆塔后立即刷新全员（光环成员变化即时生效）。
	_refresh_aura_all()
	return true


## 常驻光环伤害桶全员刷新（提交 7，STATS_PIPELINE 增益档次 1）：遍历本管理器持有的塔，
## 各自重算仁德/军旗加算汇总；Tower._process 另有 0.25s 低频兜底扫描兜底。
func _refresh_aura_all() -> void:
	for child in get_children():
		var tower := child as Tower
		if tower != null and is_instance_valid(tower) and not tower.is_queued_for_deletion():
			tower.refresh_aura_damage_bonus()
