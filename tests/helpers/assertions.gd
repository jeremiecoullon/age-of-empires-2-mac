extends RefCounted
## Test Assertions - Check game state for expected conditions
##
## Usage:
##   var result = Assertions.assert_selected([villager])
##   if not result.passed:
##       print("FAIL: " + result.message)

class_name Assertions


class AssertResult:
	var passed: bool
	var message: String

	func _init(p: bool, msg: String = "") -> void:
		passed = p
		message = msg


static func assert_selected(expected_units: Array) -> AssertResult:
	## Check that exactly these units are selected
	var actual = GameManager.selected_units

	if actual.size() != expected_units.size():
		return AssertResult.new(false,
			"Selection count mismatch: expected %d, got %d" % [expected_units.size(), actual.size()])

	for unit in expected_units:
		if unit not in actual:
			return AssertResult.new(false,
				"Expected unit not in selection: %s" % str(unit))

	# Also verify unit-side state matches
	for unit in expected_units:
		if not unit.is_selected:
			return AssertResult.new(false,
				"Unit thinks it's not selected: %s" % str(unit))

	return AssertResult.new(true)


static func assert_nothing_selected() -> AssertResult:
	## Check that no units are selected
	var actual = GameManager.selected_units

	if actual.size() != 0:
		return AssertResult.new(false,
			"Expected nothing selected, but %d units are selected" % actual.size())

	return AssertResult.new(true)


static func assert_selection_count(expected_count: int) -> AssertResult:
	## Check that exactly N units are selected
	var actual = GameManager.selected_units.size()

	if actual != expected_count:
		return AssertResult.new(false,
			"Selection count mismatch: expected %d, got %d" % [expected_count, actual])

	return AssertResult.new(true)


static func assert_unit_selected(unit: Node) -> AssertResult:
	## Check that a specific unit is selected (among possibly others)
	if unit not in GameManager.selected_units:
		return AssertResult.new(false,
			"Unit not in selection: %s" % str(unit))

	if not unit.is_selected:
		return AssertResult.new(false,
			"Unit thinks it's not selected: %s" % str(unit))

	return AssertResult.new(true)


static func assert_unit_not_selected(unit: Node) -> AssertResult:
	## Check that a specific unit is NOT selected
	if unit in GameManager.selected_units:
		return AssertResult.new(false,
			"Unit should not be in selection: %s" % str(unit))

	if unit.is_selected:
		return AssertResult.new(false,
			"Unit thinks it's selected but shouldn't be: %s" % str(unit))

	return AssertResult.new(true)


static func assert_unit_at_position(unit: Node2D, expected_pos: Vector2, tolerance: float = 10.0) -> AssertResult:
	## Check that unit is near expected position
	var distance = unit.global_position.distance_to(expected_pos)

	if distance > tolerance:
		return AssertResult.new(false,
			"Unit at %s, expected near %s (distance: %.1f, tolerance: %.1f)" % [
				str(unit.global_position), str(expected_pos), distance, tolerance])

	return AssertResult.new(true)


static func assert_true(condition: bool, message: String = "Condition was false") -> AssertResult:
	## Generic true assertion
	if not condition:
		return AssertResult.new(false, message)
	return AssertResult.new(true)


static func assert_equal(actual, expected, message: String = "") -> AssertResult:
	## Generic equality assertion
	if actual != expected:
		var msg = message if message else "Expected %s, got %s" % [str(expected), str(actual)]
		return AssertResult.new(false, msg)
	return AssertResult.new(true)
