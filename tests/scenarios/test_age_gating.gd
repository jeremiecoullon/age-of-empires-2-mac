extends Node
## Age Gating Tests - Tests for Phase 4B Age-Gating + Visual Changes
##
## These tests verify:
## - GameManager.is_building_unlocked(): Dark/Feudal buildings gated by age
## - GameManager.is_unit_unlocked(): Dark/Feudal/Castle units gated by age
## - GameManager.get_required_age_name(): returns correct age names for entities
## - AI get_can_train_reason() age gating: returns "requires_feudal_age" / "requires_castle_age"
## - AI get_can_build_reason() age gating: returns "requires_feudal_age" for locked buildings
## - Starting population: 4 on init and after reset (3 villagers + 1 scout)
## - Team independence: player and AI ages are checked independently

class_name TestAgeGating

var runner: TestRunner


func _init(test_runner: TestRunner) -> void:
	runner = test_runner


func get_all_tests() -> Array[Callable]:
	## Returns all test methods to run
	return [
		# GameManager.is_building_unlocked tests
		test_dark_age_buildings_unlocked_in_dark_age,
		test_feudal_buildings_locked_in_dark_age,
		test_feudal_buildings_unlocked_in_feudal_age,
		test_feudal_buildings_unlocked_in_castle_age,
		test_building_unlock_checks_correct_team,
		# GameManager.is_unit_unlocked tests
		test_dark_age_units_unlocked_in_dark_age,
		test_feudal_units_locked_in_dark_age,
		test_feudal_units_unlocked_in_feudal_age,
		test_castle_units_locked_in_dark_age,
		test_castle_units_locked_in_feudal_age,
		test_castle_units_unlocked_in_castle_age,
		test_unit_unlock_checks_correct_team,
		# GameManager.get_required_age_name tests
		test_get_required_age_name_dark_age_building,
		test_get_required_age_name_feudal_building,
		test_get_required_age_name_dark_age_unit,
		test_get_required_age_name_feudal_unit,
		test_get_required_age_name_castle_unit,
		# Starting population tests
		test_starting_population_is_four,
		test_reset_population_is_four,
		# AI get_can_train_reason age gating tests
		test_ai_cant_train_feudal_unit_in_dark_age,
		test_ai_cant_train_castle_unit_in_feudal_age,
		test_ai_can_train_feudal_unit_in_feudal_age,
		test_ai_cant_train_castle_unit_in_dark_age,
		test_ai_train_reason_format_feudal,
		test_ai_train_reason_format_castle,
		# AI get_can_build_reason age gating tests
		test_ai_cant_build_feudal_building_in_dark_age,
		test_ai_can_build_feudal_building_in_feudal_age,
		test_ai_build_reason_format_feudal,
		# Unlisted entities default to Dark Age
		test_unlisted_building_defaults_to_dark_age,
		test_unlisted_unit_defaults_to_dark_age,
	]


# =============================================================================
# Mock AI Controller (same pattern as test_ai_military.gd)
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
# GameManager.is_building_unlocked Tests
# =============================================================================

func test_dark_age_buildings_unlocked_in_dark_age() -> Assertions.AssertResult:
	## Buildings with no age requirement (house, barracks, farm, mill, etc) should be unlocked in Dark Age
	var dark_buildings = ["house", "barracks", "farm", "mill", "lumber_camp", "mining_camp"]

	for building_type in dark_buildings:
		if not GameManager.is_building_unlocked(building_type, 0):
			return Assertions.AssertResult.new(false,
				"%s should be unlocked in Dark Age" % building_type)

	return Assertions.AssertResult.new(true)


func test_feudal_buildings_locked_in_dark_age() -> Assertions.AssertResult:
	## Archery range, stable, and market should be locked in Dark Age
	var feudal_buildings = ["archery_range", "stable", "market"]

	for building_type in feudal_buildings:
		if GameManager.is_building_unlocked(building_type, 0):
			return Assertions.AssertResult.new(false,
				"%s should be locked in Dark Age" % building_type)

	return Assertions.AssertResult.new(true)


func test_feudal_buildings_unlocked_in_feudal_age() -> Assertions.AssertResult:
	## Feudal buildings should be unlocked once in Feudal Age
	GameManager.set_age(GameManager.AGE_FEUDAL, 0)

	var feudal_buildings = ["archery_range", "stable", "market"]

	for building_type in feudal_buildings:
		if not GameManager.is_building_unlocked(building_type, 0):
			return Assertions.AssertResult.new(false,
				"%s should be unlocked in Feudal Age" % building_type)

	return Assertions.AssertResult.new(true)


