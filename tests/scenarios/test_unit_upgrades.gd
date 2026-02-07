extends Node
## Unit Upgrade Tests - Tests for Phase 5B Unit Upgrade System and Knight
##
## These tests verify:
## - Knight initial stats (HP, attack, armor, speed)
## - Knight group membership (military, cavalry, knights)
## - Knight training at Stable (cost deduction, queue)
## - Unit upgrade stat changes (militia -> man-at-arms)
## - Unit upgrade group swapping (old group removed, new group added)
## - Upgrade chain prerequisites (man_at_arms required before long_swordsman)
## - Research blocks training (barracks, archery_range, stable)
## - _apply_researched_upgrades for newly spawned units after upgrade research
## - Tech bonuses applied correctly after upgrade (base stats reset + reapply)

class_name TestUnitUpgrades

var runner: TestRunner


func _init(test_runner: TestRunner) -> void:
	runner = test_runner


func get_all_tests() -> Array[Callable]:
	## Returns all test methods to run
	return [
		# Knight stats and groups
		test_knight_initial_hp,
		test_knight_initial_attack,
		test_knight_initial_armor,
		test_knight_initial_speed,
		test_knight_group_membership,
		# Knight training at Stable
		test_knight_training_deducts_resources,
		test_knight_training_fails_without_food,
		test_knight_training_fails_without_gold,
		# Unit upgrade: militia -> man-at-arms
		test_militia_to_man_at_arms_stats,
		test_militia_to_man_at_arms_group_swap,
		test_militia_to_man_at_arms_display_name,
		test_militia_to_man_at_arms_hp_increase,
		# Unit upgrade: man-at-arms -> long swordsman (chain)
		test_long_swordsman_requires_man_at_arms,
		test_long_swordsman_upgrade_chain,
		# Unit upgrade: spearman -> pikeman
		test_spearman_to_pikeman_stats,
		test_spearman_to_pikeman_bonus_vs_cavalry,
		# Unit upgrade: archer -> crossbowman
		test_archer_to_crossbowman_stats,
		# Unit upgrade: scout_cavalry -> light_cavalry
		test_scout_to_light_cavalry_stats,
		# _apply_researched_upgrades for newly spawned units
		test_new_militia_spawns_as_man_at_arms,
		test_new_militia_spawns_as_long_swordsman_chain,
		# Tech bonuses reapplied after upgrade
		test_tech_bonus_reapplied_after_upgrade,
		# Only upgrades own team
		test_upgrade_only_affects_own_team,
		# Research blocks training
		test_barracks_research_blocks_training,
		test_archery_range_research_blocks_training,
		test_stable_research_blocks_training,
		# Knight age requirement
		test_knight_requires_castle_age,
	]


# =============================================================================
# Knight Stats and Group Tests
# =============================================================================

func test_knight_initial_hp() -> Assertions.AssertResult:
	## Knight should have 100 HP (AoE2 spec)
	var knight = runner.spawner.spawn_knight(Vector2(400, 400))
	await runner.wait_frames(2)

	if knight.max_hp != 100:
		return Assertions.AssertResult.new(false,
			"Knight max_hp should be 100, got: %d" % knight.max_hp)
	if knight.current_hp != 100:
		return Assertions.AssertResult.new(false,
			"Knight current_hp should be 100, got: %d" % knight.current_hp)
	return Assertions.AssertResult.new(true)


func test_knight_initial_attack() -> Assertions.AssertResult:
	## Knight should have 10 attack damage (AoE2 spec)
	var knight = runner.spawner.spawn_knight(Vector2(400, 400))
	await runner.wait_frames(2)

	if knight.attack_damage != 10:
		return Assertions.AssertResult.new(false,
			"Knight attack_damage should be 10, got: %d" % knight.attack_damage)
	return Assertions.AssertResult.new(true)


func test_knight_initial_armor() -> Assertions.AssertResult:
	## Knight should have 2/2 armor (AoE2 spec)
	var knight = runner.spawner.spawn_knight(Vector2(400, 400))
	await runner.wait_frames(2)

	if knight.melee_armor != 2:
		return Assertions.AssertResult.new(false,
			"Knight melee_armor should be 2, got: %d" % knight.melee_armor)
	if knight.pierce_armor != 2:
		return Assertions.AssertResult.new(false,
			"Knight pierce_armor should be 2, got: %d" % knight.pierce_armor)
	return Assertions.AssertResult.new(true)


