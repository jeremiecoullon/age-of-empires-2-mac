extends Node
class_name AIController

# =============================================================================
# AI Controller - Rule-Based System (Phase 3.1)
# =============================================================================
#
# Implements an AoE2-style rule-based AI system.
# Rules are independent - all matching rules fire each tick.
# Strategic numbers control behavior thresholds.
#
# See: docs/ai_player_designs/godot_rule_implementation.md
#
# =============================================================================

# Team constants (used by other systems)
const PLAYER_TEAM: int = 0
const AI_TEAM: int = 1

# Base positions
const AI_BASE_POSITION: Vector2 = Vector2(1700, 1700)
const PLAYER_BASE_POSITION: Vector2 = Vector2(480, 480)

# Starting units
const STARTING_VILLAGERS: int = 3

# Scene paths for spawning
const TC_SCENE: PackedScene = preload("res://scenes/buildings/town_center.tscn")
const HOUSE_SCENE: PackedScene = preload("res://scenes/buildings/house.tscn")
const VILLAGER_SCENE: PackedScene = preload("res://scenes/units/villager.tscn")

# Decision timing
const DECISION_INTERVAL: float = 0.5  # Evaluate rules every 0.5 seconds
const VILLAGER_ASSIGN_INTERVAL: float = 2.0  # Assign villagers every 2 seconds
const DEBUG_PRINT_INTERVAL: float = 10.0  # Print debug state every 10 seconds

var decision_timer: float = 0.0
var villager_assign_timer: float = 0.0
var debug_print_timer: float = 0.0

## Debug: Set to true to print AI state every 10 seconds
@export var debug_print_enabled: bool = true

# Game state wrapper
var game_state: AIGameState = null

# Rules
var rules: Array = []

# Strategic numbers - tunable AI parameters
var strategic_numbers: Dictionary = {
	# Resource gathering allocation (must sum to 100)
	"sn_food_gatherer_percentage": 60,
	"sn_wood_gatherer_percentage": 40,
	"sn_gold_gatherer_percentage": 0,
	"sn_stone_gatherer_percentage": 0,

	# Targets
	"sn_target_villagers": 20,

	# Building placement
	"sn_maximum_town_size": 24,

	# Attack settings
	"sn_minimum_attack_group_size": 5,
}

# Goals - state variables for rules
var goals: Dictionary = {}

# Timers - time-based triggers
var timers: Dictionary = {}


func _ready() -> void:
	# Spawn AI starting base
	_spawn_starting_base()

	# Initialize game state wrapper
	game_state = AIGameState.new()
	game_state.initialize(self, get_tree())

	# Create rules
	rules = AIRules.create_all_rules()


func _spawn_starting_base() -> void:
	# Get containers - find by path in main scene
	var main = get_tree().current_scene
	var buildings_container = main.get_node_or_null("Buildings")
	var units_container = main.get_node_or_null("Units")

	# Fallback to main scene if containers not found
	if not buildings_container:
		buildings_container = main
	if not units_container:
		units_container = main

	# Spawn Town Center
	var tc = TC_SCENE.instantiate()
	tc.global_position = AI_BASE_POSITION
	tc.team = AI_TEAM
	buildings_container.add_child(tc)

	# Spawn initial house for population cap
	var house = HOUSE_SCENE.instantiate()
	house.global_position = AI_BASE_POSITION + Vector2(-100, 0)
	house.team = AI_TEAM
	buildings_container.add_child(house)

	# Set AI population cap (TC gives 5, house gives 5 more)
	GameManager.ai_population_cap = 10

	# Spawn starting villagers
	var villager_offsets = [
		Vector2(40, 80),
		Vector2(-40, 80),
		Vector2(0, 100)
	]
	for i in range(STARTING_VILLAGERS):
		var villager = VILLAGER_SCENE.instantiate()
		villager.global_position = AI_BASE_POSITION + villager_offsets[i]
		villager.team = AI_TEAM
		units_container.add_child(villager)
		GameManager.add_population(1, AI_TEAM)


