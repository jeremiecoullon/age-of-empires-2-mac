extends Node
## Tech Research Tests - Tests for Phase 5A Technology Research System
##
## These tests verify:
## - GameManager TECHNOLOGIES dict: has_tech, can_research_tech, spend_tech_cost, refund_tech_cost
## - GameManager complete_tech_research, get_tech_bonus, _recalculate_tech_bonuses
## - Building base class research system: start_research, cancel_research, _process_research, get_research_progress
## - Blacksmith building: creation, group membership, available techs, age-gating for techs
## - Loom at Town Center: start_loom_research, blocks training, resumes training after completion
## - Tech effects on units: apply_tech_bonuses for infantry, cavalry, archers, villagers
## - AI game state: can_research, has_tech, _count_researched_techs, get_can_research_reason
## - Age-gating for Blacksmith building (requires Feudal)
## - Reset clears all tech state

class_name TestTechResearch

var runner: TestRunner


func _init(test_runner: TestRunner) -> void:
	runner = test_runner


func get_all_tests() -> Array[Callable]:
	## Returns all test methods to run
	return [
		# GameManager tech state tests
		test_has_tech_false_by_default,
		test_has_tech_true_after_research,
		test_has_tech_team_independent,
		test_reset_clears_all_tech_state,
		# can_research_tech tests
		test_can_research_valid_tech,
		test_cannot_research_unknown_tech,
		test_cannot_research_already_researched,
		test_cannot_research_without_age,
		test_cannot_research_without_prereq,
		test_cannot_research_without_resources,
		test_can_research_with_prereq_met,
		# spend_tech_cost / refund_tech_cost tests
		test_spend_tech_cost_deducts_resources,
		test_spend_tech_cost_fails_insufficient_resources,
		test_refund_tech_cost_returns_resources,
		test_refund_unknown_tech_does_nothing,
		# complete_tech_research + bonuses
		test_complete_tech_research_adds_to_list,
		test_complete_tech_research_emits_signal,
		test_complete_tech_research_calculates_bonuses,
		test_get_tech_bonus_returns_zero_for_unknown,
		test_stacked_bonuses_accumulate,
		# Building base class research system
		test_building_start_research_succeeds,
		test_building_start_research_fails_when_already_researching,
		test_building_cancel_research_refunds_cost,
		test_building_cancel_research_resets_state,
		test_building_research_progress_reports_correctly,
		test_building_research_completes_via_process,
		# Blacksmith building tests
		test_blacksmith_in_blacksmiths_group,
		test_blacksmith_stats,
		test_blacksmith_get_all_techs_returns_blacksmith_only,
		test_blacksmith_available_techs_feudal_age,
		test_blacksmith_available_techs_exclude_researched,
		test_blacksmith_available_techs_require_prereq,
		test_blacksmith_available_techs_castle_age,
		test_blacksmith_age_requirement,
		# Loom at Town Center tests
		test_tc_start_loom_research,
		test_tc_loom_blocks_training,
		test_tc_loom_completes_and_resumes_training,
		test_tc_loom_fails_during_age_research,
		# Tech effects on units
		test_infantry_attack_bonus_militia,
		test_infantry_attack_bonus_spearman,
		test_cavalry_attack_bonus,
		test_archer_attack_bonus,
		test_archer_range_bonus,
		test_infantry_armor_bonus,
		test_cavalry_armor_bonus,
		test_archer_armor_bonus,
		test_villager_loom_hp_bonus,
		test_villager_loom_armor_bonus,
		test_tech_bonus_idempotent,
		# AI game state tech tests
		test_ai_has_tech_false_by_default,
		test_ai_has_tech_true_after_research,
		test_ai_can_research_ok,
		test_ai_can_research_reason_unknown_tech,
		test_ai_can_research_reason_already_researched,
		test_ai_can_research_reason_wrong_age,
		test_ai_can_research_reason_missing_prereq,
		test_ai_can_research_reason_no_blacksmith,
		test_ai_can_research_reason_building_busy,
		test_ai_count_researched_techs,
	]


# =============================================================================
# Mock AI Controller (same pattern as test_age_gating.gd)
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
# GameManager Tech State Tests
# =============================================================================

func test_has_tech_false_by_default() -> Assertions.AssertResult:
	## No techs should be researched after reset
	if GameManager.has_tech("loom", 0):
		return Assertions.AssertResult.new(false, "loom should not be researched by default")
	if GameManager.has_tech("forging", 0):
		return Assertions.AssertResult.new(false, "forging should not be researched by default")
	return Assertions.AssertResult.new(true)


func test_has_tech_true_after_research() -> Assertions.AssertResult:
	## has_tech returns true after complete_tech_research
	GameManager.complete_tech_research("loom", 0)

	if not GameManager.has_tech("loom", 0):
		return Assertions.AssertResult.new(false, "loom should be researched after complete_tech_research")
	return Assertions.AssertResult.new(true)


func test_has_tech_team_independent() -> Assertions.AssertResult:
	## Player researching a tech does not give it to the AI
	GameManager.complete_tech_research("loom", 0)

	if GameManager.has_tech("loom", 1):
		return Assertions.AssertResult.new(false, "AI should not have loom just because player researched it")
	if not GameManager.has_tech("loom", 0):
		return Assertions.AssertResult.new(false, "Player should have loom")
	return Assertions.AssertResult.new(true)


