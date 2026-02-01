extends Node
## AI Tests - Tests for AI Controller economic and military decisions
##
## Phase 2C tests verify:
## - Villager training decisions
## - Villager allocation to resources
## - Farm building decisions
## - Mill building decisions
## - Military building variety (Archery Range, Stable)
## - Mixed army training decisions
## - Attack threshold logic
## - Building rebuilding logic
##
## Phase 3A tests verify:
## - Build order system
## - Build order step execution
## - Continuous villager production (TC queue maintenance)
## - Production building scaling (multiple barracks/ranges/stables)
## - Floating resource detection
## - Idle villager reassignment
##
## Phase 3B tests verify:
## - Scouting system initialization and state management
## - Enemy base tracking
## - Army composition tracking
## - Threat assessment levels
## - Building type identification
##
## Phase 3C tests verify:
## - Counter-unit production logic
## - Army composition goal updates
## - Attack timing (strength comparison, vulnerability checks)
## - Target prioritization scoring
## - Retreat behavior (HP threshold, state checking)
## - Focus fire coordination
##
## Phase 3D tests verify:
## - Ranged unit kiting (is_ranged_unit detection, threat detection, kiting_units tracking)
## - Villager flee behavior (fleeing_villagers tracking)
## - Town Bell system (activation, cooldown, thresholds)
## - Split attention (harass squad setup, can_split_attention logic)
## - Reinforcement waves (main_army tracking, rally points)
## - Helper functions (idle/patrolling detection, constants)

class_name TestAI

var runner: TestRunner

# AI controller instance for testing
var ai_controller: AIController

const AI_TEAM: int = 1


func _init(test_runner: TestRunner) -> void:
	runner = test_runner


func get_all_tests() -> Array[Callable]:
	## Returns all test methods to run
	return [
		# Villager allocation tests
		test_get_needed_resource_defaults_to_food,
		test_get_needed_resource_returns_highest_deficit,
		test_get_needed_resource_emergency_food,
		test_get_needed_resource_emergency_wood,
		# Farm decision tests
		test_should_build_farm_false_at_max_farms,
		test_should_build_farm_false_without_wood,
		test_should_build_farm_true_when_no_natural_food,
		test_count_farms_returns_ai_farms_only,
		# Attack threshold tests
		test_should_attack_false_without_villagers,
		test_should_attack_false_without_military,
		test_should_attack_false_after_attacking,
		test_should_attack_true_with_economy_and_military,
		# Building check tests
		test_has_barracks_detects_ai_barracks,
		test_has_barracks_ignores_player_barracks,
		test_count_barracks_counts_multiple,
		test_has_archery_range_detects_ai_range,
		test_has_stable_detects_ai_stable,
		test_has_mill_detects_ai_mill,
		# Market decision tests
		test_should_build_market_false_without_surplus,
		test_should_build_market_true_with_surplus_and_low_gold,
		# Phase 3A: Build order tests
		test_build_order_creates_steps,
		test_build_order_dark_age_has_villager_steps,
		test_build_order_dark_age_has_building_steps,
		# Phase 3A: Continuous villager production tests
		test_is_floating_resources_false_when_low,
		test_is_floating_resources_true_when_high,
		# Phase 3A: Production building scaling tests
		test_count_archery_ranges_counts_ai_only,
		test_count_stables_counts_ai_only,
		# Phase 3B: Scouting system tests
		test_scout_state_starts_idle,
		test_scout_found_enemy_base_initially_false,
		test_has_scouted_enemy_base_returns_false_initially,
		test_get_enemy_base_position_returns_default_when_not_scouted,
		# Phase 3B: Enemy tracking tests
		test_estimated_enemy_army_starts_zero,
		test_get_enemy_dominant_unit_type_defaults_to_militia,
		test_known_enemy_buildings_starts_empty,
		# Phase 3B: Threat assessment tests
		test_threat_level_starts_zero,
		test_get_threat_level_returns_current_value,
		test_enemy_has_more_returns_false_when_equal,
		test_enemy_has_more_returns_true_when_enemy_has_more,
		test_building_type_string_returns_correct_types,
		# Phase 3C: Counter-unit production tests
		test_get_counter_for_unit_returns_correct_counters,
		test_get_counter_for_unit_defaults_to_militia,
		test_get_counter_unit_priority_returns_default_with_low_intel,
		test_get_counter_unit_priority_counters_archers_with_skirmishers,
		test_get_counter_unit_priority_counters_cavalry_with_spearmen,
		# Phase 3C: Army composition goal tests
		test_army_composition_goals_has_default_ratios,
		test_update_army_composition_goals_adjusts_for_ranged_enemy,
		test_update_army_composition_goals_adjusts_for_cavalry_enemy,
		test_update_army_composition_goals_adjusts_for_infantry_enemy,
		# Phase 3C: Attack timing tests
		test_get_military_strength_counts_ai_units,
		test_get_military_strength_weights_unit_types,
		test_get_enemy_strength_estimate_uses_estimated_army,
		test_has_military_advantage_requires_threshold,
		test_is_enemy_vulnerable_true_when_low_military,
		test_is_enemy_vulnerable_true_when_villagers_seen_recently,
		# Phase 3C: Target prioritization tests
		test_prioritize_target_prefers_villagers,
		test_prioritize_target_prefers_ranged_over_military,
		test_prioritize_target_prefers_low_hp,
		test_prioritize_target_returns_null_for_empty_list,
		# Phase 3C: Retreat behavior tests
		test_is_unit_attacking_returns_false_for_idle_unit,
		test_should_unit_retreat_false_at_full_hp,
		test_should_unit_retreat_true_at_low_hp_in_combat,
		test_retreating_units_starts_empty,
		# Phase 3C: Focus fire tests
		test_count_units_attacking_target_returns_zero_with_no_attackers,
		test_get_attackers_on_target_delegates_to_count,
		test_find_focus_fire_target_returns_null_with_no_enemies,
		# Phase 3D: Ranged unit kiting tests
		test_is_ranged_unit_returns_true_for_archer,
		test_is_ranged_unit_returns_true_for_skirmisher,
		test_is_ranged_unit_returns_true_for_cavalry_archer,
		test_is_ranged_unit_returns_false_for_militia,
		test_is_ranged_unit_returns_false_for_spearman,
		test_is_ranged_unit_returns_false_for_scout_cavalry,
		test_kiting_units_starts_empty,
		test_get_nearest_melee_threat_returns_null_when_no_enemies,
		# Phase 3D: Villager flee behavior tests
		test_fleeing_villagers_starts_empty,
		# Phase 3D: Town Bell system tests
		test_town_bell_active_starts_false,
		test_town_bell_cooldown_timer_starts_at_zero,
		test_town_bell_threat_threshold_constant,
		test_town_bell_cooldown_constant,
		# Phase 3D: Split attention tests
		test_harass_squad_starts_empty,
		test_can_split_attention_returns_false_with_no_military,
		test_harass_force_size_constant,
		# Phase 3D: Reinforcement waves tests
		test_main_army_starts_empty,
		test_active_attack_position_starts_at_zero,
		test_reinforcement_rally_point_starts_at_zero,
		test_get_rally_point_returns_position_between_base_and_attack,
		# Phase 3D: Helper function tests
		test_is_unit_idle_or_patrolling_returns_false_for_invalid_unit,
		test_kite_distance_constant,
		test_melee_threat_range_constant,
		test_villager_flee_radius_constant,
	]


func _create_ai_controller() -> AIController:
	## Creates a minimal AI controller for testing
	## We need to prevent _ready from spawning AI base, so we use set_process(false)
	## before adding to tree, then manually set the node up
	var controller = AIController.new()
	controller.set_process(false)  # Prevent _process decisions during test
	runner.spawner.spawned_entities.append(controller)
	# Add to tree so it can use get_tree() - _ready will still fire but fail gracefully
	runner.add_child(controller)
	return controller


func _cleanup_ai_controller(controller: AIController) -> void:
	## Cleanup AI controller after test
	if is_instance_valid(controller):
		controller.queue_free()


# === Villager Allocation Tests ===

func test_get_needed_resource_defaults_to_food() -> Assertions.AssertResult:
	## When no villagers are gathering, should default to food
	var controller = _create_ai_controller()
	await runner.wait_frames(2)

	var allocation = {"food": 0, "wood": 0, "gold": 0, "stone": 0}
	var needed = controller._get_needed_resource(allocation)

	_cleanup_ai_controller(controller)

	if needed != "food":
		return Assertions.AssertResult.new(false,
			"Should default to food when no gatherers, got: %s" % needed)

	return Assertions.AssertResult.new(true)


