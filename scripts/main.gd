extends Node2D

const CursorManager = preload("res://scripts/ui/cursor_manager.gd")

const HOUSE_SCENE_PATH = "res://scenes/buildings/house.tscn"
const BARRACKS_SCENE_PATH = "res://scenes/buildings/barracks.tscn"
const FARM_SCENE_PATH = "res://scenes/buildings/farm.tscn"
const MILL_SCENE_PATH = "res://scenes/buildings/mill.tscn"
const LUMBER_CAMP_SCENE_PATH = "res://scenes/buildings/lumber_camp.tscn"
const MINING_CAMP_SCENE_PATH = "res://scenes/buildings/mining_camp.tscn"
const MARKET_SCENE_PATH = "res://scenes/buildings/market.tscn"
const ARCHERY_RANGE_SCENE_PATH = "res://scenes/buildings/archery_range.tscn"
const STABLE_SCENE_PATH = "res://scenes/buildings/stable.tscn"
const BLACKSMITH_SCENE_PATH = "res://scenes/buildings/blacksmith.tscn"
const MONASTERY_SCENE_PATH = "res://scenes/buildings/monastery.tscn"
const OUTPOST_SCENE_PATH = "res://scenes/buildings/outpost.tscn"
const WATCH_TOWER_SCENE_PATH = "res://scenes/buildings/watch_tower.tscn"
const RELIC_SCENE: PackedScene = preload("res://scenes/objects/relic.tscn")
const TILE_SIZE = 32

enum BuildingType { NONE, HOUSE, BARRACKS, FARM, MILL, LUMBER_CAMP, MINING_CAMP, MARKET, ARCHERY_RANGE, STABLE, BLACKSMITH, MONASTERY, OUTPOST, WATCH_TOWER }
var current_building_type: BuildingType = BuildingType.NONE

@onready var hud: CanvasLayer = $HUD
@onready var map: Node2D = $Map
@onready var buildings_container: Node2D = $Buildings
@onready var units_container: Node2D = $Units

var is_dragging: bool = false
var drag_start: Vector2 = Vector2.ZERO
var selection_rect: Rect2 = Rect2()
var building_ghost: Sprite2D = null
var cursor_manager: Node = null
var _game_logger: GameLogger = null

func _ready() -> void:
	# Initialize cursor manager
	cursor_manager = CursorManager.new()
	add_child(cursor_manager)
	cursor_manager.initialize(self)

	_game_logger = get_node_or_null("GameLogger") as GameLogger
	_spawn_relics()


func _spawn_relics() -> void:
	var relic_positions: Array[Vector2] = []
	var min_separation: float = 300.0
	var map_min: float = 400.0
	var map_max: float = 1400.0
	var max_attempts: int = 100

	for _i in range(GameManager.TOTAL_RELICS):
		var placed = false
		for _attempt in range(max_attempts):
			var pos = Vector2(
				randf_range(map_min, map_max),
				randf_range(map_min, map_max)
			)
			# Check separation from other relics
			var too_close = false
			for existing in relic_positions:
				if pos.distance_to(existing) < min_separation:
					too_close = true
					break
			if too_close:
				continue
			# Check not on top of buildings/resources
			var on_obstacle = false
			for building in get_tree().get_nodes_in_group("buildings"):
				if pos.distance_to(building.global_position) < 80.0:
					on_obstacle = true
					break
			if not on_obstacle:
				for resource in get_tree().get_nodes_in_group("resources"):
					if pos.distance_to(resource.global_position) < 60.0:
						on_obstacle = true
						break
			if on_obstacle:
				continue
			relic_positions.append(pos)
			placed = true
			break
		if not placed:
			# Fallback: place at a default position
			relic_positions.append(Vector2(
				map_min + (_i * (map_max - map_min) / GameManager.TOTAL_RELICS),
				map_min + (_i * (map_max - map_min) / GameManager.TOTAL_RELICS)
			))

	for pos in relic_positions:
		var relic = RELIC_SCENE.instantiate()
		relic.global_position = pos
		add_child(relic)


func _get_relic_at_position(pos: Vector2) -> Node:
	var relics = get_tree().get_nodes_in_group("relics")
	var closest: Node = null
	var closest_dist: float = 40.0

	for relic in relics:
		if not relic.visible:
			continue
		var dist = pos.distance_to(relic.global_position)
		if dist < closest_dist:
			closest_dist = dist
			closest = relic

	return closest


