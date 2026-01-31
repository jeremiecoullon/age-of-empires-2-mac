extends Unit
class_name Skirmisher

## Skirmisher - cheap anti-archer ranged unit.
## AoE2 spec: 25F + 35W cost, 30 HP, 2 attack, 0/3 armor, range 4, +3 bonus vs archers

enum State { IDLE, MOVING, ATTACKING }

@export var attack_damage: int = 2
@export var attack_range: float = 128.0  # ~4 tiles at 32px/tile
@export var attack_cooldown: float = 2.0
@export var bonus_vs_archers: int = 3  # Extra damage vs archer group

const SKIRMISHER_TEXTURE: Texture2D = preload("res://assets/sprites/units/skirmisher.svg")

var current_state: State = State.IDLE
var attack_target: Node2D = null  # Can be Unit or Building
var attack_timer: float = 0.0
var aggro_check_timer: float = 0.0
const AGGRO_CHECK_INTERVAL: float = 0.3
var original_position: Vector2 = Vector2.ZERO
const DEFENSIVE_CHASE_RANGE: float = 200.0

func _ready() -> void:
	super._ready()
	add_to_group("military")
	add_to_group("archers")  # Counts as archer-type for targeting
	max_hp = 30
	current_hp = max_hp
	move_speed = 96.0
	melee_armor = 0
	pierce_armor = 3  # High pierce armor - resists arrows
	if SKIRMISHER_TEXTURE:
		_load_static_sprite(SKIRMISHER_TEXTURE)

func _load_static_sprite(texture: Texture2D) -> void:
	if not sprite or not texture:
		return
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
			_check_auto_aggro(delta)
		State.MOVING:
			_process_moving(delta)
		State.ATTACKING:
			_process_attacking(delta)

func _check_auto_aggro(delta: float) -> void:
	if stance == Stance.NO_ATTACK:
		return

	aggro_check_timer += delta
	if aggro_check_timer < AGGRO_CHECK_INTERVAL:
		return
	aggro_check_timer = 0.0

	var enemy = find_enemy_in_sight()
	if enemy:
		if stance == Stance.STAND_GROUND:
			var dist = global_position.distance_to(enemy.global_position)
			if dist <= attack_range:
				command_attack(enemy)
		else:
			original_position = global_position
			command_attack(enemy)

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
		# Check stance restrictions
		if stance == Stance.STAND_GROUND:
			attack_target = null
			current_state = State.IDLE
			velocity = Vector2.ZERO
			return

		if stance == Stance.DEFENSIVE and original_position != Vector2.ZERO:
			var dist_from_origin = global_position.distance_to(original_position)
			if dist_from_origin > DEFENSIVE_CHASE_RANGE:
				attack_target = null
				current_state = State.IDLE
				velocity = Vector2.ZERO
				return

		# Move closer to get in range
		nav_agent.target_position = attack_target.global_position
		var next_path_position = nav_agent.get_next_path_position()
		var direction = global_position.direction_to(next_path_position)
		velocity = direction * move_speed
		move_and_slide()
		_update_facing_direction()
		return

	# In range - stop and attack
	velocity = Vector2.ZERO
	attack_timer += delta

	if attack_timer >= attack_cooldown:
		attack_timer = 0.0
		_fire_at_target()

func _fire_at_target() -> void:
	if not is_instance_valid(attack_target):
		return

	var bonus = 0
	# Apply bonus damage vs archers
	if attack_target is Unit and attack_target.is_in_group("archers"):
		bonus = bonus_vs_archers

	attack_target.take_damage(attack_damage, "pierce", bonus, self)

func command_attack(target: Node2D) -> void:
	attack_target = target
	current_state = State.ATTACKING
	attack_timer = 0.0

func move_to(target_position: Vector2) -> void:
	attack_target = null
	current_state = State.MOVING
	nav_agent.target_position = target_position
