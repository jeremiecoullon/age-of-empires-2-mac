extends Node
## AI Military Tests - Tests for Phase 3.1C AI Military Rules
##
## These tests verify:
## - Military building rules (archery range, stable)
## - Military training rules (militia, spearman, archer, skirmisher, scout cavalry, cavalry archer)
## - Counter-unit logic (enemy cavalry/archer counting)
## - Defense rule (defend when under attack)
## - Scouting rule (send idle scouts to explore)
##
## Note: These tests unit test the helper methods and rule conditions directly,
## not full AI behavior (that's tested by AI behavior tests).

class_name TestAIMilitary

var runner: TestRunner


func _init(test_runner: TestRunner) -> void:
	runner = test_runner


func get_all_tests() -> Array[Callable]:
	## Returns all test methods to run
	return [
		# Enemy count helpers
		test_get_enemy_cavalry_count_includes_scouts,
		test_get_enemy_cavalry_count_includes_cavalry_archers,
		test_get_enemy_cavalry_count_excludes_ai_cavalry,
		test_get_enemy_cavalry_count_excludes_dead,
		test_get_enemy_archer_count_includes_archers,
		test_get_enemy_archer_count_includes_cavalry_archers,
		test_get_enemy_archer_count_excludes_ai_archers,
		test_get_enemy_infantry_count_includes_militia,
		test_get_enemy_infantry_count_includes_spearmen,
		# Military building rules
		test_build_archery_range_requires_barracks,
		test_build_archery_range_requires_villagers,
		test_build_archery_range_fires_when_conditions_met,
		test_build_archery_range_queued_flag_prevents_multiple,
		test_build_archery_range_queued_flag_resets,
		test_build_stable_requires_barracks,
		test_build_stable_requires_more_villagers_than_archery_range,
		test_build_stable_fires_when_conditions_met,
		test_build_stable_queued_flag_prevents_multiple,
		# Military training rules
		test_train_militia_requires_barracks,
		test_train_militia_fires_with_barracks,
		test_train_spearman_requires_enemy_cavalry,
		test_train_spearman_doesnt_fire_without_cavalry,
		test_train_archer_requires_archery_range,
		test_train_archer_respects_ranged_cap,
		test_train_skirmisher_requires_enemy_archers,
		test_train_skirmisher_doesnt_fire_without_archers,
		test_train_scout_cavalry_requires_stable,
		test_train_scout_cavalry_first_always_trains,
		test_train_scout_cavalry_caps_at_three,
		test_train_cavalry_archer_requires_stable,
		test_train_cavalry_archer_requires_gold,
		test_train_cavalry_archer_requires_military,
		# Defense rule
		test_defend_base_fires_when_under_attack,
		test_defend_base_requires_military,
		test_is_under_attack_detects_nearby_enemy,
		test_is_under_attack_ignores_distant_enemy,
		test_get_nearest_threat_returns_closest,
		# Scouting rule
		test_scouting_rule_requires_idle_scout,
		test_get_idle_scout_returns_idle,
		test_get_idle_scout_excludes_moving,
		test_scout_targets_cycle,
	]


# =============================================================================
# Mock AI Controller
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
# Enemy Count Helper Tests
# =============================================================================

func test_get_enemy_cavalry_count_includes_scouts() -> Assertions.AssertResult:
	## Enemy scout cavalry should be counted
	var gs = _create_ai_game_state()

	# Spawn player scout cavalry (team 0)
	runner.spawner.spawn_scout_cavalry(Vector2(500, 500), 0)
	runner.spawner.spawn_scout_cavalry(Vector2(550, 500), 0)
	await runner.wait_frames(2)

	var count = gs.get_enemy_cavalry_count()

	if count != 2:
		return Assertions.AssertResult.new(false,
			"Should count 2 enemy scout cavalry, got: %d" % count)

	return Assertions.AssertResult.new(true)


func test_get_enemy_cavalry_count_includes_cavalry_archers() -> Assertions.AssertResult:
	## Enemy cavalry archers should be counted as cavalry
	var gs = _create_ai_game_state()

	# Spawn player cavalry archer (team 0)
	runner.spawner.spawn_cavalry_archer(Vector2(500, 500), 0)
	await runner.wait_frames(2)

	var count = gs.get_enemy_cavalry_count()

	if count != 1:
		return Assertions.AssertResult.new(false,
			"Should count 1 enemy cavalry archer as cavalry, got: %d" % count)

	return Assertions.AssertResult.new(true)


