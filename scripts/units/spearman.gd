extends Unit
class_name Spearman

## Spearman - cheap anti-cavalry infantry.
## AoE2 spec: 35F + 25W cost, 45 HP, 3 attack, 0/0 armor, +15 bonus vs cavalry

enum State { IDLE, MOVING, ATTACKING }

@export var attack_damage: int = 3
@export var attack_range: float = 30.0
@export var attack_cooldown: float = 2.0
@export var bonus_vs_cavalry: int = 15  # Extra damage vs cavalry group

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
	add_to_group("infantry")
	add_to_group("spearmen")
	max_hp = 45
	current_hp = max_hp
	move_speed = 96.0  # Same as archer, slower than militia
	melee_armor = 0
	pierce_armor = 0
	_load_directional_animations("res://assets/sprites/units/spearman_frames", "Spearmanstand", 45)
	_apply_researched_upgrades()
	_store_base_stats()
	apply_tech_bonuses()

func _store_base_stats() -> void:
	super._store_base_stats()
	_base_attack_damage = attack_damage

func apply_tech_bonuses() -> void:
	super.apply_tech_bonuses()
	attack_damage = _base_attack_damage + GameManager.get_tech_bonus("infantry_attack", team)

func _physics_process(delta: float) -> void:
	match current_state:
		State.IDLE:
			_stop_and_stay()
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
		return

	var next_path_position = nav_agent.get_next_path_position()
	var direction = global_position.direction_to(next_path_position)
	_resume_movement()
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
		# Check stance restrictions
		if stance == Stance.STAND_GROUND:
			attack_target = null
			current_state = State.IDLE
			return

		if stance == Stance.DEFENSIVE and original_position != Vector2.ZERO:
			var dist_from_origin = global_position.distance_to(original_position)
			if dist_from_origin > DEFENSIVE_CHASE_RANGE:
				attack_target = null
				current_state = State.IDLE
				return

		# Move closer to target using nav_agent
		nav_agent.target_position = attack_target.global_position
		var next_path_position = nav_agent.get_next_path_position()
		var direction = global_position.direction_to(next_path_position)
		_resume_movement()
		_apply_movement(direction * move_speed)
		return

	# In range, stop and attack
	_stop_and_stay()
	attack_timer += delta

	if attack_timer >= attack_cooldown:
		attack_timer = 0.0
		_deal_damage()

func _deal_damage() -> void:
	if not is_instance_valid(attack_target):
		return

	var bonus = 0
	# Apply bonus damage vs cavalry
	if attack_target is Unit and attack_target.is_in_group("cavalry"):
		bonus = bonus_vs_cavalry

	attack_target.take_damage(attack_damage, "melee", bonus, self)

func command_attack(target: Node2D) -> void:
	attack_target = target
	current_state = State.ATTACKING
	attack_timer = 0.0

func move_to(target_position: Vector2) -> void:
	attack_target = null
	current_state = State.MOVING
	nav_agent.target_position = target_position