func test_get_needed_resource_returns_highest_deficit() -> Assertions.AssertResult:
	## Should return resource with highest deficit from target
	var controller = _create_ai_controller()
	await runner.wait_frames(2)

	# Set up resources to avoid emergency thresholds
	GameManager.ai_resources["food"] = 100
	GameManager.ai_resources["wood"] = 100

	# AI targets: food=6, wood=5, gold=3, stone=1
	# Current allocation: food full, wood missing 3, gold full, stone full
	var allocation = {"food": 6, "wood": 2, "gold": 3, "stone": 1}
	var needed = controller._get_needed_resource(allocation)

	_cleanup_ai_controller(controller)

	if needed != "wood":
		return Assertions.AssertResult.new(false,
			"Should return wood (highest deficit), got: %s" % needed)

	return Assertions.AssertResult.new(true)


func test_get_needed_resource_emergency_food() -> Assertions.AssertResult:
	## When food is critically low (<50), should override normal allocation
	var controller = _create_ai_controller()
	await runner.wait_frames(2)

	# Set food to emergency level
	GameManager.ai_resources["food"] = 30
	GameManager.ai_resources["wood"] = 200

	# Even though wood has higher deficit, food emergency overrides
	var allocation = {"food": 6, "wood": 0, "gold": 0, "stone": 0}
	var needed = controller._get_needed_resource(allocation)

	_cleanup_ai_controller(controller)

	if needed != "food":
		return Assertions.AssertResult.new(false,
			"Should return food in emergency (<50), got: %s" % needed)

	return Assertions.AssertResult.new(true)


func test_get_needed_resource_emergency_wood() -> Assertions.AssertResult:
	## When wood is critically low (<50), should return wood after food check
	var controller = _create_ai_controller()
	await runner.wait_frames(2)

	# Food OK but wood emergency
	GameManager.ai_resources["food"] = 100
	GameManager.ai_resources["wood"] = 30

	# Even though gold has deficit, wood emergency overrides
	var allocation = {"food": 6, "wood": 5, "gold": 0, "stone": 0}
	var needed = controller._get_needed_resource(allocation)

	_cleanup_ai_controller(controller)

	if needed != "wood":
		return Assertions.AssertResult.new(false,
			"Should return wood in emergency (<50), got: %s" % needed)

	return Assertions.AssertResult.new(true)


# === Farm Decision Tests ===

func test_should_build_farm_false_at_max_farms() -> Assertions.AssertResult:
	## Should not build farm when already at TARGET_FARMS (6)
	var controller = _create_ai_controller()
	await runner.wait_frames(2)

	# Give AI plenty of wood
	GameManager.ai_resources["wood"] = 500

	# Spawn 6 farms for AI (at TARGET_FARMS limit)
	for i in range(6):
		runner.spawner.spawn_farm(Vector2(200 + i * 80, 200), AI_TEAM)
	await runner.wait_frames(2)

	var should_build = controller._should_build_farm()

	_cleanup_ai_controller(controller)

	if should_build:
		return Assertions.AssertResult.new(false,
			"Should not build farm when at TARGET_FARMS limit")

	return Assertions.AssertResult.new(true)


func test_should_build_farm_false_without_wood() -> Assertions.AssertResult:
	## Should not build farm when AI cannot afford it (needs 50 wood)
	var controller = _create_ai_controller()
	await runner.wait_frames(2)

	# Set AI wood below farm cost
	GameManager.ai_resources["wood"] = 40

	var should_build = controller._should_build_farm()

	_cleanup_ai_controller(controller)

	if should_build:
		return Assertions.AssertResult.new(false,
			"Should not build farm without 50 wood")

	return Assertions.AssertResult.new(true)


func test_should_build_farm_true_when_no_natural_food() -> Assertions.AssertResult:
	## Should build farm when no natural food sources nearby
	var controller = _create_ai_controller()
	await runner.wait_frames(2)

	# Give AI wood and clear any natural food
	GameManager.ai_resources["wood"] = 200

	# Note: No berry bushes or animals near AI base (1700, 1700)
	# The controller checks within 600px for animals, 500px for berries

	var should_build = controller._should_build_farm()

	_cleanup_ai_controller(controller)

	if not should_build:
		return Assertions.AssertResult.new(false,
			"Should build farm when no natural food sources")

	return Assertions.AssertResult.new(true)


func test_count_farms_returns_ai_farms_only() -> Assertions.AssertResult:
	## _count_farms should only count AI team farms
	var controller = _create_ai_controller()
	await runner.wait_frames(2)

	# Spawn farms for both teams
	runner.spawner.spawn_farm(Vector2(200, 200), 0)  # Player farm
	runner.spawner.spawn_farm(Vector2(300, 200), 0)  # Player farm
	runner.spawner.spawn_farm(Vector2(400, 200), AI_TEAM)  # AI farm
	runner.spawner.spawn_farm(Vector2(500, 200), AI_TEAM)  # AI farm
	runner.spawner.spawn_farm(Vector2(600, 200), AI_TEAM)  # AI farm
	await runner.wait_frames(2)

	var count = controller._count_farms()

	_cleanup_ai_controller(controller)

	if count != 3:
		return Assertions.AssertResult.new(false,
			"Should count 3 AI farms, got: %d" % count)

	return Assertions.AssertResult.new(true)


# === Attack Threshold Tests ===

func test_should_attack_false_without_villagers() -> Assertions.AssertResult:
	## Should not attack without minimum villagers (MIN_VILLAGERS_FOR_ATTACK = 15)
	var controller = _create_ai_controller()
	await runner.wait_frames(2)

	# Spawn only 5 AI villagers (below threshold of 15)
	for i in range(5):
		runner.spawner.spawn_villager(Vector2(1700 + i * 30, 1700), AI_TEAM)
	await runner.wait_frames(2)

	# Spawn some military so that's not the limiting factor
	for i in range(10):
		runner.spawner.spawn_militia(Vector2(1600, 1600 + i * 20), AI_TEAM)
	await runner.wait_frames(2)

	var should_attack = controller._should_attack()

	_cleanup_ai_controller(controller)

	if should_attack:
		return Assertions.AssertResult.new(false,
			"Should not attack without 15 villagers")

	return Assertions.AssertResult.new(true)


func test_should_attack_false_without_military() -> Assertions.AssertResult:
	## Should not attack without minimum military (MIN_MILITARY_FOR_ATTACK = 5)
	var controller = _create_ai_controller()
	await runner.wait_frames(2)

	# Spawn 20 AI villagers (above threshold)
	for i in range(20):
		runner.spawner.spawn_villager(Vector2(1700 + (i % 5) * 30, 1700 + (i / 5) * 30), AI_TEAM)
	await runner.wait_frames(2)

	# Spawn only 3 military (below threshold of 5)
	for i in range(3):
		runner.spawner.spawn_militia(Vector2(1600, 1600 + i * 20), AI_TEAM)
	await runner.wait_frames(2)

	var should_attack = controller._should_attack()

	_cleanup_ai_controller(controller)

	if should_attack:
		return Assertions.AssertResult.new(false,
			"Should not attack without 5 military units")

	return Assertions.AssertResult.new(true)


func test_should_attack_false_after_attacking() -> Assertions.AssertResult:
	## Should not attack again while attack cooldown is active
	var controller = _create_ai_controller()
	await runner.wait_frames(2)

	# Set up sufficient economy and military
	for i in range(20):
		runner.spawner.spawn_villager(Vector2(1700 + (i % 5) * 30, 1700 + (i / 5) * 30), AI_TEAM)
	for i in range(10):
		runner.spawner.spawn_militia(Vector2(1600, 1600 + i * 20), AI_TEAM)
	await runner.wait_frames(2)

	# Set attack cooldown active (means AI recently attacked)
	controller.attack_cooldown = 10.0  # 10 seconds remaining on cooldown

	var should_attack = controller._should_attack()

	_cleanup_ai_controller(controller)

	if should_attack:
		return Assertions.AssertResult.new(false,
			"Should not attack when attack cooldown is active")

	return Assertions.AssertResult.new(true)


func test_should_attack_true_with_economy_and_military() -> Assertions.AssertResult:
	## Should attack when economy and military thresholds met
	var controller = _create_ai_controller()
	await runner.wait_frames(2)

	# Spawn 16 AI villagers (>= 15 threshold)
	for i in range(16):
		runner.spawner.spawn_villager(Vector2(1700 + (i % 5) * 30, 1700 + (i / 5) * 30), AI_TEAM)
	await runner.wait_frames(2)

	# Spawn 6 military (>= 5 threshold)
	for i in range(6):
		runner.spawner.spawn_militia(Vector2(1600, 1600 + i * 20), AI_TEAM)
	await runner.wait_frames(2)

	# Ensure attack is not on cooldown
	controller.attack_cooldown = 0.0

	var should_attack = controller._should_attack()

	_cleanup_ai_controller(controller)

	if not should_attack:
		return Assertions.AssertResult.new(false,
			"Should attack with 16 villagers and 6 military")

	return Assertions.AssertResult.new(true)


