extends Unit
class_name Scorpion

## Scorpion - ranged siege unit with pass-through bolt damage.
## AoE2 spec: 75W + 75G, 40 HP, 12 attack, 0/6 armor, range 5 tiles
## Bolt passes through primary target and damages enemies along the line.

enum State { IDLE, MOVING, ATTACKING }

@export var attack_damage: int = 12
@export var attack_range: float = 160.0  # 5 tiles at 32px/tile
@export var attack_cooldown: float = 3.5

const PASS_THROUGH_EXTEND: float = 100.0  # How far bolt extends past target
const PASS_THROUGH_WIDTH: float = 20.0  # Half-width of bolt hit area

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
	add_to_group("siege")
	add_to_group("scorpions")
	max_hp = 40
	current_hp = max_hp
	move_speed = 60.0
	melee_armor = 0
	pierce_armor = 6
	_load_animation_frames("res://assets/sprites/units/scorpion_frames", "Scorpionstand", 1)
	_apply_researched_upgrades()
	_store_base_stats()
	apply_tech_bonuses()

func _store_base_stats() -> void:
	super._store_base_stats()
	_base_attack_damage = attack_damage
	_base_attack_range = attack_range

func apply_tech_bonuses() -> void:
	# Siege units don't benefit from Blacksmith — only call super for base armor/HP
	super.apply_tech_bonuses()

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

		# Move closer to get in range
		nav_agent.target_position = attack_target.global_position
		var next_path_position = nav_agent.get_next_path_position()
		var direction = global_position.direction_to(next_path_position)
		_resume_movement()
		_apply_movement(direction * move_speed)
		return

	# In range - stop and attack
	_stop_and_stay()
	attack_timer += delta

	if attack_timer >= attack_cooldown:
		attack_timer = 0.0
		_fire_pass_through()

func _fire_pass_through() -> void:
	if not is_instance_valid(attack_target):
		return

	var target_pos = attack_target.global_position
	var direction = global_position.direction_to(target_pos)
	var bolt_end = target_pos + direction * PASS_THROUGH_EXTEND

	# Full damage to primary target
	attack_target.take_damage(attack_damage, "pierce", 0, self)

	# Pass-through: damage enemy units along the bolt line (no friendly fire)
	for unit in get_tree().get_nodes_in_group("units"):
		if unit == attack_target:
			continue  # Already hit
		if unit.is_dead:
			continue
		if unit == self:
			continue
		if unit.team == team:
			continue  # No friendly fire for scorpion
		if _point_near_line_segment(unit.global_position, global_position, bolt_end, PASS_THROUGH_WIDTH):
			unit.take_damage(attack_damage, "pierce", 0, self)

	# Also check enemy buildings along the line
	for building in get_tree().get_nodes_in_group("buildings"):
		if building == attack_target:
			continue
		if building.is_destroyed:
			continue
		if building.team == team:
			continue
		if _point_near_line_segment(building.global_position, global_position, bolt_end, PASS_THROUGH_WIDTH):
			building.take_damage(attack_damage, "pierce", 0, self)

func _point_near_line_segment(point: Vector2, line_start: Vector2, line_end: Vector2, max_dist: float) -> bool:
	## Returns true if point is within max_dist of the line segment from line_start to line_end.
	var line_vec = line_end - line_start
	var line_len_sq = line_vec.length_squared()
	if line_len_sq == 0:
		return point.distance_to(line_start) <= max_dist

	# Project point onto line, clamped to segment
	var t = clampf((point - line_start).dot(line_vec) / line_len_sq, 0.0, 1.0)
	var closest = line_start + line_vec * t
	return point.distance_to(closest) <= max_dist

func command_attack(target: Node2D) -> void:
	attack_target = target
	current_state = State.ATTACKING
	attack_timer = 0.0

func move_to(target_position: Vector2) -> void:
	attack_target = null
	current_state = State.MOVING
	nav_agent.target_position = target_position
