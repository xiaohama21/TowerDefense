extends SceneTree

func _init() -> void:
	var data: Resource = load("res://assets/characters/guan_yu/hero_guan_yu_a-data-res.tres")
	var spine: Object = ClassDB.instantiate("SpineSprite")
	spine.set("skeleton_data_res", data)
	var state: Object = spine.get_animation_state()
	for an in ["Active_A", "Appear", "Attack_A", "Critical", "Death", "Idle", "Move", "Stiff", "Stun", "UI_Death", "X", "XX"]:
		var track: Object = state.set_animation(an, true, 0)
		print("anim ok: ", an, " track=", track != null)
	print("RESULT: ok")
	quit()
