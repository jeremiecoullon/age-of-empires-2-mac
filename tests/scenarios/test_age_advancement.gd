extends Node
## Age Advancement Tests - Tests for Phase 4A Age Advancement System
##
## These tests verify:
## - GameManager age state: get/set/reset, age names, age constants
## - can_advance_age() with various conditions (wrong age, buildings, resources)
## - get_qualifying_building_count() counts distinct types correctly
## - spend_age_cost() / refund_age_cost() resource handling
## - Town Center age research: start, cancel, complete, timer, signals
## - TC blocks villager training during age research
## - TC destruction during research refunds resources
## - AI rule conditions: AdvanceToFeudalAgeRule, AdvanceToCastleAgeRule
## - AI can_train("villager") blocked during age research

class_name TestAgeAdvancement

var runner: TestRunner


func _init(test_runner: TestRunner) -> void:
	runner = test_runner


func get_all_tests() -> Array[Callable]:
	## Returns all test methods to run
	return [
		# GameManager age state tests
		test_age_starts_at_dark_age,
		test_set_age_updates_player_age,
		test_set_age_updates_ai_age,
		test_get_age_name_returns_correct_names,
		test_reset_resets_ages_to_dark,
		test_age_changed_signal_emits,
		# can_advance_age tests
		test_cannot_advance_past_imperial,
		test_cannot_advance_without_qualifying_buildings,
		test_cannot_advance_without_resources,
		test_can_advance_with_all_requirements,
		# get_qualifying_building_count tests
		test_qualifying_count_distinct_types_for_feudal,
		test_qualifying_count_two_same_type_counts_as_one,
		test_qualifying_count_only_functional_buildings,
		test_qualifying_count_only_own_team,
		test_qualifying_count_feudal_age_buildings,
		test_qualifying_count_castle_age_buildings,
		# can_afford_age / spend / refund tests
		test_can_afford_feudal_age,
		test_cannot_afford_feudal_age,
		test_can_afford_castle_age_requires_food_and_gold,
		test_spend_age_cost_deducts_resources,
		test_spend_age_cost_fails_if_not_affordable,
		test_refund_age_cost_returns_resources,
		test_refund_age_cost_handles_invalid_age,
		# Town Center age research tests
		test_tc_start_age_research_succeeds,
		test_tc_start_age_research_spends_resources,
		test_tc_start_age_research_fails_without_resources,
		test_tc_start_age_research_fails_without_buildings,
		test_tc_start_age_research_fails_if_already_researching,
		test_tc_start_age_research_fails_for_wrong_age_order,
		test_tc_cancel_age_research_refunds_resources,
		test_tc_cancel_age_research_resets_state,
		test_tc_age_research_blocks_villager_training,
		test_tc_age_research_completes_and_sets_age,
		test_tc_age_research_progress_reports_correctly,
		test_tc_age_research_emits_signals,
		test_tc_destruction_during_research_refunds_resources,
		# AI age rule tests
		test_ai_feudal_rule_fires_when_ready,
		test_ai_feudal_rule_blocks_wrong_age,
		test_ai_feudal_rule_blocks_insufficient_villagers,
		test_ai_feudal_rule_blocks_insufficient_buildings,
		test_ai_castle_rule_fires_when_ready,
		test_ai_castle_rule_blocks_wrong_age,
		test_ai_castle_rule_blocks_insufficient_villagers,
		# AI can_train blocks during research
		test_ai_can_train_villager_blocked_during_research,
	]


# =============================================================================
# Mock AI Controller (same pattern as test_ai_economy.gd)
# =============================================================================

class MockAIController extends Node:
	## Minimal mock that provides the data structures AIGameState needs
	var strategic_numbers: Dictionary = {}
	var goals: Dictionary = {}
	var timers: Dictionary = {}
	var game_time_elapsed: float = 0.0


func _create_ai_game_state() -> AIGameState:
	## Creates an AIGameState with mock controller for testing
	var gs = AIGameState.new()
	var controller = MockAIController.new()
	gs.initialize(controller, runner.get_tree())
	return gs


# =============================================================================
# GameManager Age State Tests
# =============================================================================

func test_age_starts_at_dark_age() -> Assertions.AssertResult:
	## After reset, both player and AI should be in Dark Age
	var player_age = GameManager.get_age(0)
	var ai_age = GameManager.get_age(1)

	if player_age != GameManager.AGE_DARK:
		return Assertions.AssertResult.new(false,
			"Player should start in Dark Age (0), got: %d" % player_age)
	if ai_age != GameManager.AGE_DARK:
		return Assertions.AssertResult.new(false,
			"AI should start in Dark Age (0), got: %d" % ai_age)

	return Assertions.AssertResult.new(true)


func test_set_age_updates_player_age() -> Assertions.AssertResult:
	## set_age should update player age
	GameManager.set_age(GameManager.AGE_FEUDAL, 0)

	var age = GameManager.get_age(0)
	if age != GameManager.AGE_FEUDAL:
		return Assertions.AssertResult.new(false,
			"Player age should be Feudal (1), got: %d" % age)

	return Assertions.AssertResult.new(true)


