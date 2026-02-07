extends Node
## Monastery + Monk Tests - Tests for Phase 6A
##
## These tests verify:
## - Monk initial stats (HP, armor, speed, stance)
## - Monk group membership (monks, NOT military)
## - Monastery stats (HP, wood cost, group)
## - Monk training at monastery (gold cost, population cap, cancel refund)
## - Conversion immunity rules (can_convert)
## - Healing target assignment and state transitions
## - Healing accumulator (1 HP/sec, not 1 HP/frame)
## - Tech bonuses (Sanctity, Fervor, Block Printing, Illumination)
## - Scout cavalry conversion resistance
## - Rejuvenation blocking new conversions
## - Monastery research blocks training

class_name TestMonastery

var runner: TestRunner


func _init(test_runner: TestRunner) -> void:
	runner = test_runner


func get_all_tests() -> Array[Callable]:
	## Returns all test methods to run
	return [
		# Monk stats and groups
		test_monk_initial_hp,
		test_monk_initial_armor,
		test_monk_initial_speed,
		test_monk_stance_no_attack,
		test_monk_group_membership,
		test_monk_not_in_military_group,
		# Monastery stats
		test_monastery_initial_hp,
		test_monastery_wood_cost,
		test_monastery_group_membership,
		# Monk training
		test_monk_training_deducts_gold,
		test_monk_training_fails_without_gold,
		test_monk_training_fails_pop_capped,
		test_monastery_cancel_training_refunds_gold,
		test_monastery_training_queue,
		# Monastery guards
		test_monastery_destroyed_blocks_training,
		# Conversion immunity rules (can_convert)
		test_can_convert_enemy_unit,
		test_cannot_convert_same_team,
		test_cannot_convert_building_without_redemption,
		test_can_convert_building_with_redemption,
		test_cannot_convert_tc_even_with_redemption,
		test_cannot_convert_monastery_even_with_redemption,
		test_cannot_convert_farm_even_with_redemption,
		test_cannot_convert_monk_without_atonement,
		test_can_convert_monk_with_atonement,
		# Conversion command
		test_command_convert_sets_state,
		test_command_convert_blocked_by_rejuvenation,
		test_command_convert_blocked_by_immunity,
		# Healing
		test_command_heal_sets_state,
		test_command_heal_rejects_enemy,
		test_command_heal_rejects_dead,
		test_healing_accumulator_not_instant,
		# Tech bonuses
		test_sanctity_adds_hp,
		test_fervor_adds_speed,
		test_block_printing_adds_range,
		test_illumination_reduces_rejuvenation,
		# Scout cavalry conversion resistance
		test_scout_cavalry_conversion_resistance,
		# Rejuvenation
		test_rejuvenation_starts_after_conversion,
		test_rejuvenation_timer_expires,
		# Monastery research blocks training
		test_monastery_research_blocks_training,
		# Status text
		test_monk_status_text_idle,
		test_monk_status_text_rejuvenating,
	]


# =============================================================================
# Monk Stats and Groups
# =============================================================================

func test_monk_initial_hp() -> Assertions.AssertResult:
	## Monk should have 30 HP (AoE2 spec)
	var monk = runner.spawner.spawn_monk(Vector2(400, 400))
	await runner.wait_frames(2)

	if monk.max_hp != 30:
		return Assertions.AssertResult.new(false,
			"Monk max_hp should be 30, got: %d" % monk.max_hp)
	if monk.current_hp != 30:
		return Assertions.AssertResult.new(false,
			"Monk current_hp should be 30, got: %d" % monk.current_hp)
	return Assertions.AssertResult.new(true)


func test_monk_initial_armor() -> Assertions.AssertResult:
	## Monk should have 0/0 armor
	var monk = runner.spawner.spawn_monk(Vector2(400, 400))
	await runner.wait_frames(2)

	if monk.melee_armor != 0:
		return Assertions.AssertResult.new(false,
			"Monk melee_armor should be 0, got: %d" % monk.melee_armor)
	if monk.pierce_armor != 0:
		return Assertions.AssertResult.new(false,
			"Monk pierce_armor should be 0, got: %d" % monk.pierce_armor)
	return Assertions.AssertResult.new(true)


