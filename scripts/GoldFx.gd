extends Node2D

## 局内金币获取反馈（✅ 0.8.17.1 / DESIGN_REVIEW §12.7 方案 A / UI_LAYOUT §10 v0.20.67）。
## 纯表现层：只读 GameManager.gold_gain_fx（击杀点 + 档位），不改任何经济数值。
## 节点由 Main 按需创建——父 CanvasLayer（层 2、PROCESS_MODE_PAUSABLE），headless 不创建（回归零差异）。
## 性能三道闸：40ms 窗口合簇 / 金币节点池化复用 / 屏内活跃金币 ≤ 24。

## 击杀档位（GameManager.gold_gain_fx / Enemy.die 传入）：普通 / 精英 / Boss。
enum Tier { NORMAL, ELITE, BOSS }

const MAX_ACTIVE_COINS := 24
## 同窗口多杀合并（§12.7 拍板 4）。
const MERGE_WINDOW := 0.04
## 三段式：出生 0.10s 上抛 + 散布 → 飞行 0.35~0.50s 贝塞尔弧线 → 入账缩没 0.08s。
const SPAWN_DURATION := 0.10
const SPAWN_UP_MIN := 8.0
const SPAWN_UP_MAX := 14.0
const SPAWN_SPREAD_X := 10.0
const FLIGHT_MIN := 0.35
const FLIGHT_MAX := 0.50
const ARC_MIN := 40.0
const ARC_MAX := 70.0
const SHRINK_DURATION := 0.08
## 多杀合并簇枚数封顶：枚数只作视觉强弱、不承担计数（真值由 HUD 数字滚动体现）。
const MERGED_CLUSTER_CAP := 3
const COIN_ICON := "coin"
const COIN_ICON_SIZE := 22.0
const COIN_TINT := Color("#ffd479")
const WAVE_TEXT_SIZE := 18
## 单杀簇枚数（§12.7 拍板 2）：普通 2~3 / 精英 3~4 / Boss 6~8。
const TIER_COIN_RANGE := {
	Tier.NORMAL: Vector2i(2, 3),
	Tier.ELITE: Vector2i(3, 4),
	Tier.BOSS: Vector2i(6, 8),
}

var _ui: Node = null
var _rng := RandomNumberGenerator.new()
var _texture: Texture2D = null
var _pool: Array[Sprite2D] = []
var _free: Array[Sprite2D] = []
var _active := 0
var _pending_positions: Array[Vector2] = []
var _pending_kills := 0
var _pending_tier := Tier.NORMAL
var _merge_timer: Timer = null
var _coin_scale := 1.0


func _ready() -> void:
	_rng.randomize()
	_texture = UITheme.hud_icon(COIN_ICON)
	if _texture != null:
		_coin_scale = COIN_ICON_SIZE / maxf(float(_texture.get_width()), 1.0)
	_merge_timer = Timer.new()
	_merge_timer.name = "GoldFxMerge"
	_merge_timer.one_shot = true
	_merge_timer.wait_time = MERGE_WINDOW
	_merge_timer.timeout.connect(_flush_cluster)
	add_child(_merge_timer)


## Main 注入 UI 引用（锚点 = UI.get_gold_anchor()；落地回调 = UI.on_gold_fx_landed()）。
func setup(ui_node: Node) -> void:
	_ui = ui_node


## 击杀金币 FX 请求（Main 转发 GameManager.gold_gain_fx）：world_pos = 击杀点世界坐标。
func request_kill_fx(world_pos: Vector2, tier: int) -> void:
	if _texture == null:
		_notify_landed()
		return
	_pending_positions.append(_world_to_screen(world_pos))
	_pending_kills += 1
	_pending_tier = maxi(_pending_tier, clampi(tier, Tier.NORMAL, Tier.BOSS))
	if _merge_timer != null:
		_merge_timer.start()


## 波次完成奖变体（§12.7 拍板 6）：旗帜位置金币图徽 + `+N` 飘字，不跨屏飞行、数字即时滚动。
func request_wave_bonus(world_pos: Vector2, amount: int) -> void:
	var screen := _world_to_screen(world_pos)
	var row := HBoxContainer.new()
	row.name = "GoldWaveBonus"
	row.add_theme_constant_override("separation", 2)
	row.position = screen + Vector2(-24.0, -20.0)
	add_child(row)
	if _texture != null:
		var icon := TextureRect.new()
		icon.texture = _texture
		icon.custom_minimum_size = Vector2(20.0, 20.0)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row.add_child(icon)
	var label := Label.new()
	label.text = "+%d" % maxi(amount, 0)
	label.add_theme_font_size_override("font_size", WAVE_TEXT_SIZE)
	label.add_theme_color_override("font_color", COIN_TINT)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	label.add_theme_constant_override("outline_size", 4)
	row.add_child(label)
	row.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(row, "modulate:a", 1.0, 0.10)
	tween.parallel().tween_property(row, "position:y", row.position.y - 30.0, 0.8) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(row, "modulate:a", 0.0, 0.35).set_delay(0.15)
	tween.tween_callback(row.queue_free)
	_notify_landed()


