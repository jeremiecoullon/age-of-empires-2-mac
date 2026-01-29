extends Node
## Input Simulator - Simulates mouse clicks and drags for testing
##
## Usage:
##   var input_sim = InputSimulator.new()
##   add_child(input_sim)
##   input_sim.setup(camera)
##   await input_sim.click_at_world_pos(Vector2(100, 100))

class_name InputSimulator

var camera: Camera2D
var viewport: Viewport


func setup(cam: Camera2D) -> void:
	camera = cam
	viewport = get_viewport()
	if not viewport:
		push_error("InputSimulator.setup() called before node is in scene tree")


func world_to_screen(world_pos: Vector2) -> Vector2:
	## Convert world position to screen position using camera transform
	if camera:
		return viewport.get_canvas_transform() * world_pos
	return world_pos


func screen_to_world(screen_pos: Vector2) -> Vector2:
	## Convert screen position to world position
	if camera:
		return viewport.get_canvas_transform().affine_inverse() * screen_pos
	return screen_pos


func click_at_world_pos(world_pos: Vector2) -> void:
	## Simulate a left-click at a world position
	var screen_pos = world_to_screen(world_pos)
	await _simulate_click(screen_pos, MOUSE_BUTTON_LEFT)


func right_click_at_world_pos(world_pos: Vector2) -> void:
	## Simulate a right-click at a world position
	var screen_pos = world_to_screen(world_pos)
	await _simulate_click(screen_pos, MOUSE_BUTTON_RIGHT)


func click_on_entity(entity: Node2D) -> void:
	## Click directly on an entity's position
	await click_at_world_pos(entity.global_position)


func direct_select_at_world_pos(world_pos: Vector2) -> void:
	## Directly call selection logic, bypassing input simulation.
	## Use this when input simulation doesn't work (e.g., headless mode bugs).
	var main_node = get_tree().current_scene
	if main_node.has_method("_click_select"):
		main_node._click_select(world_pos)
		await get_tree().process_frame
	else:
		push_error("Main scene doesn't have _click_select method")


func direct_select_entity(entity: Node2D) -> void:
	## Directly select an entity by position
	await direct_select_at_world_pos(entity.global_position)


func direct_box_select(start_world: Vector2, end_world: Vector2) -> void:
	## Directly perform box selection without input simulation.
	## Selects all player units within the world-space rectangle.
	GameManager.clear_selection()

	var rect = Rect2(start_world, end_world - start_world).abs()
	var units = get_tree().get_nodes_in_group("units")

	for unit in units:
		if unit.team == 0 and rect.has_point(unit.global_position):
			GameManager.select_unit(unit)

	await get_tree().process_frame


func right_click_on_entity(entity: Node2D) -> void:
	## Right-click directly on an entity's position
	await right_click_at_world_pos(entity.global_position)


func drag_box(start_world: Vector2, end_world: Vector2) -> void:
	## Simulate a box selection drag from start to end
	var start_screen = world_to_screen(start_world)
	var end_screen = world_to_screen(end_world)
	var scale_factor = _get_input_scale_factor()
	var adjusted_start = start_screen / scale_factor
	var adjusted_end = end_screen / scale_factor

	# Mouse down at start
	var press_event = InputEventMouseButton.new()
	press_event.button_index = MOUSE_BUTTON_LEFT
	press_event.pressed = true
	press_event.position = adjusted_start
	press_event.global_position = adjusted_start
	Input.parse_input_event(press_event)

	await get_tree().process_frame

	# Mouse move to end
	var motion_event = InputEventMouseMotion.new()
	motion_event.position = adjusted_end
	motion_event.global_position = adjusted_end
	Input.parse_input_event(motion_event)

	await get_tree().process_frame

	# Mouse up at end
	var release_event = InputEventMouseButton.new()
	release_event.button_index = MOUSE_BUTTON_LEFT
	release_event.pressed = false
	release_event.position = adjusted_end
	release_event.global_position = adjusted_end
	Input.parse_input_event(release_event)

	await get_tree().process_frame


func _simulate_click(screen_pos: Vector2, button: MouseButton) -> void:
	## Internal: simulate press and release at screen position
	## Note: Input simulation has issues in Godot headless mode on Mac.
	## Prefer using direct_select_* methods for tests.
	var scale_factor = _get_input_scale_factor()
	var adjusted_pos = screen_pos / scale_factor

	# Press
	var press_event = InputEventMouseButton.new()
	press_event.button_index = button
	press_event.pressed = true
	press_event.position = adjusted_pos
	press_event.global_position = adjusted_pos
	Input.parse_input_event(press_event)

	await get_tree().process_frame

	# Release
	var release_event = InputEventMouseButton.new()
	release_event.button_index = button
	release_event.pressed = false
	release_event.position = adjusted_pos
	release_event.global_position = adjusted_pos
	Input.parse_input_event(release_event)

	await get_tree().process_frame


func _get_input_scale_factor() -> float:
	## Detect the input scale factor by checking if we're in headless mode
	## Godot headless mode on Mac scales input by ~20x due to a bug
	if DisplayServer.get_name() == "headless":
		return 20.0
	return 1.0