func test_get_enemy_cavalry_count_excludes_ai_cavalry() -> Assertions.AssertResult:
	## AI's own cavalry should NOT be counted as enemy
	var gs = _create_ai_game_state()

	# Spawn AI scout cavalry (team 1)
	runner.spawner.spawn_scout_cavalry(Vector2(500, 500), 1)
	# Spawn player scout cavalry (team 0)
	runner.spawner.spawn_scout_cavalry(Vector2(550, 500), 0)
	await runner.wait_frames(2)

	var count = gs.get_enemy_cavalry_count()

	if count != 1:
		return Assertions.AssertResult.new(false,
			"Should only count player cavalry (1), not AI cavalry, got: %d" % count)

	return Assertions.AssertResult.new(true)


func test_get_enemy_cavalry_count_excludes_dead() -> Assertions.AssertResult:
	## Dead cavalry should not be counted
	var gs = _create_ai_game_state()

	var scout = runner.spawner.spawn_scout_cavalry(Vector2(500, 500), 0)
	await runner.wait_frames(2)

	# Kill the scout
	scout.is_dead = true

	var count = gs.get_enemy_cavalry_count()

	if count != 0:
		return Assertions.AssertResult.new(false,
			"Dead cavalry should not be counted, got: %d" % count)

	return Assertions.AssertResult.new(true)


func test_get_enemy_archer_count_includes_archers() -> Assertions.AssertResult:
	## Enemy archers should be counted
	var gs = _create_ai_game_state()

	runner.spawner.spawn_archer(Vector2(500, 500), 0)
	runner.spawner.spawn_archer(Vector2(550, 500), 0)
	await runner.wait_frames(2)

	var count = gs.get_enemy_archer_count()

	if count != 2:
		return Assertions.AssertResult.new(false,
			"Should count 2 enemy archers, got: %d" % count)

	return Assertions.AssertResult.new(true)


func test_get_enemy_archer_count_includes_cavalry_archers() -> Assertions.AssertResult:
	## Enemy cavalry archers should also be counted as archers (ranged)
	var gs = _create_ai_game_state()

	runner.spawner.spawn_cavalry_archer(Vector2(500, 500), 0)
	await runner.wait_frames(2)

	var count = gs.get_enemy_archer_count()

	if count != 1:
		return Assertions.AssertResult.new(false,
			"Should count 1 enemy cavalry archer as ranged, got: %d" % count)

	return Assertions.AssertResult.new(true)


func test_get_enemy_archer_count_excludes_ai_archers() -> Assertions.AssertResult:
	## AI's own archers should NOT be counted as enemy
	var gs = _create_ai_game_state()

	# Spawn AI archer (team 1)
	runner.spawner.spawn_archer(Vector2(500, 500), 1)
	# Spawn player archer (team 0)
	runner.spawner.spawn_archer(Vector2(550, 500), 0)
	await runner.wait_frames(2)

	var count = gs.get_enemy_archer_count()

	if count != 1:
		return Assertions.AssertResult.new(false,
			"Should only count player archers (1), not AI archers, got: %d" % count)

	return Assertions.AssertResult.new(true)


func test_get_enemy_infantry_count_includes_militia() -> Assertions.AssertResult:
	## Enemy militia should be counted as infantry
	var gs = _create_ai_game_state()

	runner.spawner.spawn_militia(Vector2(500, 500), 0)
	await runner.wait_frames(2)

	var count = gs.get_enemy_infantry_count()

	if count < 1:
		return Assertions.AssertResult.new(false,
			"Should count enemy militia as infantry, got: %d" % count)

	return Assertions.AssertResult.new(true)


func test_get_enemy_infantry_count_includes_spearmen() -> Assertions.AssertResult:
	## Enemy spearmen should be counted as infantry
	var gs = _create_ai_game_state()

	runner.spawner.spawn_spearman(Vector2(500, 500), 0)
	await runner.wait_frames(2)

	var count = gs.get_enemy_infantry_count()

	if count < 1:
		return Assertions.AssertResult.new(false,
			"Should count enemy spearmen as infantry, got: %d" % count)

	return Assertions.AssertResult.new(true)


# =============================================================================
# Military Building Rule Tests
# =============================================================================

func test_build_archery_range_requires_barracks() -> Assertions.AssertResult:
	## BuildArcheryRangeRule should not fire without barracks
	var gs = _create_ai_game_state()

	# Spawn enough villagers
	for i in range(10):
		var v = runner.spawner.spawn_villager(Vector2(500 + i * 50, 500), 1)
		v.current_state = Villager.State.IDLE
	GameManager.ai_resources["wood"] = 300
	await runner.wait_frames(2)

	var rule = AIRules.BuildArcheryRangeRule.new()
	var should_fire = rule.conditions(gs)

	if should_fire:
		return Assertions.AssertResult.new(false,
			"BuildArcheryRangeRule should not fire without barracks")

	return Assertions.AssertResult.new(true)