# === Building Check Tests ===

func test_has_barracks_detects_ai_barracks() -> Assertions.AssertResult:
	## _has_barracks should detect AI team barracks
	var controller = _create_ai_controller()
	await runner.wait_frames(2)

	# Initially no barracks
	var has_before = controller._has_barracks()

	# Spawn AI barracks
	runner.spawner.spawn_barracks(Vector2(1650, 1650), AI_TEAM)
	await runner.wait_frames(2)

	var has_after = controller._has_barracks()

	_cleanup_ai_controller(controller)

	if has_before:
		return Assertions.AssertResult.new(false,
			"Should not detect barracks before spawning")

	if not has_after:
		return Assertions.AssertResult.new(false,
			"Should detect AI barracks after spawning")

	return Assertions.AssertResult.new(true)


func test_has_barracks_ignores_player_barracks() -> Assertions.AssertResult:
	## _has_barracks should not count player barracks
	var controller = _create_ai_controller()
	await runner.wait_frames(2)

	# Spawn player barracks only
	runner.spawner.spawn_barracks(Vector2(200, 200), 0)  # Player team
	await runner.wait_frames(2)

	var has_barracks = controller._has_barracks()

	_cleanup_ai_controller(controller)

	if has_barracks:
		return Assertions.AssertResult.new(false,
			"Should not count player barracks as AI barracks")

	return Assertions.AssertResult.new(true)


func test_count_barracks_counts_multiple() -> Assertions.AssertResult:
	## _count_barracks should count multiple AI barracks
	var controller = _create_ai_controller()
	await runner.wait_frames(2)

	# Spawn 2 AI barracks and 1 player barracks
	runner.spawner.spawn_barracks(Vector2(1600, 1600), AI_TEAM)
	runner.spawner.spawn_barracks(Vector2(1700, 1600), AI_TEAM)
	runner.spawner.spawn_barracks(Vector2(200, 200), 0)  # Player
	await runner.wait_frames(2)

	var count = controller._count_barracks()

	_cleanup_ai_controller(controller)

	if count != 2:
		return Assertions.AssertResult.new(false,
			"Should count 2 AI barracks, got: %d" % count)

	return Assertions.AssertResult.new(true)


func test_has_archery_range_detects_ai_range() -> Assertions.AssertResult:
	## _has_archery_range should detect AI team archery range
	var controller = _create_ai_controller()
	await runner.wait_frames(2)

	# Initially no archery range
	var has_before = controller._has_archery_range()

	# Spawn AI archery range
	runner.spawner.spawn_archery_range(Vector2(1650, 1650), AI_TEAM)
	await runner.wait_frames(2)

	var has_after = controller._has_archery_range()

	_cleanup_ai_controller(controller)

	if has_before:
		return Assertions.AssertResult.new(false,
			"Should not detect archery range before spawning")

	if not has_after:
		return Assertions.AssertResult.new(false,
			"Should detect AI archery range after spawning")

	return Assertions.AssertResult.new(true)


func test_has_stable_detects_ai_stable() -> Assertions.AssertResult:
	## _has_stable should detect AI team stable
	var controller = _create_ai_controller()
	await runner.wait_frames(2)

	# Initially no stable
	var has_before = controller._has_stable()

	# Spawn AI stable
	runner.spawner.spawn_stable(Vector2(1650, 1650), AI_TEAM)
	await runner.wait_frames(2)

	var has_after = controller._has_stable()

	_cleanup_ai_controller(controller)

	if has_before:
		return Assertions.AssertResult.new(false,
			"Should not detect stable before spawning")

	if not has_after:
		return Assertions.AssertResult.new(false,
			"Should detect AI stable after spawning")

	return Assertions.AssertResult.new(true)


func test_has_mill_detects_ai_mill() -> Assertions.AssertResult:
	## _has_mill should detect AI team mill
	var controller = _create_ai_controller()
	await runner.wait_frames(2)

	# Initially no mill
	var has_before = controller._has_mill()

	# Spawn AI mill
	runner.spawner.spawn_mill(Vector2(1650, 1650), AI_TEAM)
	await runner.wait_frames(2)

	var has_after = controller._has_mill()

	_cleanup_ai_controller(controller)

	if has_before:
		return Assertions.AssertResult.new(false,
			"Should not detect mill before spawning")

	if not has_after:
		return Assertions.AssertResult.new(false,
			"Should detect AI mill after spawning")

	return Assertions.AssertResult.new(true)


# === Market Decision Tests ===

func test_should_build_market_false_without_surplus() -> Assertions.AssertResult:
	## Should not build market without resource surplus
	var controller = _create_ai_controller()
	await runner.wait_frames(2)

	# Low resources, no surplus
	GameManager.ai_resources["wood"] = 100
	GameManager.ai_resources["food"] = 100
	GameManager.ai_resources["stone"] = 50
	GameManager.ai_resources["gold"] = 50

	var should_build = controller._should_build_market()

	_cleanup_ai_controller(controller)

	if should_build:
		return Assertions.AssertResult.new(false,
			"Should not build market without surplus (>300 wood/food or >200 stone)")

	return Assertions.AssertResult.new(true)


func test_should_build_market_true_with_surplus_and_low_gold() -> Assertions.AssertResult:
	## Should build market when surplus resources and low gold
	var controller = _create_ai_controller()
	await runner.wait_frames(2)

	# Surplus wood, low gold
	GameManager.ai_resources["wood"] = 400
	GameManager.ai_resources["food"] = 100
	GameManager.ai_resources["stone"] = 50
	GameManager.ai_resources["gold"] = 50  # Low gold (<100)

	var should_build = controller._should_build_market()

	_cleanup_ai_controller(controller)

	if not should_build:
		return Assertions.AssertResult.new(false,
			"Should build market with surplus wood (400) and low gold (50)")

	return Assertions.AssertResult.new(true)


# === Phase 3A: Build Order Tests ===

func test_build_order_creates_steps() -> Assertions.AssertResult:
	## BuildOrder class should create a proper build order with steps
	var bo = BuildOrder.new("Test")

	# Add some steps
	bo.add_step(BuildOrder.Step.queue_villager("food"))
	bo.add_step(BuildOrder.Step.build("house"))
	bo.add_step(BuildOrder.Step.wait_villagers(5))

	if bo.size() != 3:
		return Assertions.AssertResult.new(false,
			"Build order should have 3 steps, got: %d" % bo.size())

	var step1 = bo.get_step(0)
	if step1.type != BuildOrder.StepType.QUEUE_VILLAGER:
		return Assertions.AssertResult.new(false,
			"First step should be QUEUE_VILLAGER")

	if step1.target_resource != "food":
		return Assertions.AssertResult.new(false,
			"First step target_resource should be 'food', got: %s" % step1.target_resource)

	return Assertions.AssertResult.new(true)


func test_build_order_dark_age_has_villager_steps() -> Assertions.AssertResult:
	## Dark Age build order should start with villager queueing
	var bo = BuildOrder.create_dark_age_build_order()

	if bo.size() < 10:
		return Assertions.AssertResult.new(false,
			"Dark Age build order should have many steps, got: %d" % bo.size())

	# First few steps should queue villagers
	var villager_steps = 0
	for i in range(min(5, bo.size())):
		var step = bo.get_step(i)
		if step.type == BuildOrder.StepType.QUEUE_VILLAGER:
			villager_steps += 1

	if villager_steps < 3:
		return Assertions.AssertResult.new(false,
			"First 5 steps should have at least 3 villager queues, got: %d" % villager_steps)

	return Assertions.AssertResult.new(true)


func test_build_order_dark_age_has_building_steps() -> Assertions.AssertResult:
	## Dark Age build order should include key buildings
	var bo = BuildOrder.create_dark_age_build_order()

	var has_house = false
	var has_lumber_camp = false
	var has_barracks = false

	for i in range(bo.size()):
		var step = bo.get_step(i)
		if step.type == BuildOrder.StepType.BUILD_BUILDING:
			if step.building_type == "house":
				has_house = true
			elif step.building_type == "lumber_camp":
				has_lumber_camp = true
			elif step.building_type == "barracks":
				has_barracks = true

	if not has_house:
		return Assertions.AssertResult.new(false,
			"Dark Age build order should include house building")

	if not has_lumber_camp:
		return Assertions.AssertResult.new(false,
			"Dark Age build order should include lumber camp building")

	if not has_barracks:
		return Assertions.AssertResult.new(false,
			"Dark Age build order should include barracks building")

	return Assertions.AssertResult.new(true)


# === Phase 3A: Floating Resources Tests ===

