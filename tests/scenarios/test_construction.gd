extends Node
## Construction Tests - Tests for building construction system (Phase 2.5B)
##
## These tests verify:
## - Building.start_construction() sets is_constructed=false, HP=1, progress=0
## - Building.progress_construction() increases progress and HP over time
## - Building.get_builder_count() filters invalid builders
## - Building.is_functional() returns false during construction
## - Villager.command_build() sets BUILDING state
## - Multi-builder construction speed (more villagers = faster)
## - Construction completion signal and state transitions

class_name TestConstruction

var runner: TestRunner


func _init(test_runner: TestRunner) -> void:
	runner = test_runner


func get_all_tests() -> Array[Callable]:
	## Returns all test methods to run
	return [
		# Building.start_construction() tests
		test_start_construction_sets_is_constructed_false,
		test_start_construction_sets_hp_to_one,
		test_start_construction_sets_progress_to_zero,
		# Building.is_functional() tests
		test_is_functional_returns_false_during_construction,
		test_is_functional_returns_true_when_complete,
		test_is_functional_returns_false_when_destroyed,
		# Building.get_builder_count() tests
		test_get_builder_count_returns_zero_initially,
		test_get_builder_count_tracks_added_builders,
		test_get_builder_count_filters_invalid_builders,
		test_get_builder_count_after_remove_builder,
		# Building.progress_construction() tests
		test_progress_construction_returns_false_when_no_builders,
		test_progress_construction_increases_progress,
		test_progress_construction_increases_hp_proportionally,
		test_progress_construction_returns_true_when_complete,
		test_progress_construction_clears_builders_on_complete,
		test_progress_construction_emits_signal_on_complete,
		# Villager.command_build() tests
		test_command_build_sets_building_state,
		test_command_build_adds_villager_to_builders,
		test_command_build_clears_previous_targets,
		test_command_build_removes_from_old_construction,
		# Multi-builder construction speed tests
		test_two_builders_faster_than_one,
		test_three_builders_has_diminishing_returns,
		# Construction completion flow
		test_villager_goes_idle_after_construction_complete,
	]


# === Building.start_construction() Tests ===

func test_start_construction_sets_is_constructed_false() -> Assertions.AssertResult:
	## start_construction() should set is_constructed to false
	var house = runner.spawner.spawn_house(Vector2(400, 400))
	await runner.wait_frames(2)

	# House spawns as complete by default
	if not house.is_constructed:
		return Assertions.AssertResult.new(false,
			"House should start as constructed")

	house.start_construction()

	if house.is_constructed:
		return Assertions.AssertResult.new(false,
			"is_constructed should be false after start_construction()")

	return Assertions.AssertResult.new(true)


func test_start_construction_sets_hp_to_one() -> Assertions.AssertResult:
	## start_construction() should set current_hp to 1
	var house = runner.spawner.spawn_house(Vector2(400, 400))
	await runner.wait_frames(2)

	# House should have full HP initially
	if house.current_hp != house.max_hp:
		return Assertions.AssertResult.new(false,
			"House should start with max HP, got: %d" % house.current_hp)

	house.start_construction()

	if house.current_hp != 1:
		return Assertions.AssertResult.new(false,
			"current_hp should be 1 after start_construction(), got: %d" % house.current_hp)

	return Assertions.AssertResult.new(true)


func test_start_construction_sets_progress_to_zero() -> Assertions.AssertResult:
	## start_construction() should set construction_progress to 0.0
	var house = runner.spawner.spawn_house(Vector2(400, 400))
	await runner.wait_frames(2)

	house.start_construction()

	if house.construction_progress != 0.0:
		return Assertions.AssertResult.new(false,
			"construction_progress should be 0.0 after start_construction(), got: %f" % house.construction_progress)

	return Assertions.AssertResult.new(true)


# === Building.is_functional() Tests ===

func test_is_functional_returns_false_during_construction() -> Assertions.AssertResult:
	## is_functional() should return false while building is under construction
	var house = runner.spawner.spawn_house(Vector2(400, 400))
	await runner.wait_frames(2)

	house.start_construction()

	if house.is_functional():
		return Assertions.AssertResult.new(false,
			"is_functional() should return false during construction")

	return Assertions.AssertResult.new(true)