func test_build_archery_range_requires_villagers() -> Assertions.AssertResult:
	## BuildArcheryRangeRule should not fire with too few villagers
	var gs = _create_ai_game_state()

	# Spawn barracks but only 5 villagers (need 8)
	runner.spawner.spawn_barracks(Vector2(600, 600), 1)
	for i in range(5):
		var v = runner.spawner.spawn_villager(Vector2(500 + i * 50, 500), 1)
		v.current_state = Villager.State.IDLE
	GameManager.ai_resources["wood"] = 300
	await runner.wait_frames(2)

	var rule = AIRules.BuildArcheryRangeRule.new()
	var should_fire = rule.conditions(gs)

	if should_fire:
		return Assertions.AssertResult.new(false,
			"BuildArcheryRangeRule should not fire with only 5 villagers (need 8+)")

	return Assertions.AssertResult.new(true)


func test_build_archery_range_fires_when_conditions_met() -> Assertions.AssertResult:
	## BuildArcheryRangeRule should fire when barracks exists and 8+ villagers
	var gs = _create_ai_game_state()

	runner.spawner.spawn_barracks(Vector2(600, 600), 1)
	for i in range(9):
		var v = runner.spawner.spawn_villager(Vector2(500 + (i % 4) * 50, 500 + (i / 4) * 50), 1)
		v.current_state = Villager.State.IDLE
	GameManager.ai_resources["wood"] = 300
	await runner.wait_frames(2)

	var rule = AIRules.BuildArcheryRangeRule.new()
	var should_fire = rule.conditions(gs)

	if not should_fire:
		var vill_count = gs.get_civilian_population()
		var barracks_count = gs.get_building_count("barracks")
		var can_build = gs.can_build("archery_range")
		return Assertions.AssertResult.new(false,
			"BuildArcheryRangeRule should fire. Debug: vill=%d, barracks=%d, can_build=%s" % [
				vill_count, barracks_count, str(can_build)])

	return Assertions.AssertResult.new(true)


func test_build_archery_range_queued_flag_prevents_multiple() -> Assertions.AssertResult:
	## BuildArcheryRangeRule should not fire twice (queued flag)
	var gs = _create_ai_game_state()

	runner.spawner.spawn_barracks(Vector2(600, 600), 1)
	for i in range(9):
		var v = runner.spawner.spawn_villager(Vector2(500 + (i % 4) * 50, 500 + (i / 4) * 50), 1)
		v.current_state = Villager.State.IDLE
	GameManager.ai_resources["wood"] = 500
	await runner.wait_frames(2)

	var rule = AIRules.BuildArcheryRangeRule.new()

	# First check - should fire
	var first_fire = rule.conditions(gs)
	if first_fire:
		rule.actions(gs)  # This sets _archery_range_queued = true

	# Second check - should NOT fire (already queued)
	var second_fire = rule.conditions(gs)

	if second_fire:
		return Assertions.AssertResult.new(false,
			"BuildArcheryRangeRule should not fire twice when already queued")

	return Assertions.AssertResult.new(true)


func test_build_archery_range_queued_flag_resets() -> Assertions.AssertResult:
	## BuildArcheryRangeRule queued flag should reset when building exists
	var gs = _create_ai_game_state()

	runner.spawner.spawn_barracks(Vector2(600, 600), 1)
	for i in range(9):
		var v = runner.spawner.spawn_villager(Vector2(500 + (i % 4) * 50, 500 + (i / 4) * 50), 1)
		v.current_state = Villager.State.IDLE
	GameManager.ai_resources["wood"] = 500
	await runner.wait_frames(2)

	var rule = AIRules.BuildArcheryRangeRule.new()

	# First: fire and queue
	var first_fire = rule.conditions(gs)
	if first_fire:
		rule.actions(gs)

	# Now spawn archery range (simulating construction complete)
	runner.spawner.spawn_archery_range(Vector2(700, 700), 1)
	await runner.wait_frames(2)

	# Check again - should return false (building exists) AND reset the flag
	var after_exists = rule.conditions(gs)

	# Building exists, so condition should be false
	if after_exists:
		return Assertions.AssertResult.new(false,
			"BuildArcheryRangeRule should not fire when archery range already exists")

	return Assertions.AssertResult.new(true)


