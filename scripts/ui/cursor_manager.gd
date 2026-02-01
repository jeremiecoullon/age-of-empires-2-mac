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
##
## Uses sprite-based cursor rendering to work around macOS/Godot cursor API issues.

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

# Sprite-based cursor (workaround for macOS/Godot cursor API issues)
var _cursor_layer: CanvasLayer = null
var _cursor_sprite: Sprite2D = null

# Hotspot positions for cursors (where the "click point" is)
# Values scaled by 0.67 to match cursor sprite scale
const CURSOR_SCALE := 0.67
const HOTSPOT_DEFAULT := Vector2(0, 0) * CURSOR_SCALE     # Arrow tip at top-left
const HOTSPOT_ATTACK := Vector2(16, 0) * CURSOR_SCALE     # Sword tip at top-center
const HOTSPOT_GATHER := Vector2(12, 4) * CURSOR_SCALE     # Axe blade near top
const HOTSPOT_HAND := Vector2(8, 0) * CURSOR_SCALE        # Fingertip
const HOTSPOT_BUILD := Vector2(8, 4) * CURSOR_SCALE       # Hammer head near top
const HOTSPOT_FORBIDDEN := Vector2(16, 16) * CURSOR_SCALE # Center of circle

var _current_hotspot := Vector2.ZERO
var _cursor_over_ui := false

# Throttling for hover queries (avoid expensive group searches every frame)
const CURSOR_UPDATE_INTERVAL: float = 0.1  # 10 updates per second
var _cursor_update_timer: float = 0.0
var _cached_hover_unit: Node = null
var _cached_hover_building: Node = null
var _cached_hover_resource: Node = null
var _cached_hover_animal: Node = null


func _ready() -> void:
	# Create sprite-based cursor
	_setup_cursor_sprite()
	# Hide system cursor
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	# Set default cursor
	_set_cursor(CursorType.DEFAULT)


func _setup_cursor_sprite() -> void:
	## Create CanvasLayer and Sprite2D for cursor rendering
	_cursor_layer = CanvasLayer.new()
	_cursor_layer.layer = 100  # Render above everything
	add_child(_cursor_layer)

	_cursor_sprite = Sprite2D.new()
	_cursor_sprite.centered = false  # Position from top-left for hotspot math
	_cursor_sprite.scale = Vector2(CURSOR_SCALE, CURSOR_SCALE)  # Scale down cursors
	_cursor_layer.add_child(_cursor_sprite)


func _exit_tree() -> void:
	# Restore system cursor when this node is removed
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func initialize(main: Node2D) -> void:
	## Call this from main.gd to provide reference for position queries
	main_scene = main


func _process(delta: float) -> void:
	# Check if mouse is over UI elements
	var over_ui := _is_mouse_over_ui()
	if over_ui != _cursor_over_ui:
		_cursor_over_ui = over_ui
		_update_cursor_visibility()

	# Always update cursor sprite position to follow mouse
	_update_cursor_position()

	if not main_scene:
		return

	# Throttle hover cache updates to reduce group iteration costs
	_cursor_update_timer += delta
	if _cursor_update_timer >= CURSOR_UPDATE_INTERVAL:
		_cursor_update_timer = 0.0
		_update_hover_cache()

	_update_cursor()


func _is_mouse_over_ui() -> bool:
	## Check if mouse is hovering over a UI Control element
	var viewport = get_viewport()
	if not viewport:
		return false
	var hovered_control = viewport.gui_get_hovered_control()
	return hovered_control != null


func _update_cursor_visibility() -> void:
	## Show/hide sprite cursor based on whether mouse is over UI
	if _cursor_over_ui:
		# Over UI - show system cursor, hide sprite
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		if _cursor_sprite:
			_cursor_sprite.visible = false
	else:
		# Over game world - hide system cursor, show sprite
		Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
		if _cursor_sprite:
			_cursor_sprite.visible = true


func _update_cursor_position() -> void:
	## Update sprite position to follow mouse, accounting for hotspot
	if _cursor_sprite and _cursor_sprite.visible:
		var mouse_pos = get_viewport().get_mouse_position()
		_cursor_sprite.position = mouse_pos - _current_hotspot


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
			# Check resource type - wood uses axe cursor, others use hand
			var resource_type = hover_resource.get_resource_type() if hover_resource.has_method("get_resource_type") else ""
			if resource_type == "wood":
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
	## Apply the cursor texture to the sprite
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

	if texture == null:
		return

	_current_hotspot = hotspot
	if _cursor_sprite:
		_cursor_sprite.texture = texture


func reset_cursor() -> void:
	## Reset to default cursor (call when game resets)
	_set_cursor(CursorType.DEFAULT)
