extends Node
## Phase 8B Tests - Siege Workshop + Siege Units
##
## These tests verify:
## - Siege Workshop building stats and group membership
## - Siege Workshop age requirement (Castle Age)
## - Siege Workshop training costs and queue system
## - Siege Workshop _destroy() refund of queued training resources
## - Battering Ram stats (HP, attack, armor, bonus_vs_buildings)
## - Battering Ram building-only targeting (command_attack)
## - Battering Ram garrison system (can_garrison_in_ram, garrison_in_ram, capacity)
## - Battering Ram ungarrison on death
## - Mangonel stats (HP, attack, armor, range, min_range)
## - Mangonel area splash damage and friendly fire
## - Mangonel minimum range enforcement
## - Scorpion stats (HP, attack, armor, range)
## - Scorpion pass-through line geometry (_point_near_line_segment)
## - Scorpion pass-through no friendly fire
## - Siege unit tech upgrade TECHNOLOGIES entries (capped_ram, onager, heavy_scorpion)
## - Building garrison exclusion for siege units

class_name TestPhase8B

var runner: TestRunner


func _init(test_runner: TestRunner) -> void:
	runner = test_runner


func get_all_tests() -> Array[Callable]:
	return [
		# Siege Workshop building tests
		test_siege_workshop_stats,
		test_siege_workshop_group_membership,
		test_siege_workshop_age_requirement,
		# Siege Workshop training costs
		test_train_battering_ram_cost,
		test_train_mangonel_cost,
		test_train_scorpion_cost,
		test_train_insufficient_resources,
		test_train_queue_max_size,
		# Siege Workshop cancel and refund
		test_cancel_training_refunds_resources,
		test_destroy_refunds_all_queued,
		# Battering Ram stat tests
		test_battering_ram_stats,
		test_battering_ram_group_membership,
		test_battering_ram_bonus_vs_buildings,
		# Battering Ram targeting
		test_ram_command_attack_building,
		test_ram_command_attack_siege_unit,
		test_ram_ignores_non_building_non_siege,
		test_ram_no_auto_aggro,
		# Battering Ram garrison system
		test_ram_garrison_infantry,
		test_ram_garrison_capacity_limit,
		test_ram_garrison_rejects_cavalry,
		test_ram_garrison_rejects_wrong_team,
		test_ram_garrison_rejects_dead_unit,
		test_ram_ungarrison_all,
		test_ram_ejects_garrison_on_death,
		# Mangonel stat tests
		test_mangonel_stats,
		test_mangonel_group_membership,
		test_mangonel_min_range,
		# Mangonel area splash
		test_mangonel_splash_damage_calculation,
		test_mangonel_splash_hits_friendlies,
		test_mangonel_splash_does_not_hit_self,
		# Scorpion stat tests
		test_scorpion_stats,
		test_scorpion_group_membership,
		# Scorpion pass-through geometry
		test_point_near_line_on_line,
		test_point_near_line_off_line,
		test_point_near_line_past_endpoint,
		# Scorpion pass-through no friendly fire
		test_scorpion_no_friendly_fire,
		# Siege unit tech upgrade entries
		test_capped_ram_tech_entry,
		test_onager_tech_entry,
		test_heavy_scorpion_tech_entry,
		# Building garrison exclusion
		test_building_garrison_rejects_siege,
	]


# =============================================================================
# Siege Workshop Building Tests
# =============================================================================

func test_siege_workshop_stats() -> Assertions.AssertResult:
	## Siege Workshop should have correct stats from AoE2 spec
	GameManager.set_age(GameManager.AGE_CASTLE, 0)
	var sw = runner.spawner.spawn_siege_workshop(Vector2(200, 200), 0)
	await runner.wait_frames(2)

	if sw.max_hp != 2100:
		return Assertions.AssertResult.new(false,
			"Siege Workshop max_hp should be 2100, got: %d" % sw.max_hp)
	if sw.wood_cost != 200:
		return Assertions.AssertResult.new(false,
			"Siege Workshop wood_cost should be 200, got: %d" % sw.wood_cost)
	if sw.building_name != "Siege Workshop":
		return Assertions.AssertResult.new(false,
			"Siege Workshop building_name should be 'Siege Workshop', got: '%s'" % sw.building_name)
	if sw.size != Vector2i(3, 3):
		return Assertions.AssertResult.new(false,
			"Siege Workshop size should be (3,3), got: %s" % str(sw.size))
	if sw.garrison_capacity != 10:
		return Assertions.AssertResult.new(false,
			"Siege Workshop garrison_capacity should be 10, got: %d" % sw.garrison_capacity)
	return Assertions.AssertResult.new(true)


func test_siege_workshop_group_membership() -> Assertions.AssertResult:
	## Siege Workshop should be in correct groups
	GameManager.set_age(GameManager.AGE_CASTLE, 0)
	var sw = runner.spawner.spawn_siege_workshop(Vector2(200, 200), 0)
	await runner.wait_frames(2)

	if not sw.is_in_group("siege_workshops"):
		return Assertions.AssertResult.new(false, "Siege Workshop should be in 'siege_workshops' group")
	if not sw.is_in_group("buildings"):
		return Assertions.AssertResult.new(false, "Siege Workshop should be in 'buildings' group")
	return Assertions.AssertResult.new(true)


func test_siege_workshop_age_requirement() -> Assertions.AssertResult:
	## Siege Workshop requires Castle Age to build
	var required = GameManager.BUILDING_AGE_REQUIREMENTS.get("siege_workshop", GameManager.AGE_DARK)
	if required != GameManager.AGE_CASTLE:
		return Assertions.AssertResult.new(false,
			"Siege Workshop should require Castle Age, got: %d" % required)
	# Dark Age: should be locked
	if GameManager.is_building_unlocked("siege_workshop", 0):
		return Assertions.AssertResult.new(false, "Siege Workshop should be locked in Dark Age")
	# Castle Age: should be unlocked
	GameManager.set_age(GameManager.AGE_CASTLE, 0)
	if not GameManager.is_building_unlocked("siege_workshop", 0):
		return Assertions.AssertResult.new(false, "Siege Workshop should be unlocked in Castle Age")
	return Assertions.AssertResult.new(true)


