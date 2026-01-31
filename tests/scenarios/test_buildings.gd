extends Node
## Building Tests - Tests for building HP, destruction, and training mechanics
##
## These tests verify:
## - Buildings take damage correctly
## - Buildings are destroyed when HP reaches 0
## - destroyed signal is emitted
## - Town Center trains villagers with correct costs
## - Barracks trains militia with correct costs
## - Archery Range trains archers with correct costs
## - Training fails when can't afford
## - Training fails when pop capped
## - House increases population cap
## - Stable trains Scout Cavalry with correct costs
## - Barracks trains Spearman with correct costs
## - Archery Range trains Skirmisher with correct costs
## - Stable trains Cavalry Archer with correct costs
## - Production queue system (Phase 2.5A):
##   - Queue capacity (MAX_QUEUE_SIZE = 15)
##   - Resources deducted on queue, refunded on cancel
##   - Queue size tracking via get_queue_size()
##   - Multiple unit types can be queued
##   - Cancel removes last queued item

class_name TestBuildings

var runner: TestRunner


func _init(test_runner: TestRunner) -> void:
	runner = test_runner


func get_all_tests() -> Array[Callable]:
	## Returns all test methods to run
	return [
		# Building HP tests
		test_building_takes_damage,
		test_building_destroyed_at_zero_hp,
		test_building_destroyed_signal_emits,
		test_building_team_assignment,
		# Town Center training tests
		test_tc_trains_villager_costs_food,
		test_tc_training_fails_if_no_food,
		test_tc_training_fails_if_pop_capped,
		test_tc_can_queue_while_training,
		# Barracks training tests
		test_barracks_trains_militia_costs_resources,
		test_barracks_training_fails_if_no_food,
		test_barracks_training_fails_if_no_wood,
		# Archery Range training tests (Phase 2A)
		test_archery_range_has_correct_cost,
		test_archery_range_trains_archer_costs_resources,
		test_archery_range_training_fails_if_no_wood,
		test_archery_range_training_fails_if_no_gold,
		test_archery_range_training_fails_if_pop_capped,
		test_archery_range_can_queue_while_training,
		test_archery_range_spawns_archer_with_correct_team,
		# Stable training tests (Phase 2B)
		test_stable_has_correct_cost_and_hp,
		test_stable_trains_scout_cavalry_costs_food,
		test_stable_training_fails_if_no_food,
		test_stable_training_fails_if_pop_capped,
		test_stable_can_queue_while_training,
		test_stable_spawns_scout_cavalry_with_correct_team,
		# Barracks Spearman training tests (Phase 2B)
		test_barracks_trains_spearman_costs_resources,
		test_barracks_spearman_training_fails_if_no_food,
		test_barracks_spearman_training_fails_if_no_wood,
		# Archery Range Skirmisher training tests (Phase 2D)
		test_archery_range_trains_skirmisher_costs_resources,
		test_archery_range_skirmisher_training_fails_if_no_food,
		test_archery_range_skirmisher_training_fails_if_no_wood,
		test_archery_range_skirmisher_training_fails_if_pop_capped,
		test_archery_range_can_queue_skirmisher_while_training,
		# Stable Cavalry Archer training tests (Phase 2D)
		test_stable_trains_cavalry_archer_costs_resources,
		test_stable_cavalry_archer_training_fails_if_no_wood,
		test_stable_cavalry_archer_training_fails_if_no_gold,
		test_stable_cavalry_archer_training_fails_if_pop_capped,
		test_stable_can_queue_cavalry_archer_while_training,
		test_stable_spawns_cavalry_archer_with_correct_team,
		# House tests
		test_house_increases_population_cap,
		# AI team tests (regression test for gotchas.md bug)
		test_ai_tc_uses_ai_resources,
		test_ai_barracks_uses_ai_resources,
		# Production Queue tests (Phase 2.5A)
		test_tc_queue_max_capacity,
		test_tc_cancel_training_refunds_resources,
		test_tc_cancel_empty_queue_returns_false,
		test_barracks_queue_mixed_unit_types,
		test_stable_queue_max_capacity,
		test_archery_range_cancel_refunds_correct_resources,
		test_market_can_queue_trade_carts,
		test_market_cancel_training_refunds_resources,
	]


# === Building HP Tests ===

func test_building_takes_damage() -> Assertions.AssertResult:
	## take_damage should reduce building HP
	var house = runner.spawner.spawn_house(Vector2(400, 400))
	await runner.wait_frames(2)

	var initial_hp = house.current_hp
	house.take_damage(50)

	if house.current_hp != initial_hp - 50:
		return Assertions.AssertResult.new(false,
			"Building HP should decrease by damage amount. Expected: %d, Got: %d" % [initial_hp - 50, house.current_hp])

	return Assertions.AssertResult.new(true)


func test_building_destroyed_at_zero_hp() -> Assertions.AssertResult:
	## Building should be destroyed (freed) when HP reaches 0
	var house = runner.spawner.spawn_house(Vector2(400, 400))
	await runner.wait_frames(2)

	house.take_damage(house.current_hp)
	await runner.wait_frames(5)

	if is_instance_valid(house):
		return Assertions.AssertResult.new(false,
			"Building should be freed after HP reaches 0")

	return Assertions.AssertResult.new(true)


func test_building_destroyed_signal_emits() -> Assertions.AssertResult:
	## destroyed signal should be emitted when building is destroyed
	var house = runner.spawner.spawn_house(Vector2(400, 400))
	await runner.wait_frames(2)

	# Use array to capture by reference (GDScript lambdas capture primitives by value)
	var signal_received = [false]
	house.destroyed.connect(func(): signal_received[0] = true)

	house.take_damage(house.current_hp)
	await runner.wait_frames(5)

	if not signal_received[0]:
		return Assertions.AssertResult.new(false,
			"destroyed signal should be emitted when building is destroyed")

	return Assertions.AssertResult.new(true)


