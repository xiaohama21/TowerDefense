extends RefCounted

class_name GameBalance

## 数值配置中心化访问层（GDD 阶段 6 · 提交 2，v0.18.0）：
## 全局平衡数值唯一来源 `resources/balance/game_balance.tres`（BalanceData）；
## 加载失败回退 BalanceData 内置默认（与 .tres 一致），保证缺资源也可运行。

const BALANCE_PATH := "res://resources/balance/game_balance.tres"

static var _cached: BalanceData = null


static func get_balance() -> BalanceData:
	if _cached == null:
		_cached = load(BALANCE_PATH) as BalanceData
	if _cached == null:
		_cached = BalanceData.new()
	return _cached


static func reset_cache() -> void:
	_cached = null