func test_knight_initial_speed() -> Assertions.AssertResult:
	## Knight should have 140 move speed (fast cavalry)
	var knight = runner.spawner.spawn_knight(Vector2(400, 400))
	await runner.wait_frames(2)

	if abs(knight.move_speed - 140.0) > 0.1:
		return Assertions.AssertResult.new(false,
			"Knight move_speed should be 140, got: %.1f" % knight.move_speed)
	return Assertions.AssertResult.new(true)


func test_knight_group_membership() -> Assertions.AssertResult:
	## Knight should be in military, cavalry, and knights groups
	var knight = runner.spawner.spawn_knight(Vector2(400, 400))
	await runner.wait_frames(2)

	if not knight.is_in_group("military"):
		return Assertions.AssertResult.new(false,
			"Knight should be in 'military' group")
	if not knight.is_in_group("cavalry"):
		return Assertions.AssertResult.new(false,
			"Knight should be in 'cavalry' group")
	if not knight.is_in_group("knights"):
		return Assertions.AssertResult.new(false,
			"Knight should be in 'knights' group")
	if not knight.is_in_group("units"):
		return Assertions.AssertResult.new(false,
			"Knight should be in 'units' group")
	return Assertions.AssertResult.new(true)


# =============================================================================
# Knight Training Tests
# =============================================================================

func test_knight_training_deducts_resources() -> Assertions.AssertResult:
	## Training a knight should cost 60 food + 75 gold
	GameManager.resources["food"] = 200
	GameManager.resources["gold"] = 200
	GameManager.population_cap = 20
	var stable = runner.spawner.spawn_stable(Vector2(400, 400), 0)
	await runner.wait_frames(2)

	var result = stable.train_knight()
	if not result:
		return Assertions.AssertResult.new(false, "train_knight should succeed with enough resources")
	if GameManager.resources["food"] != 140:
		return Assertions.AssertResult.new(false,
			"Food should be 140 after training knight (200-60), got: %d" % GameManager.resources["food"])
	if GameManager.resources["gold"] != 125:
		return Assertions.AssertResult.new(false,
			"Gold should be 125 after training knight (200-75), got: %d" % GameManager.resources["gold"])
	return Assertions.AssertResult.new(true)


func test_knight_training_fails_without_food() -> Assertions.AssertResult:
	## Training a knight should fail without enough food
	GameManager.resources["food"] = 10
	GameManager.resources["gold"] = 200
	GameManager.population_cap = 20
	var stable = runner.spawner.spawn_stable(Vector2(400, 400), 0)
	await runner.wait_frames(2)

	var result = stable.train_knight()
	if result:
		return Assertions.AssertResult.new(false,
			"train_knight should fail with only 10 food (needs 60)")
	return Assertions.AssertResult.new(true)


func test_knight_training_fails_without_gold() -> Assertions.AssertResult:
	## Training a knight should fail without enough gold
	GameManager.resources["food"] = 200
	GameManager.resources["gold"] = 10
	GameManager.population_cap = 20
	var stable = runner.spawner.spawn_stable(Vector2(400, 400), 0)
	await runner.wait_frames(2)

	var result = stable.train_knight()
	if result:
		return Assertions.AssertResult.new(false,
			"train_knight should fail with only 10 gold (needs 75)")
	return Assertions.AssertResult.new(true)


# =============================================================================
# Unit Upgrade: Militia -> Man-at-Arms
# =============================================================================

func test_militia_to_man_at_arms_stats() -> Assertions.AssertResult:
	## Man-at-Arms upgrade should change militia stats: 45 HP, 6 attack
	GameManager.set_age(GameManager.AGE_FEUDAL, 0)
	var militia = runner.spawner.spawn_militia(Vector2(400, 400), 0)
	await runner.wait_frames(2)

	# Verify base militia stats first
	if militia.max_hp != 40:
		return Assertions.AssertResult.new(false,
			"Militia should start with 40 HP, got: %d" % militia.max_hp)
	if militia.attack_damage != 4:
		return Assertions.AssertResult.new(false,
			"Militia should start with 4 attack, got: %d" % militia.attack_damage)

	# Apply the man-at-arms upgrade via GameManager
	GameManager.complete_tech_research("man_at_arms", 0)
	await runner.wait_frames(2)

	if militia.max_hp != 45:
		return Assertions.AssertResult.new(false,
			"Man-at-Arms max_hp should be 45, got: %d" % militia.max_hp)
	if militia.attack_damage != 6:
		return Assertions.AssertResult.new(false,
			"Man-at-Arms attack_damage should be 6, got: %d" % militia.attack_damage)
	return Assertions.AssertResult.new(true)