func test_feudal_buildings_unlocked_in_castle_age() -> Assertions.AssertResult:
	## Feudal buildings should remain unlocked in Castle Age (>= check)
	GameManager.set_age(GameManager.AGE_CASTLE, 0)

	var feudal_buildings = ["archery_range", "stable", "market"]

	for building_type in feudal_buildings:
		if not GameManager.is_building_unlocked(building_type, 0):
			return Assertions.AssertResult.new(false,
				"%s should still be unlocked in Castle Age" % building_type)

	return Assertions.AssertResult.new(true)


func test_building_unlock_checks_correct_team() -> Assertions.AssertResult:
	## Building unlock should check the correct team's age
	# Player is in Dark Age, AI is in Feudal Age
	GameManager.set_age(GameManager.AGE_DARK, 0)
	GameManager.set_age(GameManager.AGE_FEUDAL, 1)

	# Player should NOT have archery range unlocked
	if GameManager.is_building_unlocked("archery_range", 0):
		return Assertions.AssertResult.new(false,
			"Player should not have archery_range unlocked in Dark Age")

	# AI SHOULD have archery range unlocked
	if not GameManager.is_building_unlocked("archery_range", 1):
		return Assertions.AssertResult.new(false,
			"AI should have archery_range unlocked in Feudal Age")

	return Assertions.AssertResult.new(true)


# =============================================================================
# GameManager.is_unit_unlocked Tests
# =============================================================================

func test_dark_age_units_unlocked_in_dark_age() -> Assertions.AssertResult:
	## Villager and militia should be available in Dark Age
	var dark_units = ["villager", "militia"]

	for unit_type in dark_units:
		if not GameManager.is_unit_unlocked(unit_type, 0):
			return Assertions.AssertResult.new(false,
				"%s should be unlocked in Dark Age" % unit_type)

	return Assertions.AssertResult.new(true)


func test_feudal_units_locked_in_dark_age() -> Assertions.AssertResult:
	## Feudal units should be locked in Dark Age
	var feudal_units = ["archer", "skirmisher", "spearman", "scout_cavalry", "trade_cart"]

	for unit_type in feudal_units:
		if GameManager.is_unit_unlocked(unit_type, 0):
			return Assertions.AssertResult.new(false,
				"%s should be locked in Dark Age" % unit_type)

	return Assertions.AssertResult.new(true)


func test_feudal_units_unlocked_in_feudal_age() -> Assertions.AssertResult:
	## Feudal units should be unlocked in Feudal Age
	GameManager.set_age(GameManager.AGE_FEUDAL, 0)

	var feudal_units = ["archer", "skirmisher", "spearman", "scout_cavalry", "trade_cart"]

	for unit_type in feudal_units:
		if not GameManager.is_unit_unlocked(unit_type, 0):
			return Assertions.AssertResult.new(false,
				"%s should be unlocked in Feudal Age" % unit_type)

	return Assertions.AssertResult.new(true)


func test_castle_units_locked_in_dark_age() -> Assertions.AssertResult:
	## Cavalry archer should be locked in Dark Age
	if GameManager.is_unit_unlocked("cavalry_archer", 0):
		return Assertions.AssertResult.new(false,
			"cavalry_archer should be locked in Dark Age")

	return Assertions.AssertResult.new(true)


func test_castle_units_locked_in_feudal_age() -> Assertions.AssertResult:
	## Cavalry archer should still be locked in Feudal Age
	GameManager.set_age(GameManager.AGE_FEUDAL, 0)

	if GameManager.is_unit_unlocked("cavalry_archer", 0):
		return Assertions.AssertResult.new(false,
			"cavalry_archer should be locked in Feudal Age")

	return Assertions.AssertResult.new(true)


func test_castle_units_unlocked_in_castle_age() -> Assertions.AssertResult:
	## Cavalry archer should be unlocked in Castle Age
	GameManager.set_age(GameManager.AGE_CASTLE, 0)

	if not GameManager.is_unit_unlocked("cavalry_archer", 0):
		return Assertions.AssertResult.new(false,
			"cavalry_archer should be unlocked in Castle Age")

	return Assertions.AssertResult.new(true)


func test_unit_unlock_checks_correct_team() -> Assertions.AssertResult:
	## Unit unlock should check the correct team's age
	# Player is in Feudal, AI is in Dark
	GameManager.set_age(GameManager.AGE_FEUDAL, 0)
	GameManager.set_age(GameManager.AGE_DARK, 1)

	# Player should have archer unlocked
	if not GameManager.is_unit_unlocked("archer", 0):
		return Assertions.AssertResult.new(false,
			"Player should have archer unlocked in Feudal Age")

	# AI should NOT have archer unlocked
	if GameManager.is_unit_unlocked("archer", 1):
		return Assertions.AssertResult.new(false,
			"AI should not have archer unlocked in Dark Age")

	return Assertions.AssertResult.new(true)


