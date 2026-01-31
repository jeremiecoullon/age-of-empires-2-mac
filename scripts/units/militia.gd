extends Unit
class_name Militia

enum State { IDLE, MOVING, ATTACKING }

@export var attack_damage: int = 5
@export var attack_range: float = 30.0
@export var attack_cooldown: float = 1.0

var current_state: State = State.IDLE
var attack_target: Node2D = null  # Can be Unit or Building
var attack_timer: float = 0.0
var aggro_check_timer: float = 0.0
const AGGRO_CHECK_INTERVAL: float = 0.3  # Check for enemies every 0.3 sec
var original_position: Vector2 = Vector2.ZERO  # For DEFENSIVE stance distance limit
const DEFENSIVE_CHASE_RANGE: float = 200.0  # Max chase distance for DEFENSIVE stance

func _ready() -> void:
	super._ready()
	add_to_group("military")
	add_to_group("infantry")
	max_hp = 50
	current_hp = max_hp
	# 30 frames total, 8 directions = ~4 frames per direction
	_load_directional_animations("res://assets/sprites/units/militia_frames", "Militiastand", 30)

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
		return  # Never auto-attack

	aggro_check_timer += delta
	if aggro_check_timer < AGGRO_CHECK_INTERVAL:
		return
	aggro_check_timer = 0.0

	# Find enemy in sight
	var enemy = find_enemy_in_sight()
	if enemy:
		# For STAND_GROUND, only attack if already in range
		if stance == Stance.STAND_GROUND:
			var dist = global_position.distance_to(enemy.global_position)
			if dist <= attack_range:
				command_attack(enemy)
		else:
			# AGGRESSIVE or DEFENSIVE - chase and attack
			original_position = global_position  # Remember where we started
			command_attack(enemy)

func _process_moving(delta: float) -> void:
	# Use NavigationAgent2D for proper pathfinding
	if nav_agent.is_navigation_finished():
		current_state = State.IDLE
		velocity = Vector2.ZERO
		return

	var next_path_position = nav_agent.get_next_path_position()
	var direction = global_position.direction_to(next_path_position)
	_apply_movement(direction * move_speed)

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
		# Check stance restrictions on movement
		if stance == Stance.STAND_GROUND:
			# Don't move, give up attack if target moved out of range
			attack_target = null
			current_state = State.IDLE
			velocity = Vector2.ZERO
			return

		if stance == Stance.DEFENSIVE and original_position != Vector2.ZERO:
			# Check if we've chased too far from original position
			var dist_from_origin = global_position.distance_to(original_position)
			if dist_from_origin > DEFENSIVE_CHASE_RANGE:
				# Give up chase and return
				attack_target = null
				current_state = State.IDLE
				velocity = Vector2.ZERO
				return

		# Move closer to target using nav_agent
		nav_agent.target_position = attack_target.global_position
		var next_path_position = nav_agent.get_next_path_position()
		var direction = global_position.direction_to(next_path_position)
		_apply_movement(direction * move_speed)
		# Don't increment attack timer when out of range
		return

	# In range, stop and attack
	velocity = Vector2.ZERO
	attack_timer += delta

	if attack_timer >= attack_cooldown:
		attack_timer = 0.0
		attack_target.take_damage(attack_damage, "melee", 0, self)

func command_attack(target: Node2D) -> void:
	attack_target = target
	current_state = State.ATTACKING
	attack_timer = 0.0

func move_to(target_position: Vector2) -> void:
	attack_target = null
	current_state = State.MOVING
	nav_agent.target_position = target_position