func test_build_stable_requires_barracks() -> Assertions.AssertResult:
	## BuildStableRule should not fire without barracks
	var gs = _create_ai_game_state()

	for i in range(12):
		var v = runner.spawner.spawn_villager(Vector2(500 + (i % 4) * 50, 500 + (i / 4) * 50), 1)
		v.current_state = Villager.State.IDLE
	GameManager.ai_resources["wood"] = 300
	await runner.wait_frames(2)

	var rule = AIRules.BuildStableRule.new()
	var should_fire = rule.conditions(gs)

	if should_fire:
		return Assertions.AssertResult.new(false,
			"BuildStableRule should not fire without barracks")

	return Assertions.AssertResult.new(true)


func test_build_stable_requires_more_villagers_than_archery_range() -> Assertions.AssertResult:
	## BuildStableRule requires 10+ villagers (vs 8 for archery range)
	var gs = _create_ai_game_state()

	runner.spawner.spawn_barracks(Vector2(600, 600), 1)
	# Spawn exactly 8 villagers (enough for archery range but not stable)
	for i in range(8):
		var v = runner.spawner.spawn_villager(Vector2(500 + (i % 4) * 50, 500 + (i / 4) * 50), 1)
		v.current_state = Villager.State.IDLE
	GameManager.ai_resources["wood"] = 300
	await runner.wait_frames(2)

	var archery_rule = AIRules.BuildArcheryRangeRule.new()
	var stable_rule = AIRules.BuildStableRule.new()

	var archery_fires = archery_rule.conditions(gs)
	var stable_fires = stable_rule.conditions(gs)

	if not archery_fires:
		return Assertions.AssertResult.new(false,
			"Archery range should fire with 8 villagers")

	if stable_fires:
		return Assertions.AssertResult.new(false,
			"Stable should NOT fire with only 8 villagers (needs 10)")

	return Assertions.AssertResult.new(true)


func test_build_stable_fires_when_conditions_met() -> Assertions.AssertResult:
	## BuildStableRule should fire when barracks exists and 10+ villagers
	var gs = _create_ai_game_state()

	runner.spawner.spawn_barracks(Vector2(600, 600), 1)
	for i in range(12):
		var v = runner.spawner.spawn_villager(Vector2(500 + (i % 4) * 50, 500 + (i / 4) * 50), 1)
		v.current_state = Villager.State.IDLE
	GameManager.ai_resources["wood"] = 300
	await runner.wait_frames(2)

	var rule = AIRules.BuildStableRule.new()
	var should_fire = rule.conditions(gs)

	if not should_fire:
		var vill_count = gs.get_civilian_population()
		var barracks_count = gs.get_building_count("barracks")
		var can_build = gs.can_build("stable")
		return Assertions.AssertResult.new(false,
			"BuildStableRule should fire. Debug: vill=%d, barracks=%d, can_build=%s" % [
				vill_count, barracks_count, str(can_build)])

	return Assertions.AssertResult.new(true)


func test_build_stable_queued_flag_prevents_multiple() -> Assertions.AssertResult:
	## BuildStableRule should not fire twice (queued flag)
	var gs = _create_ai_game_state()

	runner.spawner.spawn_barracks(Vector2(600, 600), 1)
	for i in range(12):
		var v = runner.spawner.spawn_villager(Vector2(500 + (i % 4) * 50, 500 + (i / 4) * 50), 1)
		v.current_state = Villager.State.IDLE
	GameManager.ai_resources["wood"] = 500
	await runner.wait_frames(2)

	var rule = AIRules.BuildStableRule.new()

	# First check - should fire
	var first_fire = rule.conditions(gs)
	if first_fire:
		rule.actions(gs)  # This sets _stable_queued = true

	# Second check - should NOT fire
	var second_fire = rule.conditions(gs)

	if second_fire:
		return Assertions.AssertResult.new(false,
			"BuildStableRule should not fire twice when already queued")

	return Assertions.AssertResult.new(true)


# =============================================================================
# Military Training Rule Tests
# =============================================================================

func test_train_militia_requires_barracks() -> Assertions.AssertResult:
	## TrainMilitiaRule should not fire without barracks
	var gs = _create_ai_game_state()

	GameManager.ai_resources["food"] = 200
	GameManager.ai_resources["wood"] = 200

	var rule = AIRules.TrainMilitiaRule.new()
	var should_fire = rule.conditions(gs)

	if should_fire:
		return Assertions.AssertResult.new(false,
			"TrainMilitiaRule should not fire without barracks")

	return Assertions.AssertResult.new(true)