func test_militia_to_man_at_arms_group_swap() -> Assertions.AssertResult:
	## Man-at-Arms upgrade should swap militia group to man_at_arms group
	GameManager.set_age(GameManager.AGE_FEUDAL, 0)
	var militia = runner.spawner.spawn_militia(Vector2(400, 400), 0)
	await runner.wait_frames(2)

	# Verify militia is in "militia" group
	if not militia.is_in_group("militia"):
		return Assertions.AssertResult.new(false,
			"Unit should be in 'militia' group before upgrade")

	GameManager.complete_tech_research("man_at_arms", 0)
	await runner.wait_frames(2)

	if militia.is_in_group("militia"):
		return Assertions.AssertResult.new(false,
			"Unit should NOT be in 'militia' group after Man-at-Arms upgrade")
	if not militia.is_in_group("man_at_arms"):
		return Assertions.AssertResult.new(false,
			"Unit should be in 'man_at_arms' group after Man-at-Arms upgrade")
	# Should still be in infantry and military
	if not militia.is_in_group("infantry"):
		return Assertions.AssertResult.new(false,
			"Unit should still be in 'infantry' group after upgrade")
	if not militia.is_in_group("military"):
		return Assertions.AssertResult.new(false,
			"Unit should still be in 'military' group after upgrade")
	return Assertions.AssertResult.new(true)


func test_militia_to_man_at_arms_display_name() -> Assertions.AssertResult:
	## Man-at-Arms upgrade should set the display name
	GameManager.set_age(GameManager.AGE_FEUDAL, 0)
	var militia = runner.spawner.spawn_militia(Vector2(400, 400), 0)
	await runner.wait_frames(2)

	GameManager.complete_tech_research("man_at_arms", 0)
	await runner.wait_frames(2)

	if militia.unit_display_name != "Man-at-Arms":
		return Assertions.AssertResult.new(false,
			"Display name should be 'Man-at-Arms', got: '%s'" % militia.unit_display_name)
	return Assertions.AssertResult.new(true)


func test_militia_to_man_at_arms_hp_increase() -> Assertions.AssertResult:
	## Upgrade should increase current HP by the delta (40->45 = +5)
	GameManager.set_age(GameManager.AGE_FEUDAL, 0)
	var militia = runner.spawner.spawn_militia(Vector2(400, 400), 0)
	await runner.wait_frames(2)

	# Damage militia a bit first
	militia.current_hp = 30  # Damaged from 40

	GameManager.complete_tech_research("man_at_arms", 0)
	await runner.wait_frames(2)

	# max_hp goes 40->45 = +5, so current_hp should go 30+5=35
	if militia.current_hp != 35:
		return Assertions.AssertResult.new(false,
			"Current HP should increase by delta (30+5=35), got: %d" % militia.current_hp)
	if militia.max_hp != 45:
		return Assertions.AssertResult.new(false,
			"Max HP should be 45, got: %d" % militia.max_hp)
	return Assertions.AssertResult.new(true)


# =============================================================================
# Upgrade Chain: Man-at-Arms -> Long Swordsman
# =============================================================================

func test_long_swordsman_requires_man_at_arms() -> Assertions.AssertResult:
	## Long Swordsman requires "man_at_arms" prerequisite
	GameManager.set_age(GameManager.AGE_CASTLE, 0)
	GameManager.resources["food"] = 1000
	GameManager.resources["gold"] = 1000

	# Should not be researchable without man_at_arms
	if GameManager.can_research_tech("long_swordsman", 0):
		return Assertions.AssertResult.new(false,
			"Long Swordsman should require Man-at-Arms prerequisite")
	return Assertions.AssertResult.new(true)