func test_is_floating_resources_false_when_low() -> Assertions.AssertResult:
	## _is_floating_resources should return false when all resources < 300
	var controller = _create_ai_controller()
	await runner.wait_frames(2)

	GameManager.ai_resources["wood"] = 200
	GameManager.ai_resources["food"] = 200
	GameManager.ai_resources["gold"] = 100

	var floating = controller._is_floating_resources()

	_cleanup_ai_controller(controller)

	if floating:
		return Assertions.AssertResult.new(false,
			"Should not be floating with wood=200, food=200, gold=100")

	return Assertions.AssertResult.new(true)


func test_is_floating_resources_true_when_high() -> Assertions.AssertResult:
	## _is_floating_resources should return true when any resource > 300
	var controller = _create_ai_controller()
	await runner.wait_frames(2)

	GameManager.ai_resources["wood"] = 400  # Over threshold
	GameManager.ai_resources["food"] = 200
	GameManager.ai_resources["gold"] = 100

	var floating = controller._is_floating_resources()

	_cleanup_ai_controller(controller)

	if not floating:
		return Assertions.AssertResult.new(false,
			"Should be floating with wood=400 (>300)")

	return Assertions.AssertResult.new(true)


# === Phase 3A: Production Building Scaling Tests ===

func test_count_archery_ranges_counts_ai_only() -> Assertions.AssertResult:
	## _count_archery_ranges should only count AI team archery ranges
	var controller = _create_ai_controller()
	await runner.wait_frames(2)

	# Spawn archery ranges for both teams
	runner.spawner.spawn_archery_range(Vector2(200, 200), 0)  # Player
	runner.spawner.spawn_archery_range(Vector2(1600, 1600), AI_TEAM)  # AI
	runner.spawner.spawn_archery_range(Vector2(1700, 1600), AI_TEAM)  # AI
	await runner.wait_frames(2)

	var count = controller._count_archery_ranges()

	_cleanup_ai_controller(controller)

	if count != 2:
		return Assertions.AssertResult.new(false,
			"Should count 2 AI archery ranges, got: %d" % count)

	return Assertions.AssertResult.new(true)


func test_count_stables_counts_ai_only() -> Assertions.AssertResult:
	## _count_stables should only count AI team stables
	var controller = _create_ai_controller()
	await runner.wait_frames(2)

	# Spawn stables for both teams
	runner.spawner.spawn_stable(Vector2(200, 200), 0)  # Player
	runner.spawner.spawn_stable(Vector2(300, 200), 0)  # Player
	runner.spawner.spawn_stable(Vector2(1600, 1600), AI_TEAM)  # AI
	await runner.wait_frames(2)

	var count = controller._count_stables()

	_cleanup_ai_controller(controller)

	if count != 1:
		return Assertions.AssertResult.new(false,
			"Should count 1 AI stable, got: %d" % count)

	return Assertions.AssertResult.new(true)


# === Phase 3B: Scouting System Tests ===

func test_scout_state_starts_idle() -> Assertions.AssertResult:
	## Scout state should start at IDLE
	var controller = _create_ai_controller()
	await runner.wait_frames(2)

	if controller.scout_state != AIController.ScoutState.IDLE:
		_cleanup_ai_controller(controller)
		return Assertions.AssertResult.new(false,
			"Scout state should start at IDLE, got: %d" % controller.scout_state)

	_cleanup_ai_controller(controller)
	return Assertions.AssertResult.new(true)


func test_scout_found_enemy_base_initially_false() -> Assertions.AssertResult:
	## scout_found_enemy_base should initially be false
	var controller = _create_ai_controller()
	await runner.wait_frames(2)

	if controller.scout_found_enemy_base:
		_cleanup_ai_controller(controller)
		return Assertions.AssertResult.new(false,
			"scout_found_enemy_base should initially be false")

	_cleanup_ai_controller(controller)
	return Assertions.AssertResult.new(true)


func test_has_scouted_enemy_base_returns_false_initially() -> Assertions.AssertResult:
	## has_scouted_enemy_base() should return false before scouting
	var controller = _create_ai_controller()
	await runner.wait_frames(2)

	var has_scouted = controller.has_scouted_enemy_base()

	_cleanup_ai_controller(controller)

	if has_scouted:
		return Assertions.AssertResult.new(false,
			"has_scouted_enemy_base() should be false before scouting")

	return Assertions.AssertResult.new(true)


func test_get_enemy_base_position_returns_default_when_not_scouted() -> Assertions.AssertResult:
	## get_enemy_base_position() should return PLAYER_BASE_POSITION when not scouted
	var controller = _create_ai_controller()
	await runner.wait_frames(2)

	var enemy_pos = controller.get_enemy_base_position()

	_cleanup_ai_controller(controller)

	if enemy_pos != AIController.PLAYER_BASE_POSITION:
		return Assertions.AssertResult.new(false,
			"Should return PLAYER_BASE_POSITION when not scouted, got: %s" % str(enemy_pos))

	return Assertions.AssertResult.new(true)


# === Phase 3B: Enemy Tracking Tests ===

func test_estimated_enemy_army_starts_zero() -> Assertions.AssertResult:
	## All estimated_enemy_army values should start at 0
	var controller = _create_ai_controller()
	await runner.wait_frames(2)

	var total = controller.estimated_enemy_army.total_military

	_cleanup_ai_controller(controller)

	if total != 0:
		return Assertions.AssertResult.new(false,
			"estimated_enemy_army.total_military should start at 0, got: %d" % total)

	return Assertions.AssertResult.new(true)


func test_get_enemy_dominant_unit_type_defaults_to_militia() -> Assertions.AssertResult:
	## get_enemy_dominant_unit_type() should default to militia when no enemies seen
	var controller = _create_ai_controller()
	await runner.wait_frames(2)

	var dominant = controller.get_enemy_dominant_unit_type()

	_cleanup_ai_controller(controller)

	if dominant != "militia":
		return Assertions.AssertResult.new(false,
			"Should default to 'militia' when no enemies seen, got: %s" % dominant)

	return Assertions.AssertResult.new(true)


func test_known_enemy_buildings_starts_empty() -> Assertions.AssertResult:
	## known_enemy_buildings should start empty
	var controller = _create_ai_controller()
	await runner.wait_frames(2)

	var count = controller.known_enemy_buildings.size()

	_cleanup_ai_controller(controller)

	if count != 0:
		return Assertions.AssertResult.new(false,
			"known_enemy_buildings should start empty, has: %d items" % count)

	return Assertions.AssertResult.new(true)


# === Phase 3B: Threat Assessment Tests ===

func test_threat_level_starts_zero() -> Assertions.AssertResult:
	## current_threat_level should start at 0
	var controller = _create_ai_controller()
	await runner.wait_frames(2)

	if controller.current_threat_level != 0:
		_cleanup_ai_controller(controller)
		return Assertions.AssertResult.new(false,
			"current_threat_level should start at 0, got: %d" % controller.current_threat_level)

	_cleanup_ai_controller(controller)
	return Assertions.AssertResult.new(true)


func test_get_threat_level_returns_current_value() -> Assertions.AssertResult:
	## get_threat_level() should return current_threat_level
	var controller = _create_ai_controller()
	await runner.wait_frames(2)

	# Set a threat level manually
	controller.current_threat_level = AIController.THREAT_MODERATE

	var level = controller.get_threat_level()

	_cleanup_ai_controller(controller)

	if level != AIController.THREAT_MODERATE:
		return Assertions.AssertResult.new(false,
			"get_threat_level() should return THREAT_MODERATE (2), got: %d" % level)

	return Assertions.AssertResult.new(true)


func test_enemy_has_more_returns_false_when_equal() -> Assertions.AssertResult:
	## enemy_has_more() should return false when counts are equal (0 == 0)
	var controller = _create_ai_controller()
	await runner.wait_frames(2)

	var result = controller.enemy_has_more("militia")

	_cleanup_ai_controller(controller)

	if result:
		return Assertions.AssertResult.new(false,
			"enemy_has_more() should be false when both have 0 militia")

	return Assertions.AssertResult.new(true)


func test_enemy_has_more_returns_true_when_enemy_has_more() -> Assertions.AssertResult:
	## enemy_has_more() should return true when estimated enemy count is higher
	var controller = _create_ai_controller()
	await runner.wait_frames(2)

	# Manually set estimated enemy militia count
	controller.estimated_enemy_army["militia"] = 5

	# AI has no militia
	var result = controller.enemy_has_more("militia")

	_cleanup_ai_controller(controller)

	if not result:
		return Assertions.AssertResult.new(false,
			"enemy_has_more() should be true when enemy has 5 militia and AI has 0")

	return Assertions.AssertResult.new(true)