func test_monk_initial_speed() -> Assertions.AssertResult:
	## Monk should have 70 move speed (slow)
	var monk = runner.spawner.spawn_monk(Vector2(400, 400))
	await runner.wait_frames(2)

	if abs(monk.move_speed - 70.0) > 0.1:
		return Assertions.AssertResult.new(false,
			"Monk move_speed should be 70, got: %.1f" % monk.move_speed)
	return Assertions.AssertResult.new(true)


func test_monk_stance_no_attack() -> Assertions.AssertResult:
	## Monk should use NO_ATTACK stance (never auto-attacks)
	var monk = runner.spawner.spawn_monk(Vector2(400, 400))
	await runner.wait_frames(2)

	if monk.stance != Unit.Stance.NO_ATTACK:
		return Assertions.AssertResult.new(false,
			"Monk stance should be NO_ATTACK (%d), got: %d" % [Unit.Stance.NO_ATTACK, monk.stance])
	return Assertions.AssertResult.new(true)


func test_monk_group_membership() -> Assertions.AssertResult:
	## Monk should be in "monks" and "units" groups
	var monk = runner.spawner.spawn_monk(Vector2(400, 400))
	await runner.wait_frames(2)

	if not monk.is_in_group("monks"):
		return Assertions.AssertResult.new(false, "Monk should be in 'monks' group")
	if not monk.is_in_group("units"):
		return Assertions.AssertResult.new(false, "Monk should be in 'units' group")
	return Assertions.AssertResult.new(true)


func test_monk_not_in_military_group() -> Assertions.AssertResult:
	## Monk should NOT be in "military" group (support unit)
	var monk = runner.spawner.spawn_monk(Vector2(400, 400))
	await runner.wait_frames(2)

	if monk.is_in_group("military"):
		return Assertions.AssertResult.new(false,
			"Monk should NOT be in 'military' group")
	return Assertions.AssertResult.new(true)


# =============================================================================
# Monastery Stats
# =============================================================================

func test_monastery_initial_hp() -> Assertions.AssertResult:
	## Monastery should have 2100 HP (AoE2 spec)
	var monastery = runner.spawner.spawn_monastery(Vector2(400, 400))
	await runner.wait_frames(2)

	if monastery.max_hp != 2100:
		return Assertions.AssertResult.new(false,
			"Monastery max_hp should be 2100, got: %d" % monastery.max_hp)
	if monastery.current_hp != 2100:
		return Assertions.AssertResult.new(false,
			"Monastery current_hp should be 2100, got: %d" % monastery.current_hp)
	return Assertions.AssertResult.new(true)


func test_monastery_wood_cost() -> Assertions.AssertResult:
	## Monastery should cost 175 wood
	var monastery = runner.spawner.spawn_monastery(Vector2(400, 400))
	await runner.wait_frames(2)

	if monastery.wood_cost != 175:
		return Assertions.AssertResult.new(false,
			"Monastery wood_cost should be 175, got: %d" % monastery.wood_cost)
	return Assertions.AssertResult.new(true)


func test_monastery_group_membership() -> Assertions.AssertResult:
	## Monastery should be in "monasteries" group
	var monastery = runner.spawner.spawn_monastery(Vector2(400, 400))
	await runner.wait_frames(2)

	if not monastery.is_in_group("monasteries"):
		return Assertions.AssertResult.new(false,
			"Monastery should be in 'monasteries' group")
	return Assertions.AssertResult.new(true)


# =============================================================================
# Monk Training
# =============================================================================

