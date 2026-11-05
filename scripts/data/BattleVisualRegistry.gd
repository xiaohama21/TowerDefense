extends RefCounted
class_name BattleVisualRegistry

## Render metadata only. Combat timing stays explicit per hero.
const HEROES := {
	"guan_yu": {"data": "res://assets/characters/guan_yu/hero_guan_yu_a-data-res.tres", "scale": .33, "foot": 8.0, "hit": .4, "attack_duration": .733, "ult_hit": .267, "ult_duration": .8},
	"liu_bei": {"data": "res://assets/battle_visuals/liu_bei/liu_bei-data.tres", "scale": .34, "foot": 8.0, "native_facing": 1.0, "hit": .11, "attack_duration": .33, "ult_hit": 0.0, "ult_duration": .55},
}
const ENEMIES := {
	"yellow_turban_soldier": {"scale": .28, "foot": 16.0, "top": 136.0, "width": 95.0},
	"yellow_turban_cavalry": {"scale": .30, "foot": 20.0, "top": 170.0, "width": 177.0},
	"yellow_turban_sergeant": {"scale": .33, "foot": 18.0, "top": 143.0, "width": 126.0},
	"yellow_turban_general": {"scale": .43, "foot": 24.0, "top": 145.0, "width": 144.0},
}
const PORTRAITS := {
	"guan_yu": "res://assets/characters/guan_yu/hero_guan_yu_a_avatar.png",
	"liu_bei": "res://assets/battle_visuals/liu_bei/avatar.png",
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
	actor.position.y = float(spec.foot)
	actor.scale = Vector2.ONE * float(spec.scale)
	return actor
