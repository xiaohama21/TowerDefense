extends Resource

class_name DropEntryData

## 概率掉落条目（GDD modules/DROPS_GACHA.md 7.2）：结算时逐条掷点。
@export var item: ItemData
@export_range(1, 999, 1) var amount: int = 1
## 掉落概率（0.5 = 50%）。
@export_range(0.0, 1.0, 0.01) var chance: float = 0.5
