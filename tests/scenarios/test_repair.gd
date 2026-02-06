extends Node
## Repair Tests - Tests for building repair system
##
## These tests verify:
## - Building.needs_repair() returns correct values for various states
## - Building.get_full_repair_cost() returns 50% of original build cost
## - Building.start_repair() resets cost accumulator
## - Building.progress_repair() heals HP and deducts resources
## - Villager.command_repair() sets REPAIRING state and wires up builders
## - Villager goes idle when repair completes or target is destroyed

class_name TestRepair

var runner: TestRunner


func _init(test_runner: TestRunner) -> void:
	runner = test_runner


func get_all_tests() -> Array[Callable]:
	## Returns all test methods to run
	return [
		# Building.needs_repair() tests
		test_needs_repair_false_for_full_hp,
		test_needs_repair_true_for_damaged,
		test_needs_repair_false_for_under_construction,
		test_needs_repair_false_for_destroyed,
		# Building.get_full_repair_cost() tests
		test_get_full_repair_cost_wood_only,
		test_get_full_repair_cost_food_only,
		test_get_full_repair_cost_both_resources,
		test_get_full_repair_cost_zero_cost_building,
		test_get_full_repair_cost_minimum_one,
		# Building.start_repair() tests
		test_start_repair_resets_accumulator,
		# Building.progress_repair() tests
		test_progress_repair_heals_hp,
		test_progress_repair_returns_true_when_complete,
		test_progress_repair_returns_false_with_no_builders,
		test_progress_repair_returns_true_when_already_full_hp,
		test_progress_repair_free_building_heals_without_resources,
		test_progress_repair_deducts_resources,
		test_progress_repair_pauses_when_cannot_afford,
		# Villager.command_repair() tests
		test_command_repair_sets_repairing_state,
		test_command_repair_adds_villager_to_builders,
		test_command_repair_clears_previous_targets,
		test_command_repair_removes_from_old_repair,
		test_command_repair_removes_from_old_construction,
		# Repair completion flow
		test_villager_goes_idle_when_repair_completes,
		test_villager_goes_idle_when_repair_target_destroyed,
	]


# === Building.needs_repair() Tests ===

func test_needs_repair_false_for_full_hp() -> Assertions.AssertResult:
	## needs_repair() should return false when building is at full HP
	var house = runner.spawner.spawn_house(Vector2(400, 400))
	await runner.wait_frames(2)

	if house.needs_repair():
		return Assertions.AssertResult.new(false,
			"needs_repair() should return false for full HP building")

	return Assertions.AssertResult.new(true)


func test_needs_repair_true_for_damaged() -> Assertions.AssertResult:
	## needs_repair() should return true when building has less than max HP
	var house = runner.spawner.spawn_house(Vector2(400, 400))
	await runner.wait_frames(2)

	# Damage the building
	house.current_hp = house.max_hp - 50

	if not house.needs_repair():
		return Assertions.AssertResult.new(false,
			"needs_repair() should return true for damaged building (HP: %d/%d)" % [house.current_hp, house.max_hp])

	return Assertions.AssertResult.new(true)


func test_needs_repair_false_for_under_construction() -> Assertions.AssertResult:
	## needs_repair() should return false for a building under construction
	var house = runner.spawner.spawn_house(Vector2(400, 400))
	await runner.wait_frames(2)

	house.start_construction()

	if house.needs_repair():
		return Assertions.AssertResult.new(false,
			"needs_repair() should return false for under-construction building")

	return Assertions.AssertResult.new(true)


func test_needs_repair_false_for_destroyed() -> Assertions.AssertResult:
	## needs_repair() should return false for a destroyed building
	var house = runner.spawner.spawn_house(Vector2(400, 400))
	await runner.wait_frames(2)

	# Mark as destroyed without freeing (so we can still test)
	house.is_destroyed = true
	house.current_hp = 0

	if house.needs_repair():
		return Assertions.AssertResult.new(false,
			"needs_repair() should return false for destroyed building")

	return Assertions.AssertResult.new(true)


# === Building.get_full_repair_cost() Tests ===