func test_reset_clears_all_tech_state() -> Assertions.AssertResult:
	## reset() clears researched techs and bonuses
	GameManager.complete_tech_research("loom", 0)
	GameManager.complete_tech_research("forging", 1)
	GameManager.reset()

	if GameManager.has_tech("loom", 0):
		return Assertions.AssertResult.new(false, "Player techs should be cleared after reset")
	if GameManager.has_tech("forging", 1):
		return Assertions.AssertResult.new(false, "AI techs should be cleared after reset")
	if GameManager.get_tech_bonus("villager_hp", 0) != 0:
		return Assertions.AssertResult.new(false, "Player tech bonuses should be cleared after reset")
	if GameManager.get_tech_bonus("infantry_attack", 1) != 0:
		return Assertions.AssertResult.new(false, "AI tech bonuses should be cleared after reset")
	return Assertions.AssertResult.new(true)


# =============================================================================
# can_research_tech Tests
# =============================================================================

func test_can_research_valid_tech() -> Assertions.AssertResult:
	## Loom is Dark Age, costs 50 gold, no prereq - should be researchable with enough gold
	GameManager.resources["gold"] = 100

	if not GameManager.can_research_tech("loom", 0):
		return Assertions.AssertResult.new(false, "Should be able to research loom with 100 gold in Dark Age")
	return Assertions.AssertResult.new(true)


func test_cannot_research_unknown_tech() -> Assertions.AssertResult:
	## Unknown tech ID should return false
	if GameManager.can_research_tech("nonexistent_tech", 0):
		return Assertions.AssertResult.new(false, "Unknown tech should not be researchable")
	return Assertions.AssertResult.new(true)


func test_cannot_research_already_researched() -> Assertions.AssertResult:
	## Already researched tech should not be researchable again
	GameManager.resources["gold"] = 100
	GameManager.complete_tech_research("loom", 0)

	if GameManager.can_research_tech("loom", 0):
		return Assertions.AssertResult.new(false, "Already researched tech should not be researchable")
	return Assertions.AssertResult.new(true)


func test_cannot_research_without_age() -> Assertions.AssertResult:
	## Forging requires Feudal, should be blocked in Dark Age
	GameManager.resources["food"] = 1000
	# Player is in Dark Age (default)

	if GameManager.can_research_tech("forging", 0):
		return Assertions.AssertResult.new(false, "Forging should require Feudal Age")
	return Assertions.AssertResult.new(true)


func test_cannot_research_without_prereq() -> Assertions.AssertResult:
	## Iron Casting requires Forging as prerequisite
	GameManager.set_age(GameManager.AGE_CASTLE, 0)
	GameManager.resources["food"] = 1000
	GameManager.resources["gold"] = 1000

	if GameManager.can_research_tech("iron_casting", 0):
		return Assertions.AssertResult.new(false, "Iron Casting should require Forging")
	return Assertions.AssertResult.new(true)


func test_cannot_research_without_resources() -> Assertions.AssertResult:
	## Loom costs 50 gold - should fail with 0 gold
	# Gold is 0 after reset

	if GameManager.can_research_tech("loom", 0):
		return Assertions.AssertResult.new(false, "Loom should require 50 gold")
	return Assertions.AssertResult.new(true)


func test_can_research_with_prereq_met() -> Assertions.AssertResult:
	## Iron Casting should be researchable when Forging is done and in Castle Age
	GameManager.set_age(GameManager.AGE_CASTLE, 0)
	GameManager.resources["food"] = 1000
	GameManager.resources["gold"] = 1000
	GameManager.complete_tech_research("forging", 0)

	if not GameManager.can_research_tech("iron_casting", 0):
		return Assertions.AssertResult.new(false, "Iron Casting should be researchable with Forging done and Castle Age")
	return Assertions.AssertResult.new(true)


# =============================================================================
# spend_tech_cost / refund_tech_cost Tests
# =============================================================================

func test_spend_tech_cost_deducts_resources() -> Assertions.AssertResult:
	## Spending loom cost (50 gold) should deduct from player pool
	GameManager.resources["gold"] = 100

	var success = GameManager.spend_tech_cost("loom", 0)
	if not success:
		return Assertions.AssertResult.new(false, "spend_tech_cost should succeed with enough gold")
	if GameManager.resources["gold"] != 50:
		return Assertions.AssertResult.new(false,
			"Gold should be 50 after spending loom cost, got: %d" % GameManager.resources["gold"])
	return Assertions.AssertResult.new(true)


func test_spend_tech_cost_fails_insufficient_resources() -> Assertions.AssertResult:
	## Spending should fail if not enough resources
	GameManager.resources["gold"] = 10

	var success = GameManager.spend_tech_cost("loom", 0)
	if success:
		return Assertions.AssertResult.new(false, "spend_tech_cost should fail with insufficient gold")
	if GameManager.resources["gold"] != 10:
		return Assertions.AssertResult.new(false, "Gold should be unchanged after failed spend")
	return Assertions.AssertResult.new(true)


func test_refund_tech_cost_returns_resources() -> Assertions.AssertResult:
	## Refunding loom cost should add 50 gold back
	GameManager.resources["gold"] = 0

	GameManager.refund_tech_cost("loom", 0)
	if GameManager.resources["gold"] != 50:
		return Assertions.AssertResult.new(false,
			"Gold should be 50 after refunding loom, got: %d" % GameManager.resources["gold"])
	return Assertions.AssertResult.new(true)


func test_refund_unknown_tech_does_nothing() -> Assertions.AssertResult:
	## Refunding an unknown tech should not crash or change resources
	GameManager.resources["gold"] = 100
	GameManager.refund_tech_cost("nonexistent_tech", 0)

	if GameManager.resources["gold"] != 100:
		return Assertions.AssertResult.new(false, "Gold should be unchanged after refunding unknown tech")
	return Assertions.AssertResult.new(true)


# =============================================================================
# complete_tech_research + Tech Bonus Tests
# =============================================================================