# =============================================================================
# Siege Workshop Training Costs
# =============================================================================

func test_train_battering_ram_cost() -> Assertions.AssertResult:
	## Training a Battering Ram should cost 160W + 75G
	GameManager.set_age(GameManager.AGE_CASTLE, 0)
	GameManager.resources["wood"] = 500
	GameManager.resources["gold"] = 500
	GameManager.population = 0
	GameManager.population_cap = 10
	var sw = runner.spawner.spawn_siege_workshop(Vector2(200, 200), 0)
	await runner.wait_frames(2)

	var result = sw.train_battering_ram()
	if not result:
		return Assertions.AssertResult.new(false, "train_battering_ram() should return true with sufficient resources")
	if GameManager.resources["wood"] != 340:
		return Assertions.AssertResult.new(false,
			"Wood after training ram should be 340 (500-160), got: %d" % GameManager.resources["wood"])
	if GameManager.resources["gold"] != 425:
		return Assertions.AssertResult.new(false,
			"Gold after training ram should be 425 (500-75), got: %d" % GameManager.resources["gold"])
	if sw.training_queue.size() != 1:
		return Assertions.AssertResult.new(false,
			"Queue should have 1 item, got: %d" % sw.training_queue.size())
	return Assertions.AssertResult.new(true)


func test_train_mangonel_cost() -> Assertions.AssertResult:
	## Training a Mangonel should cost 160W + 135G
	GameManager.set_age(GameManager.AGE_CASTLE, 0)
	GameManager.resources["wood"] = 500
	GameManager.resources["gold"] = 500
	GameManager.population = 0
	GameManager.population_cap = 10
	var sw = runner.spawner.spawn_siege_workshop(Vector2(200, 200), 0)
	await runner.wait_frames(2)

	var result = sw.train_mangonel()
	if not result:
		return Assertions.AssertResult.new(false, "train_mangonel() should return true with sufficient resources")
	if GameManager.resources["wood"] != 340:
		return Assertions.AssertResult.new(false,
			"Wood after training mangonel should be 340 (500-160), got: %d" % GameManager.resources["wood"])
	if GameManager.resources["gold"] != 365:
		return Assertions.AssertResult.new(false,
			"Gold after training mangonel should be 365 (500-135), got: %d" % GameManager.resources["gold"])
	return Assertions.AssertResult.new(true)


func test_train_scorpion_cost() -> Assertions.AssertResult:
	## Training a Scorpion should cost 75W + 75G
	GameManager.set_age(GameManager.AGE_CASTLE, 0)
	GameManager.resources["wood"] = 500
	GameManager.resources["gold"] = 500
	GameManager.population = 0
	GameManager.population_cap = 10
	var sw = runner.spawner.spawn_siege_workshop(Vector2(200, 200), 0)
	await runner.wait_frames(2)

	var result = sw.train_scorpion()
	if not result:
		return Assertions.AssertResult.new(false, "train_scorpion() should return true with sufficient resources")
	if GameManager.resources["wood"] != 425:
		return Assertions.AssertResult.new(false,
			"Wood after training scorpion should be 425 (500-75), got: %d" % GameManager.resources["wood"])
	if GameManager.resources["gold"] != 425:
		return Assertions.AssertResult.new(false,
			"Gold after training scorpion should be 425 (500-75), got: %d" % GameManager.resources["gold"])
	return Assertions.AssertResult.new(true)


func test_train_insufficient_resources() -> Assertions.AssertResult:
	## Training should fail when resources are insufficient
	GameManager.set_age(GameManager.AGE_CASTLE, 0)
	GameManager.resources["wood"] = 50  # Not enough for any siege unit
	GameManager.resources["gold"] = 50
	GameManager.population = 0
	GameManager.population_cap = 10
	var sw = runner.spawner.spawn_siege_workshop(Vector2(200, 200), 0)
	await runner.wait_frames(2)

	if sw.train_battering_ram():
		return Assertions.AssertResult.new(false, "train_battering_ram should fail with 50W (needs 160)")
	if sw.train_mangonel():
		return Assertions.AssertResult.new(false, "train_mangonel should fail with 50W (needs 160)")
	if sw.train_scorpion():
		return Assertions.AssertResult.new(false, "train_scorpion should fail with 50W (needs 75)")
	# Resources should not have changed
	if GameManager.resources["wood"] != 50:
		return Assertions.AssertResult.new(false,
			"Wood should remain 50 after failed training, got: %d" % GameManager.resources["wood"])
	return Assertions.AssertResult.new(true)


func test_train_queue_max_size() -> Assertions.AssertResult:
	## Queue should be limited to MAX_QUEUE_SIZE (15)
	GameManager.set_age(GameManager.AGE_CASTLE, 0)
	GameManager.resources["wood"] = 99999
	GameManager.resources["gold"] = 99999
	GameManager.population = 0
	GameManager.population_cap = 200
	var sw = runner.spawner.spawn_siege_workshop(Vector2(200, 200), 0)
	await runner.wait_frames(2)

	# Fill queue to max
	for i in range(15):
		sw.train_scorpion()  # Cheapest unit

	if sw.training_queue.size() != 15:
		return Assertions.AssertResult.new(false,
			"Queue should have 15 items, got: %d" % sw.training_queue.size())

	# 16th should fail
	var result = sw.train_scorpion()
	if result:
		return Assertions.AssertResult.new(false, "16th training should fail (queue full)")
	return Assertions.AssertResult.new(true)