func _screen_to_world(screen_pos: Vector2) -> Vector2:
	## Convert screen coordinates to world coordinates
	## This uses the canvas transform so it works with both real and simulated input
	return get_viewport().get_canvas_transform().affine_inverse() * screen_pos


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
			_issue_command(_screen_to_world(event.position))

	elif event is InputEventMouseMotion and is_dragging:
		_update_selection(event.position)

	elif event is InputEventKey:
		if event.keycode == KEY_DELETE and event.pressed:
			# Delete selected building under construction
			hud.delete_selected_building()

func _start_selection(screen_pos: Vector2) -> void:
	var world_pos = _screen_to_world(screen_pos)

	# Check for units first - they have selection priority over buildings
	var clicked_unit = _get_unit_at_position(world_pos)
	if clicked_unit:
		# Unit found - skip building check, let drag/click selection handle it
		hud.hide_tc_panel()
		hud.hide_barracks_panel()
		hud.hide_market_panel()
		hud.hide_archery_range_panel()
		hud.hide_stable_panel()
		hud.hide_blacksmith_panel()
		hud.hide_monastery_panel()
		hud.hide_garrison_panel()
		is_dragging = true
		drag_start = screen_pos
		selection_rect = Rect2(drag_start, Vector2.ZERO)
		return

	# Check if clicking on a building (only if no unit nearby)
	var clicked_building = _get_building_at_position(world_pos)
	if clicked_building:
		GameManager.clear_selection()
		hud.hide_info()
		hud.hide_tc_panel()
		hud.hide_barracks_panel()
		hud.hide_market_panel()
		hud.hide_archery_range_panel()
		hud.hide_stable_panel()
		hud.hide_blacksmith_panel()
		hud.hide_monastery_panel()
		hud.hide_garrison_panel()
		if clicked_building is TownCenter:
			hud.show_tc_panel(clicked_building)
			hud.show_info(clicked_building)
		elif clicked_building is Barracks:
			hud.show_barracks_panel(clicked_building)
			hud.show_info(clicked_building)
		elif clicked_building is Market:
			hud.show_market_panel(clicked_building)
			hud.show_info(clicked_building)
		elif clicked_building is ArcheryRange:
			hud.show_archery_range_panel(clicked_building)
			hud.show_info(clicked_building)
		elif clicked_building is Stable:
			hud.show_stable_panel(clicked_building)
			hud.show_info(clicked_building)
		elif clicked_building is Blacksmith:
			hud.show_blacksmith_panel(clicked_building)
			hud.show_info(clicked_building)
		elif clicked_building is Monastery:
			hud.show_monastery_panel(clicked_building)
			hud.show_info(clicked_building)
		elif clicked_building is WatchTower:
			hud.show_garrison_building_panel(clicked_building)
			hud.show_info(clicked_building)
		else:
			hud.show_info(clicked_building)
		return

	hud.hide_tc_panel()
	hud.hide_barracks_panel()
	hud.hide_market_panel()
	hud.hide_archery_range_panel()
	hud.hide_stable_panel()
	hud.hide_blacksmith_panel()
	hud.hide_monastery_panel()
	hud.hide_garrison_panel()
	is_dragging = true
	drag_start = screen_pos
	selection_rect = Rect2(drag_start, Vector2.ZERO)

func _update_selection(screen_pos: Vector2) -> void:
	var size = screen_pos - drag_start
	selection_rect = Rect2(drag_start, size).abs()
	hud.update_selection_rect(selection_rect, true)

func _end_selection(screen_pos: Vector2) -> void:
	is_dragging = false

	if drag_start.distance_to(screen_pos) < 5:
		# Click selection
		_click_select(_screen_to_world(screen_pos))
	else:
		# Box selection
		_box_select()

	selection_rect = Rect2()
	hud.update_selection_rect(selection_rect, false)

func _click_select(world_pos: Vector2) -> void:
	GameManager.clear_selection()

	# Check for unit first
	var unit = _get_unit_at_position(world_pos)
	if unit:
		# Only add player units to selection (for commands)
		# But show info for any unit (for scouting enemy)
		if unit.team == 0:
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

		if selection_rect.has_point(screen_pos) and unit.team == 0:
			GameManager.select_unit(unit)