func test_complete_tech_research_adds_to_list() -> Assertions.AssertResult:
	## complete_tech_research adds tech to the researched list
	GameManager.complete_tech_research("loom", 0)

	if not GameManager.player_researched_techs.has("loom"):
		return Assertions.AssertResult.new(false, "loom should be in player_researched_techs")
	return Assertions.AssertResult.new(true)


func test_complete_tech_research_emits_signal() -> Assertions.AssertResult:
	## tech_researched signal should fire with correct args
	var signal_data = [false, -1, ""]
	GameManager.tech_researched.connect(func(t, tid): signal_data[0] = true; signal_data[1] = t; signal_data[2] = tid)

	GameManager.complete_tech_research("loom", 0)

	# Disconnect all - hack to avoid lingering connections
	# The signal will have fired synchronously
	if not signal_data[0]:
		return Assertions.AssertResult.new(false, "tech_researched signal should have emitted")
	if signal_data[1] != 0:
		return Assertions.AssertResult.new(false, "Signal team should be 0, got: %d" % signal_data[1])
	if signal_data[2] != "loom":
		return Assertions.AssertResult.new(false, "Signal tech_id should be 'loom', got: '%s'" % signal_data[2])
	return Assertions.AssertResult.new(true)


func test_complete_tech_research_calculates_bonuses() -> Assertions.AssertResult:
	## Completing loom should create tech bonuses for villager_hp, villager_melee_armor, villager_pierce_armor
	GameManager.complete_tech_research("loom", 0)

	var hp = GameManager.get_tech_bonus("villager_hp", 0)
	var ma = GameManager.get_tech_bonus("villager_melee_armor", 0)
	var pa = GameManager.get_tech_bonus("villager_pierce_armor", 0)

	if hp != 15:
		return Assertions.AssertResult.new(false, "Loom villager_hp bonus should be 15, got: %d" % hp)
	if ma != 1:
		return Assertions.AssertResult.new(false, "Loom villager_melee_armor bonus should be 1, got: %d" % ma)
	if pa != 1:
		return Assertions.AssertResult.new(false, "Loom villager_pierce_armor bonus should be 1, got: %d" % pa)
	return Assertions.AssertResult.new(true)


func test_get_tech_bonus_returns_zero_for_unknown() -> Assertions.AssertResult:
	## Unknown bonus keys should return 0
	var val = GameManager.get_tech_bonus("nonexistent_bonus_key", 0)
	if val != 0:
		return Assertions.AssertResult.new(false, "Unknown bonus key should return 0, got: %d" % val)
	return Assertions.AssertResult.new(true)


func test_stacked_bonuses_accumulate() -> Assertions.AssertResult:
	## Forging (+1 infantry_attack, +1 cavalry_attack) and Iron Casting (+1 each) should stack
	GameManager.complete_tech_research("forging", 0)
	GameManager.complete_tech_research("iron_casting", 0)

	var inf_atk = GameManager.get_tech_bonus("infantry_attack", 0)
	var cav_atk = GameManager.get_tech_bonus("cavalry_attack", 0)

	if inf_atk != 2:
		return Assertions.AssertResult.new(false,
			"Forging + Iron Casting should give +2 infantry_attack, got: %d" % inf_atk)
	if cav_atk != 2:
		return Assertions.AssertResult.new(false,
			"Forging + Iron Casting should give +2 cavalry_attack, got: %d" % cav_atk)
	return Assertions.AssertResult.new(true)


# =============================================================================
# Building Base Class Research System Tests
# =============================================================================

func test_building_start_research_succeeds() -> Assertions.AssertResult:
	## start_research on a blacksmith should work with correct conditions
	GameManager.set_age(GameManager.AGE_FEUDAL, 0)
	GameManager.resources["food"] = 1000
	var bs = runner.spawner.spawn_blacksmith(Vector2(200, 200), 0)
	await runner.wait_frames(2)

	var success = bs.start_research("forging")
	if not success:
		return Assertions.AssertResult.new(false, "start_research should succeed for forging in Feudal Age")
	if not bs.is_researching:
		return Assertions.AssertResult.new(false, "Building should be researching after start_research")
	if bs.current_research_id != "forging":
		return Assertions.AssertResult.new(false, "current_research_id should be 'forging'")
	return Assertions.AssertResult.new(true)


func test_building_start_research_fails_when_already_researching() -> Assertions.AssertResult:
	## Cannot start a second research while one is in progress
	GameManager.set_age(GameManager.AGE_FEUDAL, 0)
	GameManager.resources["food"] = 2000
	var bs = runner.spawner.spawn_blacksmith(Vector2(200, 200), 0)
	await runner.wait_frames(2)

	bs.start_research("forging")
	var second = bs.start_research("scale_mail_armor")
	if second:
		return Assertions.AssertResult.new(false, "Should not be able to start second research while researching")
	return Assertions.AssertResult.new(true)


func test_building_cancel_research_refunds_cost() -> Assertions.AssertResult:
	## Cancelling research should refund the cost
	GameManager.set_age(GameManager.AGE_FEUDAL, 0)
	GameManager.resources["food"] = 200
	var bs = runner.spawner.spawn_blacksmith(Vector2(200, 200), 0)
	await runner.wait_frames(2)

	var food_before = GameManager.resources["food"]
	bs.start_research("forging")  # Costs 150 food
	var food_after_start = GameManager.resources["food"]
	bs.cancel_research()
	var food_after_cancel = GameManager.resources["food"]

	if food_after_start != food_before - 150:
		return Assertions.AssertResult.new(false,
			"Food should decrease by 150 on start, got: %d -> %d" % [food_before, food_after_start])
	if food_after_cancel != food_before:
		return Assertions.AssertResult.new(false,
			"Food should be refunded to %d on cancel, got: %d" % [food_before, food_after_cancel])
	return Assertions.AssertResult.new(true)


