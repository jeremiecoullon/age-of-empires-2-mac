extends Node
## Combat Tests - Tests for Militia and Archer attack mechanics
##
## These tests verify:
## - Militia can attack another unit
## - Militia can attack a building
## - Militia stops attacking when target dies/destroyed
## - Militia state transitions during combat
## - Attack cooldown prevents instant kills
## - Archer ranged attack behavior
## - Archer stats match AoE2 spec
## - Scout Cavalry stats and cavalry group membership
## - Spearman stats, infantry group, and anti-cavalry bonus

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
		# Archer tests (Phase 2A)
		test_archer_has_correct_stats,
		test_archer_command_attack_sets_target,
		test_archer_state_changes_to_attacking,
		test_archer_attacks_from_range,
		test_archer_deals_damage_to_unit,
		test_archer_deals_damage_to_building,
		test_archer_stops_attacking_dead_unit,
		test_archer_groups_membership,
		# Scout Cavalry tests (Phase 2B)
		test_scout_cavalry_has_correct_stats,
		test_scout_cavalry_groups_membership,
		test_scout_cavalry_command_attack_sets_target,
		test_scout_cavalry_state_changes_to_attacking,
		test_scout_cavalry_deals_damage_to_unit,
		test_scout_cavalry_stops_attacking_dead_unit,
		# Spearman tests (Phase 2B)
		test_spearman_has_correct_stats,
		test_spearman_groups_membership,
		test_spearman_command_attack_sets_target,
		test_spearman_state_changes_to_attacking,
		test_spearman_deals_damage_to_unit,
		test_spearman_stops_attacking_dead_unit,
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


# === Archer Tests (Phase 2A) ===

func test_archer_has_correct_stats() -> Assertions.AssertResult:
	## Archer should have AoE2 spec stats: 30 HP, 4 attack, 128px range
	var archer = runner.spawner.spawn_archer(Vector2(400, 400))
	await runner.wait_frames(2)

	if archer.max_hp != 30:
		return Assertions.AssertResult.new(false,
			"Archer max_hp should be 30, got: %d" % archer.max_hp)

	if archer.current_hp != 30:
		return Assertions.AssertResult.new(false,
			"Archer current_hp should be 30, got: %d" % archer.current_hp)

	if archer.attack_damage != 4:
		return Assertions.AssertResult.new(false,
			"Archer attack_damage should be 4, got: %d" % archer.attack_damage)

	if archer.attack_range != 128.0:
		return Assertions.AssertResult.new(false,
			"Archer attack_range should be 128.0, got: %.1f" % archer.attack_range)

	return Assertions.AssertResult.new(true)


func test_archer_command_attack_sets_target() -> Assertions.AssertResult:
	## command_attack should set attack_target and change state
	var archer = runner.spawner.spawn_archer(Vector2(400, 400))
	var target = runner.spawner.spawn_militia(Vector2(450, 400), 1)  # Enemy
	await runner.wait_frames(2)

	archer.command_attack(target)
	await runner.wait_frames(2)

	if archer.attack_target != target:
		return Assertions.AssertResult.new(false,
			"attack_target should be set to target unit")

	return Assertions.assert_archer_state(archer, Archer.State.ATTACKING)


func test_archer_state_changes_to_attacking() -> Assertions.AssertResult:
	## Archer should transition to ATTACKING state when commanded
	var archer = runner.spawner.spawn_archer(Vector2(400, 400))
	var target = runner.spawner.spawn_militia(Vector2(450, 400), 1)
	await runner.wait_frames(2)

	# Verify initial state is IDLE
	if archer.current_state != Archer.State.IDLE:
		return Assertions.AssertResult.new(false,
			"Initial state should be IDLE, got %d" % archer.current_state)

	archer.command_attack(target)
	await runner.wait_frames(2)

	return Assertions.assert_archer_state(archer, Archer.State.ATTACKING)


func test_archer_attacks_from_range() -> Assertions.AssertResult:
	## Archer should attack from range without closing to melee distance
	var archer = runner.spawner.spawn_archer(Vector2(400, 400))
	# Place target within archer range (128px) but far from melee range
	var target = runner.spawner.spawn_militia(Vector2(500, 400), 1)  # 100px away, within 128px range
	await runner.wait_frames(2)

	var initial_archer_pos = archer.global_position
	var initial_target_hp = target.current_hp

	archer.command_attack(target)

	# Wait for attack cooldown (2.0 sec) + generous buffer for headless mode
	for i in range(300):
		await runner.wait_frames(1)
		if not is_instance_valid(target):
			break
		if target.current_hp < initial_target_hp:
			break

	# Archer should NOT have moved much (it's already in range)
	var move_distance = archer.global_position.distance_to(initial_archer_pos)
	if move_distance > 20.0:  # Allow small movement tolerance
		return Assertions.AssertResult.new(false,
			"Archer should attack from range, not close distance. Moved: %.1f px" % move_distance)

	# Target should have taken damage
	if is_instance_valid(target) and target.current_hp >= initial_target_hp:
		return Assertions.AssertResult.new(false,
			"Target should have taken damage from ranged attack")

	return Assertions.AssertResult.new(true)


