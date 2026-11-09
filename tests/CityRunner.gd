extends Node

var checks := 0
var failures: Array[String] = []
var hub: Control

func _ready() -> void:
	ProfileStore.configure_paths("user://.city_runner.json")
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		printerr("FAIL: "+message)

func run() -> void:
	check(GameFlow.start_new_game(),"create isolated fresh save")
	var profile := ProfileStore.get_profile()
	check(PlayerProfile.CURRENT_SCHEMA_VERSION==13 and not profile.city_state.legacy_access,"fresh schema13, progress gating")
	var count := 0
	for data in CityRegistry.all():
		if data.building:
			count+=1
			for style in ["day","dusk"]: check(ResourceLoader.exists("res://assets/city/%s/%s.svg" % [style,data.entry_id]),"building asset "+str(data.entry_id))
	check(count==9,"nine real building entry points")
	for id in [&"map",&"command",&"encyclopedia"]: check(CityRegistry.is_open(profile,id),"initial entry "+str(id))
	for id in [&"develop",&"inventory",&"shop",&"tech",&"supply",&"tavern",&"stable"]: check(not CityRegistry.is_open(profile,id),"fresh locked "+str(id))
	var failed := BattleSession.new(&"ch01_s01")
	failed.mark_defeat()
	check(not profile.apply_battle_session(failed) and not CityRegistry.is_open(profile,&"develop"),"defeat cannot unlock city entries")
	var won := BattleSession.new(&"ch01_s01")
	won.mark_victory({"difficulty":"normal"})
	check(ProfileStore.commit_victory(won),"real victory commit")
	for id in [&"develop",&"inventory"]: check(CityRegistry.is_open(profile,id),"first victory unlock "+str(id))
	for stage in range(2,6):
		profile.mark_stage_completed("ch01_s%02d" % stage,{"difficulty":"normal"})
		if stage==2: check(CityRegistry.is_open(profile,&"shop"),"market opens at s02")
		if stage==4: check(CityRegistry.is_open(profile,&"supply"),"supply opens at s04")
		if stage==5: check(CityRegistry.is_open(profile,&"tech"),"tech opens at s05")
	var old := profile.to_dict()
	old.schema_version=12;old.erase("city_state")
	old["stage_progress"]={}
	var migrated: Dictionary = ProfileStore._migrate_to_current(old)
	check(migrated.ok and migrated.data.city_state.legacy_access,"v12 migration retains old entry access")
	check(ProfileStore._migrate_to_current(migrated.data).data==migrated.data,"migration idempotent")
	for key in old:
		if key!="schema_version": check(migrated.data[key]==old[key],"migration preserves "+key)
	var legacy := PlayerProfile.from_dict(migrated.data)
	for data in CityRegistry.all(): check(CityRegistry.is_open(legacy,data.entry_id)==data.implemented,"legacy access "+str(data.entry_id))
	await check_disk_compatibility(old)
	var normalized := CityRegistry.normalize_state({"legacy_access":"yes","visited":["map","map","tavern","unknown",42]})
	check(not normalized.legacy_access and normalized.visited==["map"],"invalid and planned visits normalized")
	check(ProfileStore.save_profile(profile),"persist progress fixture")
	var before := profile.to_dict()
	ProfileStore._writes_blocked=true
	check(not ProfileStore.mark_city_visited(&"map"),"visit refused on blocked write")
	check(profile.to_dict()==before,"failed visit write leaves live state untouched")
	ProfileStore._writes_blocked=false
	check(not ProfileStore.mark_city_visited(&"tavern"),"construction cannot mark visited")
	check(ProfileStore.mark_city_visited(&"map") and not CityRegistry.is_new(profile,&"map"),"visit clears red dot")
	ProfileStore.profile=null;profile=ProfileStore.load_profile()
	check(profile.city_state.visited.has("map"),"visit survives reload")
	GameFlow.hub_active_panel=&"city"
	hub=load("res://scenes/GameHub.tscn").instantiate()
	add_child(hub)
	for i in range(3): await get_tree().process_frame
	check(not hub._hub_panel.visible and hub._buttons.size()==9,"default full city, no sidebar")
	for data in CityRegistry.all():
		if not data.building: continue
		var button: Control=hub._buttons[data.entry_id]
		check(Rect2(Vector2.ZERO,Vector2(1280,720)).encloses(button.get_rect()),"building bounds "+str(data.entry_id))
		for other in CityRegistry.all():
			if other.building and str(other.entry_id)>str(data.entry_id): check(not button.get_rect().intersects(hub._buttons[other.entry_id].get_rect()),"building hit regions separate %s/%s" % [data.entry_id,other.entry_id])
	for id in [&"tavern",&"stable"]:
		hub._buttons[id].pressed.emit()
		check(not hub._hub_panel.visible and hub._hint.text.contains("未开放"),"construction explains without navigation")
	hub._buttons[&"encyclopedia"].pressed.emit()
	check(hub._panels[&"encyclopedia"].visible and is_instance_valid(hub._intro),"building routes to real panel with first explanation")
	ProfileStore._writes_blocked=true
	hub._close_intro()
	check(is_instance_valid(hub._intro) and CityRegistry.is_new(profile,&"encyclopedia"),"failed intro save stays retryable")
	ProfileStore._writes_blocked=false
	hub._close_intro()
	check(not is_instance_valid(hub._intro) and not CityRegistry.is_new(profile,&"encyclopedia"),"skip/close persists explanation once")
	for id in [&"map",&"command",&"develop",&"tech",&"inventory",&"shop",&"supply",&"settings",&"encyclopedia"]:
		hub._show_panel(id,false)
		for i in range(3): await get_tree().process_frame
		check(hub._panels[id].visible and hub._hub_panel.visible,"real panel "+str(id))
		hub._show_panel(&"city")
		check(not hub._hub_panel.visible,"back to city from "+str(id))
	var escape:=InputEventKey.new();escape.keycode=KEY_ESCAPE;escape.pressed=true
	hub._unhandled_key_input(escape)
	check(hub._system_menu.visible,"escape opens city menu")
	hub._unhandled_key_input(escape)
	check(not hub._system_menu.visible,"escape closes menu")
	hub._show_panel(&"map",false);hub._unhandled_key_input(escape)
	check(not hub._hub_panel.visible,"escape closes functional page")
	hub.queue_free();await get_tree().process_frame
	# Keep the runner alive while exercising the actual scene navigation methods.
	get_tree().current_scene=null
	GameFlow.goto_hub()
	for i in range(4): await get_tree().process_frame
	check(GameFlow.hub_active_panel==&"city" and not get_tree().current_scene._hub_panel.visible,"return/continue routes to city")
	GameFlow.goto_stage_select()
	for i in range(4): await get_tree().process_frame
	check(get_tree().current_scene._panels[&"map"].visible,"squad back routes to map")
	get_tree().current_scene.queue_free();await get_tree().process_frame
	print("CITY_RESULT: %s checks=%d failures=%d" % ["PASS" if failures.is_empty() else "FAIL",checks,failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)

func check_disk_compatibility(old: Dictionary) -> void:
	var manager := SaveManager.new()
	add_child(manager)
	manager.configure_paths("user://.city_migration_disk.json")
	var file := FileAccess.open(manager.save_path,FileAccess.WRITE)
	file.store_string(JSON.stringify(old));file.close()
	var migrated := manager.load_profile()
	check(migrated.city_state.legacy_access,"disk migration grants previous access")
	var saved: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(manager.save_path))
	check(saved.schema_version==13 and saved.city_state.legacy_access,"disk migration writes schema13")
	manager.profile=null
	check(manager.load_profile().to_dict()==migrated.to_dict(),"disk migration reload is idempotent")
	manager.configure_paths("user://.city_future_disk.json")
	var future := old.duplicate(true)
	future.schema_version=PlayerProfile.CURRENT_SCHEMA_VERSION+1
	file=FileAccess.open(manager.save_path,FileAccess.WRITE)
	file.store_string(JSON.stringify(future));file.close()
	var bytes := FileAccess.get_file_as_bytes(manager.save_path)
	manager.profile=null
	manager.load_profile()
	check(manager.is_write_blocked(),"future profile remains read-only")
	check(not manager.mark_city_visited(&"map"),"future profile rejects first-visit write")
	check(FileAccess.get_file_as_bytes(manager.save_path)==bytes,"future profile preserved byte-for-byte")
	manager.queue_free()
	await get_tree().process_frame
