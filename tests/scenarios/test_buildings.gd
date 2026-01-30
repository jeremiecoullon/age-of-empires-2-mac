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
		test_tc_cannot_train_while_training,
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
		test_archery_range_cannot_train_while_training,
		test_archery_range_spawns_archer_with_correct_team,
		# House tests
		test_house_increases_population_cap,
		# AI team tests (regression test for gotchas.md bug)
		test_ai_tc_uses_ai_resources,
		test_ai_barracks_uses_ai_resources,
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


func test_tc_cannot_train_while_training() -> Assertions.AssertResult:
	## Can't start a new training while one is in progress
	var tc = runner.spawner.spawn_town_center(Vector2(400, 400))
	await runner.wait_frames(2)

	GameManager.resources["food"] = 200
	GameManager.population = 0
	GameManager.population_cap = 10

	var first_success = tc.train_villager()
	var second_success = tc.train_villager()  # Should fail

	if not first_success:
		return Assertions.AssertResult.new(false,
			"First train_villager should succeed")

	if second_success:
		return Assertions.AssertResult.new(false,
			"Second train_villager should fail while training")

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


func test_archery_range_cannot_train_while_training() -> Assertions.AssertResult:
	## Can't start a new training while one is in progress
	var archery_range = runner.spawner.spawn_archery_range(Vector2(400, 400))
	await runner.wait_frames(2)

	GameManager.resources["wood"] = 200
	GameManager.resources["gold"] = 200
	GameManager.population = 0
	GameManager.population_cap = 10

	var first_success = archery_range.train_archer()
	var second_success = archery_range.train_archer()  # Should fail

	if not first_success:
		return Assertions.AssertResult.new(false,
			"First train_archer should succeed")

	if second_success:
		return Assertions.AssertResult.new(false,
			"Second train_archer should fail while training")

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
