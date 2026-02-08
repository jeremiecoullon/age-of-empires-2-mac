extends Unit
class_name Mangonel

## Mangonel - ranged siege unit with area damage and minimum range.
## AoE2 spec: 160W + 135G, 50 HP, 40 attack, 0/6 armor, range 7 tiles, min range 3 tiles
## Deals area splash damage including friendly fire.

enum State { IDLE, MOVING, ATTACKING }

@export var attack_damage: int = 40
@export var attack_range: float = 224.0  # 7 tiles at 32px/tile
@export var attack_cooldown: float = 6.0
@export var min_range: float = 96.0  # 3 tiles minimum range

const SPLASH_RADIUS: float = 48.0  # Area of effect radius
const SPLASH_DAMAGE_RATIO: float = 0.5  # 50% damage to splash targets

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
	add_to_group("mangonels")
	max_hp = 50
	current_hp = max_hp
	move_speed = 60.0
	melee_armor = 0
	pierce_armor = 6
	_load_animation_frames("res://assets/sprites/units/mangonel_frames", "Mangonelstand", 1)
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
		# Check minimum range
		var dist = global_position.distance_to(enemy.global_position)
		if dist < min_range:
			return  # Too close, can't fire
		if stance == Stance.STAND_GROUND:
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

	# Minimum range check — if too close, stop attacking
	if distance < min_range:
		_stop_and_stay()
		return  # Stay idle, don't try to move away

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
		_fire_area_attack()

func _fire_area_attack() -> void:
	if not is_instance_valid(attack_target):
		return

	var target_pos = attack_target.global_position

	# Full damage to primary target
	attack_target.take_damage(attack_damage, "pierce", 0, self)

	# Splash damage to all units and buildings within radius (including friendlies!)
	for unit in get_tree().get_nodes_in_group("units"):
		if unit == attack_target:
			continue  # Already hit
		if unit.is_dead:
			continue
		if unit == self:
			continue  # Don't hit self
		if unit.global_position.distance_to(target_pos) <= SPLASH_RADIUS:
			var splash_dmg = int(attack_damage * SPLASH_DAMAGE_RATIO)
			unit.take_damage(splash_dmg, "pierce", 0, self)

	for building in get_tree().get_nodes_in_group("buildings"):
		if building == attack_target:
			continue  # Already hit
		if building.is_destroyed:
			continue
		if building.global_position.distance_to(target_pos) <= SPLASH_RADIUS:
			var splash_dmg = int(attack_damage * SPLASH_DAMAGE_RATIO)
			building.take_damage(splash_dmg, "pierce", 0, self)

func command_attack(target: Node2D) -> void:
	attack_target = target
	current_state = State.ATTACKING
	attack_timer = 0.0

func move_to(target_position: Vector2) -> void:
	attack_target = null
	current_state = State.MOVING
	nav_agent.target_position = target_position
