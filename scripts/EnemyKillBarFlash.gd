extends Node2D

class_name EnemyKillBarFlash

## 一击必杀 · 血条定格（UI_LAYOUT §10 / 程序 0.8.16.5）：
## 满血敌人被单次受击直接打死时，血量在同一帧 100% → 0 并立即 queue_free（无「掉血但活着」的帧），
## 玩家整场看不到这条血条 —— 由 Enemy.die() 在死亡点生成本节点补播一段定格：
## 红填充 1.0 → 0（FILL_DRAIN 秒打空）+ 白色掉血残影 1.0 → 0（GHOST_DRAIN 秒拖尾）+ 尾部 FADE 秒整体淡出。
## 纯表现层：不参与战斗逻辑、不含刻度与低血发光（群伤清场不留噪点），父级 = 当前战斗场景，播完自释放。

## 总时长 / 填充打空 / 残影拖尾 / 淡出起点（秒）；画法见 Enemy.draw_hp_bar_skin。
const DURATION: float = 0.50
const FILL_DRAIN: float = 0.20
const GHOST_DRAIN: float = 0.36
const FADE_START: float = 0.35

## 血条矩形（死者局部坐标，取自 Enemy.get_hp_bar_rect）与档位（Enemy.HpBarTier）。
var bar_rect: Rect2 = Rect2()
var bar_tier: int = 0
var _time: float = 0.0


func setup(rect: Rect2, tier: int) -> void:
	bar_rect = rect
	bar_tier = tier


## 填充比例（1.0 → 0，前 FILL_DRAIN 秒打空）。
static func fill_ratio_at(time: float) -> float:
	return 1.0 - clampf(time / FILL_DRAIN, 0.0, 1.0)


## 掉血残影比例（1.0 → 0，滞后 GHOST_DRAIN 秒的白色拖尾）。
static func ghost_ratio_at(time: float) -> float:
	return 1.0 - clampf(time / GHOST_DRAIN, 0.0, 1.0)


## 整体不透明度（FADE_START 之后线性淡出，DURATION 归零）。
static func alpha_at(time: float) -> float:
	return 1.0 - clampf((time - FADE_START) / (DURATION - FADE_START), 0.0, 1.0)


func _process(delta: float) -> void:
	_time += delta
	if _time >= DURATION:
		queue_free()
		return
	modulate.a = alpha_at(_time)
	queue_redraw()


func _draw() -> void:
	Enemy.draw_hp_bar_skin(
		self, bar_rect, bar_tier, fill_ratio_at(_time), ghost_ratio_at(_time), false
	)
