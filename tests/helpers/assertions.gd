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
		if not is_instance_valid(unit):
			return AssertResult.new(false, "Unit was freed unexpectedly")
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
	if not is_instance_valid(unit):
		return AssertResult.new(false, "Unit was freed unexpectedly")

	if unit not in GameManager.selected_units:
		return AssertResult.new(false,
			"Unit not in selection: %s" % str(unit))

	if not unit.is_selected:
		return AssertResult.new(false,
			"Unit thinks it's not selected: %s" % str(unit))

	return AssertResult.new(true)


static func assert_unit_not_selected(unit: Node) -> AssertResult:
	## Check that a specific unit is NOT selected
	if not is_instance_valid(unit):
		return AssertResult.new(false, "Unit was freed unexpectedly")

	if unit in GameManager.selected_units:
		return AssertResult.new(false,
			"Unit should not be in selection: %s" % str(unit))

	if unit.is_selected:
		return AssertResult.new(false,
			"Unit thinks it's selected but shouldn't be: %s" % str(unit))

	return AssertResult.new(true)


static func assert_unit_at_position(unit: Node2D, expected_pos: Vector2, tolerance: float = 10.0) -> AssertResult:
	## Check that unit is near expected position
	if not is_instance_valid(unit):
		return AssertResult.new(false, "Unit was freed unexpectedly")

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


# Economy assertions

static func assert_resource(type: String, expected: int, team: int = 0) -> AssertResult:
	## Check that a resource amount matches exactly
	var actual = GameManager.get_resource(type, team)
	if actual != expected:
		return AssertResult.new(false,
			"Resource %s: expected %d, got %d (team %d)" % [type, expected, actual, team])
	return AssertResult.new(true)


static func assert_resource_at_least(type: String, minimum: int, team: int = 0) -> AssertResult:
	## Check that a resource amount is at least the minimum
	var actual = GameManager.get_resource(type, team)
	if actual < minimum:
		return AssertResult.new(false,
			"Resource %s: expected at least %d, got %d (team %d)" % [type, minimum, actual, team])
	return AssertResult.new(true)


static func assert_villager_state(villager: Node, expected_state: int) -> AssertResult:
	## Check villager's current state enum
	if not is_instance_valid(villager):
		return AssertResult.new(false, "Villager was freed unexpectedly")

	if not villager is Villager:
		return AssertResult.new(false, "Node is not a Villager")

	var actual = villager.current_state
	if actual != expected_state:
		# Use enum keys directly to stay in sync with Villager.State
		var state_keys = Villager.State.keys()
		var expected_name = state_keys[expected_state] if expected_state < state_keys.size() else str(expected_state)
		var actual_name = state_keys[actual] if actual < state_keys.size() else str(actual)
		return AssertResult.new(false,
			"Villager state: expected %s, got %s" % [expected_name, actual_name])
	return AssertResult.new(true)


static func assert_villager_carrying(villager: Node, type: String, min_amount: int) -> AssertResult:
	## Check that villager is carrying at least min_amount of the specified resource type
	if not is_instance_valid(villager):
		return AssertResult.new(false, "Villager was freed unexpectedly")

	if not villager is Villager:
		return AssertResult.new(false, "Node is not a Villager")

	if villager.carried_resource_type != type:
		return AssertResult.new(false,
			"Villager carrying %s, expected %s" % [villager.carried_resource_type, type])

	if villager.carried_amount < min_amount:
		return AssertResult.new(false,
			"Villager carrying %d %s, expected at least %d" % [villager.carried_amount, type, min_amount])
	return AssertResult.new(true)


# Combat assertions

static func assert_militia_state(militia: Node, expected_state: int) -> AssertResult:
	## Check militia's current state enum
	if not is_instance_valid(militia):
		return AssertResult.new(false, "Militia was freed unexpectedly")

	if not militia is Militia:
		return AssertResult.new(false, "Node is not a Militia")

	var actual = militia.current_state
	if actual != expected_state:
		var state_keys = Militia.State.keys()
		var expected_name = state_keys[expected_state] if expected_state < state_keys.size() else str(expected_state)
		var actual_name = state_keys[actual] if actual < state_keys.size() else str(actual)
		return AssertResult.new(false,
			"Militia state: expected %s, got %s" % [expected_name, actual_name])
	return AssertResult.new(true)


static func assert_archer_state(archer: Node, expected_state: int) -> AssertResult:
	## Check archer's current state enum
	if not is_instance_valid(archer):
		return AssertResult.new(false, "Archer was freed unexpectedly")

	if not archer is Archer:
		return AssertResult.new(false, "Node is not an Archer")

	var actual = archer.current_state
	if actual != expected_state:
		var state_keys = Archer.State.keys()
		var expected_name = state_keys[expected_state] if expected_state < state_keys.size() else str(expected_state)
		var actual_name = state_keys[actual] if actual < state_keys.size() else str(actual)
		return AssertResult.new(false,
			"Archer state: expected %s, got %s" % [expected_name, actual_name])
	return AssertResult.new(true)


