extends Node
## Armor System Tests - Tests for melee/pierce armor and damage reduction
##
## These tests verify:
## - Melee armor reduces melee damage
## - Pierce armor reduces pierce/ranged damage
## - Minimum 1 damage even with high armor
## - Bonus damage bypasses armor
## - Building armor works the same as unit armor

class_name TestArmor

var runner: TestRunner


func _init(test_runner: TestRunner) -> void:
	runner = test_runner


func get_all_tests() -> Array[Callable]:
	## Returns all test methods to run
	return [
		# Unit armor tests
		test_unit_melee_armor_reduces_melee_damage,
		test_unit_pierce_armor_reduces_pierce_damage,
		test_unit_melee_armor_does_not_affect_pierce_damage,
		test_unit_pierce_armor_does_not_affect_melee_damage,
		test_unit_minimum_1_damage_with_high_armor,
		test_unit_bonus_damage_bypasses_armor,
		test_unit_bonus_damage_added_after_armor_reduction,
		# Building armor tests
		test_building_melee_armor_reduces_melee_damage,
		test_building_pierce_armor_reduces_pierce_damage,
		test_building_minimum_1_damage_with_high_armor,
		test_building_bonus_damage_bypasses_armor,
		# Scout Cavalry specific armor tests
		test_scout_cavalry_has_pierce_armor,
		test_scout_cavalry_resists_pierce_attacks,
		# Spearman bonus damage tests
		test_spearman_bonus_vs_cavalry,
		test_spearman_no_bonus_vs_non_cavalry,
	]


# === Unit Armor Tests ===

func test_unit_melee_armor_reduces_melee_damage() -> Assertions.AssertResult:
	## Melee armor should reduce melee damage (damage - armor)
	var scout = runner.spawner.spawn_scout_cavalry(Vector2(400, 400))
	await runner.wait_frames(2)

	# Scout has 0 melee armor, 45 HP - verify base case first
	var initial_hp = scout.current_hp
	scout.take_damage(10, "melee")

	if scout.current_hp != initial_hp - 10:
		return Assertions.AssertResult.new(false,
			"With 0 melee armor, should take full damage. Expected: %d, Got: %d" % [initial_hp - 10, scout.current_hp])

	return Assertions.AssertResult.new(true)


func test_unit_pierce_armor_reduces_pierce_damage() -> Assertions.AssertResult:
	## Pierce armor should reduce pierce/ranged damage
	var scout = runner.spawner.spawn_scout_cavalry(Vector2(400, 400))
	await runner.wait_frames(2)

	# Scout has 2 pierce armor, 45 HP
	var initial_hp = scout.current_hp
	scout.take_damage(10, "pierce")

	# 10 damage - 2 armor = 8 damage
	var expected_hp = initial_hp - 8
	if scout.current_hp != expected_hp:
		return Assertions.AssertResult.new(false,
			"With 2 pierce armor, 10 damage should deal 8. Expected HP: %d, Got: %d" % [expected_hp, scout.current_hp])

	return Assertions.AssertResult.new(true)


func test_unit_melee_armor_does_not_affect_pierce_damage() -> Assertions.AssertResult:
	## Melee armor should NOT reduce pierce damage - test with artificially set armor
	var militia = runner.spawner.spawn_militia(Vector2(400, 400))
	await runner.wait_frames(2)

	# Set melee armor high to verify it doesn't affect pierce damage
	militia.melee_armor = 5
	militia.pierce_armor = 0

	var initial_hp = militia.current_hp
	militia.take_damage(10, "pierce")

	# With 0 pierce armor, should take full 10 damage (melee armor of 5 should not apply)
	if militia.current_hp != initial_hp - 10:
		return Assertions.AssertResult.new(false,
			"Pierce damage should use pierce armor (0), not melee armor (5). Expected HP: %d, Got: %d" % [initial_hp - 10, militia.current_hp])

	return Assertions.AssertResult.new(true)


func test_unit_pierce_armor_does_not_affect_melee_damage() -> Assertions.AssertResult:
	## Pierce armor should NOT reduce melee damage
	var scout = runner.spawner.spawn_scout_cavalry(Vector2(400, 400))
	await runner.wait_frames(2)

	# Scout has 2 pierce armor, 0 melee armor
	if scout.melee_armor != 0:
		return Assertions.AssertResult.new(false,
			"Scout melee_armor should be 0, got: %d" % scout.melee_armor)

	if scout.pierce_armor != 2:
		return Assertions.AssertResult.new(false,
			"Scout pierce_armor should be 2, got: %d" % scout.pierce_armor)

	var initial_hp = scout.current_hp
	scout.take_damage(10, "melee")

	# With 0 melee armor, should take full 10 damage
	if scout.current_hp != initial_hp - 10:
		return Assertions.AssertResult.new(false,
			"Melee damage should use melee armor (0), not pierce armor. Expected HP: %d, Got: %d" % [initial_hp - 10, scout.current_hp])

	return Assertions.AssertResult.new(true)