func test_long_swordsman_upgrade_chain() -> Assertions.AssertResult:
	## Applying man-at-arms then long swordsman should produce correct final stats
	GameManager.set_age(GameManager.AGE_CASTLE, 0)
	var militia = runner.spawner.spawn_militia(Vector2(400, 400), 0)
	await runner.wait_frames(2)

	# First upgrade: militia -> man-at-arms
	GameManager.complete_tech_research("man_at_arms", 0)
	await runner.wait_frames(2)

	if militia.max_hp != 45:
		return Assertions.AssertResult.new(false,
			"After Man-at-Arms, HP should be 45, got: %d" % militia.max_hp)

	# Second upgrade: man-at-arms -> long swordsman
	GameManager.complete_tech_research("long_swordsman", 0)
	await runner.wait_frames(2)

	if militia.max_hp != 55:
		return Assertions.AssertResult.new(false,
			"After Long Swordsman, HP should be 55, got: %d" % militia.max_hp)
	if militia.attack_damage != 9:
		return Assertions.AssertResult.new(false,
			"After Long Swordsman, attack should be 9, got: %d" % militia.attack_damage)
	if not militia.is_in_group("long_swordsmen"):
		return Assertions.AssertResult.new(false,
			"Unit should be in 'long_swordsmen' group after Long Swordsman upgrade")
	if militia.is_in_group("man_at_arms"):
		return Assertions.AssertResult.new(false,
			"Unit should NOT be in 'man_at_arms' group after Long Swordsman upgrade")
	if militia.unit_display_name != "Long Swordsman":
		return Assertions.AssertResult.new(false,
			"Display name should be 'Long Swordsman', got: '%s'" % militia.unit_display_name)
	return Assertions.AssertResult.new(true)


# =============================================================================
# Unit Upgrade: Spearman -> Pikeman
# =============================================================================

func test_spearman_to_pikeman_stats() -> Assertions.AssertResult:
	## Pikeman upgrade should set correct stats: 55 HP, 4 atk, 1/0 armor
	GameManager.set_age(GameManager.AGE_CASTLE, 0)
	var spearman = runner.spawner.spawn_spearman(Vector2(400, 400), 0)
	await runner.wait_frames(2)

	GameManager.complete_tech_research("pikeman", 0)
	await runner.wait_frames(2)

	if spearman.max_hp != 55:
		return Assertions.AssertResult.new(false,
			"Pikeman max_hp should be 55, got: %d" % spearman.max_hp)
	if spearman.attack_damage != 4:
		return Assertions.AssertResult.new(false,
			"Pikeman attack_damage should be 4, got: %d" % spearman.attack_damage)
	if spearman.melee_armor != 1:
		return Assertions.AssertResult.new(false,
			"Pikeman melee_armor should be 1, got: %d" % spearman.melee_armor)
	if not spearman.is_in_group("pikemen"):
		return Assertions.AssertResult.new(false,
			"Unit should be in 'pikemen' group after upgrade")
	if spearman.is_in_group("spearmen"):
		return Assertions.AssertResult.new(false,
			"Unit should NOT be in 'spearmen' group after upgrade")
	return Assertions.AssertResult.new(true)


func test_spearman_to_pikeman_bonus_vs_cavalry() -> Assertions.AssertResult:
	## Pikeman should have bonus_vs_cavalry = 22
	GameManager.set_age(GameManager.AGE_CASTLE, 0)
	var spearman = runner.spawner.spawn_spearman(Vector2(400, 400), 0)
	await runner.wait_frames(2)

	GameManager.complete_tech_research("pikeman", 0)
	await runner.wait_frames(2)

	if spearman.bonus_vs_cavalry != 22:
		return Assertions.AssertResult.new(false,
			"Pikeman bonus_vs_cavalry should be 22, got: %d" % spearman.bonus_vs_cavalry)
	return Assertions.AssertResult.new(true)


# =============================================================================
# Unit Upgrade: Archer -> Crossbowman
# =============================================================================

