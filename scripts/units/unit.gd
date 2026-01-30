extends CharacterBody2D
class_name Unit

const PLAYER_COLOR = Color(0.3, 0.5, 0.9, 1)  # Blue
const AI_COLOR = Color(0.9, 0.2, 0.2, 1)  # Red

# 8 directions in AoE sprite order: SW, W, NW, N, NE, E, SE, S
enum Direction { SW, W, NW, N, NE, E, SE, S }
const DIRECTION_NAMES = ["sw", "w", "nw", "n", "ne", "e", "se", "s"]

# Cache for loaded SpriteFrames to avoid repeated file I/O
static var _sprite_frames_cache: Dictionary = {}

@export var move_speed: float = 100.0
@export var max_hp: int = 100
@export var team: int = 0  # 0 = player, 1 = AI
@export var melee_armor: int = 0  # Reduces melee damage
@export var pierce_armor: int = 0  # Reduces pierce/ranged damage

@onready var nav_agent: NavigationAgent2D = $NavigationAgent2D
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var selection_indicator: Sprite2D = $SelectionIndicator

var is_selected: bool = false
var current_hp: int
var is_dead: bool = false
var current_direction: int = Direction.S  # Default facing south

signal died

func _ready() -> void:
	add_to_group("units")
	current_hp = max_hp
	nav_agent.path_desired_distance = 4.0
	nav_agent.target_desired_distance = 4.0
	selection_indicator.visible = false
	_apply_team_color()

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

	velocity = direction * move_speed
	move_and_slide()
	_update_facing_direction()

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
func take_damage(amount: int, attack_type: String = "melee", bonus_damage: int = 0) -> void:
	var armor = melee_armor if attack_type == "melee" else pierce_armor
	var base_damage = max(1, amount - armor)  # Minimum 1 damage
	var final_damage = base_damage + bonus_damage
	current_hp -= final_damage
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