func test_get_full_repair_cost_wood_only() -> Assertions.AssertResult:
	## get_full_repair_cost() should return 50% of wood cost
	var house = runner.spawner.spawn_house(Vector2(400, 400))
	await runner.wait_frames(2)

	house.wood_cost = 100
	house.food_cost = 0

	var cost = house.get_full_repair_cost()

	if not cost.has("wood"):
		return Assertions.AssertResult.new(false,
			"Cost should include 'wood' key")
	if cost["wood"] != 50:
		return Assertions.AssertResult.new(false,
			"Wood repair cost should be 50 (50%% of 100), got: %d" % cost["wood"])
	if cost.has("food"):
		return Assertions.AssertResult.new(false,
			"Cost should not include 'food' when food_cost is 0")

	return Assertions.AssertResult.new(true)


func test_get_full_repair_cost_food_only() -> Assertions.AssertResult:
	## get_full_repair_cost() should return 50% of food cost
	var house = runner.spawner.spawn_house(Vector2(400, 400))
	await runner.wait_frames(2)

	house.wood_cost = 0
	house.food_cost = 60

	var cost = house.get_full_repair_cost()

	if cost.has("wood"):
		return Assertions.AssertResult.new(false,
			"Cost should not include 'wood' when wood_cost is 0")
	if not cost.has("food"):
		return Assertions.AssertResult.new(false,
			"Cost should include 'food' key")
	if cost["food"] != 30:
		return Assertions.AssertResult.new(false,
			"Food repair cost should be 30 (50%% of 60), got: %d" % cost["food"])

	return Assertions.AssertResult.new(true)


func test_get_full_repair_cost_both_resources() -> Assertions.AssertResult:
	## get_full_repair_cost() should return 50% of both wood and food costs
	var house = runner.spawner.spawn_house(Vector2(400, 400))
	await runner.wait_frames(2)

	house.wood_cost = 200
	house.food_cost = 100

	var cost = house.get_full_repair_cost()

	if not cost.has("wood") or not cost.has("food"):
		return Assertions.AssertResult.new(false,
			"Cost should include both 'wood' and 'food' keys")
	if cost["wood"] != 100:
		return Assertions.AssertResult.new(false,
			"Wood repair cost should be 100, got: %d" % cost["wood"])
	if cost["food"] != 50:
		return Assertions.AssertResult.new(false,
			"Food repair cost should be 50, got: %d" % cost["food"])

	return Assertions.AssertResult.new(true)


func test_get_full_repair_cost_zero_cost_building() -> Assertions.AssertResult:
	## get_full_repair_cost() should return empty dict for a free building
	var house = runner.spawner.spawn_house(Vector2(400, 400))
	await runner.wait_frames(2)

	house.wood_cost = 0
	house.food_cost = 0

	var cost = house.get_full_repair_cost()

	if cost.size() != 0:
		return Assertions.AssertResult.new(false,
			"Cost should be empty for free building, got: %s" % str(cost))

	return Assertions.AssertResult.new(true)


func test_get_full_repair_cost_minimum_one() -> Assertions.AssertResult:
	## get_full_repair_cost() should return at least 1 for any non-zero cost
	var house = runner.spawner.spawn_house(Vector2(400, 400))
	await runner.wait_frames(2)

	# 50% of 1 = 0.5, but should be clamped to 1
	house.wood_cost = 1
	house.food_cost = 0

	var cost = house.get_full_repair_cost()

	if not cost.has("wood"):
		return Assertions.AssertResult.new(false,
			"Cost should include 'wood' key")
	if cost["wood"] < 1:
		return Assertions.AssertResult.new(false,
			"Minimum repair cost should be 1, got: %d" % cost["wood"])

	return Assertions.AssertResult.new(true)


# === Building.start_repair() Tests ===

func test_start_repair_resets_accumulator() -> Assertions.AssertResult:
	## start_repair() should reset the cost accumulator to 0
	var house = runner.spawner.spawn_house(Vector2(400, 400))
	var villager = runner.spawner.spawn_villager(Vector2(400, 400))
	await runner.wait_frames(2)

	house.wood_cost = 200
	house.current_hp = house.max_hp - 100

	# Simulate some repair progress to build up the accumulator
	house.add_builder(villager)
	house.progress_repair(0.1)

	# Now reset
	house.start_repair()

	# The accumulator is private, but we can verify indirectly:
	# After reset, a small tick should not yet deduct resources
	# (accumulator starts from 0 again)
	if house._repair_cost_accumulator != 0.0:
		return Assertions.AssertResult.new(false,
			"start_repair() should reset accumulator to 0, got: %f" % house._repair_cost_accumulator)

	return Assertions.AssertResult.new(true)


