extends Node
## Fog of War Tests - Tests for visibility system (Phase 2E)
##
## These tests verify:
## - Three visibility states: UNEXPLORED, EXPLORED, VISIBLE
## - Tile grid initialization (60x60 tiles)
## - Player units reveal visibility based on sight_range
## - Player buildings reveal visibility based on sight_range
## - is_position_visible() and is_explored() helper methods
## - reveal_all() reveals entire map
## - reset() returns map to UNEXPLORED
## - Building sight_range values (default 192.0, TC 256.0)

class_name TestFogOfWar

const FogOfWarScript = preload("res://scripts/fog_of_war.gd")

var runner: TestRunner

const PLAYER_TEAM: int = 0
const AI_TEAM: int = 1
const NEUTRAL_TEAM: int = -1


func _init(test_runner: TestRunner) -> void:
	runner = test_runner


func _create_fog() -> Node:
	## Helper to create a FogOfWar instance and add it to the scene
	var fog = FogOfWarScript.new()
	fog.set_process(false)  # Prevent updates during test
	runner.add_child(fog)
	runner.spawner.spawned_entities.append(fog)
	return fog


func get_all_tests() -> Array[Callable]:
	## Returns all test methods to run
	return [
		# Fog of War grid initialization tests
		test_fog_grid_initializes_to_unexplored,
		test_fog_grid_has_correct_size,
		test_fog_constants_correct,
		# Visibility state tests
		test_is_visible_returns_false_for_unexplored,
		test_is_explored_returns_false_for_unexplored,
		test_reveal_all_makes_all_tiles_visible,
		test_reset_returns_tiles_to_unexplored,
		# Player unit visibility reveal tests
		test_player_unit_reveals_nearby_tiles,
		test_player_villager_reveals_based_on_sight_range,
		# Building sight_range tests
		test_building_default_sight_range,
		test_town_center_has_larger_sight_range,
		test_player_building_reveals_nearby_tiles,
	]


# === Fog of War Grid Initialization Tests ===

func test_fog_grid_initializes_to_unexplored() -> Assertions.AssertResult:
	## New FogOfWar grid should start with all tiles UNEXPLORED
	var fog = FogOfWarScript.new()
	fog.set_process(false)  # Prevent updates during test
	runner.add_child(fog)
	runner.spawner.spawned_entities.append(fog)
	await runner.wait_frames(2)

	# Check that initial tiles are UNEXPLORED
	var is_all_unexplored = true
	for x in range(5):  # Sample a few tiles
		for y in range(5):
			if fog.visibility_grid[x][y] != FogOfWarScript.VisibilityState.UNEXPLORED:
				is_all_unexplored = false
				break

	if not is_all_unexplored:
		return Assertions.AssertResult.new(false,
			"Grid should initialize with all tiles UNEXPLORED")

	return Assertions.AssertResult.new(true)


func test_fog_grid_has_correct_size() -> Assertions.AssertResult:
	## Grid should be 60x60 tiles
	var fog = FogOfWarScript.new()
	fog.set_process(false)
	runner.add_child(fog)
	runner.spawner.spawned_entities.append(fog)
	await runner.wait_frames(2)

	if fog.visibility_grid.size() != 60:
		return Assertions.AssertResult.new(false,
			"Grid X size should be 60, got: %d" % fog.visibility_grid.size())

	if fog.visibility_grid[0].size() != 60:
		return Assertions.AssertResult.new(false,
			"Grid Y size should be 60, got: %d" % fog.visibility_grid[0].size())

	return Assertions.AssertResult.new(true)


func test_fog_constants_correct() -> Assertions.AssertResult:
	## Verify FogOfWar constants match expected values
	if FogOfWarScript.TILE_SIZE != 32:
		return Assertions.AssertResult.new(false,
			"TILE_SIZE should be 32, got: %d" % FogOfWarScript.TILE_SIZE)

	if FogOfWarScript.MAP_SIZE != 1920:
		return Assertions.AssertResult.new(false,
			"MAP_SIZE should be 1920, got: %d" % FogOfWarScript.MAP_SIZE)

	if FogOfWarScript.GRID_SIZE != 60:
		return Assertions.AssertResult.new(false,
			"GRID_SIZE should be 60, got: %d" % FogOfWarScript.GRID_SIZE)

	return Assertions.AssertResult.new(true)