func test_unit_minimum_1_damage_with_high_armor() -> Assertions.AssertResult:
	## Even with armor higher than damage, minimum 1 damage should be dealt
	var scout = runner.spawner.spawn_scout_cavalry(Vector2(400, 400))
	await runner.wait_frames(2)

	# Scout has 2 pierce armor - deal 1 pierce damage (less than armor)
	var initial_hp = scout.current_hp
	scout.take_damage(1, "pierce")  # 1 - 2 = -1, but should be clamped to 1

	if scout.current_hp != initial_hp - 1:
		return Assertions.AssertResult.new(false,
			"Minimum 1 damage should always be dealt. Expected HP: %d, Got: %d" % [initial_hp - 1, scout.current_hp])

	return Assertions.AssertResult.new(true)


func test_unit_bonus_damage_bypasses_armor() -> Assertions.AssertResult:
	## Bonus damage should be added on top of base damage, not reduced by armor
	var scout = runner.spawner.spawn_scout_cavalry(Vector2(400, 400))
	await runner.wait_frames(2)

	# Scout has 2 pierce armor
	# Test with pierce attack: 5 damage with 10 bonus
	# Base: max(1, 5 - 2) = 3
	# Final: 3 + 10 = 13
	var initial_hp = scout.current_hp
	scout.take_damage(5, "pierce", 10)

	var expected_hp = initial_hp - 13
	if scout.current_hp != expected_hp:
		return Assertions.AssertResult.new(false,
			"Bonus damage should bypass armor. Expected HP: %d, Got: %d (5 pierce - 2 armor + 10 bonus = 13)" % [expected_hp, scout.current_hp])

	return Assertions.AssertResult.new(true)


func test_unit_bonus_damage_added_after_armor_reduction() -> Assertions.AssertResult:
	## Verify bonus damage is calculated correctly: max(1, base-armor) + bonus
	var scout = runner.spawner.spawn_scout_cavalry(Vector2(400, 400))
	await runner.wait_frames(2)

	# Scout has 0 melee armor
	# Test: 10 melee + 5 bonus = 15 total
	var initial_hp = scout.current_hp
	scout.take_damage(10, "melee", 5)

	var expected_hp = initial_hp - 15
	if scout.current_hp != expected_hp:
		return Assertions.AssertResult.new(false,
			"Total damage should be base (after armor) + bonus. Expected HP: %d, Got: %d" % [expected_hp, scout.current_hp])

	return Assertions.AssertResult.new(true)


# === Building Armor Tests ===

func test_building_melee_armor_reduces_melee_damage() -> Assertions.AssertResult:
	## Building melee armor should reduce melee damage
	var house = runner.spawner.spawn_house(Vector2(400, 400))
	await runner.wait_frames(2)

	# House has 0 melee armor by default
	var initial_hp = house.current_hp
	house.take_damage(50, "melee")

	if house.current_hp != initial_hp - 50:
		return Assertions.AssertResult.new(false,
			"Building with 0 armor should take full damage. Expected: %d, Got: %d" % [initial_hp - 50, house.current_hp])

	return Assertions.AssertResult.new(true)


func test_building_pierce_armor_reduces_pierce_damage() -> Assertions.AssertResult:
	## Building pierce armor should reduce pierce damage
	var house = runner.spawner.spawn_house(Vector2(400, 400))
	await runner.wait_frames(2)

	# Manually set pierce armor for this test
	house.pierce_armor = 5

	var initial_hp = house.current_hp
	house.take_damage(20, "pierce")

	# 20 - 5 = 15 damage
	var expected_hp = initial_hp - 15
	if house.current_hp != expected_hp:
		return Assertions.AssertResult.new(false,
			"Building with 5 pierce armor should reduce 20 damage to 15. Expected HP: %d, Got: %d" % [expected_hp, house.current_hp])

	return Assertions.AssertResult.new(true)


func test_building_minimum_1_damage_with_high_armor() -> Assertions.AssertResult:
	## Buildings should also take minimum 1 damage with high armor
	var house = runner.spawner.spawn_house(Vector2(400, 400))
	await runner.wait_frames(2)

	# Set very high armor
	house.melee_armor = 100

	var initial_hp = house.current_hp
	house.take_damage(10, "melee")  # 10 - 100 = -90, should be 1

	if house.current_hp != initial_hp - 1:
		return Assertions.AssertResult.new(false,
			"Building should take minimum 1 damage even with high armor. Expected HP: %d, Got: %d" % [initial_hp - 1, house.current_hp])

	return Assertions.AssertResult.new(true)


func test_building_bonus_damage_bypasses_armor() -> Assertions.AssertResult:
	## Bonus damage against buildings should bypass armor (e.g., rams vs buildings)
	var house = runner.spawner.spawn_house(Vector2(400, 400))
	await runner.wait_frames(2)

	house.melee_armor = 10

	var initial_hp = house.current_hp
	# 5 damage - 10 armor = 1 (minimum), + 50 bonus = 51 total
	house.take_damage(5, "melee", 50)

	var expected_hp = initial_hp - 51
	if house.current_hp != expected_hp:
		return Assertions.AssertResult.new(false,
			"Building bonus damage should bypass armor. Expected HP: %d, Got: %d" % [expected_hp, house.current_hp])

	return Assertions.AssertResult.new(true)