func test_set_age_updates_ai_age() -> Assertions.AssertResult:
	## set_age should update AI age independently
	GameManager.set_age(GameManager.AGE_CASTLE, 1)

	var player_age = GameManager.get_age(0)
	var ai_age = GameManager.get_age(1)

	if player_age != GameManager.AGE_DARK:
		return Assertions.AssertResult.new(false,
			"Player age should still be Dark (0), got: %d" % player_age)
	if ai_age != GameManager.AGE_CASTLE:
		return Assertions.AssertResult.new(false,
			"AI age should be Castle (2), got: %d" % ai_age)

	return Assertions.AssertResult.new(true)


func test_get_age_name_returns_correct_names() -> Assertions.AssertResult:
	## get_age_name should return human-readable age names
	GameManager.set_age(GameManager.AGE_DARK, 0)
	if GameManager.get_age_name(0) != "Dark Age":
		return Assertions.AssertResult.new(false,
			"Dark Age name mismatch: %s" % GameManager.get_age_name(0))

	GameManager.set_age(GameManager.AGE_FEUDAL, 0)
	if GameManager.get_age_name(0) != "Feudal Age":
		return Assertions.AssertResult.new(false,
			"Feudal Age name mismatch: %s" % GameManager.get_age_name(0))

	GameManager.set_age(GameManager.AGE_CASTLE, 0)
	if GameManager.get_age_name(0) != "Castle Age":
		return Assertions.AssertResult.new(false,
			"Castle Age name mismatch: %s" % GameManager.get_age_name(0))

	GameManager.set_age(GameManager.AGE_IMPERIAL, 0)
	if GameManager.get_age_name(0) != "Imperial Age":
		return Assertions.AssertResult.new(false,
			"Imperial Age name mismatch: %s" % GameManager.get_age_name(0))

	return Assertions.AssertResult.new(true)


func test_reset_resets_ages_to_dark() -> Assertions.AssertResult:
	## GameManager.reset() should reset both ages to Dark Age
	GameManager.set_age(GameManager.AGE_IMPERIAL, 0)
	GameManager.set_age(GameManager.AGE_CASTLE, 1)

	GameManager.reset()

	if GameManager.get_age(0) != GameManager.AGE_DARK:
		return Assertions.AssertResult.new(false,
			"Player age should reset to Dark (0), got: %d" % GameManager.get_age(0))
	if GameManager.get_age(1) != GameManager.AGE_DARK:
		return Assertions.AssertResult.new(false,
			"AI age should reset to Dark (0), got: %d" % GameManager.get_age(1))

	return Assertions.AssertResult.new(true)


func test_age_changed_signal_emits() -> Assertions.AssertResult:
	## age_changed signal should emit with correct team and age
	var signal_data = [false, -1, -1]  # [received, team, age]
	GameManager.age_changed.connect(func(team, new_age):
		signal_data[0] = true
		signal_data[1] = team
		signal_data[2] = new_age
	)

	GameManager.set_age(GameManager.AGE_FEUDAL, 0)

	# Disconnect to avoid affecting other tests
	for conn in GameManager.age_changed.get_connections():
		GameManager.age_changed.disconnect(conn.callable)

	if not signal_data[0]:
		return Assertions.AssertResult.new(false,
			"age_changed signal should be emitted")
	if signal_data[1] != 0:
		return Assertions.AssertResult.new(false,
			"Signal team should be 0, got: %d" % signal_data[1])
	if signal_data[2] != GameManager.AGE_FEUDAL:
		return Assertions.AssertResult.new(false,
			"Signal age should be Feudal (1), got: %d" % signal_data[2])

	return Assertions.AssertResult.new(true)


# =============================================================================
# can_advance_age Tests
# =============================================================================

func test_cannot_advance_past_imperial() -> Assertions.AssertResult:
	## Cannot advance if already at Imperial Age
	GameManager.set_age(GameManager.AGE_IMPERIAL, 0)
	GameManager.resources["food"] = 99999
	GameManager.resources["gold"] = 99999

	var result = GameManager.can_advance_age(0)
	if result:
		return Assertions.AssertResult.new(false,
			"Should not be able to advance past Imperial Age")

	return Assertions.AssertResult.new(true)


func test_cannot_advance_without_qualifying_buildings() -> Assertions.AssertResult:
	## Cannot advance to Feudal without 2 qualifying buildings
	GameManager.resources["food"] = 1000  # Enough food

	# No buildings spawned, so qualifying count = 0
	var result = GameManager.can_advance_age(0)
	if result:
		return Assertions.AssertResult.new(false,
			"Should not advance without qualifying buildings")

	return Assertions.AssertResult.new(true)


func test_cannot_advance_without_resources() -> Assertions.AssertResult:
	## Cannot advance to Feudal without 500 food
	GameManager.resources["food"] = 100  # Not enough

	# Spawn 2 qualifying buildings
	var barracks = runner.spawner.spawn_barracks(Vector2(400, 400), 0)
	var mill = runner.spawner.spawn_mill(Vector2(500, 400), 0)
	await runner.wait_frames(2)

	var result = GameManager.can_advance_age(0)
	if result:
		return Assertions.AssertResult.new(false,
			"Should not advance without sufficient resources")

	return Assertions.AssertResult.new(true)


