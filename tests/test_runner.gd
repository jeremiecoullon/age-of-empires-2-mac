extends Node
## Test Runner - Executes test scenarios and reports results
##
## Attach this to a test scene root node.
## To run: Open tests/test_scene.tscn, then Cmd+R (Mac) or F6 (Windows/Linux)
## (or click the clapperboard icon in the top-right toolbar)
##
## Results are printed to console:
##   PASS: test_click_selects_villager
##   FAIL: test_click_empty_deselects - Expected nothing selected, but 1 units are selected

class_name TestRunner

signal all_tests_completed(passed: int, failed: int, results: Array)

# Test tracking
var test_results: Array = []  # Array of {name: String, passed: bool, message: String}
var passed_count: int = 0
var failed_count: int = 0

# Helpers
var spawner: TestSpawner
var input_sim: InputSimulator

# Scene references (set via setup())
var units_container: Node2D
var buildings_container: Node2D
var resources_container: Node2D
var camera: Camera2D


func setup(units: Node2D, buildings: Node2D, cam: Camera2D, resources: Node2D = null) -> void:
	units_container = units
	buildings_container = buildings
	resources_container = resources
	camera = cam

	# Create helpers
	spawner = TestSpawner.new()
	add_child(spawner)
	spawner.setup(units, buildings, resources)

	input_sim = InputSimulator.new()
	add_child(input_sim)
	input_sim.setup(cam)


func run_all_tests(test_methods: Array[Callable]) -> void:
	## Run an array of test methods
	print("\n========================================")
	print("STARTING TEST RUN: %d tests" % test_methods.size())
	print("========================================\n")

	for test_method in test_methods:
		await run_single_test(test_method)

	_print_summary()
	all_tests_completed.emit(passed_count, failed_count, test_results)


func run_single_test(test_method: Callable) -> void:
	## Run a single test method with setup/teardown
	var test_name = test_method.get_method()

	# Setup: clear state
	_before_each()

	# Wait a frame for cleanup to process
	await get_tree().process_frame
	await get_tree().process_frame

	# Run test
	var result = await test_method.call()

	# Record result
	if result is Assertions.AssertResult:
		_record_result(test_name, result.passed, result.message)
	elif result == null:
		# Test didn't return a result, assume pass if no exception
		_record_result(test_name, true, "")
	else:
		_record_result(test_name, false, "Test returned unexpected value: %s" % str(result))

	# Teardown
	_after_each()
	await get_tree().process_frame


func _before_each() -> void:
	## Reset state before each test
	spawner.clear_all()  # This already calls GameManager.clear_selection()
	GameManager.reset()  # Reset resources, population, market prices


func _after_each() -> void:
	## Cleanup after each test
	spawner.clear_all()


func _record_result(test_name: String, passed: bool, message: String) -> void:
	test_results.append({
		"name": test_name,
		"passed": passed,
		"message": message
	})

	if passed:
		passed_count += 1
		print("PASS: %s" % test_name)
	else:
		failed_count += 1
		print("FAIL: %s - %s" % [test_name, message])


func _print_summary() -> void:
	print("\n========================================")
	print("TEST RESULTS: %d passed, %d failed" % [passed_count, failed_count])
	print("========================================")

	if failed_count > 0:
		print("\nFailed tests:")
		for result in test_results:
			if not result.passed:
				print("  - %s: %s" % [result.name, result.message])

	print("")


# Utility: wait for N frames
func wait_frames(n: int) -> void:
	for i in range(n):
		await get_tree().process_frame


# Utility: wait for N seconds
func wait_seconds(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout
