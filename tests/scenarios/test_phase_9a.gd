extends Node
## Phase 9A Tests - Imperial Age Advancement + Imperial Blacksmith Techs + Deferred Unit Upgrades
##
## These tests verify:
## - 5 Imperial Blacksmith techs: costs, effects, prerequisites, age requirements
## - 6 Imperial unit upgrades: costs, stats, group swaps, upgrade chains
## - AdvanceToImperialAgeRule: conditions (Castle Age, 20 vills, 2 qualifying buildings, affordability)
## - should_save_for_age(): Imperial case requires 20 villagers
## - Imperial Age qualifying buildings (monasteries, universities)
## - Blacksmith available techs in Imperial Age

class_name TestPhase9A

var runner: TestRunner


func _init(test_runner: TestRunner) -> void:
	runner = test_runner


func get_all_tests() -> Array[Callable]:
	## Returns all test methods to run
	return [
		# Imperial Blacksmith tech definitions
		test_blast_furnace_tech_definition,
		test_plate_mail_armor_tech_definition,
		test_plate_barding_armor_tech_definition,
		test_bracer_tech_definition,
		test_ring_archer_armor_tech_definition,
		# Imperial Blacksmith tech prerequisites
		test_blast_furnace_requires_iron_casting,
		test_plate_mail_armor_requires_chain_mail,
		test_plate_barding_armor_requires_chain_barding,
		test_bracer_requires_bodkin_arrow,
		test_ring_archer_armor_requires_leather_archer_armor,
		# Imperial Blacksmith tech age gating
		test_imperial_techs_blocked_in_castle_age,
		test_imperial_techs_available_in_imperial_age,
		# Imperial Blacksmith tech effects on units
		test_blast_furnace_infantry_attack_bonus,
		test_blast_furnace_cavalry_attack_bonus,
		test_plate_mail_armor_infantry_armor_bonus,
		test_plate_barding_armor_cavalry_armor_bonus,
		test_bracer_archer_attack_and_range_bonus,
		test_ring_archer_armor_archer_armor_bonus,
		# Full Blacksmith line stacking (3 tiers)
		test_full_infantry_attack_line_stacks,
		test_full_archer_armor_line_stacks,
		# Imperial unit upgrades: two_handed_swordsman
		test_two_handed_swordsman_tech_definition,
		test_long_swordsman_to_two_handed_swordsman_stats,
		test_two_handed_swordsman_group_swap,
		# Imperial unit upgrades: champion
		test_champion_tech_definition,
		test_two_handed_swordsman_to_champion_stats,
		test_champion_full_chain_from_militia,
		# Imperial unit upgrades: arbalester
		test_arbalester_tech_definition,
		test_crossbowman_to_arbalester_stats,
		test_arbalester_group_swap,
		# Imperial unit upgrades: cavalier
		test_cavalier_tech_definition,
		test_knight_to_cavalier_stats,
		test_cavalier_group_swap,
		# Imperial unit upgrades: paladin
		test_paladin_tech_definition,
		test_cavalier_to_paladin_stats,
		test_paladin_full_chain_from_knight,
		# Imperial unit upgrades: siege_ram
		test_siege_ram_tech_definition,
		test_capped_ram_to_siege_ram_stats,
		test_siege_ram_group_swap,
		# Newly spawned units auto-apply upgrade chains
		test_new_militia_spawns_as_two_handed_swordsman,
		test_new_militia_spawns_as_champion,
		# Upgrade team isolation
		test_imperial_upgrade_only_affects_own_team,
		# Tech bonus reapplied after Imperial upgrade
		test_tech_bonus_reapplied_after_two_handed_swordsman_upgrade,
		# Imperial Age advancement conditions
		test_imperial_age_cost,
		test_qualifying_buildings_for_imperial,
		test_qualifying_count_imperial_needs_monastery_and_university,
		test_cannot_advance_to_imperial_without_qualifying_buildings,
		test_can_advance_to_imperial_with_all_requirements,
		# AI: AdvanceToImperialAgeRule
		test_ai_imperial_rule_fires_when_ready,
		test_ai_imperial_rule_blocks_wrong_age,
		test_ai_imperial_rule_blocks_insufficient_villagers,
		test_ai_imperial_rule_blocks_insufficient_buildings,
		test_ai_imperial_rule_blocks_insufficient_resources,
		# AI: should_save_for_age() Imperial case
		test_should_save_for_age_imperial_needs_20_vills,
		test_should_save_for_age_false_when_already_imperial,
		test_should_save_for_age_false_when_can_afford,
	]


# =============================================================================
# Mock AI Controller (same pattern as other test files)
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
# Imperial Blacksmith Tech Definitions
# =============================================================================

func test_blast_furnace_tech_definition() -> Assertions.AssertResult:
	## Blast Furnace: 275F+225G, Imperial, building=blacksmith, requires iron_casting
	var tech = GameManager.TECHNOLOGIES.get("blast_furnace", {})
	if tech.is_empty():
		return Assertions.AssertResult.new(false, "blast_furnace tech not found in TECHNOLOGIES")
	if tech["age"] != GameManager.AGE_IMPERIAL:
		return Assertions.AssertResult.new(false,
			"blast_furnace age should be Imperial (3), got: %d" % tech["age"])
	if tech["cost"].get("food", 0) != 275:
		return Assertions.AssertResult.new(false,
			"blast_furnace food cost should be 275, got: %d" % tech["cost"].get("food", 0))
	if tech["cost"].get("gold", 0) != 225:
		return Assertions.AssertResult.new(false,
			"blast_furnace gold cost should be 225, got: %d" % tech["cost"].get("gold", 0))
	if tech["building"] != "blacksmith":
		return Assertions.AssertResult.new(false,
			"blast_furnace building should be 'blacksmith', got: '%s'" % tech["building"])
	# Verify effects: +2 infantry_attack, +2 cavalry_attack
	if tech["effects"].get("infantry_attack", 0) != 2:
		return Assertions.AssertResult.new(false,
			"blast_furnace infantry_attack effect should be 2, got: %d" % tech["effects"].get("infantry_attack", 0))
	if tech["effects"].get("cavalry_attack", 0) != 2:
		return Assertions.AssertResult.new(false,
			"blast_furnace cavalry_attack effect should be 2, got: %d" % tech["effects"].get("cavalry_attack", 0))
	return Assertions.AssertResult.new(true)


func test_plate_mail_armor_tech_definition() -> Assertions.AssertResult:
	## Plate Mail Armor: 300F+150G, Imperial, requires chain_mail_armor
	var tech = GameManager.TECHNOLOGIES.get("plate_mail_armor", {})
	if tech.is_empty():
		return Assertions.AssertResult.new(false, "plate_mail_armor tech not found")
	if tech["age"] != GameManager.AGE_IMPERIAL:
		return Assertions.AssertResult.new(false,
			"plate_mail_armor age should be Imperial, got: %d" % tech["age"])
	if tech["cost"].get("food", 0) != 300:
		return Assertions.AssertResult.new(false,
			"plate_mail_armor food cost should be 300, got: %d" % tech["cost"].get("food", 0))
	if tech["cost"].get("gold", 0) != 150:
		return Assertions.AssertResult.new(false,
			"plate_mail_armor gold cost should be 150, got: %d" % tech["cost"].get("gold", 0))
	# Effects: +1 melee, +2 pierce for infantry
	if tech["effects"].get("infantry_melee_armor", 0) != 1:
		return Assertions.AssertResult.new(false,
			"plate_mail_armor infantry_melee_armor should be 1, got: %d" % tech["effects"].get("infantry_melee_armor", 0))
	if tech["effects"].get("infantry_pierce_armor", 0) != 2:
		return Assertions.AssertResult.new(false,
			"plate_mail_armor infantry_pierce_armor should be 2, got: %d" % tech["effects"].get("infantry_pierce_armor", 0))
	return Assertions.AssertResult.new(true)