func test_archer_to_crossbowman_stats() -> Assertions.AssertResult:
	## Crossbowman upgrade: 35 HP, 5 attack, 160 range
	GameManager.set_age(GameManager.AGE_CASTLE, 0)
	var archer = runner.spawner.spawn_archer(Vector2(400, 400), 0)
	await runner.wait_frames(2)

	GameManager.complete_tech_research("crossbowman", 0)
	await runner.wait_frames(2)

	if archer.max_hp != 35:
		return Assertions.AssertResult.new(false,
			"Crossbowman max_hp should be 35, got: %d" % archer.max_hp)
	if archer.attack_damage != 5:
		return Assertions.AssertResult.new(false,
			"Crossbowman attack_damage should be 5, got: %d" % archer.attack_damage)
	if abs(archer.attack_range - 160.0) > 0.5:
		return Assertions.AssertResult.new(false,
			"Crossbowman attack_range should be 160.0, got: %.1f" % archer.attack_range)
	if not archer.is_in_group("crossbowmen"):
		return Assertions.AssertResult.new(false,
			"Unit should be in 'crossbowmen' group after upgrade")
	if archer.is_in_group("archers_line"):
		return Assertions.AssertResult.new(false,
			"Unit should NOT be in 'archers_line' group after upgrade")
	return Assertions.AssertResult.new(true)


# =============================================================================
# Unit Upgrade: Scout Cavalry -> Light Cavalry
# =============================================================================

func test_scout_to_light_cavalry_stats() -> Assertions.AssertResult:
	## Light Cavalry upgrade: 60 HP, 7 atk, 0/2 armor
	GameManager.set_age(GameManager.AGE_CASTLE, 0)
	var scout = runner.spawner.spawn_scout_cavalry(Vector2(400, 400), 0)
	await runner.wait_frames(2)

	GameManager.complete_tech_research("light_cavalry", 0)
	await runner.wait_frames(2)

	if scout.max_hp != 60:
		return Assertions.AssertResult.new(false,
			"Light Cavalry max_hp should be 60, got: %d" % scout.max_hp)
	if scout.attack_damage != 7:
		return Assertions.AssertResult.new(false,
			"Light Cavalry attack_damage should be 7, got: %d" % scout.attack_damage)
	if scout.melee_armor != 0:
		return Assertions.AssertResult.new(false,
			"Light Cavalry melee_armor should be 0, got: %d" % scout.melee_armor)
	if scout.pierce_armor != 2:
		return Assertions.AssertResult.new(false,
			"Light Cavalry pierce_armor should be 2, got: %d" % scout.pierce_armor)
	if not scout.is_in_group("light_cavalry"):
		return Assertions.AssertResult.new(false,
			"Unit should be in 'light_cavalry' group after upgrade")
	if scout.is_in_group("scout_cavalry"):
		return Assertions.AssertResult.new(false,
			"Unit should NOT be in 'scout_cavalry' group after upgrade")
	return Assertions.AssertResult.new(true)


# =============================================================================
# _apply_researched_upgrades for Newly Spawned Units
# =============================================================================

func test_new_militia_spawns_as_man_at_arms() -> Assertions.AssertResult:
	## A militia spawned after Man-at-Arms is researched should auto-apply the upgrade
	GameManager.set_age(GameManager.AGE_FEUDAL, 0)
	GameManager.complete_tech_research("man_at_arms", 0)
	await runner.wait_frames(2)

	# Now spawn a new militia - it should auto-upgrade to Man-at-Arms
	var militia = runner.spawner.spawn_militia(Vector2(400, 400), 0)
	await runner.wait_frames(2)

	if militia.max_hp != 45:
		return Assertions.AssertResult.new(false,
			"Newly spawned militia should have Man-at-Arms HP (45), got: %d" % militia.max_hp)
	if militia.attack_damage != 6:
		return Assertions.AssertResult.new(false,
			"Newly spawned militia should have Man-at-Arms attack (6), got: %d" % militia.attack_damage)
	if not militia.is_in_group("man_at_arms"):
		return Assertions.AssertResult.new(false,
			"Newly spawned militia should be in 'man_at_arms' group")
	if militia.is_in_group("militia"):
		return Assertions.AssertResult.new(false,
			"Newly spawned militia should NOT be in 'militia' group after auto-upgrade")
	if militia.unit_display_name != "Man-at-Arms":
		return Assertions.AssertResult.new(false,
			"Newly spawned militia display_name should be 'Man-at-Arms', got: '%s'" % militia.unit_display_name)
	return Assertions.AssertResult.new(true)


