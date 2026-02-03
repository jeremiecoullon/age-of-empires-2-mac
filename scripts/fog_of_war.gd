extends Node2D
class_name FogOfWar

## Fog of War system with three visibility states:
## - UNEXPLORED (black): Never seen
## - EXPLORED (fog): Previously seen but not currently visible
## - VISIBLE (clear): Currently in line of sight

## DEBUG: Set to true to disable fog of war (see entire map)
const FOG_DISABLED: bool = true  # <-- Set to false for normal gameplay

enum VisibilityState { UNEXPLORED, EXPLORED, VISIBLE }

const TILE_SIZE: int = 32
const MAP_SIZE: int = 1920  # Map dimensions in pixels
const GRID_SIZE: int = 60   # MAP_SIZE / TILE_SIZE = 60x60 tiles

# Visibility grid - stores per-tile state
var visibility_grid: Array = []  # 2D array [x][y] of VisibilityState

# For rendering
var fog_image: Image
var fog_texture: ImageTexture
var fog_sprite: Sprite2D

# Colors for each state
const COLOR_UNEXPLORED = Color(0, 0, 0, 1)      # Solid black
const COLOR_EXPLORED = Color(0, 0, 0, 0.6)       # Semi-transparent black (fog)
const COLOR_VISIBLE = Color(0, 0, 0, 0)          # Fully transparent

# Update throttling
var update_timer: float = 0.0
const UPDATE_INTERVAL: float = 0.2  # Update fog every 0.2 seconds

# Team constants
const PLAYER_TEAM: int = 0
const NEUTRAL_TEAM: int = -1  # Wild animals, unowned sheep

func _ready() -> void:
	add_to_group("fog_of_war")
	z_index = 100  # Draw above game objects but UI (CanvasLayer) is still on top
	_init_grid()
	_init_rendering()
	# Initial reveal around player starting position
	call_deferred("_initial_reveal")

func _init_grid() -> void:
	visibility_grid.resize(GRID_SIZE)
	for x in range(GRID_SIZE):
		visibility_grid[x] = []
		visibility_grid[x].resize(GRID_SIZE)
		for y in range(GRID_SIZE):
			visibility_grid[x][y] = VisibilityState.UNEXPLORED

func _init_rendering() -> void:
	# Create the fog image and texture
	fog_image = Image.create(GRID_SIZE, GRID_SIZE, false, Image.FORMAT_RGBA8)
	fog_image.fill(COLOR_UNEXPLORED)

	fog_texture = ImageTexture.create_from_image(fog_image)

	# Create sprite to display fog
	fog_sprite = Sprite2D.new()
	fog_sprite.texture = fog_texture
	fog_sprite.centered = false
	fog_sprite.scale = Vector2(TILE_SIZE, TILE_SIZE)  # Scale up to map size
	add_child(fog_sprite)

	# DEBUG: Hide fog if disabled
	if FOG_DISABLED:
		fog_sprite.visible = false
		print("=== FOG OF WAR DISABLED FOR DEBUGGING ===")

func _initial_reveal() -> void:
	# Reveal around player's starting units and buildings
	_update_visibility()

func _process(delta: float) -> void:
	if FOG_DISABLED:
		return  # Skip all processing when debugging
	update_timer += delta
	if update_timer >= UPDATE_INTERVAL:
		update_timer = 0.0
		_update_visibility()

func _update_visibility() -> void:
	# Step 1: Demote all VISIBLE tiles to EXPLORED
	for x in range(GRID_SIZE):
		for y in range(GRID_SIZE):
			if visibility_grid[x][y] == VisibilityState.VISIBLE:
				visibility_grid[x][y] = VisibilityState.EXPLORED

	# Step 2: Reveal tiles around player units
	var units = get_tree().get_nodes_in_group("units")
	for unit in units:
		if not is_instance_valid(unit):
			continue
		if unit.team != PLAYER_TEAM:
			continue
		if unit.is_dead:
			continue
		_reveal_around(unit.global_position, unit.sight_range)

	# Step 3: Reveal tiles around player buildings
	var buildings = get_tree().get_nodes_in_group("buildings")
	for building in buildings:
		if not is_instance_valid(building):
			continue
		if building.team != PLAYER_TEAM:
			continue
		if building.is_destroyed:
			continue
		# Buildings always have sight_range defined in Building base class
		_reveal_around(building.global_position, building.sight_range)

	# Step 4: Update the fog texture
	_update_fog_texture()

	# Step 5: Update visibility of enemy entities
	_update_enemy_visibility()