func test_archer_deals_damage_to_unit() -> Assertions.AssertResult:
	## Archer should deal damage to target unit over time
	var archer = runner.spawner.spawn_archer(Vector2(400, 400))
	var target = runner.spawner.spawn_militia(Vector2(450, 400), 1)  # Within 128px range
	await runner.wait_frames(2)

	var initial_hp = target.current_hp

	archer.command_attack(target)

	# Wait for attack cooldown (2.0 sec) + generous buffer
	# Headless mode physics timing can vary - use 300 frames for 2.0s cooldown
	for i in range(300):
		await runner.wait_frames(1)
		if not is_instance_valid(target):
			break
		if target.current_hp < initial_hp:
			break

	if not is_instance_valid(target):
		return Assertions.AssertResult.new(false,
			"Target died unexpectedly during test")

	if target.current_hp >= initial_hp:
		return Assertions.AssertResult.new(false,
			"Target HP should decrease. Initial: %d, Current: %d" % [initial_hp, target.current_hp])

	return Assertions.AssertResult.new(true)


func test_archer_deals_damage_to_building() -> Assertions.AssertResult:
	## Archer should be able to attack buildings
	var archer = runner.spawner.spawn_archer(Vector2(400, 400))
	var target_building = runner.spawner.spawn_house(Vector2(450, 400), 1)  # Enemy building
	await runner.wait_frames(2)

	var initial_hp = target_building.current_hp

	archer.command_attack(target_building)

	# Wait for attack cooldown (2.0 sec) + generous buffer for headless mode
	for i in range(300):
		await runner.wait_frames(1)
		if not is_instance_valid(target_building):
			break
		if target_building.current_hp < initial_hp:
			break

	if not is_instance_valid(target_building):
		return Assertions.AssertResult.new(false,
			"Building destroyed unexpectedly during test")

	if target_building.current_hp >= initial_hp:
		return Assertions.AssertResult.new(false,
			"Building HP should decrease. Initial: %d, Current: %d" % [initial_hp, target_building.current_hp])

	return Assertions.AssertResult.new(true)


func test_archer_stops_attacking_dead_unit() -> Assertions.AssertResult:
	## Archer should return to IDLE when target dies
	var archer = runner.spawner.spawn_archer(Vector2(400, 400))
	var target = runner.spawner.spawn_militia(Vector2(450, 400), 1)
	await runner.wait_frames(2)

	archer.command_attack(target)
	await runner.wait_frames(2)

	# Kill the target directly
	target.die()
	await runner.wait_frames(5)  # Let state machine process

	if archer.attack_target != null:
		return Assertions.AssertResult.new(false,
			"attack_target should be null after target dies")

	return Assertions.assert_archer_state(archer, Archer.State.IDLE)


func test_archer_groups_membership() -> Assertions.AssertResult:
	## Archer should belong to "military" and "archers" groups
	var archer = runner.spawner.spawn_archer(Vector2(400, 400))
	await runner.wait_frames(2)

	if not archer.is_in_group("military"):
		return Assertions.AssertResult.new(false,
			"Archer should be in 'military' group")

	if not archer.is_in_group("archers"):
		return Assertions.AssertResult.new(false,
			"Archer should be in 'archers' group")

	return Assertions.AssertResult.new(true)


# === Scout Cavalry Tests (Phase 2B) ===

func test_scout_cavalry_has_correct_stats() -> Assertions.AssertResult:
	## Scout Cavalry should have AoE2 spec stats: 45 HP, 3 attack, 0/2 armor, 150 speed
	var scout = runner.spawner.spawn_scout_cavalry(Vector2(400, 400))
	await runner.wait_frames(2)

	if scout.max_hp != 45:
		return Assertions.AssertResult.new(false,
			"Scout Cavalry max_hp should be 45, got: %d" % scout.max_hp)

	if scout.current_hp != 45:
		return Assertions.AssertResult.new(false,
			"Scout Cavalry current_hp should be 45, got: %d" % scout.current_hp)

	if scout.attack_damage != 3:
		return Assertions.AssertResult.new(false,
			"Scout Cavalry attack_damage should be 3, got: %d" % scout.attack_damage)

	if scout.melee_armor != 0:
		return Assertions.AssertResult.new(false,
			"Scout Cavalry melee_armor should be 0, got: %d" % scout.melee_armor)

	if scout.pierce_armor != 2:
		return Assertions.AssertResult.new(false,
			"Scout Cavalry pierce_armor should be 2, got: %d" % scout.pierce_armor)

	if scout.move_speed != 150.0:
		return Assertions.AssertResult.new(false,
			"Scout Cavalry move_speed should be 150.0, got: %.1f" % scout.move_speed)

	return Assertions.AssertResult.new(true)


