extends Node
## Combat Tests - Tests for Militia attack mechanics
##
## These tests verify:
## - Militia can attack another unit
## - Militia can attack a building
## - Militia stops attacking when target dies/destroyed
## - Militia state transitions during combat
## - Attack cooldown prevents instant kills

class_name TestCombat

var runner: TestRunner


func _init(test_runner: TestRunner) -> void:
	runner = test_runner


func get_all_tests() -> Array[Callable]:
	## Returns all test methods to run
	return [
		test_militia_command_attack_sets_target,
		test_militia_state_changes_to_attacking,
		test_militia_deals_damage_to_unit,
		test_militia_deals_damage_to_building,
		test_militia_stops_attacking_dead_unit,
		test_militia_stops_attacking_destroyed_building,
		test_militia_attack_cooldown,
		test_militia_chases_out_of_range_target,
	]


func test_militia_command_attack_sets_target() -> Assertions.AssertResult:
	## command_attack should set attack_target and change state
	var attacker = runner.spawner.spawn_militia(Vector2(400, 400))
	var target = runner.spawner.spawn_militia(Vector2(410, 400), 1)  # Enemy
	await runner.wait_frames(2)

	attacker.command_attack(target)
	await runner.wait_frames(2)

	if attacker.attack_target != target:
		return Assertions.AssertResult.new(false,
			"attack_target should be set to target unit")

	return Assertions.assert_militia_state(attacker, Militia.State.ATTACKING)


func test_militia_state_changes_to_attacking() -> Assertions.AssertResult:
	## Militia should transition to ATTACKING state when commanded
	var attacker = runner.spawner.spawn_militia(Vector2(400, 400))
	var target = runner.spawner.spawn_militia(Vector2(410, 400), 1)
	await runner.wait_frames(2)

	# Verify initial state is IDLE
	if attacker.current_state != Militia.State.IDLE:
		return Assertions.AssertResult.new(false,
			"Initial state should be IDLE, got %d" % attacker.current_state)

	attacker.command_attack(target)
	await runner.wait_frames(2)

	return Assertions.assert_militia_state(attacker, Militia.State.ATTACKING)


func test_militia_deals_damage_to_unit() -> Assertions.AssertResult:
	## Militia should deal damage to target unit over time
	var attacker = runner.spawner.spawn_militia(Vector2(400, 400))
	var target = runner.spawner.spawn_militia(Vector2(410, 400), 1)  # Within attack range
	await runner.wait_frames(2)

	var initial_hp = target.current_hp

	attacker.command_attack(target)

	# Wait for attack cooldown (1.0 sec) + generous buffer for CI/headless mode
	# Use 150 frames and exit early if damage dealt
	for i in range(150):
		await runner.wait_frames(1)
		if not is_instance_valid(target):
			break
		if target.current_hp < initial_hp:
			break  # Damage dealt, test can pass

	if not is_instance_valid(target):
		return Assertions.AssertResult.new(false,
			"Target died unexpectedly during test")

	if target.current_hp >= initial_hp:
		return Assertions.AssertResult.new(false,
			"Target HP should decrease. Initial: %d, Current: %d" % [initial_hp, target.current_hp])

	return Assertions.AssertResult.new(true)


func test_militia_deals_damage_to_building() -> Assertions.AssertResult:
	## Militia should be able to attack buildings
	var attacker = runner.spawner.spawn_militia(Vector2(400, 400))
	var target_building = runner.spawner.spawn_house(Vector2(420, 400), 1)  # Enemy building
	await runner.wait_frames(2)

	var initial_hp = target_building.current_hp

	attacker.command_attack(target_building)

	# Wait for attack with generous buffer and early exit
	for i in range(150):
		await runner.wait_frames(1)
		if not is_instance_valid(target_building):
			break
		if target_building.current_hp < initial_hp:
			break  # Damage dealt

	if not is_instance_valid(target_building):
		return Assertions.AssertResult.new(false,
			"Building destroyed unexpectedly during test")

	if target_building.current_hp >= initial_hp:
		return Assertions.AssertResult.new(false,
			"Building HP should decrease. Initial: %d, Current: %d" % [initial_hp, target_building.current_hp])

	return Assertions.AssertResult.new(true)


func test_militia_stops_attacking_dead_unit() -> Assertions.AssertResult:
	## Militia should return to IDLE when target dies
	var attacker = runner.spawner.spawn_militia(Vector2(400, 400))
	var target = runner.spawner.spawn_militia(Vector2(410, 400), 1)
	await runner.wait_frames(2)

	attacker.command_attack(target)
	await runner.wait_frames(2)

	# Kill the target directly
	target.die()
	await runner.wait_frames(5)  # Let state machine process

	if attacker.attack_target != null:
		return Assertions.AssertResult.new(false,
			"attack_target should be null after target dies")

	return Assertions.assert_militia_state(attacker, Militia.State.IDLE)


func test_militia_stops_attacking_destroyed_building() -> Assertions.AssertResult:
	## Militia should return to IDLE when target building is destroyed
	var attacker = runner.spawner.spawn_militia(Vector2(400, 400))
	var target_building = runner.spawner.spawn_house(Vector2(420, 400), 1)
	await runner.wait_frames(2)

	attacker.command_attack(target_building)
	await runner.wait_frames(2)

	# Destroy the building directly
	target_building.take_damage(target_building.current_hp)
	await runner.wait_frames(5)

	if attacker.attack_target != null:
		return Assertions.AssertResult.new(false,
			"attack_target should be null after building destroyed")

	return Assertions.assert_militia_state(attacker, Militia.State.IDLE)


func test_militia_attack_cooldown() -> Assertions.AssertResult:
	## Militia should not attack instantly - must wait for cooldown
	var attacker = runner.spawner.spawn_militia(Vector2(400, 400))
	var target = runner.spawner.spawn_militia(Vector2(410, 400), 1)
	await runner.wait_frames(2)

	var initial_hp = target.current_hp

	attacker.command_attack(target)

	# Verify attack_timer starts at 0 (per militia.gd command_attack)
	if attacker.attack_timer != 0.0:
		return Assertions.AssertResult.new(false,
			"attack_timer should start at 0 after command_attack")

	# Check after just a few frames - no damage yet
	await runner.wait_frames(5)

	# HP should still be full (cooldown hasn't elapsed)
	if target.current_hp != initial_hp:
		return Assertions.AssertResult.new(false,
			"Target should not take damage before cooldown. Initial: %d, Current: %d" % [initial_hp, target.current_hp])

	return Assertions.AssertResult.new(true)


func test_militia_chases_out_of_range_target() -> Assertions.AssertResult:
	## Militia should move toward target if out of attack range
	var attacker = runner.spawner.spawn_militia(Vector2(400, 400))
	var target = runner.spawner.spawn_militia(Vector2(500, 400), 1)  # Out of 30px range
	await runner.wait_frames(2)

	var initial_attacker_pos = attacker.global_position

	attacker.command_attack(target)
	# Let it move for a bit
	for i in range(30):
		await runner.wait_frames(1)

	# Attacker should have moved closer
	var new_distance = attacker.global_position.distance_to(target.global_position)
	var initial_distance = initial_attacker_pos.distance_to(target.global_position)

	if new_distance >= initial_distance:
		return Assertions.AssertResult.new(false,
			"Attacker should move closer to target. Initial dist: %.1f, Current: %.1f" % [initial_distance, new_distance])

	return Assertions.AssertResult.new(true)