static func assert_scout_cavalry_state(scout: Node, expected_state: int) -> AssertResult:
	## Check scout cavalry's current state enum
	if not is_instance_valid(scout):
		return AssertResult.new(false, "Scout Cavalry was freed unexpectedly")

	if not scout is ScoutCavalry:
		return AssertResult.new(false, "Node is not a ScoutCavalry")

	var actual = scout.current_state
	if actual != expected_state:
		var state_keys = ScoutCavalry.State.keys()
		var expected_name = state_keys[expected_state] if expected_state < state_keys.size() else str(expected_state)
		var actual_name = state_keys[actual] if actual < state_keys.size() else str(actual)
		return AssertResult.new(false,
			"Scout Cavalry state: expected %s, got %s" % [expected_name, actual_name])
	return AssertResult.new(true)


static func assert_spearman_state(spearman: Node, expected_state: int) -> AssertResult:
	## Check spearman's current state enum
	if not is_instance_valid(spearman):
		return AssertResult.new(false, "Spearman was freed unexpectedly")

	if not spearman is Spearman:
		return AssertResult.new(false, "Node is not a Spearman")

	var actual = spearman.current_state
	if actual != expected_state:
		var state_keys = Spearman.State.keys()
		var expected_name = state_keys[expected_state] if expected_state < state_keys.size() else str(expected_state)
		var actual_name = state_keys[actual] if actual < state_keys.size() else str(actual)
		return AssertResult.new(false,
			"Spearman state: expected %s, got %s" % [expected_name, actual_name])
	return AssertResult.new(true)


static func assert_unit_hp(unit: Node, expected_hp: int) -> AssertResult:
	## Check unit's current HP
	if not is_instance_valid(unit):
		return AssertResult.new(false, "Unit was freed unexpectedly")

	if not unit is Unit:
		return AssertResult.new(false, "Node is not a Unit")

	if unit.current_hp != expected_hp:
		return AssertResult.new(false,
			"Unit HP: expected %d, got %d" % [expected_hp, unit.current_hp])
	return AssertResult.new(true)


static func assert_building_hp(building: Node, expected_hp: int) -> AssertResult:
	## Check building's current HP
	if not is_instance_valid(building):
		return AssertResult.new(false, "Building was freed unexpectedly")

	if not building is Building:
		return AssertResult.new(false, "Node is not a Building")

	if building.current_hp != expected_hp:
		return AssertResult.new(false,
			"Building HP: expected %d, got %d" % [expected_hp, building.current_hp])
	return AssertResult.new(true)


static func assert_population(expected_pop: int, team: int = 0) -> AssertResult:
	## Check population count for a team
	var actual = GameManager.get_population(team)
	if actual != expected_pop:
		return AssertResult.new(false,
			"Population: expected %d, got %d (team %d)" % [expected_pop, actual, team])
	return AssertResult.new(true)


static func assert_population_cap(expected_cap: int, team: int = 0) -> AssertResult:
	## Check population cap for a team
	var actual = GameManager.get_population_cap(team)
	if actual != expected_cap:
		return AssertResult.new(false,
			"Population cap: expected %d, got %d (team %d)" % [expected_cap, actual, team])
	return AssertResult.new(true)


# Animal assertions

static func assert_animal_state(animal: Node, expected_state: int) -> AssertResult:
	## Check animal's current state enum
	if not is_instance_valid(animal):
		return AssertResult.new(false, "Animal was freed unexpectedly")

	if not animal is Animal:
		return AssertResult.new(false, "Node is not an Animal")

	var actual = animal.current_state
	if actual != expected_state:
		var state_keys = Animal.State.keys()
		var expected_name = state_keys[expected_state] if expected_state < state_keys.size() else str(expected_state)
		var actual_name = state_keys[actual] if actual < state_keys.size() else str(actual)
		return AssertResult.new(false,
			"Animal state: expected %s, got %s" % [expected_name, actual_name])
	return AssertResult.new(true)


static func assert_animal_team(animal: Node, expected_team: int) -> AssertResult:
	## Check animal's team ownership (-1 = neutral)
	if not is_instance_valid(animal):
		return AssertResult.new(false, "Animal was freed unexpectedly")

	if not animal is Animal:
		return AssertResult.new(false, "Node is not an Animal")

	if animal.team != expected_team:
		return AssertResult.new(false,
			"Animal team: expected %d, got %d" % [expected_team, animal.team])
	return AssertResult.new(true)