# === Visibility State Tests ===

func test_is_visible_returns_false_for_unexplored() -> Assertions.AssertResult:
	## is_visible should return false for UNEXPLORED tiles
	var fog = FogOfWarScript.new()
	fog.set_process(false)
	runner.add_child(fog)
	runner.spawner.spawned_entities.append(fog)
	await runner.wait_frames(2)

	# Far corner that won't be revealed by anything
	var far_pos = Vector2(1900, 1900)
	var tile_visible = fog.call("is_visible",far_pos)

	if tile_visible:
		return Assertions.AssertResult.new(false,
			"is_visible should return false for UNEXPLORED tile")

	return Assertions.AssertResult.new(true)


func test_is_explored_returns_false_for_unexplored() -> Assertions.AssertResult:
	## is_explored should return false for UNEXPLORED tiles
	var fog = FogOfWarScript.new()
	fog.set_process(false)
	runner.add_child(fog)
	runner.spawner.spawned_entities.append(fog)
	await runner.wait_frames(2)

	# Far corner that won't be revealed by anything
	var far_pos = Vector2(1900, 1900)
	var tile_explored = fog.call("is_explored",far_pos)

	if tile_explored:
		return Assertions.AssertResult.new(false,
			"is_explored should return false for UNEXPLORED tile")

	return Assertions.AssertResult.new(true)


func test_reveal_all_makes_all_tiles_visible() -> Assertions.AssertResult:
	## reveal_all() should set all tiles to VISIBLE
	var fog = FogOfWarScript.new()
	fog.set_process(false)
	runner.add_child(fog)
	runner.spawner.spawned_entities.append(fog)
	await runner.wait_frames(2)

	fog.call("reveal_all")

	# Check that all tiles are now VISIBLE
	var is_all_visible = true
	for x in range(FogOfWarScript.GRID_SIZE):
		for y in range(FogOfWarScript.GRID_SIZE):
			if fog.visibility_grid[x][y] != FogOfWarScript.VisibilityState.VISIBLE:
				is_all_visible = false
				break
		if not is_all_visible:
			break

	if not is_all_visible:
		return Assertions.AssertResult.new(false,
			"reveal_all should make all tiles VISIBLE")

	# Also check helper methods
	var far_pos = Vector2(1900, 1900)
	if not fog.call("is_visible",far_pos):
		return Assertions.AssertResult.new(false,
			"is_visible should return true after reveal_all")

	if not fog.call("is_explored",far_pos):
		return Assertions.AssertResult.new(false,
			"is_explored should return true after reveal_all")

	return Assertions.AssertResult.new(true)


func test_reset_returns_tiles_to_unexplored() -> Assertions.AssertResult:
	## reset() should return all tiles to UNEXPLORED
	var fog = FogOfWarScript.new()
	fog.set_process(false)
	runner.add_child(fog)
	runner.spawner.spawned_entities.append(fog)
	await runner.wait_frames(2)

	# First reveal all
	fog.call("reveal_all")

	# Then reset
	fog.call("reset")

	# Check that all tiles are now UNEXPLORED
	var is_all_unexplored = true
	for x in range(FogOfWarScript.GRID_SIZE):
		for y in range(FogOfWarScript.GRID_SIZE):
			if fog.visibility_grid[x][y] != FogOfWarScript.VisibilityState.UNEXPLORED:
				is_all_unexplored = false
				break
		if not is_all_unexplored:
			break

	if not is_all_unexplored:
		return Assertions.AssertResult.new(false,
			"reset should return all tiles to UNEXPLORED")

	return Assertions.AssertResult.new(true)


# === Player Unit Visibility Reveal Tests ===