func test_plate_barding_armor_tech_definition() -> Assertions.AssertResult:
	## Plate Barding Armor: 350F+200G, Imperial, requires chain_barding_armor
	var tech = GameManager.TECHNOLOGIES.get("plate_barding_armor", {})
	if tech.is_empty():
		return Assertions.AssertResult.new(false, "plate_barding_armor tech not found")
	if tech["age"] != GameManager.AGE_IMPERIAL:
		return Assertions.AssertResult.new(false,
			"plate_barding_armor age should be Imperial, got: %d" % tech["age"])
	if tech["cost"].get("food", 0) != 350:
		return Assertions.AssertResult.new(false,
			"plate_barding_armor food cost should be 350, got: %d" % tech["cost"].get("food", 0))
	if tech["cost"].get("gold", 0) != 200:
		return Assertions.AssertResult.new(false,
			"plate_barding_armor gold cost should be 200, got: %d" % tech["cost"].get("gold", 0))
	# Effects: +1 melee, +2 pierce for cavalry
	if tech["effects"].get("cavalry_melee_armor", 0) != 1:
		return Assertions.AssertResult.new(false,
			"plate_barding_armor cavalry_melee_armor should be 1, got: %d" % tech["effects"].get("cavalry_melee_armor", 0))
	if tech["effects"].get("cavalry_pierce_armor", 0) != 2:
		return Assertions.AssertResult.new(false,
			"plate_barding_armor cavalry_pierce_armor should be 2, got: %d" % tech["effects"].get("cavalry_pierce_armor", 0))
	return Assertions.AssertResult.new(true)


func test_bracer_tech_definition() -> Assertions.AssertResult:
	## Bracer: 300F+200G, Imperial, requires bodkin_arrow
	var tech = GameManager.TECHNOLOGIES.get("bracer", {})
	if tech.is_empty():
		return Assertions.AssertResult.new(false, "bracer tech not found")
	if tech["age"] != GameManager.AGE_IMPERIAL:
		return Assertions.AssertResult.new(false,
			"bracer age should be Imperial, got: %d" % tech["age"])
	if tech["cost"].get("food", 0) != 300:
		return Assertions.AssertResult.new(false,
			"bracer food cost should be 300, got: %d" % tech["cost"].get("food", 0))
	if tech["cost"].get("gold", 0) != 200:
		return Assertions.AssertResult.new(false,
			"bracer gold cost should be 200, got: %d" % tech["cost"].get("gold", 0))
	# Effects: +1 attack, +1 range for archers
	if tech["effects"].get("archer_attack", 0) != 1:
		return Assertions.AssertResult.new(false,
			"bracer archer_attack should be 1, got: %d" % tech["effects"].get("archer_attack", 0))
	if tech["effects"].get("archer_range", 0) != 1:
		return Assertions.AssertResult.new(false,
			"bracer archer_range should be 1, got: %d" % tech["effects"].get("archer_range", 0))
	return Assertions.AssertResult.new(true)


func test_ring_archer_armor_tech_definition() -> Assertions.AssertResult:
	## Ring Archer Armor: 250F+250G, Imperial, requires leather_archer_armor
	var tech = GameManager.TECHNOLOGIES.get("ring_archer_armor", {})
	if tech.is_empty():
		return Assertions.AssertResult.new(false, "ring_archer_armor tech not found")
	if tech["age"] != GameManager.AGE_IMPERIAL:
		return Assertions.AssertResult.new(false,
			"ring_archer_armor age should be Imperial, got: %d" % tech["age"])
	if tech["cost"].get("food", 0) != 250:
		return Assertions.AssertResult.new(false,
			"ring_archer_armor food cost should be 250, got: %d" % tech["cost"].get("food", 0))
	if tech["cost"].get("gold", 0) != 250:
		return Assertions.AssertResult.new(false,
			"ring_archer_armor gold cost should be 250, got: %d" % tech["cost"].get("gold", 0))
	# Effects: +1 melee, +2 pierce for archers
	if tech["effects"].get("archer_melee_armor", 0) != 1:
		return Assertions.AssertResult.new(false,
			"ring_archer_armor archer_melee_armor should be 1, got: %d" % tech["effects"].get("archer_melee_armor", 0))
	if tech["effects"].get("archer_pierce_armor", 0) != 2:
		return Assertions.AssertResult.new(false,
			"ring_archer_armor archer_pierce_armor should be 2, got: %d" % tech["effects"].get("archer_pierce_armor", 0))
	return Assertions.AssertResult.new(true)


# =============================================================================
# Imperial Blacksmith Tech Prerequisites
# =============================================================================

func test_blast_furnace_requires_iron_casting() -> Assertions.AssertResult:
	## Blast Furnace needs iron_casting researched first
	GameManager.set_age(GameManager.AGE_IMPERIAL, 0)
	GameManager.resources["food"] = 5000
	GameManager.resources["gold"] = 5000
	# Without iron_casting, should be blocked
	if GameManager.can_research_tech("blast_furnace", 0):
		return Assertions.AssertResult.new(false,
			"blast_furnace should require iron_casting prereq")
	# Research prereqs
	GameManager.complete_tech_research("forging", 0)
	GameManager.complete_tech_research("iron_casting", 0)
	if not GameManager.can_research_tech("blast_furnace", 0):
		return Assertions.AssertResult.new(false,
			"blast_furnace should be researchable after iron_casting")
	return Assertions.AssertResult.new(true)


func test_plate_mail_armor_requires_chain_mail() -> Assertions.AssertResult:
	## Plate Mail Armor needs chain_mail_armor
	GameManager.set_age(GameManager.AGE_IMPERIAL, 0)
	GameManager.resources["food"] = 5000
	GameManager.resources["gold"] = 5000
	if GameManager.can_research_tech("plate_mail_armor", 0):
		return Assertions.AssertResult.new(false,
			"plate_mail_armor should require chain_mail_armor")
	GameManager.complete_tech_research("scale_mail_armor", 0)
	GameManager.complete_tech_research("chain_mail_armor", 0)
	if not GameManager.can_research_tech("plate_mail_armor", 0):
		return Assertions.AssertResult.new(false,
			"plate_mail_armor should be researchable after chain_mail_armor")
	return Assertions.AssertResult.new(true)


func test_plate_barding_armor_requires_chain_barding() -> Assertions.AssertResult:
	## Plate Barding Armor needs chain_barding_armor
	GameManager.set_age(GameManager.AGE_IMPERIAL, 0)
	GameManager.resources["food"] = 5000
	GameManager.resources["gold"] = 5000
	if GameManager.can_research_tech("plate_barding_armor", 0):
		return Assertions.AssertResult.new(false,
			"plate_barding_armor should require chain_barding_armor")
	GameManager.complete_tech_research("scale_barding_armor", 0)
	GameManager.complete_tech_research("chain_barding_armor", 0)
	if not GameManager.can_research_tech("plate_barding_armor", 0):
		return Assertions.AssertResult.new(false,
			"plate_barding_armor should be researchable after chain_barding_armor")
	return Assertions.AssertResult.new(true)


func test_bracer_requires_bodkin_arrow() -> Assertions.AssertResult:
	## Bracer needs bodkin_arrow
	GameManager.set_age(GameManager.AGE_IMPERIAL, 0)
	GameManager.resources["food"] = 5000
	GameManager.resources["gold"] = 5000
	if GameManager.can_research_tech("bracer", 0):
		return Assertions.AssertResult.new(false,
			"bracer should require bodkin_arrow")
	GameManager.complete_tech_research("fletching", 0)
	GameManager.complete_tech_research("bodkin_arrow", 0)
	if not GameManager.can_research_tech("bracer", 0):
		return Assertions.AssertResult.new(false,
			"bracer should be researchable after bodkin_arrow")
	return Assertions.AssertResult.new(true)


func test_ring_archer_armor_requires_leather_archer_armor() -> Assertions.AssertResult:
	## Ring Archer Armor needs leather_archer_armor
	GameManager.set_age(GameManager.AGE_IMPERIAL, 0)
	GameManager.resources["food"] = 5000
	GameManager.resources["gold"] = 5000
	if GameManager.can_research_tech("ring_archer_armor", 0):
		return Assertions.AssertResult.new(false,
			"ring_archer_armor should require leather_archer_armor")
	GameManager.complete_tech_research("padded_archer_armor", 0)
	GameManager.complete_tech_research("leather_archer_armor", 0)
	if not GameManager.can_research_tech("ring_archer_armor", 0):
		return Assertions.AssertResult.new(false,
			"ring_archer_armor should be researchable after leather_archer_armor")
	return Assertions.AssertResult.new(true)


# =============================================================================
# Imperial Blacksmith Tech Age Gating
# =============================================================================

