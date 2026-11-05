extends Node2D

const SPECS = preload("res://tools/capture_liu_variants.gd").VARIANTS
const POSES := ["Idle","Attack_A","Critical","Active_A","XX","Move","Stun","Death"]
const LABELS := ["待机","普攻","暴击","光环","大招","移动","受控","倒地"]
var actors:Array[Node2D]=[]
var selected := "Idle"
var elapsed := 0.0
var speed := 1.0
var paused := false
var facing := 1
var live_pose := ""
var duration := 1.3

func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("182b27"))
	var layer:=CanvasLayer.new();add_child(layer)
	var title:=Label.new();title.text="刘备双版本 · 原生模型对照";title.position=Vector2(26,16);title.add_theme_font_size_override("font_size",26);layer.add_child(title)
	var bar:=HBoxContainer.new();bar.position=Vector2(26,64);bar.add_theme_constant_override("separation",10);layer.add_child(bar)
	var choices:=OptionButton.new()
	for label in LABELS:choices.add_item(label)
	choices.item_selected.connect(func(index:int):selected=POSES[index];restart())
	bar.add_child(choices)
	var slow:=CheckButton.new();slow.text="慢放 0.5×";slow.toggled.connect(func(on:bool):speed=.5 if on else 1.0);bar.add_child(slow)
	var pause:=CheckButton.new();pause.text="暂停";pause.toggled.connect(func(on:bool):paused=on);bar.add_child(pause)
	var flip:=Button.new();flip.text="换方向";flip.pressed.connect(func():facing=-facing;apply_facing());bar.add_child(flip)
	for i in range(2):
		var id:String="a_158" if i==0 else "b_original";var spec:Dictionary=SPECS[id]
		var actor:Node2D=ClassDB.instantiate("SpineSprite");actor.set("skeleton_data_res",load(spec.data));add_child(actor)
		actor.set("update_mode",2);actor.position=Vector2(285+640*i,570);actors.append(actor)
		var label:=Label.new();label.text="A · 158 底模改造" if i==0 else "B · 原创分层重画";label.position=Vector2(75+640*i,125);label.add_theme_font_size_override("font_size",23);layer.add_child(label)
	var tip:=Label.new();tip.text="同等游戏比例放大 4 倍。普攻命中 0.110 s；暴击在实际命中后切入；大招辅助即时生效。";tip.position=Vector2(26,672);layer.add_child(tip)
	apply_facing();restart()

func apply_facing() -> void:
	for i in range(actors.size()):
		var spec:Dictionary=SPECS["a_158" if i==0 else "b_original"]
		actors[i].scale=Vector2(facing*float(spec.facing),1)*float(spec.scale)*4

func restart() -> void:
	elapsed=0;live_pose=""
	duration=float({"Attack_A":.33,"Critical":.44,"Active_A":.4,"XX":.55,"Death":.84}.get(selected,1.3))
	apply_pose()

func apply_pose() -> void:
	var pose:=selected
	if selected=="Critical" and elapsed<.11:pose="Attack_A"
	if elapsed>duration:pose="Idle"
	for actor in actors:
		var state:Object=actor.get_animation_state()
		if live_pose!=pose:
			state.clear_tracks();actor.get_skeleton().set_to_setup_pose()
			state.set_animation(pose,false,0).set_mix_duration(0)
		var track:Object=state.get_track(0);track.set_track_time(elapsed if pose==selected or selected=="Critical" and pose=="Attack_A" else 0)
		actor.update_skeleton(0)
	live_pose=pose

func _process(delta:float) -> void:
	if actors.is_empty() or paused:return
	elapsed+=delta*speed
	if elapsed>duration+.6:elapsed=0;live_pose=""
	apply_pose()
