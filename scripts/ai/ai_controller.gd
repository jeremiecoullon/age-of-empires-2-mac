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

# Economy caps
const STOCKPILE_CAP: int = 400  # Stop gathering a resource when stockpile exceeds this

var decision_timer: float = 0.0
var villager_assign_timer: float = 0.0
var debug_print_timer: float = 0.0
var game_time_elapsed: float = 0.0  # Tracks game time (respects Engine.time_scale)

## Debug: Set to true to print AI logs to terminal
@export var debug_print_enabled: bool = false


func _log(message: String) -> void:
	## Central logging method. Prints to stdout (if enabled) and calls log callback if set.
	if debug_print_enabled:
		print(message)
	# Check for log callback (set by test controller)
	if has_meta("log_callback"):
		var callback = get_meta("log_callback")
		if callback is Callable:
			callback.call(message)

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

	# Gathering efficiency - max villagers per resource node before preferring other nodes
	"sn_max_gatherers_per_resource": 2,
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

	# Track game time
	game_time_elapsed += delta

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

	# Track which rules fired for logging
	var fired_rules: Array[String] = []
	var skipped_rules: Dictionary = {}  # rule_name -> reason

	# Evaluate all rules
	for rule in rules:
		if not rule.enabled:
			continue

		if rule.conditions(game_state):
			rule.actions(game_state)
			fired_rules.append(rule.rule_name)
		else:
			# Get reason why rule didn't fire (for key rules)
			var reason = _get_rule_skip_reason(rule.rule_name, rule)
			skipped_rules[rule.rule_name] = reason

	# Execute queued actions
	game_state.execute_actions()

	# Log rule evaluation results
	if debug_print_enabled:
		_log_rule_tick(fired_rules, skipped_rules)


func _get_rule_skip_reason(rule_name: String, rule = null) -> String:
	## Returns a brief reason why a rule's conditions returned false.
	## For common rules, provides specific diagnostics.
	## Pass the rule object to check internal state (like _queued flags).
	match rule_name:
		"build_house":
			var headroom = game_state.get_housing_headroom()
			if headroom >= 5:
				return "headroom_%d" % headroom
			var can_build_reason = game_state.get_can_build_reason("house")
			if can_build_reason != "ok":
				return can_build_reason
		"train_villager":
			var target = game_state.get_sn("sn_target_villagers")
			var current = game_state.get_civilian_population()
			if current >= target:
				return "at_target_%d/%d" % [current, target]
			if game_state.get_building_count("barracks") >= 1 \
				and game_state.get_military_population() < 3 \
				and current >= 10:
				return "paused_for_military_%d/3" % game_state.get_military_population()
			return game_state.get_can_train_reason("villager")
		"build_barracks":
			if game_state.get_building_count("barracks") > 0:
				return "already_have_barracks"
			# Check if queued (rule has internal state)
			if rule and rule.get("_barracks_queued"):
				return "already_queued"
			var pop = game_state.get_civilian_population()
			if pop < 5:
				return "need_5_villagers_have_%d" % pop
			return game_state.get_can_build_reason("barracks")
		"build_mill":
			if game_state.get_building_count("mill") > 0:
				return "already_have_mill"
			# Check if queued (rule has internal state)
			if rule and rule.get("_mill_queued"):
				return "already_queued"
			if not game_state.needs_mill():
				return "not_needed"
			return game_state.get_can_build_reason("mill")
		"build_lumber_camp":
			if game_state.get_building_count("lumber_camp") > 0:
				return "already_have_lumber_camp"
			# Check if queued (rule has internal state)
			if rule and rule.get("_lumber_camp_queued"):
				return "already_queued"
			if not game_state.needs_lumber_camp():
				return "not_needed"
			return game_state.get_can_build_reason("lumber_camp")
		"train_militia":
			if game_state.get_building_count("barracks") < 1:
				return "no_barracks"
			return game_state.get_can_train_reason("militia")
		"train_spearman":
			if game_state.get_building_count("barracks") < 1:
				return "no_barracks"
			if game_state.get_enemy_cavalry_count() == 0:
				return "no_enemy_cavalry"
			return game_state.get_can_train_reason("spearman")
		"train_archer":
			if game_state.get_building_count("archery_range") < 1:
				return "no_archery_range"
			var ranged = game_state.get_unit_count("ranged")
			var infantry = game_state.get_unit_count("infantry")
			if ranged >= infantry + 2:
				return "enough_ranged_%d_vs_%d_infantry" % [ranged, infantry]
			return game_state.get_can_train_reason("archer")
		"train_skirmisher":
			if game_state.get_building_count("archery_range") < 1:
				return "no_archery_range"
			if game_state.get_enemy_archer_count() == 0:
				return "no_enemy_archers"
			return game_state.get_can_train_reason("skirmisher")
		"train_scout_cavalry":
			if game_state.get_building_count("stable") < 1:
				return "no_stable"
			var scouts = game_state.get_unit_count("scout_cavalry")
			if scouts >= 3:
				return "have_%d_scouts" % scouts
			return game_state.get_can_train_reason("scout_cavalry")
		"train_cavalry_archer":
			if game_state.get_building_count("stable") < 1:
				return "no_stable"
			if game_state.get_resource("gold") <= 150:
				return "not_enough_gold"
			if game_state.get_military_population() < 3:
				return "need_3_military_first"
			return game_state.get_can_train_reason("cavalry_archer")
		"build_archery_range":
			if game_state.get_building_count("archery_range") > 0:
				return "already_have_archery_range"
			if game_state.get_building_count("barracks") < 1:
				return "need_barracks_first"
			var pop = game_state.get_civilian_population()
			if pop < 8:
				return "need_8_villagers_have_%d" % pop
			return game_state.get_can_build_reason("archery_range")
		"build_stable":
			if game_state.get_building_count("stable") > 0:
				return "already_have_stable"
			if game_state.get_building_count("barracks") < 1:
				return "need_barracks_first"
			var pop = game_state.get_civilian_population()
			if pop < 10:
				return "need_10_villagers_have_%d" % pop
			return game_state.get_can_build_reason("stable")
		"defend_base":
			if not game_state.is_under_attack():
				return "not_under_attack"
			if game_state.get_military_population() == 0:
				return "no_military"
		"scouting":
			var scout_count = game_state.get_unit_count("scout_cavalry")
			if scout_count == 0:
				return "no_scouts"
			if game_state.get_idle_scout() == null:
				return "scouts_busy_%d" % scout_count
		"attack":
			var min_military = game_state.get_sn("sn_minimum_attack_group_size")
			var current_military = game_state.get_military_population()
			if current_military < min_military:
				return "need_%d_military_have_%d" % [min_military, current_military]
			if not game_state.is_timer_triggered(1):
				return "timer_not_ready"
			if game_state.is_under_attack():
				return "under_attack"

	return "conditions_false"


