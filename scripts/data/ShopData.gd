extends Resource
class_name ShopData

@export var max_lord_level: int = 100
@export var exp_base: int = 30
@export var exp_step: int = 5
@export var first_ingots: int = 30
@export var repeat_ingots: int = 10
@export var hard_ingot_mult: float = 2.0
@export var first_lord_exp: int = 80
@export var repeat_lord_exp: int = 25
@export var hard_exp_mult: float = 1.5
@export var refresh_prices: Array[int] = [10, 20, 30]
@export var tier_levels: Array[int] = [1, 10, 20, 40, 60, 80]
@export var permanent_offers: Array[Dictionary] = []
@export var rotating_offers: Array[Dictionary] = []
@export var merit_offers: Array[Dictionary] = []