# =============================================================================
# Siege Workshop Cancel and Refund
# =============================================================================

func test_cancel_training_refunds_resources() -> Assertions.AssertResult:
	## Cancelling training should refund the unit's cost
	GameManager.set_age(GameManager.AGE_CASTLE, 0)
	GameManager.resources["wood"] = 500
	GameManager.resources["gold"] = 500
	GameManager.population = 0
	GameManager.population_cap = 10
	var sw = runner.spawner.spawn_siege_workshop(Vector2(200, 200), 0)
	await runner.wait_frames(2)

	sw.train_battering_ram()  # costs 160W + 75G
	# After training: 340W, 425G
	sw.cancel_training()
	# After cancel: should be back to 500W, 500G
	if GameManager.resources["wood"] != 500:
		return Assertions.AssertResult.new(false,
			"Wood should be refunded to 500, got: %d" % GameManager.resources["wood"])
	if GameManager.resources["gold"] != 500:
		return Assertions.AssertResult.new(false,
			"Gold should be refunded to 500, got: %d" % GameManager.resources["gold"])
	return Assertions.AssertResult.new(true)


func test_destroy_refunds_all_queued() -> Assertions.AssertResult:
	## Destroying a Siege Workshop should refund all queued training resources
	GameManager.set_age(GameManager.AGE_CASTLE, 0)
	GameManager.resources["wood"] = 99999
	GameManager.resources["gold"] = 99999
	GameManager.population = 0
	GameManager.population_cap = 200
	var sw = runner.spawner.spawn_siege_workshop(Vector2(200, 200), 0)
	await runner.wait_frames(2)

	# Queue one of each
	sw.train_battering_ram()  # 160W + 75G
	sw.train_mangonel()       # 160W + 135G
	sw.train_scorpion()       # 75W + 75G
	# Total spent: 395W + 285G

	var wood_before_destroy = GameManager.resources["wood"]
	var gold_before_destroy = GameManager.resources["gold"]

	# Destroy the workshop
	sw._destroy()
	await runner.wait_frames(2)

	# After _destroy(), the 3 queued items minus the first (which was already started
	# and is at front of queue) should all be refunded. But _destroy() iterates
	# ALL items in training_queue, so all should be refunded.
	var wood_after = GameManager.resources["wood"]
	var gold_after = GameManager.resources["gold"]
	var wood_refund = wood_after - wood_before_destroy
	var gold_refund = gold_after - gold_before_destroy

	# Total refund should be 160+160+75 = 395W and 75+135+75 = 285G
	if wood_refund != 395:
		return Assertions.AssertResult.new(false,
			"Wood refund on destroy should be 395, got: %d" % wood_refund)
	if gold_refund != 285:
		return Assertions.AssertResult.new(false,
			"Gold refund on destroy should be 285, got: %d" % gold_refund)
	return Assertions.AssertResult.new(true)


# =============================================================================
# Battering Ram Stat Tests
# =============================================================================

func test_battering_ram_stats() -> Assertions.AssertResult:
	## Battering Ram should have correct stats from AoE2 spec
	var ram = runner.spawner.spawn_battering_ram(Vector2(300, 300), 0)
	await runner.wait_frames(2)

	if ram.max_hp != 175:
		return Assertions.AssertResult.new(false,
			"Ram max_hp should be 175, got: %d" % ram.max_hp)
	if ram.attack_damage != 2:
		return Assertions.AssertResult.new(false,
			"Ram attack_damage should be 2, got: %d" % ram.attack_damage)
	if ram.melee_armor != 0:
		return Assertions.AssertResult.new(false,
			"Ram melee_armor should be 0, got: %d" % ram.melee_armor)
	if ram.pierce_armor != 180:
		return Assertions.AssertResult.new(false,
			"Ram pierce_armor should be 180, got: %d" % ram.pierce_armor)
	if ram.bonus_vs_buildings != 125:
		return Assertions.AssertResult.new(false,
			"Ram bonus_vs_buildings should be 125, got: %d" % ram.bonus_vs_buildings)
	if abs(ram.move_speed - 50.0) > 0.1:
		return Assertions.AssertResult.new(false,
			"Ram move_speed should be 50.0, got: %.1f" % ram.move_speed)
	return Assertions.AssertResult.new(true)


func test_battering_ram_group_membership() -> Assertions.AssertResult:
	## Battering Ram should be in correct groups
	var ram = runner.spawner.spawn_battering_ram(Vector2(300, 300), 0)
	await runner.wait_frames(2)

	if not ram.is_in_group("military"):
		return Assertions.AssertResult.new(false, "Ram should be in 'military' group")
	if not ram.is_in_group("siege"):
		return Assertions.AssertResult.new(false, "Ram should be in 'siege' group")
	if not ram.is_in_group("battering_rams"):
		return Assertions.AssertResult.new(false, "Ram should be in 'battering_rams' group")
	if not ram.is_in_group("units"):
		return Assertions.AssertResult.new(false, "Ram should be in 'units' group")
	return Assertions.AssertResult.new(true)


func test_battering_ram_bonus_vs_buildings() -> Assertions.AssertResult:
	## Ram's bonus damage should apply against buildings but not against siege
	var ram = runner.spawner.spawn_battering_ram(Vector2(300, 300), 0)
	var building = runner.spawner.spawn_house(Vector2(330, 300), 1)
	await runner.wait_frames(2)

	var hp_before = building.current_hp
	# Simulate the ram attacking the building (melee damage + bonus_vs_buildings)
	# Ram's attack: 2 base, melee type, +125 bonus. Building has melee armor.
	var building_melee_armor = building.melee_armor
	var expected_base_dmg = max(1, ram.attack_damage - building_melee_armor)
	var expected_total = expected_base_dmg + ram.bonus_vs_buildings
	building.take_damage(ram.attack_damage, "melee", ram.bonus_vs_buildings, ram)
	var actual_dmg = hp_before - building.current_hp

	if actual_dmg != expected_total:
		return Assertions.AssertResult.new(false,
			"Ram vs building damage should be %d (base %d + bonus %d), got: %d" % [
				expected_total, expected_base_dmg, ram.bonus_vs_buildings, actual_dmg])
	return Assertions.AssertResult.new(true)