func test_building_cancel_research_resets_state() -> Assertions.AssertResult:
	## Cancelling research should reset all research state
	GameManager.set_age(GameManager.AGE_FEUDAL, 0)
	GameManager.resources["food"] = 1000
	var bs = runner.spawner.spawn_blacksmith(Vector2(200, 200), 0)
	await runner.wait_frames(2)

	bs.start_research("forging")
	bs.cancel_research()

	if bs.is_researching:
		return Assertions.AssertResult.new(false, "is_researching should be false after cancel")
	if bs.current_research_id != "":
		return Assertions.AssertResult.new(false, "current_research_id should be empty after cancel")
	if bs.research_timer != 0.0:
		return Assertions.AssertResult.new(false, "research_timer should be 0 after cancel")
	return Assertions.AssertResult.new(true)


func test_building_research_progress_reports_correctly() -> Assertions.AssertResult:
	## get_research_progress should report 0 when not researching, and between 0-1 during research
	GameManager.set_age(GameManager.AGE_FEUDAL, 0)
	GameManager.resources["food"] = 1000
	var bs = runner.spawner.spawn_blacksmith(Vector2(200, 200), 0)
	await runner.wait_frames(2)

	var progress_before = bs.get_research_progress()
	if abs(progress_before) > 0.001:
		return Assertions.AssertResult.new(false, "Progress should be 0 before research, got: %f" % progress_before)

	bs.start_research("forging")
	# Simulate some time passing
	bs.research_timer = 25.0  # Forging takes 50s, so this is 50%
	var progress_during = bs.get_research_progress()
	if abs(progress_during - 0.5) > 0.01:
		return Assertions.AssertResult.new(false,
			"Progress should be ~0.5 at 25/50s, got: %f" % progress_during)
	return Assertions.AssertResult.new(true)


func test_building_research_completes_via_process() -> Assertions.AssertResult:
	## _process_research should complete research when timer exceeds research_time
	GameManager.set_age(GameManager.AGE_FEUDAL, 0)
	GameManager.resources["food"] = 1000
	var bs = runner.spawner.spawn_blacksmith(Vector2(200, 200), 0)
	await runner.wait_frames(2)

	bs.start_research("forging")
	# Fast-forward the timer to just before completion
	bs.research_timer = 49.0
	# Process one big delta to complete
	var completed = bs._process_research(2.0)

	if not completed:
		return Assertions.AssertResult.new(false, "_process_research should return true when research completes")
	if bs.is_researching:
		return Assertions.AssertResult.new(false, "is_researching should be false after completion")
	if not GameManager.has_tech("forging", 0):
		return Assertions.AssertResult.new(false, "forging should be in researched techs after completion")
	return Assertions.AssertResult.new(true)


# =============================================================================
# Blacksmith Building Tests
# =============================================================================

func test_blacksmith_in_blacksmiths_group() -> Assertions.AssertResult:
	## Blacksmith should be in "blacksmiths" group
	var bs = runner.spawner.spawn_blacksmith(Vector2(200, 200), 0)
	await runner.wait_frames(2)

	if not bs.is_in_group("blacksmiths"):
		return Assertions.AssertResult.new(false, "Blacksmith should be in 'blacksmiths' group")
	if not bs.is_in_group("buildings"):
		return Assertions.AssertResult.new(false, "Blacksmith should be in 'buildings' group")
	return Assertions.AssertResult.new(true)


func test_blacksmith_stats() -> Assertions.AssertResult:
	## Blacksmith should have correct stats from AoE2 spec
	var bs = runner.spawner.spawn_blacksmith(Vector2(200, 200), 0)
	await runner.wait_frames(2)

	if bs.max_hp != 2100:
		return Assertions.AssertResult.new(false, "Blacksmith max_hp should be 2100, got: %d" % bs.max_hp)
	if bs.wood_cost != 150:
		return Assertions.AssertResult.new(false, "Blacksmith wood_cost should be 150, got: %d" % bs.wood_cost)
	if bs.building_name != "Blacksmith":
		return Assertions.AssertResult.new(false, "Blacksmith building_name should be 'Blacksmith', got: '%s'" % bs.building_name)
	return Assertions.AssertResult.new(true)


func test_blacksmith_get_all_techs_returns_blacksmith_only() -> Assertions.AssertResult:
	## get_all_techs should return only techs with building == "blacksmith"
	var bs = runner.spawner.spawn_blacksmith(Vector2(200, 200), 0)
	await runner.wait_frames(2)

	var all_techs = bs.get_all_techs()
	# Loom should NOT be in the list (it's at town_center)
	if all_techs.has("loom"):
		return Assertions.AssertResult.new(false, "Blacksmith techs should not include loom")
	# Forging should be in the list
	if not all_techs.has("forging"):
		return Assertions.AssertResult.new(false, "Blacksmith techs should include forging")
	# Count should match the number of blacksmith techs in TECHNOLOGIES
	var expected_count = 0
	for tech_id in GameManager.TECHNOLOGIES:
		if GameManager.TECHNOLOGIES[tech_id]["building"] == "blacksmith":
			expected_count += 1
	if all_techs.size() != expected_count:
		return Assertions.AssertResult.new(false,
			"Expected %d blacksmith techs, got: %d" % [expected_count, all_techs.size()])
	return Assertions.AssertResult.new(true)