func test_is_functional_returns_true_when_complete() -> Assertions.AssertResult:
	## is_functional() should return true when building is complete and not destroyed
	var house = runner.spawner.spawn_house(Vector2(400, 400))
	await runner.wait_frames(2)

	# House spawns as complete
	if not house.is_functional():
		return Assertions.AssertResult.new(false,
			"is_functional() should return true for completed building")

	return Assertions.AssertResult.new(true)


func test_is_functional_returns_false_when_destroyed() -> Assertions.AssertResult:
	## is_functional() should return false when building is destroyed
	var house = runner.spawner.spawn_house(Vector2(400, 400))
	await runner.wait_frames(2)

	# Manually set is_destroyed flag without freeing the node
	house.is_destroyed = true

	if house.is_functional():
		return Assertions.AssertResult.new(false,
			"is_functional() should return false when is_destroyed is true")

	return Assertions.AssertResult.new(true)


# === Building.get_builder_count() Tests ===

func test_get_builder_count_returns_zero_initially() -> Assertions.AssertResult:
	## get_builder_count() should return 0 for a new building
	var house = runner.spawner.spawn_house(Vector2(400, 400))
	await runner.wait_frames(2)

	house.start_construction()

	if house.get_builder_count() != 0:
		return Assertions.AssertResult.new(false,
			"get_builder_count() should return 0 initially, got: %d" % house.get_builder_count())

	return Assertions.AssertResult.new(true)


func test_get_builder_count_tracks_added_builders() -> Assertions.AssertResult:
	## get_builder_count() should return correct count after adding builders
	var house = runner.spawner.spawn_house(Vector2(400, 400))
	var villager1 = runner.spawner.spawn_villager(Vector2(350, 400))
	var villager2 = runner.spawner.spawn_villager(Vector2(450, 400))
	await runner.wait_frames(2)

	house.start_construction()
	house.add_builder(villager1)

	if house.get_builder_count() != 1:
		return Assertions.AssertResult.new(false,
			"get_builder_count() should return 1 after adding one builder, got: %d" % house.get_builder_count())

	house.add_builder(villager2)

	if house.get_builder_count() != 2:
		return Assertions.AssertResult.new(false,
			"get_builder_count() should return 2 after adding two builders, got: %d" % house.get_builder_count())

	return Assertions.AssertResult.new(true)


func test_get_builder_count_filters_invalid_builders() -> Assertions.AssertResult:
	## get_builder_count() should filter out freed/invalid builders
	var house = runner.spawner.spawn_house(Vector2(400, 400))
	var villager1 = runner.spawner.spawn_villager(Vector2(350, 400))
	var villager2 = runner.spawner.spawn_villager(Vector2(450, 400))
	await runner.wait_frames(2)

	house.start_construction()
	house.add_builder(villager1)
	house.add_builder(villager2)

	if house.get_builder_count() != 2:
		return Assertions.AssertResult.new(false,
			"Should have 2 builders initially, got: %d" % house.get_builder_count())

	# Free one villager
	villager1.queue_free()
	await runner.wait_frames(2)

	# get_builder_count should now return 1 (filtering invalid)
	if house.get_builder_count() != 1:
		return Assertions.AssertResult.new(false,
			"get_builder_count() should filter freed builder, expected 1, got: %d" % house.get_builder_count())

	return Assertions.AssertResult.new(true)


func test_get_builder_count_after_remove_builder() -> Assertions.AssertResult:
	## remove_builder() should decrease the builder count
	var house = runner.spawner.spawn_house(Vector2(400, 400))
	var villager = runner.spawner.spawn_villager(Vector2(350, 400))
	await runner.wait_frames(2)

	house.start_construction()
	house.add_builder(villager)

	if house.get_builder_count() != 1:
		return Assertions.AssertResult.new(false,
			"Should have 1 builder after add, got: %d" % house.get_builder_count())

	house.remove_builder(villager)

	if house.get_builder_count() != 0:
		return Assertions.AssertResult.new(false,
			"Should have 0 builders after remove, got: %d" % house.get_builder_count())

	return Assertions.AssertResult.new(true)