# =============================================================================
# Battering Ram Targeting
# =============================================================================

func test_ram_command_attack_building() -> Assertions.AssertResult:
	## Ram should accept attack command against a building
	var ram = runner.spawner.spawn_battering_ram(Vector2(300, 300), 0)
	var building = runner.spawner.spawn_house(Vector2(400, 300), 1)
	await runner.wait_frames(2)

	ram.command_attack(building)

	if ram.current_state != BatteringRam.State.ATTACKING:
		return Assertions.AssertResult.new(false,
			"Ram should be in ATTACKING state after command_attack on building")
	if ram.attack_target != building:
		return Assertions.AssertResult.new(false, "Ram's attack_target should be the building")
	return Assertions.AssertResult.new(true)


func test_ram_command_attack_siege_unit() -> Assertions.AssertResult:
	## Ram should accept attack command against a siege unit
	var ram = runner.spawner.spawn_battering_ram(Vector2(300, 300), 0)
	var enemy_ram = runner.spawner.spawn_battering_ram(Vector2(400, 300), 1)
	await runner.wait_frames(2)

	ram.command_attack(enemy_ram)

	if ram.current_state != BatteringRam.State.ATTACKING:
		return Assertions.AssertResult.new(false,
			"Ram should be in ATTACKING state after command_attack on siege unit")
	if ram.attack_target != enemy_ram:
		return Assertions.AssertResult.new(false, "Ram's attack_target should be the enemy ram")
	return Assertions.AssertResult.new(true)


func test_ram_ignores_non_building_non_siege() -> Assertions.AssertResult:
	## Ram should ignore attack commands against non-building, non-siege targets
	var ram = runner.spawner.spawn_battering_ram(Vector2(300, 300), 0)
	var militia = runner.spawner.spawn_militia(Vector2(400, 300), 1)
	await runner.wait_frames(2)

	ram.command_attack(militia)

	# Ram should stay IDLE since militia is neither building nor siege
	if ram.current_state != BatteringRam.State.IDLE:
		return Assertions.AssertResult.new(false,
			"Ram should remain IDLE when commanded to attack a militia (non-building, non-siege)")
	if ram.attack_target != null:
		return Assertions.AssertResult.new(false, "Ram's attack_target should be null after ignoring militia")
	return Assertions.AssertResult.new(true)


func test_ram_no_auto_aggro() -> Assertions.AssertResult:
	## Ram's find_enemy_in_sight should always return null (no auto-aggro)
	var ram = runner.spawner.spawn_battering_ram(Vector2(300, 300), 0)
	var _enemy = runner.spawner.spawn_militia(Vector2(310, 300), 1)
	await runner.wait_frames(2)

	var found = ram.find_enemy_in_sight()
	if found != null:
		return Assertions.AssertResult.new(false,
			"Ram find_enemy_in_sight() should always return null, got: %s" % str(found))
	return Assertions.AssertResult.new(true)


# =============================================================================
# Battering Ram Garrison System
# =============================================================================

func test_ram_garrison_infantry() -> Assertions.AssertResult:
	## Infantry should be able to garrison inside a ram
	var ram = runner.spawner.spawn_battering_ram(Vector2(300, 300), 0)
	var militia = runner.spawner.spawn_militia(Vector2(310, 300), 0)
	await runner.wait_frames(2)

	if not ram.can_garrison_in_ram(militia):
		return Assertions.AssertResult.new(false, "Infantry should be able to garrison in ram")
	var result = ram.garrison_in_ram(militia)
	if not result:
		return Assertions.AssertResult.new(false, "garrison_in_ram should return true for infantry")
	if ram.get_garrisoned_count() != 1:
		return Assertions.AssertResult.new(false,
			"Ram garrisoned count should be 1, got: %d" % ram.get_garrisoned_count())
	if not militia.visible == false:
		return Assertions.AssertResult.new(false, "Garrisoned militia should be invisible")
	return Assertions.AssertResult.new(true)


func test_ram_garrison_capacity_limit() -> Assertions.AssertResult:
	## Ram should hold max 4 infantry (RAM_GARRISON_CAPACITY)
	var ram = runner.spawner.spawn_battering_ram(Vector2(300, 300), 0)
	var units = []
	for i in range(5):
		var m = runner.spawner.spawn_militia(Vector2(310 + i * 10, 300), 0)
		units.append(m)
	await runner.wait_frames(2)

	for i in range(4):
		var result = ram.garrison_in_ram(units[i])
		if not result:
			return Assertions.AssertResult.new(false,
				"garrison_in_ram should succeed for unit %d" % i)

	if ram.get_garrisoned_count() != 4:
		return Assertions.AssertResult.new(false,
			"Ram garrisoned count should be 4, got: %d" % ram.get_garrisoned_count())

	# 5th unit should be rejected
	if ram.can_garrison_in_ram(units[4]):
		return Assertions.AssertResult.new(false,
			"can_garrison_in_ram should return false when full (4/4)")
	var result = ram.garrison_in_ram(units[4])
	if result:
		return Assertions.AssertResult.new(false,
			"garrison_in_ram should fail when ram is full")
	return Assertions.AssertResult.new(true)