# =============================================================================
# GameManager.get_required_age_name Tests
# =============================================================================

func test_get_required_age_name_dark_age_building() -> Assertions.AssertResult:
	## Buildings not in BUILDING_AGE_REQUIREMENTS should return "Dark Age"
	var name = GameManager.get_required_age_name("house", true)
	if name != "Dark Age":
		return Assertions.AssertResult.new(false,
			"house required age name should be 'Dark Age', got: '%s'" % name)

	return Assertions.AssertResult.new(true)


func test_get_required_age_name_feudal_building() -> Assertions.AssertResult:
	## Feudal buildings should return "Feudal Age"
	var feudal_buildings = ["archery_range", "stable", "market"]

	for building_type in feudal_buildings:
		var name = GameManager.get_required_age_name(building_type, true)
		if name != "Feudal Age":
			return Assertions.AssertResult.new(false,
				"%s required age name should be 'Feudal Age', got: '%s'" % [building_type, name])

	return Assertions.AssertResult.new(true)


func test_get_required_age_name_dark_age_unit() -> Assertions.AssertResult:
	## Units not in UNIT_AGE_REQUIREMENTS should return "Dark Age"
	var name = GameManager.get_required_age_name("villager", false)
	if name != "Dark Age":
		return Assertions.AssertResult.new(false,
			"villager required age name should be 'Dark Age', got: '%s'" % name)

	return Assertions.AssertResult.new(true)


func test_get_required_age_name_feudal_unit() -> Assertions.AssertResult:
	## Feudal units should return "Feudal Age"
	var name = GameManager.get_required_age_name("archer", false)
	if name != "Feudal Age":
		return Assertions.AssertResult.new(false,
			"archer required age name should be 'Feudal Age', got: '%s'" % name)

	return Assertions.AssertResult.new(true)


func test_get_required_age_name_castle_unit() -> Assertions.AssertResult:
	## Castle units should return "Castle Age"
	var name = GameManager.get_required_age_name("cavalry_archer", false)
	if name != "Castle Age":
		return Assertions.AssertResult.new(false,
			"cavalry_archer required age name should be 'Castle Age', got: '%s'" % name)

	return Assertions.AssertResult.new(true)


# =============================================================================
# Starting Population Tests
# =============================================================================

func test_starting_population_is_four() -> Assertions.AssertResult:
	## Population should start at 4 (3 villagers + 1 scout)
	# reset() is called in _before_each, so population should be at starting value
	var pop = GameManager.population
	if pop != 4:
		return Assertions.AssertResult.new(false,
			"Starting population should be 4, got: %d" % pop)

	return Assertions.AssertResult.new(true)


func test_reset_population_is_four() -> Assertions.AssertResult:
	## After explicit reset, population should return to 4
	GameManager.population = 15
	GameManager.reset()

	var pop = GameManager.population
	if pop != 4:
		return Assertions.AssertResult.new(false,
			"Population after reset should be 4, got: %d" % pop)

	return Assertions.AssertResult.new(true)


# =============================================================================
# AI get_can_train_reason Age Gating Tests
# =============================================================================

func test_ai_cant_train_feudal_unit_in_dark_age() -> Assertions.AssertResult:
	## AI should not be able to train Feudal units in Dark Age
	var gs = _create_ai_game_state()

	# AI is in Dark Age (default after reset)
	# Give AI resources and buildings
	GameManager.ai_resources["food"] = 1000
	GameManager.ai_resources["wood"] = 1000
	GameManager.ai_resources["gold"] = 1000
	GameManager.ai_population = 5
	GameManager.ai_population_cap = 30

	# Spawn required buildings (even though they shouldn't be buildable in Dark Age,
	# this tests the training check specifically)
	runner.spawner.spawn_archery_range(Vector2(1600, 1600), 1)
	runner.spawner.spawn_stable(Vector2(1500, 1600), 1)
	runner.spawner.spawn_barracks(Vector2(1400, 1600), 1)
	await runner.wait_frames(2)

	var can_train_archer = gs.can_train("archer")
	var can_train_spearman = gs.can_train("spearman")
	var can_train_scout = gs.can_train("scout_cavalry")

	if can_train_archer:
		return Assertions.AssertResult.new(false,
			"Should not be able to train archer in Dark Age")
	if can_train_spearman:
		return Assertions.AssertResult.new(false,
			"Should not be able to train spearman in Dark Age")
	if can_train_scout:
		return Assertions.AssertResult.new(false,
			"Should not be able to train scout_cavalry in Dark Age")

	return Assertions.AssertResult.new(true)