func _process(delta: float) -> void:
	if GameManager.game_ended:
		return

	# Decision loop
	decision_timer += delta
	if decision_timer >= DECISION_INTERVAL:
		decision_timer = 0.0
		_evaluate_rules()

	# Villager assignment loop (less frequent)
	villager_assign_timer += delta
	if villager_assign_timer >= VILLAGER_ASSIGN_INTERVAL:
		villager_assign_timer = 0.0
		_assign_villagers()

	# Debug print loop
	if debug_print_enabled:
		debug_print_timer += delta
		if debug_print_timer >= DEBUG_PRINT_INTERVAL:
			debug_print_timer = 0.0
			_print_debug_state()


func _evaluate_rules() -> void:
	# Refresh game state cache
	game_state.refresh()

	# Evaluate all rules
	for rule in rules:
		if rule.enabled and rule.conditions(game_state):
			rule.actions(game_state)

	# Execute queued actions
	game_state.execute_actions()


func _assign_villagers() -> void:
	# Get current villager distribution
	var villagers_by_task = game_state.get_villagers_by_task()
	var idle_villagers = villagers_by_task["idle"]

	if idle_villagers.is_empty():
		return

	# Get target percentages
	var food_pct = strategic_numbers["sn_food_gatherer_percentage"]
	var wood_pct = strategic_numbers["sn_wood_gatherer_percentage"]
	var gold_pct = strategic_numbers["sn_gold_gatherer_percentage"]
	var stone_pct = strategic_numbers["sn_stone_gatherer_percentage"]

	# Calculate current counts (excluding idle and builders)
	var food_count = villagers_by_task["food"].size()
	var wood_count = villagers_by_task["wood"].size()
	var gold_count = villagers_by_task["gold"].size()
	var stone_count = villagers_by_task["stone"].size()
	var total_gatherers = food_count + wood_count + gold_count + stone_count

	# Assign idle villagers to most needed resource
	for villager in idle_villagers:
		var target_resource = _get_most_needed_resource(
			food_count, wood_count, gold_count, stone_count,
			total_gatherers + 1,  # +1 for the villager we're about to assign
			food_pct, wood_pct, gold_pct, stone_pct
		)

		if target_resource != "":
			game_state.assign_villager_to_resource(villager, target_resource)
			# Update counts for next iteration
			match target_resource:
				"food":
					food_count += 1
				"wood":
					wood_count += 1
				"gold":
					gold_count += 1
				"stone":
					stone_count += 1
			total_gatherers += 1


func _get_most_needed_resource(
	food_count: int, wood_count: int, gold_count: int, stone_count: int,
	total: int,
	food_pct: int, wood_pct: int, gold_pct: int, stone_pct: int
) -> String:
	# Calculate how far each resource is from target percentage
	var food_target = (food_pct / 100.0) * total
	var wood_target = (wood_pct / 100.0) * total
	var gold_target = (gold_pct / 100.0) * total
	var stone_target = (stone_pct / 100.0) * total

	var food_deficit = food_target - food_count
	var wood_deficit = wood_target - wood_count
	var gold_deficit = gold_target - gold_count
	var stone_deficit = stone_target - stone_count

	# Return resource with largest deficit
	var max_deficit = -INF
	var target_resource = "food"  # Default

	if food_pct > 0 and food_deficit > max_deficit:
		max_deficit = food_deficit
		target_resource = "food"

	if wood_pct > 0 and wood_deficit > max_deficit:
		max_deficit = wood_deficit
		target_resource = "wood"

	if gold_pct > 0 and gold_deficit > max_deficit:
		max_deficit = gold_deficit
		target_resource = "gold"

	if stone_pct > 0 and stone_deficit > max_deficit:
		max_deficit = stone_deficit
		target_resource = "stone"

	return target_resource


# =============================================================================
# DEBUG METHODS (for testing/tuning)
# =============================================================================

