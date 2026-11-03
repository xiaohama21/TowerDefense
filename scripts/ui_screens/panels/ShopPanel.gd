extends VBoxContainer

var _page := 0
var _message := ""
var _scroll: ScrollContainer

func _ready() -> void:
	add_theme_constant_override("separation", 8)
	_refresh()

func _on_shown() -> void:
	_refresh()

func _label(text: String, pixels: int = 14, color: Color = UITheme.LIGHT_BODY, wrap: bool = false) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", pixels)
	label.add_theme_color_override("font_color", color)
	if wrap:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return label

func _refresh() -> void:
	var old_scroll := _scroll.scroll_vertical if is_instance_valid(_scroll) else 0
	for child in get_children():
		remove_child(child)
		child.queue_free()
	var profile := ProfileStore.get_profile()
	var progress := ShopRegistry.lord_progress(profile.lord_exp)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	add_child(top)
	var title := _label("商店", 27, UITheme.LIGHT_INK)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	top.add_child(ConceptIcon.new("lord_level", 28, "主公等级：只解锁商店货档"))
	var level := _label("Lv.%d" % int(progress.level), 18, UITheme.LIGHT_INK)
	level.name = "LordLevel"
	top.add_child(level)
	top.add_child(ConceptIcon.new("ingot", 28, "元宝：通关固定获得"))
	var ingots := _label(str(profile.ingots), 18, UITheme.LIGHT_GOLD_TEXT)
	ingots.name = "IngotBalance"
	top.add_child(ingots)
	top.add_child(ConceptIcon.new("merit", 28, "军功：胜利带出，用于兑换永久遗物"))
	top.add_child(_label(str(profile.military_merit), 18, UITheme.LIGHT_INK))
	var growth := HBoxContainer.new()
	growth.add_theme_constant_override("separation", 10)
	add_child(growth)
	growth.add_child(ConceptIcon.new("lord_exp", 20, "主公经验"))
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(220, 14)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.show_percentage = false
	bar.max_value = maxi(int(progress.required), 1)
	bar.value = int(progress.current) if int(progress.required) > 0 else 1
	bar.tooltip_text = "每次胜利获得经验，等级不提供战斗属性。"
	growth.add_child(bar)
	growth.add_child(_label("%d / %d" % [int(progress.current), int(progress.required)] if int(progress.required) > 0 else "已满级", 12, UITheme.LIGHT_MUTED))
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	add_child(tabs)
	for page in range(2):
		var button := Button.new()
		button.name = "ShopTab_%d" % page
		button.custom_minimum_size = Vector2(116, 36)
		button.text = "补给" if page == 0 else "兑换"
		button.toggle_mode = true
		button.set_pressed_no_signal(page == _page)
		button.tooltip_text = "元宝商店" if page == 0 else "军功商店"
		var currency_icon := ConceptIcon.new("ingot" if page == 0 else "merit", 22, button.tooltip_text)
		currency_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		currency_icon.position = Vector2(10, 7)
		currency_icon.size = Vector2(22, 22)
		button.add_child(currency_icon)
		UITheme.apply_light_selectable(button)
		button.pressed.connect(_switch_page.bind(page))
		tabs.add_child(button)
	for index in range(ShopRegistry.data().tier_levels.size()):
		var threshold: int = ShopRegistry.data().tier_levels[index]
		var badge := _label("%s · Lv.%d" % [["Ⅰ", "Ⅱ", "Ⅲ", "Ⅳ", "Ⅴ", "Ⅵ"][index], threshold], 12, UITheme.LIGHT_GOLD_TEXT if int(progress.level) >= threshold else UITheme.LIGHT_MUTED)
		badge.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tabs.add_child(badge)
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 16)
	add_child(body)
	_scroll = ScrollContainer.new()
	_scroll.name = "PermanentShelf"
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(_scroll)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 8)
	_scroll.add_child(content)
	for group in range(2 if _page == 0 else 1):
		content.add_child(_label(("常驻物资" if group == 0 else "装备补给") if _page == 0 else "永久遗物 · 每件仅一次", 16, UITheme.LIGHT_INK))
		var grid := GridContainer.new()
		grid.name = ("MaterialsGrid" if group == 0 else "EquipmentGrid") if _page == 0 else "MeritGrid"
		grid.columns = 2 if _page == 0 else 3
		grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_theme_constant_override("h_separation", 10)
		grid.add_theme_constant_override("v_separation", 10)
		content.add_child(grid)
		for entry in ShopRegistry.all_offers():
			if (_page == 0 and entry.shelf == "permanent" and entry.has("weapon") == (group == 1)) or (_page == 1 and entry.shelf == "merit"):
				grid.add_child(_offer_card(profile, entry))
	if _page == 0:
		var rotation := VBoxContainer.new()
		rotation.custom_minimum_size = Vector2(286, 0)
		rotation.add_theme_constant_override("separation", 8)
		body.add_child(rotation)
		rotation.add_child(_label("轮换补给", 16, UITheme.LIGHT_INK))
		for slot in range(3):
			if slot < profile.shop_state.rotation.size():
				rotation.add_child(_offer_card(profile, ShopRegistry.offer(str(profile.shop_state.rotation[slot])), true))
			else:
				var empty := HBoxContainer.new()
				empty.custom_minimum_size.y = 60
				empty.add_child(ConceptIcon.new("", 38, "轮换空位"))
				empty.add_child(_label("升至Lv.10后补齐", 13, UITheme.LIGHT_MUTED))
				rotation.add_child(empty)
		var action := HBoxContainer.new()
		rotation.add_child(action)
		var refresh := Button.new()
		refresh.name = "RefreshShop"
		refresh.text = "刷新"
		refresh.disabled = profile.ingots < ShopRegistry.refresh_price(profile)
		refresh.custom_minimum_size = Vector2(86, 34)
		UITheme.apply_light_selectable(refresh)
		refresh.pressed.connect(_refresh_offers.bind(int(profile.shop_state.revision)))
		action.add_child(refresh)
		action.add_child(ConceptIcon.new("ingot", 24, "刷新费用"))
		action.add_child(_label(str(ShopRegistry.refresh_price(profile)), 16, UITheme.LIGHT_GOLD_TEXT))
		rotation.add_child(_label("胜利后免费刷新并重置费用。\n10 → 20 → 30 → 10", 12, UITheme.LIGHT_MUTED, true))
	add_child(_label(_message if not _message.is_empty() else "通关后可购买对应装备；余额不足或达到上限时无法购买。", 13, UITheme.LIGHT_LOCK if not _message.is_empty() else UITheme.LIGHT_MUTED, true))
	_restore_scroll(_scroll, old_scroll)

