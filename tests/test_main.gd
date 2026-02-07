extends "res://scripts/main.gd"
## Test Main - Extends main game scene with test execution
##
## This scene works like the main game but:
## - Starts with no units/buildings
## - Runs tests automatically on _ready
## - No AI controller
##
## To run: Open tests/test_scene.tscn in Godot, then:
##   - Cmd+R (Mac) or F6 (Windows/Linux), OR
##   - Click the clapperboard icon (top-right toolbar)

# Preload test scenarios to ensure classes are available
const TestSelectionScript = preload("res://tests/scenarios/test_selection.gd")
const TestEconomyScript = preload("res://tests/scenarios/test_economy.gd")
const TestCombatScript = preload("res://tests/scenarios/test_combat.gd")
const TestUnitsScript = preload("res://tests/scenarios/test_units.gd")
const TestBuildingsScript = preload("res://tests/scenarios/test_buildings.gd")
const TestVictoryScript = preload("res://tests/scenarios/test_victory.gd")
const TestResourcesScript = preload("res://tests/scenarios/test_resources.gd")
const TestAnimalsScript = preload("res://tests/scenarios/test_animals.gd")
const TestDirectionsScript = preload("res://tests/scenarios/test_directions.gd")
const TestArmorScript = preload("res://tests/scenarios/test_armor.gd")
const TestFogOfWarScript = preload("res://tests/scenarios/test_fog_of_war.gd")
const TestConstructionScript = preload("res://tests/scenarios/test_construction.gd")
const TestCursorScript = preload("res://tests/scenarios/test_cursor.gd")
const TestAIEconomyScript = preload("res://tests/scenarios/test_ai_economy.gd")
const TestAIMilitaryScript = preload("res://tests/scenarios/test_ai_military.gd")
const TestBugfixesScript = preload("res://tests/scenarios/test_bugfixes.gd")
const TestRepairScript = preload("res://tests/scenarios/test_repair.gd")
const TestAgeAdvancementScript = preload("res://tests/scenarios/test_age_advancement.gd")
const TestAgeGatingScript = preload("res://tests/scenarios/test_age_gating.gd")
const TestTechResearchScript = preload("res://tests/scenarios/test_tech_research.gd")
const TestUnitUpgradesScript = preload("res://tests/scenarios/test_unit_upgrades.gd")
const TestMonasteryScript = preload("res://tests/scenarios/test_monastery.gd")
const TestPhase8AScript = preload("res://tests/scenarios/test_phase_8a.gd")

var test_runner: TestRunner
var camera_node: Camera2D
var resources_container: Node2D
var all_suites_complete: bool = false


func _ready() -> void:
	super._ready()

	# Get camera and resources references
	camera_node = $Camera2D
	resources_container = $Resources

	# Reset GameManager state for clean tests
	GameManager.reset()

	# Setup test runner
	test_runner = TestRunner.new()
	add_child(test_runner)
	test_runner.setup(units_container, buildings_container, camera_node, resources_container)

	# Run tests after a brief delay to let scene initialize
	await get_tree().create_timer(0.5).timeout
	await _run_all_test_suites()