func _print_debug_state() -> void:
	var game_time = Time.get_ticks_msec() / 1000.0

	# Get villager distribution
	var villagers_by_task = game_state.get_villagers_by_task()
	var food_gatherers = villagers_by_task["food"].size()
	var wood_gatherers = villagers_by_task["wood"].size()
	var gold_gatherers = villagers_by_task["gold"].size()
	var stone_gatherers = villagers_by_task["stone"].size()
	var idle_villagers = villagers_by_task["idle"].size()
	var builders = villagers_by_task["building"].size()

	# Get military breakdown
	var militia_count = game_state.get_unit_count("militia")
	var spearman_count = game_state.get_unit_count("spearman")
	var archer_count = game_state.get_unit_count("archer")
	var scout_count = game_state.get_unit_count("scout_cavalry")

	# Get building counts
	var tc_count = game_state.get_building_count("town_center")
	var house_count = game_state.get_building_count("house")
	var barracks_count = game_state.get_building_count("barracks")
	var farm_count = game_state.get_building_count("farm")
	var mill_count = game_state.get_building_count("mill")
	var lumber_camp_count = game_state.get_building_count("lumber_camp")
	var mining_camp_count = game_state.get_building_count("mining_camp")
	var market_count = game_state.get_building_count("market")

	# Format timers
	var timer_strs = []
	for timer_id in timers:
		var remaining = timers[timer_id] - game_time
		timer_strs.append("T%d: %.1fs" % [timer_id, remaining])
	var timers_str = ", ".join(timer_strs) if timer_strs.size() > 0 else "none"

	# Format goals
	var goal_strs = []
	for goal_id in goals:
		goal_strs.append("G%d=%d" % [goal_id, goals[goal_id]])
	var goals_str = ", ".join(goal_strs) if goal_strs.size() > 0 else "none"

	var separator = "======================================================================"
	print("")
	print(separator)
	print("AI DEBUG STATE @ %.1fs" % game_time)
	print(separator)
	print("")
	print("RESOURCES:")
	print("  Food: %d | Wood: %d | Gold: %d | Stone: %d" % [
		game_state.get_resource("food"),
		game_state.get_resource("wood"),
		game_state.get_resource("gold"),
		game_state.get_resource("stone")
	])
	print("")
	print("POPULATION: %d / %d (headroom: %d)" % [
		game_state.get_population(),
		game_state.get_population_cap(),
		game_state.get_housing_headroom()
	])
	print("  Villagers: %d total" % game_state.get_civilian_population())
	print("    - Food: %d, Wood: %d, Gold: %d, Stone: %d" % [food_gatherers, wood_gatherers, gold_gatherers, stone_gatherers])
	print("    - Idle: %d, Building: %d" % [idle_villagers, builders])
	print("  Military: %d total" % game_state.get_military_population())
	print("    - Militia: %d, Spearman: %d, Archer: %d, Scout: %d" % [militia_count, spearman_count, archer_count, scout_count])
	print("")
	print("BUILDINGS:")
	print("  TC: %d | Houses: %d | Barracks: %d" % [tc_count, house_count, barracks_count])
	print("  Farms: %d | Mill: %d | Lumber Camp: %d | Mining Camp: %d" % [farm_count, mill_count, lumber_camp_count, mining_camp_count])
	print("  Market: %d" % market_count)
	print("")
	print("STRATEGIC NUMBERS:")
	print("  Food%%: %d | Wood%%: %d | Gold%%: %d | Stone%%: %d" % [
		strategic_numbers["sn_food_gatherer_percentage"],
		strategic_numbers["sn_wood_gatherer_percentage"],
		strategic_numbers["sn_gold_gatherer_percentage"],
		strategic_numbers["sn_stone_gatherer_percentage"]
	])
	print("  Target Villagers: %d | Min Attack Group: %d" % [
		strategic_numbers["sn_target_villagers"],
		strategic_numbers["sn_minimum_attack_group_size"]
	])
	print("")
	print("STATE:")
	print("  Under Attack: %s" % str(game_state.is_under_attack()))
	print("  Timers: %s" % timers_str)
	print("  Goals: %s" % goals_str)
	print("")
	print("CAN AFFORD:")
	print("  Train Villager: %s | Train Militia: %s" % [
		str(game_state.can_train("villager")),
		str(game_state.can_train("militia"))
	])
	print("  Build House: %s | Build Barracks: %s" % [
		str(game_state.can_build("house")),
		str(game_state.can_build("barracks"))
	])
	print(separator)
	print("")


func get_status() -> Dictionary:
	return {
		"villagers": game_state.get_civilian_population(),
		"military": game_state.get_military_population(),
		"food": game_state.get_resource("food"),
		"wood": game_state.get_resource("wood"),
		"gold": game_state.get_resource("gold"),
		"stone": game_state.get_resource("stone"),
		"housing_headroom": game_state.get_housing_headroom(),
		"barracks_count": game_state.get_building_count("barracks"),
		"under_attack": game_state.is_under_attack(),
	}