func test_ram_garrison_rejects_cavalry() -> Assertions.AssertResult:
	## Cavalry (non-infantry) should not be able to garrison in ram
	var ram = runner.spawner.spawn_battering_ram(Vector2(300, 300), 0)
	var scout = runner.spawner.spawn_scout_cavalry(Vector2(310, 300), 0)
	await runner.wait_frames(2)

	if ram.can_garrison_in_ram(scout):
		return Assertions.AssertResult.new(false,
			"Cavalry should not be able to garrison in ram (infantry only)")
	return Assertions.AssertResult.new(true)


func test_ram_garrison_rejects_wrong_team() -> Assertions.AssertResult:
	## Enemy infantry should not be able to garrison in ram
	var ram = runner.spawner.spawn_battering_ram(Vector2(300, 300), 0)
	var enemy_militia = runner.spawner.spawn_militia(Vector2(310, 300), 1)
	await runner.wait_frames(2)

	if ram.can_garrison_in_ram(enemy_militia):
		return Assertions.AssertResult.new(false,
			"Enemy infantry should not be able to garrison in ram")
	return Assertions.AssertResult.new(true)


func test_ram_garrison_rejects_dead_unit() -> Assertions.AssertResult:
	## Dead units should not be able to garrison in ram
	var ram = runner.spawner.spawn_battering_ram(Vector2(300, 300), 0)
	var militia = runner.spawner.spawn_militia(Vector2(310, 300), 0)
	await runner.wait_frames(2)

	militia.is_dead = true
	if ram.can_garrison_in_ram(militia):
		return Assertions.AssertResult.new(false,
			"Dead units should not be able to garrison in ram")
	return Assertions.AssertResult.new(true)


func test_ram_ungarrison_all() -> Assertions.AssertResult:
	## Ungarrisoning should restore visibility and make units free
	var ram = runner.spawner.spawn_battering_ram(Vector2(300, 300), 0)
	var m1 = runner.spawner.spawn_militia(Vector2(310, 300), 0)
	var m2 = runner.spawner.spawn_militia(Vector2(320, 300), 0)
	await runner.wait_frames(2)

	ram.garrison_in_ram(m1)
	ram.garrison_in_ram(m2)

	if ram.get_garrisoned_count() != 2:
		return Assertions.AssertResult.new(false,
			"Should have 2 garrisoned, got: %d" % ram.get_garrisoned_count())

	ram.ungarrison_all_from_ram()

	if ram.get_garrisoned_count() != 0:
		return Assertions.AssertResult.new(false,
			"Should have 0 garrisoned after ungarrison, got: %d" % ram.get_garrisoned_count())
	if not m1.visible:
		return Assertions.AssertResult.new(false, "Ungarrisoned militia 1 should be visible")
	if not m2.visible:
		return Assertions.AssertResult.new(false, "Ungarrisoned militia 2 should be visible")
	if m1.garrisoned_in != null:
		return Assertions.AssertResult.new(false, "Ungarrisoned militia 1 garrisoned_in should be null")
	return Assertions.AssertResult.new(true)


func test_ram_ejects_garrison_on_death() -> Assertions.AssertResult:
	## When ram dies, garrisoned infantry should be ejected
	var ram = runner.spawner.spawn_battering_ram(Vector2(300, 300), 0)
	var militia = runner.spawner.spawn_militia(Vector2(310, 300), 0)
	await runner.wait_frames(2)

	ram.garrison_in_ram(militia)
	if not militia.visible == false:
		return Assertions.AssertResult.new(false, "Garrisoned militia should be invisible before ram death")

	ram.die()
	await runner.wait_frames(2)

	if not militia.visible:
		return Assertions.AssertResult.new(false, "Militia should be visible after ram death (ejected)")
	if militia.garrisoned_in != null:
		return Assertions.AssertResult.new(false, "Militia garrisoned_in should be null after ram death")
	return Assertions.AssertResult.new(true)


# =============================================================================
# Mangonel Stat Tests
# =============================================================================

func test_mangonel_stats() -> Assertions.AssertResult:
	## Mangonel should have correct stats from AoE2 spec
	var mango = runner.spawner.spawn_mangonel(Vector2(300, 300), 0)
	await runner.wait_frames(2)

	if mango.max_hp != 50:
		return Assertions.AssertResult.new(false,
			"Mangonel max_hp should be 50, got: %d" % mango.max_hp)
	if mango.attack_damage != 40:
		return Assertions.AssertResult.new(false,
			"Mangonel attack_damage should be 40, got: %d" % mango.attack_damage)
	if mango.melee_armor != 0:
		return Assertions.AssertResult.new(false,
			"Mangonel melee_armor should be 0, got: %d" % mango.melee_armor)
	if mango.pierce_armor != 6:
		return Assertions.AssertResult.new(false,
			"Mangonel pierce_armor should be 6, got: %d" % mango.pierce_armor)
	if abs(mango.attack_range - 224.0) > 0.1:
		return Assertions.AssertResult.new(false,
			"Mangonel attack_range should be 224.0, got: %.1f" % mango.attack_range)
	if abs(mango.min_range - 96.0) > 0.1:
		return Assertions.AssertResult.new(false,
			"Mangonel min_range should be 96.0, got: %.1f" % mango.min_range)
	return Assertions.AssertResult.new(true)


func test_mangonel_group_membership() -> Assertions.AssertResult:
	## Mangonel should be in correct groups
	var mango = runner.spawner.spawn_mangonel(Vector2(300, 300), 0)
	await runner.wait_frames(2)

	if not mango.is_in_group("military"):
		return Assertions.AssertResult.new(false, "Mangonel should be in 'military' group")
	if not mango.is_in_group("siege"):
		return Assertions.AssertResult.new(false, "Mangonel should be in 'siege' group")
	if not mango.is_in_group("mangonels"):
		return Assertions.AssertResult.new(false, "Mangonel should be in 'mangonels' group")
	return Assertions.AssertResult.new(true)