func test_imperial_techs_blocked_in_castle_age() -> Assertions.AssertResult:
	## All 5 Imperial blacksmith techs should be blocked in Castle Age
	GameManager.set_age(GameManager.AGE_CASTLE, 0)
	GameManager.resources["food"] = 5000
	GameManager.resources["gold"] = 5000
	# Research all Castle prereqs so only age blocks us
	GameManager.complete_tech_research("forging", 0)
	GameManager.complete_tech_research("iron_casting", 0)
	GameManager.complete_tech_research("scale_mail_armor", 0)
	GameManager.complete_tech_research("chain_mail_armor", 0)
	GameManager.complete_tech_research("scale_barding_armor", 0)
	GameManager.complete_tech_research("chain_barding_armor", 0)
	GameManager.complete_tech_research("fletching", 0)
	GameManager.complete_tech_research("bodkin_arrow", 0)
	GameManager.complete_tech_research("padded_archer_armor", 0)
	GameManager.complete_tech_research("leather_archer_armor", 0)

	var imperial_techs = ["blast_furnace", "plate_mail_armor", "plate_barding_armor", "bracer", "ring_archer_armor"]
	for tech_id in imperial_techs:
		if GameManager.can_research_tech(tech_id, 0):
			return Assertions.AssertResult.new(false,
				"%s should be blocked in Castle Age" % tech_id)
	return Assertions.AssertResult.new(true)


func test_imperial_techs_available_in_imperial_age() -> Assertions.AssertResult:
	## All 5 Imperial blacksmith techs should be available in Imperial Age (with prereqs)
	GameManager.set_age(GameManager.AGE_IMPERIAL, 0)
	GameManager.resources["food"] = 5000
	GameManager.resources["gold"] = 5000
	# Research all prereqs
	GameManager.complete_tech_research("forging", 0)
	GameManager.complete_tech_research("iron_casting", 0)
	GameManager.complete_tech_research("scale_mail_armor", 0)
	GameManager.complete_tech_research("chain_mail_armor", 0)
	GameManager.complete_tech_research("scale_barding_armor", 0)
	GameManager.complete_tech_research("chain_barding_armor", 0)
	GameManager.complete_tech_research("fletching", 0)
	GameManager.complete_tech_research("bodkin_arrow", 0)
	GameManager.complete_tech_research("padded_archer_armor", 0)
	GameManager.complete_tech_research("leather_archer_armor", 0)

	var imperial_techs = ["blast_furnace", "plate_mail_armor", "plate_barding_armor", "bracer", "ring_archer_armor"]
	for tech_id in imperial_techs:
		if not GameManager.can_research_tech(tech_id, 0):
			return Assertions.AssertResult.new(false,
				"%s should be available in Imperial Age with prereqs" % tech_id)
	return Assertions.AssertResult.new(true)


# =============================================================================
# Imperial Blacksmith Tech Effects on Units
# =============================================================================

func test_blast_furnace_infantry_attack_bonus() -> Assertions.AssertResult:
	## Blast Furnace gives +2 infantry_attack (on top of forging +1 and iron_casting +1)
	var militia = runner.spawner.spawn_militia(Vector2(200, 200), 0)
	await runner.wait_frames(2)

	var base_attack = militia.attack_damage
	GameManager.complete_tech_research("forging", 0)
	GameManager.complete_tech_research("iron_casting", 0)
	GameManager.complete_tech_research("blast_furnace", 0)
	await runner.wait_frames(1)

	# Total bonus: forging(+1) + iron_casting(+1) + blast_furnace(+2) = +4
	var expected = base_attack + 4
	if militia.attack_damage != expected:
		return Assertions.AssertResult.new(false,
			"Militia attack should be %d after full attack line, got: %d" % [expected, militia.attack_damage])
	return Assertions.AssertResult.new(true)


func test_blast_furnace_cavalry_attack_bonus() -> Assertions.AssertResult:
	## Blast Furnace also gives +2 cavalry_attack
	var scout = runner.spawner.spawn_scout_cavalry(Vector2(200, 200), 0)
	await runner.wait_frames(2)

	var base_attack = scout.attack_damage
	GameManager.complete_tech_research("forging", 0)
	GameManager.complete_tech_research("iron_casting", 0)
	GameManager.complete_tech_research("blast_furnace", 0)
	await runner.wait_frames(1)

	var expected = base_attack + 4
	if scout.attack_damage != expected:
		return Assertions.AssertResult.new(false,
			"Scout attack should be %d after full attack line, got: %d" % [expected, scout.attack_damage])
	return Assertions.AssertResult.new(true)


func test_plate_mail_armor_infantry_armor_bonus() -> Assertions.AssertResult:
	## Full infantry armor line: scale(+1/+1) + chain(+1/+1) + plate(+1/+2) = +3/+4
	var militia = runner.spawner.spawn_militia(Vector2(200, 200), 0)
	await runner.wait_frames(2)

	var base_ma = militia.melee_armor
	var base_pa = militia.pierce_armor
	GameManager.complete_tech_research("scale_mail_armor", 0)
	GameManager.complete_tech_research("chain_mail_armor", 0)
	GameManager.complete_tech_research("plate_mail_armor", 0)
	await runner.wait_frames(1)

	if militia.melee_armor != base_ma + 3:
		return Assertions.AssertResult.new(false,
			"Militia melee_armor should be %d after full armor line, got: %d" % [base_ma + 3, militia.melee_armor])
	if militia.pierce_armor != base_pa + 4:
		return Assertions.AssertResult.new(false,
			"Militia pierce_armor should be %d after full armor line, got: %d" % [base_pa + 4, militia.pierce_armor])
	return Assertions.AssertResult.new(true)


func test_plate_barding_armor_cavalry_armor_bonus() -> Assertions.AssertResult:
	## Full cavalry armor line: scale(+1/+1) + chain(+1/+1) + plate(+1/+2) = +3/+4
	var scout = runner.spawner.spawn_scout_cavalry(Vector2(200, 200), 0)
	await runner.wait_frames(2)

	var base_ma = scout.melee_armor
	var base_pa = scout.pierce_armor
	GameManager.complete_tech_research("scale_barding_armor", 0)
	GameManager.complete_tech_research("chain_barding_armor", 0)
	GameManager.complete_tech_research("plate_barding_armor", 0)
	await runner.wait_frames(1)

	if scout.melee_armor != base_ma + 3:
		return Assertions.AssertResult.new(false,
			"Scout melee_armor should be %d after full barding line, got: %d" % [base_ma + 3, scout.melee_armor])
	if scout.pierce_armor != base_pa + 4:
		return Assertions.AssertResult.new(false,
			"Scout pierce_armor should be %d after full barding line, got: %d" % [base_pa + 4, scout.pierce_armor])
	return Assertions.AssertResult.new(true)


func test_bracer_archer_attack_and_range_bonus() -> Assertions.AssertResult:
	## Full archer attack line: fletching(+1/+32px) + bodkin(+1/+32px) + bracer(+1/+32px) = +3 atk, +96px range
	var archer = runner.spawner.spawn_archer(Vector2(200, 200), 0)
	await runner.wait_frames(2)

	var base_attack = archer.attack_damage
	var base_range = archer.attack_range
	GameManager.complete_tech_research("fletching", 0)
	GameManager.complete_tech_research("bodkin_arrow", 0)
	GameManager.complete_tech_research("bracer", 0)
	await runner.wait_frames(1)

	if archer.attack_damage != base_attack + 3:
		return Assertions.AssertResult.new(false,
			"Archer attack should be %d after full attack line, got: %d" % [base_attack + 3, archer.attack_damage])
	var expected_range = base_range + 96.0  # 3 * 32px per range level
	if abs(archer.attack_range - expected_range) > 0.5:
		return Assertions.AssertResult.new(false,
			"Archer range should be %.1f after full attack line, got: %.1f" % [expected_range, archer.attack_range])
	return Assertions.AssertResult.new(true)


func test_ring_archer_armor_archer_armor_bonus() -> Assertions.AssertResult:
	## Full archer armor line: padded(+1/+1) + leather(+1/+1) + ring(+1/+2) = +3/+4
	var archer = runner.spawner.spawn_archer(Vector2(200, 200), 0)
	await runner.wait_frames(2)

	var base_ma = archer.melee_armor
	var base_pa = archer.pierce_armor
	GameManager.complete_tech_research("padded_archer_armor", 0)
	GameManager.complete_tech_research("leather_archer_armor", 0)
	GameManager.complete_tech_research("ring_archer_armor", 0)
	await runner.wait_frames(1)

	if archer.melee_armor != base_ma + 3:
		return Assertions.AssertResult.new(false,
			"Archer melee_armor should be %d after full armor line, got: %d" % [base_ma + 3, archer.melee_armor])
	if archer.pierce_armor != base_pa + 4:
		return Assertions.AssertResult.new(false,
			"Archer pierce_armor should be %d after full armor line, got: %d" % [base_pa + 4, archer.pierce_armor])
	return Assertions.AssertResult.new(true)