func test_can_advance_with_all_requirements() -> Assertions.AssertResult:
	## Can advance to Feudal with 2 qualifying buildings and 500 food
	GameManager.resources["food"] = 600

	# Spawn 2 different qualifying building types
	var barracks = runner.spawner.spawn_barracks(Vector2(400, 400), 0)
	var mill = runner.spawner.spawn_mill(Vector2(500, 400), 0)
	await runner.wait_frames(2)

	var result = GameManager.can_advance_age(0)
	if not result:
		var count = GameManager.get_qualifying_building_count(GameManager.AGE_FEUDAL, 0)
		var can_afford = GameManager.can_afford_age(GameManager.AGE_FEUDAL, 0)
		return Assertions.AssertResult.new(false,
			"Should be able to advance to Feudal. qualifying_count=%d, can_afford=%s" % [count, str(can_afford)])

	return Assertions.AssertResult.new(true)


# =============================================================================
# get_qualifying_building_count Tests
# =============================================================================

func test_qualifying_count_distinct_types_for_feudal() -> Assertions.AssertResult:
	## Feudal qualifying buildings: barracks, mills, lumber_camps, mining_camps
	## Should count distinct types
	var barracks = runner.spawner.spawn_barracks(Vector2(400, 400), 0)
	var mill = runner.spawner.spawn_mill(Vector2(500, 400), 0)
	await runner.wait_frames(2)

	var count = GameManager.get_qualifying_building_count(GameManager.AGE_FEUDAL, 0)
	if count != 2:
		return Assertions.AssertResult.new(false,
			"Should count 2 distinct qualifying types, got: %d" % count)

	return Assertions.AssertResult.new(true)


func test_qualifying_count_two_same_type_counts_as_one() -> Assertions.AssertResult:
	## Two barracks should count as 1 qualifying type (not 2)
	var barracks1 = runner.spawner.spawn_barracks(Vector2(400, 400), 0)
	var barracks2 = runner.spawner.spawn_barracks(Vector2(500, 400), 0)
	await runner.wait_frames(2)

	var count = GameManager.get_qualifying_building_count(GameManager.AGE_FEUDAL, 0)
	if count != 1:
		return Assertions.AssertResult.new(false,
			"Two barracks should count as 1 qualifying type, got: %d" % count)

	return Assertions.AssertResult.new(true)


func test_qualifying_count_only_functional_buildings() -> Assertions.AssertResult:
	## Buildings under construction should not count
	var barracks = runner.spawner.spawn_barracks(Vector2(400, 400), 0)
	var mill = runner.spawner.spawn_mill(Vector2(500, 400), 0)
	await runner.wait_frames(2)

	# Put mill under construction (not functional)
	mill.is_constructed = false

	var count = GameManager.get_qualifying_building_count(GameManager.AGE_FEUDAL, 0)
	if count != 1:
		return Assertions.AssertResult.new(false,
			"Non-functional building should not count. Expected 1, got: %d" % count)

	return Assertions.AssertResult.new(true)


func test_qualifying_count_only_own_team() -> Assertions.AssertResult:
	## AI buildings should not count for player's qualifying buildings
	var barracks_player = runner.spawner.spawn_barracks(Vector2(400, 400), 0)
	var mill_ai = runner.spawner.spawn_mill(Vector2(500, 400), 1)  # AI building
	await runner.wait_frames(2)

	var count = GameManager.get_qualifying_building_count(GameManager.AGE_FEUDAL, 0)
	if count != 1:
		return Assertions.AssertResult.new(false,
			"AI buildings should not count for player. Expected 1, got: %d" % count)

	return Assertions.AssertResult.new(true)


func test_qualifying_count_feudal_age_buildings() -> Assertions.AssertResult:
	## All 4 Dark Age qualifying types should count toward Feudal
	var barracks = runner.spawner.spawn_barracks(Vector2(300, 400), 0)
	var mill = runner.spawner.spawn_mill(Vector2(400, 400), 0)
	var lumber_camp = runner.spawner.spawn_lumber_camp(Vector2(500, 400), 0)
	var mining_camp = runner.spawner.spawn_mining_camp(Vector2(600, 400), 0)
	await runner.wait_frames(2)

	var count = GameManager.get_qualifying_building_count(GameManager.AGE_FEUDAL, 0)
	if count != 4:
		return Assertions.AssertResult.new(false,
			"All 4 Dark Age building types should qualify. Expected 4, got: %d" % count)

	return Assertions.AssertResult.new(true)


func test_qualifying_count_castle_age_buildings() -> Assertions.AssertResult:
	## Castle qualifying buildings: archery_ranges, stables, markets
	var archery_range = runner.spawner.spawn_archery_range(Vector2(400, 400), 0)
	var stable = runner.spawner.spawn_stable(Vector2(500, 400), 0)
	var market = runner.spawner.spawn_market(Vector2(600, 400), 0)
	await runner.wait_frames(2)

	var count = GameManager.get_qualifying_building_count(GameManager.AGE_CASTLE, 0)
	if count != 3:
		return Assertions.AssertResult.new(false,
			"All 3 Feudal Age building types should qualify for Castle. Expected 3, got: %d" % count)

	return Assertions.AssertResult.new(true)


# =============================================================================
# can_afford_age / spend_age_cost / refund_age_cost Tests
# =============================================================================

func test_can_afford_feudal_age() -> Assertions.AssertResult:
	## Feudal costs 500 food
	GameManager.resources["food"] = 500

	if not GameManager.can_afford_age(GameManager.AGE_FEUDAL, 0):
		return Assertions.AssertResult.new(false,
			"Should be able to afford Feudal with 500 food")

	return Assertions.AssertResult.new(true)