func test_building_team_assignment() -> Assertions.AssertResult:
	## Buildings should have correct team assignment
	var player_house = runner.spawner.spawn_house(Vector2(400, 400), 0)
	var ai_house = runner.spawner.spawn_house(Vector2(500, 400), 1)
	await runner.wait_frames(2)

	if player_house.team != 0:
		return Assertions.AssertResult.new(false,
			"Player house should have team 0, got: %d" % player_house.team)

	if ai_house.team != 1:
		return Assertions.AssertResult.new(false,
			"AI house should have team 1, got: %d" % ai_house.team)

	return Assertions.AssertResult.new(true)


# === Town Center Training Tests ===

func test_tc_trains_villager_costs_food() -> Assertions.AssertResult:
	## Training a villager should cost 50 food
	var tc = runner.spawner.spawn_town_center(Vector2(400, 400))
	await runner.wait_frames(2)

	GameManager.resources["food"] = 100
	GameManager.population = 0
	GameManager.population_cap = 10

	var initial_food = GameManager.get_resource("food")
	var success = tc.train_villager()

	if not success:
		return Assertions.AssertResult.new(false,
			"train_villager should return true when can afford")

	var expected_food = initial_food - TownCenter.VILLAGER_COST
	var result = Assertions.assert_resource("food", expected_food)
	if not result.passed:
		return result

	return Assertions.assert_true(tc.is_training,
		"TC should be in training state after train_villager()")


func test_tc_training_fails_if_no_food() -> Assertions.AssertResult:
	## Training should fail if not enough food
	var tc = runner.spawner.spawn_town_center(Vector2(400, 400))
	await runner.wait_frames(2)

	GameManager.resources["food"] = 10  # Not enough (need 50)
	GameManager.population = 0
	GameManager.population_cap = 10

	var success = tc.train_villager()

	if success:
		return Assertions.AssertResult.new(false,
			"train_villager should return false when can't afford")

	return Assertions.assert_true(not tc.is_training,
		"TC should not be training when can't afford")


func test_tc_training_fails_if_pop_capped() -> Assertions.AssertResult:
	## Training should fail if at population cap
	var tc = runner.spawner.spawn_town_center(Vector2(400, 400))
	await runner.wait_frames(2)

	GameManager.resources["food"] = 100
	GameManager.population = 5
	GameManager.population_cap = 5  # At cap

	var success = tc.train_villager()

	if success:
		return Assertions.AssertResult.new(false,
			"train_villager should return false when pop capped")

	return Assertions.assert_true(not tc.is_training,
		"TC should not be training when pop capped")


func test_tc_can_queue_while_training() -> Assertions.AssertResult:
	## Can queue additional villagers while training is in progress
	var tc = runner.spawner.spawn_town_center(Vector2(400, 400))
	await runner.wait_frames(2)

	GameManager.resources["food"] = 200
	GameManager.population = 0
	GameManager.population_cap = 10

	var first_success = tc.train_villager()
	var second_success = tc.train_villager()  # Should succeed and add to queue

	if not first_success:
		return Assertions.AssertResult.new(false,
			"First train_villager should succeed")

	if not second_success:
		return Assertions.AssertResult.new(false,
			"Second train_villager should succeed (queued)")

	# Queue should have 2 items
	if tc.get_queue_size() != 2:
		return Assertions.AssertResult.new(false,
			"Queue size should be 2, got: %d" % tc.get_queue_size())

	# Food should be deducted for both
	var expected_food = 200 - (TownCenter.VILLAGER_COST * 2)
	var result = Assertions.assert_resource("food", expected_food)
	if not result.passed:
		return result

	return Assertions.AssertResult.new(true)


# === Barracks Training Tests ===

func test_barracks_trains_militia_costs_resources() -> Assertions.AssertResult:
	## Training militia should cost 60 food and 20 wood
	var barracks = runner.spawner.spawn_barracks(Vector2(400, 400))
	await runner.wait_frames(2)

	GameManager.resources["food"] = 100
	GameManager.resources["wood"] = 100
	GameManager.population = 0
	GameManager.population_cap = 10

	var initial_food = GameManager.get_resource("food")
	var initial_wood = GameManager.get_resource("wood")

	var success = barracks.train_militia()

	if not success:
		return Assertions.AssertResult.new(false,
			"train_militia should return true when can afford")

	var result = Assertions.assert_resource("food", initial_food - Barracks.MILITIA_FOOD_COST)
	if not result.passed:
		return result

	result = Assertions.assert_resource("wood", initial_wood - Barracks.MILITIA_WOOD_COST)
	if not result.passed:
		return result

	return Assertions.assert_true(barracks.is_training,
		"Barracks should be in training state")


func test_barracks_training_fails_if_no_food() -> Assertions.AssertResult:
	## Training should fail if not enough food
	var barracks = runner.spawner.spawn_barracks(Vector2(400, 400))
	await runner.wait_frames(2)

	GameManager.resources["food"] = 10  # Not enough (need 60)
	GameManager.resources["wood"] = 100
	GameManager.population = 0
	GameManager.population_cap = 10

	var success = barracks.train_militia()

	if success:
		return Assertions.AssertResult.new(false,
			"train_militia should return false when can't afford food")

	return Assertions.AssertResult.new(true)


func test_barracks_training_fails_if_no_wood() -> Assertions.AssertResult:
	## Training should fail if not enough wood
	var barracks = runner.spawner.spawn_barracks(Vector2(400, 400))
	await runner.wait_frames(2)

	GameManager.resources["food"] = 100
	GameManager.resources["wood"] = 10  # Not enough (need 20)
	GameManager.population = 0
	GameManager.population_cap = 10

	var success = barracks.train_militia()

	if success:
		return Assertions.AssertResult.new(false,
			"train_militia should return false when can't afford wood")

	return Assertions.AssertResult.new(true)


# === Archery Range Training Tests (Phase 2A) ===

func test_archery_range_has_correct_cost() -> Assertions.AssertResult:
	## Archery Range should have correct building cost (175 wood per AoE2 spec)
	var archery_range = runner.spawner.spawn_archery_range(Vector2(400, 400))
	await runner.wait_frames(2)

	if archery_range.wood_cost != 175:
		return Assertions.AssertResult.new(false,
			"Archery Range wood_cost should be 175, got: %d" % archery_range.wood_cost)

	return Assertions.AssertResult.new(true)


