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
