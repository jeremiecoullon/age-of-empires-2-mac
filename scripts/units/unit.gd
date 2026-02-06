extends CharacterBody2D
class_name Unit

const PLAYER_COLOR = Color(0.3, 0.5, 0.9, 1)  # Blue
const AI_COLOR = Color(0.9, 0.2, 0.2, 1)  # Red

# 8 directions in AoE sprite order: SW, W, NW, N, NE, E, SE, S
enum Direction { SW, W, NW, N, NE, E, SE, S }
const DIRECTION_NAMES = ["sw", "w", "nw", "n", "ne", "e", "se", "s"]

# Combat stances - affects auto-attack behavior
enum Stance { AGGRESSIVE, DEFENSIVE, STAND_GROUND, NO_ATTACK }

# Cache for loaded SpriteFrames to avoid repeated file I/O
static var _sprite_frames_cache: Dictionary = {}

@export var move_speed: float = 100.0
@export var max_hp: int = 100
@export var team: int = 0  # 0 = player, 1 = AI
@export var melee_armor: int = 0  # Reduces melee damage
@export var pierce_armor: int = 0  # Reduces pierce/ranged damage
@export var sight_range: float = 128.0  # How far unit can see (for auto-aggro), ~4 tiles

var stance: int = Stance.AGGRESSIVE  # Default stance for all units

@onready var nav_agent: NavigationAgent2D = $NavigationAgent2D
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var selection_indicator: Sprite2D = $SelectionIndicator

var is_selected: bool = false
var current_hp: int
var is_dead: bool = false
var current_direction: int = Direction.S  # Default facing south

signal died
signal damaged(amount: int, attacker: Node2D)  # Emitted when unit takes damage

func _ready() -> void:
	add_to_group("units")
	current_hp = max_hp
	nav_agent.path_desired_distance = 4.0
	nav_agent.target_desired_distance = 4.0
	nav_agent.target_position = global_position  # Prevent flying to (0,0) on spawn
	nav_agent.avoidance_enabled = false  # Disable until _resume_movement(); prevents avoidance push before first _physics_process
	selection_indicator.visible = false
	_apply_team_color()
	# Connect to attack notification system
	damaged.connect(_on_damaged_for_notification)
	# Connect to avoidance velocity computed signal for pathfinding around other units
	nav_agent.velocity_computed.connect(_on_velocity_computed)

func _apply_team_color() -> void:
	if sprite:
		if team == 0:
			sprite.modulate = PLAYER_COLOR
		else:
			sprite.modulate = AI_COLOR

## Load 8-directional animation frames from a folder. Expects numbered files like "Prefix001.png".
## total_frames: Total number of frames in the folder (will be divided by 8 for frames per direction).
## fps: Animation playback speed (default 8 FPS).
func _load_directional_animations(folder_path: String, prefix: String, total_frames: int, fps: float = 8.0) -> void:
	if not sprite:
		return

	# Use cached SpriteFrames if available (avoids repeated file I/O)
	var cache_key = folder_path + "_" + prefix + "_8dir"
	if _sprite_frames_cache.has(cache_key):
		sprite.sprite_frames = _sprite_frames_cache[cache_key]
		_play_direction_animation()
		return

	var sprite_frames = SpriteFrames.new()
	sprite_frames.remove_animation("default")  # Remove auto-created default animation

	# Load all frames from folder
	var dir = DirAccess.open(folder_path)
	if not dir:
		push_warning("Could not open animation folder: " + folder_path)
		return

	var files: Array[String] = []
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".png") and file_name.begins_with(prefix):
			files.append(file_name)
		file_name = dir.get_next()
	dir.list_dir_end()

	files.sort()

	if files.size() == 0:
		push_warning("No frames found in: " + folder_path)
		return

	# Load all textures
	var textures: Array[Texture2D] = []
	for f in files:
		var texture = load(folder_path + "/" + f)
		if texture:
			textures.append(texture)

	# Calculate frames per direction (integer division - extra frames beyond 8*n are unused)
	var frames_per_dir = textures.size() / 8
	if frames_per_dir == 0:
		push_warning("Not enough frames for 8 directions in: " + folder_path + " (found " + str(textures.size()) + " frames)")
		return

	# Create animation for each direction
	for dir_idx in range(8):
		var anim_name = "idle_" + DIRECTION_NAMES[dir_idx]
		sprite_frames.add_animation(anim_name)
		sprite_frames.set_animation_loop(anim_name, true)
		sprite_frames.set_animation_speed(anim_name, fps)

		# Add frames for this direction
		var start_frame = dir_idx * frames_per_dir
		var end_frame = start_frame + frames_per_dir
		for i in range(start_frame, end_frame):
			if i < textures.size():
				sprite_frames.add_frame(anim_name, textures[i])

	_sprite_frames_cache[cache_key] = sprite_frames  # Cache for reuse
	sprite.sprite_frames = sprite_frames
	_play_direction_animation()