func _reveal_around(world_pos: Vector2, radius: float) -> void:
	var center_tile = _world_to_tile(world_pos)
	var tile_radius = int(ceil(radius / TILE_SIZE))

	for dx in range(-tile_radius, tile_radius + 1):
		for dy in range(-tile_radius, tile_radius + 1):
			var tx = center_tile.x + dx
			var ty = center_tile.y + dy

			if tx < 0 or tx >= GRID_SIZE or ty < 0 or ty >= GRID_SIZE:
				continue

			# Check if within circular radius
			var tile_center = _tile_to_world(Vector2i(tx, ty))
			if world_pos.distance_to(tile_center) <= radius:
				visibility_grid[tx][ty] = VisibilityState.VISIBLE

func _world_to_tile(world_pos: Vector2) -> Vector2i:
	var tx = clampi(int(world_pos.x / TILE_SIZE), 0, GRID_SIZE - 1)
	var ty = clampi(int(world_pos.y / TILE_SIZE), 0, GRID_SIZE - 1)
	return Vector2i(tx, ty)

func _tile_to_world(tile: Vector2i) -> Vector2:
	# Returns center of tile
	return Vector2(tile.x * TILE_SIZE + TILE_SIZE / 2.0, tile.y * TILE_SIZE + TILE_SIZE / 2.0)

func _update_fog_texture() -> void:
	for x in range(GRID_SIZE):
		for y in range(GRID_SIZE):
			var color: Color
			match visibility_grid[x][y]:
				VisibilityState.UNEXPLORED:
					color = COLOR_UNEXPLORED
				VisibilityState.EXPLORED:
					color = COLOR_EXPLORED
				VisibilityState.VISIBLE:
					color = COLOR_VISIBLE
			fog_image.set_pixel(x, y, color)

	fog_texture.update(fog_image)

func _update_enemy_visibility() -> void:
	# Hide/show enemy units based on visibility
	var units = get_tree().get_nodes_in_group("units")
	for unit in units:
		if not is_instance_valid(unit):
			continue
		if unit.team == PLAYER_TEAM:
			continue  # Player units always visible

		var tile = _world_to_tile(unit.global_position)
		var state = visibility_grid[tile.x][tile.y]

		if unit.team == NEUTRAL_TEAM:
			# Neutral units (wild animals) visible once explored
			unit.visible = (state != VisibilityState.UNEXPLORED)
		else:
			# Enemy units only visible when tile is VISIBLE
			unit.visible = (state == VisibilityState.VISIBLE)

	# Hide/show enemy buildings based on visibility
	var buildings = get_tree().get_nodes_in_group("buildings")
	for building in buildings:
		if not is_instance_valid(building):
			continue
		if building.team == PLAYER_TEAM:
			continue  # Player buildings always visible

		var tile = _world_to_tile(building.global_position)
		var state = visibility_grid[tile.x][tile.y]

		# Enemy buildings visible if EXPLORED or VISIBLE (last known position)
		building.visible = (state != VisibilityState.UNEXPLORED)

## Check if a world position is currently visible to the player
func is_position_visible(world_pos: Vector2) -> bool:
	var tile = _world_to_tile(world_pos)
	return visibility_grid[tile.x][tile.y] == VisibilityState.VISIBLE

## Check if a world position has been explored (seen at least once)
func is_explored(world_pos: Vector2) -> bool:
	var tile = _world_to_tile(world_pos)
	return visibility_grid[tile.x][tile.y] != VisibilityState.UNEXPLORED

## Get the visibility state at a world position
func get_visibility_at(world_pos: Vector2) -> VisibilityState:
	var tile = _world_to_tile(world_pos)
	return visibility_grid[tile.x][tile.y]

## Reveal entire map (for debugging or cheats)
func reveal_all() -> void:
	for x in range(GRID_SIZE):
		for y in range(GRID_SIZE):
			visibility_grid[x][y] = VisibilityState.VISIBLE
	_update_fog_texture()
	_update_enemy_visibility()

## Reset fog to unexplored (for new game)
func reset() -> void:
	for x in range(GRID_SIZE):
		for y in range(GRID_SIZE):
			visibility_grid[x][y] = VisibilityState.UNEXPLORED
	_update_fog_texture()
	_update_enemy_visibility()