func test_monk_training_deducts_gold() -> Assertions.AssertResult:
	## Training a monk should cost 100 gold
	GameManager.resources["gold"] = 200
	GameManager.population_cap = 20
	var monastery = runner.spawner.spawn_monastery(Vector2(400, 400), 0)
	await runner.wait_frames(2)

	var result = monastery.train_monk()
	if not result:
		return Assertions.AssertResult.new(false,
			"train_monk should succeed with enough gold")
	if GameManager.resources["gold"] != 100:
		return Assertions.AssertResult.new(false,
			"Gold should be 100 after training monk (200-100), got: %d" % GameManager.resources["gold"])
	return Assertions.AssertResult.new(true)


func test_monk_training_fails_without_gold() -> Assertions.AssertResult:
	## Training a monk should fail without enough gold
	GameManager.resources["gold"] = 50
	GameManager.population_cap = 20
	var monastery = runner.spawner.spawn_monastery(Vector2(400, 400), 0)
	await runner.wait_frames(2)

	var result = monastery.train_monk()
	if result:
		return Assertions.AssertResult.new(false,
			"train_monk should fail with only 50 gold (needs 100)")
	return Assertions.AssertResult.new(true)


func test_monk_training_fails_pop_capped() -> Assertions.AssertResult:
	## Training a monk should fail when population is at cap
	GameManager.resources["gold"] = 200
	# population starts at 4, cap at 5 by default from reset()
	GameManager.population = 5
	GameManager.population_cap = 5
	var monastery = runner.spawner.spawn_monastery(Vector2(400, 400), 0)
	await runner.wait_frames(2)

	var result = monastery.train_monk()
	if result:
		return Assertions.AssertResult.new(false,
			"train_monk should fail when population is at cap")
	return Assertions.AssertResult.new(true)


func test_monastery_cancel_training_refunds_gold() -> Assertions.AssertResult:
	## Cancelling monk training should refund 100 gold
	GameManager.resources["gold"] = 200
	GameManager.population_cap = 20
	var monastery = runner.spawner.spawn_monastery(Vector2(400, 400), 0)
	await runner.wait_frames(2)

	monastery.train_monk()
	# Gold should be 100 after training
	if GameManager.resources["gold"] != 100:
		return Assertions.AssertResult.new(false,
			"Gold should be 100 after training, got: %d" % GameManager.resources["gold"])

	var cancelled = monastery.cancel_training()
	if not cancelled:
		return Assertions.AssertResult.new(false,
			"cancel_training should succeed when queue is not empty")
	if GameManager.resources["gold"] != 200:
		return Assertions.AssertResult.new(false,
			"Gold should be 200 after cancel (refund 100), got: %d" % GameManager.resources["gold"])
	return Assertions.AssertResult.new(true)


func test_monastery_training_queue() -> Assertions.AssertResult:
	## Queue multiple monks — queue size should reflect and cancel pops last
	GameManager.resources["gold"] = 500
	GameManager.population_cap = 20
	var monastery = runner.spawner.spawn_monastery(Vector2(400, 400), 0)
	await runner.wait_frames(2)

	monastery.train_monk()
	monastery.train_monk()
	monastery.train_monk()

	if monastery.get_queue_size() != 3:
		return Assertions.AssertResult.new(false,
			"Queue size should be 3, got: %d" % monastery.get_queue_size())
	if GameManager.resources["gold"] != 200:
		return Assertions.AssertResult.new(false,
			"Gold should be 200 (500 - 3*100), got: %d" % GameManager.resources["gold"])

	# Cancel one — should refund 100, queue = 2
	monastery.cancel_training()
	if monastery.get_queue_size() != 2:
		return Assertions.AssertResult.new(false,
			"Queue size should be 2 after cancel, got: %d" % monastery.get_queue_size())
	if GameManager.resources["gold"] != 300:
		return Assertions.AssertResult.new(false,
			"Gold should be 300 after one cancel, got: %d" % GameManager.resources["gold"])
	return Assertions.AssertResult.new(true)


# =============================================================================
# Monastery Guards
# =============================================================================