## Load a static sprite (single image) as a 1-frame animation.
## Used for units with SVG placeholders instead of 8-dir animations.
## scale_factor: Scale to apply to the sprite (default 0.5 for 64px SVGs).
func _load_static_sprite(texture: Texture2D, scale_factor: float = 0.5) -> void:
	if not sprite or not texture:
		return
	var sprite_frames = SpriteFrames.new()
	sprite_frames.remove_animation("default")
	sprite_frames.add_animation("idle")
	sprite_frames.set_animation_loop("idle", true)
	sprite_frames.add_frame("idle", texture)
	sprite.sprite_frames = sprite_frames
	sprite.play("idle")
	sprite.scale = Vector2(scale_factor, scale_factor)

## Legacy single-direction loader (for units without 8-dir sprites)
func _load_animation_frames(folder_path: String, prefix: String, frame_step: int = 5, fps: float = 8.0) -> void:
	if not sprite:
		return

	var cache_key = folder_path + "_" + prefix + "_" + str(frame_step)
	if _sprite_frames_cache.has(cache_key):
		sprite.sprite_frames = _sprite_frames_cache[cache_key]
		sprite.play("idle")
		return

	var sprite_frames = SpriteFrames.new()
	sprite_frames.remove_animation("default")
	sprite_frames.add_animation("idle")
	sprite_frames.set_animation_loop("idle", true)
	sprite_frames.set_animation_speed("idle", fps)

	var dir = DirAccess.open(folder_path)
	if not dir:
		push_warning("Could not open animation folder: " + folder_path)
		return

	var files: Array[String] = []
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".png") and file_name.begins_with(prefix):
			files.append(file_name)
		file_name = dir.get_next()
	dir.list_dir_end()

	files.sort()

	var frame_count = 0
	for i in range(0, files.size(), frame_step):
		var texture = load(folder_path + "/" + files[i])
		if texture:
			sprite_frames.add_frame("idle", texture)
			frame_count += 1

	if frame_count > 0:
		_sprite_frames_cache[cache_key] = sprite_frames
		sprite.sprite_frames = sprite_frames
		sprite.play("idle")
	else:
		push_warning("No frames loaded from: " + folder_path)

func _physics_process(delta: float) -> void:
	if nav_agent.is_navigation_finished():
		return

	var current_position = global_position
	var next_path_position = nav_agent.get_next_path_position()
	var direction = current_position.direction_to(next_path_position)

	var desired_velocity = direction * move_speed

	# Use avoidance to path around other units
	if nav_agent.avoidance_enabled:
		nav_agent.set_velocity(desired_velocity)
	else:
		velocity = desired_velocity
		move_and_slide()
		_update_facing_direction()

## Called when avoidance velocity is computed - use safe velocity for movement
func _on_velocity_computed(safe_velocity: Vector2) -> void:
	if not nav_agent.avoidance_enabled:
		return  # Ignore stale callbacks when unit should be stationary
	velocity = safe_velocity
	move_and_slide()
	_update_facing_direction()

## Apply movement with avoidance support. Subclasses should call this instead of directly
## setting velocity and calling move_and_slide() when they want avoidance.
## When avoidance is enabled, nav_agent.set_velocity triggers _on_velocity_computed synchronously.
func _apply_movement(desired_velocity: Vector2) -> void:
	if nav_agent.avoidance_enabled:
		nav_agent.set_velocity(desired_velocity)
		# The callback _on_velocity_computed is called synchronously and handles move_and_slide
	else:
		velocity = desired_velocity
		move_and_slide()
		_update_facing_direction()

## Stop movement completely and prevent avoidance from pushing us around.
## Call this when the unit should be stationary (attacking in range, gathering, etc.)
func _stop_and_stay() -> void:
	velocity = Vector2.ZERO
	nav_agent.target_position = global_position  # Clear navigation target
	nav_agent.avoidance_enabled = false  # Disable avoidance while stationary

## Re-enable avoidance before moving. Call this before _apply_movement() when resuming movement.
func _resume_movement() -> void:
	nav_agent.avoidance_enabled = true