# =============================================================================
# Full Blacksmith Line Stacking (3 tiers)
# =============================================================================

func test_full_infantry_attack_line_stacks() -> Assertions.AssertResult:
	## Forging(+1) + Iron Casting(+1) + Blast Furnace(+2) = +4 total infantry_attack bonus
	GameManager.complete_tech_research("forging", 0)
	GameManager.complete_tech_research("iron_casting", 0)
	GameManager.complete_tech_research("blast_furnace", 0)

	var bonus = GameManager.get_tech_bonus("infantry_attack", 0)
	if bonus != 4:
		return Assertions.AssertResult.new(false,
			"Full infantry attack line should give +4 bonus, got: %d" % bonus)
	return Assertions.AssertResult.new(true)


func test_full_archer_armor_line_stacks() -> Assertions.AssertResult:
	## Padded(+1) + Leather(+1) + Ring(+1) = +3 archer_melee_armor
	## Padded(+1) + Leather(+1) + Ring(+2) = +4 archer_pierce_armor
	GameManager.complete_tech_research("padded_archer_armor", 0)
	GameManager.complete_tech_research("leather_archer_armor", 0)
	GameManager.complete_tech_research("ring_archer_armor", 0)

	var melee_bonus = GameManager.get_tech_bonus("archer_melee_armor", 0)
	var pierce_bonus = GameManager.get_tech_bonus("archer_pierce_armor", 0)
	if melee_bonus != 3:
		return Assertions.AssertResult.new(false,
			"Full archer melee armor bonus should be +3, got: %d" % melee_bonus)
	if pierce_bonus != 4:
		return Assertions.AssertResult.new(false,
			"Full archer pierce armor bonus should be +4, got: %d" % pierce_bonus)
	return Assertions.AssertResult.new(true)


# =============================================================================
# Imperial Unit Upgrade: Two-Handed Swordsman
# =============================================================================

func test_two_handed_swordsman_tech_definition() -> Assertions.AssertResult:
	## Two-Handed Swordsman: 300F+100G, Imperial, requires long_swordsman
	var tech = GameManager.TECHNOLOGIES.get("two_handed_swordsman", {})
	if tech.is_empty():
		return Assertions.AssertResult.new(false, "two_handed_swordsman tech not found")
	if tech["age"] != GameManager.AGE_IMPERIAL:
		return Assertions.AssertResult.new(false,
			"two_handed_swordsman age should be Imperial, got: %d" % tech["age"])
	if tech["cost"].get("food", 0) != 300:
		return Assertions.AssertResult.new(false,
			"two_handed_swordsman food cost should be 300, got: %d" % tech["cost"].get("food", 0))
	if tech["cost"].get("gold", 0) != 100:
		return Assertions.AssertResult.new(false,
			"two_handed_swordsman gold cost should be 100, got: %d" % tech["cost"].get("gold", 0))
	if tech["requires"] != "long_swordsman":
		return Assertions.AssertResult.new(false,
			"two_handed_swordsman should require long_swordsman, got: '%s'" % tech["requires"])
	if tech.get("type", "") != "unit_upgrade":
		return Assertions.AssertResult.new(false,
			"two_handed_swordsman should be type 'unit_upgrade'")
	return Assertions.AssertResult.new(true)


func test_long_swordsman_to_two_handed_swordsman_stats() -> Assertions.AssertResult:
	## Militia -> Man-at-Arms -> Long Swordsman -> Two-Handed Swordsman: 60 HP, 11 atk
	GameManager.set_age(GameManager.AGE_IMPERIAL, 0)
	var militia = runner.spawner.spawn_militia(Vector2(400, 400), 0)
	await runner.wait_frames(2)

	GameManager.complete_tech_research("man_at_arms", 0)
	GameManager.complete_tech_research("long_swordsman", 0)
	GameManager.complete_tech_research("two_handed_swordsman", 0)
	await runner.wait_frames(2)

	if militia.max_hp != 60:
		return Assertions.AssertResult.new(false,
			"Two-Handed Swordsman max_hp should be 60, got: %d" % militia.max_hp)
	if militia.attack_damage != 11:
		return Assertions.AssertResult.new(false,
			"Two-Handed Swordsman attack should be 11, got: %d" % militia.attack_damage)
	if militia.unit_display_name != "Two-Handed Swordsman":
		return Assertions.AssertResult.new(false,
			"Display name should be 'Two-Handed Swordsman', got: '%s'" % militia.unit_display_name)
	return Assertions.AssertResult.new(true)


func test_two_handed_swordsman_group_swap() -> Assertions.AssertResult:
	## After upgrade, should be in two_handed_swordsmen group, not long_swordsmen
	GameManager.set_age(GameManager.AGE_IMPERIAL, 0)
	var militia = runner.spawner.spawn_militia(Vector2(400, 400), 0)
	await runner.wait_frames(2)

	GameManager.complete_tech_research("man_at_arms", 0)
	GameManager.complete_tech_research("long_swordsman", 0)
	GameManager.complete_tech_research("two_handed_swordsman", 0)
	await runner.wait_frames(2)

	if not militia.is_in_group("two_handed_swordsmen"):
		return Assertions.AssertResult.new(false,
			"Unit should be in 'two_handed_swordsmen' group")
	if militia.is_in_group("long_swordsmen"):
		return Assertions.AssertResult.new(false,
			"Unit should NOT be in 'long_swordsmen' group")
	if not militia.is_in_group("infantry"):
		return Assertions.AssertResult.new(false,
			"Unit should still be in 'infantry' group")
	if not militia.is_in_group("military"):
		return Assertions.AssertResult.new(false,
			"Unit should still be in 'military' group")
	return Assertions.AssertResult.new(true)


# =============================================================================
# Imperial Unit Upgrade: Champion
# =============================================================================

func test_champion_tech_definition() -> Assertions.AssertResult:
	## Champion: 750F+350G, Imperial, requires two_handed_swordsman
	var tech = GameManager.TECHNOLOGIES.get("champion", {})
	if tech.is_empty():
		return Assertions.AssertResult.new(false, "champion tech not found")
	if tech["age"] != GameManager.AGE_IMPERIAL:
		return Assertions.AssertResult.new(false,
			"champion age should be Imperial, got: %d" % tech["age"])
	if tech["cost"].get("food", 0) != 750:
		return Assertions.AssertResult.new(false,
			"champion food cost should be 750, got: %d" % tech["cost"].get("food", 0))
	if tech["cost"].get("gold", 0) != 350:
		return Assertions.AssertResult.new(false,
			"champion gold cost should be 350, got: %d" % tech["cost"].get("gold", 0))
	if tech["requires"] != "two_handed_swordsman":
		return Assertions.AssertResult.new(false,
			"champion should require two_handed_swordsman, got: '%s'" % tech["requires"])
	return Assertions.AssertResult.new(true)


func test_two_handed_swordsman_to_champion_stats() -> Assertions.AssertResult:
	## Two-Handed Swordsman -> Champion: 70 HP, 13 atk, 1/0 armor
	GameManager.set_age(GameManager.AGE_IMPERIAL, 0)
	var militia = runner.spawner.spawn_militia(Vector2(400, 400), 0)
	await runner.wait_frames(2)

	GameManager.complete_tech_research("man_at_arms", 0)
	GameManager.complete_tech_research("long_swordsman", 0)
	GameManager.complete_tech_research("two_handed_swordsman", 0)
	GameManager.complete_tech_research("champion", 0)
	await runner.wait_frames(2)

	if militia.max_hp != 70:
		return Assertions.AssertResult.new(false,
			"Champion max_hp should be 70, got: %d" % militia.max_hp)
	if militia.attack_damage != 13:
		return Assertions.AssertResult.new(false,
			"Champion attack should be 13, got: %d" % militia.attack_damage)
	if militia.melee_armor != 1:
		return Assertions.AssertResult.new(false,
			"Champion melee_armor should be 1, got: %d" % militia.melee_armor)
	if not militia.is_in_group("champions"):
		return Assertions.AssertResult.new(false,
			"Unit should be in 'champions' group")
	if militia.is_in_group("two_handed_swordsmen"):
		return Assertions.AssertResult.new(false,
			"Unit should NOT be in 'two_handed_swordsmen' group")
	return Assertions.AssertResult.new(true)