func test_blacksmith_available_techs_feudal_age() -> Assertions.AssertResult:
	## In Feudal Age, only Feudal techs without prereqs should be available
	GameManager.set_age(GameManager.AGE_FEUDAL, 0)
	var bs = runner.spawner.spawn_blacksmith(Vector2(200, 200), 0)
	await runner.wait_frames(2)

	var available = bs.get_available_techs()
	# Feudal techs with no prereq: forging, scale_mail_armor, scale_barding_armor, fletching, padded_archer_armor
	var expected_feudal = ["forging", "scale_mail_armor", "scale_barding_armor", "fletching", "padded_archer_armor"]
	for tech_id in expected_feudal:
		if not available.has(tech_id):
			return Assertions.AssertResult.new(false,
				"%s should be available in Feudal Age, available: %s" % [tech_id, str(available)])

	# Castle techs should NOT be available
	var castle_techs = ["iron_casting", "chain_mail_armor", "chain_barding_armor", "bodkin_arrow", "leather_archer_armor"]
	for tech_id in castle_techs:
		if available.has(tech_id):
			return Assertions.AssertResult.new(false,
				"%s should NOT be available in Feudal Age" % tech_id)

	return Assertions.AssertResult.new(true)


func test_blacksmith_available_techs_exclude_researched() -> Assertions.AssertResult:
	## Already researched techs should not appear in available list
	GameManager.set_age(GameManager.AGE_FEUDAL, 0)
	GameManager.complete_tech_research("forging", 0)
	var bs = runner.spawner.spawn_blacksmith(Vector2(200, 200), 0)
	await runner.wait_frames(2)

	var available = bs.get_available_techs()
	if available.has("forging"):
		return Assertions.AssertResult.new(false, "Already researched forging should not be in available list")
	return Assertions.AssertResult.new(true)


func test_blacksmith_available_techs_require_prereq() -> Assertions.AssertResult:
	## Castle techs that require a Feudal prereq should only appear when prereq is done
	GameManager.set_age(GameManager.AGE_CASTLE, 0)
	var bs = runner.spawner.spawn_blacksmith(Vector2(200, 200), 0)
	await runner.wait_frames(2)

	# Iron Casting requires Forging - should NOT be available yet
	var available_before = bs.get_available_techs()
	if available_before.has("iron_casting"):
		return Assertions.AssertResult.new(false,
			"Iron Casting should not be available without Forging")

	# Research Forging
	GameManager.complete_tech_research("forging", 0)
	var available_after = bs.get_available_techs()
	if not available_after.has("iron_casting"):
		return Assertions.AssertResult.new(false,
			"Iron Casting should be available after Forging is done, available: %s" % str(available_after))
	return Assertions.AssertResult.new(true)


func test_blacksmith_available_techs_castle_age() -> Assertions.AssertResult:
	## In Castle Age with prereqs done, Castle techs should appear
	GameManager.set_age(GameManager.AGE_CASTLE, 0)
	# Research all Feudal prereqs
	GameManager.complete_tech_research("forging", 0)
	GameManager.complete_tech_research("scale_mail_armor", 0)
	GameManager.complete_tech_research("scale_barding_armor", 0)
	GameManager.complete_tech_research("fletching", 0)
	GameManager.complete_tech_research("padded_archer_armor", 0)
	var bs = runner.spawner.spawn_blacksmith(Vector2(200, 200), 0)
	await runner.wait_frames(2)

	var available = bs.get_available_techs()
	var castle_techs = ["iron_casting", "chain_mail_armor", "chain_barding_armor", "bodkin_arrow", "leather_archer_armor"]
	for tech_id in castle_techs:
		if not available.has(tech_id):
			return Assertions.AssertResult.new(false,
				"%s should be available in Castle Age with prereqs done, available: %s" % [tech_id, str(available)])
	return Assertions.AssertResult.new(true)


func test_blacksmith_age_requirement() -> Assertions.AssertResult:
	## Blacksmith requires Feudal Age to build
	var required = GameManager.BUILDING_AGE_REQUIREMENTS.get("blacksmith", GameManager.AGE_DARK)
	if required != GameManager.AGE_FEUDAL:
		return Assertions.AssertResult.new(false,
			"Blacksmith should require Feudal Age, got: %d" % required)
	# Dark Age: should be locked
	if GameManager.is_building_unlocked("blacksmith", 0):
		return Assertions.AssertResult.new(false, "Blacksmith should be locked in Dark Age")
	# Feudal Age: should be unlocked
	GameManager.set_age(GameManager.AGE_FEUDAL, 0)
	if not GameManager.is_building_unlocked("blacksmith", 0):
		return Assertions.AssertResult.new(false, "Blacksmith should be unlocked in Feudal Age")
	return Assertions.AssertResult.new(true)


# =============================================================================
# Loom at Town Center Tests
# =============================================================================

func test_tc_start_loom_research() -> Assertions.AssertResult:
	## TC should be able to research Loom when gold is available
	GameManager.resources["gold"] = 100
	var tc = runner.spawner.spawn_town_center(Vector2(400, 400), 0)
	await runner.wait_frames(2)

	var success = tc.start_loom_research()
	if not success:
		return Assertions.AssertResult.new(false, "start_loom_research should succeed with enough gold")
	if not tc.is_researching:
		return Assertions.AssertResult.new(false, "TC should be in researching state")
	if tc.current_research_id != "loom":
		return Assertions.AssertResult.new(false, "current_research_id should be 'loom'")
	# Gold should be deducted
	if GameManager.resources["gold"] != 50:
		return Assertions.AssertResult.new(false,
			"Gold should be 50 after starting loom (cost 50), got: %d" % GameManager.resources["gold"])
	return Assertions.AssertResult.new(true)


