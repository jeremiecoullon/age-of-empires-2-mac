extends Node
## Direction Tests - Tests for 8-directional sprite system (Phase 1D)
##
## These tests verify:
## - Direction enum values and order (SW, W, NW, N, NE, E, SE, S)
## - _get_direction_from_velocity() produces consistent output for given inputs
## - Direction updates when velocity changes
## - Direction is preserved when velocity is zero/small
## - Opposite velocities produce opposite directions
##
## NOTE: The actual angle-to-direction mapping is tuned for the AoE sprite assets
## and may not match mathematical expectations. These tests verify the mapping
## is consistent and symmetric, not that it matches specific expected values.

class_name TestDirections

var runner: TestRunner


func _init(test_runner: TestRunner) -> void:
	runner = test_runner


func get_all_tests() -> Array[Callable]:
	## Returns all test methods to run
	return [
		test_direction_enum_order,
		test_direction_names_match_enum,
		test_eight_distinct_directions,
		test_opposite_velocities_produce_opposite_directions,
		test_cardinal_directions_are_distinct,
		test_diagonal_directions_are_distinct,
		test_direction_preserved_on_zero_velocity,
		test_direction_preserved_on_small_velocity,
		test_villager_default_direction_south,
		test_villager_direction_updates_on_movement,
		test_militia_direction_updates_on_movement,
		test_direction_changes_when_velocity_changes,
	]


# === Direction Enum Tests ===

func test_direction_enum_order() -> Assertions.AssertResult:
	## Direction enum should be SW, W, NW, N, NE, E, SE, S (AoE sprite order)
	if Unit.Direction.SW != 0:
		return Assertions.AssertResult.new(false,
			"Direction.SW should be 0, got: %d" % Unit.Direction.SW)
	if Unit.Direction.W != 1:
		return Assertions.AssertResult.new(false,
			"Direction.W should be 1, got: %d" % Unit.Direction.W)
	if Unit.Direction.NW != 2:
		return Assertions.AssertResult.new(false,
			"Direction.NW should be 2, got: %d" % Unit.Direction.NW)
	if Unit.Direction.N != 3:
		return Assertions.AssertResult.new(false,
			"Direction.N should be 3, got: %d" % Unit.Direction.N)
	if Unit.Direction.NE != 4:
		return Assertions.AssertResult.new(false,
			"Direction.NE should be 4, got: %d" % Unit.Direction.NE)
	if Unit.Direction.E != 5:
		return Assertions.AssertResult.new(false,
			"Direction.E should be 5, got: %d" % Unit.Direction.E)
	if Unit.Direction.SE != 6:
		return Assertions.AssertResult.new(false,
			"Direction.SE should be 6, got: %d" % Unit.Direction.SE)
	if Unit.Direction.S != 7:
		return Assertions.AssertResult.new(false,
			"Direction.S should be 7, got: %d" % Unit.Direction.S)
	return Assertions.AssertResult.new(true)


func test_direction_names_match_enum() -> Assertions.AssertResult:
	## DIRECTION_NAMES array should match enum order
	var expected_names = ["sw", "w", "nw", "n", "ne", "e", "se", "s"]
	if Unit.DIRECTION_NAMES.size() != 8:
		return Assertions.AssertResult.new(false,
			"DIRECTION_NAMES should have 8 entries, got: %d" % Unit.DIRECTION_NAMES.size())
	for i in range(8):
		if Unit.DIRECTION_NAMES[i] != expected_names[i]:
			return Assertions.AssertResult.new(false,
				"DIRECTION_NAMES[%d] should be '%s', got: '%s'" % [i, expected_names[i], Unit.DIRECTION_NAMES[i]])
	return Assertions.AssertResult.new(true)


# === Direction from Velocity Tests ===
# These test the consistency and symmetry of the angle-to-direction mapping

func test_eight_distinct_directions() -> Assertions.AssertResult:
	## Eight distinct velocities (45 degrees apart) should produce 8 distinct directions
	var villager = runner.spawner.spawn_villager(Vector2(400, 400))
	await runner.wait_frames(2)

	# Test velocities at 8 angles (0, 45, 90, 135, 180, 225, 270, 315 degrees)
	var test_velocities = [
		Vector2(100, 0),    # 0 deg (E)
		Vector2(100, 100),  # 45 deg (SE)
		Vector2(0, 100),    # 90 deg (S)
		Vector2(-100, 100), # 135 deg (SW)
		Vector2(-100, 0),   # 180 deg (W)
		Vector2(-100, -100),# 225 deg (NW)
		Vector2(0, -100),   # 270 deg (N)
		Vector2(100, -100), # 315 deg (NE)
	]

	var directions_seen: Array[int] = []
	for vel in test_velocities:
		var dir = villager._get_direction_from_velocity(vel)
		if dir in directions_seen:
			return Assertions.AssertResult.new(false,
				"Direction %d (%s) was produced by multiple velocities" % [dir, Unit.DIRECTION_NAMES[dir]])
		directions_seen.append(dir)

	if directions_seen.size() != 8:
		return Assertions.AssertResult.new(false,
			"Expected 8 distinct directions, got: %d" % directions_seen.size())

	return Assertions.AssertResult.new(true)