func test_archery_range_trains_archer_costs_resources() -> Assertions.AssertResult:
	## Training archer should cost 25 wood and 45 gold
	var archery_range = runner.spawner.spawn_archery_range(Vector2(400, 400))
	await runner.wait_frames(2)

	GameManager.resources["wood"] = 100
	GameManager.resources["gold"] = 100
	GameManager.population = 0
	GameManager.population_cap = 10

	var initial_wood = GameManager.get_resource("wood")
	var initial_gold = GameManager.get_resource("gold")

	var success = archery_range.train_archer()

	if not success:
		return Assertions.AssertResult.new(false,
			"train_archer should return true when can afford")

	var result = Assertions.assert_resource("wood", initial_wood - ArcheryRange.ARCHER_WOOD_COST)
	if not result.passed:
		return result

	result = Assertions.assert_resource("gold", initial_gold - ArcheryRange.ARCHER_GOLD_COST)
	if not result.passed:
		return result

	return Assertions.assert_true(archery_range.is_training,
		"Archery Range should be in training state")


func test_archery_range_training_fails_if_no_wood() -> Assertions.AssertResult:
	## Training should fail if not enough wood
	var archery_range = runner.spawner.spawn_archery_range(Vector2(400, 400))
	await runner.wait_frames(2)

	GameManager.resources["wood"] = 10  # Not enough (need 25)
	GameManager.resources["gold"] = 100
	GameManager.population = 0
	GameManager.population_cap = 10

	var success = archery_range.train_archer()

	if success:
		return Assertions.AssertResult.new(false,
			"train_archer should return false when can't afford wood")

	return Assertions.AssertResult.new(true)


func test_archery_range_training_fails_if_no_gold() -> Assertions.AssertResult:
	## Training should fail if not enough gold
	var archery_range = runner.spawner.spawn_archery_range(Vector2(400, 400))
	await runner.wait_frames(2)

	GameManager.resources["wood"] = 100
	GameManager.resources["gold"] = 10  # Not enough (need 45)
	GameManager.population = 0
	GameManager.population_cap = 10

	var success = archery_range.train_archer()

	if success:
		return Assertions.AssertResult.new(false,
			"train_archer should return false when can't afford gold")

	return Assertions.AssertResult.new(true)


func test_archery_range_training_fails_if_pop_capped() -> Assertions.AssertResult:
	## Training should fail if at population cap
	var archery_range = runner.spawner.spawn_archery_range(Vector2(400, 400))
	await runner.wait_frames(2)

	GameManager.resources["wood"] = 100
	GameManager.resources["gold"] = 100
	GameManager.population = 5
	GameManager.population_cap = 5  # At cap

	var success = archery_range.train_archer()

	if success:
		return Assertions.AssertResult.new(false,
			"train_archer should return false when pop capped")

	return Assertions.assert_true(not archery_range.is_training,
		"Archery Range should not be training when pop capped")


func test_archery_range_can_queue_while_training() -> Assertions.AssertResult:
	## Can queue additional archers while training is in progress
	var archery_range = runner.spawner.spawn_archery_range(Vector2(400, 400))
	await runner.wait_frames(2)

	GameManager.resources["wood"] = 200
	GameManager.resources["gold"] = 200
	GameManager.population = 0
	GameManager.population_cap = 10

	var first_success = archery_range.train_archer()
	var second_success = archery_range.train_archer()  # Should succeed and add to queue

	if not first_success:
		return Assertions.AssertResult.new(false,
			"First train_archer should succeed")

	if not second_success:
		return Assertions.AssertResult.new(false,
			"Second train_archer should succeed (queued)")

	# Queue should have 2 items
	if archery_range.get_queue_size() != 2:
		return Assertions.AssertResult.new(false,
			"Queue size should be 2, got: %d" % archery_range.get_queue_size())

	return Assertions.AssertResult.new(true)


func test_archery_range_spawns_archer_with_correct_team() -> Assertions.AssertResult:
	## Trained archer should inherit team from archery range
	## We test that training sets up correctly - actual spawn tested via spawn_archer tests
	var archery_range = runner.spawner.spawn_archery_range(Vector2(400, 400), 1)  # AI team
	await runner.wait_frames(2)

	GameManager.ai_resources["wood"] = 100
	GameManager.ai_resources["gold"] = 100
	GameManager.ai_population = 0
	GameManager.ai_population_cap = 10

	var success = archery_range.train_archer()

	if not success:
		return Assertions.AssertResult.new(false,
			"train_archer should succeed for AI team")

	# Verify training state is set correctly
	if archery_range.current_training != ArcheryRange.TrainingType.ARCHER:
		return Assertions.AssertResult.new(false,
			"Training type should be ARCHER")

	# Verify the archery range has correct team (which will be inherited by spawned unit)
	if archery_range.team != 1:
		return Assertions.AssertResult.new(false,
			"Archery range should have team 1, got: %d" % archery_range.team)

	# Test that spawned archer (via test spawner) gets correct team
	var archer = runner.spawner.spawn_archer(Vector2(500, 400), 1)
	await runner.wait_frames(2)

	if archer.team != 1:
		return Assertions.AssertResult.new(false,
			"Spawned archer should have team 1 (AI), got: %d" % archer.team)

	return Assertions.AssertResult.new(true)


# === Stable Training Tests (Phase 2B) ===

func test_stable_has_correct_cost_and_hp() -> Assertions.AssertResult:
	## Stable should have correct building cost (175 wood) and HP (1500) per AoE2 spec
	var stable = runner.spawner.spawn_stable(Vector2(400, 400))
	await runner.wait_frames(2)

	if stable.wood_cost != 175:
		return Assertions.AssertResult.new(false,
			"Stable wood_cost should be 175, got: %d" % stable.wood_cost)

	if stable.max_hp != 1500:
		return Assertions.AssertResult.new(false,
			"Stable max_hp should be 1500, got: %d" % stable.max_hp)

	if stable.current_hp != 1500:
		return Assertions.AssertResult.new(false,
			"Stable current_hp should be 1500, got: %d" % stable.current_hp)

	return Assertions.AssertResult.new(true)