func test_mangonel_min_range() -> Assertions.AssertResult:
	## Mangonel should not fire at targets within min_range (96px)
	var mango = runner.spawner.spawn_mangonel(Vector2(300, 300), 0)
	var enemy = runner.spawner.spawn_militia(Vector2(330, 300), 1)  # 30px away < 96 min range
	await runner.wait_frames(2)

	# Set up attacking state manually
	mango.command_attack(enemy)
	# Process a frame - should detect target is within min range and stop
	await runner.wait_frames(5)

	# Check that the mangonel's attack timer hasn't progressed to firing
	# The _process_attacking method stops when distance < min_range
	var dist = mango.global_position.distance_to(enemy.global_position)
	if dist >= mango.min_range:
		return Assertions.AssertResult.new(false,
			"Test setup: enemy should be within min_range. dist=%.1f, min=%.1f" % [dist, mango.min_range])

	# Enemy should still be alive (mangonel couldn't fire)
	if enemy.current_hp != enemy.max_hp:
		return Assertions.AssertResult.new(false,
			"Enemy within min_range should not have taken damage. HP: %d/%d" % [enemy.current_hp, enemy.max_hp])
	return Assertions.AssertResult.new(true)


# =============================================================================
# Mangonel Area Splash
# =============================================================================

func test_mangonel_splash_damage_calculation() -> Assertions.AssertResult:
	## Splash targets should take 50% of mangonel attack damage
	var expected_splash = int(40 * 0.5)  # 20
	if expected_splash != 20:
		return Assertions.AssertResult.new(false,
			"Splash damage should be 20 (40 * 0.5), got: %d" % expected_splash)
	# Verify the constants on the class
	if Mangonel.SPLASH_RADIUS != 48.0:
		return Assertions.AssertResult.new(false,
			"Mangonel SPLASH_RADIUS should be 48.0, got: %.1f" % Mangonel.SPLASH_RADIUS)
	if abs(Mangonel.SPLASH_DAMAGE_RATIO - 0.5) > 0.01:
		return Assertions.AssertResult.new(false,
			"Mangonel SPLASH_DAMAGE_RATIO should be 0.5, got: %.2f" % Mangonel.SPLASH_DAMAGE_RATIO)
	return Assertions.AssertResult.new(true)


func test_mangonel_splash_hits_friendlies() -> Assertions.AssertResult:
	## Mangonel splash should damage friendly units near the target (friendly fire)
	var mango = runner.spawner.spawn_mangonel(Vector2(100, 300), 0)
	var enemy = runner.spawner.spawn_militia(Vector2(300, 300), 1)  # Primary target (200px away, in range)
	var friendly = runner.spawner.spawn_militia(Vector2(320, 300), 0)  # 20px from enemy, within splash 48px
	await runner.wait_frames(2)

	var friendly_hp_before = friendly.current_hp

	# Directly call _fire_area_attack to test splash logic
	mango.attack_target = enemy
	mango._fire_area_attack()
	await runner.wait_frames(2)

	# Friendly should have taken splash damage (20 - friendly's pierce armor since it's "pierce" type)
	if friendly.current_hp >= friendly_hp_before:
		return Assertions.AssertResult.new(false,
			"Friendly unit near splash should take damage. HP before: %d, after: %d" % [
				friendly_hp_before, friendly.current_hp])
	return Assertions.AssertResult.new(true)


func test_mangonel_splash_does_not_hit_self() -> Assertions.AssertResult:
	## Mangonel should not damage itself with its own splash
	var mango = runner.spawner.spawn_mangonel(Vector2(300, 300), 0)
	var enemy = runner.spawner.spawn_militia(Vector2(310, 300), 1)  # Very close to mango
	await runner.wait_frames(2)

	var mango_hp_before = mango.current_hp
	mango.attack_target = enemy
	mango._fire_area_attack()
	await runner.wait_frames(2)

	if mango.current_hp != mango_hp_before:
		return Assertions.AssertResult.new(false,
			"Mangonel should not damage itself. HP before: %d, after: %d" % [
				mango_hp_before, mango.current_hp])
	return Assertions.AssertResult.new(true)


# =============================================================================
# Scorpion Stat Tests
# =============================================================================

func test_scorpion_stats() -> Assertions.AssertResult:
	## Scorpion should have correct stats from AoE2 spec
	var scorp = runner.spawner.spawn_scorpion(Vector2(300, 300), 0)
	await runner.wait_frames(2)

	if scorp.max_hp != 40:
		return Assertions.AssertResult.new(false,
			"Scorpion max_hp should be 40, got: %d" % scorp.max_hp)
	if scorp.attack_damage != 12:
		return Assertions.AssertResult.new(false,
			"Scorpion attack_damage should be 12, got: %d" % scorp.attack_damage)
	if scorp.melee_armor != 0:
		return Assertions.AssertResult.new(false,
			"Scorpion melee_armor should be 0, got: %d" % scorp.melee_armor)
	if scorp.pierce_armor != 6:
		return Assertions.AssertResult.new(false,
			"Scorpion pierce_armor should be 6, got: %d" % scorp.pierce_armor)
	if abs(scorp.attack_range - 160.0) > 0.1:
		return Assertions.AssertResult.new(false,
			"Scorpion attack_range should be 160.0, got: %.1f" % scorp.attack_range)
	return Assertions.AssertResult.new(true)