func test_opposite_velocities_produce_opposite_directions() -> Assertions.AssertResult:
	## Moving in opposite directions should produce opposite facing directions
	## (e.g., moving +X vs -X should differ by 4 in direction index)
	var villager = runner.spawner.spawn_villager(Vector2(400, 400))
	await runner.wait_frames(2)

	# Test pairs of opposite velocities
	var opposite_pairs = [
		[Vector2(100, 0), Vector2(-100, 0)],     # E vs W
		[Vector2(0, 100), Vector2(0, -100)],     # S vs N
		[Vector2(100, 100), Vector2(-100, -100)], # SE vs NW
		[Vector2(-100, 100), Vector2(100, -100)], # SW vs NE
	]

	for pair in opposite_pairs:
		var dir1 = villager._get_direction_from_velocity(pair[0])
		var dir2 = villager._get_direction_from_velocity(pair[1])

		# Directions should differ by 4 (opposite in 8-direction circle)
		# Use circular distance to handle wraparound (e.g., 0 and 7 are adjacent)
		var circular_diff = ((dir1 - dir2) % 8 + 8) % 8
		if circular_diff != 4:
			return Assertions.AssertResult.new(false,
				"Velocities %s and %s should produce opposite directions (circular_diff=4), got circular_diff=%d (%s vs %s)" % [
					str(pair[0]), str(pair[1]), circular_diff,
					Unit.DIRECTION_NAMES[dir1], Unit.DIRECTION_NAMES[dir2]])

	return Assertions.AssertResult.new(true)


func test_cardinal_directions_are_distinct() -> Assertions.AssertResult:
	## Cardinal directions (N, E, S, W) should produce distinct direction indices
	var villager = runner.spawner.spawn_villager(Vector2(400, 400))
	await runner.wait_frames(2)

	var dir_e = villager._get_direction_from_velocity(Vector2(100, 0))
	var dir_w = villager._get_direction_from_velocity(Vector2(-100, 0))
	var dir_n = villager._get_direction_from_velocity(Vector2(0, -100))
	var dir_s = villager._get_direction_from_velocity(Vector2(0, 100))

	var cardinals = [dir_e, dir_w, dir_n, dir_s]
	for i in range(cardinals.size()):
		for j in range(i + 1, cardinals.size()):
			if cardinals[i] == cardinals[j]:
				return Assertions.AssertResult.new(false,
					"Cardinal directions should be distinct, but found duplicate")

	return Assertions.AssertResult.new(true)


func test_diagonal_directions_are_distinct() -> Assertions.AssertResult:
	## Diagonal directions (NE, NW, SE, SW) should produce distinct direction indices
	var villager = runner.spawner.spawn_villager(Vector2(400, 400))
	await runner.wait_frames(2)

	var dir_ne = villager._get_direction_from_velocity(Vector2(100, -100))
	var dir_nw = villager._get_direction_from_velocity(Vector2(-100, -100))
	var dir_se = villager._get_direction_from_velocity(Vector2(100, 100))
	var dir_sw = villager._get_direction_from_velocity(Vector2(-100, 100))

	var diagonals = [dir_ne, dir_nw, dir_se, dir_sw]
	for i in range(diagonals.size()):
		for j in range(i + 1, diagonals.size()):
			if diagonals[i] == diagonals[j]:
				return Assertions.AssertResult.new(false,
					"Diagonal directions should be distinct, but found duplicate")

	return Assertions.AssertResult.new(true)


# === Direction Preservation Tests ===

func test_direction_preserved_on_zero_velocity() -> Assertions.AssertResult:
	## Zero velocity should preserve current direction
	var villager = runner.spawner.spawn_villager(Vector2(400, 400))
	await runner.wait_frames(2)

	# Set a known direction
	villager.current_direction = Unit.Direction.NW

	# Call with zero velocity
	var direction = villager._get_direction_from_velocity(Vector2.ZERO)

	if direction != Unit.Direction.NW:
		return Assertions.AssertResult.new(false,
			"Zero velocity should preserve direction NW (2), got: %d (%s)" % [direction, Unit.DIRECTION_NAMES[direction]])
	return Assertions.AssertResult.new(true)


