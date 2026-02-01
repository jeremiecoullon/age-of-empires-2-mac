extends Control
class_name Minimap

## Square minimap displaying terrain, units, buildings, and fog of war.
## Simple 1:1 mapping: world X = minimap X, world Y = minimap Y.

const TILE_SIZE: int = 32
const MAP_SIZE: int = 1920  # Map dimensions in pixels
const GRID_SIZE: int = 60   # MAP_SIZE / TILE_SIZE = 60x60 tiles

# Team constants (matching fog_of_war.gd)
const PLAYER_TEAM: int = 0
const AI_TEAM: int = 1
const NEUTRAL_TEAM: int = -1

# Minimap dimensions - set from Control size in _ready (110x110 in scene)
var minimap_size: Vector2 = Vector2(110, 110)

# Rendering
var minimap_image: Image
var minimap_texture: ImageTexture

# Colors
const COLOR_TERRAIN = Color(0.25, 0.45, 0.2)       # Green grass
const COLOR_TREE = Color(0.1, 0.3, 0.1)            # Dark green trees
const COLOR_GOLD = Color(1.0, 0.85, 0.0)           # Gold
const COLOR_STONE = Color(0.5, 0.5, 0.5)           # Gray stone
const COLOR_BERRY = Color(0.8, 0.2, 0.2)           # Red berries
const COLOR_PLAYER_UNIT = Color(0.3, 0.5, 0.9)     # Blue
const COLOR_PLAYER_BUILDING = Color(0.2, 0.4, 0.8) # Darker blue
const COLOR_AI_UNIT = Color(0.9, 0.2, 0.2)         # Red
const COLOR_AI_BUILDING = Color(0.7, 0.15, 0.15)   # Darker red
const COLOR_NEUTRAL = Color(0.8, 0.8, 0.3)         # Yellow for neutral/sheep
const COLOR_FOG_UNEXPLORED = Color(0.12, 0.12, 0.12, 1)  # Very dark grey
const COLOR_FOG_EXPLORED = Color(0, 0, 0, 0.5)     # Semi-transparent black
const COLOR_CAMERA_BOX = Color(1, 1, 1, 0.8)       # White camera indicator

# Update throttling
var update_timer: float = 0.0
const UPDATE_INTERVAL: float = 0.25  # Update minimap every 0.25 seconds

# References
var fog_of_war: FogOfWar = null
var camera: Camera2D = null

# Camera viewport indicator
var camera_rect: Rect2 = Rect2()

signal minimap_clicked(world_position: Vector2)


func _ready() -> void:
	# Initialize minimap rendering
	minimap_size = size
	_init_rendering()

	# Find fog of war reference
	call_deferred("_find_references")

	# Enable mouse input
	mouse_filter = Control.MOUSE_FILTER_STOP


func _find_references() -> void:
	var fog_nodes = get_tree().get_nodes_in_group("fog_of_war")
	if fog_nodes.size() > 0:
		fog_of_war = fog_nodes[0]

	# Find camera
	camera = get_viewport().get_camera_2d()


func _init_rendering() -> void:
	minimap_image = Image.create(GRID_SIZE, GRID_SIZE, false, Image.FORMAT_RGBA8)
	minimap_image.fill(COLOR_TERRAIN)
	minimap_texture = ImageTexture.create_from_image(minimap_image)


func _process(delta: float) -> void:
	update_timer += delta
	if update_timer >= UPDATE_INTERVAL:
		update_timer = 0.0
		_update_minimap()
		queue_redraw()


func _update_minimap() -> void:
	# Step 1: Fill with terrain color
	minimap_image.fill(COLOR_TERRAIN)

	# Step 2: Draw resources
	_draw_resources()

	# Step 3: Draw buildings
	_draw_buildings()

	# Step 4: Draw units
	_draw_units()

	# Step 5: Apply fog of war overlay
	_apply_fog_overlay()

	# Step 6: Update camera rect
	_update_camera_rect()

	# Update texture
	minimap_texture.update(minimap_image)


func _draw_resources() -> void:
	var resources = get_tree().get_nodes_in_group("resources")
	for resource in resources:
		if not is_instance_valid(resource):
			continue

		var tile = _world_to_tile(resource.global_position)
		var color: Color

		if resource is Farm:
			color = COLOR_TERRAIN  # Farms blend with terrain
		elif resource.resource_type == "wood":
			color = COLOR_TREE
		elif resource.resource_type == "gold":
			color = COLOR_GOLD
		elif resource.resource_type == "stone":
			color = COLOR_STONE
		elif resource.resource_type == "food":
			color = COLOR_BERRY
		else:
			continue

		_set_pixel_safe(tile.x, tile.y, color)