func _restore_scroll(target: ScrollContainer, offset: int) -> void:
	# Nested grids settle after the deferred container sort passes.
	for frame in range(3): await get_tree().process_frame
	if is_instance_valid(target) and target == _scroll:
		target.scroll_vertical = offset

func _offer_card(profile: PlayerProfile, entry: Dictionary, compact: bool = false) -> Control:
	var card := PanelContainer.new()
	card.name = "ShopOffer_" + str(entry.id)
	card.custom_minimum_size = Vector2(252, 126) if not compact else Vector2.ZERO
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style := UITheme.light_card_style(Color.WHITE, UITheme.LIGHT_PANEL_BORDER)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 6 if compact else 10
	style.content_margin_bottom = 6 if compact else 10
	card.add_theme_stylebox_override("panel", style)
	card.tooltip_text = (WeaponRegistry.acquisition_text(WeaponRegistry.get_weapon(str(entry.weapon))) if entry.has("weapon") else ShopRegistry.description(entry)) + "\n" + ShopRegistry.brief_description(entry)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 5)
	card.add_child(box)
	var heading := HBoxContainer.new()
	heading.add_theme_constant_override("separation", 8)
	box.add_child(heading)
	if entry.has("weapon"):
		heading.add_child(ConceptIcon.new(str(entry.weapon), 32, ShopRegistry.description(entry)))
	else:
		for id in entry.items:
			heading.add_child(ConceptIcon.new(str(id), 24 if entry.items.size() > 1 else 32, GameFlow.get_item_display_name(str(id))))
	var title_box := VBoxContainer.new()
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_box.add_theme_constant_override("separation", 0)
	heading.add_child(title_box)
	var title := _label(ShopRegistry.display_name(entry), 14 if compact else 16, UITheme.LIGHT_INK, true)
	title.name = "OfferName"
	title_box.add_child(title)
	if entry.items.size() > 1:
		title_box.add_child(_label(ShopRegistry.description(entry), 11, UITheme.LIGHT_MUTED, true))
	var description := _label(ShopRegistry.brief_description(entry), 12 if compact else 13, UITheme.LIGHT_BODY, true)
	description.name = "OfferDescription"
	description.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(description)
	if entry.has("weapon"):
		if not profile.stage_progress.has(entry.unlock_stage):
			var stage := GameFlow.load_stage_data(StringName(entry.unlock_stage))
			box.add_child(_label("通关s%02d·%s后解锁" % [stage.stage_number, stage.display_name], 12, UITheme.LIGHT_MUTED, true))
	var action := HBoxContainer.new()
	action.add_theme_constant_override("separation", 6)
	box.add_child(action)
	action.add_child(ConceptIcon.new("ingot" if entry.currency == "ingots" else "merit", 21, "售价"))
	action.add_child(_label(str(entry.price), 16, UITheme.LIGHT_GOLD_TEXT))
	var status := ShopRegistry.purchase_status(profile, entry)
	var capacity := "持有%d/3" % profile.weapon_count(str(entry.weapon)) if entry.has("weapon") else ("剩余%d次" % (0 if entry.shelf == "merit" and status == "已购" else maxi(int(entry.limit) - int(profile.shop_state.permanent_counts.get(entry.id, 0)), 0)) if int(entry.limit) > 0 else "不限购")
	var remaining := _label(capacity, 11, UITheme.LIGHT_MUTED)
	remaining.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	remaining.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	action.add_child(remaining)
	var button := Button.new()
	button.name = "BuyOffer"
	button.text = status
	button.disabled = status != "购买"
	button.custom_minimum_size = Vector2(72, 28 if compact else 30)
	UITheme.apply_light_selectable(button)
	button.pressed.connect(_buy.bind(str(entry.id), int(profile.shop_state.revision)))
	action.add_child(button)
	return card

func _switch_page(page: int) -> void:
	_page = page
	_scroll = null
	_message = ""
	_refresh()

func _buy(id: String, revision: int) -> void:
	_message = "" if ProfileStore.buy_shop_offer(id, revision) else "购买未完成，未扣除。请重试。"
	_refresh()

func _refresh_offers(revision: int) -> void:
	_message = "" if ProfileStore.refresh_shop(revision) else "刷新未完成，未扣除。请重试。"
	_refresh()