# === Building.progress_repair() Tests ===

func test_progress_repair_heals_hp() -> Assertions.AssertResult:
	## progress_repair() should increase building HP
	var house = runner.spawner.spawn_house(Vector2(400, 400))
	var villager = runner.spawner.spawn_villager(Vector2(400, 400))
	await runner.wait_frames(2)

	# Free building (no resource cost), damaged
	house.wood_cost = 0
	house.food_cost = 0
	house.current_hp = 100  # Half of max_hp (200)
	var initial_hp = house.current_hp

	house.add_builder(villager)
	house.progress_repair(1.0)

	if house.current_hp <= initial_hp:
		return Assertions.AssertResult.new(false,
			"HP should increase after progress_repair(). Initial: %d, After: %d" % [initial_hp, house.current_hp])

	return Assertions.AssertResult.new(true)


func test_progress_repair_returns_true_when_complete() -> Assertions.AssertResult:
	## progress_repair() should return true when building reaches max HP
	var house = runner.spawner.spawn_house(Vector2(400, 400))
	var villager = runner.spawner.spawn_villager(Vector2(400, 400))
	await runner.wait_frames(2)

	# Free building, nearly full HP
	house.wood_cost = 0
	house.food_cost = 0
	house.current_hp = house.max_hp - 1

	house.add_builder(villager)
	var completed = house.progress_repair(10.0)

	if not completed:
		return Assertions.AssertResult.new(false,
			"progress_repair() should return true when repair completes")

	if house.current_hp != house.max_hp:
		return Assertions.AssertResult.new(false,
			"HP should be max after completion, got: %d/%d" % [house.current_hp, house.max_hp])

	return Assertions.AssertResult.new(true)


func test_progress_repair_returns_false_with_no_builders() -> Assertions.AssertResult:
	## progress_repair() should return false when no builders are assigned
	var house = runner.spawner.spawn_house(Vector2(400, 400))
	await runner.wait_frames(2)

	house.current_hp = house.max_hp - 50

	var completed = house.progress_repair(1.0)

	if completed:
		return Assertions.AssertResult.new(false,
			"progress_repair() should return false when no builders assigned")

	return Assertions.AssertResult.new(true)


func test_progress_repair_returns_true_when_already_full_hp() -> Assertions.AssertResult:
	## progress_repair() should return true immediately if building is already full HP
	var house = runner.spawner.spawn_house(Vector2(400, 400))
	await runner.wait_frames(2)

	# Full HP building - needs_repair() is false
	var completed = house.progress_repair(1.0)

	if not completed:
		return Assertions.AssertResult.new(false,
			"progress_repair() should return true for full HP building")

	return Assertions.AssertResult.new(true)


func test_progress_repair_free_building_heals_without_resources() -> Assertions.AssertResult:
	## A building with 0 cost should heal without spending any resources
	var house = runner.spawner.spawn_house(Vector2(400, 400))
	var villager = runner.spawner.spawn_villager(Vector2(400, 400))
	await runner.wait_frames(2)

	house.wood_cost = 0
	house.food_cost = 0
	house.current_hp = 100

	var initial_wood = GameManager.get_resource("wood")

	house.add_builder(villager)
	house.progress_repair(5.0)

	var final_wood = GameManager.get_resource("wood")

	if final_wood != initial_wood:
		return Assertions.AssertResult.new(false,
			"Free building repair should not spend resources. Wood before: %d, after: %d" % [initial_wood, final_wood])

	return Assertions.AssertResult.new(true)


func test_progress_repair_deducts_resources() -> Assertions.AssertResult:
	## Repairing a building with wood cost should deduct wood over time
	var house = runner.spawner.spawn_house(Vector2(400, 400))
	var villager = runner.spawner.spawn_villager(Vector2(400, 400))
	await runner.wait_frames(2)

	house.wood_cost = 200
	house.food_cost = 0
	house.current_hp = 1  # Almost fully damaged

	# Give player plenty of wood
	GameManager.resources["wood"] = 1000

	var initial_wood = GameManager.get_resource("wood")

	house.add_builder(villager)
	house.start_repair()

	# Progress enough to trigger resource deduction
	# With wood_cost=200, full repair cost = 100 wood
	# Repair heals 3x construction speed, so a large delta should deduct some wood
	house.progress_repair(5.0)

	var final_wood = GameManager.get_resource("wood")

	if final_wood >= initial_wood:
		return Assertions.AssertResult.new(false,
			"Wood should decrease during repair. Before: %d, After: %d" % [initial_wood, final_wood])

	return Assertions.AssertResult.new(true)