func test_ai_cant_train_castle_unit_in_feudal_age() -> Assertions.AssertResult:
	## AI should not be able to train Castle units in Feudal Age
	var gs = _create_ai_game_state()

	GameManager.set_age(GameManager.AGE_FEUDAL, 1)
	GameManager.ai_resources["wood"] = 1000
	GameManager.ai_resources["gold"] = 1000
	GameManager.ai_population = 5
	GameManager.ai_population_cap = 30

	runner.spawner.spawn_stable(Vector2(1500, 1600), 1)
	await runner.wait_frames(2)

	var can_train = gs.can_train("cavalry_archer")
	if can_train:
		return Assertions.AssertResult.new(false,
			"Should not be able to train cavalry_archer in Feudal Age")

	return Assertions.AssertResult.new(true)


func test_ai_can_train_feudal_unit_in_feudal_age() -> Assertions.AssertResult:
	## AI should be able to train Feudal units once in Feudal Age (given other conditions met)
	var gs = _create_ai_game_state()

	GameManager.set_age(GameManager.AGE_FEUDAL, 1)
	GameManager.ai_resources["wood"] = 1000
	GameManager.ai_resources["gold"] = 1000
	GameManager.ai_resources["food"] = 1000
	GameManager.ai_population = 5
	GameManager.ai_population_cap = 30

	runner.spawner.spawn_archery_range(Vector2(1600, 1600), 1)
	runner.spawner.spawn_house(Vector2(1500, 1500), 1)
	await runner.wait_frames(2)

	var can_train_archer = gs.can_train("archer")
	if not can_train_archer:
		var reason = gs.get_can_train_reason("archer")
		return Assertions.AssertResult.new(false,
			"Should be able to train archer in Feudal Age, reason: %s" % reason)

	return Assertions.AssertResult.new(true)


func test_ai_cant_train_castle_unit_in_dark_age() -> Assertions.AssertResult:
	## Cavalry archer should not be trainable in Dark Age
	var gs = _create_ai_game_state()

	# AI in Dark Age
	GameManager.ai_resources["wood"] = 1000
	GameManager.ai_resources["gold"] = 1000
	GameManager.ai_population = 5
	GameManager.ai_population_cap = 30

	runner.spawner.spawn_stable(Vector2(1500, 1600), 1)
	await runner.wait_frames(2)

	var reason = gs.get_can_train_reason("cavalry_archer")
	if not reason.begins_with("requires_"):
		return Assertions.AssertResult.new(false,
			"cavalry_archer in Dark Age should return requires_* reason, got: %s" % reason)

	return Assertions.AssertResult.new(true)


func test_ai_train_reason_format_feudal() -> Assertions.AssertResult:
	## get_can_train_reason should return "requires_feudal_age" for Feudal units in Dark Age
	var gs = _create_ai_game_state()

	GameManager.ai_resources["food"] = 1000
	GameManager.ai_resources["wood"] = 1000
	GameManager.ai_resources["gold"] = 1000
	GameManager.ai_population = 5
	GameManager.ai_population_cap = 30

	runner.spawner.spawn_archery_range(Vector2(1600, 1600), 1)
	runner.spawner.spawn_barracks(Vector2(1500, 1600), 1)
	runner.spawner.spawn_stable(Vector2(1400, 1600), 1)
	await runner.wait_frames(2)

	# Test several Feudal units
	var feudal_units = ["archer", "spearman", "scout_cavalry", "skirmisher"]
	for unit_type in feudal_units:
		var reason = gs.get_can_train_reason(unit_type)
		if reason != "requires_feudal_age":
			return Assertions.AssertResult.new(false,
				"%s reason should be 'requires_feudal_age', got: '%s'" % [unit_type, reason])

	return Assertions.AssertResult.new(true)


func test_ai_train_reason_format_castle() -> Assertions.AssertResult:
	## get_can_train_reason should return "requires_castle_age" for Castle units before Castle
	var gs = _create_ai_game_state()

	# In Feudal (not Castle yet)
	GameManager.set_age(GameManager.AGE_FEUDAL, 1)
	GameManager.ai_resources["wood"] = 1000
	GameManager.ai_resources["gold"] = 1000
	GameManager.ai_population = 5
	GameManager.ai_population_cap = 30

	runner.spawner.spawn_stable(Vector2(1500, 1600), 1)
	await runner.wait_frames(2)

	var reason = gs.get_can_train_reason("cavalry_archer")
	if reason != "requires_castle_age":
		return Assertions.AssertResult.new(false,
			"cavalry_archer reason should be 'requires_castle_age', got: '%s'" % reason)

	return Assertions.AssertResult.new(true)


