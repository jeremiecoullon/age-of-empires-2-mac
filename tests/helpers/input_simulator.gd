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


func right_click_on_entity(entity: Node2D) -> void:
	## Right-click directly on an entity's position
	await right_click_at_world_pos(entity.global_position)


func drag_box(start_world: Vector2, end_world: Vector2) -> void:
	## Simulate a box selection drag from start to end
	var start_screen = world_to_screen(start_world)
	var end_screen = world_to_screen(end_world)

	# Mouse down at start
	var press_event = InputEventMouseButton.new()
	press_event.button_index = MOUSE_BUTTON_LEFT
	press_event.pressed = true
	press_event.position = start_screen
	press_event.global_position = start_screen
	viewport.push_input(press_event)

	await get_tree().process_frame

	# Mouse move to end
	var motion_event = InputEventMouseMotion.new()
	motion_event.position = end_screen
	motion_event.global_position = end_screen
	viewport.push_input(motion_event)

	await get_tree().process_frame

	# Mouse up at end
	var release_event = InputEventMouseButton.new()
	release_event.button_index = MOUSE_BUTTON_LEFT
	release_event.pressed = false
	release_event.position = end_screen
	release_event.global_position = end_screen
	viewport.push_input(release_event)

	await get_tree().process_frame


func _simulate_click(screen_pos: Vector2, button: MouseButton) -> void:
	## Internal: simulate press and release at screen position

	# Press
	var press_event = InputEventMouseButton.new()
	press_event.button_index = button
	press_event.pressed = true
	press_event.position = screen_pos
	press_event.global_position = screen_pos
	viewport.push_input(press_event)

	await get_tree().process_frame

	# Release
	var release_event = InputEventMouseButton.new()
	release_event.button_index = button
	release_event.pressed = false
	release_event.position = screen_pos
	release_event.global_position = screen_pos
	viewport.push_input(release_event)

	await get_tree().process_frame