func test_monastery_destroyed_blocks_training() -> Assertions.AssertResult:
	## A destroyed monastery should not process training
	GameManager.resources["gold"] = 200
	GameManager.population_cap = 20
	var monastery = runner.spawner.spawn_monastery(Vector2(400, 400), 0)
	await runner.wait_frames(2)

	monastery.train_monk()

	# Destroy the monastery
	monastery.is_destroyed = true

	# Manually process — should return early due to is_destroyed guard
	monastery._process(5.0)

	# Training timer should not have advanced beyond what it was
	# The monastery calls _process which checks is_destroyed first
	# Since we set is_destroyed after train_monk, the timer should not advance further
	if monastery.train_timer >= monastery.MONK_TRAIN_TIME:
		return Assertions.AssertResult.new(false,
			"Training should not complete on a destroyed monastery")
	return Assertions.AssertResult.new(true)


# =============================================================================
# Conversion Immunity Rules (can_convert)
# =============================================================================

func test_can_convert_enemy_unit() -> Assertions.AssertResult:
	## Monk should be able to convert an enemy militia
	var monk = runner.spawner.spawn_monk(Vector2(400, 400), 0)
	var enemy = runner.spawner.spawn_militia(Vector2(500, 400), 1)
	await runner.wait_frames(2)

	if not monk.can_convert(enemy):
		return Assertions.AssertResult.new(false,
			"Monk should be able to convert enemy militia")
	return Assertions.AssertResult.new(true)


func test_cannot_convert_same_team() -> Assertions.AssertResult:
	## Monk should NOT be able to convert a friendly unit
	var monk = runner.spawner.spawn_monk(Vector2(400, 400), 0)
	var friendly = runner.spawner.spawn_militia(Vector2(500, 400), 0)
	await runner.wait_frames(2)

	if monk.can_convert(friendly):
		return Assertions.AssertResult.new(false,
			"Monk should NOT be able to convert same-team unit")
	return Assertions.AssertResult.new(true)


func test_cannot_convert_building_without_redemption() -> Assertions.AssertResult:
	## Without Redemption tech, monk cannot convert enemy buildings
	var monk = runner.spawner.spawn_monk(Vector2(400, 400), 0)
	var enemy_barracks = runner.spawner.spawn_barracks(Vector2(600, 400), 1)
	await runner.wait_frames(2)

	if monk.can_convert(enemy_barracks):
		return Assertions.AssertResult.new(false,
			"Monk should NOT convert buildings without Redemption tech")
	return Assertions.AssertResult.new(true)


func test_can_convert_building_with_redemption() -> Assertions.AssertResult:
	## With Redemption tech, monk CAN convert enemy barracks
	GameManager.complete_tech_research("redemption", 0)
	var monk = runner.spawner.spawn_monk(Vector2(400, 400), 0)
	var enemy_barracks = runner.spawner.spawn_barracks(Vector2(600, 400), 1)
	await runner.wait_frames(2)

	if not monk.can_convert(enemy_barracks):
		return Assertions.AssertResult.new(false,
			"Monk WITH Redemption should be able to convert enemy barracks")
	return Assertions.AssertResult.new(true)


func test_cannot_convert_tc_even_with_redemption() -> Assertions.AssertResult:
	## Town Centers are always immune to conversion, even with Redemption
	GameManager.complete_tech_research("redemption", 0)
	var monk = runner.spawner.spawn_monk(Vector2(400, 400), 0)
	var enemy_tc = runner.spawner.spawn_town_center(Vector2(600, 400), 1)
	await runner.wait_frames(2)

	if monk.can_convert(enemy_tc):
		return Assertions.AssertResult.new(false,
			"Monk should NOT convert Town Center even with Redemption")
	return Assertions.AssertResult.new(true)


func test_cannot_convert_monastery_even_with_redemption() -> Assertions.AssertResult:
	## Monasteries are always immune to conversion, even with Redemption
	GameManager.complete_tech_research("redemption", 0)
	var monk = runner.spawner.spawn_monk(Vector2(400, 400), 0)
	var enemy_monastery = runner.spawner.spawn_monastery(Vector2(600, 400), 1)
	await runner.wait_frames(2)

	if monk.can_convert(enemy_monastery):
		return Assertions.AssertResult.new(false,
			"Monk should NOT convert Monastery even with Redemption")
	return Assertions.AssertResult.new(true)