func _run_all_test_suites() -> void:
	## Run all test suites in sequence, then report final results
	var total_passed = 0
	var total_failed = 0

	# Selection tests
	print("\n=== RUNNING SELECTION TESTS ===\n")
	var selection_tests = TestSelectionScript.new(test_runner)
	await test_runner.run_all_tests(selection_tests.get_all_tests())
	total_passed += test_runner.passed_count
	total_failed += test_runner.failed_count

	# Economy tests
	print("\n=== RUNNING ECONOMY TESTS ===\n")
	var economy_tests = TestEconomyScript.new(test_runner)
	await test_runner.run_all_tests(economy_tests.get_all_tests())

	# Combat tests
	print("\n=== RUNNING COMBAT TESTS ===\n")
	var combat_tests = TestCombatScript.new(test_runner)
	await test_runner.run_all_tests(combat_tests.get_all_tests())

	# Unit tests
	print("\n=== RUNNING UNIT TESTS ===\n")
	var unit_tests = TestUnitsScript.new(test_runner)
	await test_runner.run_all_tests(unit_tests.get_all_tests())

	# Building tests
	print("\n=== RUNNING BUILDING TESTS ===\n")
	var building_tests = TestBuildingsScript.new(test_runner)
	await test_runner.run_all_tests(building_tests.get_all_tests())

	# Victory tests
	print("\n=== RUNNING VICTORY TESTS ===\n")
	var victory_tests = TestVictoryScript.new(test_runner)
	await test_runner.run_all_tests(victory_tests.get_all_tests())

	# Resource tests
	print("\n=== RUNNING RESOURCE TESTS ===\n")
	var resource_tests = TestResourcesScript.new(test_runner)
	await test_runner.run_all_tests(resource_tests.get_all_tests())

	# Animal tests (Phase 1B)
	print("\n=== RUNNING ANIMAL TESTS ===\n")
	var animal_tests = TestAnimalsScript.new(test_runner)
	await test_runner.run_all_tests(animal_tests.get_all_tests())

	# Direction tests (Phase 1D)
	print("\n=== RUNNING DIRECTION TESTS ===\n")
	var direction_tests = TestDirectionsScript.new(test_runner)
	await test_runner.run_all_tests(direction_tests.get_all_tests())

	# Armor tests (Phase 2B)
	print("\n=== RUNNING ARMOR TESTS ===\n")
	var armor_tests = TestArmorScript.new(test_runner)
	await test_runner.run_all_tests(armor_tests.get_all_tests())

	# Fog of War tests (Phase 2E)
	print("\n=== RUNNING FOG OF WAR TESTS ===\n")
	var fog_of_war_tests = TestFogOfWarScript.new(test_runner)
	await test_runner.run_all_tests(fog_of_war_tests.get_all_tests())

	# Construction tests (Phase 2.5B)
	print("\n=== RUNNING CONSTRUCTION TESTS ===\n")
	var construction_tests = TestConstructionScript.new(test_runner)
	await test_runner.run_all_tests(construction_tests.get_all_tests())

	# Cursor tests (Phase 2.6B)
	print("\n=== RUNNING CURSOR TESTS ===\n")
	var cursor_tests = TestCursorScript.new(test_runner)
	await test_runner.run_all_tests(cursor_tests.get_all_tests())

	# AI Economy tests (Phase 3.1B)
	print("\n=== RUNNING AI ECONOMY TESTS ===\n")
	var ai_economy_tests = TestAIEconomyScript.new(test_runner)
	await test_runner.run_all_tests(ai_economy_tests.get_all_tests())

	# AI Military tests (Phase 3.1C)
	print("\n=== RUNNING AI MILITARY TESTS ===\n")
	var ai_military_tests = TestAIMilitaryScript.new(test_runner)
	await test_runner.run_all_tests(ai_military_tests.get_all_tests())

	# Repair tests
	print("\n=== RUNNING REPAIR TESTS ===\n")
	var repair_tests = TestRepairScript.new(test_runner)
	await test_runner.run_all_tests(repair_tests.get_all_tests())

	# Age Advancement tests (Phase 4A)
	print("\n=== RUNNING AGE ADVANCEMENT TESTS ===\n")
	var age_advancement_tests = TestAgeAdvancementScript.new(test_runner)
	await test_runner.run_all_tests(age_advancement_tests.get_all_tests())

	# Age Gating tests (Phase 4B)
	print("\n=== RUNNING AGE GATING TESTS ===\n")
	var age_gating_tests = TestAgeGatingScript.new(test_runner)
	await test_runner.run_all_tests(age_gating_tests.get_all_tests())

	# Tech Research tests (Phase 5A)
	print("\n=== RUNNING TECH RESEARCH TESTS ===\n")
	var tech_research_tests = TestTechResearchScript.new(test_runner)
	await test_runner.run_all_tests(tech_research_tests.get_all_tests())

	# Unit Upgrade tests (Phase 5B)
	print("\n=== RUNNING UNIT UPGRADE TESTS ===\n")
	var unit_upgrade_tests = TestUnitUpgradesScript.new(test_runner)
	await test_runner.run_all_tests(unit_upgrade_tests.get_all_tests())

	# Monastery + Monk tests (Phase 6A)
	print("\n=== RUNNING MONASTERY TESTS ===\n")
	var monastery_tests = TestMonasteryScript.new(test_runner)
	await test_runner.run_all_tests(monastery_tests.get_all_tests())

	# Phase 8A tests (University, Building Upgrades, University Techs)
	print("\n=== RUNNING PHASE 8A TESTS ===\n")
	var phase_8a_tests = TestPhase8AScript.new(test_runner)
	await test_runner.run_all_tests(phase_8a_tests.get_all_tests())

	# Bugfix regression tests
	print("\n=== RUNNING BUGFIX TESTS ===\n")
	var bugfix_tests = TestBugfixesScript.new(test_runner)
	await test_runner.run_all_tests(bugfix_tests.get_all_tests())

	# Final summary (test_runner accumulates across all suites)
	_print_final_summary(test_runner.passed_count, test_runner.failed_count)


func _print_final_summary(passed: int, failed: int) -> void:
	print("\n========================================")
	print("FINAL RESULTS: %d passed, %d failed" % [passed, failed])
	print("========================================")

	if failed == 0:
		print("All tests passed!")
	else:
		print("Some tests failed - see above for details")

	# Auto-quit in headless mode (for CLI/CI)
	if DisplayServer.get_name() == "headless" or "--quit-after-tests" in OS.get_cmdline_args():
		await get_tree().create_timer(0.5).timeout
		get_tree().quit(0 if failed == 0 else 1)