func test_building_type_string_returns_correct_types() -> Assertions.AssertResult:
	## _get_building_type_string() should return correct building type names
	var controller = _create_ai_controller()
	await runner.wait_frames(2)

	# Spawn a barracks and test
	var barracks = runner.spawner.spawn_barracks(Vector2(1600, 1600), AI_TEAM)
	await runner.wait_frames(2)

	var type_str = controller._get_building_type_string(barracks)

	_cleanup_ai_controller(controller)

	if type_str != "barracks":
		return Assertions.AssertResult.new(false,
			"_get_building_type_string() for Barracks should return 'barracks', got: %s" % type_str)

	return Assertions.AssertResult.new(true)


# === Phase 3C: Counter-Unit Production Tests ===

func test_get_counter_for_unit_returns_correct_counters() -> Assertions.AssertResult:
	## _get_counter_for_unit should return correct counter units from COUNTER_UNITS dict
	var controller = _create_ai_controller()
	await runner.wait_frames(2)

	# Test key counter matchups
	var archer_counter = controller._get_counter_for_unit("archer")
	var cavalry_counter = controller._get_counter_for_unit("scout_cavalry")
	var militia_counter = controller._get_counter_for_unit("militia")

	_cleanup_ai_controller(controller)

	if archer_counter != "skirmisher":
		return Assertions.AssertResult.new(false,
			"Counter for archer should be 'skirmisher', got: %s" % archer_counter)

	if cavalry_counter != "spearman":
		return Assertions.AssertResult.new(false,
			"Counter for scout_cavalry should be 'spearman', got: %s" % cavalry_counter)

	if militia_counter != "archer":
		return Assertions.AssertResult.new(false,
			"Counter for militia should be 'archer', got: %s" % militia_counter)

	return Assertions.AssertResult.new(true)


func test_get_counter_for_unit_defaults_to_militia() -> Assertions.AssertResult:
	## _get_counter_for_unit should return 'militia' for unknown unit types
	var controller = _create_ai_controller()
	await runner.wait_frames(2)

	var unknown_counter = controller._get_counter_for_unit("unknown_unit")

	_cleanup_ai_controller(controller)

	if unknown_counter != "militia":
		return Assertions.AssertResult.new(false,
			"Counter for unknown unit type should default to 'militia', got: %s" % unknown_counter)

	return Assertions.AssertResult.new(true)


func test_get_counter_unit_priority_returns_default_with_low_intel() -> Assertions.AssertResult:
	## _get_counter_unit_priority should return default when enemy intel is low
	var controller = _create_ai_controller()
	await runner.wait_frames(2)

	# Ensure enemy army estimate is below threshold (< 3)
	controller.estimated_enemy_army.total_military = 2

	var priority = controller._get_counter_unit_priority()

	_cleanup_ai_controller(controller)

	if priority.type != "militia":
		return Assertions.AssertResult.new(false,
			"Should default to 'militia' with low intel, got: %s" % priority.type)

	if priority.reason != "default":
		return Assertions.AssertResult.new(false,
			"Reason should be 'default' with low intel, got: %s" % priority.reason)

	return Assertions.AssertResult.new(true)


func test_get_counter_unit_priority_counters_archers_with_skirmishers() -> Assertions.AssertResult:
	## _get_counter_unit_priority should prioritize skirmishers against archer-heavy enemy
	var controller = _create_ai_controller()
	await runner.wait_frames(2)

	# Set up enemy composition with many archers
	controller.estimated_enemy_army.archer = 5
	controller.estimated_enemy_army.militia = 1
	controller.estimated_enemy_army.total_military = 6

	var priority = controller._get_counter_unit_priority()

	_cleanup_ai_controller(controller)

	# Note: The actual result depends on the logic in _get_counter_unit_priority
	# It checks dominant unit type and the anti-archer check
	if priority.type != "skirmisher":
		return Assertions.AssertResult.new(false,
			"Should prioritize 'skirmisher' against archers, got: %s (reason: %s)" % [priority.type, priority.reason])

	return Assertions.AssertResult.new(true)


func test_get_counter_unit_priority_counters_cavalry_with_spearmen() -> Assertions.AssertResult:
	## _get_counter_unit_priority should prioritize spearmen against cavalry-heavy enemy
	var controller = _create_ai_controller()
	await runner.wait_frames(2)

	# Set up enemy composition with many cavalry
	controller.estimated_enemy_army.scout_cavalry = 4
	controller.estimated_enemy_army.militia = 1
	controller.estimated_enemy_army.total_military = 5

	var priority = controller._get_counter_unit_priority()

	_cleanup_ai_controller(controller)

	if priority.type != "spearman":
		return Assertions.AssertResult.new(false,
			"Should prioritize 'spearman' against cavalry, got: %s (reason: %s)" % [priority.type, priority.reason])

	return Assertions.AssertResult.new(true)


# === Phase 3C: Army Composition Goal Tests ===

func test_army_composition_goals_has_default_ratios() -> Assertions.AssertResult:
	## army_composition_goals should have default ratios (40/40/20)
	var controller = _create_ai_controller()
	await runner.wait_frames(2)

	var infantry = controller.army_composition_goals.infantry
	var ranged = controller.army_composition_goals.ranged
	var cavalry = controller.army_composition_goals.cavalry

	_cleanup_ai_controller(controller)

	if abs(infantry - 0.4) > 0.01:
		return Assertions.AssertResult.new(false,
			"Default infantry ratio should be 0.4, got: %f" % infantry)

	if abs(ranged - 0.4) > 0.01:
		return Assertions.AssertResult.new(false,
			"Default ranged ratio should be 0.4, got: %f" % ranged)

	if abs(cavalry - 0.2) > 0.01:
		return Assertions.AssertResult.new(false,
			"Default cavalry ratio should be 0.2, got: %f" % cavalry)

	return Assertions.AssertResult.new(true)


func test_update_army_composition_goals_adjusts_for_ranged_enemy() -> Assertions.AssertResult:
	## _update_army_composition_goals should increase ranged ratio against archer-heavy enemy
	var controller = _create_ai_controller()
	await runner.wait_frames(2)

	# Set enemy composition: heavy archers (>50% ranged)
	controller.estimated_enemy_army.archer = 6
	controller.estimated_enemy_army.militia = 2
	controller.estimated_enemy_army.total_military = 8

	controller._update_army_composition_goals()

	var ranged = controller.army_composition_goals.ranged
	var cavalry = controller.army_composition_goals.cavalry

	_cleanup_ai_controller(controller)

	# Against heavy archers, should prioritize ranged (skirmishers) and cavalry
	if ranged < 0.45:
		return Assertions.AssertResult.new(false,
			"Ranged ratio should increase against archer enemy, got: %f" % ranged)

	return Assertions.AssertResult.new(true)


func test_update_army_composition_goals_adjusts_for_cavalry_enemy() -> Assertions.AssertResult:
	## _update_army_composition_goals should increase infantry ratio against cavalry-heavy enemy
	var controller = _create_ai_controller()
	await runner.wait_frames(2)

	# Set enemy composition: heavy cavalry (>40% cavalry)
	controller.estimated_enemy_army.scout_cavalry = 5
	controller.estimated_enemy_army.militia = 3
	controller.estimated_enemy_army.total_military = 8

	controller._update_army_composition_goals()

	var infantry = controller.army_composition_goals.infantry

	_cleanup_ai_controller(controller)

	# Against heavy cavalry, should prioritize infantry (spearmen)
	if infantry < 0.45:
		return Assertions.AssertResult.new(false,
			"Infantry ratio should increase against cavalry enemy, got: %f" % infantry)

	return Assertions.AssertResult.new(true)


func test_update_army_composition_goals_adjusts_for_infantry_enemy() -> Assertions.AssertResult:
	## _update_army_composition_goals should increase ranged ratio against infantry-heavy enemy
	var controller = _create_ai_controller()
	await runner.wait_frames(2)

	# Set enemy composition: heavy infantry (>50% infantry)
	controller.estimated_enemy_army.militia = 5
	controller.estimated_enemy_army.spearman = 3
	controller.estimated_enemy_army.total_military = 8

	controller._update_army_composition_goals()

	var ranged = controller.army_composition_goals.ranged

	_cleanup_ai_controller(controller)

	# Against heavy infantry, should prioritize ranged (archers)
	if ranged < 0.45:
		return Assertions.AssertResult.new(false,
			"Ranged ratio should increase against infantry enemy, got: %f" % ranged)

	return Assertions.AssertResult.new(true)


# === Phase 3C: Attack Timing Tests ===