func _draw_buildings() -> void:
	var buildings = get_tree().get_nodes_in_group("buildings")
	for building in buildings:
		if not is_instance_valid(building):
			continue
		if building.is_destroyed:
			continue

		var tile = _world_to_tile(building.global_position)

		# Fog of war check for enemy buildings - only draw if EXPLORED or VISIBLE
		if building.team != PLAYER_TEAM and fog_of_war:
			if tile.x >= 0 and tile.x < GRID_SIZE and tile.y >= 0 and tile.y < GRID_SIZE:
				var state = fog_of_war.visibility_grid[tile.x][tile.y]
				if state == FogOfWar.VisibilityState.UNEXPLORED:
					continue  # Don't draw unexplored enemy buildings

		var color: Color
		if building.team == PLAYER_TEAM:
			color = COLOR_PLAYER_BUILDING
		else:
			color = COLOR_AI_BUILDING

		# Buildings are larger - draw 2x2 for visibility
		for dx in range(-1, 2):
			for dy in range(-1, 2):
				_set_pixel_safe(tile.x + dx, tile.y + dy, color)


func _draw_units() -> void:
	var units = get_tree().get_nodes_in_group("units")
	for unit in units:
		if not is_instance_valid(unit):
			continue
		if unit.is_dead:
			continue

		var tile = _world_to_tile(unit.global_position)

		# Fog of war visibility check
		if fog_of_war and tile.x >= 0 and tile.x < GRID_SIZE and tile.y >= 0 and tile.y < GRID_SIZE:
			var state = fog_of_war.visibility_grid[tile.x][tile.y]

			if unit.team == NEUTRAL_TEAM:
				# Neutral units visible once explored
				if state == FogOfWar.VisibilityState.UNEXPLORED:
					continue
			elif unit.team != PLAYER_TEAM:
				# Enemy units only visible when tile is VISIBLE
				if state != FogOfWar.VisibilityState.VISIBLE:
					continue

		var color: Color
		if unit.team == PLAYER_TEAM:
			color = COLOR_PLAYER_UNIT
		elif unit.team == NEUTRAL_TEAM:
			color = COLOR_NEUTRAL  # Wild animals
		else:
			color = COLOR_AI_UNIT

		_set_pixel_safe(tile.x, tile.y, color)


func _apply_fog_overlay() -> void:
	if not fog_of_war:
		return

	# Validate fog grid dimensions match expected size
	if fog_of_war.visibility_grid.size() != GRID_SIZE:
		return

	for x in range(GRID_SIZE):
		if fog_of_war.visibility_grid[x].size() != GRID_SIZE:
			continue

		for y in range(GRID_SIZE):
			var state = fog_of_war.visibility_grid[x][y]

			if state == FogOfWar.VisibilityState.UNEXPLORED:
				_set_pixel_safe(x, y, COLOR_FOG_UNEXPLORED)
			elif state == FogOfWar.VisibilityState.EXPLORED:
				# Blend fog with existing color
				var existing = minimap_image.get_pixel(x, y)
				var blended = existing.darkened(0.4)
				_set_pixel_safe(x, y, blended)
			# VISIBLE: no overlay


func _update_camera_rect() -> void:
	if not camera:
		camera = get_viewport().get_camera_2d()
		if not camera:
			return

	var viewport_size = get_viewport().get_visible_rect().size
	var cam_pos = camera.global_position
	var zoom = camera.zoom

	# Safety check for zero zoom
	if zoom.x == 0 or zoom.y == 0:
		return

	# Calculate camera viewport in world coordinates
	var half_viewport = viewport_size / 2.0 / zoom
	var world_rect = Rect2(
		cam_pos - half_viewport,
		viewport_size / zoom
	)

	# Convert to minimap coordinates (simple scale)
	var scale_factor = minimap_size / Vector2(MAP_SIZE, MAP_SIZE)
	camera_rect = Rect2(
		world_rect.position * scale_factor,
		world_rect.size * scale_factor
	)


func _draw() -> void:
	# Draw the minimap image (60x60 grid) scaled to control size
	draw_texture_rect(minimap_texture, Rect2(Vector2.ZERO, minimap_size), false)

	# Draw camera viewport indicator (white rectangle)
	if camera_rect.size.x > 0:
		draw_rect(camera_rect, COLOR_CAMERA_BOX, false, 2.0)


func _world_to_tile(world_pos: Vector2) -> Vector2i:
	# Simple 1:1 mapping from world to grid coordinates
	var tx = clampi(int(world_pos.x / TILE_SIZE), 0, GRID_SIZE - 1)
	var ty = clampi(int(world_pos.y / TILE_SIZE), 0, GRID_SIZE - 1)
	return Vector2i(tx, ty)


func _set_pixel_safe(x: int, y: int, color: Color) -> void:
	if x >= 0 and x < GRID_SIZE and y >= 0 and y < GRID_SIZE:
		minimap_image.set_pixel(x, y, color)


signal minimap_right_clicked(world_position: Vector2)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		var world_pos = _local_to_world(event.position)
		if event.button_index == MOUSE_BUTTON_LEFT:
			minimap_clicked.emit(world_pos)
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			minimap_right_clicked.emit(world_pos)
			get_viewport().set_input_as_handled()


func _local_to_world(local_pos: Vector2) -> Vector2:
	# Convert minimap click position to world position (simple scale)
	var normalized = local_pos / minimap_size
	var world_pos = normalized * Vector2(MAP_SIZE, MAP_SIZE)

	# Clamp to map bounds
	world_pos.x = clampf(world_pos.x, 0, MAP_SIZE)
	world_pos.y = clampf(world_pos.y, 0, MAP_SIZE)
	return world_pos