func _issue_command(world_pos: Vector2) -> void:
	if GameManager.selected_units.is_empty():
		return

	# Check if clicking on an enemy unit (for attack command)
	# Exclude animals — they're handled separately below via command_hunt
	var target_unit = _get_unit_at_position(world_pos)
	if target_unit and target_unit.team != 0 and not target_unit.is_in_group("animals"):
		# Mixed group: monks convert, military attacks
		for unit in GameManager.selected_units:
			if unit is Monk:
				unit.command_convert(target_unit)
			elif unit.has_method("command_attack"):
				unit.command_attack(target_unit)
		if _game_logger:
			_game_logger.log_action("attack", {"target": "unit"})
		return

	# Check if clicking on a relic (for monk pickup)
	var relic = _get_relic_at_position(world_pos)
	if relic and not relic.is_carried and not relic.is_garrisoned:
		var sent_monk = false
		for unit in GameManager.selected_units:
			if unit is Monk and not unit.carrying_relic:
				unit.command_pickup_relic(relic)
				sent_monk = true
				break  # Only one monk per relic
		if sent_monk:
			if _game_logger:
				_game_logger.log_action("pickup_relic", {})
			return

	# Check if clicking on a friendly wounded unit (monk heal)
	if target_unit and target_unit.team == 0 and target_unit.current_hp < target_unit.max_hp:
		var has_monks = false
		for unit in GameManager.selected_units:
			if unit is Monk:
				unit.command_heal(target_unit)
				has_monks = true
		if has_monks:
			if _game_logger:
				_game_logger.log_action("heal", {"target": "unit"})
			return

	# Check if clicking on a building
	var target_building = _get_building_at_position(world_pos)
	if target_building:
		# Friendly monastery - garrison relic if monk is carrying one
		if target_building.team == 0 and target_building is Monastery:
			var sent_monk = false
			for unit in GameManager.selected_units:
				if unit is Monk and unit.carrying_relic:
					unit.command_garrison_relic(target_building)
					sent_monk = true
			if sent_monk:
				if _game_logger:
					_game_logger.log_action("garrison_relic", {})
				return
		# Enemy building - attack
		if target_building.team != 0:
			for unit in GameManager.selected_units:
				if unit.has_method("command_attack"):
					unit.command_attack(target_building)
			if _game_logger:
				_game_logger.log_action("attack", {"target": "building"})
			return
		# Friendly building under construction - help build
		elif not target_building.is_constructed:
			for unit in GameManager.selected_units:
				if unit is Villager:
					unit.command_build(target_building)
			if _game_logger:
				_game_logger.log_action("build_assist", {})
			return
		# Friendly building damaged - repair
		elif target_building.needs_repair():
			for unit in GameManager.selected_units:
				if unit is Villager:
					unit.command_repair(target_building)
			if _game_logger:
				_game_logger.log_action("repair", {})
			return
		# Friendly functional building with garrison capacity - garrison eligible units
		elif target_building.garrison_capacity > 0 and target_building.is_functional():
			var garrisoned_any = false
			for unit in GameManager.selected_units:
				if target_building.can_garrison(unit):
					target_building.garrison_unit(unit)
					garrisoned_any = true
			if garrisoned_any:
				GameManager.clear_selection()
				if _game_logger:
					_game_logger.log_action("garrison", {"building": target_building.building_name})
				return

	# Check if clicking on an animal (for hunting)
	var animal = _get_animal_at_position(world_pos)
	if animal:
		for unit in GameManager.selected_units:
			if unit is Villager:
				unit.command_hunt(animal)
		if _game_logger:
			_game_logger.log_action("hunt", {})
		return

	# Check if clicking on a resource
	var resource = _get_resource_at_position(world_pos)
	if resource:
		for unit in GameManager.selected_units:
			if unit is Villager:
				unit.command_gather(resource)
		if _game_logger:
			_game_logger.log_action("gather", {"resource": resource.resource_type if "resource_type" in resource else "unknown"})
		return

	# Otherwise, move command
	for unit in GameManager.selected_units:
		unit.move_to(world_pos)
	if _game_logger:
		_game_logger.log_action("move", {"pos": [world_pos.x, world_pos.y]})

func _get_resource_at_position(pos: Vector2) -> Node:  # Returns ResourceNode or Farm
	var resources = get_tree().get_nodes_in_group("resources")
	var closest: Node = null
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

func start_market_placement() -> void:
	if building_ghost:
		building_ghost.queue_free()

	building_ghost = Sprite2D.new()
	building_ghost.texture = _create_placeholder_texture(Vector2i(96, 96), Color(0.8, 0.6, 0.2, 0.5))
	add_child(building_ghost)

	current_building_type = BuildingType.MARKET
	GameManager.start_building_placement(load(MARKET_SCENE_PATH), building_ghost)

