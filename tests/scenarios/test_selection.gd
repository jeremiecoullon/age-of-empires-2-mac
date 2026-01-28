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
	]


func test_click_selects_villager() -> Assertions.AssertResult:
	## Clicking on a villager should select it
	var villager = runner.spawner.spawn_villager(Vector2(400, 400))
	await runner.wait_frames(2)

	await runner.input_sim.click_on_entity(villager)
	await runner.wait_frames(2)

	return Assertions.assert_selected([villager])


func test_click_selects_militia() -> Assertions.AssertResult:
	## Clicking on a militia should select it
	var militia = runner.spawner.spawn_militia(Vector2(400, 400))
	await runner.wait_frames(2)

	await runner.input_sim.click_on_entity(militia)
	await runner.wait_frames(2)

	return Assertions.assert_selected([militia])


func test_click_empty_deselects() -> Assertions.AssertResult:
	## Clicking on empty ground should deselect all units
	var villager = runner.spawner.spawn_villager(Vector2(400, 400))
	await runner.wait_frames(2)

	# First select the villager
	await runner.input_sim.click_on_entity(villager)
	await runner.wait_frames(2)

	# Then click on empty ground (far from any entity)
	await runner.input_sim.click_at_world_pos(Vector2(100, 100))
	await runner.wait_frames(2)

	return Assertions.assert_nothing_selected()


func test_click_different_unit_changes_selection() -> Assertions.AssertResult:
	## Clicking a different unit should deselect the first and select the second
	var villager1 = runner.spawner.spawn_villager(Vector2(400, 400))
	var villager2 = runner.spawner.spawn_villager(Vector2(500, 400))
	await runner.wait_frames(2)

	# Select first villager
	await runner.input_sim.click_on_entity(villager1)
	await runner.wait_frames(2)

	# Select second villager
	await runner.input_sim.click_on_entity(villager2)
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
	await runner.input_sim.click_at_world_pos(Vector2(420, 400))
	await runner.wait_frames(2)

	return Assertions.assert_selected([villager])


func test_click_far_from_unit_no_select() -> Assertions.AssertResult:
	## Clicking more than 30 pixels from a unit should not select it
	var villager = runner.spawner.spawn_villager(Vector2(400, 400))
	await runner.wait_frames(2)

	# Click 50 pixels away (outside 30px radius)
	await runner.input_sim.click_at_world_pos(Vector2(450, 400))
	await runner.wait_frames(2)

	return Assertions.assert_nothing_selected()


func test_box_select_multiple_units() -> Assertions.AssertResult:
	## Dragging a box around multiple units should select all of them
	var villager1 = runner.spawner.spawn_villager(Vector2(400, 400))
	var villager2 = runner.spawner.spawn_villager(Vector2(450, 400))
	var villager3 = runner.spawner.spawn_villager(Vector2(400, 450))
	await runner.wait_frames(2)

	# Drag box from top-left to bottom-right
	await runner.input_sim.drag_box(Vector2(350, 350), Vector2(500, 500))
	await runner.wait_frames(2)

	return Assertions.assert_selection_count(3)


func test_box_select_empty_area() -> Assertions.AssertResult:
	## Dragging a box in empty area should not select anything
	var villager = runner.spawner.spawn_villager(Vector2(400, 400))
	await runner.wait_frames(2)

	# Drag box in empty area
	await runner.input_sim.drag_box(Vector2(100, 100), Vector2(200, 200))
	await runner.wait_frames(2)

	return Assertions.assert_nothing_selected()


func test_only_player_units_selectable() -> Assertions.AssertResult:
	## Clicking on enemy units should not select them
	var enemy_villager = runner.spawner.spawn_villager(Vector2(400, 400), 1)  # team 1 = AI
	await runner.wait_frames(2)

	await runner.input_sim.click_on_entity(enemy_villager)
	await runner.wait_frames(2)

	return Assertions.assert_nothing_selected()