func test_stable_trains_scout_cavalry_costs_food() -> Assertions.AssertResult:
	## Training Scout Cavalry should cost 80 food
	var stable = runner.spawner.spawn_stable(Vector2(400, 400))
	await runner.wait_frames(2)

	GameManager.resources["food"] = 100
	GameManager.population = 0
	GameManager.population_cap = 10

	var initial_food = GameManager.get_resource("food")

	var success = stable.train_scout_cavalry()

	if not success:
		return Assertions.AssertResult.new(false,
			"train_scout_cavalry should return true when can afford")

	var expected_food = initial_food - Stable.SCOUT_CAVALRY_FOOD_COST
	var result = Assertions.assert_resource("food", expected_food)
	if not result.passed:
		return result

	return Assertions.assert_true(stable.is_training,
		"Stable should be in training state after train_scout_cavalry()")


func test_stable_training_fails_if_no_food() -> Assertions.AssertResult:
	## Training should fail if not enough food
	var stable = runner.spawner.spawn_stable(Vector2(400, 400))
	await runner.wait_frames(2)

	GameManager.resources["food"] = 50  # Not enough (need 80)
	GameManager.population = 0
	GameManager.population_cap = 10

	var success = stable.train_scout_cavalry()

	if success:
		return Assertions.AssertResult.new(false,
			"train_scout_cavalry should return false when can't afford")

	return Assertions.assert_true(not stable.is_training,
		"Stable should not be training when can't afford")


func test_stable_training_fails_if_pop_capped() -> Assertions.AssertResult:
	## Training should fail if at population cap
	var stable = runner.spawner.spawn_stable(Vector2(400, 400))
	await runner.wait_frames(2)

	GameManager.resources["food"] = 100
	GameManager.population = 5
	GameManager.population_cap = 5  # At cap

	var success = stable.train_scout_cavalry()

	if success:
		return Assertions.AssertResult.new(false,
			"train_scout_cavalry should return false when pop capped")

	return Assertions.assert_true(not stable.is_training,
		"Stable should not be training when pop capped")


func test_stable_can_queue_while_training() -> Assertions.AssertResult:
	## Can queue additional scout cavalry while training is in progress
	var stable = runner.spawner.spawn_stable(Vector2(400, 400))
	await runner.wait_frames(2)

	GameManager.resources["food"] = 200
	GameManager.population = 0
	GameManager.population_cap = 10

	var first_success = stable.train_scout_cavalry()
	var second_success = stable.train_scout_cavalry()  # Should succeed and add to queue

	if not first_success:
		return Assertions.AssertResult.new(false,
			"First train_scout_cavalry should succeed")

	if not second_success:
		return Assertions.AssertResult.new(false,
			"Second train_scout_cavalry should succeed (queued)")

	# Queue should have 2 items
	if stable.get_queue_size() != 2:
		return Assertions.AssertResult.new(false,
			"Queue size should be 2, got: %d" % stable.get_queue_size())

	return Assertions.AssertResult.new(true)


func test_stable_spawns_scout_cavalry_with_correct_team() -> Assertions.AssertResult:
	## Trained Scout Cavalry should inherit team from stable
	var stable = runner.spawner.spawn_stable(Vector2(400, 400), 1)  # AI team
	await runner.wait_frames(2)

	GameManager.ai_resources["food"] = 100
	GameManager.ai_population = 0
	GameManager.ai_population_cap = 10

	var success = stable.train_scout_cavalry()

	if not success:
		return Assertions.AssertResult.new(false,
			"train_scout_cavalry should succeed for AI team")

	# Verify training state is set correctly
	if stable.current_training != Stable.TrainingType.SCOUT_CAVALRY:
		return Assertions.AssertResult.new(false,
			"Training type should be SCOUT_CAVALRY")

	# Verify the stable has correct team (which will be inherited by spawned unit)
	if stable.team != 1:
		return Assertions.AssertResult.new(false,
			"Stable should have team 1, got: %d" % stable.team)

	# Test that spawned scout cavalry (via test spawner) gets correct team
	var scout = runner.spawner.spawn_scout_cavalry(Vector2(500, 400), 1)
	await runner.wait_frames(2)

	if scout.team != 1:
		return Assertions.AssertResult.new(false,
			"Spawned Scout Cavalry should have team 1 (AI), got: %d" % scout.team)

	return Assertions.AssertResult.new(true)


# === Barracks Spearman Training Tests (Phase 2B) ===

func test_barracks_trains_spearman_costs_resources() -> Assertions.AssertResult:
	## Training Spearman should cost 35 food and 25 wood
	var barracks = runner.spawner.spawn_barracks(Vector2(400, 400))
	await runner.wait_frames(2)

	GameManager.resources["food"] = 100
	GameManager.resources["wood"] = 100
	GameManager.population = 0
	GameManager.population_cap = 10

	var initial_food = GameManager.get_resource("food")
	var initial_wood = GameManager.get_resource("wood")

	var success = barracks.train_spearman()

	if not success:
		return Assertions.AssertResult.new(false,
			"train_spearman should return true when can afford")

	var result = Assertions.assert_resource("food", initial_food - Barracks.SPEARMAN_FOOD_COST)
	if not result.passed:
		return result

	result = Assertions.assert_resource("wood", initial_wood - Barracks.SPEARMAN_WOOD_COST)
	if not result.passed:
		return result

	return Assertions.assert_true(barracks.is_training,
		"Barracks should be in training state")


func test_barracks_spearman_training_fails_if_no_food() -> Assertions.AssertResult:
	## Training Spearman should fail if not enough food
	var barracks = runner.spawner.spawn_barracks(Vector2(400, 400))
	await runner.wait_frames(2)

	GameManager.resources["food"] = 20  # Not enough (need 35)
	GameManager.resources["wood"] = 100
	GameManager.population = 0
	GameManager.population_cap = 10

	var success = barracks.train_spearman()

	if success:
		return Assertions.AssertResult.new(false,
			"train_spearman should return false when can't afford food")

	return Assertions.AssertResult.new(true)