func test_cannot_afford_feudal_age() -> Assertions.AssertResult:
	## Feudal costs 500 food - should fail with less
	GameManager.resources["food"] = 499

	if GameManager.can_afford_age(GameManager.AGE_FEUDAL, 0):
		return Assertions.AssertResult.new(false,
			"Should not afford Feudal with 499 food")

	return Assertions.AssertResult.new(true)


func test_can_afford_castle_age_requires_food_and_gold() -> Assertions.AssertResult:
	## Castle costs 800 food + 200 gold - both must be met
	GameManager.resources["food"] = 800
	GameManager.resources["gold"] = 200

	if not GameManager.can_afford_age(GameManager.AGE_CASTLE, 0):
		return Assertions.AssertResult.new(false,
			"Should afford Castle with 800 food + 200 gold")

	# Fail with enough food but not enough gold
	GameManager.resources["gold"] = 100
	if GameManager.can_afford_age(GameManager.AGE_CASTLE, 0):
		return Assertions.AssertResult.new(false,
			"Should not afford Castle with only 100 gold")

	return Assertions.AssertResult.new(true)


func test_spend_age_cost_deducts_resources() -> Assertions.AssertResult:
	## spend_age_cost should deduct the correct resources
	GameManager.resources["food"] = 600

	var success = GameManager.spend_age_cost(GameManager.AGE_FEUDAL, 0)
	if not success:
		return Assertions.AssertResult.new(false,
			"spend_age_cost should return true when affordable")

	var food = GameManager.get_resource("food", 0)
	if food != 100:
		return Assertions.AssertResult.new(false,
			"Food should be 100 after spending 500, got: %d" % food)

	return Assertions.AssertResult.new(true)


func test_spend_age_cost_fails_if_not_affordable() -> Assertions.AssertResult:
	## spend_age_cost should return false and not deduct if not affordable
	GameManager.resources["food"] = 100

	var success = GameManager.spend_age_cost(GameManager.AGE_FEUDAL, 0)
	if success:
		return Assertions.AssertResult.new(false,
			"spend_age_cost should return false when not affordable")

	# Food should be unchanged
	var food = GameManager.get_resource("food", 0)
	if food != 100:
		return Assertions.AssertResult.new(false,
			"Food should be unchanged at 100, got: %d" % food)

	return Assertions.AssertResult.new(true)


func test_refund_age_cost_returns_resources() -> Assertions.AssertResult:
	## refund_age_cost should add back the correct resources
	GameManager.resources["food"] = 100
	GameManager.resources["gold"] = 50

	GameManager.refund_age_cost(GameManager.AGE_CASTLE, 0)

	var food = GameManager.get_resource("food", 0)
	var gold = GameManager.get_resource("gold", 0)
	if food != 900:
		return Assertions.AssertResult.new(false,
			"Food should be 900 after Castle refund (100 + 800), got: %d" % food)
	if gold != 250:
		return Assertions.AssertResult.new(false,
			"Gold should be 250 after Castle refund (50 + 200), got: %d" % gold)

	return Assertions.AssertResult.new(true)


func test_refund_age_cost_handles_invalid_age() -> Assertions.AssertResult:
	## refund_age_cost should do nothing for invalid age values
	GameManager.resources["food"] = 100

	GameManager.refund_age_cost(0, 0)  # Dark Age has no cost
	GameManager.refund_age_cost(-1, 0)  # Invalid
	GameManager.refund_age_cost(99, 0)  # Out of bounds

	var food = GameManager.get_resource("food", 0)
	if food != 100:
		return Assertions.AssertResult.new(false,
			"Food should be unchanged at 100 for invalid refunds, got: %d" % food)

	return Assertions.AssertResult.new(true)


# =============================================================================
# Town Center Age Research Tests
# =============================================================================

func test_tc_start_age_research_succeeds() -> Assertions.AssertResult:
	## TC should start age research with valid conditions
	GameManager.resources["food"] = 600

	var tc = runner.spawner.spawn_town_center(Vector2(400, 400), 0)
	var barracks = runner.spawner.spawn_barracks(Vector2(500, 400), 0)
	var mill = runner.spawner.spawn_mill(Vector2(600, 400), 0)
	await runner.wait_frames(2)

	var success = tc.start_age_research(GameManager.AGE_FEUDAL)
	if not success:
		return Assertions.AssertResult.new(false,
			"start_age_research should return true with valid conditions")

	if not tc.is_researching_age:
		return Assertions.AssertResult.new(false,
			"TC should be in researching state")
	if tc.age_research_target != GameManager.AGE_FEUDAL:
		return Assertions.AssertResult.new(false,
			"Research target should be Feudal (1), got: %d" % tc.age_research_target)

	return Assertions.AssertResult.new(true)


func test_tc_start_age_research_spends_resources() -> Assertions.AssertResult:
	## Starting age research should deduct the age cost
	GameManager.resources["food"] = 600

	var tc = runner.spawner.spawn_town_center(Vector2(400, 400), 0)
	var barracks = runner.spawner.spawn_barracks(Vector2(500, 400), 0)
	var mill = runner.spawner.spawn_mill(Vector2(600, 400), 0)
	await runner.wait_frames(2)

	tc.start_age_research(GameManager.AGE_FEUDAL)

	var food = GameManager.get_resource("food", 0)
	if food != 100:
		return Assertions.AssertResult.new(false,
			"Food should be 100 after starting Feudal research (600 - 500), got: %d" % food)

	return Assertions.AssertResult.new(true)


