extends Node
## Resource Tests - Tests for resource nodes and gathering different resource types
##
## These tests verify:
## - Villager can gather food from berry bushes
## - Villager can gather gold from gold mines
## - Villager can gather stone from stone mines
## - Resource nodes deplete and emit signal when empty
## - Farm provides infinite food at slower rate
## - Mining camp is correctly selected for gold/stone drop-off

class_name TestResources

var runner: TestRunner


func _init(test_runner: TestRunner) -> void:
	runner = test_runner


func get_all_tests() -> Array[Callable]:
	## Returns all test methods to run
	return [
		# Resource gathering by type
		test_villager_gathers_food_from_berry_bush,
		test_villager_gathers_gold_from_mine,
		test_villager_gathers_stone_from_mine,
		# Drop-off building selection
		test_villager_finds_mining_camp_for_gold,
		test_villager_finds_mining_camp_for_stone,
		test_villager_finds_mill_for_food,
		test_villager_finds_tc_as_universal_dropoff,
		# Resource depletion
		test_resource_node_depletes_and_emits_signal,
		test_resource_node_frees_when_depleted,
		# Farm special behavior
		test_farm_provides_infinite_food,
		test_farm_has_slower_gather_rate,
		test_villager_command_gather_on_farm,
		# Edge cases
		test_villager_waits_when_no_dropoff_available,
		# Villager movement
		test_villager_move_to_changes_state,
		test_villager_move_to_clears_targets,
	]


# === Resource Gathering by Type ===

func test_villager_gathers_food_from_berry_bush() -> Assertions.AssertResult:
	## Villager should be able to gather food from berry bush
	var villager = runner.spawner.spawn_villager(Vector2(400, 400))
	var berry_bush = runner.spawner.spawn_berry_bush(Vector2(420, 400), 100)
	await runner.wait_frames(2)

	villager.command_gather(berry_bush)
	await runner.wait_frames(2)

	# Verify state and target
	var result = Assertions.assert_villager_state(villager, Villager.State.GATHERING)
	if not result.passed:
		return result

	if villager.target_resource != berry_bush:
		return Assertions.AssertResult.new(false,
			"Villager should target the berry bush")

	return Assertions.assert_true(villager.carried_resource_type == "food",
		"Villager should have carried_resource_type = 'food', got: %s" % villager.carried_resource_type)


func test_villager_gathers_gold_from_mine() -> Assertions.AssertResult:
	## Villager should be able to gather gold from gold mine
	var villager = runner.spawner.spawn_villager(Vector2(400, 400))
	var gold_mine = runner.spawner.spawn_gold_mine(Vector2(420, 400), 800)
	await runner.wait_frames(2)

	villager.command_gather(gold_mine)
	await runner.wait_frames(2)

	var result = Assertions.assert_villager_state(villager, Villager.State.GATHERING)
	if not result.passed:
		return result

	return Assertions.assert_true(villager.carried_resource_type == "gold",
		"Villager should have carried_resource_type = 'gold', got: %s" % villager.carried_resource_type)


func test_villager_gathers_stone_from_mine() -> Assertions.AssertResult:
	## Villager should be able to gather stone from stone mine
	var villager = runner.spawner.spawn_villager(Vector2(400, 400))
	var stone_mine = runner.spawner.spawn_stone_mine(Vector2(420, 400), 350)
	await runner.wait_frames(2)

	villager.command_gather(stone_mine)
	await runner.wait_frames(2)

	var result = Assertions.assert_villager_state(villager, Villager.State.GATHERING)
	if not result.passed:
		return result

	return Assertions.assert_true(villager.carried_resource_type == "stone",
		"Villager should have carried_resource_type = 'stone', got: %s" % villager.carried_resource_type)


# === Drop-off Building Selection ===

func test_villager_finds_mining_camp_for_gold() -> Assertions.AssertResult:
	## Villager with gold should find mining camp (not lumber camp or mill)
	var villager = runner.spawner.spawn_villager(Vector2(400, 400))
	# Place all types - only mining camp accepts gold
	var lumber_camp = runner.spawner.spawn_lumber_camp(Vector2(380, 400))  # Closer
	var mill = runner.spawner.spawn_mill(Vector2(390, 400))  # Closer
	var mining_camp = runner.spawner.spawn_mining_camp(Vector2(500, 400))  # Further
	await runner.wait_frames(2)

	villager.carried_resource_type = "gold"
	villager.carried_amount = 10

	var drop_off = villager._find_drop_off("gold")

	if drop_off == null:
		return Assertions.AssertResult.new(false,
			"_find_drop_off should find a building for gold")

	if drop_off != mining_camp:
		return Assertions.AssertResult.new(false,
			"_find_drop_off for gold should return mining_camp, got: %s" % str(drop_off))

	return Assertions.AssertResult.new(true)


