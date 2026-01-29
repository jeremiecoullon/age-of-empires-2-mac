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

var test_runner: TestRunner
var camera_node: Camera2D


func _ready() -> void:
	super._ready()

	# Get camera reference
	camera_node = $Camera2D

	# Reset GameManager state for clean tests
	GameManager.reset()

	# Setup test runner
	test_runner = TestRunner.new()
	add_child(test_runner)
	test_runner.setup(units_container, buildings_container, camera_node)

	# Connect completion signal
	test_runner.all_tests_completed.connect(_on_tests_completed)

	# Run tests after a brief delay to let scene initialize
	await get_tree().create_timer(0.5).timeout
	_run_selection_tests()


func _run_selection_tests() -> void:
	print("\n=== RUNNING SELECTION TESTS ===\n")

	var selection_tests = TestSelection.new(test_runner)
	await test_runner.run_all_tests(selection_tests.get_all_tests())


func _on_tests_completed(passed: int, failed: int, _results: Array) -> void:
	print("\n=== ALL TESTS COMPLETED ===")
	print("Passed: %d, Failed: %d" % [passed, failed])

	if failed == 0:
		print("All tests passed!")
	else:
		print("Some tests failed - see above for details")

	# Auto-quit in headless mode (for CLI/CI)
	if DisplayServer.get_name() == "headless" or "--quit-after-tests" in OS.get_cmdline_args():
		await get_tree().create_timer(0.5).timeout
		get_tree().quit(0 if failed == 0 else 1)
