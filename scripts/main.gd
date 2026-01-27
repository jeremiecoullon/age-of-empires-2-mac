extends Node2D

const HOUSE_SCENE_PATH = "res://scenes/buildings/house.tscn"
const BARRACKS_SCENE_PATH = "res://scenes/buildings/barracks.tscn"
const FARM_SCENE_PATH = "res://scenes/buildings/farm.tscn"
const MILL_SCENE_PATH = "res://scenes/buildings/mill.tscn"
const LUMBER_CAMP_SCENE_PATH = "res://scenes/buildings/lumber_camp.tscn"
const MINING_CAMP_SCENE_PATH = "res://scenes/buildings/mining_camp.tscn"
const TILE_SIZE = 32

enum BuildingType { NONE, HOUSE, BARRACKS, FARM, MILL, LUMBER_CAMP, MINING_CAMP }
var current_building_type: BuildingType = BuildingType.NONE

@onready var hud: CanvasLayer = $HUD
@onready var map: Node2D = $Map
@onready var buildings_container: Node2D = $Buildings
@onready var units_container: Node2D = $Units

var is_dragging: bool = false
var drag_start: Vector2 = Vector2.ZERO
var selection_rect: Rect2 = Rect2()
var building_ghost: Sprite2D = null

func _ready() -> void:
	pass

func _unhandled_input(event: InputEvent) -> void:
	if GameManager.is_placing_building:
		_handle_building_placement_input(event)
		return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_start_selection(event.position)
			else:
				_end_selection(event.position)
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			_issue_command(get_global_mouse_position())

	elif event is InputEventMouseMotion and is_dragging:
		_update_selection(event.position)

func _start_selection(screen_pos: Vector2) -> void:
	var world_pos = get_global_mouse_position()

	# Check if clicking on a building first
	var clicked_building = _get_building_at_position(world_pos)
	if clicked_building:
		GameManager.clear_selection()
		hud.hide_info()
		hud.hide_tc_panel()
		hud.hide_barracks_panel()
		if clicked_building is TownCenter:
			hud.show_tc_panel(clicked_building)
			hud.show_info(clicked_building)
		elif clicked_building is Barracks:
			hud.show_barracks_panel(clicked_building)
			hud.show_info(clicked_building)
		else:
			hud.show_info(clicked_building)
		return

	hud.hide_tc_panel()
	hud.hide_barracks_panel()
	is_dragging = true
	drag_start = screen_pos
	selection_rect = Rect2(drag_start, Vector2.ZERO)

func _update_selection(screen_pos: Vector2) -> void:
	var size = screen_pos - drag_start
	selection_rect = Rect2(drag_start, size).abs()
	queue_redraw()

func _end_selection(screen_pos: Vector2) -> void:
	is_dragging = false

	if drag_start.distance_to(screen_pos) < 5:
		# Click selection
		_click_select(get_global_mouse_position())
	else:
		# Box selection
		_box_select()

	selection_rect = Rect2()
	queue_redraw()

func _click_select(world_pos: Vector2) -> void:
	GameManager.clear_selection()

	# Check for unit first
	var unit = _get_unit_at_position(world_pos)
	if unit:
		GameManager.select_unit(unit)
		hud.show_info(unit)
		return

	# Check for resource
	var resource = _get_resource_at_position(world_pos)
	if resource:
		hud.show_info(resource)
		return

	# Nothing clicked, hide info
	hud.hide_info()

func _get_unit_at_position(pos: Vector2) -> Unit:
	var units = get_tree().get_nodes_in_group("units")
	var closest: Unit = null
	var closest_dist: float = 30.0

	for unit in units:
		var dist = pos.distance_to(unit.global_position)
		if dist < closest_dist:
			closest_dist = dist
			closest = unit

	return closest

func _box_select() -> void:
	GameManager.clear_selection()

	var units = get_tree().get_nodes_in_group("units")
	var camera = get_viewport().get_camera_2d()

	for unit in units:
		var screen_pos = unit.global_position
		if camera:
			screen_pos = camera.get_viewport().get_canvas_transform() * unit.global_position
		else:
			screen_pos = get_viewport().get_canvas_transform() * unit.global_position

		if selection_rect.has_point(screen_pos):
			GameManager.select_unit(unit)