func test_cannot_convert_farm_even_with_redemption() -> Assertions.AssertResult:
	## Farms are always immune to conversion, even with Redemption
	GameManager.complete_tech_research("redemption", 0)
	var monk = runner.spawner.spawn_monk(Vector2(400, 400), 0)
	var enemy_farm = runner.spawner.spawn_farm(Vector2(600, 400), 1)
	await runner.wait_frames(2)

	if monk.can_convert(enemy_farm):
		return Assertions.AssertResult.new(false,
			"Monk should NOT convert Farm even with Redemption")
	return Assertions.AssertResult.new(true)


func test_cannot_convert_monk_without_atonement() -> Assertions.AssertResult:
	## Without Atonement tech, monk cannot convert enemy monks
	var monk = runner.spawner.spawn_monk(Vector2(400, 400), 0)
	var enemy_monk = runner.spawner.spawn_monk(Vector2(500, 400), 1)
	await runner.wait_frames(2)

	if monk.can_convert(enemy_monk):
		return Assertions.AssertResult.new(false,
			"Monk should NOT convert enemy monk without Atonement tech")
	return Assertions.AssertResult.new(true)


func test_can_convert_monk_with_atonement() -> Assertions.AssertResult:
	## With Atonement tech, monk CAN convert enemy monks
	GameManager.complete_tech_research("atonement", 0)
	var monk = runner.spawner.spawn_monk(Vector2(400, 400), 0)
	var enemy_monk = runner.spawner.spawn_monk(Vector2(500, 400), 1)
	await runner.wait_frames(2)

	if not monk.can_convert(enemy_monk):
		return Assertions.AssertResult.new(false,
			"Monk WITH Atonement should be able to convert enemy monk")
	return Assertions.AssertResult.new(true)


# =============================================================================
# Conversion Command
# =============================================================================

func test_command_convert_sets_state() -> Assertions.AssertResult:
	## command_convert should set monk to CONVERTING state
	var monk = runner.spawner.spawn_monk(Vector2(400, 400), 0)
	var enemy = runner.spawner.spawn_militia(Vector2(500, 400), 1)
	await runner.wait_frames(2)

	monk.command_convert(enemy)

	if monk.current_state != Monk.State.CONVERTING:
		return Assertions.AssertResult.new(false,
			"Monk should be in CONVERTING state, got: %d" % monk.current_state)
	if monk.conversion_target != enemy:
		return Assertions.AssertResult.new(false,
			"Monk conversion_target should be the enemy")
	if monk.conversion_timer != 0.0:
		return Assertions.AssertResult.new(false,
			"Conversion timer should be reset to 0")
	return Assertions.AssertResult.new(true)


func test_command_convert_blocked_by_rejuvenation() -> Assertions.AssertResult:
	## Monk should not start conversion while rejuvenating
	var monk = runner.spawner.spawn_monk(Vector2(400, 400), 0)
	var enemy = runner.spawner.spawn_militia(Vector2(500, 400), 1)
	await runner.wait_frames(2)

	# Simulate rejuvenation
	monk.is_rejuvenating = true

	monk.command_convert(enemy)

	if monk.current_state == Monk.State.CONVERTING:
		return Assertions.AssertResult.new(false,
			"Monk should NOT enter CONVERTING state while rejuvenating")
	if monk.conversion_target == enemy:
		return Assertions.AssertResult.new(false,
			"Monk should NOT have conversion_target set while rejuvenating")
	return Assertions.AssertResult.new(true)


func test_command_convert_blocked_by_immunity() -> Assertions.AssertResult:
	## command_convert should refuse if can_convert returns false
	var monk = runner.spawner.spawn_monk(Vector2(400, 400), 0)
	var friendly = runner.spawner.spawn_militia(Vector2(500, 400), 0)
	await runner.wait_frames(2)

	monk.command_convert(friendly)

	if monk.current_state == Monk.State.CONVERTING:
		return Assertions.AssertResult.new(false,
			"Monk should NOT enter CONVERTING state for immune target")
	return Assertions.AssertResult.new(true)