func test_get_military_strength_counts_ai_units() -> Assertions.AssertResult:
	## _get_military_strength should return strength score for AI military units
	var controller = _create_ai_controller()
	await runner.wait_frames(2)

	# Start with no military
	var strength_before = controller._get_military_strength()

	# Spawn some AI military
	runner.spawner.spawn_militia(Vector2(1600, 1600), AI_TEAM)
	runner.spawner.spawn_militia(Vector2(1620, 1600), AI_TEAM)
	await runner.wait_frames(2)

	var strength_after = controller._get_military_strength()

	_cleanup_ai_controller(controller)

	if strength_before != 0:
		return Assertions.AssertResult.new(false,
			"Strength should be 0 with no military, got: %d" % strength_before)

	# Each militia is worth 2 strength, so 2 militia = 4
	if strength_after != 4:
		return Assertions.AssertResult.new(false,
			"Strength should be 4 with 2 militia (2 each), got: %d" % strength_after)

	return Assertions.AssertResult.new(true)


func test_get_military_strength_weights_unit_types() -> Assertions.AssertResult:
	## _get_military_strength should weight different unit types differently
	var controller = _create_ai_controller()
	await runner.wait_frames(2)

	# Spawn 1 militia (2 strength), 1 archer (3 strength), 1 scout cavalry (3 strength)
	runner.spawner.spawn_militia(Vector2(1600, 1600), AI_TEAM)
	runner.spawner.spawn_archer(Vector2(1620, 1600), AI_TEAM)
	runner.spawner.spawn_scout_cavalry(Vector2(1640, 1600), AI_TEAM)
	await runner.wait_frames(2)

	var strength = controller._get_military_strength()

	_cleanup_ai_controller(controller)

	# 2 + 3 + 3 = 8
	if strength != 8:
		return Assertions.AssertResult.new(false,
			"Strength should be 8 (militia=2 + archer=3 + scout=3), got: %d" % strength)

	return Assertions.AssertResult.new(true)


func test_get_enemy_strength_estimate_uses_estimated_army() -> Assertions.AssertResult:
	## _get_enemy_strength_estimate should calculate from estimated_enemy_army
	var controller = _create_ai_controller()
	await runner.wait_frames(2)

	# No enemy intel = 0 strength
	var strength_before = controller._get_enemy_strength_estimate()

	# Set estimated enemy composition
	controller.estimated_enemy_army.militia = 2  # 2 * 2 = 4
	controller.estimated_enemy_army.archer = 1   # 1 * 3 = 3
	# Total = 7

	var strength_after = controller._get_enemy_strength_estimate()

	_cleanup_ai_controller(controller)

	if strength_before != 0:
		return Assertions.AssertResult.new(false,
			"Enemy strength should be 0 with no intel, got: %d" % strength_before)

	if strength_after != 7:
		return Assertions.AssertResult.new(false,
			"Enemy strength should be 7 (2*2 + 1*3), got: %d" % strength_after)

	return Assertions.AssertResult.new(true)


func test_has_military_advantage_requires_threshold() -> Assertions.AssertResult:
	## _has_military_advantage should require ATTACK_ADVANTAGE_THRESHOLD more strength
	var controller = _create_ai_controller()
	await runner.wait_frames(2)

	# Set up scenario: AI has 5 strength, enemy has 4
	# Advantage threshold is 3, so 5 - 4 = 1, not enough
	runner.spawner.spawn_militia(Vector2(1600, 1600), AI_TEAM)  # +2
	runner.spawner.spawn_archer(Vector2(1620, 1600), AI_TEAM)   # +3 = 5 total
	await runner.wait_frames(2)

	controller.estimated_enemy_army.militia = 2  # 2 * 2 = 4

	var has_advantage = controller._has_military_advantage()

	_cleanup_ai_controller(controller)

	# 5 >= 4 + 3 is false (5 < 7)
	if has_advantage:
		return Assertions.AssertResult.new(false,
			"Should NOT have advantage when difference < threshold (5 vs 4, threshold 3)")

	return Assertions.AssertResult.new(true)


func test_is_enemy_vulnerable_true_when_low_military() -> Assertions.AssertResult:
	## _is_enemy_vulnerable should return true when enemy has <= 2 military
	var controller = _create_ai_controller()
	await runner.wait_frames(2)

	# Set low enemy military
	controller.estimated_enemy_army.total_military = 2

	var is_vulnerable = controller._is_enemy_vulnerable()

	_cleanup_ai_controller(controller)

	if not is_vulnerable:
		return Assertions.AssertResult.new(false,
			"Enemy should be vulnerable when total_military <= 2")

	return Assertions.AssertResult.new(true)


func test_is_enemy_vulnerable_true_when_villagers_seen_recently() -> Assertions.AssertResult:
	## _is_enemy_vulnerable should return true when villagers seen recently
	var controller = _create_ai_controller()
	await runner.wait_frames(2)

	# Set enemy villagers seen and recent sighting
	controller.estimated_enemy_army.villagers = 5
	controller.estimated_enemy_army.total_military = 10  # Not low
	controller.last_enemy_sighting_time = Time.get_ticks_msec() / 1000.0 - 10.0  # 10 seconds ago

	var is_vulnerable = controller._is_enemy_vulnerable()

	_cleanup_ai_controller(controller)

	if not is_vulnerable:
		return Assertions.AssertResult.new(false,
			"Enemy should be vulnerable when villagers seen recently (within 30s)")

	return Assertions.AssertResult.new(true)


# === Phase 3C: Target Prioritization Tests ===

func test_prioritize_target_prefers_villagers() -> Assertions.AssertResult:
	## _prioritize_target_from_list should prioritize villagers over military
	var controller = _create_ai_controller()
	await runner.wait_frames(2)

	# Spawn player villager and militia
	var villager = runner.spawner.spawn_villager(Vector2(200, 200), 0)
	var militia = runner.spawner.spawn_militia(Vector2(220, 200), 0)
	await runner.wait_frames(2)

	var targets = [militia, villager]
	var best = controller._prioritize_target_from_list(targets)

	_cleanup_ai_controller(controller)

	if best != villager:
		return Assertions.AssertResult.new(false,
			"Should prioritize villager over militia")

	return Assertions.AssertResult.new(true)


func test_prioritize_target_prefers_ranged_over_military() -> Assertions.AssertResult:
	## _prioritize_target_from_list should prefer ranged units over melee military
	var controller = _create_ai_controller()
	await runner.wait_frames(2)

	# Spawn player archer and militia at same distance from AI base
	var archer = runner.spawner.spawn_archer(Vector2(200, 200), 0)
	var militia = runner.spawner.spawn_militia(Vector2(200, 220), 0)
	await runner.wait_frames(2)

	var targets = [militia, archer]
	var best = controller._prioritize_target_from_list(targets)

	_cleanup_ai_controller(controller)

	if best != archer:
		return Assertions.AssertResult.new(false,
			"Should prioritize archer (ranged) over militia (melee)")

	return Assertions.AssertResult.new(true)


func test_prioritize_target_prefers_low_hp() -> Assertions.AssertResult:
	## _prioritize_target_from_list should prefer low HP targets (same unit type)
	var controller = _create_ai_controller()
	await runner.wait_frames(2)

	# Spawn two militia, damage one
	var militia1 = runner.spawner.spawn_militia(Vector2(200, 200), 0)
	var militia2 = runner.spawner.spawn_militia(Vector2(200, 220), 0)
	await runner.wait_frames(2)

	# Damage militia1 to low HP
	militia1.current_hp = 10  # Low HP
	# militia2 stays at full HP

	var targets = [militia2, militia1]
	var best = controller._prioritize_target_from_list(targets)

	_cleanup_ai_controller(controller)

	if best != militia1:
		return Assertions.AssertResult.new(false,
			"Should prioritize low HP militia over full HP militia")

	return Assertions.AssertResult.new(true)


func test_prioritize_target_returns_null_for_empty_list() -> Assertions.AssertResult:
	## _prioritize_target_from_list should return null for empty target list
	var controller = _create_ai_controller()
	await runner.wait_frames(2)

	var best = controller._prioritize_target_from_list([])

	_cleanup_ai_controller(controller)

	if best != null:
		return Assertions.AssertResult.new(false,
			"Should return null for empty target list")

	return Assertions.AssertResult.new(true)


# === Phase 3C: Retreat Behavior Tests ===

func test_is_unit_attacking_returns_false_for_idle_unit() -> Assertions.AssertResult:
	## _is_unit_attacking should return false for idle units
	var controller = _create_ai_controller()
	await runner.wait_frames(2)

	# Spawn idle AI militia
	var militia = runner.spawner.spawn_militia(Vector2(1600, 1600), AI_TEAM)
	await runner.wait_frames(2)

	# Unit should start idle
	var is_attacking = controller._is_unit_attacking(militia)

	_cleanup_ai_controller(controller)

	if is_attacking:
		return Assertions.AssertResult.new(false,
			"_is_unit_attacking should return false for idle unit")

	return Assertions.AssertResult.new(true)