func _issue_command(world_pos: Vector2) -> void:
	if GameManager.selected_units.is_empty():
		return

	# Check if clicking on an enemy unit (for attack command)
	var target_unit = _get_unit_at_position(world_pos)
	if target_unit and target_unit.team != 0:  # Only attack enemy team units
		for unit in GameManager.selected_units:
			if unit is Militia:
				unit.command_attack(target_unit)
		return

	# Check if clicking on an enemy building (for attack command)
	var target_building = _get_building_at_position(world_pos)
	if target_building and target_building.team != 0:  # Only attack enemy buildings
		for unit in GameManager.selected_units:
			if unit is Militia:
				unit.command_attack(target_building)
		return

	# Check if clicking on an animal (for hunting)
	var animal = _get_animal_at_position(world_pos)
	if animal:
		for unit in GameManager.selected_units:
			if unit is Villager:
				unit.command_hunt(animal)
		return

	# Check if clicking on a resource
	var resource = _get_resource_at_position(world_pos)
	if resource:
		for unit in GameManager.selected_units:
			if unit is Villager:
				unit.command_gather(resource)
		return

	# Otherwise, move command
	for unit in GameManager.selected_units:
		unit.move_to(world_pos)

func _get_resource_at_position(pos: Vector2) -> ResourceNode:
	var resources = get_tree().get_nodes_in_group("resources")
	var closest: ResourceNode = null
	var closest_dist: float = 40.0  # Click detection radius

	for resource in resources:
		var dist = pos.distance_to(resource.global_position)
		if dist < closest_dist:
			closest_dist = dist
			closest = resource

	return closest

func _get_animal_at_position(pos: Vector2) -> Animal:
	var animals = get_tree().get_nodes_in_group("animals")
	var closest: Animal = null
	var closest_dist: float = 40.0  # Click detection radius

	for animal in animals:
		if animal.is_dead:
			continue
		var dist = pos.distance_to(animal.global_position)
		if dist < closest_dist:
			closest_dist = dist
			closest = animal

	return closest

func _get_building_at_position(pos: Vector2) -> Building:
	var buildings = get_tree().get_nodes_in_group("buildings")
	var closest: Building = null
	var closest_dist: float = 60.0

	for building in buildings:
		var dist = pos.distance_to(building.global_position)
		if dist < closest_dist:
			closest_dist = dist
			closest = building

	return closest

func _draw() -> void:
	if is_dragging and selection_rect.size != Vector2.ZERO:
		var local_rect = Rect2(
			selection_rect.position - global_position,
			selection_rect.size
		)
		draw_rect(local_rect, Color(0.2, 0.8, 0.2, 0.3), true)
		draw_rect(local_rect, Color(0.2, 0.8, 0.2, 0.8), false, 2.0)

func start_house_placement() -> void:
	if building_ghost:
		building_ghost.queue_free()

	building_ghost = Sprite2D.new()
	building_ghost.texture = _create_placeholder_texture(Vector2i(64, 64), Color(0.6, 0.4, 0.2, 0.5))
	add_child(building_ghost)

	current_building_type = BuildingType.HOUSE
	GameManager.start_building_placement(load(HOUSE_SCENE_PATH), building_ghost)

func start_barracks_placement() -> void:
	if building_ghost:
		building_ghost.queue_free()

	building_ghost = Sprite2D.new()
	building_ghost.texture = _create_placeholder_texture(Vector2i(96, 96), Color(0.3, 0.3, 0.35, 0.5))
	add_child(building_ghost)

	current_building_type = BuildingType.BARRACKS
	GameManager.start_building_placement(load(BARRACKS_SCENE_PATH), building_ghost)

func start_farm_placement() -> void:
	if building_ghost:
		building_ghost.queue_free()

	building_ghost = Sprite2D.new()
	building_ghost.texture = _create_placeholder_texture(Vector2i(64, 64), Color(0.9, 0.8, 0.3, 0.5))
	add_child(building_ghost)

	current_building_type = BuildingType.FARM
	GameManager.start_building_placement(load(FARM_SCENE_PATH), building_ghost)

func start_mill_placement() -> void:
	if building_ghost:
		building_ghost.queue_free()

	building_ghost = Sprite2D.new()
	building_ghost.texture = _create_placeholder_texture(Vector2i(64, 64), Color(0.9, 0.8, 0.4, 0.5))
	add_child(building_ghost)

	current_building_type = BuildingType.MILL
	GameManager.start_building_placement(load(MILL_SCENE_PATH), building_ghost)

func start_lumber_camp_placement() -> void:
	if building_ghost:
		building_ghost.queue_free()

	building_ghost = Sprite2D.new()
	building_ghost.texture = _create_placeholder_texture(Vector2i(64, 64), Color(0.5, 0.35, 0.2, 0.5))
	add_child(building_ghost)

	current_building_type = BuildingType.LUMBER_CAMP
	GameManager.start_building_placement(load(LUMBER_CAMP_SCENE_PATH), building_ghost)

func start_mining_camp_placement() -> void:
	if building_ghost:
		building_ghost.queue_free()

	building_ghost = Sprite2D.new()
	building_ghost.texture = _create_placeholder_texture(Vector2i(64, 64), Color(0.5, 0.5, 0.55, 0.5))
	add_child(building_ghost)

	current_building_type = BuildingType.MINING_CAMP
	GameManager.start_building_placement(load(MINING_CAMP_SCENE_PATH), building_ghost)

func _handle_building_placement_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		if building_ghost:
			var pos = get_global_mouse_position()
			# Snap to grid
			pos.x = snapped(pos.x, TILE_SIZE) + TILE_SIZE / 2
			pos.y = snapped(pos.y, TILE_SIZE) + TILE_SIZE / 2
			building_ghost.global_position = pos

	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_place_building()
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			_cancel_building_placement()

	elif event is InputEventKey:
		if event.keycode == KEY_ESCAPE and event.pressed:
			_cancel_building_placement()

func _cancel_building_placement() -> void:
	GameManager.cancel_building_placement()
	building_ghost = null
	current_building_type = BuildingType.NONE

func _place_building() -> void:
	if not GameManager.building_to_place:
		return

	var pos = building_ghost.global_position

	# Get building size for collision check
	var building_size = _get_building_size(current_building_type)

	# Check for valid placement (no overlaps)
	if not _is_valid_building_position(pos, building_size):
		hud._show_error("Cannot place building here!")
		return

	# Instantiate to get cost from the building itself (avoid duplicate values)
	var building = GameManager.building_to_place.instantiate()
	var cost = building.wood_cost

	if not GameManager.spend_resource("wood", cost):
		building.queue_free()
		return

	building.global_position = pos
	buildings_container.add_child(building)

	GameManager.complete_building_placement()
	current_building_type = BuildingType.NONE
	if building_ghost:
		building_ghost.queue_free()
		building_ghost = null

func _get_building_size(type: BuildingType) -> Vector2:
	match type:
		BuildingType.HOUSE:
			return Vector2(64, 64)
		BuildingType.BARRACKS:
			return Vector2(96, 96)
		BuildingType.FARM:
			return Vector2(64, 64)
		BuildingType.MILL:
			return Vector2(64, 64)
		BuildingType.LUMBER_CAMP:
			return Vector2(64, 64)
		BuildingType.MINING_CAMP:
			return Vector2(64, 64)
		_:
			return Vector2(64, 64)

func _is_valid_building_position(pos: Vector2, size: Vector2) -> bool:
	var half_size = size / 2

	# Check collision with existing buildings
	var buildings = get_tree().get_nodes_in_group("buildings")
	for building in buildings:
		var building_half_size = Vector2(building.size.x * TILE_SIZE, building.size.y * TILE_SIZE) / 2
		# Simple AABB overlap check
		if abs(pos.x - building.global_position.x) < (half_size.x + building_half_size.x) and \
		   abs(pos.y - building.global_position.y) < (half_size.y + building_half_size.y):
			return false

	# Check collision with resources
	var resources = get_tree().get_nodes_in_group("resources")
	for resource in resources:
		if not resource is Farm:  # Farms are buildings, already checked
			if pos.distance_to(resource.global_position) < half_size.x + 20:
				return false

	# Check if within map bounds (1920x1920 map)
	if pos.x - half_size.x < 0 or pos.x + half_size.x > 1920:
		return false
	if pos.y - half_size.y < 0 or pos.y + half_size.y > 1920:
		return false

	return true

func _create_placeholder_texture(size: Vector2i, color: Color) -> ImageTexture:
	var image = Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	image.fill(color)
	return ImageTexture.create_from_image(image)