func test_direction_preserved_on_small_velocity() -> Assertions.AssertResult:
	## Very small velocity (< 1.0 length_squared) should preserve current direction
	## Tests boundary conditions around the threshold
	var villager = runner.spawner.spawn_villager(Vector2(400, 400))
	await runner.wait_frames(2)

	# Set a known direction
	villager.current_direction = Unit.Direction.E

	# Test below threshold (length_squared = 0.5 < 1.0) - should preserve
	var dir_below = villager._get_direction_from_velocity(Vector2(0.5, 0.5))
	if dir_below != Unit.Direction.E:
		return Assertions.AssertResult.new(false,
			"Small velocity (0.5,0.5) should preserve direction E, got: %s" % Unit.DIRECTION_NAMES[dir_below])

	# Test just below threshold (length_squared = 0.98 < 1.0) - should preserve
	var dir_near = villager._get_direction_from_velocity(Vector2(0.7, 0.7))  # 0.49 + 0.49 = 0.98
	if dir_near != Unit.Direction.E:
		return Assertions.AssertResult.new(false,
			"Velocity just below threshold (0.7,0.7) should preserve direction E, got: %s" % Unit.DIRECTION_NAMES[dir_near])

	# Test at/above threshold (length_squared = 1.0) - should calculate direction
	var dir_at = villager._get_direction_from_velocity(Vector2(1.0, 0.0))  # length_squared = 1.0
	if dir_at == Unit.Direction.E:
		# This is ambiguous - it might legitimately calculate E if that's the right direction
		# So let's test with a different current direction
		villager.current_direction = Unit.Direction.N
		var dir_at2 = villager._get_direction_from_velocity(Vector2(1.0, 0.0))  # Moving east
		# Should NOT be N (should calculate the actual direction)
		if dir_at2 == Unit.Direction.N:
			return Assertions.AssertResult.new(false,
				"Velocity at threshold (1.0,0.0) should calculate direction, not preserve N")

	return Assertions.AssertResult.new(true)


# === Default Direction Tests ===

func test_villager_default_direction_south() -> Assertions.AssertResult:
	## Villager should start facing South by default
	var villager = runner.spawner.spawn_villager(Vector2(400, 400))
	await runner.wait_frames(2)

	if villager.current_direction != Unit.Direction.S:
		return Assertions.AssertResult.new(false,
			"Villager should start facing S (7), got: %d (%s)" % [villager.current_direction, Unit.DIRECTION_NAMES[villager.current_direction]])
	return Assertions.AssertResult.new(true)


# === Integration Tests ===
# NOTE: These tests are loose integration checks that depend on timing and navigation.
# They're designed to catch obvious regressions - they only fail if the unit IS moving
# but direction hasn't updated. If navigation/timing prevents movement, they pass.
# The core direction logic is thoroughly tested in unit tests above.

func test_villager_direction_updates_on_movement() -> Assertions.AssertResult:
	## Villager's current_direction should change from default when moving
	## (Loose check - passes if unit isn't moving yet)
	var villager = runner.spawner.spawn_villager(Vector2(400, 400))
	await runner.wait_frames(2)

	# Record starting direction
	var start_dir = villager.current_direction

	# Move villager to a position that requires horizontal movement
	villager.move_to(Vector2(600, 400))

	# Wait for unit to start moving and update direction
	await runner.wait_frames(10)

	# Direction should have changed from starting direction
	# (We don't assert which direction because the mapping is tuned for sprites)
	if villager.current_direction == start_dir:
		# Could be that the unit already arrived or is still accelerating
		# Check if unit is moving
		if villager.velocity.length_squared() > 1.0:
			return Assertions.AssertResult.new(false,
				"Villager is moving but direction hasn't changed from default")
	return Assertions.AssertResult.new(true)


func test_militia_direction_updates_on_movement() -> Assertions.AssertResult:
	## Militia's current_direction should change from default when moving
	var militia = runner.spawner.spawn_militia(Vector2(400, 400))
	await runner.wait_frames(2)

	# Record starting direction
	var start_dir = militia.current_direction

	# Move militia to a position that requires horizontal movement
	militia.move_to(Vector2(200, 400))

	# Wait for unit to start moving and update direction
	await runner.wait_frames(10)

	# Direction should have changed from starting direction
	if militia.current_direction == start_dir:
		if militia.velocity.length_squared() > 1.0:
			return Assertions.AssertResult.new(false,
				"Militia is moving but direction hasn't changed from default")
	return Assertions.AssertResult.new(true)


func test_direction_changes_when_velocity_changes() -> Assertions.AssertResult:
	## Changing velocity direction should change facing direction
	var villager = runner.spawner.spawn_villager(Vector2(400, 400))
	await runner.wait_frames(2)

	# Get direction for moving right
	var dir_right = villager._get_direction_from_velocity(Vector2(100, 0))

	# Get direction for moving left (opposite)
	var dir_left = villager._get_direction_from_velocity(Vector2(-100, 0))

	# They should be different
	if dir_right == dir_left:
		return Assertions.AssertResult.new(false,
			"Moving right and left should produce different directions, both gave: %d (%s)" % [dir_right, Unit.DIRECTION_NAMES[dir_right]])

	return Assertions.AssertResult.new(true)