func test_should_unit_retreat_false_at_full_hp() -> Assertions.AssertResult:
	## _should_unit_retreat should return false for unit at full HP
	var controller = _create_ai_controller()
	await runner.wait_frames(2)

	# Spawn AI militia at full HP
	var militia = runner.spawner.spawn_militia(Vector2(1600, 1600), AI_TEAM)
	await runner.wait_frames(2)

	var should_retreat = controller._should_unit_retreat(militia)

	_cleanup_ai_controller(controller)

	if should_retreat:
		return Assertions.AssertResult.new(false,
			"Should not retreat at full HP")

	return Assertions.AssertResult.new(true)


func test_should_unit_retreat_true_at_low_hp_in_combat() -> Assertions.AssertResult:
	## _should_unit_retreat should return true for low HP unit near enemies
	var controller = _create_ai_controller()
	await runner.wait_frames(2)

	# Spawn AI militia and damage it severely (below 25% threshold)
	var militia = runner.spawner.spawn_militia(Vector2(1600, 1600), AI_TEAM)
	await runner.wait_frames(2)

	# Set HP below retreat threshold (25%)
	militia.current_hp = int(militia.max_hp * 0.2)  # 20% HP

	# Spawn enemy nearby to trigger retreat check
	runner.spawner.spawn_militia(Vector2(1620, 1600), 0)  # Player militia nearby
	await runner.wait_frames(2)

	var should_retreat = controller._should_unit_retreat(militia)

	_cleanup_ai_controller(controller)

	if not should_retreat:
		return Assertions.AssertResult.new(false,
			"Should retreat at low HP (20%%) with enemy nearby")

	return Assertions.AssertResult.new(true)


func test_retreating_units_starts_empty() -> Assertions.AssertResult:
	## retreating_units array should start empty
	var controller = _create_ai_controller()
	await runner.wait_frames(2)

	var count = controller.retreating_units.size()

	_cleanup_ai_controller(controller)

	if count != 0:
		return Assertions.AssertResult.new(false,
			"retreating_units should start empty, has: %d" % count)

	return Assertions.AssertResult.new(true)


# === Phase 3C: Focus Fire Tests ===

func test_count_units_attacking_target_returns_zero_with_no_attackers() -> Assertions.AssertResult:
	## _count_units_attacking_target should return 0 when no units are attacking target
	var controller = _create_ai_controller()
	await runner.wait_frames(2)

	# Spawn a player unit as potential target
	var target = runner.spawner.spawn_militia(Vector2(200, 200), 0)
	await runner.wait_frames(2)

	var count = controller._count_units_attacking_target(target)

	_cleanup_ai_controller(controller)

	if count != 0:
		return Assertions.AssertResult.new(false,
			"Should return 0 when no units attacking target, got: %d" % count)

	return Assertions.AssertResult.new(true)


func test_get_attackers_on_target_delegates_to_count() -> Assertions.AssertResult:
	## get_attackers_on_target (public API) should delegate to _count_units_attacking_target
	var controller = _create_ai_controller()
	await runner.wait_frames(2)

	# Spawn a player unit as potential target
	var target = runner.spawner.spawn_militia(Vector2(200, 200), 0)
	await runner.wait_frames(2)

	# Both methods should return the same value
	var private_count = controller._count_units_attacking_target(target)
	var public_count = controller.get_attackers_on_target(target)

	_cleanup_ai_controller(controller)

	if private_count != public_count:
		return Assertions.AssertResult.new(false,
			"get_attackers_on_target should match _count_units_attacking_target")

	return Assertions.AssertResult.new(true)


func test_find_focus_fire_target_returns_null_with_no_enemies() -> Assertions.AssertResult:
	## _find_focus_fire_target should return null when no enemies nearby
	var controller = _create_ai_controller()
	await runner.wait_frames(2)

	# No enemies spawned, search near AI base
	var target = controller._find_focus_fire_target(Vector2(1600, 1600))

	_cleanup_ai_controller(controller)

	if target != null:
		return Assertions.AssertResult.new(false,
			"Should return null when no enemies nearby")

	return Assertions.AssertResult.new(true)


# === Phase 3D: Ranged Unit Kiting Tests ===

func test_is_ranged_unit_returns_true_for_archer() -> Assertions.AssertResult:
	## _is_ranged_unit should return true for Archer units
	var controller = _create_ai_controller()
	await runner.wait_frames(2)

	var archer = runner.spawner.spawn_archer(Vector2(1600, 1600), AI_TEAM)
	await runner.wait_frames(2)

	var is_ranged = controller._is_ranged_unit(archer)

	_cleanup_ai_controller(controller)

	if not is_ranged:
		return Assertions.AssertResult.new(false,
			"_is_ranged_unit should return true for Archer")

	return Assertions.AssertResult.new(true)


func test_is_ranged_unit_returns_true_for_skirmisher() -> Assertions.AssertResult:
	## _is_ranged_unit should return true for Skirmisher units
	var controller = _create_ai_controller()
	await runner.wait_frames(2)

	var skirmisher = runner.spawner.spawn_skirmisher(Vector2(1600, 1600), AI_TEAM)
	await runner.wait_frames(2)

	var is_ranged = controller._is_ranged_unit(skirmisher)

	_cleanup_ai_controller(controller)

	if not is_ranged:
		return Assertions.AssertResult.new(false,
			"_is_ranged_unit should return true for Skirmisher")

	return Assertions.AssertResult.new(true)


func test_is_ranged_unit_returns_true_for_cavalry_archer() -> Assertions.AssertResult:
	## _is_ranged_unit should return true for CavalryArcher units
	var controller = _create_ai_controller()
	await runner.wait_frames(2)

	var cav_archer = runner.spawner.spawn_cavalry_archer(Vector2(1600, 1600), AI_TEAM)
	await runner.wait_frames(2)

	var is_ranged = controller._is_ranged_unit(cav_archer)

	_cleanup_ai_controller(controller)

	if not is_ranged:
		return Assertions.AssertResult.new(false,
			"_is_ranged_unit should return true for CavalryArcher")

	return Assertions.AssertResult.new(true)


func test_is_ranged_unit_returns_false_for_militia() -> Assertions.AssertResult:
	## _is_ranged_unit should return false for Militia units
	var controller = _create_ai_controller()
	await runner.wait_frames(2)

	var militia = runner.spawner.spawn_militia(Vector2(1600, 1600), AI_TEAM)
	await runner.wait_frames(2)

	var is_ranged = controller._is_ranged_unit(militia)

	_cleanup_ai_controller(controller)

	if is_ranged:
		return Assertions.AssertResult.new(false,
			"_is_ranged_unit should return false for Militia")

	return Assertions.AssertResult.new(true)


func test_is_ranged_unit_returns_false_for_spearman() -> Assertions.AssertResult:
	## _is_ranged_unit should return false for Spearman units
	var controller = _create_ai_controller()
	await runner.wait_frames(2)

	var spearman = runner.spawner.spawn_spearman(Vector2(1600, 1600), AI_TEAM)
	await runner.wait_frames(2)

	var is_ranged = controller._is_ranged_unit(spearman)

	_cleanup_ai_controller(controller)

	if is_ranged:
		return Assertions.AssertResult.new(false,
			"_is_ranged_unit should return false for Spearman")

	return Assertions.AssertResult.new(true)


func test_is_ranged_unit_returns_false_for_scout_cavalry() -> Assertions.AssertResult:
	## _is_ranged_unit should return false for ScoutCavalry units
	var controller = _create_ai_controller()
	await runner.wait_frames(2)

	var scout = runner.spawner.spawn_scout_cavalry(Vector2(1600, 1600), AI_TEAM)
	await runner.wait_frames(2)

	var is_ranged = controller._is_ranged_unit(scout)

	_cleanup_ai_controller(controller)

	if is_ranged:
		return Assertions.AssertResult.new(false,
			"_is_ranged_unit should return false for ScoutCavalry")

	return Assertions.AssertResult.new(true)


func test_kiting_units_starts_empty() -> Assertions.AssertResult:
	## kiting_units array should start empty
	var controller = _create_ai_controller()
	await runner.wait_frames(2)

	var count = controller.kiting_units.size()

	_cleanup_ai_controller(controller)

	if count != 0:
		return Assertions.AssertResult.new(false,
			"kiting_units should start empty, has: %d" % count)

	return Assertions.AssertResult.new(true)


func test_get_nearest_melee_threat_returns_null_when_no_enemies() -> Assertions.AssertResult:
	## _get_nearest_melee_threat should return null when no melee enemies nearby
	var controller = _create_ai_controller()
	await runner.wait_frames(2)

	# No enemies spawned
	var threat = controller._get_nearest_melee_threat(Vector2(1600, 1600), 100.0)

	_cleanup_ai_controller(controller)

	if threat != null:
		return Assertions.AssertResult.new(false,
			"Should return null when no melee enemies nearby")

	return Assertions.AssertResult.new(true)