func test_scorpion_group_membership() -> Assertions.AssertResult:
	## Scorpion should be in correct groups
	var scorp = runner.spawner.spawn_scorpion(Vector2(300, 300), 0)
	await runner.wait_frames(2)

	if not scorp.is_in_group("military"):
		return Assertions.AssertResult.new(false, "Scorpion should be in 'military' group")
	if not scorp.is_in_group("siege"):
		return Assertions.AssertResult.new(false, "Scorpion should be in 'siege' group")
	if not scorp.is_in_group("scorpions"):
		return Assertions.AssertResult.new(false, "Scorpion should be in 'scorpions' group")
	return Assertions.AssertResult.new(true)


# =============================================================================
# Scorpion Pass-Through Geometry
# =============================================================================

func test_point_near_line_on_line() -> Assertions.AssertResult:
	## A point directly on the line segment should be detected as near
	var scorp = runner.spawner.spawn_scorpion(Vector2(300, 300), 0)
	await runner.wait_frames(2)

	# Line from (0,0) to (100,0), point at (50,0) -> on line, distance = 0
	var result = scorp._point_near_line_segment(
		Vector2(50, 0), Vector2(0, 0), Vector2(100, 0), 20.0)
	if not result:
		return Assertions.AssertResult.new(false,
			"Point (50,0) should be near line (0,0)-(100,0) with width 20")

	# Point 15px away from line, still within 20px width
	result = scorp._point_near_line_segment(
		Vector2(50, 15), Vector2(0, 0), Vector2(100, 0), 20.0)
	if not result:
		return Assertions.AssertResult.new(false,
			"Point (50,15) should be near line (0,0)-(100,0) with width 20")
	return Assertions.AssertResult.new(true)


func test_point_near_line_off_line() -> Assertions.AssertResult:
	## A point far from the line should not be detected
	var scorp = runner.spawner.spawn_scorpion(Vector2(300, 300), 0)
	await runner.wait_frames(2)

	# Line from (0,0) to (100,0), point at (50, 50) -> distance = 50, beyond 20px width
	var result = scorp._point_near_line_segment(
		Vector2(50, 50), Vector2(0, 0), Vector2(100, 0), 20.0)
	if result:
		return Assertions.AssertResult.new(false,
			"Point (50,50) should NOT be near line (0,0)-(100,0) with width 20")
	return Assertions.AssertResult.new(true)


func test_point_near_line_past_endpoint() -> Assertions.AssertResult:
	## A point past the endpoint of the segment should use endpoint distance
	var scorp = runner.spawner.spawn_scorpion(Vector2(300, 300), 0)
	await runner.wait_frames(2)

	# Line from (0,0) to (100,0), point at (150,0) -> past endpoint, distance = 50
	var result = scorp._point_near_line_segment(
		Vector2(150, 0), Vector2(0, 0), Vector2(100, 0), 20.0)
	if result:
		return Assertions.AssertResult.new(false,
			"Point (150,0) past endpoint should NOT be within 20px of segment (0,0)-(100,0)")

	# Point at (110,0) -> past endpoint by 10, within 20px
	result = scorp._point_near_line_segment(
		Vector2(110, 0), Vector2(0, 0), Vector2(100, 0), 20.0)
	if not result:
		return Assertions.AssertResult.new(false,
			"Point (110,0) should be within 20px of endpoint (100,0)")
	return Assertions.AssertResult.new(true)


# =============================================================================
# Scorpion Pass-Through No Friendly Fire
# =============================================================================

func test_scorpion_no_friendly_fire() -> Assertions.AssertResult:
	## Scorpion pass-through should NOT damage friendly units along the bolt line
	var scorp = runner.spawner.spawn_scorpion(Vector2(100, 300), 0)
	var enemy = runner.spawner.spawn_militia(Vector2(250, 300), 1)  # Primary target
	var friendly = runner.spawner.spawn_militia(Vector2(300, 300), 0)  # Behind enemy, same team as scorpion
	await runner.wait_frames(2)

	var friendly_hp_before = friendly.current_hp

	# Directly call _fire_pass_through
	scorp.attack_target = enemy
	scorp._fire_pass_through()
	await runner.wait_frames(2)

	if friendly.current_hp != friendly_hp_before:
		return Assertions.AssertResult.new(false,
			"Friendly unit should NOT take scorpion pass-through damage. HP before: %d, after: %d" % [
				friendly_hp_before, friendly.current_hp])
	return Assertions.AssertResult.new(true)


# =============================================================================
# Siege Unit Tech Upgrade Entries
# =============================================================================

func test_capped_ram_tech_entry() -> Assertions.AssertResult:
	## Capped Ram tech should have correct cost, age, and new_stats
	var tech = GameManager.TECHNOLOGIES.get("capped_ram", null)
	if tech == null:
		return Assertions.AssertResult.new(false, "capped_ram tech not found in TECHNOLOGIES")
	if tech["age"] != GameManager.AGE_CASTLE:
		return Assertions.AssertResult.new(false,
			"Capped Ram should require Castle Age, got: %d" % tech["age"])
	if tech["building"] != "siege_workshop":
		return Assertions.AssertResult.new(false,
			"Capped Ram building should be 'siege_workshop', got: '%s'" % tech["building"])
	if tech["cost"].get("food", 0) != 300:
		return Assertions.AssertResult.new(false,
			"Capped Ram food cost should be 300, got: %d" % tech["cost"].get("food", 0))
	if tech.get("type", "") != "unit_upgrade":
		return Assertions.AssertResult.new(false,
			"Capped Ram should be type 'unit_upgrade', got: '%s'" % tech.get("type", ""))
	if tech["from_group"] != "battering_rams":
		return Assertions.AssertResult.new(false,
			"Capped Ram from_group should be 'battering_rams', got: '%s'" % tech["from_group"])
	if tech["to_group"] != "capped_rams":
		return Assertions.AssertResult.new(false,
			"Capped Ram to_group should be 'capped_rams', got: '%s'" % tech["to_group"])
	var ns = tech["new_stats"]
	if ns.get("max_hp", 0) != 200:
		return Assertions.AssertResult.new(false,
			"Capped Ram new max_hp should be 200, got: %d" % ns.get("max_hp", 0))
	if ns.get("attack_damage", 0) != 3:
		return Assertions.AssertResult.new(false,
			"Capped Ram new attack_damage should be 3, got: %d" % ns.get("attack_damage", 0))
	if ns.get("pierce_armor", 0) != 190:
		return Assertions.AssertResult.new(false,
			"Capped Ram new pierce_armor should be 190, got: %d" % ns.get("pierce_armor", 0))
	return Assertions.AssertResult.new(true)


