extends RefCounted

class_name LevelCurve

## 等级经验曲线（GDD modules/NUMBERS.md 10.1）：
## total_exp(L) = exp_base_per_level*(L-1) + exp_growth_per_level*(L-1)*(L-2)，L≥1；
## 存档只存 total_exp，等级由此推导。参数与上限 v0.18.0 起读 GameBalance 中心配置。

static func exp_total_for_level(level: int) -> int:
	var balance := GameBalance.get_balance()
	var l := maxi(level, 1)
	return balance.exp_base_per_level * (l - 1) + balance.exp_growth_per_level * (l - 1) * (l - 2)


static func max_level() -> int:
	return GameBalance.get_balance().max_level


static func level_from_total_exp(total_exp: int) -> int:
	var exp_value := maxi(total_exp, 0)
	var level := 1
	while level < max_level() and exp_total_for_level(level + 1) <= exp_value:
		level += 1
	return level


## 当前等级内的进度信息，供养成界面经验条使用。
static func progress_at(total_exp: int) -> Dictionary:
	var level := level_from_total_exp(total_exp)
	var level_floor := exp_total_for_level(level)
	var next_floor := exp_total_for_level(level + 1) if level < max_level() else level_floor
	return {
		"level": level,
		"exp_into_level": total_exp - level_floor,
		"exp_for_next": next_floor - level_floor,
		"is_max_level": level >= max_level(),
	}