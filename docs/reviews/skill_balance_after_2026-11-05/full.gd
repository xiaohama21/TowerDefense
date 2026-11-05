extends "res://docs/reviews/skill_balance_after_2026-11-05/driver.gd"

func _run() -> void:
	ProfileStore.create_new_profile(false)
	GameFlow.squad_character_ids=[]
	GameFlow.clear_squad_relics()
	GameManager.reset(999999,20,1)
	_build_environment()
	var amplifiers: Dictionary={}
	for id in GameFlow.get_all_character_ids():
		var character:=GameFlow.load_character_data(id)
		var options: Array=[]
		var trees:=TalentRegistry.tree_ids(id)
		for first in range(3):
			for second in range(first+1,3):
				var alloc:Dictionary={}
				for tree_index in [first,second]:
					for node in TalentRegistry.get_tree_data(trees[tree_index]).nodes: alloc[str(node.id)]=2
				for weapon in WeaponRegistry.for_character(character):
					var levels:Dictionary={}
					for skill in character.get_skill_ids(): levels[str(skill)]=10
					var stats:=character.compute_stats_at(100,5,null,0,{},levels,weapon,alloc)
					options.append({"trees":[trees[first],trees[second]],"weapon":str(weapon.item_id),"attack":stats.damage,"crit_rate":stats.crit_rate,"crit_damage":stats.crit_damage,"skill_amp":stats.skill_amp,"ultimate_amp":float(stats.talents.get("ultimate_amp",0)),"talents":stats.talents})
					if id not in ["liu_bei","diao_chan"]:
						await _measure(id,{"level":100,"rank":5,"skill_level":10,"weapon":str(weapon.item_id),"talent_alloc":alloc},1,20)
		amplifiers[id]=options
	var file:=FileAccess.open("res://docs/reviews/skill_balance_after_full_2026-11-05.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"measurements":audit_results,"options":amplifiers},"\t"))
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(_profile_file+suffix): DirAccess.remove_absolute(ProjectSettings.globalize_path(_profile_file+suffix))
	print("AUDIT_FULL_COMPLETE rows=%d"%audit_results.size())
	get_tree().quit()