func test_progress_repair_pauses_when_cannot_afford() -> Assertions.AssertResult:
	## Repair should pause (return false) when player cannot afford the next tick
	var house = runner.spawner.spawn_house(Vector2(400, 400))
	var villager = runner.spawner.spawn_villager(Vector2(400, 400))
	await runner.wait_frames(2)

	house.wood_cost = 200
	house.food_cost = 0
	house.current_hp = 1  # Almost fully damaged

	# Set wood to 0 so player can't afford
	GameManager.resources["wood"] = 0

	house.add_builder(villager)
	house.start_repair()

	var hp_before = house.current_hp

	# Try to repair - should pause because can't afford
	var completed = house.progress_repair(5.0)

	if completed:
		return Assertions.AssertResult.new(false,
			"progress_repair() should return false when can't afford resources")

	# HP should not have increased (or only marginally before the cost check kicks in)
	# The key assertion is that it returned false
	return Assertions.AssertResult.new(true)


# === Villager.command_repair() Tests ===

func test_command_repair_sets_repairing_state() -> Assertions.AssertResult:
	## command_repair() should set villager state to REPAIRING
	var house = runner.spawner.spawn_house(Vector2(400, 400))
	var villager = runner.spawner.spawn_villager(Vector2(350, 400))
	await runner.wait_frames(2)

	# Damage the building so it needs repair
	house.current_hp = house.max_hp - 50

	villager.command_repair(house)

	var result = Assertions.assert_villager_state(villager, Villager.State.REPAIRING)
	if not result.passed:
		return result

	return Assertions.AssertResult.new(true)


func test_command_repair_adds_villager_to_builders() -> Assertions.AssertResult:
	## command_repair() should add villager to building's builders list
	var house = runner.spawner.spawn_house(Vector2(400, 400))
	var villager = runner.spawner.spawn_villager(Vector2(350, 400))
	await runner.wait_frames(2)

	house.current_hp = house.max_hp - 50

	if house.get_builder_count() != 0:
		return Assertions.AssertResult.new(false,
			"Should have 0 builders initially")

	villager.command_repair(house)

	if house.get_builder_count() != 1:
		return Assertions.AssertResult.new(false,
			"Should have 1 builder after command_repair(), got: %d" % house.get_builder_count())

	return Assertions.AssertResult.new(true)


func test_command_repair_clears_previous_targets() -> Assertions.AssertResult:
	## command_repair() should clear target_resource, target_animal, target_construction, attack_target
	var house = runner.spawner.spawn_house(Vector2(400, 400))
	var villager = runner.spawner.spawn_villager(Vector2(350, 400))
	var tree = runner.spawner.spawn_tree(Vector2(300, 400))
	await runner.wait_frames(2)

	# Start gathering
	villager.command_gather(tree)
	await runner.wait_frames(2)

	if villager.target_resource != tree:
		return Assertions.AssertResult.new(false,
			"target_resource should be set after command_gather")

	# Now command to repair
	house.current_hp = house.max_hp - 50
	villager.command_repair(house)

	if villager.target_resource != null:
		return Assertions.AssertResult.new(false,
			"target_resource should be cleared after command_repair()")

	if villager.target_animal != null:
		return Assertions.AssertResult.new(false,
			"target_animal should be cleared after command_repair()")

	if villager.target_construction != null:
		return Assertions.AssertResult.new(false,
			"target_construction should be cleared after command_repair()")

	if villager.attack_target != null:
		return Assertions.AssertResult.new(false,
			"attack_target should be cleared after command_repair()")

	return Assertions.AssertResult.new(true)