func test_train_militia_fires_with_barracks() -> Assertions.AssertResult:
	## TrainMilitiaRule should fire when barracks exists
	var gs = _create_ai_game_state()

	runner.spawner.spawn_barracks(Vector2(600, 600), 1)
	runner.spawner.spawn_house(Vector2(500, 500), 1)  # For pop cap
	await runner.wait_frames(2)

	GameManager.ai_resources["food"] = 200
	GameManager.ai_resources["wood"] = 200

	var rule = AIRules.TrainMilitiaRule.new()
	var should_fire = rule.conditions(gs)

	if not should_fire:
		var barracks_count = gs.get_building_count("barracks")
		var can_train = gs.can_train("militia")
		var reason = gs.get_can_train_reason("militia")
		return Assertions.AssertResult.new(false,
			"TrainMilitiaRule should fire with barracks. Debug: barracks=%d, can_train=%s, reason=%s" % [
				barracks_count, str(can_train), reason])

	return Assertions.AssertResult.new(true)


func test_train_spearman_requires_enemy_cavalry() -> Assertions.AssertResult:
	## TrainSpearmanRule should only fire when enemy has cavalry (counter unit)
	var gs = _create_ai_game_state()

	runner.spawner.spawn_barracks(Vector2(600, 600), 1)
	runner.spawner.spawn_house(Vector2(500, 500), 1)
	# Spawn enemy cavalry
	runner.spawner.spawn_scout_cavalry(Vector2(800, 800), 0)
	await runner.wait_frames(2)

	GameManager.ai_resources["food"] = 200
	GameManager.ai_resources["wood"] = 200

	var rule = AIRules.TrainSpearmanRule.new()
	var should_fire = rule.conditions(gs)

	if not should_fire:
		var enemy_cav = gs.get_enemy_cavalry_count()
		var can_train = gs.can_train("spearman")
		return Assertions.AssertResult.new(false,
			"TrainSpearmanRule should fire when enemy has cavalry. Debug: enemy_cav=%d, can_train=%s" % [
				enemy_cav, str(can_train)])

	return Assertions.AssertResult.new(true)


func test_train_spearman_doesnt_fire_without_cavalry() -> Assertions.AssertResult:
	## TrainSpearmanRule should NOT fire when enemy has no cavalry
	var gs = _create_ai_game_state()

	runner.spawner.spawn_barracks(Vector2(600, 600), 1)
	runner.spawner.spawn_house(Vector2(500, 500), 1)
	# Spawn enemy infantry only (no cavalry)
	runner.spawner.spawn_militia(Vector2(800, 800), 0)
	await runner.wait_frames(2)

	GameManager.ai_resources["food"] = 200
	GameManager.ai_resources["wood"] = 200

	var rule = AIRules.TrainSpearmanRule.new()
	var should_fire = rule.conditions(gs)

	if should_fire:
		return Assertions.AssertResult.new(false,
			"TrainSpearmanRule should NOT fire when enemy has no cavalry")

	return Assertions.AssertResult.new(true)


func test_train_archer_requires_archery_range() -> Assertions.AssertResult:
	## TrainArcherRule should not fire without archery range
	var gs = _create_ai_game_state()

	GameManager.ai_resources["wood"] = 200
	GameManager.ai_resources["gold"] = 200

	var rule = AIRules.TrainArcherRule.new()
	var should_fire = rule.conditions(gs)

	if should_fire:
		return Assertions.AssertResult.new(false,
			"TrainArcherRule should not fire without archery range")

	return Assertions.AssertResult.new(true)


func test_train_archer_respects_ranged_cap() -> Assertions.AssertResult:
	## TrainArcherRule has a cap: max(3, infantry+2)
	var gs = _create_ai_game_state()

	runner.spawner.spawn_archery_range(Vector2(600, 600), 1)
	runner.spawner.spawn_house(Vector2(500, 500), 1)
	# Spawn 4 archers (already at cap with 0 infantry: max(3, 0+2) = 3)
	for i in range(4):
		runner.spawner.spawn_archer(Vector2(700 + i * 50, 700), 1)
	await runner.wait_frames(2)

	GameManager.ai_resources["wood"] = 200
	GameManager.ai_resources["gold"] = 200

	var rule = AIRules.TrainArcherRule.new()
	var should_fire = rule.conditions(gs)

	if should_fire:
		var ranged = gs.get_unit_count("ranged")
		var infantry = gs.get_unit_count("infantry")
		return Assertions.AssertResult.new(false,
			"TrainArcherRule should not fire when at ranged cap. ranged=%d, infantry=%d, cap=%d" % [
				ranged, infantry, max(3, infantry + 2)])

	return Assertions.AssertResult.new(true)


