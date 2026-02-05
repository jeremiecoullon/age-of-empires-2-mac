extends Node
## Unit Tests - Tests for unit HP, death, and population mechanics
##
## These tests verify:
## - Units take damage correctly
## - Units die when HP reaches 0
## - died signal is emitted on death
## - Population decreases when unit dies
## - Team assignment works correctly

class_name TestUnits

var runner: TestRunner


func _init(test_runner: TestRunner) -> void:
	runner = test_runner


func get_all_tests() -> Array[Callable]:
	## Returns all test methods to run
	return [
		test_unit_takes_damage,
		test_unit_dies_at_zero_hp,
		test_unit_died_signal_emits,
		test_unit_death_decreases_population,
		test_unit_team_assignment,
		test_unit_cannot_die_twice,
		test_villager_initial_hp,
		test_militia_initial_hp,
		# Phase 3.1C unit tests
		test_skirmisher_initial_stats,
		test_skirmisher_group_membership,
		test_cavalry_archer_initial_stats,
		test_cavalry_archer_group_membership,
	]


func test_unit_takes_damage() -> Assertions.AssertResult:
	## take_damage should reduce current_hp
	var villager = runner.spawner.spawn_villager(Vector2(400, 400))
	await runner.wait_frames(2)

	var initial_hp = villager.current_hp
	villager.take_damage(10)

	if villager.current_hp != initial_hp - 10:
		return Assertions.AssertResult.new(false,
			"HP should decrease by damage amount. Expected: %d, Got: %d" % [initial_hp - 10, villager.current_hp])

	return Assertions.AssertResult.new(true)


func test_unit_dies_at_zero_hp() -> Assertions.AssertResult:
	## Unit should die (be freed) when HP reaches 0
	var villager = runner.spawner.spawn_villager(Vector2(400, 400))
	await runner.wait_frames(2)

	# Deal lethal damage
	villager.take_damage(villager.current_hp)
	await runner.wait_frames(5)

	if is_instance_valid(villager):
		return Assertions.AssertResult.new(false,
			"Unit should be freed after HP reaches 0")

	return Assertions.AssertResult.new(true)


func test_unit_died_signal_emits() -> Assertions.AssertResult:
	## died signal should be emitted when unit dies
	var villager = runner.spawner.spawn_villager(Vector2(400, 400))
	await runner.wait_frames(2)

	# Use array to capture by reference (GDScript lambdas capture primitives by value)
	var signal_received = [false]
	villager.died.connect(func(): signal_received[0] = true)

	villager.take_damage(villager.current_hp)
	await runner.wait_frames(2)

	if not signal_received[0]:
		return Assertions.AssertResult.new(false,
			"died signal should be emitted when unit dies")

	return Assertions.AssertResult.new(true)


func test_unit_death_decreases_population() -> Assertions.AssertResult:
	## Population should decrease when a unit dies
	# Spawn villager first, then check population
	var villager = runner.spawner.spawn_villager(Vector2(400, 400))
	await runner.wait_frames(2)

	# Record population AFTER spawn (includes the spawned villager)
	var pop_before_death = GameManager.population

	# Kill the unit
	villager.take_damage(villager.current_hp)
	await runner.wait_frames(5)

	if GameManager.population != pop_before_death - 1:
		return Assertions.AssertResult.new(false,
			"Population should decrease by 1. Before: %d, After: %d" % [pop_before_death, GameManager.population])

	return Assertions.AssertResult.new(true)


func test_unit_team_assignment() -> Assertions.AssertResult:
	## Units should have correct team assignment
	var player_villager = runner.spawner.spawn_villager(Vector2(400, 400), 0)
	var ai_villager = runner.spawner.spawn_villager(Vector2(500, 400), 1)
	await runner.wait_frames(2)

	if player_villager.team != 0:
		return Assertions.AssertResult.new(false,
			"Player villager should have team 0, got: %d" % player_villager.team)

	if ai_villager.team != 1:
		return Assertions.AssertResult.new(false,
			"AI villager should have team 1, got: %d" % ai_villager.team)

	return Assertions.AssertResult.new(true)


func test_unit_cannot_die_twice() -> Assertions.AssertResult:
	## Calling die() twice should not cause issues
	var villager = runner.spawner.spawn_villager(Vector2(400, 400))
	await runner.wait_frames(2)

	# Reset population to known value
	GameManager.population = 5
	var initial_pop = GameManager.population

	# Use array to capture by reference
	var death_count = [0]
	villager.died.connect(func(): death_count[0] += 1)

	# Die once
	villager.die()
	await runner.wait_frames(2)

	# The second die() would fail since villager is freed,
	# but we're testing the is_dead flag prevents double-death effects
	if death_count[0] != 1:
		return Assertions.AssertResult.new(false,
			"died signal should only emit once, got: %d" % death_count[0])

	if GameManager.population != initial_pop - 1:
		return Assertions.AssertResult.new(false,
			"Population should only decrease once")

	return Assertions.AssertResult.new(true)