# === Building.progress_construction() Tests ===

func test_progress_construction_returns_false_when_no_builders() -> Assertions.AssertResult:
	## progress_construction() should return false when there are no builders
	var house = runner.spawner.spawn_house(Vector2(400, 400))
	await runner.wait_frames(2)

	house.start_construction()

	var completed = house.progress_construction(1.0)

	if completed:
		return Assertions.AssertResult.new(false,
			"progress_construction() should return false when no builders")

	# Progress should not have changed
	if house.construction_progress != 0.0:
		return Assertions.AssertResult.new(false,
			"Progress should remain 0 without builders, got: %f" % house.construction_progress)

	return Assertions.AssertResult.new(true)


func test_progress_construction_increases_progress() -> Assertions.AssertResult:
	## progress_construction() should increase construction_progress
	var house = runner.spawner.spawn_house(Vector2(400, 400))
	var villager = runner.spawner.spawn_villager(Vector2(350, 400))
	await runner.wait_frames(2)

	house.start_construction()
	house.add_builder(villager)

	var initial_progress = house.construction_progress

	# Progress by 1 second (build_time is typically 25s for a house)
	house.progress_construction(1.0)

	if house.construction_progress <= initial_progress:
		return Assertions.AssertResult.new(false,
			"Progress should increase after progress_construction(), initial: %f, after: %f" % [initial_progress, house.construction_progress])

	# Expected progress: 1.0 / build_time = 1/25 = 0.04
	var expected_progress = 1.0 / house.build_time
	if abs(house.construction_progress - expected_progress) > 0.001:
		return Assertions.AssertResult.new(false,
			"Progress should be approximately %f, got: %f" % [expected_progress, house.construction_progress])

	return Assertions.AssertResult.new(true)


func test_progress_construction_increases_hp_proportionally() -> Assertions.AssertResult:
	## HP should scale with construction progress
	var house = runner.spawner.spawn_house(Vector2(400, 400))
	var villager = runner.spawner.spawn_villager(Vector2(350, 400))
	await runner.wait_frames(2)

	house.start_construction()
	house.add_builder(villager)

	# Progress to ~50%
	var half_build_time = house.build_time / 2.0
	house.progress_construction(half_build_time)

	# HP should be approximately halfway between 1 and max_hp
	var expected_hp = int(1 + (house.max_hp - 1) * house.construction_progress)
	if abs(house.current_hp - expected_hp) > 1:
		return Assertions.AssertResult.new(false,
			"HP should scale with progress. Expected ~%d, got: %d (progress: %f)" % [expected_hp, house.current_hp, house.construction_progress])

	return Assertions.AssertResult.new(true)


func test_progress_construction_returns_true_when_complete() -> Assertions.AssertResult:
	## progress_construction() should return true when construction completes
	var house = runner.spawner.spawn_house(Vector2(400, 400))
	var villager = runner.spawner.spawn_villager(Vector2(350, 400))
	await runner.wait_frames(2)

	house.start_construction()
	house.add_builder(villager)

	# Progress past build time
	var completed = house.progress_construction(house.build_time + 1.0)

	if not completed:
		return Assertions.AssertResult.new(false,
			"progress_construction() should return true when construction completes")

	if not house.is_constructed:
		return Assertions.AssertResult.new(false,
			"is_constructed should be true after completion")

	if house.current_hp != house.max_hp:
		return Assertions.AssertResult.new(false,
			"HP should be max_hp after completion, got: %d" % house.current_hp)

	return Assertions.AssertResult.new(true)


func test_progress_construction_clears_builders_on_complete() -> Assertions.AssertResult:
	## Builders array should be cleared when construction completes
	var house = runner.spawner.spawn_house(Vector2(400, 400))
	var villager = runner.spawner.spawn_villager(Vector2(350, 400))
	await runner.wait_frames(2)

	house.start_construction()
	house.add_builder(villager)

	# Complete construction
	house.progress_construction(house.build_time + 1.0)

	if house.get_builder_count() != 0:
		return Assertions.AssertResult.new(false,
			"Builders should be cleared after completion, got: %d" % house.get_builder_count())

	return Assertions.AssertResult.new(true)