# === Scout Cavalry Specific Tests ===

func test_scout_cavalry_has_pierce_armor() -> Assertions.AssertResult:
	## Scout Cavalry should have 0/2 armor (0 melee, 2 pierce) per AoE2 spec
	var scout = runner.spawner.spawn_scout_cavalry(Vector2(400, 400))
	await runner.wait_frames(2)

	if scout.melee_armor != 0:
		return Assertions.AssertResult.new(false,
			"Scout Cavalry melee_armor should be 0, got: %d" % scout.melee_armor)

	if scout.pierce_armor != 2:
		return Assertions.AssertResult.new(false,
			"Scout Cavalry pierce_armor should be 2, got: %d" % scout.pierce_armor)

	return Assertions.AssertResult.new(true)


func test_scout_cavalry_resists_pierce_attacks() -> Assertions.AssertResult:
	## Scout Cavalry's pierce armor should reduce archer damage
	var scout = runner.spawner.spawn_scout_cavalry(Vector2(400, 400))
	var archer = runner.spawner.spawn_archer(Vector2(500, 400), 1)  # Enemy archer
	await runner.wait_frames(2)

	var initial_hp = scout.current_hp
	# Archer does 4 pierce damage, scout has 2 pierce armor
	# Expected: 4 - 2 = 2 damage
	scout.take_damage(4, "pierce")  # Simulate archer hit

	var expected_hp = initial_hp - 2
	if scout.current_hp != expected_hp:
		return Assertions.AssertResult.new(false,
			"Scout should resist pierce (4 - 2 armor = 2 damage). Expected HP: %d, Got: %d" % [expected_hp, scout.current_hp])

	return Assertions.AssertResult.new(true)


# === Spearman Bonus Damage Tests ===

func test_spearman_bonus_vs_cavalry() -> Assertions.AssertResult:
	## Spearman should deal bonus damage (+15) vs cavalry units
	var spearman = runner.spawner.spawn_spearman(Vector2(400, 400))
	var scout = runner.spawner.spawn_scout_cavalry(Vector2(410, 400), 1)  # Enemy cavalry
	await runner.wait_frames(2)

	# Verify scout is in cavalry group
	if not scout.is_in_group("cavalry"):
		return Assertions.AssertResult.new(false,
			"Scout Cavalry should be in 'cavalry' group")

	# Verify spearman has correct bonus
	if spearman.bonus_vs_cavalry != 15:
		return Assertions.AssertResult.new(false,
			"Spearman bonus_vs_cavalry should be 15, got: %d" % spearman.bonus_vs_cavalry)

	var initial_hp = scout.current_hp
	# Manually call _deal_damage to test bonus calculation
	# Spearman: 3 attack + 15 bonus vs cavalry = 18 damage
	# Scout: 0 melee armor
	spearman.attack_target = scout
	spearman._deal_damage()

	# Expected: 3 base + 15 bonus = 18 damage
	var expected_hp = initial_hp - 18
	if scout.current_hp != expected_hp:
		return Assertions.AssertResult.new(false,
			"Spearman should deal 3 + 15 bonus = 18 damage to cavalry. Expected HP: %d, Got: %d" % [expected_hp, scout.current_hp])

	return Assertions.AssertResult.new(true)


func test_spearman_no_bonus_vs_non_cavalry() -> Assertions.AssertResult:
	## Spearman should NOT deal bonus damage to non-cavalry units
	var spearman = runner.spawner.spawn_spearman(Vector2(400, 400))
	var militia = runner.spawner.spawn_militia(Vector2(410, 400), 1)  # Enemy infantry
	await runner.wait_frames(2)

	# Verify militia is NOT in cavalry group
	if militia.is_in_group("cavalry"):
		return Assertions.AssertResult.new(false,
			"Militia should NOT be in 'cavalry' group")

	# Verify militia has 0 melee armor (from base Unit class)
	if militia.melee_armor != 0:
		return Assertions.AssertResult.new(false,
			"Militia melee_armor should be 0, got: %d" % militia.melee_armor)

	var initial_hp = militia.current_hp
	# Spearman: 3 attack, no bonus vs infantry
	# Militia: 0 melee armor
	spearman.attack_target = militia
	spearman._deal_damage()

	# Expected: 3 base - 0 armor = 3 damage (no bonus)
	var expected_hp = initial_hp - 3
	if militia.current_hp != expected_hp:
		return Assertions.AssertResult.new(false,
			"Spearman should deal 3 - 0 armor = 3 damage to infantry (no bonus). Expected HP: %d, Got: %d" % [expected_hp, militia.current_hp])

	return Assertions.AssertResult.new(true)
