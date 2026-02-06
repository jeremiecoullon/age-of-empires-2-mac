extends Node

# Age constants
const AGE_DARK: int = 0
const AGE_FEUDAL: int = 1
const AGE_CASTLE: int = 2
const AGE_IMPERIAL: int = 3

const AGE_NAMES: Array[String] = ["Dark Age", "Feudal Age", "Castle Age", "Imperial Age"]

# Age advancement costs and research times
const AGE_COSTS: Array[Dictionary] = [
	{},  # Dark Age (starting age, no cost)
	{"food": 500},  # Feudal Age
	{"food": 800, "gold": 200},  # Castle Age
	{"food": 1000, "gold": 800},  # Imperial Age
]

const AGE_RESEARCH_TIMES: Array[float] = [
	0.0,   # Dark Age
	130.0, # Feudal Age (AoE2: ~130 seconds)
	160.0, # Castle Age (AoE2: ~160 seconds)
	190.0, # Imperial Age (AoE2: ~190 seconds)
]

# Qualifying building groups per target age
# To advance to Feudal: need 2 from Dark Age qualifying buildings
# To advance to Castle: need 2 from Feudal Age qualifying buildings
# To advance to Imperial: need 2 from Castle Age qualifying buildings
const AGE_QUALIFYING_GROUPS: Array[Array] = [
	[],  # Dark Age (starting age)
	["barracks", "mills", "lumber_camps", "mining_camps"],  # For Feudal
	["archery_ranges", "stables", "markets"],  # For Castle
	[],  # For Imperial (placeholder - Castle Age buildings not yet implemented)
]

const AGE_REQUIRED_QUALIFYING_COUNT: int = 2

# Age state per player
var player_age: int = AGE_DARK
var ai_age: int = AGE_DARK

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
signal player_under_attack(attack_type: String)  # "military", "villager", or "building"
signal age_changed(team: int, new_age: int)  # Emitted when a player advances to a new age

var game_ended: bool = false

# Attack notification throttling
const ATTACK_NOTIFY_COOLDOWN: float = 5.0  # Don't spam notifications
var _last_military_attack_time: float = -ATTACK_NOTIFY_COOLDOWN
var _last_civilian_attack_time: float = -ATTACK_NOTIFY_COOLDOWN

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

# Age functions
func get_age(team: int = 0) -> int:
	return player_age if team == 0 else ai_age

func set_age(age: int, team: int = 0) -> void:
	if team == 0:
		player_age = age
	else:
		ai_age = age
	age_changed.emit(team, age)

func get_age_name(team: int = 0) -> String:
	var age = get_age(team)
	return AGE_NAMES[age] if age < AGE_NAMES.size() else "Unknown"

func can_advance_age(team: int = 0) -> bool:
	var current_age = get_age(team)
	if current_age >= AGE_IMPERIAL:
		return false  # Already at max age
	var target_age = current_age + 1
	# Check qualifying building count
	if get_qualifying_building_count(target_age, team) < AGE_REQUIRED_QUALIFYING_COUNT:
		return false
	# Check resources
	if not can_afford_age(target_age, team):
		return false
	return true

func get_qualifying_building_count(target_age: int, team: int = 0) -> int:
	# Counts distinct building types (groups) with at least one functional building.
	# AoE2 requires 2 *different* building types, not 2 buildings of the same type.
	if target_age <= 0 or target_age >= AGE_QUALIFYING_GROUPS.size():
		return 0
	var qualifying_groups: Array = AGE_QUALIFYING_GROUPS[target_age]
	var distinct_count: int = 0
	for group_name in qualifying_groups:
		for building in get_tree().get_nodes_in_group(group_name):
			if building.team == team and building.is_functional():
				distinct_count += 1
				break
	return distinct_count

func can_afford_age(target_age: int, team: int = 0) -> bool:
	if target_age <= 0 or target_age >= AGE_COSTS.size():
		return false
	var costs: Dictionary = AGE_COSTS[target_age]
	var pool = resources if team == 0 else ai_resources
	for resource_type in costs:
		if pool[resource_type] < costs[resource_type]:
			return false
	return true

func spend_age_cost(target_age: int, team: int = 0) -> bool:
	if not can_afford_age(target_age, team):
		return false
	var costs: Dictionary = AGE_COSTS[target_age]
	for resource_type in costs:
		spend_resource(resource_type, costs[resource_type], team)
	return true

func refund_age_cost(target_age: int, team: int = 0) -> void:
	if target_age <= 0 or target_age >= AGE_COSTS.size():
		return
	var costs: Dictionary = AGE_COSTS[target_age]
	for resource_type in costs:
		add_resource(resource_type, costs[resource_type], team)

# Victory check
func check_victory() -> void:
	if game_ended:
		return

	var player_tc_exists = false
	var ai_tc_exists = false

	for tc in get_tree().get_nodes_in_group("town_centers"):
		# Skip destroyed TCs (still in group until queue_free completes)
		if tc.is_destroyed:
			continue
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
	player_age = AGE_DARK
	ai_age = AGE_DARK
	game_ended = false
	clear_selection()
	is_placing_building = false
	building_to_place = null
	building_ghost = null
	reset_market_prices()
	_last_military_attack_time = -ATTACK_NOTIFY_COOLDOWN
	_last_civilian_attack_time = -ATTACK_NOTIFY_COOLDOWN
	# Reset fog of war if it exists
	var fog = get_tree().get_first_node_in_group("fog_of_war") if get_tree() else null
	if fog and fog.has_method("reset"):
		fog.reset()

## Called when a unit takes damage. Emits player_under_attack signal if player unit attacked.
## Automatically connected to unit.damaged signal when units are registered.
func notify_unit_damaged(unit: Node, amount: int, attacker: Node2D) -> void:
	if not is_instance_valid(unit):
		return
	if unit.team != 0:  # Only notify for player units
		return
	if game_ended:
		return
	# Don't notify for friendly fire (e.g. villager hunting own sheep)
	if is_instance_valid(attacker) and "team" in attacker and attacker.team == unit.team:
		return

	var current_time = Time.get_ticks_msec() / 1000.0
	var attack_type: String

	# Determine attack type based on unit type
	if unit.is_in_group("military"):
		attack_type = "military"
		if current_time - _last_military_attack_time < ATTACK_NOTIFY_COOLDOWN:
			return  # Throttled
		_last_military_attack_time = current_time
	else:
		attack_type = "villager"
		if current_time - _last_civilian_attack_time < ATTACK_NOTIFY_COOLDOWN:
			return  # Throttled
		_last_civilian_attack_time = current_time

	player_under_attack.emit(attack_type)

## Called when a building takes damage. Emits player_under_attack signal if player building attacked.
func notify_building_damaged(building: Node, amount: int, attacker: Node2D) -> void:
	if not is_instance_valid(building):
		return
	if building.team != 0:  # Only notify for player buildings
		return
	if game_ended:
		return
	# Don't notify for friendly fire
	if is_instance_valid(attacker) and "team" in attacker and attacker.team == building.team:
		return

	var current_time = Time.get_ticks_msec() / 1000.0

	# Buildings use civilian attack notification
	if current_time - _last_civilian_attack_time < ATTACK_NOTIFY_COOLDOWN:
		return  # Throttled
	_last_civilian_attack_time = current_time

	player_under_attack.emit("building")