func test_champion_full_chain_from_militia() -> Assertions.AssertResult:
	## Complete chain: militia(40/4) -> maa(45/6) -> ls(55/9) -> ths(60/11) -> champ(70/13)
	## Spawn militia, apply all 4 upgrades, verify final display name
	GameManager.set_age(GameManager.AGE_IMPERIAL, 0)
	var militia = runner.spawner.spawn_militia(Vector2(400, 400), 0)
	await runner.wait_frames(2)

	GameManager.complete_tech_research("man_at_arms", 0)
	GameManager.complete_tech_research("long_swordsman", 0)
	GameManager.complete_tech_research("two_handed_swordsman", 0)
	GameManager.complete_tech_research("champion", 0)
	await runner.wait_frames(2)

	if militia.unit_display_name != "Champion":
		return Assertions.AssertResult.new(false,
			"Full chain should end as 'Champion', got: '%s'" % militia.unit_display_name)
	if militia.max_hp != 70:
		return Assertions.AssertResult.new(false,
			"Champion HP should be 70, got: %d" % militia.max_hp)
	return Assertions.AssertResult.new(true)


# =============================================================================
# Imperial Unit Upgrade: Arbalester
# =============================================================================

func test_arbalester_tech_definition() -> Assertions.AssertResult:
	## Arbalester: 350F+300G, Imperial, requires crossbowman
	var tech = GameManager.TECHNOLOGIES.get("arbalester", {})
	if tech.is_empty():
		return Assertions.AssertResult.new(false, "arbalester tech not found")
	if tech["age"] != GameManager.AGE_IMPERIAL:
		return Assertions.AssertResult.new(false,
			"arbalester age should be Imperial, got: %d" % tech["age"])
	if tech["cost"].get("food", 0) != 350:
		return Assertions.AssertResult.new(false,
			"arbalester food cost should be 350, got: %d" % tech["cost"].get("food", 0))
	if tech["cost"].get("gold", 0) != 300:
		return Assertions.AssertResult.new(false,
			"arbalester gold cost should be 300, got: %d" % tech["cost"].get("gold", 0))
	if tech["requires"] != "crossbowman":
		return Assertions.AssertResult.new(false,
			"arbalester should require crossbowman, got: '%s'" % tech["requires"])
	return Assertions.AssertResult.new(true)


func test_crossbowman_to_arbalester_stats() -> Assertions.AssertResult:
	## Archer -> Crossbowman -> Arbalester: 40 HP, 6 atk, 160 range
	GameManager.set_age(GameManager.AGE_IMPERIAL, 0)
	var archer = runner.spawner.spawn_archer(Vector2(400, 400), 0)
	await runner.wait_frames(2)

	GameManager.complete_tech_research("crossbowman", 0)
	GameManager.complete_tech_research("arbalester", 0)
	await runner.wait_frames(2)

	if archer.max_hp != 40:
		return Assertions.AssertResult.new(false,
			"Arbalester max_hp should be 40, got: %d" % archer.max_hp)
	if archer.attack_damage != 6:
		return Assertions.AssertResult.new(false,
			"Arbalester attack should be 6, got: %d" % archer.attack_damage)
	if abs(archer.attack_range - 160.0) > 0.5:
		return Assertions.AssertResult.new(false,
			"Arbalester range should be 160.0, got: %.1f" % archer.attack_range)
	if archer.unit_display_name != "Arbalester":
		return Assertions.AssertResult.new(false,
			"Display name should be 'Arbalester', got: '%s'" % archer.unit_display_name)
	return Assertions.AssertResult.new(true)


func test_arbalester_group_swap() -> Assertions.AssertResult:
	## Arbalester should be in arbalesters group, not crossbowmen
	GameManager.set_age(GameManager.AGE_IMPERIAL, 0)
	var archer = runner.spawner.spawn_archer(Vector2(400, 400), 0)
	await runner.wait_frames(2)

	GameManager.complete_tech_research("crossbowman", 0)
	GameManager.complete_tech_research("arbalester", 0)
	await runner.wait_frames(2)

	if not archer.is_in_group("arbalesters"):
		return Assertions.AssertResult.new(false,
			"Unit should be in 'arbalesters' group")
	if archer.is_in_group("crossbowmen"):
		return Assertions.AssertResult.new(false,
			"Unit should NOT be in 'crossbowmen' group")
	return Assertions.AssertResult.new(true)


# =============================================================================
# Imperial Unit Upgrade: Cavalier
# =============================================================================

func test_cavalier_tech_definition() -> Assertions.AssertResult:
	## Cavalier: 300F+300G, Imperial, no prereq (from knights)
	var tech = GameManager.TECHNOLOGIES.get("cavalier", {})
	if tech.is_empty():
		return Assertions.AssertResult.new(false, "cavalier tech not found")
	if tech["age"] != GameManager.AGE_IMPERIAL:
		return Assertions.AssertResult.new(false,
			"cavalier age should be Imperial, got: %d" % tech["age"])
	if tech["cost"].get("food", 0) != 300:
		return Assertions.AssertResult.new(false,
			"cavalier food cost should be 300, got: %d" % tech["cost"].get("food", 0))
	if tech["cost"].get("gold", 0) != 300:
		return Assertions.AssertResult.new(false,
			"cavalier gold cost should be 300, got: %d" % tech["cost"].get("gold", 0))
	if tech["from_group"] != "knights":
		return Assertions.AssertResult.new(false,
			"cavalier from_group should be 'knights', got: '%s'" % tech["from_group"])
	return Assertions.AssertResult.new(true)


func test_knight_to_cavalier_stats() -> Assertions.AssertResult:
	## Knight -> Cavalier: 120 HP, 12 atk, 2/2 armor
	GameManager.set_age(GameManager.AGE_IMPERIAL, 0)
	var knight = runner.spawner.spawn_knight(Vector2(400, 400), 0)
	await runner.wait_frames(2)

	GameManager.complete_tech_research("cavalier", 0)
	await runner.wait_frames(2)

	if knight.max_hp != 120:
		return Assertions.AssertResult.new(false,
			"Cavalier max_hp should be 120, got: %d" % knight.max_hp)
	if knight.attack_damage != 12:
		return Assertions.AssertResult.new(false,
			"Cavalier attack should be 12, got: %d" % knight.attack_damage)
	if knight.melee_armor != 2:
		return Assertions.AssertResult.new(false,
			"Cavalier melee_armor should be 2, got: %d" % knight.melee_armor)
	if knight.pierce_armor != 2:
		return Assertions.AssertResult.new(false,
			"Cavalier pierce_armor should be 2, got: %d" % knight.pierce_armor)
	if knight.unit_display_name != "Cavalier":
		return Assertions.AssertResult.new(false,
			"Display name should be 'Cavalier', got: '%s'" % knight.unit_display_name)
	return Assertions.AssertResult.new(true)


func test_cavalier_group_swap() -> Assertions.AssertResult:
	## Cavalier should be in cavaliers group, not knights
	GameManager.set_age(GameManager.AGE_IMPERIAL, 0)
	var knight = runner.spawner.spawn_knight(Vector2(400, 400), 0)
	await runner.wait_frames(2)

	GameManager.complete_tech_research("cavalier", 0)
	await runner.wait_frames(2)

	if not knight.is_in_group("cavaliers"):
		return Assertions.AssertResult.new(false,
			"Unit should be in 'cavaliers' group")
	if knight.is_in_group("knights"):
		return Assertions.AssertResult.new(false,
			"Unit should NOT be in 'knights' group")
	if not knight.is_in_group("cavalry"):
		return Assertions.AssertResult.new(false,
			"Unit should still be in 'cavalry' group")
	return Assertions.AssertResult.new(true)


# =============================================================================
# Imperial Unit Upgrade: Paladin
# =============================================================================