func test_progress_construction_emits_signal_on_complete() -> Assertions.AssertResult:
	## construction_completed signal should emit when building finishes
	var house = runner.spawner.spawn_house(Vector2(400, 400))
	var villager = runner.spawner.spawn_villager(Vector2(350, 400))
	await runner.wait_frames(2)

	house.start_construction()
	house.add_builder(villager)

	var signal_received = [false]
	house.construction_completed.connect(func(): signal_received[0] = true)

	# Complete construction
	house.progress_construction(house.build_time + 1.0)

	if not signal_received[0]:
		return Assertions.AssertResult.new(false,
			"construction_completed signal should be emitted")

	return Assertions.AssertResult.new(true)


# === Villager.command_build() Tests ===

func test_command_build_sets_building_state() -> Assertions.AssertResult:
	## command_build() should set villager state to BUILDING
	var house = runner.spawner.spawn_house(Vector2(400, 400))
	var villager = runner.spawner.spawn_villager(Vector2(350, 400))
	await runner.wait_frames(2)

	house.start_construction()
	villager.command_build(house)

	var result = Assertions.assert_villager_state(villager, Villager.State.BUILDING)
	if not result.passed:
		return result

	return Assertions.AssertResult.new(true)


func test_command_build_adds_villager_to_builders() -> Assertions.AssertResult:
	## command_build() should add villager to building's builders list
	var house = runner.spawner.spawn_house(Vector2(400, 400))
	var villager = runner.spawner.spawn_villager(Vector2(350, 400))
	await runner.wait_frames(2)

	house.start_construction()

	if house.get_builder_count() != 0:
		return Assertions.AssertResult.new(false,
			"Should have 0 builders initially")

	villager.command_build(house)

	if house.get_builder_count() != 1:
		return Assertions.AssertResult.new(false,
			"Should have 1 builder after command_build(), got: %d" % house.get_builder_count())

	return Assertions.AssertResult.new(true)


func test_command_build_clears_previous_targets() -> Assertions.AssertResult:
	## command_build() should clear target_resource and target_animal
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

	# Now command to build
	house.start_construction()
	villager.command_build(house)

	if villager.target_resource != null:
		return Assertions.AssertResult.new(false,
			"target_resource should be cleared after command_build()")

	if villager.target_animal != null:
		return Assertions.AssertResult.new(false,
			"target_animal should be cleared after command_build()")

	return Assertions.AssertResult.new(true)


func test_command_build_removes_from_old_construction() -> Assertions.AssertResult:
	## command_build() should remove villager from previous construction
	var house1 = runner.spawner.spawn_house(Vector2(400, 400))
	var house2 = runner.spawner.spawn_house(Vector2(500, 400))
	var villager = runner.spawner.spawn_villager(Vector2(350, 400))
	await runner.wait_frames(2)

	house1.start_construction()
	house2.start_construction()

	villager.command_build(house1)

	if house1.get_builder_count() != 1:
		return Assertions.AssertResult.new(false,
			"house1 should have 1 builder initially")

	# Switch to building house2
	villager.command_build(house2)

	if house1.get_builder_count() != 0:
		return Assertions.AssertResult.new(false,
			"house1 should have 0 builders after villager switched, got: %d" % house1.get_builder_count())

	if house2.get_builder_count() != 1:
		return Assertions.AssertResult.new(false,
			"house2 should have 1 builder, got: %d" % house2.get_builder_count())

	return Assertions.AssertResult.new(true)


# === Multi-builder Construction Speed Tests ===

