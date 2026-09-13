extends Resource

class_name BattleSupplyData

## 局内军需（✅ 0.8.16 重构 / NUMBERS.md 10.15）：**局外解锁 · 强化 → 局内金币购买入「军需带」
## → 点击带内条目择时使用**（购买不立即生效；未使用结算作废、不返还）。
## 数值按强化等级 L1~L3 承载（费用 / 限次 / 幅度），本资源是唯一数据源；
## 解锁消耗为军功（基础 4 件 = 0，默认已解锁）。

## 军需目录与展示顺序（✅ 0.8.16 / NUMBERS 10.15）：修整 / 火攻 / 擂鼓 / 缓兵 / 掷石齐射 / 犒军。
const DIRECTORY := "res://resources/battle_supplies"
const DISPLAY_ORDER: Array[String] = ["repair", "fire_attack", "war_drum", "slow_down", "stone_volley", "reward_army"]


## 目录扫描（PCK 兼容）：局内面板与大厅「军需处」共用同一份目录与顺序。
static func load_catalog() -> Array[BattleSupplyData]:
	var supplies: Array[BattleSupplyData] = []
	for entry in ResourceLoader.list_directory(DIRECTORY):
		if not entry.ends_with(".tres"):
			continue
		var supply := load(DIRECTORY + "/" + entry) as BattleSupplyData
		if supply == null or not supply.is_valid():
			push_warning("军需资源无效：%s" % entry)
			continue
		supplies.append(supply)
	supplies.sort_custom(func(a: BattleSupplyData, b: BattleSupplyData) -> bool:
		return display_order(a) < display_order(b)
	)
	return supplies


static func display_order(supply: BattleSupplyData) -> int:
	var index := DISPLAY_ORDER.find(str(supply.supply_id))
	return index if index >= 0 else DISPLAY_ORDER.size()


@export_category("Identity")
@export var supply_id: StringName
@export var display_name: String = ""
@export_multiline var description: String = ""
## 局外解锁消耗（军功）：0 = 基础件（默认已解锁）。
@export_range(0, 99999, 1) var merit_unlock_cost: int = 0

@export_category("Purchase (逐级，索引 0~2 = L1~L3)")
## 金币费用（L1 / L2 / L3）；支付 = 本级值 ×（1 − 科技 supply_discount_pct）向上取整。
@export var level_costs: Array[int] = [50, 50, 50]
## 每局可用次数（L1 / L2 / L3）。
@export var level_max_uses: Array[int] = [1, 1, 1]

@export_category("Effects (NUMBERS.md 10.15)")
## 修整：基地生命回复量。
@export var level_heal: Array[int] = [0, 0, 0]
## 火攻：全场立即魔法伤害。
@export var level_instant_magic: Array[int] = [0, 0, 0]
## 火攻：灼烧（每秒伤害，持续 level_duration）。
@export var level_burn_dps: Array[int] = [0, 0, 0]
## 掷石齐射：全场物理伤害（军需独立来源、不经塔任何桶、按护甲结算）。
@export var level_instant_physical: Array[int] = [0, 0, 0]
## 擂鼓：全队攻速加成（0.30 = +30%）。
@export var level_attack_speed_bonus: Array[float] = [0.0, 0.0, 0.0]
## 缓兵：全场减速因子（0.60 = 减速 40%）。
@export var level_slow_factor: Array[float] = [1.0, 1.0, 1.0]
## 火攻 / 擂鼓 / 缓兵：效果持续（秒）。
@export var level_duration: Array[float] = [0.0, 0.0, 0.0]
## 犒军：全队怒气固定值（直接加怒，不吃科技怒气% 与月幕倍率）。
@export var level_rage_gain: Array[int] = [0, 0, 0]


func is_valid() -> bool:
	return not supply_id.is_empty() and not display_name.is_empty() and level_costs.size() > 0


## 强化等级 → 数组索引（1~3 → 0~2；越界夹取，缺项回退末位）。
func level_index(level: int) -> int:
	return clampi(level - 1, 0, 2)


func cost_at(level: int) -> int:
	return _int_at(level_costs, level, 50)


func max_uses_at(level: int) -> int:
	return maxi(_int_at(level_max_uses, level, 1), 1)


func heal_at(level: int) -> int:
	return _int_at(level_heal, level, 0)


func instant_magic_at(level: int) -> int:
	return _int_at(level_instant_magic, level, 0)


func burn_dps_at(level: int) -> int:
	return _int_at(level_burn_dps, level, 0)


func instant_physical_at(level: int) -> int:
	return _int_at(level_instant_physical, level, 0)


func attack_speed_bonus_at(level: int) -> float:
	return _float_at(level_attack_speed_bonus, level, 0.0)


func slow_factor_at(level: int) -> float:
	return _float_at(level_slow_factor, level, 1.0)


func duration_at(level: int) -> float:
	return _float_at(level_duration, level, 0.0)


func rage_gain_at(level: int) -> int:
	return _int_at(level_rage_gain, level, 0)


## 是否为军需独立来源的直伤类（掷石齐射：全场物理、不经塔桶）。
func is_physical_strike() -> bool:
	return instant_physical_at(1) > 0


## 效果摘要（军需处卡片 / 局内列表副行；按当前等级取实际数值）。
func summary_at(level: int) -> String:
	var index := level_index(level)
	if instant_physical_at(level) > 0:
		return "全场敌人各受 %d 物理伤害" % instant_physical_at(level)
	if rage_gain_at(level) > 0:
		return "全队怒气 +%d（直接加怒）" % rage_gain_at(level)
	if heal_at(level) > 0:
		return "基地生命 +%d" % heal_at(level)
	if burn_dps_at(level) > 0:
		return "立即 %d 魔法伤害 + 灼烧 %d/秒（%.0fs）" % [
			instant_magic_at(level), burn_dps_at(level), duration_at(level)
		]
	if attack_speed_bonus_at(level) > 0.0:
		return "全队攻速 +%d%%（%.0fs）" % [
			roundi(attack_speed_bonus_at(level) * 100.0), duration_at(level)
		]
	if slow_factor_at(level) < 1.0:
		return "全场减速 %d%%（%.0fs）" % [
			roundi((1.0 - slow_factor_at(level)) * 100.0), duration_at(level)
		]
	return _fallback_summary(index)


func _fallback_summary(_index: int) -> String:
	return description


func _int_at(values: Array[int], level: int, fallback: int) -> int:
	if values.is_empty():
		return fallback
	var index := clampi(level_index(level), 0, values.size() - 1)
	return values[index]


func _float_at(values: Array[float], level: int, fallback: float) -> float:
	if values.is_empty():
		return fallback
	var index := clampi(level_index(level), 0, values.size() - 1)
	return values[index]
