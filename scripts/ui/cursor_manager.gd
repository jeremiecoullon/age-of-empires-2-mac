extends Node
## Manages context-sensitive cursor changes based on selection and hover target.
## Changes cursor to indicate what action will happen on right-click.
##
## AoE2-style cursor behavior:
## - Default arrow for normal state
## - Sword for attack targets (enemies)
## - Axe for wood gathering (trees)
## - Hand for other resources (gold, stone, food, animals)
## - Hammer for building placement/construction
## - Forbidden for invalid actions

# Cursor textures - preloaded for performance
const CURSOR_DEFAULT: Texture2D = preload("res://assets/sprites_extracted/cursors/cursor_default.png")
const CURSOR_ATTACK: Texture2D = preload("res://assets/sprites_extracted/cursors/cursor_attack.png")
const CURSOR_GATHER: Texture2D = preload("res://assets/sprites_extracted/cursors/cursor_gather.png")
const CURSOR_HAND: Texture2D = preload("res://assets/sprites_extracted/cursors/cursor_hand.png")
const CURSOR_BUILD: Texture2D = preload("res://assets/sprites_extracted/cursors/cursor_build.png")
const CURSOR_FORBIDDEN: Texture2D = preload("res://assets/sprites_extracted/cursors/cursor_forbidden.png")

enum CursorType {
	DEFAULT,
	ATTACK,
	GATHER,  # Axe for trees
	HAND,    # Hand for gold/stone/farm/sheep/berries
	BUILD,   # Hammer for building placement or helping construction
	FORBIDDEN
}

var current_cursor: CursorType = CursorType.DEFAULT
var main_scene: Node2D = null

# Hotspot positions for cursors (where the "click point" is)
const HOTSPOT_DEFAULT := Vector2(0, 0)    # Arrow tip at top-left
const HOTSPOT_ATTACK := Vector2(16, 0)    # Sword tip at top-center
const HOTSPOT_GATHER := Vector2(12, 4)    # Axe blade near top
const HOTSPOT_HAND := Vector2(8, 0)       # Fingertip
const HOTSPOT_BUILD := Vector2(8, 4)      # Hammer head near top
const HOTSPOT_FORBIDDEN := Vector2(16, 16)  # Center of circle

# Throttling for hover queries (avoid expensive group searches every frame)
const CURSOR_UPDATE_INTERVAL: float = 0.1  # 10 updates per second
var _cursor_update_timer: float = 0.0
var _cached_hover_unit: Node = null
var _cached_hover_building: Node = null
var _cached_hover_resource: Node = null
var _cached_hover_animal: Node = null

func _ready() -> void:
	# Set default cursor on startup
	_set_cursor(CursorType.DEFAULT)


func initialize(main: Node2D) -> void:
	## Call this from main.gd to provide reference for position queries
	main_scene = main


func _process(delta: float) -> void:
	if not main_scene:
		return

	# Throttle hover cache updates to reduce group iteration costs
	_cursor_update_timer += delta
	if _cursor_update_timer >= CURSOR_UPDATE_INTERVAL:
		_cursor_update_timer = 0.0
		_update_hover_cache()

	_update_cursor()


func _update_hover_cache() -> void:
	## Update cached hover targets (throttled to avoid per-frame group iteration)
	var mouse_pos = main_scene.get_global_mouse_position()
	_cached_hover_unit = main_scene._get_unit_at_position(mouse_pos)
	_cached_hover_building = main_scene._get_building_at_position(mouse_pos)
	_cached_hover_resource = main_scene._get_resource_at_position(mouse_pos)
	_cached_hover_animal = main_scene._get_animal_at_position(mouse_pos)


func _update_cursor() -> void:
	## Determine and set the appropriate cursor based on current context
	var new_cursor: CursorType

	# Building placement mode takes priority
	if GameManager.is_placing_building:
		new_cursor = _get_building_placement_cursor()
	elif not GameManager.selected_units.is_empty():
		new_cursor = _get_selection_based_cursor()
	else:
		new_cursor = CursorType.DEFAULT

	if new_cursor != current_cursor:
		_set_cursor(new_cursor)