func test_barracks_spearman_training_fails_if_no_wood() -> Assertions.AssertResult:
	## Training Spearman should fail if not enough wood
	var barracks = runner.spawner.spawn_barracks(Vector2(400, 400))
	await runner.wait_frames(2)

	GameManager.resources["food"] = 100
	GameManager.resources["wood"] = 10  # Not enough (need 25)
	GameManager.population = 0
	GameManager.population_cap = 10

	var success = barracks.train_spearman()

	if success:
		return Assertions.AssertResult.new(false,
			"train_spearman should return false when can't afford wood")

	return Assertions.AssertResult.new(true)


# === Archery Range Skirmisher Training Tests (Phase 2D) ===

func test_archery_range_trains_skirmisher_costs_resources() -> Assertions.AssertResult:
	## Training Skirmisher should cost 25 food and 35 wood
	var archery_range = runner.spawner.spawn_archery_range(Vector2(400, 400))
	await runner.wait_frames(2)

	GameManager.resources["food"] = 100
	GameManager.resources["wood"] = 100
	GameManager.population = 0
	GameManager.population_cap = 10

	var initial_food = GameManager.get_resource("food")
	var initial_wood = GameManager.get_resource("wood")

	var success = archery_range.train_skirmisher()

	if not success:
		return Assertions.AssertResult.new(false,
			"train_skirmisher should return true when can afford")

	var result = Assertions.assert_resource("food", initial_food - ArcheryRange.SKIRMISHER_FOOD_COST)
	if not result.passed:
		return result

	result = Assertions.assert_resource("wood", initial_wood - ArcheryRange.SKIRMISHER_WOOD_COST)
	if not result.passed:
		return result

	return Assertions.assert_true(archery_range.is_training,
		"Archery Range should be in training state")


func test_archery_range_skirmisher_training_fails_if_no_food() -> Assertions.AssertResult:
	## Training Skirmisher should fail if not enough food
	var archery_range = runner.spawner.spawn_archery_range(Vector2(400, 400))
	await runner.wait_frames(2)

	GameManager.resources["food"] = 10  # Not enough (need 25)
	GameManager.resources["wood"] = 100
	GameManager.population = 0
	GameManager.population_cap = 10

	var success = archery_range.train_skirmisher()

	if success:
		return Assertions.AssertResult.new(false,
			"train_skirmisher should return false when can't afford food")

	return Assertions.AssertResult.new(true)


func test_archery_range_skirmisher_training_fails_if_no_wood() -> Assertions.AssertResult:
	## Training Skirmisher should fail if not enough wood
	var archery_range = runner.spawner.spawn_archery_range(Vector2(400, 400))
	await runner.wait_frames(2)

	GameManager.resources["food"] = 100
	GameManager.resources["wood"] = 10  # Not enough (need 35)
	GameManager.population = 0
	GameManager.population_cap = 10

	var success = archery_range.train_skirmisher()

	if success:
		return Assertions.AssertResult.new(false,
			"train_skirmisher should return false when can't afford wood")

	return Assertions.AssertResult.new(true)


func test_archery_range_skirmisher_training_fails_if_pop_capped() -> Assertions.AssertResult:
	## Training should fail if at population cap
	var archery_range = runner.spawner.spawn_archery_range(Vector2(400, 400))
	await runner.wait_frames(2)

	GameManager.resources["food"] = 100
	GameManager.resources["wood"] = 100
	GameManager.population = 5
	GameManager.population_cap = 5  # At cap

	var success = archery_range.train_skirmisher()

	if success:
		return Assertions.AssertResult.new(false,
			"train_skirmisher should return false when pop capped")

	return Assertions.assert_true(not archery_range.is_training,
		"Archery Range should not be training when pop capped")


func test_archery_range_can_queue_skirmisher_while_training() -> Assertions.AssertResult:
	## Can queue additional skirmishers while training is in progress
	var archery_range = runner.spawner.spawn_archery_range(Vector2(400, 400))
	await runner.wait_frames(2)

	GameManager.resources["food"] = 200
	GameManager.resources["wood"] = 200
	GameManager.population = 0
	GameManager.population_cap = 10

	var first_success = archery_range.train_skirmisher()
	var second_success = archery_range.train_skirmisher()  # Should succeed and add to queue

	if not first_success:
		return Assertions.AssertResult.new(false,
			"First train_skirmisher should succeed")

	if not second_success:
		return Assertions.AssertResult.new(false,
			"Second train_skirmisher should succeed (queued)")

	# Queue should have 2 items
	if archery_range.get_queue_size() != 2:
		return Assertions.AssertResult.new(false,
			"Queue size should be 2, got: %d" % archery_range.get_queue_size())

	return Assertions.AssertResult.new(true)


# === Stable Cavalry Archer Training Tests (Phase 2D) ===

func test_stable_trains_cavalry_archer_costs_resources() -> Assertions.AssertResult:
	## Training Cavalry Archer should cost 40 wood and 70 gold
	var stable = runner.spawner.spawn_stable(Vector2(400, 400))
	await runner.wait_frames(2)

	GameManager.resources["wood"] = 100
	GameManager.resources["gold"] = 100
	GameManager.population = 0
	GameManager.population_cap = 10

	var initial_wood = GameManager.get_resource("wood")
	var initial_gold = GameManager.get_resource("gold")

	var success = stable.train_cavalry_archer()

	if not success:
		return Assertions.AssertResult.new(false,
			"train_cavalry_archer should return true when can afford")

	var result = Assertions.assert_resource("wood", initial_wood - Stable.CAVALRY_ARCHER_WOOD_COST)
	if not result.passed:
		return result

	result = Assertions.assert_resource("gold", initial_gold - Stable.CAVALRY_ARCHER_GOLD_COST)
	if not result.passed:
		return result

	return Assertions.assert_true(stable.is_training,
		"Stable should be in training state after train_cavalry_archer()")