# =============================================================================
# AI get_can_build_reason Age Gating Tests
# =============================================================================

func test_ai_cant_build_feudal_building_in_dark_age() -> Assertions.AssertResult:
	## AI should not be able to build Feudal buildings in Dark Age
	var gs = _create_ai_game_state()

	# AI in Dark Age
	GameManager.ai_resources["wood"] = 1000

	# Spawn an idle villager for the build check
	var v = runner.spawner.spawn_villager(Vector2(1600, 1600), 1)
	v.current_state = Villager.State.IDLE
	await runner.wait_frames(2)

	var feudal_buildings = ["archery_range", "stable", "market"]
	for building_type in feudal_buildings:
		var can_build = gs.can_build(building_type)
		if can_build:
			return Assertions.AssertResult.new(false,
				"Should not be able to build %s in Dark Age" % building_type)

	return Assertions.AssertResult.new(true)


func test_ai_can_build_feudal_building_in_feudal_age() -> Assertions.AssertResult:
	## AI should be able to build Feudal buildings once in Feudal Age
	var gs = _create_ai_game_state()

	GameManager.set_age(GameManager.AGE_FEUDAL, 1)
	GameManager.ai_resources["wood"] = 1000

	# Spawn an idle villager
	var v = runner.spawner.spawn_villager(Vector2(1600, 1600), 1)
	v.current_state = Villager.State.IDLE
	await runner.wait_frames(2)

	var feudal_buildings = ["archery_range", "stable", "market"]
	for building_type in feudal_buildings:
		var can_build = gs.can_build(building_type)
		if not can_build:
			var reason = gs.get_can_build_reason(building_type)
			return Assertions.AssertResult.new(false,
				"Should be able to build %s in Feudal Age, reason: %s" % [building_type, reason])

	return Assertions.AssertResult.new(true)


func test_ai_build_reason_format_feudal() -> Assertions.AssertResult:
	## get_can_build_reason should return "requires_feudal_age" for Feudal buildings in Dark Age
	var gs = _create_ai_game_state()

	GameManager.ai_resources["wood"] = 1000

	var v = runner.spawner.spawn_villager(Vector2(1600, 1600), 1)
	v.current_state = Villager.State.IDLE
	await runner.wait_frames(2)

	var feudal_buildings = ["archery_range", "stable", "market"]
	for building_type in feudal_buildings:
		var reason = gs.get_can_build_reason(building_type)
		if reason != "requires_feudal_age":
			return Assertions.AssertResult.new(false,
				"%s reason should be 'requires_feudal_age', got: '%s'" % [building_type, reason])

	return Assertions.AssertResult.new(true)


# =============================================================================
# Default Age Requirement Tests
# =============================================================================

func test_unlisted_building_defaults_to_dark_age() -> Assertions.AssertResult:
	## Buildings not in BUILDING_AGE_REQUIREMENTS should default to Dark Age (always unlocked)
	# "house" is not in the requirements dict
	var unlocked = GameManager.is_building_unlocked("house", 0)
	if not unlocked:
		return Assertions.AssertResult.new(false,
			"house should default to Dark Age (always unlocked)")

	# Even a completely unknown building type should default to Dark Age
	var unknown_unlocked = GameManager.is_building_unlocked("nonexistent_building", 0)
	if not unknown_unlocked:
		return Assertions.AssertResult.new(false,
			"Unknown building should default to Dark Age (always unlocked)")

	return Assertions.AssertResult.new(true)


func test_unlisted_unit_defaults_to_dark_age() -> Assertions.AssertResult:
	## Units not in UNIT_AGE_REQUIREMENTS should default to Dark Age (always unlocked)
	# "villager" is not in the requirements dict
	var unlocked = GameManager.is_unit_unlocked("villager", 0)
	if not unlocked:
		return Assertions.AssertResult.new(false,
			"villager should default to Dark Age (always unlocked)")

	# Even a completely unknown unit type should default to Dark Age
	var unknown_unlocked = GameManager.is_unit_unlocked("nonexistent_unit", 0)
	if not unknown_unlocked:
		return Assertions.AssertResult.new(false,
			"Unknown unit should default to Dark Age (always unlocked)")

	return Assertions.AssertResult.new(true)