# =============================================================================
# Healing
# =============================================================================

func test_command_heal_sets_state() -> Assertions.AssertResult:
	## command_heal should set monk to HEALING state
	var monk = runner.spawner.spawn_monk(Vector2(400, 400), 0)
	var friendly = runner.spawner.spawn_militia(Vector2(420, 400), 0)
	await runner.wait_frames(2)

	# Damage the friendly unit
	friendly.current_hp = 20

	monk.command_heal(friendly)

	if monk.current_state != Monk.State.HEALING:
		return Assertions.AssertResult.new(false,
			"Monk should be in HEALING state, got: %d" % monk.current_state)
	if monk.heal_target != friendly:
		return Assertions.AssertResult.new(false,
			"Monk heal_target should be the friendly unit")
	return Assertions.AssertResult.new(true)


func test_command_heal_rejects_enemy() -> Assertions.AssertResult:
	## command_heal should reject enemy units
	var monk = runner.spawner.spawn_monk(Vector2(400, 400), 0)
	var enemy = runner.spawner.spawn_militia(Vector2(420, 400), 1)
	await runner.wait_frames(2)

	enemy.current_hp = 20
	monk.command_heal(enemy)

	if monk.current_state == Monk.State.HEALING:
		return Assertions.AssertResult.new(false,
			"Monk should NOT heal enemy units")
	return Assertions.AssertResult.new(true)


func test_command_heal_rejects_dead() -> Assertions.AssertResult:
	## command_heal should reject dead units
	var monk = runner.spawner.spawn_monk(Vector2(400, 400), 0)
	var friendly = runner.spawner.spawn_militia(Vector2(420, 400), 0)
	await runner.wait_frames(2)

	friendly.is_dead = true
	monk.command_heal(friendly)

	if monk.current_state == Monk.State.HEALING:
		return Assertions.AssertResult.new(false,
			"Monk should NOT heal dead units")
	return Assertions.AssertResult.new(true)


func test_healing_accumulator_not_instant() -> Assertions.AssertResult:
	## Healing should use accumulator (1 HP/sec), not instant 1 HP/frame
	## A small delta (one frame at 60fps ~0.0167s) should NOT heal 1 HP immediately
	var monk = runner.spawner.spawn_monk(Vector2(400, 400), 0)
	var friendly = runner.spawner.spawn_militia(Vector2(410, 400), 0)
	await runner.wait_frames(2)

	friendly.current_hp = 30  # Damaged (max is 40)

	monk.command_heal(friendly)
	# The monk is now in HEALING state. Simulate one short frame
	# We call _process_healing directly with a small delta
	monk._process_healing(0.0167)  # ~1 frame at 60fps

	# After ~0.017s, accumulator should be ~0.017, not yet 1.0 -> no HP healed yet
	if friendly.current_hp != 30:
		return Assertions.AssertResult.new(false,
			"After one frame, HP should still be 30 (accumulator-based), got: %d" % friendly.current_hp)

	# Now simulate ~1 full second (many small frames)
	for i in range(60):
		monk._process_healing(0.0167)

	# After ~1 second total, should have healed ~1 HP
	if friendly.current_hp != 31:
		return Assertions.AssertResult.new(false,
			"After ~1 second of healing, HP should be 31, got: %d" % friendly.current_hp)
	return Assertions.AssertResult.new(true)


# =============================================================================
# Tech Bonuses
# =============================================================================