func _log_rule_tick(fired: Array[String], skipped: Dictionary) -> void:
	# Only log when something fires (reduces noise)
	# The skipped rules still get logged to explain why other rules didn't fire
	if fired.is_empty():
		return

	var log_data = {
		"t": snappedf(game_time_elapsed, 0.1),
		"fired": fired,
		"skipped": skipped
	}
	_log("RULE_TICK|" + JSON.stringify(log_data))


func _get_rule_blockers() -> Dictionary:
	## Returns why key rules can't fire right now.
	## Used in periodic AI_STATE output for debugging.
	var blockers = {}

	# Check key economy/military rules
	var key_rules = [
		"build_barracks", "build_archery_range", "build_stable",
		"build_mill", "build_lumber_camp",
		"train_militia", "train_archer", "train_scout_cavalry",
		"defend_base", "attack"
	]
	for rule in rules:
		if not rule.enabled:
			continue
		# Only report blockers for important rules that aren't firing
		if rule.rule_name in key_rules:
			if not rule.conditions(game_state):
				blockers[rule.rule_name] = _get_rule_skip_reason(rule.rule_name, rule)

	return blockers


func _assign_villagers() -> void:
	# Get current villager distribution
	var villagers_by_task = game_state.get_villagers_by_task()
	var idle_villagers = villagers_by_task["idle"]

	if idle_villagers.is_empty():
		return

	# Log idle villager assignment attempt
	if debug_print_enabled:
		_log("AI_ASSIGN|{\"t\":%.1f,\"idle_count\":%d,\"assigning\":true}" % [game_time_elapsed, idle_villagers.size()])

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
	# Check resource availability (depletion awareness)
	var food_available = game_state.has_gatherable_resources("food")
	var wood_available = game_state.has_gatherable_resources("wood")
	var gold_available = game_state.has_gatherable_resources("gold")
	var stone_available = game_state.has_gatherable_resources("stone")

	# Check stockpile caps - don't over-gather when stockpile is high
	var food_capped = game_state.get_resource("food") > STOCKPILE_CAP
	var wood_capped = game_state.get_resource("wood") > STOCKPILE_CAP
	var gold_capped = game_state.get_resource("gold") > STOCKPILE_CAP
	var stone_capped = game_state.get_resource("stone") > STOCKPILE_CAP

	# Apply effective percentages (0 if depleted or capped)
	var eff_food_pct = food_pct if (food_available and not food_capped) else 0
	var eff_wood_pct = wood_pct if (wood_available and not wood_capped) else 0
	var eff_gold_pct = gold_pct if (gold_available and not gold_capped) else 0
	var eff_stone_pct = stone_pct if (stone_available and not stone_capped) else 0

	# Edge case: if ALL resources are capped or depleted, allow gathering the lowest stockpile
	# (prevents all villagers going idle). Returns "" if all resources are truly depleted.
	var total_eff_pct = eff_food_pct + eff_wood_pct + eff_gold_pct + eff_stone_pct
	if total_eff_pct == 0:
		var lowest_stockpile = INF
		var lowest_resource = ""
		if food_available and game_state.get_resource("food") < lowest_stockpile:
			lowest_stockpile = game_state.get_resource("food")
			lowest_resource = "food"
		if wood_available and game_state.get_resource("wood") < lowest_stockpile:
			lowest_stockpile = game_state.get_resource("wood")
			lowest_resource = "wood"
		if gold_available and game_state.get_resource("gold") < lowest_stockpile:
			lowest_stockpile = game_state.get_resource("gold")
			lowest_resource = "gold"
		if stone_available and game_state.get_resource("stone") < lowest_stockpile:
			lowest_stockpile = game_state.get_resource("stone")
			lowest_resource = "stone"
		return lowest_resource

	# Normalize effective percentages so they sum to 100%
	# This ensures villagers are fully distributed among available resources
	var norm_food = (eff_food_pct / float(total_eff_pct)) * 100.0
	var norm_wood = (eff_wood_pct / float(total_eff_pct)) * 100.0
	var norm_gold = (eff_gold_pct / float(total_eff_pct)) * 100.0
	var norm_stone = (eff_stone_pct / float(total_eff_pct)) * 100.0

	# Calculate how far each resource is from target percentage
	var food_target = (norm_food / 100.0) * total
	var wood_target = (norm_wood / 100.0) * total
	var gold_target = (norm_gold / 100.0) * total
	var stone_target = (norm_stone / 100.0) * total

	var food_deficit = food_target - food_count
	var wood_deficit = wood_target - wood_count
	var gold_deficit = gold_target - gold_count
	var stone_deficit = stone_target - stone_count

	# Return resource with largest deficit
	var max_deficit = -INF
	var target_resource = "food"  # Default

	if eff_food_pct > 0 and food_deficit > max_deficit:
		max_deficit = food_deficit
		target_resource = "food"

	if eff_wood_pct > 0 and wood_deficit > max_deficit:
		max_deficit = wood_deficit
		target_resource = "wood"

	if eff_gold_pct > 0 and gold_deficit > max_deficit:
		max_deficit = gold_deficit
		target_resource = "gold"

	if eff_stone_pct > 0 and stone_deficit > max_deficit:
		max_deficit = stone_deficit
		target_resource = "stone"

	return target_resource


