extends Node
## AI Tests - Tests for AI Controller economic and military decisions (Phase 2C)
##
## These tests verify:
## - Villager training decisions
## - Villager allocation to resources
## - Farm building decisions
## - Mill building decisions
## - Military building variety (Archery Range, Stable)
## - Mixed army training decisions
## - Attack threshold logic
## - Building rebuilding logic

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