func test_villager_finds_mining_camp_for_stone() -> Assertions.AssertResult:
	## Villager with stone should find mining camp
	var villager = runner.spawner.spawn_villager(Vector2(400, 400))
	var lumber_camp = runner.spawner.spawn_lumber_camp(Vector2(380, 400))
	var mining_camp = runner.spawner.spawn_mining_camp(Vector2(500, 400))
	await runner.wait_frames(2)

	villager.carried_resource_type = "stone"
	villager.carried_amount = 10

	var drop_off = villager._find_drop_off("stone")

	if drop_off != mining_camp:
		return Assertions.AssertResult.new(false,
			"_find_drop_off for stone should return mining_camp, got: %s" % str(drop_off))

	return Assertions.AssertResult.new(true)


func test_villager_finds_mill_for_food() -> Assertions.AssertResult:
	## Villager with food should find mill (not lumber camp or mining camp)
	var villager = runner.spawner.spawn_villager(Vector2(400, 400))
	var lumber_camp = runner.spawner.spawn_lumber_camp(Vector2(380, 400))  # Closer
	var mining_camp = runner.spawner.spawn_mining_camp(Vector2(390, 400))  # Closer
	var mill = runner.spawner.spawn_mill(Vector2(500, 400))  # Further
	await runner.wait_frames(2)

	villager.carried_resource_type = "food"
	villager.carried_amount = 10

	var drop_off = villager._find_drop_off("food")

	if drop_off != mill:
		return Assertions.AssertResult.new(false,
			"_find_drop_off for food should return mill, got: %s" % str(drop_off))

	return Assertions.AssertResult.new(true)


func test_villager_finds_tc_as_universal_dropoff() -> Assertions.AssertResult:
	## Town Center should accept all resource types (universal drop-off)
	var villager = runner.spawner.spawn_villager(Vector2(400, 400))
	var tc = runner.spawner.spawn_town_center(Vector2(500, 400))
	await runner.wait_frames(2)

	# Test all four resource types
	for resource_type in ["wood", "food", "gold", "stone"]:
		villager.carried_resource_type = resource_type
		villager.carried_amount = 10

		var drop_off = villager._find_drop_off(resource_type)

		if drop_off != tc:
			return Assertions.AssertResult.new(false,
				"TC should accept %s but _find_drop_off returned: %s" % [resource_type, str(drop_off)])

	return Assertions.AssertResult.new(true)


# === Resource Depletion ===

func test_resource_node_depletes_and_emits_signal() -> Assertions.AssertResult:
	## Resource node should emit depleted signal when fully harvested
	var tree = runner.spawner.spawn_tree(Vector2(400, 400), 5)  # Small amount
	await runner.wait_frames(2)

	var signal_received = [false]
	tree.depleted.connect(func(): signal_received[0] = true)

	# Harvest all resources
	tree.harvest(5)
	await runner.wait_frames(2)

	if not signal_received[0]:
		return Assertions.AssertResult.new(false,
			"depleted signal should be emitted when resource is fully harvested")

	return Assertions.AssertResult.new(true)


func test_resource_node_frees_when_depleted() -> Assertions.AssertResult:
	## Resource node should queue_free itself when depleted
	var tree = runner.spawner.spawn_tree(Vector2(400, 400), 5)
	await runner.wait_frames(2)

	# Harvest all
	tree.harvest(5)
	await runner.wait_frames(5)  # Let queue_free process

	if is_instance_valid(tree):
		return Assertions.AssertResult.new(false,
			"Resource node should be freed after depletion")

	return Assertions.AssertResult.new(true)


# === Farm Special Behavior ===

func test_farm_provides_infinite_food() -> Assertions.AssertResult:
	## Farm's has_resources should always return true (infinite)
	var farm = runner.spawner.spawn_farm(Vector2(400, 400))
	await runner.wait_frames(2)

	# Harvest many times - should always succeed
	for i in range(100):
		var harvested = farm.harvest(1)
		if harvested != 1:
			return Assertions.AssertResult.new(false,
				"Farm should always return requested harvest amount, got: %d" % harvested)

	if not farm.has_resources():
		return Assertions.AssertResult.new(false,
			"Farm has_resources should always return true")

	return Assertions.AssertResult.new(true)


