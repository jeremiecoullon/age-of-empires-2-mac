extends Unit
class_name Animal

## Base class for all animals (sheep, deer, boar, wolves).
## Animals wander, can be killed, and drop food carcasses.

const FOOD_CARCASS_SCENE = preload("res://scenes/resources/food_carcass.tscn")
const NEUTRAL_TEAM: int = -1  # Unowned animals

enum State { IDLE, WANDERING, FLEEING, ATTACKING }

@export var food_amount: int = 100  # Food dropped as carcass when killed
@export var wander_range: float = 100.0  # How far to wander from spawn
@export var wander_interval: float = 5.0  # Seconds between wander moves
@export var is_aggressive: bool = false  # Wolves attack, others don't
@export var aggro_range: float = 150.0  # Range to detect enemies (for aggressive animals)

var current_state: State = State.IDLE
var spawn_position: Vector2 = Vector2.ZERO
var wander_timer: float = 0.0
var aggro_timer: float = 0.0  # Throttle aggro checks for performance
var flee_target: Vector2 = Vector2.ZERO
var attack_target: Unit = null

const AGGRO_CHECK_INTERVAL: float = 0.5  # Check for enemies every 0.5 seconds

# For aggressive animals
@export var attack_damage: int = 5
@export var attack_range: float = 30.0
@export var attack_cooldown: float = 1.5
var attack_timer: float = 0.0

func _ready() -> void:
	super._ready()
	add_to_group("animals")
	spawn_position = global_position
	# Animals are not counted in population (Unit._ready() doesn't add population)

	# Start with random wander timer to desync animals
	wander_timer = randf() * wander_interval

func _physics_process(delta: float) -> void:
	match current_state:
		State.IDLE:
			_process_idle(delta)
		State.WANDERING:
			_process_wandering(delta)
		State.FLEEING:
			_process_fleeing(delta)
		State.ATTACKING:
			_process_attacking(delta)

func _process_idle(delta: float) -> void:
	_stop_and_stay()

	# Check for aggro if aggressive (throttled for performance)
	if is_aggressive:
		aggro_timer += delta
		if aggro_timer >= AGGRO_CHECK_INTERVAL:
			aggro_timer = 0.0
			var target = _find_nearby_enemy()
			if target:
				_start_attacking(target)
				return

	# Wander occasionally
	wander_timer += delta
	if wander_timer >= wander_interval:
		wander_timer = 0.0
		_start_wandering()

func _process_wandering(delta: float) -> void:
	if nav_agent.is_navigation_finished():
		current_state = State.IDLE
		return

	var next_path_position = nav_agent.get_next_path_position()
	var direction = global_position.direction_to(next_path_position)
	_resume_movement()
	_apply_movement(direction * move_speed)

func _process_fleeing(delta: float) -> void:
	if nav_agent.is_navigation_finished():
		current_state = State.IDLE
		return

	var next_path_position = nav_agent.get_next_path_position()
	var direction = global_position.direction_to(next_path_position)
	_resume_movement()
	_apply_movement(direction * move_speed)

func _process_attacking(delta: float) -> void:
	if not is_instance_valid(attack_target) or attack_target.is_dead:
		attack_target = null
		current_state = State.IDLE
		return

	var distance = global_position.distance_to(attack_target.global_position)

	if distance > attack_range:
		# Chase target
		nav_agent.target_position = attack_target.global_position
		var next_path_position = nav_agent.get_next_path_position()
		var direction = global_position.direction_to(next_path_position)
		_resume_movement()
		_apply_movement(direction * move_speed)
		return

	# In range, attack
	_stop_and_stay()
	attack_timer += delta

	if attack_timer >= attack_cooldown:
		attack_timer = 0.0
		attack_target.take_damage(attack_damage, "melee", 0, self)

func _start_wandering() -> void:
	# Pick random point within wander_range of spawn
	var angle = randf() * TAU
	var distance = randf() * wander_range
	var target = spawn_position + Vector2(cos(angle), sin(angle)) * distance

	# Clamp to map bounds
	target.x = clamp(target.x, 50, 1870)
	target.y = clamp(target.y, 50, 1870)

	nav_agent.target_position = target
	current_state = State.WANDERING

func _start_attacking(target: Unit) -> void:
	attack_target = target
	current_state = State.ATTACKING
	attack_timer = 0.0

func _find_nearby_enemy() -> Unit:
	var units = get_tree().get_nodes_in_group("units")
	var nearest: Unit = null
	var nearest_dist: float = aggro_range

	for unit in units:
		if unit == self:
			continue
		if unit is Animal:
			continue  # Don't attack other animals
		if unit.is_dead:
			continue

		var dist = global_position.distance_to(unit.global_position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = unit

	return nearest

## Called when animal takes damage - override for flee/aggro behavior
func on_damaged(attacker: Node2D) -> void:
	pass  # Subclasses override this

func take_damage(amount: int, attack_type: String = "melee", bonus_damage: int = 0, attacker: Node2D = null) -> void:
	super.take_damage(amount, attack_type, bonus_damage, attacker)
	# Notify subclass about damage (for flee/aggro behavior)
	on_damaged(attacker)

func die() -> void:
	if is_dead:
		return
	is_dead = true

	# Spawn food carcass if we have food
	if food_amount > 0:
		_spawn_carcass()

	died.emit()
	if is_selected:
		GameManager.deselect_unit(self)
	# Don't remove population - animals aren't in population
	queue_free()

func _spawn_carcass() -> void:
	var carcass = FOOD_CARCASS_SCENE.instantiate()
	carcass.global_position = global_position
	carcass.total_amount = food_amount
	carcass.current_amount = food_amount

	# Add to the main scene - find Resources container or use parent
	var main = get_tree().current_scene
	if main and main.has_node("Resources"):
		main.get_node("Resources").add_child(carcass)
	else:
		get_parent().add_child(carcass)

## Flee from a position (used by deer when attacked)
func flee_from(threat_position: Vector2) -> void:
	var direction = global_position.direction_to(threat_position).rotated(PI)  # Opposite direction
	var flee_distance = 200.0
	flee_target = global_position + direction * flee_distance

	# Clamp to map bounds
	flee_target.x = clamp(flee_target.x, 50, 1870)
	flee_target.y = clamp(flee_target.y, 50, 1870)

	nav_agent.target_position = flee_target
	current_state = State.FLEEING

func _apply_team_color() -> void:
	if sprite:
		if team == NEUTRAL_TEAM:
			sprite.modulate = Color(1, 1, 1, 1)  # White/neutral
		elif team == 0:
			sprite.modulate = PLAYER_COLOR
		else:
			sprite.modulate = AI_COLOR