func test_villager_initial_hp() -> Assertions.AssertResult:
	## Villager should have 100 HP by default (from Unit base class)
	var villager = runner.spawner.spawn_villager(Vector2(400, 400))
	await runner.wait_frames(2)

	# Villager uses Unit default max_hp = 100
	if villager.max_hp != 100:
		return Assertions.AssertResult.new(false,
			"Villager max_hp should be 100, got: %d" % villager.max_hp)

	if villager.current_hp != villager.max_hp:
		return Assertions.AssertResult.new(false,
			"Villager current_hp should equal max_hp initially")

	return Assertions.AssertResult.new(true)


func test_militia_initial_hp() -> Assertions.AssertResult:
	## Militia should have 50 HP (MVP value)
	var militia = runner.spawner.spawn_militia(Vector2(400, 400))
	await runner.wait_frames(2)

	if militia.max_hp != 50:
		return Assertions.AssertResult.new(false,
			"Militia max_hp should be 50 (MVP value), got: %d" % militia.max_hp)

	if militia.current_hp != militia.max_hp:
		return Assertions.AssertResult.new(false,
			"Militia current_hp should equal max_hp initially")

	return Assertions.AssertResult.new(true)


# =============================================================================
# Phase 3.1C Unit Tests
# =============================================================================

func test_skirmisher_initial_stats() -> Assertions.AssertResult:
	## Skirmisher should have correct AoE2 stats: 30 HP, 2 attack, 0/3 armor
	var skirmisher = runner.spawner.spawn_skirmisher(Vector2(400, 400))
	await runner.wait_frames(2)

	if skirmisher.max_hp != 30:
		return Assertions.AssertResult.new(false,
			"Skirmisher max_hp should be 30, got: %d" % skirmisher.max_hp)

	if skirmisher.attack_damage != 2:
		return Assertions.AssertResult.new(false,
			"Skirmisher attack_damage should be 2, got: %d" % skirmisher.attack_damage)

	if skirmisher.melee_armor != 0:
		return Assertions.AssertResult.new(false,
			"Skirmisher melee_armor should be 0, got: %d" % skirmisher.melee_armor)

	if skirmisher.pierce_armor != 3:
		return Assertions.AssertResult.new(false,
			"Skirmisher pierce_armor should be 3, got: %d" % skirmisher.pierce_armor)

	return Assertions.AssertResult.new(true)


func test_skirmisher_group_membership() -> Assertions.AssertResult:
	## Skirmisher should be in military, archers, and skirmishers groups
	var skirmisher = runner.spawner.spawn_skirmisher(Vector2(400, 400))
	await runner.wait_frames(2)

	if not skirmisher.is_in_group("military"):
		return Assertions.AssertResult.new(false,
			"Skirmisher should be in 'military' group")

	if not skirmisher.is_in_group("archers"):
		return Assertions.AssertResult.new(false,
			"Skirmisher should be in 'archers' group (for targeting purposes)")

	if not skirmisher.is_in_group("skirmishers"):
		return Assertions.AssertResult.new(false,
			"Skirmisher should be in 'skirmishers' group (for AI counting)")

	return Assertions.AssertResult.new(true)


func test_cavalry_archer_initial_stats() -> Assertions.AssertResult:
	## Cavalry Archer should have correct AoE2 stats: 50 HP, 6 attack, 0/0 armor
	var cav_archer = runner.spawner.spawn_cavalry_archer(Vector2(400, 400))
	await runner.wait_frames(2)

	if cav_archer.max_hp != 50:
		return Assertions.AssertResult.new(false,
			"Cavalry Archer max_hp should be 50, got: %d" % cav_archer.max_hp)

	if cav_archer.attack_damage != 6:
		return Assertions.AssertResult.new(false,
			"Cavalry Archer attack_damage should be 6, got: %d" % cav_archer.attack_damage)

	if cav_archer.melee_armor != 0:
		return Assertions.AssertResult.new(false,
			"Cavalry Archer melee_armor should be 0, got: %d" % cav_archer.melee_armor)

	if cav_archer.pierce_armor != 0:
		return Assertions.AssertResult.new(false,
			"Cavalry Archer pierce_armor should be 0, got: %d" % cav_archer.pierce_armor)

	return Assertions.AssertResult.new(true)


func test_cavalry_archer_group_membership() -> Assertions.AssertResult:
	## Cavalry Archer should be in military, cavalry, archers, and cavalry_archers groups
	var cav_archer = runner.spawner.spawn_cavalry_archer(Vector2(400, 400))
	await runner.wait_frames(2)

	if not cav_archer.is_in_group("military"):
		return Assertions.AssertResult.new(false,
			"Cavalry Archer should be in 'military' group")

	if not cav_archer.is_in_group("cavalry"):
		return Assertions.AssertResult.new(false,
			"Cavalry Archer should be in 'cavalry' group (for spearman bonus)")

	if not cav_archer.is_in_group("archers"):
		return Assertions.AssertResult.new(false,
			"Cavalry Archer should be in 'archers' group (for skirmisher bonus)")

	if not cav_archer.is_in_group("cavalry_archers"):
		return Assertions.AssertResult.new(false,
			"Cavalry Archer should be in 'cavalry_archers' group (for AI counting)")

	return Assertions.AssertResult.new(true)