func test_scout_cavalry_groups_membership() -> Assertions.AssertResult:
	## Scout Cavalry should belong to "military" and "cavalry" groups
	var scout = runner.spawner.spawn_scout_cavalry(Vector2(400, 400))
	await runner.wait_frames(2)

	if not scout.is_in_group("military"):
		return Assertions.AssertResult.new(false,
			"Scout Cavalry should be in 'military' group")

	if not scout.is_in_group("cavalry"):
		return Assertions.AssertResult.new(false,
			"Scout Cavalry should be in 'cavalry' group")

	return Assertions.AssertResult.new(true)


func test_scout_cavalry_command_attack_sets_target() -> Assertions.AssertResult:
	## command_attack should set attack_target and change state
	var scout = runner.spawner.spawn_scout_cavalry(Vector2(400, 400))
	var target = runner.spawner.spawn_militia(Vector2(410, 400), 1)  # Enemy
	await runner.wait_frames(2)

	scout.command_attack(target)
	await runner.wait_frames(2)

	if scout.attack_target != target:
		return Assertions.AssertResult.new(false,
			"attack_target should be set to target unit")

	return Assertions.assert_scout_cavalry_state(scout, ScoutCavalry.State.ATTACKING)


func test_scout_cavalry_state_changes_to_attacking() -> Assertions.AssertResult:
	## Scout Cavalry should transition to ATTACKING state when commanded
	var scout = runner.spawner.spawn_scout_cavalry(Vector2(400, 400))
	var target = runner.spawner.spawn_militia(Vector2(410, 400), 1)
	await runner.wait_frames(2)

	# Verify initial state is IDLE
	if scout.current_state != ScoutCavalry.State.IDLE:
		return Assertions.AssertResult.new(false,
			"Initial state should be IDLE, got %d" % scout.current_state)

	scout.command_attack(target)
	await runner.wait_frames(2)

	return Assertions.assert_scout_cavalry_state(scout, ScoutCavalry.State.ATTACKING)


func test_scout_cavalry_deals_damage_to_unit() -> Assertions.AssertResult:
	## Scout Cavalry should deal damage to target unit over time
	var scout = runner.spawner.spawn_scout_cavalry(Vector2(400, 400))
	var target = runner.spawner.spawn_militia(Vector2(410, 400), 1)  # Within attack range
	await runner.wait_frames(2)

	var initial_hp = target.current_hp

	scout.command_attack(target)

	# Wait for attack cooldown (2.0 sec) + generous buffer
	for i in range(300):
		await runner.wait_frames(1)
		if not is_instance_valid(target):
			break
		if target.current_hp < initial_hp:
			break

	if not is_instance_valid(target):
		return Assertions.AssertResult.new(false,
			"Target died unexpectedly during test")

	if target.current_hp >= initial_hp:
		return Assertions.AssertResult.new(false,
			"Target HP should decrease. Initial: %d, Current: %d" % [initial_hp, target.current_hp])

	return Assertions.AssertResult.new(true)


func test_scout_cavalry_stops_attacking_dead_unit() -> Assertions.AssertResult:
	## Scout Cavalry should return to IDLE when target dies
	var scout = runner.spawner.spawn_scout_cavalry(Vector2(400, 400))
	var target = runner.spawner.spawn_militia(Vector2(410, 400), 1)
	await runner.wait_frames(2)

	scout.command_attack(target)
	await runner.wait_frames(2)

	# Kill the target directly
	target.die()
	await runner.wait_frames(5)  # Let state machine process

	if scout.attack_target != null:
		return Assertions.AssertResult.new(false,
			"attack_target should be null after target dies")

	return Assertions.assert_scout_cavalry_state(scout, ScoutCavalry.State.IDLE)


# === Spearman Tests (Phase 2B) ===