func test_train_skirmisher_requires_enemy_archers() -> Assertions.AssertResult:
	## TrainSkirmisherRule should only fire when enemy has archers (counter unit)
	var gs = _create_ai_game_state()

	runner.spawner.spawn_archery_range(Vector2(600, 600), 1)
	runner.spawner.spawn_house(Vector2(500, 500), 1)
	# Spawn enemy archers
	runner.spawner.spawn_archer(Vector2(800, 800), 0)
	await runner.wait_frames(2)

	GameManager.ai_resources["food"] = 200
	GameManager.ai_resources["wood"] = 200

	var rule = AIRules.TrainSkirmisherRule.new()
	var should_fire = rule.conditions(gs)

	if not should_fire:
		var enemy_arch = gs.get_enemy_archer_count()
		var can_train = gs.can_train("skirmisher")
		return Assertions.AssertResult.new(false,
			"TrainSkirmisherRule should fire when enemy has archers. Debug: enemy_arch=%d, can_train=%s" % [
				enemy_arch, str(can_train)])

	return Assertions.AssertResult.new(true)


func test_train_skirmisher_doesnt_fire_without_archers() -> Assertions.AssertResult:
	## TrainSkirmisherRule should NOT fire when enemy has no archers
	var gs = _create_ai_game_state()

	runner.spawner.spawn_archery_range(Vector2(600, 600), 1)
	runner.spawner.spawn_house(Vector2(500, 500), 1)
	# Spawn enemy infantry only (no archers)
	runner.spawner.spawn_militia(Vector2(800, 800), 0)
	await runner.wait_frames(2)

	GameManager.ai_resources["food"] = 200
	GameManager.ai_resources["wood"] = 200

	var rule = AIRules.TrainSkirmisherRule.new()
	var should_fire = rule.conditions(gs)

	if should_fire:
		return Assertions.AssertResult.new(false,
			"TrainSkirmisherRule should NOT fire when enemy has no archers")

	return Assertions.AssertResult.new(true)


func test_train_scout_cavalry_requires_stable() -> Assertions.AssertResult:
	## TrainScoutCavalryRule should not fire without stable
	var gs = _create_ai_game_state()

	GameManager.ai_resources["food"] = 200

	var rule = AIRules.TrainScoutCavalryRule.new()
	var should_fire = rule.conditions(gs)

	if should_fire:
		return Assertions.AssertResult.new(false,
			"TrainScoutCavalryRule should not fire without stable")

	return Assertions.AssertResult.new(true)


func test_train_scout_cavalry_first_always_trains() -> Assertions.AssertResult:
	## TrainScoutCavalryRule always trains first scout (for scouting)
	var gs = _create_ai_game_state()

	runner.spawner.spawn_stable(Vector2(600, 600), 1)
	runner.spawner.spawn_house(Vector2(500, 500), 1)
	await runner.wait_frames(2)

	GameManager.ai_resources["food"] = 80  # Just enough for 1 scout

	var rule = AIRules.TrainScoutCavalryRule.new()
	var should_fire = rule.conditions(gs)

	if not should_fire:
		var scout_count = gs.get_unit_count("scout_cavalry")
		var can_train = gs.can_train("scout_cavalry")
		var reason = gs.get_can_train_reason("scout_cavalry")
		return Assertions.AssertResult.new(false,
			"TrainScoutCavalryRule should always train first scout. scouts=%d, can_train=%s, reason=%s" % [
				scout_count, str(can_train), reason])

	return Assertions.AssertResult.new(true)


func test_train_scout_cavalry_caps_at_three() -> Assertions.AssertResult:
	## TrainScoutCavalryRule should not train more than 3 scouts
	var gs = _create_ai_game_state()

	runner.spawner.spawn_stable(Vector2(600, 600), 1)
	runner.spawner.spawn_house(Vector2(500, 500), 1)
	runner.spawner.spawn_house(Vector2(500, 600), 1)  # More pop cap
	# Spawn 3 scouts
	for i in range(3):
		runner.spawner.spawn_scout_cavalry(Vector2(700 + i * 50, 700), 1)
	await runner.wait_frames(2)

	GameManager.ai_resources["food"] = 200

	var rule = AIRules.TrainScoutCavalryRule.new()
	var should_fire = rule.conditions(gs)

	if should_fire:
		return Assertions.AssertResult.new(false,
			"TrainScoutCavalryRule should not train more than 3 scouts")

	return Assertions.AssertResult.new(true)


func test_train_cavalry_archer_requires_stable() -> Assertions.AssertResult:
	## TrainCavalryArcherRule trains from stable (not archery range)
	var gs = _create_ai_game_state()

	# Spawn archery range but NOT stable
	runner.spawner.spawn_archery_range(Vector2(600, 600), 1)
	await runner.wait_frames(2)

	GameManager.ai_resources["wood"] = 200
	GameManager.ai_resources["gold"] = 200

	var rule = AIRules.TrainCavalryArcherRule.new()
	var should_fire = rule.conditions(gs)

	if should_fire:
		return Assertions.AssertResult.new(false,
			"TrainCavalryArcherRule should require stable (not just archery range)")

	return Assertions.AssertResult.new(true)


