extends RefCounted
class_name ShopRegistry

const MAX_BALANCE := 1000000000000
static var _data: ShopData

static func data() -> ShopData:
	if _data == null: _data = load("res://resources/shop/shop_catalog.tres") as ShopData
	return _data

static func non_negative(raw, cap: int = MAX_BALANCE) -> int:
	if raw is String:
		if not raw.is_valid_int(): return 0
		raw = raw.to_float()
	if typeof(raw) != TYPE_INT and typeof(raw) != TYPE_FLOAT: return 0
	return int(clampf(float(raw), 0.0, float(cap))) if is_finite(float(raw)) else 0

static func exp_for_level(level: int) -> int:
	var total := 0
	for current in range(1, clampi(level, 1, data().max_lord_level)):
		total += data().exp_base + data().exp_step * (current - 1)
	return total

static func lord_progress(total_exp: int) -> Dictionary:
	var total := clampi(total_exp, 0, exp_for_level(data().max_lord_level))
	var level := 1
	while level < data().max_lord_level and total >= exp_for_level(level + 1): level += 1
	var required := data().exp_base + data().exp_step * (level - 1) if level < data().max_lord_level else 0
	return {"level": level, "current": total - exp_for_level(level), "required": required, "total": total}

static func tier(level: int) -> int:
	var result := 0
	for threshold in data().tier_levels:
		if level >= threshold: result += 1
	return result

static func victory_rewards(first: bool, difficulty: int) -> Dictionary:
	return {"ingots": roundi((data().first_ingots if first else data().repeat_ingots) * (data().hard_ingot_mult if difficulty >= Difficulty.HARD else 1.0)), "lord_exp": roundi((data().first_lord_exp if first else data().repeat_lord_exp) * (data().hard_exp_mult if difficulty >= Difficulty.HARD else 1.0))}

static func all_offers() -> Array[Dictionary]:
	var offers: Array[Dictionary] = []
	for raw in data().permanent_offers + data().rotating_offers + data().merit_offers: offers.append(raw.duplicate(true))
	for id in WeaponRegistry.IDS:
		var weapon := WeaponRegistry.get_weapon(id)
		offers.append({"id": id, "shelf": "permanent", "currency": "ingots", "price": weapon.shop_price, "level": 1, "limit": 0, "weapon": id, "items": {}, "unlock_stage": str(weapon.unlock_stage_id)})
	return offers

static func offer(id: String) -> Dictionary:
	for entry in all_offers():
		if str(entry.id) == id: return entry
	return {}

static func rotation_pool(level: int) -> Array[String]:
	var ids: Array[String] = []
	for entry in data().rotating_offers:
		if int(entry.level) <= level: ids.append(str(entry.id))
	return ids

static func normalize_state(raw, total_exp: int) -> Dictionary:
	var source: Dictionary = raw if raw is Dictionary else {}
	var counts := {}
	var raw_counts: Dictionary = source.get("permanent_counts", {}) if source.get("permanent_counts", {}) is Dictionary else {}
	for entry in all_offers():
		if int(entry.limit) > 0:
			var count := non_negative(raw_counts.get(entry.id, 0), int(entry.limit))
			if count > 0: counts[entry.id] = count
	var pool := rotation_pool(int(lord_progress(total_exp).level))
	var rotation: Array[String] = []
	if source.get("rotation", []) is Array:
		for id in source.get("rotation", []):
			if pool.has(str(id)) and not rotation.has(str(id)) and rotation.size() < 3: rotation.append(str(id))
	for id in pool:
		if rotation.size() >= mini(3, pool.size()): break
		if not rotation.has(id): rotation.append(id)
	return {"permanent_counts": counts, "rotation": rotation, "refresh_step": non_negative(source.get("refresh_step", 0), data().refresh_prices.size() - 1), "revision": non_negative(source.get("revision", 0))}

static func refresh_price(profile) -> int:
	return data().refresh_prices[int(profile.shop_state.refresh_step)]