func start_archery_range_placement() -> void:
	if building_ghost:
		building_ghost.queue_free()

	building_ghost = Sprite2D.new()
	building_ghost.texture = _create_placeholder_texture(Vector2i(96, 96), Color(0.4, 0.6, 0.3, 0.5))
	add_child(building_ghost)

	current_building_type = BuildingType.ARCHERY_RANGE
	GameManager.start_building_placement(load(ARCHERY_RANGE_SCENE_PATH), building_ghost)

func start_stable_placement() -> void:
	if building_ghost:
		building_ghost.queue_free()

	building_ghost = Sprite2D.new()
	building_ghost.texture = _create_placeholder_texture(Vector2i(96, 96), Color(0.55, 0.35, 0.2, 0.5))
	add_child(building_ghost)

	current_building_type = BuildingType.STABLE
	GameManager.start_building_placement(load(STABLE_SCENE_PATH), building_ghost)

func start_monastery_placement() -> void:
	if building_ghost:
		building_ghost.queue_free()

	building_ghost = Sprite2D.new()
	building_ghost.texture = _create_placeholder_texture(Vector2i(96, 96), Color(0.7, 0.5, 0.8, 0.5))
	add_child(building_ghost)

	current_building_type = BuildingType.MONASTERY
	GameManager.start_building_placement(load(MONASTERY_SCENE_PATH), building_ghost)

func start_outpost_placement() -> void:
	if building_ghost:
		building_ghost.queue_free()

	building_ghost = Sprite2D.new()
	building_ghost.texture = _create_placeholder_texture(Vector2i(32, 32), Color(0.6, 0.5, 0.3, 0.5))
	add_child(building_ghost)

	current_building_type = BuildingType.OUTPOST
	GameManager.start_building_placement(load(OUTPOST_SCENE_PATH), building_ghost)

func start_watch_tower_placement() -> void:
	if building_ghost:
		building_ghost.queue_free()

	building_ghost = Sprite2D.new()
	building_ghost.texture = _create_placeholder_texture(Vector2i(32, 32), Color(0.5, 0.5, 0.55, 0.5))
	add_child(building_ghost)

	current_building_type = BuildingType.WATCH_TOWER
	GameManager.start_building_placement(load(WATCH_TOWER_SCENE_PATH), building_ghost)

func start_blacksmith_placement() -> void:
	if building_ghost:
		building_ghost.queue_free()

	building_ghost = Sprite2D.new()
	building_ghost.texture = _create_placeholder_texture(Vector2i(96, 96), Color(0.4, 0.4, 0.45, 0.5))
	add_child(building_ghost)

	current_building_type = BuildingType.BLACKSMITH
	GameManager.start_building_placement(load(BLACKSMITH_SCENE_PATH), building_ghost)

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

	# Need at least one selected villager to build
	var builder_villagers: Array[Villager] = []
	for unit in GameManager.selected_units:
		if unit is Villager and unit.team == 0:
			builder_villagers.append(unit)

	if builder_villagers.is_empty():
		hud._show_error("Select a villager to build!")
		return

	# Instantiate to get cost from the building itself (avoid duplicate values)
	var building = GameManager.building_to_place.instantiate()
	var costs: Dictionary = {}
	if building.wood_cost > 0: costs["wood"] = building.wood_cost
	if building.food_cost > 0: costs["food"] = building.food_cost
	if building.stone_cost > 0: costs["stone"] = building.stone_cost
	if building.gold_cost > 0: costs["gold"] = building.gold_cost

	# Check all resources affordable
	for res_type in costs:
		if not GameManager.can_afford(res_type, costs[res_type]):
			building.queue_free()
			return
	# Spend all resources
	for res_type in costs:
		GameManager.spend_resource(res_type, costs[res_type])

	building.global_position = pos
	building.team = 0  # Player team
	buildings_container.add_child(building)

	# Start construction (building begins at 1 HP)
	building.start_construction()

	# Command selected villagers to build
	for villager in builder_villagers:
		villager.command_build(building)

	if _game_logger:
		_game_logger.log_action("place_building", {
			"type": BuildingType.keys()[current_building_type].to_lower(),
			"pos": [pos.x, pos.y],
		})

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
		BuildingType.MARKET:
			return Vector2(96, 96)
		BuildingType.ARCHERY_RANGE:
			return Vector2(96, 96)
		BuildingType.STABLE:
			return Vector2(96, 96)
		BuildingType.BLACKSMITH:
			return Vector2(96, 96)
		BuildingType.MONASTERY:
			return Vector2(96, 96)
		BuildingType.OUTPOST:
			return Vector2(32, 32)
		BuildingType.WATCH_TOWER:
			return Vector2(32, 32)
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