## 活跃金币数（真机探针 / 回归断言用）。
func get_active_coin_count() -> int:
	return _active


## 40ms 窗口到点：合并本窗口击杀为一簇并生成金币。
func _flush_cluster() -> void:
	var positions := _pending_positions
	var kills := _pending_kills
	var tier := _pending_tier
	_pending_positions = []
	_pending_kills = 0
	_pending_tier = Tier.NORMAL
	if positions.is_empty():
		return
	var span: Vector2i = TIER_COIN_RANGE.get(tier, TIER_COIN_RANGE[Tier.NORMAL])
	var count := _rng.randi_range(span.x, span.y)
	if kills > 1:
		count = mini(count, MERGED_CLUSTER_CAP)
	var budget := MAX_ACTIVE_COINS - _active
	if budget <= 0:
		# 上限闸：直接跳数字（不生成节点）。
		_notify_landed()
		return
	count = mini(count, budget)
	var center := Vector2.ZERO
	for pos in positions:
		center += pos
	center /= float(positions.size())
	SfxLibrary.play(&"coin", -12.0, 1.0 + _rng.randf_range(-0.05, 0.05))
	var remaining := [count]
	for _index in count:
		_spawn_coin(center, remaining)


func _spawn_coin(center: Vector2, remaining: Array) -> void:
	var coin := _acquire_coin()
	if coin == null:
		_cluster_tick(remaining)
		return
	_active += 1
	var anchor := _gold_anchor()
	var spawn_pos := center + Vector2(
		_rng.randf_range(-SPAWN_SPREAD_X, SPAWN_SPREAD_X),
		_rng.randf_range(-SPAWN_UP_MAX, -SPAWN_UP_MIN)
	)
	var control := (spawn_pos + anchor) * 0.5 + Vector2(
		_rng.randf_range(-18.0, 18.0),
		-_rng.randf_range(ARC_MIN, ARC_MAX)
	)
	var flight_time := _rng.randf_range(FLIGHT_MIN, FLIGHT_MAX)
	coin.position = center
	coin.rotation = _rng.randf_range(-0.3, 0.3)
	coin.scale = Vector2.ONE * _coin_scale
	coin.modulate = Color(1, 1, 1, 1)
	coin.visible = true
	var tween := create_tween()
	tween.tween_property(coin, "position", spawn_pos, SPAWN_DURATION) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_method(
		_set_coin_flight.bind(coin, spawn_pos, control, anchor), 0.0, 1.0, flight_time
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(
		coin, "rotation", coin.rotation + _rng.randf_range(-1.4, 1.4), SPAWN_DURATION + flight_time
	)
	tween.tween_callback(_cluster_tick.bind(remaining))
	tween.tween_property(coin, "scale", Vector2.ZERO, SHRINK_DURATION) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(_release_coin.bind(coin))


## 二次贝塞尔：出生散布点 → 控制点 → 顶栏金币锚点（t 由 Tween 0→1 驱动）。
func _set_coin_flight(t: float, coin: Sprite2D, from: Vector2, control: Vector2, to: Vector2) -> void:
	if not is_instance_valid(coin):
		return
	var u := 1.0 - t
	coin.position = u * u * from + 2.0 * u * t * control + t * t * to


## 簇内一枚抵达锚点：全部到齐 → 通知 UI 数字滚动补差 + 金币胶囊弹跳。
func _cluster_tick(remaining: Array) -> void:
	remaining[0] = int(remaining[0]) - 1
	if int(remaining[0]) <= 0:
		_notify_landed()


func _notify_landed() -> void:
	if _ui != null and is_instance_valid(_ui):
		_ui.on_gold_fx_landed()
		_ui.play_gold_pill_bounce()


func _acquire_coin() -> Sprite2D:
	if not _free.is_empty():
		return _free.pop_back()
	if _pool.size() >= MAX_ACTIVE_COINS:
		return null
	var coin := Sprite2D.new()
	coin.name = "GoldCoin"
	coin.texture = _texture
	coin.centered = true
	add_child(coin)
	_pool.append(coin)
	return coin


func _release_coin(coin: Sprite2D) -> void:
	if not is_instance_valid(coin):
		return
	coin.visible = false
	coin.scale = Vector2.ONE
	_free.append(coin)
	_active = maxi(_active - 1, 0)


func _gold_anchor() -> Vector2:
	if _ui != null and is_instance_valid(_ui):
		return _ui.get_gold_anchor()
	var viewport := get_viewport()
	if viewport == null:
		return Vector2.ZERO
	return viewport.get_visible_rect().size * Vector2(0.08, 0.05)


## 起点 = canvas_transform × 世界坐标（§12.7 拍板 2；本层无自变换，父 CanvasLayer 直出屏幕坐标）。
func _world_to_screen(world_pos: Vector2) -> Vector2:
	var viewport := get_viewport()
	if viewport == null:
		return world_pos
	return viewport.get_canvas_transform() * world_pos