func test_spearman_has_correct_stats() -> Assertions.AssertResult:
	## Spearman should have AoE2 spec stats: 45 HP, 3 attack, 0/0 armor, +15 vs cavalry
	var spearman = runner.spawner.spawn_spearman(Vector2(400, 400))
	await runner.wait_frames(2)

	if spearman.max_hp != 45:
		return Assertions.AssertResult.new(false,
			"Spearman max_hp should be 45, got: %d" % spearman.max_hp)

	if spearman.current_hp != 45:
		return Assertions.AssertResult.new(false,
			"Spearman current_hp should be 45, got: %d" % spearman.current_hp)

	if spearman.attack_damage != 3:
		return Assertions.AssertResult.new(false,
			"Spearman attack_damage should be 3, got: %d" % spearman.attack_damage)

	if spearman.melee_armor != 0:
		return Assertions.AssertResult.new(false,
			"Spearman melee_armor should be 0, got: %d" % spearman.melee_armor)

	if spearman.pierce_armor != 0:
		return Assertions.AssertResult.new(false,
			"Spearman pierce_armor should be 0, got: %d" % spearman.pierce_armor)

	if spearman.bonus_vs_cavalry != 15:
		return Assertions.AssertResult.new(false,
			"Spearman bonus_vs_cavalry should be 15, got: %d" % spearman.bonus_vs_cavalry)

	return Assertions.AssertResult.new(true)


func test_spearman_groups_membership() -> Assertions.AssertResult:
	## Spearman should belong to "military" and "infantry" groups
	var spearman = runner.spawner.spawn_spearman(Vector2(400, 400))
	await runner.wait_frames(2)

	if not spearman.is_in_group("military"):
		return Assertions.AssertResult.new(false,
			"Spearman should be in 'military' group")

	if not spearman.is_in_group("infantry"):
		return Assertions.AssertResult.new(false,
			"Spearman should be in 'infantry' group")

	return Assertions.AssertResult.new(true)


func test_spearman_command_attack_sets_target() -> Assertions.AssertResult:
	## command_attack should set attack_target and change state
	var spearman = runner.spawner.spawn_spearman(Vector2(400, 400))
	var target = runner.spawner.spawn_militia(Vector2(410, 400), 1)  # Enemy
	await runner.wait_frames(2)

	spearman.command_attack(target)
	await runner.wait_frames(2)

	if spearman.attack_target != target:
		return Assertions.AssertResult.new(false,
			"attack_target should be set to target unit")

	return Assertions.assert_spearman_state(spearman, Spearman.State.ATTACKING)


func test_spearman_state_changes_to_attacking() -> Assertions.AssertResult:
	## Spearman should transition to ATTACKING state when commanded
	var spearman = runner.spawner.spawn_spearman(Vector2(400, 400))
	var target = runner.spawner.spawn_militia(Vector2(410, 400), 1)
	await runner.wait_frames(2)

	# Verify initial state is IDLE
	if spearman.current_state != Spearman.State.IDLE:
		return Assertions.AssertResult.new(false,
			"Initial state should be IDLE, got %d" % spearman.current_state)

	spearman.command_attack(target)
	await runner.wait_frames(2)

	return Assertions.assert_spearman_state(spearman, Spearman.State.ATTACKING)


func test_spearman_deals_damage_to_unit() -> Assertions.AssertResult:
	## Spearman should deal damage to target unit over time
	var spearman = runner.spawner.spawn_spearman(Vector2(400, 400))
	var target = runner.spawner.spawn_militia(Vector2(410, 400), 1)  # Within attack range
	await runner.wait_frames(2)

	var initial_hp = target.current_hp

	spearman.command_attack(target)

	# Wait for attack cooldown (2.0 sec) + generous buffer
	for i in range(300):
		await runner.wait_frames(1)
		if not is_instance_valid(target):
			break
		if target.current_hp < initial_hp:
			break

	if not is_instance_valid(target):
		return Assertions.AssertResult.new(false,
			"Target died unexpectedly during test")

	if target.current_hp >= initial_hp:
		return Assertions.AssertResult.new(false,
			"Target HP should decrease. Initial: %d, Current: %d" % [initial_hp, target.current_hp])

	return Assertions.AssertResult.new(true)


func test_spearman_stops_attacking_dead_unit() -> Assertions.AssertResult:
	## Spearman should return to IDLE when target dies
	var spearman = runner.spawner.spawn_spearman(Vector2(400, 400))
	var target = runner.spawner.spawn_militia(Vector2(410, 400), 1)
	await runner.wait_frames(2)

	spearman.command_attack(target)
	await runner.wait_frames(2)

	# Kill the target directly
	target.die()
	await runner.wait_frames(5)  # Let state machine process

	if spearman.attack_target != null:
		return Assertions.AssertResult.new(false,
			"attack_target should be null after target dies")

	return Assertions.assert_spearman_state(spearman, Spearman.State.IDLE)
