extends RefCounted
class_name BattleVisualRegistry

## Render metadata only. Combat timing stays explicit per hero.
const HEROES := {
	"guan_yu": {"data": "res://assets/characters/guan_yu/hero_guan_yu_a-data-res.tres", "scale": .33, "foot": 8.0, "hit": .4, "attack_duration": .733, "ult_hit": .267, "ult_duration": .8},
	"liu_bei": {"data": "res://assets/battle_visuals/liu_bei/liu_bei-data.tres", "scale": .53, "foot": 8.0, "native_facing": -1.0, "hit": .11, "attack_source_hit": .5333, "attack_time_scale": .5333 / .11, "attack_duration": .8667 * .11 / .5333, "ult_hit": 0.0, "ult_duration": .55, "ultimate": "Appear", "ult_time_scale": 1.4667 / .55, "critical": "Critical", "critical_start": .3, "critical_time_scale": (1.3667 - .3) / .33},
	"diao_chan": {"skin": "default", "data": "res://assets/battle_visuals/diao_chan/diao_chan-data.tres", "scale": .50, "foot": 8.0, "native_facing": -1.0, "hit": .11, "attack_start": .3333, "attack_source_hit": .3333, "attack_duration": .6667, "ult_hit": 0.0, "ult_duration": .7, "ultimate": "Active_A", "ult_time_scale": 1.2333 / .7, "critical": "Critical", "critical_start": .3333, "critical_time_scale": .6667 / .33},
	"zhao_yun": {"skin": "default", "root_motion_bone": "Character", "root_motion_scale": .08, "data": "res://assets/battle_visuals/zhao_yun/zhao_yun-data.tres", "scale": .46, "foot": 8.0, "native_facing": -1.0, "hit": .11, "attack_source_hit": .6333, "attack_time_scale": .6333 / .11, "attack_duration": .9333 * .11 / .6333, "ult_hit": 0.0, "ult_duration": .6, "ultimate": "Active_A", "ult_time_scale": 1.3333 / .6, "critical": "Critical", "critical_start": .4667, "critical_time_scale": .5333 / .33},
	"zhuge_liang": {"skin": "default", "data": "res://assets/battle_visuals/zhuge_liang/zhuge_liang-data.tres", "scale": .47, "foot": 8.0, "native_facing": -1.0, "hit": .11, "attack_start": .4333, "attack_source_hit": .4333, "attack_duration": .3334, "ult_hit": 0.0, "ult_duration": .65, "ultimate": "Appear", "ult_time_scale": 1.3333 / .65, "critical": "Critical", "critical_start": .4667, "critical_time_scale": .5333 / .33},
}
const ENEMIES := {
	"yellow_turban_soldier": {"scale": .28, "foot": 16.0, "top": 136.0, "width": 95.0},
	"yellow_turban_cavalry": {"scale": .30, "foot": 20.0, "top": 170.0, "width": 177.0},
	"yellow_turban_sergeant": {"scale": .33, "foot": 18.0, "top": 143.0, "width": 126.0},
	"yellow_turban_general": {"scale": .43, "foot": 24.0, "top": 145.0, "width": 144.0},
}
const PORTRAITS := {
	"guan_yu": "res://assets/battle_visuals/portraits/guan_yu.png",
	"liu_bei": "res://assets/battle_visuals/liu_bei/avatar.png",
	"diao_chan": "res://assets/battle_visuals/diao_chan/avatar.png",
	"zhao_yun": "res://assets/battle_visuals/zhao_yun/avatar.png",
	"zhuge_liang": "res://assets/battle_visuals/zhuge_liang/avatar.png",
}

static func hero(id: String) -> Dictionary:
	return HEROES.get(id, {}).duplicate()

static func enemy(id: String) -> Dictionary:
	var spec: Dictionary = ENEMIES.get(id, {}).duplicate()
	if not spec.is_empty(): spec["data"] = "res://assets/battle_visuals/%s/%s-data.tres" % [id, id]
	if not spec.is_empty(): spec["native_facing"] = 1.0
	return spec

static func create_actor(spec: Dictionary) -> Node2D:
	if spec.is_empty() or not ClassDB.class_exists("SpineSprite"): return null
	var path := str(spec.get("data", ""))
	if path.is_empty() or not ResourceLoader.exists(path): return null
	var data: Resource = load(path)
	if data == null: return null
	var actor := ClassDB.instantiate("SpineSprite") as Node2D
	actor.set("skeleton_data_res", data)
	if spec.has("skin"):
		actor.get_skeleton().set_skin_by_name(str(spec.skin))
	actor.position.y = float(spec.foot)
	actor.scale = Vector2.ONE * float(spec.scale)
	if spec.has("root_motion_bone"):
		actor.connect("before_world_transforms_change", _limit_root_motion.bind(spec))
	return actor

static func _limit_root_motion(actor: Node2D, spec: Dictionary) -> void:
	var bone: Object = actor.get_skeleton().find_bone(str(spec.root_motion_bone))
	if bone == null: return
	var pose: Object = bone.get_pose()
	var setup: Object = bone.get_data().get_setup_pose()
	var factor := float(spec.get("root_motion_scale", 1.0))
	pose.set_x(float(setup.get_x()) + (float(pose.get_x()) - float(setup.get_x())) * factor)
	pose.set_y(float(setup.get_y()) + (float(pose.get_y()) - float(setup.get_y())) * factor)