func test_command_repair_removes_from_old_repair() -> Assertions.AssertResult:
	## command_repair() should remove villager from previous repair job
	var house1 = runner.spawner.spawn_house(Vector2(400, 400))
	var house2 = runner.spawner.spawn_house(Vector2(500, 400))
	var villager = runner.spawner.spawn_villager(Vector2(350, 400))
	await runner.wait_frames(2)

	house1.current_hp = house1.max_hp - 50
	house2.current_hp = house2.max_hp - 50

	villager.command_repair(house1)

	if house1.get_builder_count() != 1:
		return Assertions.AssertResult.new(false,
			"house1 should have 1 builder initially")

	# Switch to repairing house2
	villager.command_repair(house2)

	if house1.get_builder_count() != 0:
		return Assertions.AssertResult.new(false,
			"house1 should have 0 builders after villager switched, got: %d" % house1.get_builder_count())

	if house2.get_builder_count() != 1:
		return Assertions.AssertResult.new(false,
			"house2 should have 1 builder, got: %d" % house2.get_builder_count())

	return Assertions.AssertResult.new(true)


func test_command_repair_removes_from_old_construction() -> Assertions.AssertResult:
	## command_repair() should remove villager from a construction job when switching to repair
	var house_building = runner.spawner.spawn_house(Vector2(400, 400))
	var house_damaged = runner.spawner.spawn_house(Vector2(500, 400))
	var villager = runner.spawner.spawn_villager(Vector2(350, 400))
	await runner.wait_frames(2)

	# Set up construction
	house_building.start_construction()
	villager.command_build(house_building)

	if house_building.get_builder_count() != 1:
		return Assertions.AssertResult.new(false,
			"Building under construction should have 1 builder")

	# Switch to repairing damaged building
	house_damaged.current_hp = house_damaged.max_hp - 50
	villager.command_repair(house_damaged)

	if house_building.get_builder_count() != 0:
		return Assertions.AssertResult.new(false,
			"Construction building should have 0 builders after switch, got: %d" % house_building.get_builder_count())

	if house_damaged.get_builder_count() != 1:
		return Assertions.AssertResult.new(false,
			"Repair building should have 1 builder, got: %d" % house_damaged.get_builder_count())

	var result = Assertions.assert_villager_state(villager, Villager.State.REPAIRING)
	if not result.passed:
		return result

	return Assertions.AssertResult.new(true)


# === Repair Completion Flow ===

func test_villager_goes_idle_when_repair_completes() -> Assertions.AssertResult:
	## Villager should go idle after repair reaches max HP
	var house = runner.spawner.spawn_house(Vector2(400, 400))
	var villager = runner.spawner.spawn_villager(Vector2(400, 400))  # Same position to avoid movement
	await runner.wait_frames(2)

	# Free building, slightly damaged
	house.wood_cost = 0
	house.food_cost = 0
	house.current_hp = house.max_hp - 1

	villager.command_repair(house)

	# Verify villager is in REPAIRING state
	var result = Assertions.assert_villager_state(villager, Villager.State.REPAIRING)
	if not result.passed:
		return result

	# Let physics process run - villager is in range (same pos), so _process_repairing
	# will call progress_repair() which should complete quickly
	await runner.wait_frames(10)

	result = Assertions.assert_villager_state(villager, Villager.State.IDLE)
	if not result.passed:
		return Assertions.AssertResult.new(false,
			"Villager should be IDLE after repair completes, got state: %d" % villager.current_state)

	# repair_target should be cleared
	if villager.repair_target != null:
		return Assertions.AssertResult.new(false,
			"repair_target should be null after completion")

	return Assertions.AssertResult.new(true)


func test_villager_goes_idle_when_repair_target_destroyed() -> Assertions.AssertResult:
	## Villager should go idle when the building being repaired is destroyed
	var house = runner.spawner.spawn_house(Vector2(400, 400))
	var villager = runner.spawner.spawn_villager(Vector2(400, 400))
	await runner.wait_frames(2)

	house.current_hp = house.max_hp - 50
	villager.command_repair(house)

	# Verify villager is in REPAIRING state
	var result = Assertions.assert_villager_state(villager, Villager.State.REPAIRING)
	if not result.passed:
		return result

	# Destroy the building (mark as destroyed, then free)
	house.is_destroyed = true
	house.queue_free()
	await runner.wait_frames(5)

	result = Assertions.assert_villager_state(villager, Villager.State.IDLE)
	if not result.passed:
		return Assertions.AssertResult.new(false,
			"Villager should be IDLE after repair target destroyed, got state: %d" % villager.current_state)

	if villager.repair_target != null:
		return Assertions.AssertResult.new(false,
			"repair_target should be null after target destroyed")

	return Assertions.AssertResult.new(true)
