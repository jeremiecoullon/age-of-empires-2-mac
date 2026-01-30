extends Unit
class_name Archer

enum State { IDLE, MOVING, ATTACKING }

# AoE2 spec: 25W, 45G, 30 HP, 4 attack, range 4 tiles
@export var attack_damage: int = 4
@export var attack_range: float = 128.0  # ~4 tiles at 32px/tile
@export var attack_cooldown: float = 2.0

# Preload texture to avoid runtime file I/O
const ARCHER_TEXTURE: Texture2D = preload("res://assets/sprites/units/archer.svg")

var current_state: State = State.IDLE
var attack_target: Node2D = null  # Can be Unit or Building
var attack_timer: float = 0.0

func _ready() -> void:
	super._ready()
	add_to_group("military")
	add_to_group("archers")
	max_hp = 30
	current_hp = max_hp
	move_speed = 96.0  # Slightly slower than militia
	# Use single SVG for now (no 8-dir sprites available)
	_load_static_sprite(ARCHER_TEXTURE)

func _load_static_sprite(texture: Texture2D) -> void:
	if not sprite or not texture:
		return
	if texture:
		var sprite_frames = SpriteFrames.new()
		sprite_frames.remove_animation("default")
		sprite_frames.add_animation("idle")
		sprite_frames.set_animation_loop("idle", true)
		sprite_frames.add_frame("idle", texture)
		sprite.sprite_frames = sprite_frames
		sprite.play("idle")
		sprite.scale = Vector2(0.5, 0.5)  # Scale down 64px SVG

func _physics_process(delta: float) -> void:
	match current_state:
		State.IDLE:
			velocity = Vector2.ZERO
		State.MOVING:
			_process_moving(delta)
		State.ATTACKING:
			_process_attacking(delta)

func _process_moving(delta: float) -> void:
	if nav_agent.is_navigation_finished():
		current_state = State.IDLE
		velocity = Vector2.ZERO
		return

	var next_path_position = nav_agent.get_next_path_position()
	var direction = global_position.direction_to(next_path_position)
	velocity = direction * move_speed
	move_and_slide()
	_update_facing_direction()

func _process_attacking(delta: float) -> void:
	if not is_instance_valid(attack_target):
		attack_target = null
		current_state = State.IDLE
		return

	# Check if target is dead/destroyed
	if attack_target is Unit:
		if attack_target.is_dead or attack_target.current_hp <= 0:
			attack_target = null
			current_state = State.IDLE
			return
	elif attack_target is Building:
		if attack_target.is_destroyed or attack_target.current_hp <= 0:
			attack_target = null
			current_state = State.IDLE
			return

	var distance = global_position.distance_to(attack_target.global_position)

	if distance > attack_range:
		# Move closer to get in range
		nav_agent.target_position = attack_target.global_position
		var next_path_position = nav_agent.get_next_path_position()
		var direction = global_position.direction_to(next_path_position)
		velocity = direction * move_speed
		move_and_slide()
		_update_facing_direction()
		return

	# In range - stop and attack (ranged, no need to be adjacent)
	velocity = Vector2.ZERO
	attack_timer += delta

	if attack_timer >= attack_cooldown:
		attack_timer = 0.0
		_fire_at_target()

func _fire_at_target() -> void:
	# For now, instant hit (hitscan). Projectile visuals can be added in Phase 9.
	if is_instance_valid(attack_target):
		attack_target.take_damage(attack_damage)

func command_attack(target: Node2D) -> void:
	attack_target = target
	current_state = State.ATTACKING
	attack_timer = 0.0

func move_to(target_position: Vector2) -> void:
	attack_target = null
	current_state = State.MOVING
	nav_agent.target_position = target_position