func test_onager_tech_entry() -> Assertions.AssertResult:
	## Onager tech should have correct cost, age, and new_stats
	var tech = GameManager.TECHNOLOGIES.get("onager", null)
	if tech == null:
		return Assertions.AssertResult.new(false, "onager tech not found in TECHNOLOGIES")
	if tech["age"] != GameManager.AGE_IMPERIAL:
		return Assertions.AssertResult.new(false,
			"Onager should require Imperial Age, got: %d" % tech["age"])
	if tech["building"] != "siege_workshop":
		return Assertions.AssertResult.new(false,
			"Onager building should be 'siege_workshop', got: '%s'" % tech["building"])
	if tech["cost"].get("food", 0) != 800:
		return Assertions.AssertResult.new(false,
			"Onager food cost should be 800, got: %d" % tech["cost"].get("food", 0))
	if tech["cost"].get("gold", 0) != 500:
		return Assertions.AssertResult.new(false,
			"Onager gold cost should be 500, got: %d" % tech["cost"].get("gold", 0))
	if tech.get("type", "") != "unit_upgrade":
		return Assertions.AssertResult.new(false,
			"Onager should be type 'unit_upgrade', got: '%s'" % tech.get("type", ""))
	if tech["from_group"] != "mangonels":
		return Assertions.AssertResult.new(false,
			"Onager from_group should be 'mangonels', got: '%s'" % tech["from_group"])
	var ns = tech["new_stats"]
	if ns.get("max_hp", 0) != 60:
		return Assertions.AssertResult.new(false,
			"Onager new max_hp should be 60, got: %d" % ns.get("max_hp", 0))
	if ns.get("attack_damage", 0) != 50:
		return Assertions.AssertResult.new(false,
			"Onager new attack_damage should be 50, got: %d" % ns.get("attack_damage", 0))
	if abs(ns.get("attack_range", 0.0) - 256.0) > 0.1:
		return Assertions.AssertResult.new(false,
			"Onager new attack_range should be 256.0, got: %.1f" % ns.get("attack_range", 0.0))
	return Assertions.AssertResult.new(true)


func test_heavy_scorpion_tech_entry() -> Assertions.AssertResult:
	## Heavy Scorpion tech should have correct cost, age, and new_stats
	var tech = GameManager.TECHNOLOGIES.get("heavy_scorpion", null)
	if tech == null:
		return Assertions.AssertResult.new(false, "heavy_scorpion tech not found in TECHNOLOGIES")
	if tech["age"] != GameManager.AGE_IMPERIAL:
		return Assertions.AssertResult.new(false,
			"Heavy Scorpion should require Imperial Age, got: %d" % tech["age"])
	if tech["building"] != "siege_workshop":
		return Assertions.AssertResult.new(false,
			"Heavy Scorpion building should be 'siege_workshop', got: '%s'" % tech["building"])
	if tech["cost"].get("food", 0) != 1000:
		return Assertions.AssertResult.new(false,
			"Heavy Scorpion food cost should be 1000, got: %d" % tech["cost"].get("food", 0))
	if tech["cost"].get("wood", 0) != 800:
		return Assertions.AssertResult.new(false,
			"Heavy Scorpion wood cost should be 800, got: %d" % tech["cost"].get("wood", 0))
	if tech.get("type", "") != "unit_upgrade":
		return Assertions.AssertResult.new(false,
			"Heavy Scorpion should be type 'unit_upgrade', got: '%s'" % tech.get("type", ""))
	if tech["from_group"] != "scorpions":
		return Assertions.AssertResult.new(false,
			"Heavy Scorpion from_group should be 'scorpions', got: '%s'" % tech["from_group"])
	var ns = tech["new_stats"]
	if ns.get("max_hp", 0) != 50:
		return Assertions.AssertResult.new(false,
			"Heavy Scorpion new max_hp should be 50, got: %d" % ns.get("max_hp", 0))
	if ns.get("attack_damage", 0) != 16:
		return Assertions.AssertResult.new(false,
			"Heavy Scorpion new attack_damage should be 16, got: %d" % ns.get("attack_damage", 0))
	if ns.get("pierce_armor", 0) != 7:
		return Assertions.AssertResult.new(false,
			"Heavy Scorpion new pierce_armor should be 7, got: %d" % ns.get("pierce_armor", 0))
	return Assertions.AssertResult.new(true)


# =============================================================================
# Building Garrison Exclusion
# =============================================================================

func test_building_garrison_rejects_siege() -> Assertions.AssertResult:
	## Siege units should NOT be able to garrison in buildings (building.can_garrison check)
	var tc = runner.spawner.spawn_town_center(Vector2(400, 400), 0)
	var ram = runner.spawner.spawn_battering_ram(Vector2(410, 400), 0)
	await runner.wait_frames(2)

	if tc.can_garrison(ram):
		return Assertions.AssertResult.new(false,
			"Siege units should not be able to garrison in buildings (can_garrison should return false)")

	var result = tc.garrison_unit(ram)
	if result:
		return Assertions.AssertResult.new(false,
			"garrison_unit should fail for siege units")
	return Assertions.AssertResult.new(true)