func test_stable_cavalry_archer_training_fails_if_no_wood() -> Assertions.AssertResult:
	## Training Cavalry Archer should fail if not enough wood
	var stable = runner.spawner.spawn_stable(Vector2(400, 400))
	await runner.wait_frames(2)

	GameManager.resources["wood"] = 20  # Not enough (need 40)
	GameManager.resources["gold"] = 100
	GameManager.population = 0
	GameManager.population_cap = 10

	var success = stable.train_cavalry_archer()

	if success:
		return Assertions.AssertResult.new(false,
			"train_cavalry_archer should return false when can't afford wood")

	return Assertions.assert_true(not stable.is_training,
		"Stable should not be training when can't afford")


func test_stable_cavalry_archer_training_fails_if_no_gold() -> Assertions.AssertResult:
	## Training Cavalry Archer should fail if not enough gold
	var stable = runner.spawner.spawn_stable(Vector2(400, 400))
	await runner.wait_frames(2)

	GameManager.resources["wood"] = 100
	GameManager.resources["gold"] = 50  # Not enough (need 70)
	GameManager.population = 0
	GameManager.population_cap = 10

	var success = stable.train_cavalry_archer()

	if success:
		return Assertions.AssertResult.new(false,
			"train_cavalry_archer should return false when can't afford gold")

	return Assertions.assert_true(not stable.is_training,
		"Stable should not be training when can't afford")


func test_stable_cavalry_archer_training_fails_if_pop_capped() -> Assertions.AssertResult:
	## Training Cavalry Archer should fail if at population cap
	var stable = runner.spawner.spawn_stable(Vector2(400, 400))
	await runner.wait_frames(2)

	GameManager.resources["wood"] = 100
	GameManager.resources["gold"] = 100
	GameManager.population = 5
	GameManager.population_cap = 5  # At cap

	var success = stable.train_cavalry_archer()

	if success:
		return Assertions.AssertResult.new(false,
			"train_cavalry_archer should return false when pop capped")

	return Assertions.assert_true(not stable.is_training,
		"Stable should not be training when pop capped")


func test_stable_can_queue_cavalry_archer_while_training() -> Assertions.AssertResult:
	## Can queue additional cavalry archers while training is in progress
	var stable = runner.spawner.spawn_stable(Vector2(400, 400))
	await runner.wait_frames(2)

	GameManager.resources["wood"] = 200
	GameManager.resources["gold"] = 200
	GameManager.population = 0
	GameManager.population_cap = 10

	var first_success = stable.train_cavalry_archer()
	var second_success = stable.train_cavalry_archer()  # Should succeed and add to queue

	if not first_success:
		return Assertions.AssertResult.new(false,
			"First train_cavalry_archer should succeed")

	if not second_success:
		return Assertions.AssertResult.new(false,
			"Second train_cavalry_archer should succeed (queued)")

	# Queue should have 2 items
	if stable.get_queue_size() != 2:
		return Assertions.AssertResult.new(false,
			"Queue size should be 2, got: %d" % stable.get_queue_size())

	return Assertions.AssertResult.new(true)


func test_stable_spawns_cavalry_archer_with_correct_team() -> Assertions.AssertResult:
	## Trained Cavalry Archer should inherit team from stable
	var stable = runner.spawner.spawn_stable(Vector2(400, 400), 1)  # AI team
	await runner.wait_frames(2)

	GameManager.ai_resources["wood"] = 100
	GameManager.ai_resources["gold"] = 100
	GameManager.ai_population = 0
	GameManager.ai_population_cap = 10

	var success = stable.train_cavalry_archer()

	if not success:
		return Assertions.AssertResult.new(false,
			"train_cavalry_archer should succeed for AI team")

	# Verify training state is set correctly
	if stable.current_training != Stable.TrainingType.CAVALRY_ARCHER:
		return Assertions.AssertResult.new(false,
			"Training type should be CAVALRY_ARCHER")

	# Verify the stable has correct team (which will be inherited by spawned unit)
	if stable.team != 1:
		return Assertions.AssertResult.new(false,
			"Stable should have team 1, got: %d" % stable.team)

	# Test that spawned cavalry archer (via test spawner) gets correct team
	var cavalry_archer = runner.spawner.spawn_cavalry_archer(Vector2(500, 400), 1)
	await runner.wait_frames(2)

	if cavalry_archer.team != 1:
		return Assertions.AssertResult.new(false,
			"Spawned Cavalry Archer should have team 1 (AI), got: %d" % cavalry_archer.team)

	return Assertions.AssertResult.new(true)


# === House Tests ===

func test_house_increases_population_cap() -> Assertions.AssertResult:
	## Building a house should increase population cap by 5
	# Reset to known value
	GameManager.population_cap = 5
	var initial_cap = GameManager.population_cap

	var house = runner.spawner.spawn_house(Vector2(400, 400))
	await runner.wait_frames(2)

	if GameManager.population_cap != initial_cap + House.POPULATION_BONUS:
		return Assertions.AssertResult.new(false,
			"House should increase pop cap by %d. Expected: %d, Got: %d" % [
				House.POPULATION_BONUS, initial_cap + House.POPULATION_BONUS, GameManager.population_cap])

	return Assertions.AssertResult.new(true)


# === AI Team Tests (regression tests per gotchas.md) ===

func test_ai_tc_uses_ai_resources() -> Assertions.AssertResult:
	## AI Town Center should spend AI resources, not player resources
	var tc = runner.spawner.spawn_town_center(Vector2(400, 400), 1)  # AI team
	await runner.wait_frames(2)

	# Set up distinct resource amounts
	GameManager.ai_resources["food"] = 100
	GameManager.resources["food"] = 50  # Player has less
	GameManager.ai_population = 0
	GameManager.ai_population_cap = 10
	GameManager.population = 3
	GameManager.population_cap = 5

	var success = tc.train_villager()

	if not success:
		return Assertions.AssertResult.new(false,
			"AI TC should be able to train villager")

	# Verify AI food was spent
	if GameManager.ai_resources["food"] != 100 - TownCenter.VILLAGER_COST:
		return Assertions.AssertResult.new(false,
			"AI food should be spent. Expected: %d, Got: %d" % [
				100 - TownCenter.VILLAGER_COST, GameManager.ai_resources["food"]])

	# Verify player food is unchanged
	if GameManager.resources["food"] != 50:
		return Assertions.AssertResult.new(false,
			"Player food should be unchanged. Expected: 50, Got: %d" % GameManager.resources["food"])

	return Assertions.AssertResult.new(true)