func test_new_militia_spawns_as_long_swordsman_chain() -> Assertions.AssertResult:
	## A militia spawned after both Man-at-Arms AND Long Swordsman are researched should chain both upgrades
	GameManager.set_age(GameManager.AGE_CASTLE, 0)
	GameManager.complete_tech_research("man_at_arms", 0)
	GameManager.complete_tech_research("long_swordsman", 0)
	await runner.wait_frames(2)

	var militia = runner.spawner.spawn_militia(Vector2(400, 400), 0)
	await runner.wait_frames(2)

	if militia.max_hp != 55:
		return Assertions.AssertResult.new(false,
			"Chained spawn should have Long Swordsman HP (55), got: %d" % militia.max_hp)
	if militia.attack_damage != 9:
		return Assertions.AssertResult.new(false,
			"Chained spawn should have Long Swordsman attack (9), got: %d" % militia.attack_damage)
	if not militia.is_in_group("long_swordsmen"):
		return Assertions.AssertResult.new(false,
			"Chained spawn should be in 'long_swordsmen' group")
	if militia.unit_display_name != "Long Swordsman":
		return Assertions.AssertResult.new(false,
			"Chained spawn display_name should be 'Long Swordsman', got: '%s'" % militia.unit_display_name)
	return Assertions.AssertResult.new(true)


# =============================================================================
# Tech Bonuses After Upgrade
# =============================================================================

func test_tech_bonus_reapplied_after_upgrade() -> Assertions.AssertResult:
	## After upgrading militia -> man-at-arms, forging bonus (+1 infantry_attack) should still apply
	GameManager.set_age(GameManager.AGE_FEUDAL, 0)

	var militia = runner.spawner.spawn_militia(Vector2(400, 400), 0)
	await runner.wait_frames(2)

	# Research forging first (gives +1 infantry attack)
	GameManager.complete_tech_research("forging", 0)
	await runner.wait_frames(2)

	# Militia should have 4 + 1 = 5 attack
	if militia.attack_damage != 5:
		return Assertions.AssertResult.new(false,
			"Militia with forging should have 5 attack, got: %d" % militia.attack_damage)

	# Now upgrade to Man-at-Arms (base 6 attack)
	GameManager.complete_tech_research("man_at_arms", 0)
	await runner.wait_frames(2)

	# Man-at-Arms base is 6, + forging 1 = 7
	if militia.attack_damage != 7:
		return Assertions.AssertResult.new(false,
			"Man-at-Arms with forging should have 7 attack (6+1), got: %d" % militia.attack_damage)
	return Assertions.AssertResult.new(true)


# =============================================================================
# Team Isolation
# =============================================================================

func test_upgrade_only_affects_own_team() -> Assertions.AssertResult:
	## Upgrading player militia should not affect AI militia
	GameManager.set_age(GameManager.AGE_FEUDAL, 0)
	var player_militia = runner.spawner.spawn_militia(Vector2(400, 400), 0)
	var ai_militia = runner.spawner.spawn_militia(Vector2(600, 400), 1)
	await runner.wait_frames(2)

	GameManager.complete_tech_research("man_at_arms", 0)
	await runner.wait_frames(2)

	# Player militia should be upgraded
	if player_militia.max_hp != 45:
		return Assertions.AssertResult.new(false,
			"Player militia should be upgraded to 45 HP, got: %d" % player_militia.max_hp)
	# AI militia should be unchanged
	if ai_militia.max_hp != 40:
		return Assertions.AssertResult.new(false,
			"AI militia should remain at 40 HP, got: %d" % ai_militia.max_hp)
	if not ai_militia.is_in_group("militia"):
		return Assertions.AssertResult.new(false,
			"AI militia should still be in 'militia' group")
	return Assertions.AssertResult.new(true)


# =============================================================================
# Research Blocks Training
# =============================================================================

