extends Building
class_name Market

const TRADE_CART_WOOD_COST: int = 100
const TRADE_CART_GOLD_COST: int = 50
const TRAIN_TIME: float = 5.0
var TradeCartScene: PackedScene  # Loaded in _ready() to avoid circular dependency with TradeCart
const MAX_QUEUE_SIZE: int = 15

var is_training: bool = false
var train_timer: float = 0.0
var spawn_point_offset: Vector2 = Vector2(0, 60)
var training_queue: Array[String] = []  # Array of "trade_cart" strings

signal training_started
signal training_completed
signal training_progress(progress: float)
signal trade_completed(resource_type: String, is_buy: bool, amount: int, gold_amount: int)
signal queue_changed(queue_size: int)

func _ready() -> void:
	TradeCartScene = load("res://scenes/units/trade_cart.tscn")
	max_hp = 2100  # Set before super._ready() so it uses correct max
	super._ready()
	add_to_group("markets")
	building_name = "Market"
	size = Vector2i(3, 3)
	wood_cost = 175  # From AoE2 spec
	build_time = 60.0

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
	if training_queue.size() >= MAX_QUEUE_SIZE:
		return false

	if not GameManager.can_add_population(team):
		return false
	if not GameManager.can_afford("wood", TRADE_CART_WOOD_COST, team):
		return false
	if not GameManager.can_afford("gold", TRADE_CART_GOLD_COST, team):
		return false

	GameManager.spend_resource("wood", TRADE_CART_WOOD_COST, team)
	GameManager.spend_resource("gold", TRADE_CART_GOLD_COST, team)

	training_queue.append("trade_cart")
	queue_changed.emit(training_queue.size())

	if not is_training:
		_start_next_training()
	return true

func cancel_training() -> bool:
	if training_queue.is_empty():
		return false

	var cancelled_type = training_queue.pop_back()
	queue_changed.emit(training_queue.size())

	if cancelled_type == "trade_cart":
		GameManager.add_resource("wood", TRADE_CART_WOOD_COST, team)
		GameManager.add_resource("gold", TRADE_CART_GOLD_COST, team)

	if training_queue.is_empty():
		is_training = false
		train_timer = 0.0

	return true

func _start_next_training() -> void:
	if training_queue.is_empty():
		is_training = false
		return

	is_training = true
	train_timer = 0.0
	training_started.emit()

func _complete_training() -> void:
	if training_queue.is_empty():
		is_training = false
		train_timer = 0.0
		return

	var completed_type = training_queue.pop_front()
	queue_changed.emit(training_queue.size())

	if completed_type == "trade_cart":
		var trade_cart = TradeCartScene.instantiate()
		trade_cart.global_position = global_position + spawn_point_offset
		trade_cart.team = team
		trade_cart.home_market = self
		get_parent().add_child(trade_cart)
		GameManager.add_population(1, team)

	training_completed.emit()

	if not training_queue.is_empty():
		_start_next_training()
	else:
		is_training = false
		train_timer = 0.0

func get_train_progress() -> float:
	if not is_training:
		return 0.0
	return train_timer / TRAIN_TIME

func get_queue_size() -> int:
	return training_queue.size()