func test_ai_barracks_uses_ai_resources() -> Assertions.AssertResult:
	## AI Barracks should spend AI resources, not player resources
	var barracks = runner.spawner.spawn_barracks(Vector2(400, 400), 1)  # AI team
	await runner.wait_frames(2)

	# Set up distinct resource amounts
	GameManager.ai_resources["food"] = 100
	GameManager.ai_resources["wood"] = 100
	GameManager.resources["food"] = 30  # Player has less
	GameManager.resources["wood"] = 10
	GameManager.ai_population = 0
	GameManager.ai_population_cap = 10

	var success = barracks.train_militia()

	if not success:
		return Assertions.AssertResult.new(false,
			"AI Barracks should be able to train militia")

	# Verify AI resources were spent
	if GameManager.ai_resources["food"] != 100 - Barracks.MILITIA_FOOD_COST:
		return Assertions.AssertResult.new(false,
			"AI food should be spent. Expected: %d, Got: %d" % [
				100 - Barracks.MILITIA_FOOD_COST, GameManager.ai_resources["food"]])

	if GameManager.ai_resources["wood"] != 100 - Barracks.MILITIA_WOOD_COST:
		return Assertions.AssertResult.new(false,
			"AI wood should be spent. Expected: %d, Got: %d" % [
				100 - Barracks.MILITIA_WOOD_COST, GameManager.ai_resources["wood"]])

	# Verify player resources unchanged
	if GameManager.resources["food"] != 30:
		return Assertions.AssertResult.new(false,
			"Player food should be unchanged")

	if GameManager.resources["wood"] != 10:
		return Assertions.AssertResult.new(false,
			"Player wood should be unchanged")

	return Assertions.AssertResult.new(true)


# === Production Queue Tests (Phase 2.5A) ===

func test_tc_queue_max_capacity() -> Assertions.AssertResult:
	## Town Center queue should be limited to MAX_QUEUE_SIZE (15)
	var tc = runner.spawner.spawn_town_center(Vector2(400, 400))
	await runner.wait_frames(2)

	# Give enough resources for 16 villagers
	GameManager.resources["food"] = 1000
	GameManager.population = 0
	GameManager.population_cap = 50

	# Queue 15 villagers (should all succeed)
	for i in range(15):
		var success = tc.train_villager()
		if not success:
			return Assertions.AssertResult.new(false,
				"Villager %d should queue successfully" % (i + 1))

	# 16th should fail
	var sixteenth = tc.train_villager()
	if sixteenth:
		return Assertions.AssertResult.new(false,
			"16th villager should fail (queue full)")

	# Verify queue size
	if tc.get_queue_size() != 15:
		return Assertions.AssertResult.new(false,
			"Queue size should be 15, got: %d" % tc.get_queue_size())

	return Assertions.AssertResult.new(true)


func test_tc_cancel_training_refunds_resources() -> Assertions.AssertResult:
	## Canceling training should refund resources for the last queued item
	var tc = runner.spawner.spawn_town_center(Vector2(400, 400))
	await runner.wait_frames(2)

	GameManager.resources["food"] = 200
	GameManager.population = 0
	GameManager.population_cap = 10

	# Queue 2 villagers
	tc.train_villager()
	tc.train_villager()

	var food_after_queue = GameManager.get_resource("food")
	var expected_after_queue = 200 - (TownCenter.VILLAGER_COST * 2)
	if food_after_queue != expected_after_queue:
		return Assertions.AssertResult.new(false,
			"Food after queueing 2 villagers should be %d, got: %d" % [expected_after_queue, food_after_queue])

	# Cancel one
	var cancel_success = tc.cancel_training()
	if not cancel_success:
		return Assertions.AssertResult.new(false,
			"cancel_training should return true")

	# Check refund
	var food_after_cancel = GameManager.get_resource("food")
	var expected_after_cancel = expected_after_queue + TownCenter.VILLAGER_COST
	if food_after_cancel != expected_after_cancel:
		return Assertions.AssertResult.new(false,
			"Food after cancel should be %d, got: %d" % [expected_after_cancel, food_after_cancel])

	# Queue should have 1 item
	if tc.get_queue_size() != 1:
		return Assertions.AssertResult.new(false,
			"Queue size should be 1 after cancel, got: %d" % tc.get_queue_size())

	return Assertions.AssertResult.new(true)


func test_tc_cancel_empty_queue_returns_false() -> Assertions.AssertResult:
	## Canceling with empty queue should return false
	var tc = runner.spawner.spawn_town_center(Vector2(400, 400))
	await runner.wait_frames(2)

	var cancel_success = tc.cancel_training()
	if cancel_success:
		return Assertions.AssertResult.new(false,
			"cancel_training should return false when queue is empty")

	return Assertions.AssertResult.new(true)


func test_barracks_queue_mixed_unit_types() -> Assertions.AssertResult:
	## Barracks can queue different unit types (militia and spearman)
	var barracks = runner.spawner.spawn_barracks(Vector2(400, 400))
	await runner.wait_frames(2)

	GameManager.resources["food"] = 500
	GameManager.resources["wood"] = 500
	GameManager.population = 0
	GameManager.population_cap = 10

	# Queue militia, spearman, militia
	var m1 = barracks.train_militia()
	var s1 = barracks.train_spearman()
	var m2 = barracks.train_militia()

	if not m1 or not s1 or not m2:
		return Assertions.AssertResult.new(false,
			"All training calls should succeed")

	if barracks.get_queue_size() != 3:
		return Assertions.AssertResult.new(false,
			"Queue size should be 3, got: %d" % barracks.get_queue_size())

	# Verify correct resources spent
	# Militia: 60F + 20W, Spearman: 35F + 25W
	# Total: (60 + 35 + 60)F = 155F, (20 + 25 + 20)W = 65W
	var expected_food = 500 - (Barracks.MILITIA_FOOD_COST * 2 + Barracks.SPEARMAN_FOOD_COST)
	var expected_wood = 500 - (Barracks.MILITIA_WOOD_COST * 2 + Barracks.SPEARMAN_WOOD_COST)

	var result = Assertions.assert_resource("food", expected_food)
	if not result.passed:
		return result

	result = Assertions.assert_resource("wood", expected_wood)
	if not result.passed:
		return result

	return Assertions.AssertResult.new(true)