## Get direction index (0-7) from velocity vector
## Returns current_direction if velocity is too small
func _get_direction_from_velocity(vel: Vector2) -> int:
	if vel.length_squared() < 1.0:
		return current_direction

	# Get angle in radians. atan2(y, x) gives angle from positive X axis
	# In Godot: +X is right, +Y is down
	var angle = vel.angle()

	# Convert angle to 0-TAU range
	if angle < 0:
		angle += TAU

	# Divide circle into 8 sectors (each 45 degrees = PI/4 radians)
	# Add PI/8 offset so sector boundaries fall between directions
	var adjusted = angle + PI / 8
	if adjusted >= TAU:
		adjusted -= TAU

	var sector = int(adjusted / (PI / 4)) % 8

	# Map from angle-based sector to AoE direction order
	#
	# Angle sectors (from +X axis, clockwise):    AoE sprite order (facing direction):
	#            N (6)                                    N (3)
	#      NW(5)   NE(7)                            NW(2)   NE(4)
	#    W(4) --+-- E(0)                          W(1) --+-- E(5)
	#      SW(3)   SE(1)                            SW(0)   SE(6)
	#            S (2)                                    S (7)
	#
	# When moving E (sector 0), unit should face E (direction 5), etc.
	const ANGLE_SECTOR_TO_AOE = [1, 2, 3, 4, 5, 6, 7, 0]
	return ANGLE_SECTOR_TO_AOE[sector]

## Update sprite animation based on current velocity direction
func _update_facing_direction() -> void:
	var new_dir = _get_direction_from_velocity(velocity)
	if new_dir != current_direction:
		current_direction = new_dir
		_play_direction_animation()

## Play the animation for the current direction
func _play_direction_animation() -> void:
	if not sprite or not sprite.sprite_frames:
		return
	var anim_name = "idle_" + DIRECTION_NAMES[current_direction]
	if sprite.sprite_frames.has_animation(anim_name):
		sprite.play(anim_name)
	elif sprite.sprite_frames.has_animation("idle"):
		# Fallback for single-direction sprites
		sprite.play("idle")

func move_to(target_position: Vector2) -> void:
	nav_agent.target_position = target_position

func set_selected(selected: bool) -> void:
	is_selected = selected
	selection_indicator.visible = selected

func stop_movement() -> void:
	nav_agent.target_position = global_position

## Take damage with armor calculation.
## attack_type: "melee" or "pierce" - determines which armor applies
## bonus_damage: Extra damage that ignores armor (e.g., spearman vs cavalry)
## attacker: The node that dealt the damage (optional, for notification/response)
func take_damage(amount: int, attack_type: String = "melee", bonus_damage: int = 0, attacker: Node2D = null) -> void:
	var armor = melee_armor if attack_type == "melee" else pierce_armor
	var base_damage = max(1, amount - armor)  # Minimum 1 damage
	var final_damage = base_damage + bonus_damage
	current_hp -= final_damage
	damaged.emit(final_damage, attacker)
	if current_hp <= 0:
		die()

func die() -> void:
	if is_dead:
		return  # Prevent double-death
	is_dead = true
	died.emit()
	if is_selected:
		GameManager.deselect_unit(self)
	GameManager.remove_population(1, team)
	queue_free()

## Called when this unit takes damage - notifies GameManager for attack alerts
func _on_damaged_for_notification(amount: int, attacker: Node2D) -> void:
	GameManager.notify_unit_damaged(self, amount, attacker)

## Set the unit's combat stance
func set_stance(new_stance: int) -> void:
	stance = new_stance

## Find nearest enemy unit within sight range. Returns null if none found.
## Only finds units that can be attacked (not same team, not dead).
func find_enemy_in_sight() -> Unit:
	if stance == Stance.NO_ATTACK:
		return null  # Never auto-attack in NO_ATTACK stance

	var units = get_tree().get_nodes_in_group("units")
	var nearest: Unit = null
	var nearest_dist: float = sight_range

	for unit in units:
		if unit == self:
			continue
		if unit.team == team:
			continue  # Same team
		if unit.is_dead:
			continue
		if unit is Animal:
			continue  # Don't auto-attack animals

		var dist = global_position.distance_to(unit.global_position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = unit

	return nearest

## Find nearest enemy building within sight range. Returns null if none found.
func find_enemy_building_in_sight() -> Building:
	if stance == Stance.NO_ATTACK:
		return null

	var buildings = get_tree().get_nodes_in_group("buildings")
	var nearest: Building = null
	var nearest_dist: float = sight_range

	for building in buildings:
		if building.team == team:
			continue
		if building.is_destroyed:
			continue

		var dist = global_position.distance_to(building.global_position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = building

	return nearest