func test_train_cavalry_archer_requires_gold() -> Assertions.AssertResult:
	## TrainCavalryArcherRule requires gold > 150
	var gs = _create_ai_game_state()

	runner.spawner.spawn_stable(Vector2(600, 600), 1)
	runner.spawner.spawn_house(Vector2(500, 500), 1)
	# Some military for the 3+ requirement
	for i in range(3):
		runner.spawner.spawn_militia(Vector2(700 + i * 50, 700), 1)
	await runner.wait_frames(2)

	GameManager.ai_resources["wood"] = 200
	GameManager.ai_resources["gold"] = 100  # Below 150 threshold

	var rule = AIRules.TrainCavalryArcherRule.new()
	var should_fire = rule.conditions(gs)

	if should_fire:
		return Assertions.AssertResult.new(false,
			"TrainCavalryArcherRule should not fire when gold < 150")

	return Assertions.AssertResult.new(true)


func test_train_cavalry_archer_requires_military() -> Assertions.AssertResult:
	## TrainCavalryArcherRule requires 3+ military
	var gs = _create_ai_game_state()

	runner.spawner.spawn_stable(Vector2(600, 600), 1)
	runner.spawner.spawn_house(Vector2(500, 500), 1)
	# Only 2 military (need 3)
	runner.spawner.spawn_militia(Vector2(700, 700), 1)
	runner.spawner.spawn_militia(Vector2(750, 700), 1)
	await runner.wait_frames(2)

	GameManager.ai_resources["wood"] = 200
	GameManager.ai_resources["gold"] = 200

	var rule = AIRules.TrainCavalryArcherRule.new()
	var should_fire = rule.conditions(gs)

	if should_fire:
		var mil_pop = gs.get_military_population()
		return Assertions.AssertResult.new(false,
			"TrainCavalryArcherRule should not fire with only %d military (need 3+)" % mil_pop)

	return Assertions.AssertResult.new(true)


# =============================================================================
# Defense Rule Tests
# =============================================================================

func test_defend_base_fires_when_under_attack() -> Assertions.AssertResult:
	## DefendBaseRule should fire when under attack with military
	var gs = _create_ai_game_state()

	# AI building (Town Center)
	runner.spawner.spawn_town_center(Vector2(600, 600), 1)
	# AI military
	runner.spawner.spawn_militia(Vector2(650, 600), 1)
	# Enemy unit near AI building (within 300px threat distance)
	runner.spawner.spawn_militia(Vector2(700, 600), 0)
	await runner.wait_frames(2)

	var rule = AIRules.DefendBaseRule.new()
	var should_fire = rule.conditions(gs)

	if not should_fire:
		var under_attack = gs.is_under_attack()
		var mil_pop = gs.get_military_population()
		return Assertions.AssertResult.new(false,
			"DefendBaseRule should fire when under attack. under_attack=%s, military=%d" % [
				str(under_attack), mil_pop])

	return Assertions.AssertResult.new(true)


func test_defend_base_requires_military() -> Assertions.AssertResult:
	## DefendBaseRule should not fire without military to defend with
	var gs = _create_ai_game_state()

	# AI building
	runner.spawner.spawn_town_center(Vector2(600, 600), 1)
	# Enemy nearby (under attack)
	runner.spawner.spawn_militia(Vector2(700, 600), 0)
	# No AI military
	await runner.wait_frames(2)

	var rule = AIRules.DefendBaseRule.new()
	var should_fire = rule.conditions(gs)

	if should_fire:
		return Assertions.AssertResult.new(false,
			"DefendBaseRule should not fire without military to defend")

	return Assertions.AssertResult.new(true)


func test_is_under_attack_detects_nearby_enemy() -> Assertions.AssertResult:
	## is_under_attack should detect enemy military near AI buildings
	var gs = _create_ai_game_state()

	# AI building
	runner.spawner.spawn_barracks(Vector2(600, 600), 1)
	# Enemy very close (within 300px)
	runner.spawner.spawn_militia(Vector2(650, 600), 0)
	await runner.wait_frames(2)

	var under_attack = gs.is_under_attack()

	if not under_attack:
		return Assertions.AssertResult.new(false,
			"is_under_attack should return true when enemy is 50px from building")

	return Assertions.AssertResult.new(true)


