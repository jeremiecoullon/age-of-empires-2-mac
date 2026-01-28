extends Building
class_name Market

const TRADE_CART_WOOD_COST: int = 100
const TRADE_CART_GOLD_COST: int = 50
const TRAIN_TIME: float = 5.0
const TradeCartScene: PackedScene = preload("res://scenes/units/trade_cart.tscn")

var is_training: bool = false
var train_timer: float = 0.0
var spawn_point_offset: Vector2 = Vector2(0, 60)

signal training_started
signal training_completed
signal training_progress(progress: float)
signal trade_completed(resource_type: String, is_buy: bool, amount: int, gold_amount: int)

func _ready() -> void:
	super._ready()
	add_to_group("markets")
	building_name = "Market"
	size = Vector2i(3, 3)
	wood_cost = 175  # From AoE2 spec
	max_hp = 2100  # From AoE2 spec

func _process(delta: float) -> void:
	if is_training:
		train_timer += delta
		training_progress.emit(train_timer / TRAIN_TIME)

		if train_timer >= TRAIN_TIME:
			_complete_training()

# Trading functions - delegate to GameManager
func buy_resource(resource_type: String) -> bool:
	if resource_type == "gold":
		return false

	var gold_cost = GameManager.get_market_buy_price(resource_type)
	if GameManager.market_buy(resource_type, team):
		trade_completed.emit(resource_type, true, 100, gold_cost)
		return true
	return false

func sell_resource(resource_type: String) -> bool:
	if resource_type == "gold":
		return false

	var gold_gained = GameManager.get_market_sell_price(resource_type)
	if GameManager.market_sell(resource_type, team):
		trade_completed.emit(resource_type, false, 100, gold_gained)
		return true
	return false

func get_buy_price(resource_type: String) -> int:
	return GameManager.get_market_buy_price(resource_type)

func get_sell_price(resource_type: String) -> int:
	return GameManager.get_market_sell_price(resource_type)

# Trade Cart training
func train_trade_cart() -> bool:
	if is_training:
		return false

	if not GameManager.can_add_population(team):
		return false
	if not GameManager.can_afford("wood", TRADE_CART_WOOD_COST, team):
		return false
	if not GameManager.can_afford("gold", TRADE_CART_GOLD_COST, team):
		return false

	GameManager.spend_resource("wood", TRADE_CART_WOOD_COST, team)
	GameManager.spend_resource("gold", TRADE_CART_GOLD_COST, team)

	is_training = true
	train_timer = 0.0
	training_started.emit()
	return true

func _complete_training() -> void:
	is_training = false
	train_timer = 0.0

	var trade_cart = TradeCartScene.instantiate()
	trade_cart.global_position = global_position + spawn_point_offset
	trade_cart.team = team
	trade_cart.home_market = self  # Set this market as home
	get_parent().add_child(trade_cart)
	GameManager.add_population(1, team)

	training_completed.emit()

func get_train_progress() -> float:
	if not is_training:
		return 0.0
	return train_timer / TRAIN_TIME
