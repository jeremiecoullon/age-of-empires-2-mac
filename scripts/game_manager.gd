extends Node

# Resource pools - dictionary-based for extensibility
var resources: Dictionary = {"wood": 200, "food": 200, "gold": 0, "stone": 0}
var ai_resources: Dictionary = {"wood": 200, "food": 200, "gold": 0, "stone": 0}

# Market system - dynamic pricing based on buy/sell activity
# Base prices: how much gold to buy 100 of each resource (AoE2-style)
const BASE_MARKET_PRICES: Dictionary = {"wood": 100, "food": 100, "stone": 130}
const MIN_MARKET_PRICE: int = 20  # Minimum price (100 resource costs 20 gold)
const MAX_MARKET_PRICE: int = 300  # Maximum price (100 resource costs 300 gold)
const PRICE_CHANGE_PER_TRADE: int = 3  # Price change per 100-unit trade

# Current market prices (shared globally - all players see same prices)
var market_prices: Dictionary = {"wood": 100, "food": 100, "stone": 130}

# Population
var population: int = 3
var population_cap: int = 5
var ai_population: int = 0
var ai_population_cap: int = 5

# Signals
signal resources_changed
signal population_changed
signal game_over(winner: int)  # 0 = player wins, 1 = AI wins
signal villager_idle(villager: Node, reason: String)  # Emitted when player villager goes idle
signal market_prices_changed  # Emitted when market prices update

var game_ended: bool = false

# Selected units
var selected_units: Array = []

# Building placement mode
var is_placing_building: bool = false
var building_to_place: PackedScene = null
var building_ghost: Node2D = null

# Unified resource functions
func add_resource(type: String, amount: int, team: int = 0) -> void:
	if team == 0:
		resources[type] += amount
	else:
		ai_resources[type] += amount
	resources_changed.emit()

func spend_resource(type: String, amount: int, team: int = 0) -> bool:
	var pool = resources if team == 0 else ai_resources
	if pool[type] >= amount:
		pool[type] -= amount
		resources_changed.emit()
		return true
	return false

func can_afford(type: String, amount: int, team: int = 0) -> bool:
	var pool = resources if team == 0 else ai_resources
	return pool[type] >= amount

func get_resource(type: String, team: int = 0) -> int:
	return resources[type] if team == 0 else ai_resources[type]

# Market functions
func get_market_buy_price(resource_type: String) -> int:
	# Returns gold cost to buy 100 of the resource
	if resource_type == "gold":
		return 0  # Can't buy gold with gold
	return market_prices.get(resource_type, 100)

func get_market_sell_price(resource_type: String) -> int:
	# Returns gold gained from selling 100 of the resource
	# Sell price is slightly lower than buy price (spread)
	if resource_type == "gold":
		return 0  # Can't sell gold for gold
	var buy_price = market_prices.get(resource_type, 100)
	# Sell price is ~70% of buy price (AoE2-style spread)
	return int(buy_price * 0.7)

func market_buy(resource_type: String, team: int = 0) -> bool:
	# Buy 100 of resource_type for gold
	if resource_type == "gold":
		return false
	var gold_cost = get_market_buy_price(resource_type)
	if not can_afford("gold", gold_cost, team):
		return false

	spend_resource("gold", gold_cost, team)
	add_resource(resource_type, 100, team)

	# Buying increases the price (demand)
	_adjust_market_price(resource_type, PRICE_CHANGE_PER_TRADE)
	return true

func market_sell(resource_type: String, team: int = 0) -> bool:
	# Sell 100 of resource_type for gold
	if resource_type == "gold":
		return false
	if not can_afford(resource_type, 100, team):
		return false

	var gold_gained = get_market_sell_price(resource_type)
	spend_resource(resource_type, 100, team)
	add_resource("gold", gold_gained, team)

	# Selling decreases the price (supply)
	_adjust_market_price(resource_type, -PRICE_CHANGE_PER_TRADE)
	return true

func _adjust_market_price(resource_type: String, change: int) -> void:
	if resource_type not in market_prices:
		return
	market_prices[resource_type] = clampi(
		market_prices[resource_type] + change,
		MIN_MARKET_PRICE,
		MAX_MARKET_PRICE
	)
	market_prices_changed.emit()

func reset_market_prices() -> void:
	market_prices = BASE_MARKET_PRICES.duplicate()
	market_prices_changed.emit()

# Population functions
func add_population(amount: int, team: int = 0) -> void:
	if team == 0:
		population += amount
	else:
		ai_population += amount
	population_changed.emit()

func remove_population(amount: int, team: int = 0) -> void:
	if team == 0:
		population -= amount
	else:
		ai_population -= amount
	population_changed.emit()

func increase_population_cap(amount: int, team: int = 0) -> void:
	if team == 0:
		population_cap += amount
	else:
		ai_population_cap += amount
	population_changed.emit()

func can_add_population(team: int = 0) -> bool:
	if team == 0:
		return population < population_cap
	else:
		return ai_population < ai_population_cap

func get_population(team: int = 0) -> int:
	return population if team == 0 else ai_population

func get_population_cap(team: int = 0) -> int:
	return population_cap if team == 0 else ai_population_cap

# Victory check
func check_victory() -> void:
	if game_ended:
		return

	var player_tc_exists = false
	var ai_tc_exists = false

	for tc in get_tree().get_nodes_in_group("town_centers"):
		if tc.team == 0:
			player_tc_exists = true
		elif tc.team == 1:
			ai_tc_exists = true

	if not player_tc_exists:
		game_ended = true
		game_over.emit(1)  # AI wins
	elif not ai_tc_exists:
		game_ended = true
		game_over.emit(0)  # Player wins

func select_unit(unit: Node2D) -> void:
	if unit not in selected_units:
		selected_units.append(unit)
		unit.set_selected(true)

func deselect_unit(unit: Node2D) -> void:
	if unit in selected_units:
		selected_units.erase(unit)
		unit.set_selected(false)

func clear_selection() -> void:
	for unit in selected_units:
		if is_instance_valid(unit):
			unit.set_selected(false)
	selected_units.clear()

func start_building_placement(building_scene: PackedScene, ghost: Node2D) -> void:
	is_placing_building = true
	building_to_place = building_scene
	building_ghost = ghost

func cancel_building_placement() -> void:
	is_placing_building = false
	building_to_place = null
	if building_ghost:
		building_ghost.queue_free()
		building_ghost = null

func complete_building_placement() -> void:
	is_placing_building = false
	building_to_place = null
	building_ghost = null

func reset() -> void:
	resources = {"wood": 200, "food": 200, "gold": 0, "stone": 0}
	ai_resources = {"wood": 200, "food": 200, "gold": 0, "stone": 0}
	population = 3
	population_cap = 5
	ai_population = 0
	ai_population_cap = 5
	game_ended = false
	clear_selection()
	is_placing_building = false
	building_to_place = null
	building_ghost = null
	reset_market_prices()