func test_sanctity_adds_hp() -> Assertions.AssertResult:
	## Sanctity tech should add 15 HP to monks (30 -> 45)
	## Note: complete_tech_research emits tech_researched signal, which auto-applies bonuses
	var monk = runner.spawner.spawn_monk(Vector2(400, 400), 0)
	await runner.wait_frames(2)

	# Verify base HP
	if monk.max_hp != 30:
		return Assertions.AssertResult.new(false,
			"Monk base max_hp should be 30, got: %d" % monk.max_hp)

	GameManager.complete_tech_research("sanctity", 0)
	# No manual apply_tech_bonuses() needed — signal auto-applies

	if monk.max_hp != 45:
		return Assertions.AssertResult.new(false,
			"Monk max_hp with Sanctity should be 45 (30+15), got: %d" % monk.max_hp)
	# current_hp should also increase
	if monk.current_hp != 45:
		return Assertions.AssertResult.new(false,
			"Monk current_hp with Sanctity should be 45, got: %d" % monk.current_hp)
	return Assertions.AssertResult.new(true)


func test_fervor_adds_speed() -> Assertions.AssertResult:
	## Fervor tech should add 15% speed to monks (70 -> 80.5)
	var monk = runner.spawner.spawn_monk(Vector2(400, 400), 0)
	await runner.wait_frames(2)

	if abs(monk.move_speed - 70.0) > 0.1:
		return Assertions.AssertResult.new(false,
			"Monk base speed should be 70, got: %.1f" % monk.move_speed)

	GameManager.complete_tech_research("fervor", 0)
	# No manual apply_tech_bonuses() needed — signal auto-applies

	# 70 * 1.15 = 80.5
	if abs(monk.move_speed - 80.5) > 0.1:
		return Assertions.AssertResult.new(false,
			"Monk speed with Fervor should be 80.5 (70*1.15), got: %.1f" % monk.move_speed)
	return Assertions.AssertResult.new(true)


func test_block_printing_adds_range() -> Assertions.AssertResult:
	## Block Printing tech should add 96 conversion range (288 -> 384)
	var monk = runner.spawner.spawn_monk(Vector2(400, 400), 0)
	await runner.wait_frames(2)

	if abs(monk.conversion_range - 288.0) > 0.1:
		return Assertions.AssertResult.new(false,
			"Monk base conversion_range should be 288, got: %.1f" % monk.conversion_range)

	GameManager.complete_tech_research("block_printing", 0)
	# No manual apply_tech_bonuses() needed — signal auto-applies

	if abs(monk.conversion_range - 384.0) > 0.1:
		return Assertions.AssertResult.new(false,
			"Monk range with Block Printing should be 384 (288+96), got: %.1f" % monk.conversion_range)
	return Assertions.AssertResult.new(true)


func test_illumination_reduces_rejuvenation() -> Assertions.AssertResult:
	## Illumination tech should reduce rejuvenation time by 1/3 (62 / 1.5 = 41.33)
	var monk = runner.spawner.spawn_monk(Vector2(400, 400), 0)
	await runner.wait_frames(2)

	if abs(monk.rejuvenation_time - 62.0) > 0.1:
		return Assertions.AssertResult.new(false,
			"Monk base rejuvenation_time should be 62, got: %.1f" % monk.rejuvenation_time)

	GameManager.complete_tech_research("illumination", 0)
	# No manual apply_tech_bonuses() needed — signal auto-applies

	var expected = 62.0 / 1.5  # ~41.33
	if abs(monk.rejuvenation_time - expected) > 0.1:
		return Assertions.AssertResult.new(false,
			"Monk rejuvenation with Illumination should be ~%.1f, got: %.1f" % [expected, monk.rejuvenation_time])
	return Assertions.AssertResult.new(true)


# =============================================================================
# Scout Cavalry Conversion Resistance
# =============================================================================

func test_scout_cavalry_conversion_resistance() -> Assertions.AssertResult:
	## Scout cavalry should have conversion_resistance = 0.5
	var scout = runner.spawner.spawn_scout_cavalry(Vector2(400, 400), 1)
	await runner.wait_frames(2)

	if abs(scout.conversion_resistance - 0.5) > 0.01:
		return Assertions.AssertResult.new(false,
			"Scout cavalry conversion_resistance should be 0.5, got: %.2f" % scout.conversion_resistance)
	return Assertions.AssertResult.new(true)


