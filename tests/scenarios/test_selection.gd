extends Node
## Selection Tests - Tests for click-to-select and box selection
##
## These tests verify:
## - Clicking a unit selects it
## - Clicking empty ground deselects
## - Clicking a different unit changes selection
## - Box drag selects multiple units
## - Only player units can be selected

class_name TestSelection

var runner: TestRunner


func _init(test_runner: TestRunner) -> void:
	runner = test_runner


func get_all_tests() -> Array[Callable]:
	## Returns all test methods to run
	return [
		test_click_selects_villager,
		test_click_selects_militia,
		test_click_empty_deselects,
		test_click_different_unit_changes_selection,
		test_click_near_unit_selects,
		test_click_far_from_unit_no_select,
		test_box_select_multiple_units,
		test_box_select_empty_area,
		test_only_player_units_selectable,
		test_box_select_excludes_enemy_units,
	]


func test_click_selects_villager() -> Assertions.AssertResult:
	## Clicking on a villager should select it
	var villager = runner.spawner.spawn_villager(Vector2(400, 400))
	await runner.wait_frames(2)

	# Use direct selection to bypass input simulation bugs in headless mode
	await runner.input_sim.direct_select_entity(villager)
	await runner.wait_frames(2)

	return Assertions.assert_selected([villager])


func test_click_selects_militia() -> Assertions.AssertResult:
	## Clicking on a militia should select it
	var militia = runner.spawner.spawn_militia(Vector2(400, 400))
	await runner.wait_frames(2)

	await runner.input_sim.direct_select_entity(militia)
	await runner.wait_frames(2)

	return Assertions.assert_selected([militia])


func test_click_empty_deselects() -> Assertions.AssertResult:
	## Clicking on empty ground should deselect all units
	var villager = runner.spawner.spawn_villager(Vector2(400, 400))
	await runner.wait_frames(2)

	# First select the villager
	await runner.input_sim.direct_select_entity(villager)
	await runner.wait_frames(2)

	# Then click on empty ground (far from any entity)
	await runner.input_sim.direct_select_at_world_pos(Vector2(100, 100))
	await runner.wait_frames(2)

	return Assertions.assert_nothing_selected()


func test_click_different_unit_changes_selection() -> Assertions.AssertResult:
	## Clicking a different unit should deselect the first and select the second
	var villager1 = runner.spawner.spawn_villager(Vector2(400, 400))
	var villager2 = runner.spawner.spawn_villager(Vector2(500, 400))
	await runner.wait_frames(2)

	# Select first villager
	await runner.input_sim.direct_select_entity(villager1)
	await runner.wait_frames(2)

	# Select second villager
	await runner.input_sim.direct_select_entity(villager2)
	await runner.wait_frames(2)

	# Only second should be selected
	var result1 = Assertions.assert_unit_not_selected(villager1)
	if not result1.passed:
		return result1

	return Assertions.assert_selected([villager2])


func test_click_near_unit_selects() -> Assertions.AssertResult:
	## Clicking within 30 pixels of a unit should select it (hit detection radius)
	var villager = runner.spawner.spawn_villager(Vector2(400, 400))
	await runner.wait_frames(2)

	# Click 20 pixels away (within 30px radius)
	await runner.input_sim.direct_select_at_world_pos(Vector2(420, 400))
	await runner.wait_frames(2)

	return Assertions.assert_selected([villager])


func test_click_far_from_unit_no_select() -> Assertions.AssertResult:
	## Clicking more than 30 pixels from a unit should not select it
	var villager = runner.spawner.spawn_villager(Vector2(400, 400))
	await runner.wait_frames(2)

	# Click 50 pixels away (outside 30px radius)
	await runner.input_sim.direct_select_at_world_pos(Vector2(450, 400))
	await runner.wait_frames(2)

	return Assertions.assert_nothing_selected()


func test_box_select_multiple_units() -> Assertions.AssertResult:
	## Dragging a box around multiple units should select all of them
	var villager1 = runner.spawner.spawn_villager(Vector2(400, 400))
	var villager2 = runner.spawner.spawn_villager(Vector2(450, 400))
	var villager3 = runner.spawner.spawn_villager(Vector2(400, 450))
	await runner.wait_frames(2)

	# Box select using world coordinates
	await runner.input_sim.direct_box_select(Vector2(350, 350), Vector2(500, 500))
	await runner.wait_frames(2)

	return Assertions.assert_selection_count(3)


func test_box_select_empty_area() -> Assertions.AssertResult:
	## Dragging a box in empty area should not select anything
	var villager = runner.spawner.spawn_villager(Vector2(400, 400))
	await runner.wait_frames(2)

	# Box select in empty area
	await runner.input_sim.direct_box_select(Vector2(100, 100), Vector2(200, 200))
	await runner.wait_frames(2)

	return Assertions.assert_nothing_selected()


func test_only_player_units_selectable() -> Assertions.AssertResult:
	## Clicking enemy units shows their info but doesn't add them to selection
	## (Enemy units can be viewed but not commanded)
	var enemy_villager = runner.spawner.spawn_villager(Vector2(400, 400), 1)  # team 1 = AI
	await runner.wait_frames(2)

	await runner.input_sim.direct_select_entity(enemy_villager)
	await runner.wait_frames(2)

	# Enemy should NOT be in selected_units (can't give them commands)
	return Assertions.assert_nothing_selected()


func test_box_select_excludes_enemy_units() -> Assertions.AssertResult:
	## Box selecting an area with both player and enemy units should only select player units
	var player_villager1 = runner.spawner.spawn_villager(Vector2(400, 400), 0)  # team 0 = player
	var player_villager2 = runner.spawner.spawn_villager(Vector2(450, 400), 0)
	var enemy_villager1 = runner.spawner.spawn_villager(Vector2(400, 450), 1)  # team 1 = AI
	var enemy_villager2 = runner.spawner.spawn_villager(Vector2(450, 450), 1)
	await runner.wait_frames(2)

	# Box select around all units
	await runner.input_sim.direct_box_select(Vector2(350, 350), Vector2(500, 500))
	await runner.wait_frames(2)

	# Only player units should be selected (2 units, not 4)
	var count_result = Assertions.assert_selection_count(2)
	if not count_result.passed:
		return count_result

	# Verify the correct units are selected
	var result1 = Assertions.assert_unit_selected(player_villager1)
	if not result1.passed:
		return result1

	var result2 = Assertions.assert_unit_selected(player_villager2)
	if not result2.passed:
		return result2

	# Verify enemy units are NOT selected
	var result3 = Assertions.assert_unit_not_selected(enemy_villager1)
	if not result3.passed:
		return result3

	return Assertions.assert_unit_not_selected(enemy_villager2)