# === Phase 3D: Villager Flee Behavior Tests ===

func test_fleeing_villagers_starts_empty() -> Assertions.AssertResult:
	## fleeing_villagers array should start empty
	var controller = _create_ai_controller()
	await runner.wait_frames(2)

	var count = controller.fleeing_villagers.size()

	_cleanup_ai_controller(controller)

	if count != 0:
		return Assertions.AssertResult.new(false,
			"fleeing_villagers should start empty, has: %d" % count)

	return Assertions.AssertResult.new(true)


# === Phase 3D: Town Bell System Tests ===

func test_town_bell_active_starts_false() -> Assertions.AssertResult:
	## town_bell_active should start as false
	var controller = _create_ai_controller()
	await runner.wait_frames(2)

	var is_active = controller.town_bell_active

	_cleanup_ai_controller(controller)

	if is_active:
		return Assertions.AssertResult.new(false,
			"town_bell_active should start as false")

	return Assertions.AssertResult.new(true)


func test_town_bell_cooldown_timer_starts_at_zero() -> Assertions.AssertResult:
	## town_bell_cooldown_timer should start at 0
	var controller = _create_ai_controller()
	await runner.wait_frames(2)

	var timer = controller.town_bell_cooldown_timer

	_cleanup_ai_controller(controller)

	if timer != 0.0:
		return Assertions.AssertResult.new(false,
			"town_bell_cooldown_timer should start at 0, got: %f" % timer)

	return Assertions.AssertResult.new(true)


func test_town_bell_threat_threshold_constant() -> Assertions.AssertResult:
	## TOWN_BELL_THREAT_THRESHOLD should be 3
	var expected = 3

	if AIController.TOWN_BELL_THREAT_THRESHOLD != expected:
		return Assertions.AssertResult.new(false,
			"TOWN_BELL_THREAT_THRESHOLD should be %d, got: %d" % [expected, AIController.TOWN_BELL_THREAT_THRESHOLD])

	return Assertions.AssertResult.new(true)


func test_town_bell_cooldown_constant() -> Assertions.AssertResult:
	## TOWN_BELL_COOLDOWN should be 30.0
	var expected = 30.0

	if abs(AIController.TOWN_BELL_COOLDOWN - expected) > 0.01:
		return Assertions.AssertResult.new(false,
			"TOWN_BELL_COOLDOWN should be %f, got: %f" % [expected, AIController.TOWN_BELL_COOLDOWN])

	return Assertions.AssertResult.new(true)


# === Phase 3D: Split Attention Tests ===

func test_harass_squad_starts_empty() -> Assertions.AssertResult:
	## harass_squad array should start empty
	var controller = _create_ai_controller()
	await runner.wait_frames(2)

	var count = controller.harass_squad.size()

	_cleanup_ai_controller(controller)

	if count != 0:
		return Assertions.AssertResult.new(false,
			"harass_squad should start empty, has: %d" % count)

	return Assertions.AssertResult.new(true)


func test_can_split_attention_returns_false_with_no_military() -> Assertions.AssertResult:
	## can_split_attention() should return false when AI has no military
	var controller = _create_ai_controller()
	await runner.wait_frames(2)

	# No military spawned
	var can_split = controller.can_split_attention()

	_cleanup_ai_controller(controller)

	if can_split:
		return Assertions.AssertResult.new(false,
			"can_split_attention() should return false with no military")

	return Assertions.AssertResult.new(true)


func test_harass_force_size_constant() -> Assertions.AssertResult:
	## HARASS_FORCE_SIZE should be 3
	var expected = 3

	if AIController.HARASS_FORCE_SIZE != expected:
		return Assertions.AssertResult.new(false,
			"HARASS_FORCE_SIZE should be %d, got: %d" % [expected, AIController.HARASS_FORCE_SIZE])

	return Assertions.AssertResult.new(true)


# === Phase 3D: Reinforcement Waves Tests ===

func test_main_army_starts_empty() -> Assertions.AssertResult:
	## main_army array should start empty
	var controller = _create_ai_controller()
	await runner.wait_frames(2)

	var count = controller.main_army.size()

	_cleanup_ai_controller(controller)

	if count != 0:
		return Assertions.AssertResult.new(false,
			"main_army should start empty, has: %d" % count)

	return Assertions.AssertResult.new(true)


func test_active_attack_position_starts_at_zero() -> Assertions.AssertResult:
	## active_attack_position should start as Vector2.ZERO
	var controller = _create_ai_controller()
	await runner.wait_frames(2)

	var pos = controller.active_attack_position

	_cleanup_ai_controller(controller)

	if pos != Vector2.ZERO:
		return Assertions.AssertResult.new(false,
			"active_attack_position should start as Vector2.ZERO, got: %s" % str(pos))

	return Assertions.AssertResult.new(true)


func test_reinforcement_rally_point_starts_at_zero() -> Assertions.AssertResult:
	## reinforcement_rally_point should start as Vector2.ZERO
	var controller = _create_ai_controller()
	await runner.wait_frames(2)

	var pos = controller.reinforcement_rally_point

	_cleanup_ai_controller(controller)

	if pos != Vector2.ZERO:
		return Assertions.AssertResult.new(false,
			"reinforcement_rally_point should start as Vector2.ZERO, got: %s" % str(pos))

	return Assertions.AssertResult.new(true)


func test_get_rally_point_returns_position_between_base_and_attack() -> Assertions.AssertResult:
	## _get_rally_point_for_attack should return a position between AI base and attack position
	var controller = _create_ai_controller()
	await runner.wait_frames(2)

	# Define an attack position (player base area)
	var attack_pos = Vector2(200, 200)
	var rally_point = controller._get_rally_point_for_attack(attack_pos)

	# AI base is at approximately (1700, 1700) - AIController.AI_BASE_POSITION
	var ai_base = AIController.AI_BASE_POSITION

	# Rally point should be between AI base and attack position
	# Check that rally point is closer to AI base than the attack position
	var dist_rally_to_base = rally_point.distance_to(ai_base)
	var dist_attack_to_base = attack_pos.distance_to(ai_base)

	_cleanup_ai_controller(controller)

	if dist_rally_to_base >= dist_attack_to_base:
		return Assertions.AssertResult.new(false,
			"Rally point should be closer to AI base than attack position")

	# Rally point should be in the direction of the attack
	var direction_to_attack = ai_base.direction_to(attack_pos)
	var direction_to_rally = ai_base.direction_to(rally_point)
	var dot_product = direction_to_attack.dot(direction_to_rally)

	if dot_product < 0.9:
		return Assertions.AssertResult.new(false,
			"Rally point should be in direction of attack (dot product: %f)" % dot_product)

	return Assertions.AssertResult.new(true)


# === Phase 3D: Helper Function Tests ===

func test_is_unit_idle_or_patrolling_returns_false_for_invalid_unit() -> Assertions.AssertResult:
	## _is_unit_idle_or_patrolling should return false for invalid/null unit
	var controller = _create_ai_controller()
	await runner.wait_frames(2)

	# Pass null (invalid unit)
	var is_idle = controller._is_unit_idle_or_patrolling(null)

	_cleanup_ai_controller(controller)

	if is_idle:
		return Assertions.AssertResult.new(false,
			"_is_unit_idle_or_patrolling should return false for invalid unit")

	return Assertions.AssertResult.new(true)


func test_kite_distance_constant() -> Assertions.AssertResult:
	## KITE_DISTANCE should be 60.0
	var expected = 60.0

	if abs(AIController.KITE_DISTANCE - expected) > 0.01:
		return Assertions.AssertResult.new(false,
			"KITE_DISTANCE should be %f, got: %f" % [expected, AIController.KITE_DISTANCE])

	return Assertions.AssertResult.new(true)


func test_melee_threat_range_constant() -> Assertions.AssertResult:
	## MELEE_THREAT_RANGE should be 80.0
	var expected = 80.0

	if abs(AIController.MELEE_THREAT_RANGE - expected) > 0.01:
		return Assertions.AssertResult.new(false,
			"MELEE_THREAT_RANGE should be %f, got: %f" % [expected, AIController.MELEE_THREAT_RANGE])

	return Assertions.AssertResult.new(true)


func test_villager_flee_radius_constant() -> Assertions.AssertResult:
	## VILLAGER_FLEE_RADIUS should be 150.0
	var expected = 150.0

	if abs(AIController.VILLAGER_FLEE_RADIUS - expected) > 0.01:
		return Assertions.AssertResult.new(false,
			"VILLAGER_FLEE_RADIUS should be %f, got: %f" % [expected, AIController.VILLAGER_FLEE_RADIUS])

	return Assertions.AssertResult.new(true)