func test_tc_loom_blocks_training() -> Assertions.AssertResult:
	## TC should not be able to train villagers while researching Loom
	GameManager.resources["gold"] = 100
	GameManager.resources["food"] = 200
	var tc = runner.spawner.spawn_town_center(Vector2(400, 400), 0)
	await runner.wait_frames(2)

	tc.start_loom_research()
	var train_result = tc.train_villager()
	if train_result:
		return Assertions.AssertResult.new(false,
			"Should not be able to train villager during Loom research")
	return Assertions.AssertResult.new(true)


func test_tc_loom_completes_and_resumes_training() -> Assertions.AssertResult:
	## After Loom completes, queued training should resume
	GameManager.resources["gold"] = 100
	GameManager.resources["food"] = 200
	GameManager.population_cap = 20
	var tc = runner.spawner.spawn_town_center(Vector2(400, 400), 0)
	await runner.wait_frames(2)

	# Queue a villager first, then start loom (loom blocks new training but the
	# queue may have items from before loom started)
	tc.train_villager()  # This should succeed and start training
	var queue_before = tc.get_queue_size()

	# Now start loom - training should pause while loom finishes
	# But since train_villager blocks during is_researching, we test the completion path directly:
	# Start loom with no existing queue, then fast-forward to completion
	tc.cancel_training()
	tc.start_loom_research()
	# Fast forward loom to completion
	tc.research_timer = tc.research_time + 1.0
	tc._process_research(0.0)  # This should trigger _complete_research

	if not GameManager.has_tech("loom", 0):
		return Assertions.AssertResult.new(false, "Loom should be researched after completion")
	if tc.is_researching:
		return Assertions.AssertResult.new(false, "TC should not be researching after Loom completes")

	# Should be able to train again
	var train_after = tc.train_villager()
	if not train_after:
		return Assertions.AssertResult.new(false, "Should be able to train villager after Loom completes")
	return Assertions.AssertResult.new(true)


func test_tc_loom_fails_during_age_research() -> Assertions.AssertResult:
	## Cannot start Loom research while TC is researching an age
	GameManager.resources["gold"] = 100
	GameManager.resources["food"] = 1000
	# Need qualifying buildings for age research
	runner.spawner.spawn_barracks(Vector2(300, 300), 0)
	runner.spawner.spawn_mill(Vector2(350, 300), 0)
	var tc = runner.spawner.spawn_town_center(Vector2(400, 400), 0)
	await runner.wait_frames(2)

	tc.start_age_research(GameManager.AGE_FEUDAL)
	var loom_result = tc.start_loom_research()
	if loom_result:
		return Assertions.AssertResult.new(false,
			"Should not be able to start Loom while researching age")
	return Assertions.AssertResult.new(true)


# =============================================================================
# Tech Effects on Units Tests
# =============================================================================

func test_infantry_attack_bonus_militia() -> Assertions.AssertResult:
	## Forging should give militia +1 attack
	var militia = runner.spawner.spawn_militia(Vector2(200, 200), 0)
	await runner.wait_frames(2)

	var base_attack = militia.attack_damage
	GameManager.complete_tech_research("forging", 0)
	# apply_tech_bonuses is called automatically via _on_tech_researched signal
	await runner.wait_frames(1)

	var new_attack = militia.attack_damage
	if new_attack != base_attack + 1:
		return Assertions.AssertResult.new(false,
			"Militia attack should be %d after Forging, got: %d" % [base_attack + 1, new_attack])
	return Assertions.AssertResult.new(true)


func test_infantry_attack_bonus_spearman() -> Assertions.AssertResult:
	## Forging should give spearman +1 attack (infantry category)
	var spearman = runner.spawner.spawn_spearman(Vector2(200, 200), 0)
	await runner.wait_frames(2)

	var base_attack = spearman.attack_damage
	GameManager.complete_tech_research("forging", 0)
	await runner.wait_frames(1)

	var new_attack = spearman.attack_damage
	if new_attack != base_attack + 1:
		return Assertions.AssertResult.new(false,
			"Spearman attack should be %d after Forging, got: %d" % [base_attack + 1, new_attack])
	return Assertions.AssertResult.new(true)


func test_cavalry_attack_bonus() -> Assertions.AssertResult:
	## Forging should give scout cavalry +1 attack (cavalry category)
	var scout = runner.spawner.spawn_scout_cavalry(Vector2(200, 200), 0)
	await runner.wait_frames(2)

	var base_attack = scout.attack_damage
	GameManager.complete_tech_research("forging", 0)
	await runner.wait_frames(1)

	var new_attack = scout.attack_damage
	if new_attack != base_attack + 1:
		return Assertions.AssertResult.new(false,
			"Scout Cavalry attack should be %d after Forging, got: %d" % [base_attack + 1, new_attack])
	return Assertions.AssertResult.new(true)


func test_archer_attack_bonus() -> Assertions.AssertResult:
	## Fletching should give archer +1 attack
	var archer = runner.spawner.spawn_archer(Vector2(200, 200), 0)
	await runner.wait_frames(2)

	var base_attack = archer.attack_damage
	GameManager.complete_tech_research("fletching", 0)
	await runner.wait_frames(1)

	var new_attack = archer.attack_damage
	if new_attack != base_attack + 1:
		return Assertions.AssertResult.new(false,
			"Archer attack should be %d after Fletching, got: %d" % [base_attack + 1, new_attack])
	return Assertions.AssertResult.new(true)


func test_archer_range_bonus() -> Assertions.AssertResult:
	## Fletching should give archer +1 range (1 tile = 32 pixels)
	var archer = runner.spawner.spawn_archer(Vector2(200, 200), 0)
	await runner.wait_frames(2)

	var base_range = archer.attack_range
	GameManager.complete_tech_research("fletching", 0)
	await runner.wait_frames(1)

	var new_range = archer.attack_range
	var expected = base_range + 32.0  # +1 range = +1 tile = +32px
	if abs(new_range - expected) > 0.5:
		return Assertions.AssertResult.new(false,
			"Archer range should be %.1f after Fletching, got: %.1f" % [expected, new_range])
	return Assertions.AssertResult.new(true)