func _get_building_placement_cursor() -> CursorType:
	## Returns cursor for building placement mode
	var mouse_pos = main_scene.get_global_mouse_position()

	# Snap to grid for position check (same as main.gd)
	var tile_size = main_scene.TILE_SIZE
	var pos = mouse_pos
	pos.x = snapped(pos.x, tile_size) + tile_size / 2
	pos.y = snapped(pos.y, tile_size) + tile_size / 2

	# Check if position is valid using main's validation
	var building_size = _get_current_building_size()
	if main_scene._is_valid_building_position(pos, building_size):
		return CursorType.BUILD
	else:
		return CursorType.FORBIDDEN


func _get_current_building_size() -> Vector2:
	## Get size of currently placing building
	return main_scene._get_building_size(main_scene.current_building_type)


func _get_selection_based_cursor() -> CursorType:
	## Returns cursor based on selected units and hover target
	# Use cached hover targets (updated at throttled rate)
	var hover_unit = _cached_hover_unit
	var hover_building = _cached_hover_building
	var hover_resource = _cached_hover_resource
	var hover_animal = _cached_hover_animal

	# Determine selection type
	var has_villager := false
	var has_military := false

	for unit in GameManager.selected_units:
		if not is_instance_valid(unit):
			continue
		if unit is Villager:
			has_villager = true
		if unit.is_in_group("military"):
			has_military = true

	# Villager-specific cursors (check first since villagers can both gather and attack)
	if has_villager:
		# Hovering over resource - use appropriate gather cursor
		if hover_resource and is_instance_valid(hover_resource):
			# Use group check for resource type (more robust than string comparison)
			if hover_resource.is_in_group("trees"):
				return CursorType.GATHER  # Axe for trees
			else:
				return CursorType.HAND  # Hand for gold/stone/berries/farms

		# Hovering over animal - hunting uses hand cursor
		if hover_animal and is_instance_valid(hover_animal):
			return CursorType.HAND

		# Hovering over friendly building under construction - help build
		if hover_building and is_instance_valid(hover_building):
			if hover_building.team == 0 and not hover_building.is_constructed:
				return CursorType.BUILD

		# Hovering over enemy - attack cursor
		if hover_unit and is_instance_valid(hover_unit) and hover_unit.team != 0:
			return CursorType.ATTACK
		if hover_building and is_instance_valid(hover_building) and hover_building.team != 0:
			return CursorType.ATTACK

	# Military unit cursors
	if has_military:
		# Hovering over enemy unit
		if hover_unit and is_instance_valid(hover_unit) and hover_unit.team != 0:
			return CursorType.ATTACK

		# Hovering over enemy building
		if hover_building and is_instance_valid(hover_building) and hover_building.team != 0:
			return CursorType.ATTACK

	return CursorType.DEFAULT


func _set_cursor(cursor_type: CursorType) -> void:
	## Apply the cursor texture with appropriate hotspot
	current_cursor = cursor_type

	var texture: Texture2D
	var hotspot: Vector2

	match cursor_type:
		CursorType.DEFAULT:
			texture = CURSOR_DEFAULT
			hotspot = HOTSPOT_DEFAULT
		CursorType.ATTACK:
			texture = CURSOR_ATTACK
			hotspot = HOTSPOT_ATTACK
		CursorType.GATHER:
			texture = CURSOR_GATHER
			hotspot = HOTSPOT_GATHER
		CursorType.HAND:
			texture = CURSOR_HAND
			hotspot = HOTSPOT_HAND
		CursorType.BUILD:
			texture = CURSOR_BUILD
			hotspot = HOTSPOT_BUILD
		CursorType.FORBIDDEN:
			texture = CURSOR_FORBIDDEN
			hotspot = HOTSPOT_FORBIDDEN

	Input.set_custom_mouse_cursor(texture, Input.CURSOR_ARROW, hotspot)


func reset_cursor() -> void:
	## Reset to default cursor (call when game resets)
	_set_cursor(CursorType.DEFAULT)