func test_tc_start_age_research_fails_without_resources() -> Assertions.AssertResult:
	## TC should fail to start research if not enough resources
	GameManager.resources["food"] = 100

	var tc = runner.spawner.spawn_town_center(Vector2(400, 400), 0)
	var barracks = runner.spawner.spawn_barracks(Vector2(500, 400), 0)
	var mill = runner.spawner.spawn_mill(Vector2(600, 400), 0)
	await runner.wait_frames(2)

	var success = tc.start_age_research(GameManager.AGE_FEUDAL)
	if success:
		return Assertions.AssertResult.new(false,
			"start_age_research should fail without enough resources")

	if tc.is_researching_age:
		return Assertions.AssertResult.new(false,
			"TC should not be researching after failed start")

	return Assertions.AssertResult.new(true)


func test_tc_start_age_research_fails_without_buildings() -> Assertions.AssertResult:
	## TC should fail to start research without qualifying buildings
	GameManager.resources["food"] = 600

	var tc = runner.spawner.spawn_town_center(Vector2(400, 400), 0)
	# Only 1 qualifying building (need 2)
	var barracks = runner.spawner.spawn_barracks(Vector2(500, 400), 0)
	await runner.wait_frames(2)

	var success = tc.start_age_research(GameManager.AGE_FEUDAL)
	if success:
		return Assertions.AssertResult.new(false,
			"start_age_research should fail without 2 qualifying buildings")

	return Assertions.AssertResult.new(true)


func test_tc_start_age_research_fails_if_already_researching() -> Assertions.AssertResult:
	## Cannot start new research while already researching
	GameManager.resources["food"] = 1200

	var tc = runner.spawner.spawn_town_center(Vector2(400, 400), 0)
	var barracks = runner.spawner.spawn_barracks(Vector2(500, 400), 0)
	var mill = runner.spawner.spawn_mill(Vector2(600, 400), 0)
	await runner.wait_frames(2)

	var first = tc.start_age_research(GameManager.AGE_FEUDAL)
	if not first:
		return Assertions.AssertResult.new(false,
			"First research should succeed")

	var second = tc.start_age_research(GameManager.AGE_FEUDAL)
	if second:
		return Assertions.AssertResult.new(false,
			"Second research should fail while already researching")

	return Assertions.AssertResult.new(true)


func test_tc_start_age_research_fails_for_wrong_age_order() -> Assertions.AssertResult:
	## Cannot skip ages (e.g., jump from Dark to Castle)
	GameManager.resources["food"] = 2000
	GameManager.resources["gold"] = 2000

	var tc = runner.spawner.spawn_town_center(Vector2(400, 400), 0)
	# Spawn Castle Age qualifying buildings too
	var archery_range = runner.spawner.spawn_archery_range(Vector2(500, 400), 0)
	var stable = runner.spawner.spawn_stable(Vector2(600, 400), 0)
	# Also Feudal qualifying buildings
	var barracks = runner.spawner.spawn_barracks(Vector2(400, 500), 0)
	var mill = runner.spawner.spawn_mill(Vector2(500, 500), 0)
	await runner.wait_frames(2)

	# Try to skip to Castle from Dark
	var success = tc.start_age_research(GameManager.AGE_CASTLE)
	if success:
		return Assertions.AssertResult.new(false,
			"Should not be able to skip from Dark to Castle Age")

	return Assertions.AssertResult.new(true)


func test_tc_cancel_age_research_refunds_resources() -> Assertions.AssertResult:
	## Canceling age research should refund the age cost
	GameManager.resources["food"] = 600

	var tc = runner.spawner.spawn_town_center(Vector2(400, 400), 0)
	var barracks = runner.spawner.spawn_barracks(Vector2(500, 400), 0)
	var mill = runner.spawner.spawn_mill(Vector2(600, 400), 0)
	await runner.wait_frames(2)

	tc.start_age_research(GameManager.AGE_FEUDAL)

	# Food should be 100 after spending 500
	var food_after_start = GameManager.get_resource("food", 0)
	if food_after_start != 100:
		return Assertions.AssertResult.new(false,
			"Food should be 100 after starting research, got: %d" % food_after_start)

	# Cancel
	var cancel_success = tc.cancel_age_research()
	if not cancel_success:
		return Assertions.AssertResult.new(false,
			"cancel_age_research should return true")

	# Food should be refunded back to 600
	var food_after_cancel = GameManager.get_resource("food", 0)
	if food_after_cancel != 600:
		return Assertions.AssertResult.new(false,
			"Food should be refunded to 600 after cancel, got: %d" % food_after_cancel)

	return Assertions.AssertResult.new(true)


func test_tc_cancel_age_research_resets_state() -> Assertions.AssertResult:
	## Cancel should reset all research state
	GameManager.resources["food"] = 600

	var tc = runner.spawner.spawn_town_center(Vector2(400, 400), 0)
	var barracks = runner.spawner.spawn_barracks(Vector2(500, 400), 0)
	var mill = runner.spawner.spawn_mill(Vector2(600, 400), 0)
	await runner.wait_frames(2)

	tc.start_age_research(GameManager.AGE_FEUDAL)
	tc.cancel_age_research()

	if tc.is_researching_age:
		return Assertions.AssertResult.new(false,
			"TC should not be researching after cancel")
	if tc.age_research_target != -1:
		return Assertions.AssertResult.new(false,
			"Research target should be -1 after cancel, got: %d" % tc.age_research_target)
	if tc.age_research_timer != 0.0:
		return Assertions.AssertResult.new(false,
			"Research timer should be 0 after cancel")

	return Assertions.AssertResult.new(true)