func test_paladin_tech_definition() -> Assertions.AssertResult:
	## Paladin: 1300F+750G, Imperial, requires cavalier
	var tech = GameManager.TECHNOLOGIES.get("paladin", {})
	if tech.is_empty():
		return Assertions.AssertResult.new(false, "paladin tech not found")
	if tech["age"] != GameManager.AGE_IMPERIAL:
		return Assertions.AssertResult.new(false,
			"paladin age should be Imperial, got: %d" % tech["age"])
	if tech["cost"].get("food", 0) != 1300:
		return Assertions.AssertResult.new(false,
			"paladin food cost should be 1300, got: %d" % tech["cost"].get("food", 0))
	if tech["cost"].get("gold", 0) != 750:
		return Assertions.AssertResult.new(false,
			"paladin gold cost should be 750, got: %d" % tech["cost"].get("gold", 0))
	if tech["requires"] != "cavalier":
		return Assertions.AssertResult.new(false,
			"paladin should require cavalier, got: '%s'" % tech["requires"])
	return Assertions.AssertResult.new(true)


func test_cavalier_to_paladin_stats() -> Assertions.AssertResult:
	## Knight -> Cavalier -> Paladin: 160 HP, 14 atk, 2/3 armor
	GameManager.set_age(GameManager.AGE_IMPERIAL, 0)
	var knight = runner.spawner.spawn_knight(Vector2(400, 400), 0)
	await runner.wait_frames(2)

	GameManager.complete_tech_research("cavalier", 0)
	GameManager.complete_tech_research("paladin", 0)
	await runner.wait_frames(2)

	if knight.max_hp != 160:
		return Assertions.AssertResult.new(false,
			"Paladin max_hp should be 160, got: %d" % knight.max_hp)
	if knight.attack_damage != 14:
		return Assertions.AssertResult.new(false,
			"Paladin attack should be 14, got: %d" % knight.attack_damage)
	if knight.melee_armor != 2:
		return Assertions.AssertResult.new(false,
			"Paladin melee_armor should be 2, got: %d" % knight.melee_armor)
	if knight.pierce_armor != 3:
		return Assertions.AssertResult.new(false,
			"Paladin pierce_armor should be 3, got: %d" % knight.pierce_armor)
	if knight.unit_display_name != "Paladin":
		return Assertions.AssertResult.new(false,
			"Display name should be 'Paladin', got: '%s'" % knight.unit_display_name)
	return Assertions.AssertResult.new(true)


func test_paladin_full_chain_from_knight() -> Assertions.AssertResult:
	## Knight -> Cavalier -> Paladin: verify group and name at end of chain
	GameManager.set_age(GameManager.AGE_IMPERIAL, 0)
	var knight = runner.spawner.spawn_knight(Vector2(400, 400), 0)
	await runner.wait_frames(2)

	GameManager.complete_tech_research("cavalier", 0)
	GameManager.complete_tech_research("paladin", 0)
	await runner.wait_frames(2)

	if not knight.is_in_group("paladins"):
		return Assertions.AssertResult.new(false,
			"Unit should be in 'paladins' group")
	if knight.is_in_group("cavaliers"):
		return Assertions.AssertResult.new(false,
			"Unit should NOT be in 'cavaliers' group")
	if knight.is_in_group("knights"):
		return Assertions.AssertResult.new(false,
			"Unit should NOT be in 'knights' group")
	return Assertions.AssertResult.new(true)


# =============================================================================
# Imperial Unit Upgrade: Siege Ram
# =============================================================================

func test_siege_ram_tech_definition() -> Assertions.AssertResult:
	## Siege Ram: 1000F+800G, Imperial, requires capped_ram
	var tech = GameManager.TECHNOLOGIES.get("siege_ram", {})
	if tech.is_empty():
		return Assertions.AssertResult.new(false, "siege_ram tech not found")
	if tech["age"] != GameManager.AGE_IMPERIAL:
		return Assertions.AssertResult.new(false,
			"siege_ram age should be Imperial, got: %d" % tech["age"])
	if tech["cost"].get("food", 0) != 1000:
		return Assertions.AssertResult.new(false,
			"siege_ram food cost should be 1000, got: %d" % tech["cost"].get("food", 0))
	if tech["cost"].get("gold", 0) != 800:
		return Assertions.AssertResult.new(false,
			"siege_ram gold cost should be 800, got: %d" % tech["cost"].get("gold", 0))
	if tech["requires"] != "capped_ram":
		return Assertions.AssertResult.new(false,
			"siege_ram should require capped_ram, got: '%s'" % tech["requires"])
	return Assertions.AssertResult.new(true)


func test_capped_ram_to_siege_ram_stats() -> Assertions.AssertResult:
	## Battering Ram -> Capped Ram -> Siege Ram: 270 HP, 4 atk, 195 pierce armor
	GameManager.set_age(GameManager.AGE_IMPERIAL, 0)
	var ram = runner.spawner.spawn_battering_ram(Vector2(400, 400), 0)
	await runner.wait_frames(2)

	GameManager.complete_tech_research("capped_ram", 0)
	GameManager.complete_tech_research("siege_ram", 0)
	await runner.wait_frames(2)

	if ram.max_hp != 270:
		return Assertions.AssertResult.new(false,
			"Siege Ram max_hp should be 270, got: %d" % ram.max_hp)
	if ram.attack_damage != 4:
		return Assertions.AssertResult.new(false,
			"Siege Ram attack should be 4, got: %d" % ram.attack_damage)
	if ram.pierce_armor != 195:
		return Assertions.AssertResult.new(false,
			"Siege Ram pierce_armor should be 195, got: %d" % ram.pierce_armor)
	if ram.unit_display_name != "Siege Ram":
		return Assertions.AssertResult.new(false,
			"Display name should be 'Siege Ram', got: '%s'" % ram.unit_display_name)
	return Assertions.AssertResult.new(true)


func test_siege_ram_group_swap() -> Assertions.AssertResult:
	## Siege Ram should be in siege_rams group, not capped_rams or battering_rams
	GameManager.set_age(GameManager.AGE_IMPERIAL, 0)
	var ram = runner.spawner.spawn_battering_ram(Vector2(400, 400), 0)
	await runner.wait_frames(2)

	GameManager.complete_tech_research("capped_ram", 0)
	GameManager.complete_tech_research("siege_ram", 0)
	await runner.wait_frames(2)

	if not ram.is_in_group("siege_rams"):
		return Assertions.AssertResult.new(false,
			"Unit should be in 'siege_rams' group")
	if ram.is_in_group("capped_rams"):
		return Assertions.AssertResult.new(false,
			"Unit should NOT be in 'capped_rams' group")
	if ram.is_in_group("battering_rams"):
		return Assertions.AssertResult.new(false,
			"Unit should NOT be in 'battering_rams' group")
	return Assertions.AssertResult.new(true)


# =============================================================================
# Newly Spawned Units Auto-Apply Upgrade Chains
# =============================================================================

func test_new_militia_spawns_as_two_handed_swordsman() -> Assertions.AssertResult:
	## Militia spawned after man_at_arms + long_swordsman + two_handed_swordsman should auto-apply
	GameManager.set_age(GameManager.AGE_IMPERIAL, 0)
	GameManager.complete_tech_research("man_at_arms", 0)
	GameManager.complete_tech_research("long_swordsman", 0)
	GameManager.complete_tech_research("two_handed_swordsman", 0)
	await runner.wait_frames(2)

	var militia = runner.spawner.spawn_militia(Vector2(400, 400), 0)
	await runner.wait_frames(2)

	if militia.max_hp != 60:
		return Assertions.AssertResult.new(false,
			"New militia should auto-upgrade to Two-Handed Swordsman (60 HP), got: %d" % militia.max_hp)
	if militia.attack_damage != 11:
		return Assertions.AssertResult.new(false,
			"New militia should have Two-Handed Swordsman attack (11), got: %d" % militia.attack_damage)
	if not militia.is_in_group("two_handed_swordsmen"):
		return Assertions.AssertResult.new(false,
			"New militia should be in 'two_handed_swordsmen' group")
	if militia.unit_display_name != "Two-Handed Swordsman":
		return Assertions.AssertResult.new(false,
			"New militia display_name should be 'Two-Handed Swordsman', got: '%s'" % militia.unit_display_name)
	return Assertions.AssertResult.new(true)