# =============================================================================
# Rejuvenation
# =============================================================================

func test_rejuvenation_starts_after_conversion() -> Assertions.AssertResult:
	## After _complete_conversion, monk should be rejuvenating
	var monk = runner.spawner.spawn_monk(Vector2(400, 400), 0)
	var enemy = runner.spawner.spawn_militia(Vector2(410, 400), 1)
	await runner.wait_frames(2)

	# Set up conversion state and complete it
	GameManager.population_cap = 20  # Ensure not pop-capped
	monk.conversion_target = enemy
	monk.current_state = Monk.State.CONVERTING
	monk._complete_conversion()

	if not monk.is_rejuvenating:
		return Assertions.AssertResult.new(false,
			"Monk should be rejuvenating after completing conversion")
	if monk.rejuvenation_timer != 0.0:
		return Assertions.AssertResult.new(false,
			"Rejuvenation timer should start at 0")
	return Assertions.AssertResult.new(true)


func test_rejuvenation_timer_expires() -> Assertions.AssertResult:
	## Rejuvenation should end after rejuvenation_time elapses
	var monk = runner.spawner.spawn_monk(Vector2(400, 400), 0)
	await runner.wait_frames(2)

	monk.is_rejuvenating = true
	monk.rejuvenation_timer = 0.0

	# Simulate time passing (less than rejuvenation time)
	monk.rejuvenation_timer = 61.0
	# Process one physics frame with delta to push past the threshold
	# The _physics_process increments rejuvenation_timer by delta
	# Since we set it to 61.0 and rejuvenation_time = 62.0, a 2s delta pushes it past
	monk._physics_process(2.0)

	if monk.is_rejuvenating:
		return Assertions.AssertResult.new(false,
			"Rejuvenation should have ended after timer exceeds 62s")
	return Assertions.AssertResult.new(true)


# =============================================================================
# Monastery Research Blocks Training
# =============================================================================

func test_monastery_research_blocks_training() -> Assertions.AssertResult:
	## A monastery that is_researching should not process training
	GameManager.set_age(GameManager.AGE_CASTLE, 0)
	GameManager.resources["gold"] = 1000
	GameManager.population_cap = 20
	var monastery = runner.spawner.spawn_monastery(Vector2(400, 400), 0)
	await runner.wait_frames(2)

	# Start research at the monastery
	monastery.start_research("fervor")
	if not monastery.is_researching:
		return Assertions.AssertResult.new(false, "Monastery should be researching fervor")

	# Queue a monk training
	var train_result = monastery.train_monk()
	if not train_result:
		return Assertions.AssertResult.new(false, "train_monk should succeed (adds to queue)")

	# Process some time — training should NOT progress because research blocks it
	monastery._process(1.0)

	if monastery.train_timer > 0.01:
		return Assertions.AssertResult.new(false,
			"Training timer should not advance during research, got: %.2f" % monastery.train_timer)
	return Assertions.AssertResult.new(true)


# =============================================================================
# Status Text
# =============================================================================

func test_monk_status_text_idle() -> Assertions.AssertResult:
	## Idle monk should report "Idle"
	var monk = runner.spawner.spawn_monk(Vector2(400, 400), 0)
	await runner.wait_frames(2)

	var status = monk.get_status_text()
	if status != "Idle":
		return Assertions.AssertResult.new(false,
			"Idle monk status should be 'Idle', got: '%s'" % status)
	return Assertions.AssertResult.new(true)


func test_monk_status_text_rejuvenating() -> Assertions.AssertResult:
	## Rejuvenating monk should report "Rejuvenating"
	var monk = runner.spawner.spawn_monk(Vector2(400, 400), 0)
	await runner.wait_frames(2)

	monk.is_rejuvenating = true
	var status = monk.get_status_text()
	if status != "Rejuvenating":
		return Assertions.AssertResult.new(false,
			"Rejuvenating monk status should be 'Rejuvenating', got: '%s'" % status)
	return Assertions.AssertResult.new(true)