func test_tc_age_research_blocks_villager_training() -> Assertions.AssertResult:
	## While researching age, TC should refuse to train villagers
	GameManager.resources["food"] = 700
	GameManager.population = 0
	GameManager.population_cap = 10

	var tc = runner.spawner.spawn_town_center(Vector2(400, 400), 0)
	var barracks = runner.spawner.spawn_barracks(Vector2(500, 400), 0)
	var mill = runner.spawner.spawn_mill(Vector2(600, 400), 0)
	await runner.wait_frames(2)

	tc.start_age_research(GameManager.AGE_FEUDAL)

	# Try to train during research
	var train_success = tc.train_villager()
	if train_success:
		return Assertions.AssertResult.new(false,
			"TC should not train villagers during age research")

	return Assertions.AssertResult.new(true)


func test_tc_age_research_completes_and_sets_age() -> Assertions.AssertResult:
	## When research timer completes, age should be updated
	GameManager.resources["food"] = 600

	var tc = runner.spawner.spawn_town_center(Vector2(400, 400), 0)
	var barracks = runner.spawner.spawn_barracks(Vector2(500, 400), 0)
	var mill = runner.spawner.spawn_mill(Vector2(600, 400), 0)
	await runner.wait_frames(2)

	tc.start_age_research(GameManager.AGE_FEUDAL)

	# Manually advance the timer past the research time
	tc.age_research_timer = GameManager.AGE_RESEARCH_TIMES[GameManager.AGE_FEUDAL] + 1.0

	# Trigger _process to complete the research
	await runner.wait_frames(2)

	var age = GameManager.get_age(0)
	if age != GameManager.AGE_FEUDAL:
		return Assertions.AssertResult.new(false,
			"Player should be in Feudal Age after research completes, got: %d" % age)

	if tc.is_researching_age:
		return Assertions.AssertResult.new(false,
			"TC should not be researching after completion")

	return Assertions.AssertResult.new(true)


func test_tc_age_research_progress_reports_correctly() -> Assertions.AssertResult:
	## get_age_research_progress() should return correct progress
	GameManager.resources["food"] = 600

	var tc = runner.spawner.spawn_town_center(Vector2(400, 400), 0)
	var barracks = runner.spawner.spawn_barracks(Vector2(500, 400), 0)
	var mill = runner.spawner.spawn_mill(Vector2(600, 400), 0)
	await runner.wait_frames(2)

	# Before research, progress should be 0
	var pre_progress = tc.get_age_research_progress()
	if abs(pre_progress) > 0.01:
		return Assertions.AssertResult.new(false,
			"Progress should be 0 before research, got: %.2f" % pre_progress)

	tc.start_age_research(GameManager.AGE_FEUDAL)

	# Set timer to half the research time
	var half_time = GameManager.AGE_RESEARCH_TIMES[GameManager.AGE_FEUDAL] / 2.0
	tc.age_research_timer = half_time

	var mid_progress = tc.get_age_research_progress()
	if abs(mid_progress - 0.5) > 0.01:
		return Assertions.AssertResult.new(false,
			"Progress should be ~0.5 at halfway, got: %.2f" % mid_progress)

	return Assertions.AssertResult.new(true)


func test_tc_age_research_emits_signals() -> Assertions.AssertResult:
	## TC should emit age_research_started and age_research_completed signals
	GameManager.resources["food"] = 600

	var tc = runner.spawner.spawn_town_center(Vector2(400, 400), 0)
	var barracks = runner.spawner.spawn_barracks(Vector2(500, 400), 0)
	var mill = runner.spawner.spawn_mill(Vector2(600, 400), 0)
	await runner.wait_frames(2)

	var started_data = [false, -1]
	var completed_data = [false, -1]
	tc.age_research_started.connect(func(target_age):
		started_data[0] = true
		started_data[1] = target_age
	)
	tc.age_research_completed.connect(func(new_age):
		completed_data[0] = true
		completed_data[1] = new_age
	)

	tc.start_age_research(GameManager.AGE_FEUDAL)

	if not started_data[0]:
		return Assertions.AssertResult.new(false,
			"age_research_started signal should be emitted")
	if started_data[1] != GameManager.AGE_FEUDAL:
		return Assertions.AssertResult.new(false,
			"started signal should have target age Feudal (1), got: %d" % started_data[1])

	# Complete the research
	tc.age_research_timer = GameManager.AGE_RESEARCH_TIMES[GameManager.AGE_FEUDAL] + 1.0
	await runner.wait_frames(2)

	if not completed_data[0]:
		return Assertions.AssertResult.new(false,
			"age_research_completed signal should be emitted")
	if completed_data[1] != GameManager.AGE_FEUDAL:
		return Assertions.AssertResult.new(false,
			"completed signal should have new age Feudal (1), got: %d" % completed_data[1])

	return Assertions.AssertResult.new(true)