static func reroll(profile, old_level: int = 0, rng: RandomNumberGenerator = null) -> void:
	var level: int = int(lord_progress(profile.lord_exp).level)
	var pool := rotation_pool(level)
	# Fisher-Yates also permits deterministic acceptance fixtures.
	for i in range(pool.size() - 1, 0, -1):
		var j := rng.randi_range(0, i) if rng != null else randi_range(0, i)
		var swap := pool[i]
		pool[i] = pool[j]
		pool[j] = swap
	if old_level > 0 and tier(level) > tier(old_level):
		var old_pool := rotation_pool(old_level)
		for id in pool:
			if not old_pool.has(id):
				pool.erase(id)
				pool.push_front(id)
				break
	profile.shop_state.rotation = pool.slice(0, mini(3, pool.size()))
	profile.shop_state.revision = non_negative(profile.shop_state.revision + 1)

static func purchase_status(profile, entry: Dictionary) -> String:
	if entry.is_empty(): return "不可购买"
	if int(lord_progress(profile.lord_exp).level) < int(entry.level): return "Lv.%d解锁" % int(entry.level)
	if entry.get("unlock_stage", "") != "" and not profile.stage_progress.has(entry.unlock_stage): return "通关后解锁"
	if entry.shelf == "rotation" and not profile.shop_state.rotation.has(entry.id): return "已刷新"
	if entry.has("weapon") and profile.weapon_count(str(entry.weapon)) >= WeaponRegistry.MAX_COUNT: return "已满"
	if entry.shelf == "merit":
		for id in entry.items:
			if int(profile.items.get(id, 0)) >= 1: return "已购"
	if int(entry.limit) > 0 and int(profile.shop_state.permanent_counts.get(entry.id, 0)) >= int(entry.limit): return "已购完"
	var balance: int = profile.ingots if entry.currency == "ingots" else profile.military_merit
	return "购买" if balance >= int(entry.price) else "不足"

static func buy(profile, id: String, expected_revision: int) -> bool:
	if expected_revision != int(profile.shop_state.revision): return false
	var entry := offer(id)
	if purchase_status(profile, entry) != "购买": return false
	if entry.currency == "ingots": profile.ingots -= int(entry.price)
	else: profile.military_merit -= int(entry.price)
	if entry.has("weapon"): profile.add_weapon(str(entry.weapon), 1)
	else:
		for item_id in entry.items: profile.add_item(str(item_id), int(entry.items[item_id]))
	if int(entry.limit) > 0: profile.shop_state.permanent_counts[entry.id] = int(profile.shop_state.permanent_counts.get(entry.id, 0)) + 1
	profile.shop_state.revision = non_negative(profile.shop_state.revision + 1)
	return true

static func manual_refresh(profile, expected_revision: int, rng: RandomNumberGenerator = null) -> bool:
	if expected_revision != int(profile.shop_state.revision) or profile.ingots < refresh_price(profile): return false
	profile.ingots -= refresh_price(profile)
	profile.shop_state.refresh_step = (int(profile.shop_state.refresh_step) + 1) % data().refresh_prices.size()
	reroll(profile, 0, rng)
	return true

static func description(entry: Dictionary) -> String:
	if entry.has("weapon"): return WeaponRegistry.get_weapon(str(entry.weapon)).display_name
	var parts: Array[String] = []
	for id in entry.items:
		var item := load("res://resources/items/%s.tres" % id) as ItemData
		parts.append("%s×%d" % [item.display_name, int(entry.items[id])])
	return " + ".join(parts)

static func acquisition_text(item_id: String) -> String:
	for entry in data().merit_offers:
		if entry.items.has(item_id): return "可在商店「兑换」页获取，每件仅一次；已有物品视为已购。"
	for entry in data().permanent_offers:
		if entry.items.has(item_id): return "可在商店「补给」页购买，货档与限购以商店显示为准。"
	return ""