func test_infantry_armor_bonus() -> Assertions.AssertResult:
	## Scale Mail Armor should give militia +1/+1 armor
	var militia = runner.spawner.spawn_militia(Vector2(200, 200), 0)
	await runner.wait_frames(2)

	var base_ma = militia.melee_armor
	var base_pa = militia.pierce_armor
	GameManager.complete_tech_research("scale_mail_armor", 0)
	await runner.wait_frames(1)

	if militia.melee_armor != base_ma + 1:
		return Assertions.AssertResult.new(false,
			"Militia melee_armor should be %d after Scale Mail, got: %d" % [base_ma + 1, militia.melee_armor])
	if militia.pierce_armor != base_pa + 1:
		return Assertions.AssertResult.new(false,
			"Militia pierce_armor should be %d after Scale Mail, got: %d" % [base_pa + 1, militia.pierce_armor])
	return Assertions.AssertResult.new(true)


func test_cavalry_armor_bonus() -> Assertions.AssertResult:
	## Scale Barding Armor should give scout cavalry +1/+1 armor
	var scout = runner.spawner.spawn_scout_cavalry(Vector2(200, 200), 0)
	await runner.wait_frames(2)

	var base_ma = scout.melee_armor
	var base_pa = scout.pierce_armor
	GameManager.complete_tech_research("scale_barding_armor", 0)
	await runner.wait_frames(1)

	if scout.melee_armor != base_ma + 1:
		return Assertions.AssertResult.new(false,
			"Scout melee_armor should be %d after Scale Barding, got: %d" % [base_ma + 1, scout.melee_armor])
	if scout.pierce_armor != base_pa + 1:
		return Assertions.AssertResult.new(false,
			"Scout pierce_armor should be %d after Scale Barding, got: %d" % [base_pa + 1, scout.pierce_armor])
	return Assertions.AssertResult.new(true)


func test_archer_armor_bonus() -> Assertions.AssertResult:
	## Padded Archer Armor should give archer +1/+1 armor
	var archer = runner.spawner.spawn_archer(Vector2(200, 200), 0)
	await runner.wait_frames(2)

	var base_ma = archer.melee_armor
	var base_pa = archer.pierce_armor
	GameManager.complete_tech_research("padded_archer_armor", 0)
	await runner.wait_frames(1)

	if archer.melee_armor != base_ma + 1:
		return Assertions.AssertResult.new(false,
			"Archer melee_armor should be %d after Padded Armor, got: %d" % [base_ma + 1, archer.melee_armor])
	if archer.pierce_armor != base_pa + 1:
		return Assertions.AssertResult.new(false,
			"Archer pierce_armor should be %d after Padded Armor, got: %d" % [base_pa + 1, archer.pierce_armor])
	return Assertions.AssertResult.new(true)


func test_villager_loom_hp_bonus() -> Assertions.AssertResult:
	## Loom should give villagers +15 HP
	var villager = runner.spawner.spawn_villager(Vector2(200, 200), 0)
	await runner.wait_frames(2)

	var base_max_hp = villager.max_hp
	var base_current_hp = villager.current_hp
	GameManager.complete_tech_research("loom", 0)
	await runner.wait_frames(1)

	if villager.max_hp != base_max_hp + 15:
		return Assertions.AssertResult.new(false,
			"Villager max_hp should be %d after Loom, got: %d" % [base_max_hp + 15, villager.max_hp])
	# Current HP should also increase by the bonus amount
	if villager.current_hp != base_current_hp + 15:
		return Assertions.AssertResult.new(false,
			"Villager current_hp should be %d after Loom, got: %d" % [base_current_hp + 15, villager.current_hp])
	return Assertions.AssertResult.new(true)


func test_villager_loom_armor_bonus() -> Assertions.AssertResult:
	## Loom should give villagers +1/+1 armor
	var villager = runner.spawner.spawn_villager(Vector2(200, 200), 0)
	await runner.wait_frames(2)

	var base_ma = villager.melee_armor
	var base_pa = villager.pierce_armor
	GameManager.complete_tech_research("loom", 0)
	await runner.wait_frames(1)

	if villager.melee_armor != base_ma + 1:
		return Assertions.AssertResult.new(false,
			"Villager melee_armor should be %d after Loom, got: %d" % [base_ma + 1, villager.melee_armor])
	if villager.pierce_armor != base_pa + 1:
		return Assertions.AssertResult.new(false,
			"Villager pierce_armor should be %d after Loom, got: %d" % [base_pa + 1, villager.pierce_armor])
	return Assertions.AssertResult.new(true)


func test_tech_bonus_idempotent() -> Assertions.AssertResult:
	## Calling apply_tech_bonuses multiple times should give same result
	var militia = runner.spawner.spawn_militia(Vector2(200, 200), 0)
	await runner.wait_frames(2)

	GameManager.complete_tech_research("forging", 0)
	await runner.wait_frames(1)

	var attack_after_first = militia.attack_damage
	# Call apply_tech_bonuses again manually
	militia.apply_tech_bonuses()
	var attack_after_second = militia.attack_damage

	if attack_after_first != attack_after_second:
		return Assertions.AssertResult.new(false,
			"apply_tech_bonuses should be idempotent: first=%d, second=%d" % [attack_after_first, attack_after_second])
	return Assertions.AssertResult.new(true)


# =============================================================================
# AI Game State Tech Tests
# =============================================================================