func test_tc_destruction_during_research_refunds_resources() -> Assertions.AssertResult:
	## Destroying TC during age research should refund the age cost
	GameManager.resources["food"] = 600

	var tc = runner.spawner.spawn_town_center(Vector2(400, 400), 0)
	var barracks = runner.spawner.spawn_barracks(Vector2(500, 400), 0)
	var mill = runner.spawner.spawn_mill(Vector2(600, 400), 0)
	await runner.wait_frames(2)

	tc.start_age_research(GameManager.AGE_FEUDAL)

	# Verify food was spent
	var food_after_start = GameManager.get_resource("food", 0)
	if food_after_start != 100:
		return Assertions.AssertResult.new(false,
			"Food should be 100 after starting research, got: %d" % food_after_start)

	# Destroy the TC (triggers cancel_age_research via _destroy)
	tc.take_damage(tc.current_hp)
	await runner.wait_frames(5)

	# Food should be refunded
	var food_after_destroy = GameManager.get_resource("food", 0)
	if food_after_destroy != 600:
		return Assertions.AssertResult.new(false,
			"Food should be refunded to 600 after TC destruction, got: %d" % food_after_destroy)

	return Assertions.AssertResult.new(true)


# =============================================================================
# AI Age Rule Tests
# =============================================================================

func test_ai_feudal_rule_fires_when_ready() -> Assertions.AssertResult:
	## AdvanceToFeudalAgeRule should fire when conditions are met
	var gs = _create_ai_game_state()

	# Set up AI economy: 10+ villagers, 2 qualifying buildings, 500+ food
	GameManager.ai_resources["food"] = 600
	GameManager.ai_population = 0
	GameManager.ai_population_cap = 30

	for i in range(10):
		var villager = runner.spawner.spawn_villager(Vector2(1600 + (i % 5) * 30, 1600 + (i / 5) * 30), 1)
		villager.current_state = Villager.State.IDLE

	# 2 qualifying buildings for Feudal (barracks, mill)
	var barracks = runner.spawner.spawn_barracks(Vector2(1500, 1500), 1)
	var mill = runner.spawner.spawn_mill(Vector2(1400, 1500), 1)
	# Need TC for the research to happen
	var tc = runner.spawner.spawn_town_center(Vector2(1700, 1700), 1)
	await runner.wait_frames(2)

	var rule = AIRules.AdvanceToFeudalAgeRule.new()
	var should_fire = rule.conditions(gs)

	if not should_fire:
		var age = gs.get_age()
		var vill_count = gs.get_civilian_population()
		var qual_count = gs.get_qualifying_building_count(GameManager.AGE_FEUDAL)
		var can_adv = gs.can_advance_age()
		return Assertions.AssertResult.new(false,
			"AdvanceToFeudalAgeRule should fire. age=%d, vills=%d, qual=%d, can_advance=%s" % [
				age, vill_count, qual_count, str(can_adv)])

	return Assertions.AssertResult.new(true)


func test_ai_feudal_rule_blocks_wrong_age() -> Assertions.AssertResult:
	## AdvanceToFeudalAgeRule should not fire if already in Feudal
	var gs = _create_ai_game_state()

	GameManager.set_age(GameManager.AGE_FEUDAL, 1)
	GameManager.ai_resources["food"] = 600

	for i in range(10):
		runner.spawner.spawn_villager(Vector2(1600 + i * 30, 1600), 1)
	runner.spawner.spawn_barracks(Vector2(1500, 1500), 1)
	runner.spawner.spawn_mill(Vector2(1400, 1500), 1)
	await runner.wait_frames(2)

	var rule = AIRules.AdvanceToFeudalAgeRule.new()
	var should_fire = rule.conditions(gs)

	if should_fire:
		return Assertions.AssertResult.new(false,
			"AdvanceToFeudalAgeRule should not fire when already Feudal")

	return Assertions.AssertResult.new(true)


func test_ai_feudal_rule_blocks_insufficient_villagers() -> Assertions.AssertResult:
	## AdvanceToFeudalAgeRule should not fire with < 10 villagers
	var gs = _create_ai_game_state()

	GameManager.ai_resources["food"] = 600

	# Only 5 villagers
	for i in range(5):
		runner.spawner.spawn_villager(Vector2(1600 + i * 30, 1600), 1)
	runner.spawner.spawn_barracks(Vector2(1500, 1500), 1)
	runner.spawner.spawn_mill(Vector2(1400, 1500), 1)
	await runner.wait_frames(2)

	var rule = AIRules.AdvanceToFeudalAgeRule.new()
	var should_fire = rule.conditions(gs)

	if should_fire:
		return Assertions.AssertResult.new(false,
			"AdvanceToFeudalAgeRule should not fire with < 10 villagers")

	return Assertions.AssertResult.new(true)


func test_ai_feudal_rule_blocks_insufficient_buildings() -> Assertions.AssertResult:
	## AdvanceToFeudalAgeRule should not fire without 2 qualifying buildings
	var gs = _create_ai_game_state()

	GameManager.ai_resources["food"] = 600

	for i in range(10):
		runner.spawner.spawn_villager(Vector2(1600 + (i % 5) * 30, 1600 + (i / 5) * 30), 1)
	# Only 1 qualifying building
	runner.spawner.spawn_barracks(Vector2(1500, 1500), 1)
	await runner.wait_frames(2)

	var rule = AIRules.AdvanceToFeudalAgeRule.new()
	var should_fire = rule.conditions(gs)

	if should_fire:
		return Assertions.AssertResult.new(false,
			"AdvanceToFeudalAgeRule should not fire with only 1 qualifying building")

	return Assertions.AssertResult.new(true)