func test_barracks_research_blocks_training() -> Assertions.AssertResult:
	## A barracks that is_researching should not process training
	GameManager.set_age(GameManager.AGE_FEUDAL, 0)
	GameManager.resources["food"] = 1000
	GameManager.resources["wood"] = 1000
	GameManager.resources["gold"] = 1000
	GameManager.population_cap = 20
	var barracks = runner.spawner.spawn_barracks(Vector2(400, 400), 0)
	await runner.wait_frames(2)

	# Start a research at the barracks
	barracks.start_research("man_at_arms")
	if not barracks.is_researching:
		return Assertions.AssertResult.new(false, "Barracks should be researching man_at_arms")

	# Queue a militia training
	var train_result = barracks.train_militia()
	if not train_result:
		return Assertions.AssertResult.new(false, "train_militia should succeed (adds to queue)")

	# Simulate some frames - training should NOT progress because research blocks it
	var initial_timer = barracks.train_timer
	# The _process function checks is_researching first and returns early,
	# so train_timer should not advance while researching
	# We need to manually call _process to test this
	barracks._process(1.0)

	# Research should have progressed, but training timer should not have changed
	# (because _process returns after processing research when is_researching is true)
	# The training won't start until after research completes because _start_next_training
	# is called from _complete_research
	if barracks.train_timer > 0.01:
		return Assertions.AssertResult.new(false,
			"Training timer should not advance during research, got: %.2f" % barracks.train_timer)
	return Assertions.AssertResult.new(true)


func test_archery_range_research_blocks_training() -> Assertions.AssertResult:
	## An archery range that is_researching should not process training
	GameManager.set_age(GameManager.AGE_CASTLE, 0)
	GameManager.resources["food"] = 1000
	GameManager.resources["wood"] = 1000
	GameManager.resources["gold"] = 1000
	GameManager.population_cap = 20
	var ar = runner.spawner.spawn_archery_range(Vector2(400, 400), 0)
	await runner.wait_frames(2)

	# Start crossbowman research
	ar.start_research("crossbowman")
	if not ar.is_researching:
		return Assertions.AssertResult.new(false, "Archery Range should be researching crossbowman")

	# Try queueing an archer
	var train_result = ar.train_archer()
	if not train_result:
		return Assertions.AssertResult.new(false, "train_archer should succeed (adds to queue)")

	# Process a frame - training should not advance
	ar._process(1.0)
	if ar.train_timer > 0.01:
		return Assertions.AssertResult.new(false,
			"Training timer should not advance during research, got: %.2f" % ar.train_timer)
	return Assertions.AssertResult.new(true)


func test_stable_research_blocks_training() -> Assertions.AssertResult:
	## A stable that is_researching should not process training
	GameManager.set_age(GameManager.AGE_CASTLE, 0)
	GameManager.resources["food"] = 1000
	GameManager.resources["wood"] = 1000
	GameManager.resources["gold"] = 1000
	GameManager.population_cap = 20
	var stable = runner.spawner.spawn_stable(Vector2(400, 400), 0)
	await runner.wait_frames(2)

	# Start light_cavalry research
	stable.start_research("light_cavalry")
	if not stable.is_researching:
		return Assertions.AssertResult.new(false, "Stable should be researching light_cavalry")

	# Queue a scout cavalry
	var train_result = stable.train_scout_cavalry()
	if not train_result:
		return Assertions.AssertResult.new(false, "train_scout_cavalry should succeed (adds to queue)")

	# Process a frame - training should not advance
	stable._process(1.0)
	if stable.train_timer > 0.01:
		return Assertions.AssertResult.new(false,
			"Training timer should not advance during research, got: %.2f" % stable.train_timer)
	return Assertions.AssertResult.new(true)


# =============================================================================
# Age Requirement
# =============================================================================

func test_knight_requires_castle_age() -> Assertions.AssertResult:
	## Knight should require Castle Age
	var required_age = GameManager.UNIT_AGE_REQUIREMENTS.get("knight", GameManager.AGE_DARK)
	if required_age != GameManager.AGE_CASTLE:
		return Assertions.AssertResult.new(false,
			"Knight should require Castle Age, got age: %d" % required_age)
	# In Dark Age: should be locked
	if GameManager.is_unit_unlocked("knight", 0):
		return Assertions.AssertResult.new(false, "Knight should be locked in Dark Age")
	# In Castle Age: should be unlocked
	GameManager.set_age(GameManager.AGE_CASTLE, 0)
	if not GameManager.is_unit_unlocked("knight", 0):
		return Assertions.AssertResult.new(false, "Knight should be unlocked in Castle Age")
	return Assertions.AssertResult.new(true)