func test_new_militia_spawns_as_champion() -> Assertions.AssertResult:
	## Militia spawned after all 4 upgrades should auto-apply to Champion
	GameManager.set_age(GameManager.AGE_IMPERIAL, 0)
	GameManager.complete_tech_research("man_at_arms", 0)
	GameManager.complete_tech_research("long_swordsman", 0)
	GameManager.complete_tech_research("two_handed_swordsman", 0)
	GameManager.complete_tech_research("champion", 0)
	await runner.wait_frames(2)

	var militia = runner.spawner.spawn_militia(Vector2(400, 400), 0)
	await runner.wait_frames(2)

	if militia.max_hp != 70:
		return Assertions.AssertResult.new(false,
			"New militia should auto-upgrade to Champion (70 HP), got: %d" % militia.max_hp)
	if militia.attack_damage != 13:
		return Assertions.AssertResult.new(false,
			"New militia should have Champion attack (13), got: %d" % militia.attack_damage)
	if not militia.is_in_group("champions"):
		return Assertions.AssertResult.new(false,
			"New militia should be in 'champions' group")
	if militia.unit_display_name != "Champion":
		return Assertions.AssertResult.new(false,
			"New militia display_name should be 'Champion', got: '%s'" % militia.unit_display_name)
	return Assertions.AssertResult.new(true)


# =============================================================================
# Upgrade Team Isolation
# =============================================================================

func test_imperial_upgrade_only_affects_own_team() -> Assertions.AssertResult:
	## Player's Two-Handed Swordsman upgrade should not affect AI's long swordsmen
	GameManager.set_age(GameManager.AGE_IMPERIAL, 0)
	GameManager.set_age(GameManager.AGE_IMPERIAL, 1)
	var player_militia = runner.spawner.spawn_militia(Vector2(400, 400), 0)
	var ai_militia = runner.spawner.spawn_militia(Vector2(600, 400), 1)
	await runner.wait_frames(2)

	# Upgrade both to long_swordsman via their respective teams
	GameManager.complete_tech_research("man_at_arms", 0)
	GameManager.complete_tech_research("long_swordsman", 0)
	GameManager.complete_tech_research("man_at_arms", 1)
	GameManager.complete_tech_research("long_swordsman", 1)
	await runner.wait_frames(2)

	# Only upgrade player to two_handed_swordsman
	GameManager.complete_tech_research("two_handed_swordsman", 0)
	await runner.wait_frames(2)

	if player_militia.max_hp != 60:
		return Assertions.AssertResult.new(false,
			"Player should be Two-Handed Swordsman (60 HP), got: %d" % player_militia.max_hp)
	if ai_militia.max_hp != 55:
		return Assertions.AssertResult.new(false,
			"AI should remain Long Swordsman (55 HP), got: %d" % ai_militia.max_hp)
	if not ai_militia.is_in_group("long_swordsmen"):
		return Assertions.AssertResult.new(false,
			"AI should still be in 'long_swordsmen' group")
	return Assertions.AssertResult.new(true)


# =============================================================================
# Tech Bonus Reapplied After Imperial Upgrade
# =============================================================================

func test_tech_bonus_reapplied_after_two_handed_swordsman_upgrade() -> Assertions.AssertResult:
	## After upgrading, Blacksmith bonuses should still apply on new base stats
	GameManager.set_age(GameManager.AGE_IMPERIAL, 0)
	var militia = runner.spawner.spawn_militia(Vector2(400, 400), 0)
	await runner.wait_frames(2)

	# Research forging (+1 infantry attack) first
	GameManager.complete_tech_research("forging", 0)
	await runner.wait_frames(1)

	# Upgrade chain
	GameManager.complete_tech_research("man_at_arms", 0)
	GameManager.complete_tech_research("long_swordsman", 0)
	GameManager.complete_tech_research("two_handed_swordsman", 0)
	await runner.wait_frames(2)

	# Two-Handed Swordsman base attack = 11, + forging(+1) = 12
	if militia.attack_damage != 12:
		return Assertions.AssertResult.new(false,
			"Two-Handed Swordsman with forging should have 12 attack (11+1), got: %d" % militia.attack_damage)
	return Assertions.AssertResult.new(true)


# =============================================================================
# Imperial Age Advancement Conditions
# =============================================================================

func test_imperial_age_cost() -> Assertions.AssertResult:
	## Imperial Age costs 1000 food + 800 gold
	var costs = GameManager.AGE_COSTS[GameManager.AGE_IMPERIAL]
	if costs.get("food", 0) != 1000:
		return Assertions.AssertResult.new(false,
			"Imperial Age food cost should be 1000, got: %d" % costs.get("food", 0))
	if costs.get("gold", 0) != 800:
		return Assertions.AssertResult.new(false,
			"Imperial Age gold cost should be 800, got: %d" % costs.get("gold", 0))
	return Assertions.AssertResult.new(true)


func test_qualifying_buildings_for_imperial() -> Assertions.AssertResult:
	## Imperial qualifying groups should be monasteries and universities
	var groups = GameManager.AGE_QUALIFYING_GROUPS[GameManager.AGE_IMPERIAL]
	if not groups.has("monasteries"):
		return Assertions.AssertResult.new(false,
			"Imperial qualifying groups should include 'monasteries', got: %s" % str(groups))
	if not groups.has("universities"):
		return Assertions.AssertResult.new(false,
			"Imperial qualifying groups should include 'universities', got: %s" % str(groups))
	if groups.size() != 2:
		return Assertions.AssertResult.new(false,
			"Imperial should have exactly 2 qualifying groups, got: %d" % groups.size())
	return Assertions.AssertResult.new(true)


func test_qualifying_count_imperial_needs_monastery_and_university() -> Assertions.AssertResult:
	## Having both a monastery and university should give count = 2
	GameManager.set_age(GameManager.AGE_CASTLE, 0)
	runner.spawner.spawn_monastery(Vector2(300, 300), 0)
	runner.spawner.spawn_university(Vector2(400, 300), 0)
	await runner.wait_frames(2)

	var count = GameManager.get_qualifying_building_count(GameManager.AGE_IMPERIAL, 0)
	if count != 2:
		return Assertions.AssertResult.new(false,
			"Qualifying count should be 2 with monastery + university, got: %d" % count)
	return Assertions.AssertResult.new(true)


func test_cannot_advance_to_imperial_without_qualifying_buildings() -> Assertions.AssertResult:
	## Castle Age player with resources but no qualifying buildings should not advance
	GameManager.set_age(GameManager.AGE_CASTLE, 0)
	GameManager.resources["food"] = 2000
	GameManager.resources["gold"] = 2000
	# No monastery or university

	if GameManager.can_advance_age(0):
		return Assertions.AssertResult.new(false,
			"Should not be able to advance to Imperial without monastery + university")
	return Assertions.AssertResult.new(true)


func test_can_advance_to_imperial_with_all_requirements() -> Assertions.AssertResult:
	## Castle Age player with resources and qualifying buildings should advance
	GameManager.set_age(GameManager.AGE_CASTLE, 0)
	GameManager.resources["food"] = 2000
	GameManager.resources["gold"] = 2000
	runner.spawner.spawn_monastery(Vector2(300, 300), 0)
	runner.spawner.spawn_university(Vector2(400, 300), 0)
	await runner.wait_frames(2)

	if not GameManager.can_advance_age(0):
		var count = GameManager.get_qualifying_building_count(GameManager.AGE_IMPERIAL, 0)
		return Assertions.AssertResult.new(false,
			"Should be able to advance to Imperial (qual_count=%d)" % count)
	return Assertions.AssertResult.new(true)


# =============================================================================
# AI: AdvanceToImperialAgeRule
# =============================================================================

func test_ai_imperial_rule_fires_when_ready() -> Assertions.AssertResult:
	## AdvanceToImperialAgeRule should fire when all conditions met
	var gs = _create_ai_game_state()

	# Must be in Castle Age
	GameManager.set_age(GameManager.AGE_CASTLE, 1)
	GameManager.ai_resources["food"] = 2000
	GameManager.ai_resources["gold"] = 1000
	GameManager.ai_population = 0
	GameManager.ai_population_cap = 50

	# 20+ villagers
	for i in range(20):
		var villager = runner.spawner.spawn_villager(Vector2(1600 + (i % 5) * 30, 1600 + (i / 5) * 30), 1)
		villager.current_state = Villager.State.IDLE

	# 2 qualifying Castle buildings (monastery + university)
	runner.spawner.spawn_monastery(Vector2(1500, 1500), 1)
	runner.spawner.spawn_university(Vector2(1400, 1500), 1)
	# Need TC for research
	runner.spawner.spawn_town_center(Vector2(1700, 1700), 1)
	await runner.wait_frames(2)

	var rule = AIRules.AdvanceToImperialAgeRule.new()
	var should_fire = rule.conditions(gs)

	if not should_fire:
		var age = gs.get_age()
		var vill_count = gs.get_civilian_population()
		var qual_count = gs.get_qualifying_building_count(GameManager.AGE_IMPERIAL)
		var can_adv = gs.can_advance_age()
		return Assertions.AssertResult.new(false,
			"AdvanceToImperialAgeRule should fire. age=%d, vills=%d, qual=%d, can_advance=%s" % [
				age, vill_count, qual_count, str(can_adv)])
	return Assertions.AssertResult.new(true)


