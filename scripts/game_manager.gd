extends Node

# Resource pools - dictionary-based for extensibility
var resources: Dictionary = {"wood": 200, "food": 200, "gold": 0, "stone": 0}
var ai_resources: Dictionary = {"wood": 200, "food": 200, "gold": 0, "stone": 0}

# Population
var population: int = 3
var population_cap: int = 5
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