func test_ai_has_tech_false_by_default() -> Assertions.AssertResult:
	## AI should not have any tech by default
	var gs = _create_ai_game_state()
	if gs.has_tech("loom"):
		return Assertions.AssertResult.new(false, "AI should not have loom by default")
	return Assertions.AssertResult.new(true)


func test_ai_has_tech_true_after_research() -> Assertions.AssertResult:
	## AI has_tech should return true after tech is researched for AI team
	var gs = _create_ai_game_state()
	GameManager.complete_tech_research("loom", 1)

	if not gs.has_tech("loom"):
		return Assertions.AssertResult.new(false, "AI should have loom after complete_tech_research")
	return Assertions.AssertResult.new(true)


func test_ai_can_research_ok() -> Assertions.AssertResult:
	## AI can_research should return true when conditions met
	var gs = _create_ai_game_state()
	GameManager.set_age(GameManager.AGE_FEUDAL, 1)
	GameManager.ai_resources["food"] = 1000
	# Need a blacksmith for forging
	runner.spawner.spawn_blacksmith(Vector2(1600, 1600), 1)
	await runner.wait_frames(2)

	if not gs.can_research("forging"):
		var reason = gs.get_can_research_reason("forging")
		return Assertions.AssertResult.new(false,
			"AI should be able to research forging, reason: %s" % reason)
	return Assertions.AssertResult.new(true)


func test_ai_can_research_reason_unknown_tech() -> Assertions.AssertResult:
	## Unknown tech should return "unknown_tech"
	var gs = _create_ai_game_state()
	var reason = gs.get_can_research_reason("nonexistent_tech")
	if reason != "unknown_tech":
		return Assertions.AssertResult.new(false,
			"Reason should be 'unknown_tech', got: '%s'" % reason)
	return Assertions.AssertResult.new(true)


func test_ai_can_research_reason_already_researched() -> Assertions.AssertResult:
	## Already researched tech should return "already_researched"
	var gs = _create_ai_game_state()
	GameManager.complete_tech_research("loom", 1)

	var reason = gs.get_can_research_reason("loom")
	if reason != "already_researched":
		return Assertions.AssertResult.new(false,
			"Reason should be 'already_researched', got: '%s'" % reason)
	return Assertions.AssertResult.new(true)


func test_ai_can_research_reason_wrong_age() -> Assertions.AssertResult:
	## Feudal tech in Dark Age should return age reason
	var gs = _create_ai_game_state()
	# AI in Dark Age (default)
	GameManager.ai_resources["food"] = 1000
	runner.spawner.spawn_blacksmith(Vector2(1600, 1600), 1)
	await runner.wait_frames(2)

	var reason = gs.get_can_research_reason("forging")
	if reason != "requires_feudal_age":
		return Assertions.AssertResult.new(false,
			"Reason should be 'requires_feudal_age', got: '%s'" % reason)
	return Assertions.AssertResult.new(true)


func test_ai_can_research_reason_missing_prereq() -> Assertions.AssertResult:
	## Castle tech without Feudal prereq should return requires_<prereq>
	var gs = _create_ai_game_state()
	GameManager.set_age(GameManager.AGE_CASTLE, 1)
	GameManager.ai_resources["food"] = 1000
	GameManager.ai_resources["gold"] = 1000
	runner.spawner.spawn_blacksmith(Vector2(1600, 1600), 1)
	await runner.wait_frames(2)

	var reason = gs.get_can_research_reason("iron_casting")
	if reason != "requires_forging":
		return Assertions.AssertResult.new(false,
			"Reason should be 'requires_forging', got: '%s'" % reason)
	return Assertions.AssertResult.new(true)


func test_ai_can_research_reason_no_blacksmith() -> Assertions.AssertResult:
	## Without a blacksmith, should return "no_blacksmith"
	var gs = _create_ai_game_state()
	GameManager.set_age(GameManager.AGE_FEUDAL, 1)
	GameManager.ai_resources["food"] = 1000
	# No blacksmith spawned

	var reason = gs.get_can_research_reason("forging")
	if reason != "no_blacksmith":
		return Assertions.AssertResult.new(false,
			"Reason should be 'no_blacksmith', got: '%s'" % reason)
	return Assertions.AssertResult.new(true)


func test_ai_can_research_reason_building_busy() -> Assertions.AssertResult:
	## If blacksmith is already researching, should return "building_busy"
	var gs = _create_ai_game_state()
	GameManager.set_age(GameManager.AGE_FEUDAL, 1)
	GameManager.ai_resources["food"] = 2000
	var bs = runner.spawner.spawn_blacksmith(Vector2(1600, 1600), 1)
	await runner.wait_frames(2)

	# Start one research
	bs.start_research("forging")

	# Try to check another
	var reason = gs.get_can_research_reason("scale_mail_armor")
	if reason != "building_busy":
		return Assertions.AssertResult.new(false,
			"Reason should be 'building_busy', got: '%s'" % reason)
	return Assertions.AssertResult.new(true)


func test_ai_count_researched_techs() -> Assertions.AssertResult:
	## _count_researched_techs should return correct count for AI
	var gs = _create_ai_game_state()

	var count_before = gs._count_researched_techs()
	if count_before != 0:
		return Assertions.AssertResult.new(false,
			"Count should be 0 initially, got: %d" % count_before)

	GameManager.complete_tech_research("loom", 1)
	GameManager.complete_tech_research("forging", 1)

	var count_after = gs._count_researched_techs()
	if count_after != 2:
		return Assertions.AssertResult.new(false,
			"Count should be 2 after researching loom + forging, got: %d" % count_after)
	return Assertions.AssertResult.new(true)