func test_ai_castle_rule_fires_when_ready() -> Assertions.AssertResult:
	## AdvanceToCastleAgeRule should fire when conditions are met
	var gs = _create_ai_game_state()

	# Must be in Feudal Age
	GameManager.set_age(GameManager.AGE_FEUDAL, 1)
	GameManager.ai_resources["food"] = 1000
	GameManager.ai_resources["gold"] = 500
	GameManager.ai_population = 0
	GameManager.ai_population_cap = 30

	# 15+ villagers
	for i in range(15):
		var villager = runner.spawner.spawn_villager(Vector2(1600 + (i % 5) * 30, 1600 + (i / 5) * 30), 1)
		villager.current_state = Villager.State.IDLE

	# 2 qualifying Feudal buildings for Castle (archery_range, stable)
	runner.spawner.spawn_archery_range(Vector2(1500, 1500), 1)
	runner.spawner.spawn_stable(Vector2(1400, 1500), 1)
	# Need TC
	runner.spawner.spawn_town_center(Vector2(1700, 1700), 1)
	await runner.wait_frames(2)

	var rule = AIRules.AdvanceToCastleAgeRule.new()
	var should_fire = rule.conditions(gs)

	if not should_fire:
		var age = gs.get_age()
		var vill_count = gs.get_civilian_population()
		var qual_count = gs.get_qualifying_building_count(GameManager.AGE_CASTLE)
		var can_adv = gs.can_advance_age()
		return Assertions.AssertResult.new(false,
			"AdvanceToCastleAgeRule should fire. age=%d, vills=%d, qual=%d, can_advance=%s" % [
				age, vill_count, qual_count, str(can_adv)])

	return Assertions.AssertResult.new(true)


func test_ai_castle_rule_blocks_wrong_age() -> Assertions.AssertResult:
	## AdvanceToCastleAgeRule should not fire in Dark Age
	var gs = _create_ai_game_state()

	# Still in Dark Age
	GameManager.ai_resources["food"] = 1000
	GameManager.ai_resources["gold"] = 500

	for i in range(15):
		runner.spawner.spawn_villager(Vector2(1600 + (i % 5) * 30, 1600 + (i / 5) * 30), 1)
	runner.spawner.spawn_archery_range(Vector2(1500, 1500), 1)
	runner.spawner.spawn_stable(Vector2(1400, 1500), 1)
	await runner.wait_frames(2)

	var rule = AIRules.AdvanceToCastleAgeRule.new()
	var should_fire = rule.conditions(gs)

	if should_fire:
		return Assertions.AssertResult.new(false,
			"AdvanceToCastleAgeRule should not fire in Dark Age")

	return Assertions.AssertResult.new(true)


func test_ai_castle_rule_blocks_insufficient_villagers() -> Assertions.AssertResult:
	## AdvanceToCastleAgeRule should not fire with < 15 villagers
	var gs = _create_ai_game_state()

	GameManager.set_age(GameManager.AGE_FEUDAL, 1)
	GameManager.ai_resources["food"] = 1000
	GameManager.ai_resources["gold"] = 500

	# Only 10 villagers (need 15)
	for i in range(10):
		runner.spawner.spawn_villager(Vector2(1600 + (i % 5) * 30, 1600 + (i / 5) * 30), 1)
	runner.spawner.spawn_archery_range(Vector2(1500, 1500), 1)
	runner.spawner.spawn_stable(Vector2(1400, 1500), 1)
	await runner.wait_frames(2)

	var rule = AIRules.AdvanceToCastleAgeRule.new()
	var should_fire = rule.conditions(gs)

	if should_fire:
		return Assertions.AssertResult.new(false,
			"AdvanceToCastleAgeRule should not fire with < 15 villagers")

	return Assertions.AssertResult.new(true)


# =============================================================================
# AI can_train blocked during research
# =============================================================================

func test_ai_can_train_villager_blocked_during_research() -> Assertions.AssertResult:
	## AIGameState.can_train("villager") should return false during age research
	var gs = _create_ai_game_state()

	GameManager.ai_resources["food"] = 1000
	GameManager.ai_population = 5
	GameManager.ai_population_cap = 30

	# Set up qualifying buildings for AI
	var tc = runner.spawner.spawn_town_center(Vector2(1700, 1700), 1)
	var barracks = runner.spawner.spawn_barracks(Vector2(1600, 1600), 1)
	var mill = runner.spawner.spawn_mill(Vector2(1500, 1600), 1)
	await runner.wait_frames(2)

	# Verify can train before research
	var can_before = gs.can_train("villager")
	if not can_before:
		var reason = gs.get_can_train_reason("villager")
		return Assertions.AssertResult.new(false,
			"Should be able to train villager before research, reason: %s" % reason)

	# Start research
	tc.start_age_research(GameManager.AGE_FEUDAL)

	# Verify cannot train during research
	var can_during = gs.can_train("villager")
	if can_during:
		return Assertions.AssertResult.new(false,
			"Should not be able to train villager during age research")

	# Verify the reason is correct
	var reason = gs.get_can_train_reason("villager")
	if reason != "tc_researching_age":
		return Assertions.AssertResult.new(false,
			"Reason should be 'tc_researching_age', got: %s" % reason)

	return Assertions.AssertResult.new(true)