func test_two_builders_faster_than_one() -> Assertions.AssertResult:
	## Two builders should construct faster than one
	var house1 = runner.spawner.spawn_house(Vector2(400, 400))
	var house2 = runner.spawner.spawn_house(Vector2(600, 400))
	var villager1 = runner.spawner.spawn_villager(Vector2(350, 400))
	var villager2 = runner.spawner.spawn_villager(Vector2(550, 400))
	var villager3 = runner.spawner.spawn_villager(Vector2(650, 400))
	await runner.wait_frames(2)

	house1.start_construction()
	house2.start_construction()

	# house1 gets 1 builder, house2 gets 2
	house1.add_builder(villager1)
	house2.add_builder(villager2)
	house2.add_builder(villager3)

	# Progress both by same delta
	house1.progress_construction(5.0)
	house2.progress_construction(5.0)

	# house2 should have more progress (2 builders = 1.5x speed)
	if house2.construction_progress <= house1.construction_progress:
		return Assertions.AssertResult.new(false,
			"Two builders should be faster. house1 progress: %f, house2 progress: %f" % [
				house1.construction_progress, house2.construction_progress])

	# Specifically, 2 builders = 1.5x speed (1 + 0.5)
	var expected_ratio = 1.5
	var actual_ratio = house2.construction_progress / house1.construction_progress
	if abs(actual_ratio - expected_ratio) > 0.01:
		return Assertions.AssertResult.new(false,
			"Two builders should be 1.5x faster. Expected ratio: %f, got: %f" % [expected_ratio, actual_ratio])

	return Assertions.AssertResult.new(true)


func test_three_builders_has_diminishing_returns() -> Assertions.AssertResult:
	## Three builders should be faster than two, but with diminishing returns
	var house2 = runner.spawner.spawn_house(Vector2(400, 400))
	var house3 = runner.spawner.spawn_house(Vector2(600, 400))
	# Create villagers for 2-builder house
	var v1 = runner.spawner.spawn_villager(Vector2(350, 400))
	var v2 = runner.spawner.spawn_villager(Vector2(450, 400))
	# Create villagers for 3-builder house
	var v3 = runner.spawner.spawn_villager(Vector2(550, 400))
	var v4 = runner.spawner.spawn_villager(Vector2(600, 400))
	var v5 = runner.spawner.spawn_villager(Vector2(650, 400))
	await runner.wait_frames(2)

	house2.start_construction()
	house3.start_construction()

	# house2 gets 2 builders, house3 gets 3
	house2.add_builder(v1)
	house2.add_builder(v2)
	house3.add_builder(v3)
	house3.add_builder(v4)
	house3.add_builder(v5)

	# Progress both by same delta
	house2.progress_construction(5.0)
	house3.progress_construction(5.0)

	# house3 should have more progress (but not 1.5x more)
	if house3.construction_progress <= house2.construction_progress:
		return Assertions.AssertResult.new(false,
			"Three builders should be faster than two. house2: %f, house3: %f" % [
				house2.construction_progress, house3.construction_progress])

	# 2 builders = 1 + 0.5 = 1.5x
	# 3 builders = 1 + 0.5 + 0.25 = 1.75x
	# Ratio should be 1.75/1.5 = 1.1667
	var expected_ratio = 1.75 / 1.5
	var actual_ratio = house3.construction_progress / house2.construction_progress
	if abs(actual_ratio - expected_ratio) > 0.01:
		return Assertions.AssertResult.new(false,
			"Diminishing returns: expected ratio %f, got: %f" % [expected_ratio, actual_ratio])

	return Assertions.AssertResult.new(true)


# === Construction Completion Flow ===

func test_villager_goes_idle_after_construction_complete() -> Assertions.AssertResult:
	## Villager should go idle after construction completes
	var house = runner.spawner.spawn_house(Vector2(400, 400))
	var villager = runner.spawner.spawn_villager(Vector2(400, 400))  # Same position to avoid movement
	await runner.wait_frames(2)

	house.start_construction()
	villager.command_build(house)

	# Verify villager is in BUILDING state
	var result = Assertions.assert_villager_state(villager, Villager.State.BUILDING)
	if not result.passed:
		return result

	# Complete the construction via progress_construction
	house.progress_construction(house.build_time + 1.0)
	await runner.wait_frames(2)

	# Villager should process the completion in _process_building and go idle
	# We need to simulate a frame of processing
	# Since we can't call _process_building directly, we trigger physics process
	await runner.wait_frames(5)

	result = Assertions.assert_villager_state(villager, Villager.State.IDLE)
	if not result.passed:
		return Assertions.AssertResult.new(false,
			"Villager should be IDLE after construction complete, got state: %d" % villager.current_state)

	# target_construction should be cleared
	if villager.target_construction != null:
		return Assertions.AssertResult.new(false,
			"target_construction should be null after completion")

	return Assertions.AssertResult.new(true)