func test_stable_queue_max_capacity() -> Assertions.AssertResult:
	## Stable queue should be limited to MAX_QUEUE_SIZE (15)
	var stable = runner.spawner.spawn_stable(Vector2(400, 400))
	await runner.wait_frames(2)

	GameManager.resources["food"] = 2000
	GameManager.population = 0
	GameManager.population_cap = 50

	# Queue 15 scout cavalry (should all succeed)
	for i in range(15):
		var success = stable.train_scout_cavalry()
		if not success:
			return Assertions.AssertResult.new(false,
				"Scout cavalry %d should queue successfully" % (i + 1))

	# 16th should fail
	var sixteenth = stable.train_scout_cavalry()
	if sixteenth:
		return Assertions.AssertResult.new(false,
			"16th scout cavalry should fail (queue full)")

	if stable.get_queue_size() != 15:
		return Assertions.AssertResult.new(false,
			"Queue size should be 15, got: %d" % stable.get_queue_size())

	return Assertions.AssertResult.new(true)


func test_archery_range_cancel_refunds_correct_resources() -> Assertions.AssertResult:
	## Canceling archer vs skirmisher should refund correct resource types
	var archery_range = runner.spawner.spawn_archery_range(Vector2(400, 400))
	await runner.wait_frames(2)

	GameManager.resources["food"] = 100
	GameManager.resources["wood"] = 200
	GameManager.resources["gold"] = 200
	GameManager.population = 0
	GameManager.population_cap = 10

	# Queue archer (25W + 45G) then skirmisher (25F + 35W)
	archery_range.train_archer()
	archery_range.train_skirmisher()

	# Resources should be: F=75, W=140, G=155
	var food_after = GameManager.get_resource("food")
	var wood_after = GameManager.get_resource("wood")
	var gold_after = GameManager.get_resource("gold")

	if food_after != 100 - ArcheryRange.SKIRMISHER_FOOD_COST:
		return Assertions.AssertResult.new(false,
			"Food after queueing should be %d, got: %d" % [100 - ArcheryRange.SKIRMISHER_FOOD_COST, food_after])

	# Cancel skirmisher (last in queue) - should refund 25F + 35W
	archery_range.cancel_training()

	var food_refunded = GameManager.get_resource("food")
	var wood_refunded = GameManager.get_resource("wood")
	var gold_refunded = GameManager.get_resource("gold")

	# Food should be back to 100
	if food_refunded != 100:
		return Assertions.AssertResult.new(false,
			"Food after cancel should be 100, got: %d" % food_refunded)

	# Wood should be 200 - 25 (archer) = 175
	if wood_refunded != 200 - ArcheryRange.ARCHER_WOOD_COST:
		return Assertions.AssertResult.new(false,
			"Wood after cancel should be %d, got: %d" % [200 - ArcheryRange.ARCHER_WOOD_COST, wood_refunded])

	# Gold should still be 200 - 45 = 155 (archer gold not refunded)
	if gold_refunded != 200 - ArcheryRange.ARCHER_GOLD_COST:
		return Assertions.AssertResult.new(false,
			"Gold after cancel should be %d, got: %d" % [200 - ArcheryRange.ARCHER_GOLD_COST, gold_refunded])

	return Assertions.AssertResult.new(true)


func test_market_can_queue_trade_carts() -> Assertions.AssertResult:
	## Market should support queueing trade carts
	var market = runner.spawner.spawn_market(Vector2(400, 400))
	await runner.wait_frames(2)

	GameManager.resources["wood"] = 500
	GameManager.resources["gold"] = 500
	GameManager.population = 0
	GameManager.population_cap = 10

	# Queue 3 trade carts
	var t1 = market.train_trade_cart()
	var t2 = market.train_trade_cart()
	var t3 = market.train_trade_cart()

	if not t1 or not t2 or not t3:
		return Assertions.AssertResult.new(false,
			"All trade cart training calls should succeed")

	if market.get_queue_size() != 3:
		return Assertions.AssertResult.new(false,
			"Queue size should be 3, got: %d" % market.get_queue_size())

	# Verify resources spent: 100W + 50G per cart = 300W + 150G
	var expected_wood = 500 - (Market.TRADE_CART_WOOD_COST * 3)
	var expected_gold = 500 - (Market.TRADE_CART_GOLD_COST * 3)

	var result = Assertions.assert_resource("wood", expected_wood)
	if not result.passed:
		return result

	result = Assertions.assert_resource("gold", expected_gold)
	if not result.passed:
		return result

	return Assertions.AssertResult.new(true)


func test_market_cancel_training_refunds_resources() -> Assertions.AssertResult:
	## Canceling market training should refund wood and gold
	var market = runner.spawner.spawn_market(Vector2(400, 400))
	await runner.wait_frames(2)

	GameManager.resources["wood"] = 200
	GameManager.resources["gold"] = 200
	GameManager.population = 0
	GameManager.population_cap = 10

	# Queue 2 trade carts
	market.train_trade_cart()
	market.train_trade_cart()

	# Cancel one
	var cancel_success = market.cancel_training()
	if not cancel_success:
		return Assertions.AssertResult.new(false,
			"cancel_training should return true")

	# Check refund - should have 100W + 50G refunded
	var expected_wood = 200 - Market.TRADE_CART_WOOD_COST  # One cart's worth spent
	var expected_gold = 200 - Market.TRADE_CART_GOLD_COST

	var result = Assertions.assert_resource("wood", expected_wood)
	if not result.passed:
		return result

	result = Assertions.assert_resource("gold", expected_gold)
	if not result.passed:
		return result

	if market.get_queue_size() != 1:
		return Assertions.AssertResult.new(false,
			"Queue size should be 1 after cancel, got: %d" % market.get_queue_size())

	return Assertions.AssertResult.new(true)