func test_is_under_attack_ignores_distant_enemy() -> Assertions.AssertResult:
	## is_under_attack should NOT detect enemy military far from AI buildings
	var gs = _create_ai_game_state()

	# AI building
	runner.spawner.spawn_barracks(Vector2(600, 600), 1)
	# Enemy far away (> 300px)
	runner.spawner.spawn_militia(Vector2(1000, 600), 0)  # 400px away
	await runner.wait_frames(2)

	var under_attack = gs.is_under_attack()

	if under_attack:
		return Assertions.AssertResult.new(false,
			"is_under_attack should return false when enemy is 400px from building")

	return Assertions.AssertResult.new(true)


func test_get_nearest_threat_returns_closest() -> Assertions.AssertResult:
	## get_nearest_threat should return the closest enemy to AI base
	var gs = _create_ai_game_state()

	# AI TC establishes base position
	runner.spawner.spawn_town_center(Vector2(600, 600), 1)
	# Far enemy threat
	var far_enemy = runner.spawner.spawn_militia(Vector2(850, 600), 0)  # 250px
	# Near enemy threat
	var near_enemy = runner.spawner.spawn_militia(Vector2(700, 600), 0)  # 100px
	await runner.wait_frames(2)

	var threat = gs.get_nearest_threat()

	if threat != near_enemy:
		return Assertions.AssertResult.new(false,
			"get_nearest_threat should return the closest enemy")

	return Assertions.AssertResult.new(true)


# =============================================================================
# Scouting Rule Tests
# =============================================================================

func test_scouting_rule_requires_idle_scout() -> Assertions.AssertResult:
	## ScoutingRule should only fire when there's an idle scout
	var gs = _create_ai_game_state()

	# Spawn a scout that's not idle (moving)
	var scout = runner.spawner.spawn_scout_cavalry(Vector2(600, 600), 1)
	await runner.wait_frames(2)
	scout.move_to(Vector2(800, 800))  # Make it move (not idle)
	await runner.wait_frames(2)

	var rule = AIRules.ScoutingRule.new()
	var should_fire = rule.conditions(gs)

	if should_fire:
		return Assertions.AssertResult.new(false,
			"ScoutingRule should not fire when scout is moving")

	return Assertions.AssertResult.new(true)


func test_get_idle_scout_returns_idle() -> Assertions.AssertResult:
	## get_idle_scout should return an idle scout
	var gs = _create_ai_game_state()

	var scout = runner.spawner.spawn_scout_cavalry(Vector2(600, 600), 1)
	await runner.wait_frames(2)

	# Ensure scout is idle (may have auto-aggro'd if enemies nearby)
	scout.current_state = scout.State.IDLE
	scout.attack_target = null
	await runner.wait_frames(1)

	var result = gs.get_idle_scout()

	if result != scout:
		var state_name = scout.State.keys()[scout.current_state]
		return Assertions.AssertResult.new(false,
			"get_idle_scout should return the idle scout. Scout state: %s" % state_name)

	return Assertions.AssertResult.new(true)


func test_get_idle_scout_excludes_moving() -> Assertions.AssertResult:
	## get_idle_scout should return null when scout is moving
	var gs = _create_ai_game_state()

	var scout = runner.spawner.spawn_scout_cavalry(Vector2(600, 600), 1)
	await runner.wait_frames(2)

	# Make scout move
	scout.move_to(Vector2(800, 800))
	await runner.wait_frames(2)

	var result = gs.get_idle_scout()

	# Scout is moving, so should return null (or different idle scout)
	if result == scout and scout.current_state != scout.State.IDLE:
		return Assertions.AssertResult.new(false,
			"get_idle_scout should not return a moving scout")

	return Assertions.AssertResult.new(true)


func test_scout_targets_cycle() -> Assertions.AssertResult:
	## ScoutingRule should cycle through targets
	var rule = AIRules.ScoutingRule.new()

	# Check that scout targets are defined
	if rule._scout_targets.is_empty():
		return Assertions.AssertResult.new(false,
			"ScoutingRule should have predefined scout targets")

	# Check that target index cycles
	var initial_index = rule._current_target_index
	var num_targets = rule._scout_targets.size()

	# Simulate multiple actions (without actual gs)
	for i in range(num_targets + 1):
		rule._current_target_index = (rule._current_target_index + 1) % num_targets

	# After cycling through all targets + 1, should be back to initial + 1
	var expected_index = (initial_index + num_targets + 1) % num_targets

	if rule._current_target_index != expected_index:
		return Assertions.AssertResult.new(false,
			"Scout targets should cycle. Expected index %d, got %d" % [
				expected_index, rule._current_target_index])

	return Assertions.AssertResult.new(true)