func test_ai_imperial_rule_blocks_wrong_age() -> Assertions.AssertResult:
	## AdvanceToImperialAgeRule should not fire in Feudal Age
	var gs = _create_ai_game_state()

	GameManager.set_age(GameManager.AGE_FEUDAL, 1)
	GameManager.ai_resources["food"] = 2000
	GameManager.ai_resources["gold"] = 1000

	for i in range(20):
		runner.spawner.spawn_villager(Vector2(1600 + (i % 5) * 30, 1600 + (i / 5) * 30), 1)
	runner.spawner.spawn_monastery(Vector2(1500, 1500), 1)
	runner.spawner.spawn_university(Vector2(1400, 1500), 1)
	await runner.wait_frames(2)

	var rule = AIRules.AdvanceToImperialAgeRule.new()
	if rule.conditions(gs):
		return Assertions.AssertResult.new(false,
			"AdvanceToImperialAgeRule should not fire in Feudal Age")
	return Assertions.AssertResult.new(true)


func test_ai_imperial_rule_blocks_insufficient_villagers() -> Assertions.AssertResult:
	## AdvanceToImperialAgeRule should not fire with <20 villagers
	var gs = _create_ai_game_state()

	GameManager.set_age(GameManager.AGE_CASTLE, 1)
	GameManager.ai_resources["food"] = 2000
	GameManager.ai_resources["gold"] = 1000
	GameManager.ai_population = 0
	GameManager.ai_population_cap = 50

	# Only 19 villagers
	for i in range(19):
		var villager = runner.spawner.spawn_villager(Vector2(1600 + (i % 5) * 30, 1600 + (i / 5) * 30), 1)
		villager.current_state = Villager.State.IDLE

	runner.spawner.spawn_monastery(Vector2(1500, 1500), 1)
	runner.spawner.spawn_university(Vector2(1400, 1500), 1)
	runner.spawner.spawn_town_center(Vector2(1700, 1700), 1)
	await runner.wait_frames(2)

	var rule = AIRules.AdvanceToImperialAgeRule.new()
	if rule.conditions(gs):
		return Assertions.AssertResult.new(false,
			"AdvanceToImperialAgeRule should not fire with only 19 villagers")
	return Assertions.AssertResult.new(true)


func test_ai_imperial_rule_blocks_insufficient_buildings() -> Assertions.AssertResult:
	## AdvanceToImperialAgeRule should not fire without 2 qualifying buildings
	var gs = _create_ai_game_state()

	GameManager.set_age(GameManager.AGE_CASTLE, 1)
	GameManager.ai_resources["food"] = 2000
	GameManager.ai_resources["gold"] = 1000
	GameManager.ai_population = 0
	GameManager.ai_population_cap = 50

	for i in range(20):
		var villager = runner.spawner.spawn_villager(Vector2(1600 + (i % 5) * 30, 1600 + (i / 5) * 30), 1)
		villager.current_state = Villager.State.IDLE

	# Only a monastery - no university
	runner.spawner.spawn_monastery(Vector2(1500, 1500), 1)
	runner.spawner.spawn_town_center(Vector2(1700, 1700), 1)
	await runner.wait_frames(2)

	var rule = AIRules.AdvanceToImperialAgeRule.new()
	if rule.conditions(gs):
		return Assertions.AssertResult.new(false,
			"AdvanceToImperialAgeRule should not fire with only 1 qualifying building")
	return Assertions.AssertResult.new(true)


func test_ai_imperial_rule_blocks_insufficient_resources() -> Assertions.AssertResult:
	## AdvanceToImperialAgeRule should not fire without 1000F + 800G
	var gs = _create_ai_game_state()

	GameManager.set_age(GameManager.AGE_CASTLE, 1)
	GameManager.ai_resources["food"] = 500  # Not enough
	GameManager.ai_resources["gold"] = 100  # Not enough
	GameManager.ai_population = 0
	GameManager.ai_population_cap = 50

	for i in range(20):
		var villager = runner.spawner.spawn_villager(Vector2(1600 + (i % 5) * 30, 1600 + (i / 5) * 30), 1)
		villager.current_state = Villager.State.IDLE

	runner.spawner.spawn_monastery(Vector2(1500, 1500), 1)
	runner.spawner.spawn_university(Vector2(1400, 1500), 1)
	runner.spawner.spawn_town_center(Vector2(1700, 1700), 1)
	await runner.wait_frames(2)

	var rule = AIRules.AdvanceToImperialAgeRule.new()
	if rule.conditions(gs):
		return Assertions.AssertResult.new(false,
			"AdvanceToImperialAgeRule should not fire without enough resources")
	return Assertions.AssertResult.new(true)


# =============================================================================
# AI: should_save_for_age() Imperial Case
# =============================================================================

func test_should_save_for_age_imperial_needs_20_vills() -> Assertions.AssertResult:
	## should_save_for_age for Imperial requires 20 villagers minimum
	var gs = _create_ai_game_state()

	GameManager.set_age(GameManager.AGE_CASTLE, 1)
	GameManager.ai_resources["food"] = 100  # Can't afford Imperial
	GameManager.ai_resources["gold"] = 100
	GameManager.ai_population = 0
	GameManager.ai_population_cap = 50

	# Only 19 villagers - should not save
	for i in range(19):
		var villager = runner.spawner.spawn_villager(Vector2(1600 + (i % 5) * 30, 1600 + (i / 5) * 30), 1)
		villager.current_state = Villager.State.IDLE

	runner.spawner.spawn_monastery(Vector2(1500, 1500), 1)
	runner.spawner.spawn_university(Vector2(1400, 1500), 1)
	runner.spawner.spawn_town_center(Vector2(1700, 1700), 1)
	await runner.wait_frames(2)

	if gs.should_save_for_age():
		return Assertions.AssertResult.new(false,
			"should_save_for_age should be false with only 19 villagers")

	# Add 20th villager
	var extra_vill = runner.spawner.spawn_villager(Vector2(1650, 1600), 1)
	extra_vill.current_state = Villager.State.IDLE
	await runner.wait_frames(2)

	if not gs.should_save_for_age():
		return Assertions.AssertResult.new(false,
			"should_save_for_age should be true with 20 villagers and not enough resources")
	return Assertions.AssertResult.new(true)


func test_should_save_for_age_false_when_already_imperial() -> Assertions.AssertResult:
	## should_save_for_age returns false if already at Imperial Age
	var gs = _create_ai_game_state()

	GameManager.set_age(GameManager.AGE_IMPERIAL, 1)

	if gs.should_save_for_age():
		return Assertions.AssertResult.new(false,
			"should_save_for_age should be false when already at Imperial Age")
	return Assertions.AssertResult.new(true)


func test_should_save_for_age_false_when_can_afford() -> Assertions.AssertResult:
	## should_save_for_age returns false if already able to afford (no need to save)
	var gs = _create_ai_game_state()

	GameManager.set_age(GameManager.AGE_CASTLE, 1)
	GameManager.ai_resources["food"] = 2000  # Can afford
	GameManager.ai_resources["gold"] = 2000
	GameManager.ai_population = 0
	GameManager.ai_population_cap = 50

	for i in range(20):
		var villager = runner.spawner.spawn_villager(Vector2(1600 + (i % 5) * 30, 1600 + (i / 5) * 30), 1)
		villager.current_state = Villager.State.IDLE

	runner.spawner.spawn_monastery(Vector2(1500, 1500), 1)
	runner.spawner.spawn_university(Vector2(1400, 1500), 1)
	runner.spawner.spawn_town_center(Vector2(1700, 1700), 1)
	await runner.wait_frames(2)

	if gs.should_save_for_age():
		return Assertions.AssertResult.new(false,
			"should_save_for_age should be false when AI can already afford Imperial")
	return Assertions.AssertResult.new(true)
