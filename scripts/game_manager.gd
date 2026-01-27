extends Node

# Player resource counts
var wood: int = 200
var food: int = 200

# Player population
var population: int = 3
var population_cap: int = 5

# AI resource counts
var ai_wood: int = 200
var ai_food: int = 200

# AI population
var ai_population: int = 0
var ai_population_cap: int = 5

# Signals
signal resources_changed
signal population_changed
signal game_over(winner: int)  # 0 = player wins, 1 = AI wins

var game_ended: bool = false

# Selected units
var selected_units: Array = []

# Building placement mode
var is_placing_building: bool = false
var building_to_place: PackedScene = null
var building_ghost: Node2D = null

func add_wood(amount: int) -> void:
	wood += amount
	resources_changed.emit()

func add_food(amount: int) -> void:
	food += amount
	resources_changed.emit()

func spend_wood(amount: int) -> bool:
	if wood >= amount:
		wood -= amount
		resources_changed.emit()
		return true
	return false

func spend_food(amount: int) -> bool:
	if food >= amount:
		food -= amount
		resources_changed.emit()
		return true
	return false

func can_afford_wood(amount: int) -> bool:
	return wood >= amount

func can_afford_food(amount: int) -> bool:
	return food >= amount

func add_population(amount: int) -> void:
	population += amount
	population_changed.emit()

func remove_population(amount: int) -> void:
	population -= amount
	population_changed.emit()

func increase_population_cap(amount: int) -> void:
	population_cap += amount
	population_changed.emit()

func can_add_population() -> bool:
	return population < population_cap

# AI Resource functions
func ai_add_wood(amount: int) -> void:
	ai_wood += amount

func ai_add_food(amount: int) -> void:
	ai_food += amount

func ai_spend_wood(amount: int) -> bool:
	if ai_wood >= amount:
		ai_wood -= amount
		return true
	return false

func ai_spend_food(amount: int) -> bool:
	if ai_food >= amount:
		ai_food -= amount
		return true
	return false

func ai_can_afford_wood(amount: int) -> bool:
	return ai_wood >= amount

func ai_can_afford_food(amount: int) -> bool:
	return ai_food >= amount

func ai_add_population(amount: int) -> void:
	ai_population += amount

func ai_remove_population(amount: int) -> void:
	ai_population -= amount

func ai_increase_population_cap(amount: int) -> void:
	ai_population_cap += amount

func ai_can_add_population() -> bool:
	return ai_population < ai_population_cap

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
	wood = 200
	food = 200
	population = 3
	population_cap = 5
	ai_wood = 200
	ai_food = 200
	ai_population = 0
	ai_population_cap = 5
	game_ended = false
	clear_selection()
	is_placing_building = false
	building_to_place = null
	building_ghost = null