# =============================================================================
# DEBUG METHODS (for testing/tuning)
# =============================================================================

func _print_debug_state() -> void:
	var game_time = game_time_elapsed

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
	var skirmisher_count = game_state.get_unit_count("skirmisher")
	var scout_count = game_state.get_unit_count("scout_cavalry")
	var cav_archer_count = game_state.get_unit_count("cavalry_archer")

	# Get building counts
	var tc_count = game_state.get_building_count("town_center")
	var house_count = game_state.get_building_count("house")
	var barracks_count = game_state.get_building_count("barracks")
	var archery_range_count = game_state.get_building_count("archery_range")
	var stable_count = game_state.get_building_count("stable")
	var farm_count = game_state.get_building_count("farm")
	var mill_count = game_state.get_building_count("mill")
	var lumber_camp_count = game_state.get_building_count("lumber_camp")
	var mining_camp_count = game_state.get_building_count("mining_camp")
	var market_count = game_state.get_building_count("market")

	# Format timers as dict
	var timers_remaining: Dictionary = {}
	for timer_id in timers:
		timers_remaining[timer_id] = snappedf(timers[timer_id] - game_time, 0.1)

	# Get gatherer efficiency metrics
	var gatherer_distances = game_state.get_gatherer_distances()
	var villagers_per_target = game_state.get_villagers_per_target()

	# Build state dictionary
	var state: Dictionary = {
		"t": snappedf(game_time, 0.1),
		"resources": {
			"food": game_state.get_resource("food"),
			"wood": game_state.get_resource("wood"),
			"gold": game_state.get_resource("gold"),
			"stone": game_state.get_resource("stone"),
		},
		"economy": {
			"depleted": {
				"food": not game_state.has_gatherable_resources("food"),
				"wood": not game_state.has_gatherable_resources("wood"),
				"gold": not game_state.has_gatherable_resources("gold"),
				"stone": not game_state.has_gatherable_resources("stone"),
			},
			"capped": {
				"food": game_state.get_resource("food") > STOCKPILE_CAP,
				"wood": game_state.get_resource("wood") > STOCKPILE_CAP,
				"gold": game_state.get_resource("gold") > STOCKPILE_CAP,
				"stone": game_state.get_resource("stone") > STOCKPILE_CAP,
			}
		},
		"population": {
			"current": game_state.get_population(),
			"cap": game_state.get_population_cap(),
			"headroom": game_state.get_housing_headroom(),
		},
		"villagers": {
			"total": game_state.get_civilian_population(),
			"food": food_gatherers,
			"wood": wood_gatherers,
			"gold": gold_gatherers,
			"stone": stone_gatherers,
			"idle": idle_villagers,
			"building": builders,
		},
		"military": {
			"total": game_state.get_military_population(),
			"militia": militia_count,
			"spearman": spearman_count,
			"archer": archer_count,
			"skirmisher": skirmisher_count,
			"scout": scout_count,
			"cav_archer": cav_archer_count,
		},
		"buildings": {
			"town_center": tc_count,
			"house": house_count,
			"barracks": barracks_count,
			"archery_range": archery_range_count,
			"stable": stable_count,
			"farm": farm_count,
			"mill": mill_count,
			"lumber_camp": lumber_camp_count,
			"mining_camp": mining_camp_count,
			"market": market_count,
		},
		"strategic_numbers": {
			"food_pct": strategic_numbers["sn_food_gatherer_percentage"],
			"wood_pct": strategic_numbers["sn_wood_gatherer_percentage"],
			"gold_pct": strategic_numbers["sn_gold_gatherer_percentage"],
			"stone_pct": strategic_numbers["sn_stone_gatherer_percentage"],
			"target_villagers": strategic_numbers["sn_target_villagers"],
			"min_attack_group": strategic_numbers["sn_minimum_attack_group_size"],
		},
		"state": {
			"under_attack": game_state.is_under_attack(),
			"timers": timers_remaining,
			"goals": goals.duplicate(),
		},
		"can_afford": {
			"villager": game_state.can_train("villager"),
			"militia": game_state.can_train("militia"),
			"house": game_state.can_build("house"),
			"barracks": game_state.can_build("barracks"),
		},
		"rule_blockers": _get_rule_blockers(),
		"efficiency": {
			"avg_food_drop_dist": snappedf(gatherer_distances["food"], 1) if gatherer_distances["food"] != INF else -1,
			"avg_wood_drop_dist": snappedf(gatherer_distances["wood"], 1) if gatherer_distances["wood"] != INF else -1,
			"avg_gold_drop_dist": snappedf(gatherer_distances["gold"], 1) if gatherer_distances["gold"] != INF else -1,
			"avg_stone_drop_dist": snappedf(gatherer_distances["stone"], 1) if gatherer_distances["stone"] != INF else -1,
			"max_on_same_food": villagers_per_target["food_max"],
			"max_on_same_wood": villagers_per_target["wood_max"],
			"max_on_same_gold": villagers_per_target["gold_max"],
			"max_on_same_stone": villagers_per_target["stone_max"],
		},
	}

	_log("AI_STATE|" + JSON.stringify(state))


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