func test_player_unit_reveals_nearby_tiles() -> Assertions.AssertResult:
	## Player unit should reveal tiles within its sight_range
	var fog = FogOfWarScript.new()
	fog.set_process(false)
	runner.add_child(fog)
	runner.spawner.spawned_entities.append(fog)
	await runner.wait_frames(2)

	# Spawn a player militia at a known position
	var militia = runner.spawner.spawn_militia(Vector2(500, 500), PLAYER_TEAM)
	await runner.wait_frames(2)

	# Manually call _update_visibility to simulate the fog update
	fog.call("_update_visibility")

	# Check that the unit's position is now visible
	var tile_visible = fog.call("is_visible",militia.global_position)

	if not tile_visible:
		return Assertions.AssertResult.new(false,
			"Tile at player unit position should be VISIBLE")

	return Assertions.AssertResult.new(true)


func test_player_villager_reveals_based_on_sight_range() -> Assertions.AssertResult:
	## Player villager should reveal tiles based on its sight_range
	var fog = FogOfWarScript.new()
	fog.set_process(false)
	runner.add_child(fog)
	runner.spawner.spawned_entities.append(fog)
	await runner.wait_frames(2)

	# Spawn a player villager
	var villager = runner.spawner.spawn_villager(Vector2(600, 600), PLAYER_TEAM)
	await runner.wait_frames(2)

	# Get villager's sight_range
	var sight_range = villager.sight_range

	# Manually update visibility
	fog.call("_update_visibility")

	# Position at villager should be visible
	if not fog.call("is_visible",villager.global_position):
		return Assertions.AssertResult.new(false,
			"Tile at villager position should be VISIBLE")

	# Position within sight_range should be visible
	var nearby_pos = villager.global_position + Vector2(sight_range * 0.5, 0)
	if not fog.call("is_visible",nearby_pos):
		return Assertions.AssertResult.new(false,
			"Tile within sight_range should be VISIBLE")

	return Assertions.AssertResult.new(true)


# === Building Sight Range Tests ===

func test_building_default_sight_range() -> Assertions.AssertResult:
	## Default building sight_range should be 192.0 pixels (~6 tiles)
	var house = runner.spawner.spawn_house(Vector2(400, 400), PLAYER_TEAM)
	await runner.wait_frames(2)

	if house.sight_range != 192.0:
		return Assertions.AssertResult.new(false,
			"Default building sight_range should be 192.0, got: %.1f" % house.sight_range)

	return Assertions.AssertResult.new(true)


func test_town_center_has_larger_sight_range() -> Assertions.AssertResult:
	## Town Center should have sight_range of 256.0 pixels (~8 tiles)
	var tc = runner.spawner.spawn_town_center(Vector2(400, 400), PLAYER_TEAM)
	await runner.wait_frames(2)

	if tc.sight_range != 256.0:
		return Assertions.AssertResult.new(false,
			"Town Center sight_range should be 256.0, got: %.1f" % tc.sight_range)

	return Assertions.AssertResult.new(true)


func test_player_building_reveals_nearby_tiles() -> Assertions.AssertResult:
	## Player building should reveal tiles within its sight_range
	var fog = FogOfWarScript.new()
	fog.set_process(false)
	runner.add_child(fog)
	runner.spawner.spawned_entities.append(fog)
	await runner.wait_frames(2)

	# Spawn a player building
	var tc = runner.spawner.spawn_town_center(Vector2(700, 700), PLAYER_TEAM)
	await runner.wait_frames(2)

	# Manually call _update_visibility
	fog.call("_update_visibility")

	# Building position should be visible
	if not fog.call("is_visible",tc.global_position):
		return Assertions.AssertResult.new(false,
			"Tile at player building position should be VISIBLE")

	# Position within sight_range should be visible
	var nearby_pos = tc.global_position + Vector2(tc.sight_range * 0.5, 0)
	if not fog.call("is_visible",nearby_pos):
		return Assertions.AssertResult.new(false,
			"Tile within building sight_range should be VISIBLE")

	return Assertions.AssertResult.new(true)
