extends Unit
class_name BatteringRam

## Battering Ram - slow melee siege unit that excels at destroying buildings.
## AoE2 spec: 160W + 75G cost, 175 HP, 2 attack, 0/180 armor, +125 vs buildings
## Can garrison up to 4 infantry to increase speed (not implemented yet).
## Only attacks buildings and siege units — ignores other units.

enum State { IDLE, MOVING, ATTACKING }

@export var attack_damage: int = 2
@export var attack_range: float = 30.0
@export var attack_cooldown: float = 2.0
@export var bonus_vs_buildings: int = 125

var current_state: State = State.IDLE
var attack_target: Node2D = null  # Can be Building or siege Unit
var attack_timer: float = 0.0

# Ram garrison system
var garrisoned_infantry: Array = []
const RAM_GARRISON_CAPACITY: int = 4

func _ready() -> void:
	super._ready()
	add_to_group("military")
	add_to_group("siege")
	add_to_group("battering_rams")
	max_hp = 175
	current_hp = max_hp
	move_speed = 50.0  # Very slow
	melee_armor = 0
	pierce_armor = 180  # Nearly immune to arrows
	_load_animation_frames("res://assets/sprites/units/battering_ram_frames", "Batteringramstand", 1)
	_apply_researched_upgrades()
	_store_base_stats()
	apply_tech_bonuses()

func _store_base_stats() -> void:
	super._store_base_stats()
	_base_attack_damage = attack_damage

func apply_tech_bonuses() -> void:
	# Siege units don't benefit from Blacksmith — only call super for base armor/HP
	super.apply_tech_bonuses()

func _physics_process(delta: float) -> void:
	match current_state:
		State.IDLE:
			_stop_and_stay()
		State.MOVING:
			_process_moving(delta)
		State.ATTACKING:
			_process_attacking(delta)

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
		var bonus = bonus_vs_buildings if attack_target is Building else 0
		attack_target.take_damage(attack_damage, "melee", bonus, self)

func command_attack(target: Node2D) -> void:
	# Rams only attack buildings and siege units
	if target is Building:
		attack_target = target
		current_state = State.ATTACKING
		attack_timer = 0.0
	elif target is Unit and target.is_in_group("siege"):
		attack_target = target
		current_state = State.ATTACKING
		attack_timer = 0.0
	# Ignore other targets silently

func move_to(target_position: Vector2) -> void:
	attack_target = null
	current_state = State.MOVING
	nav_agent.target_position = target_position

# No auto-aggro on units — rams are passive unless commanded
# Override find_enemy_in_sight to return null
func find_enemy_in_sight() -> Unit:
	return null

# ===== RAM GARRISON SYSTEM =====

func can_garrison_in_ram(unit: Node) -> bool:
	if garrisoned_infantry.size() >= RAM_GARRISON_CAPACITY:
		return false
	if unit.team != team:
		return false
	if unit.is_dead:
		return false
	if unit.is_garrisoned():
		return false
	# Only infantry (not cavalry, not siege, not trade carts)
	if not unit.is_in_group("infantry"):
		return false
	return true

func garrison_in_ram(unit: Node) -> bool:
	if not can_garrison_in_ram(unit):
		return false
	garrisoned_infantry.append(unit)
	# Same hide/disable pattern as building garrison
	unit.garrisoned_in = self
	unit._stop_and_stay()
	if unit.is_selected:
		GameManager.deselect_unit(unit)
	unit.visible = false
	unit.process_mode = Node.PROCESS_MODE_DISABLED
	var collision = unit.get_node_or_null("CollisionShape2D")
	if collision:
		collision.set_deferred("disabled", true)
	return true

func ungarrison_all_from_ram() -> void:
	var units_to_eject = garrisoned_infantry.duplicate()
	for i in range(units_to_eject.size()):
		var unit = units_to_eject[i]
		if is_instance_valid(unit):
			garrisoned_infantry.erase(unit)
			unit.garrisoned_in = null
			unit.visible = true
			unit.process_mode = Node.PROCESS_MODE_INHERIT
			var collision = unit.get_node_or_null("CollisionShape2D")
			if collision:
				collision.set_deferred("disabled", false)
			# Position around the ram
			var angle = TAU * i / max(units_to_eject.size(), 1)
			var offset = Vector2(40, 0).rotated(angle)
			unit.global_position = global_position + offset
	garrisoned_infantry.clear()

func get_garrisoned_count() -> int:
	return garrisoned_infantry.size()

func die() -> void:
	if is_dead:
		return
	# Eject garrisoned infantry before dying
	ungarrison_all_from_ram()
	super.die()