func test_farm_has_slower_gather_rate() -> Assertions.AssertResult:
	## Farm should have gather_rate of 0.5 (slower than natural resources)
	var farm = runner.spawner.spawn_farm(Vector2(400, 400))
	var tree = runner.spawner.spawn_tree(Vector2(500, 400))
	await runner.wait_frames(2)

	# Farm gather_rate should be 0.5
	if abs(farm.gather_rate - 0.5) > 0.01:
		return Assertions.AssertResult.new(false,
			"Farm gather_rate should be 0.5, got: %.2f" % farm.gather_rate)

	# Tree (normal resource) should have gather_rate of 1.0
	if abs(tree.gather_rate - 1.0) > 0.01:
		return Assertions.AssertResult.new(false,
			"Tree gather_rate should be 1.0, got: %.2f" % tree.gather_rate)

	return Assertions.AssertResult.new(true)


func test_villager_command_gather_on_farm() -> Assertions.AssertResult:
	## Villager should be able to gather from farm using command_gather()
	## This was the bug - command_gather() rejected Farm due to ResourceNode type annotation
	var villager = runner.spawner.spawn_villager(Vector2(400, 400))
	var farm = runner.spawner.spawn_farm(Vector2(420, 400))
	await runner.wait_frames(2)

	# Call the API directly - this is what the bug fix enabled
	villager.command_gather(farm)
	await runner.wait_frames(2)

	# Verify state
	var result = Assertions.assert_villager_state(villager, Villager.State.GATHERING)
	if not result.passed:
		return result

	# Verify target is the farm
	if villager.target_resource != farm:
		return Assertions.AssertResult.new(false,
			"Villager target_resource should be the farm")

	# Verify resource type is food
	if villager.carried_resource_type != "food":
		return Assertions.AssertResult.new(false,
			"Villager carried_resource_type should be 'food', got: %s" % villager.carried_resource_type)

	return Assertions.AssertResult.new(true)


# === Edge Cases from gotchas.md ===

func test_villager_waits_when_no_dropoff_available() -> Assertions.AssertResult:
	## Villager should wait in RETURNING state when no drop-off exists (not lose resources)
	## Per gotchas.md: "If no valid drop-off exists, villager should wait in place"
	var villager = runner.spawner.spawn_villager(Vector2(400, 400))
	# No drop-off buildings spawned - only villager exists
	await runner.wait_frames(2)

	# Give villager resources and put in RETURNING state
	villager.carried_resource_type = "wood"
	villager.carried_amount = 10
	villager.current_state = Villager.State.RETURNING
	villager.drop_off_building = null

	# Process several frames
	await runner.wait_frames(10)

	# Villager should still be in RETURNING state (not IDLE)
	var result = Assertions.assert_villager_state(villager, Villager.State.RETURNING)
	if not result.passed:
		return Assertions.AssertResult.new(false,
			"Villager should stay in RETURNING state when no drop-off available, got state: %d" % villager.current_state)

	# Resources should NOT be lost
	if villager.carried_amount != 10:
		return Assertions.AssertResult.new(false,
			"Villager should keep carried resources when waiting. Expected 10, got: %d" % villager.carried_amount)

	return Assertions.AssertResult.new(true)


# === Villager Movement ===

func test_villager_move_to_changes_state() -> Assertions.AssertResult:
	## move_to() should change villager state to MOVING
	var villager = runner.spawner.spawn_villager(Vector2(400, 400))
	await runner.wait_frames(2)

	# Verify initial state is IDLE
	if villager.current_state != Villager.State.IDLE:
		return Assertions.AssertResult.new(false,
			"Villager should start in IDLE state")

	villager.move_to(Vector2(500, 500))
	await runner.wait_frames(2)

	return Assertions.assert_villager_state(villager, Villager.State.MOVING)


func test_villager_move_to_clears_targets() -> Assertions.AssertResult:
	## move_to() should clear target_resource and target_animal
	var villager = runner.spawner.spawn_villager(Vector2(400, 400))
	var tree = runner.spawner.spawn_tree(Vector2(420, 400))
	await runner.wait_frames(2)

	# First set a gather target
	villager.command_gather(tree)
	await runner.wait_frames(2)

	if villager.target_resource != tree:
		return Assertions.AssertResult.new(false,
			"Setup failed: villager should have target_resource set")

	# Now move - should clear target
	villager.move_to(Vector2(500, 500))
	await runner.wait_frames(2)

	if villager.target_resource != null:
		return Assertions.AssertResult.new(false,
			"move_to should clear target_resource, but it's still set")

	if villager.target_animal != null:
		return Assertions.AssertResult.new(false,
			"move_to should clear target_animal")

	return Assertions.AssertResult.new(true)
