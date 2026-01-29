extends Unit
class_name Skirmisher

enum State { IDLE, MOVING, ATTACKING }

@export var attack_damage: int = 2
@export var attack_range: float = 128.0  # 4 tiles * 32 pixels
@export var attack_cooldown: float = 2.0
@export var bonus_vs_archers: int = 3  # Extra damage vs archer-type units

var current_state: State = State.IDLE
var attack_target: Node2D = null  # Can be Unit or Building
var attack_timer: float = 0.0

func _ready() -> void:
	super._ready()
	add_to_group("military")
	add_to_group("skirmishers")
	max_hp = 30
	current_hp = max_hp
	move_speed = 90.0  # Medium speed
	# Apply team color to static sprite (SVG)
	_apply_static_sprite_color()

func _apply_static_sprite_color() -> void:
	if has_node("Sprite2D"):
		var static_sprite = get_node("Sprite2D")
		if team == 0:
			static_sprite.modulate = PLAYER_COLOR
		else:
			static_sprite.modulate = AI_COLOR

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
		# Move closer to target using nav_agent
		nav_agent.target_position = attack_target.global_position
		var next_path_position = nav_agent.get_next_path_position()
		var direction = global_position.direction_to(next_path_position)
		velocity = direction * move_speed
		move_and_slide()
		_update_facing_direction()
		return

	# In range - stop and attack
	velocity = Vector2.ZERO

	# Face the target
	var to_target = attack_target.global_position - global_position
	var new_dir = _get_direction_from_velocity(to_target)
	if new_dir != current_direction:
		current_direction = new_dir
		_play_direction_animation()

	attack_timer += delta

	if attack_timer >= attack_cooldown:
		attack_timer = 0.0
		_perform_attack()

func _perform_attack() -> void:
	if not is_instance_valid(attack_target):
		return

	var damage = attack_damage

	# Bonus damage vs archers (including cavalry archers)
	if attack_target is Unit and attack_target.is_in_group("archers"):
		damage += bonus_vs_archers

	# Skirmishers are weak vs buildings (half damage)
	if attack_target is Building:
		damage = max(1, attack_damage / 2)

	attack_target.take_damage(damage)

func command_attack(target: Node2D) -> void:
	attack_target = target
	current_state = State.ATTACKING
	attack_timer = 0.0

func move_to(target_position: Vector2) -> void:
	attack_target = null
	current_state = State.MOVING
	nav_agent.target_position = target_position
