extends Animal
class_name Boar

## Wild Boar are dangerous huntable animals that fight back when attacked.
## They deal high damage and should be lured to TC with multiple villagers.
## Classic AoE2 mechanic: one villager lures, others help kill near TC.

var target_attacker: Unit = null
const CHASE_GIVE_UP_DISTANCE: float = 400.0  # Stop chasing if attacker gets this far

func _ready() -> void:
	team = NEUTRAL_TEAM  # Wild animal
	food_amount = 340  # High food yield
	max_hp = 25
	current_hp = max_hp
	move_speed = 80.0  # Moderately fast
	wander_range = 80.0
	wander_interval = 10.0

	# Combat stats - boar are dangerous!
	is_aggressive = false  # Not aggressive until attacked
	attack_damage = 8  # High damage
	attack_range = 25.0
	attack_cooldown = 1.2
	aggro_range = 0  # Don't aggro on sight, only when attacked

	super._ready()
	add_to_group("boar")
	# 50 frames total, 8 directions = ~6 frames per direction
	_load_directional_animations("res://assets/sprites/units/boar_frames", "Boarstand", 50)

func take_damage(amount: int) -> void:
	super.take_damage(amount)

	# If still alive and not already attacking, find and attack nearby units
	if not is_dead and current_state != State.ATTACKING:
		_retaliate()

func _retaliate() -> void:
	# Find nearest unit to attack (the one that probably attacked us)
	var units = get_tree().get_nodes_in_group("units")
	var nearest: Unit = null
	var nearest_dist: float = 300.0  # Retaliation range

	for unit in units:
		if unit == self:
			continue
		if unit is Animal:
			continue
		if unit.is_dead:
			continue

		var dist = global_position.distance_to(unit.global_position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = unit

	if nearest:
		target_attacker = nearest
		_start_attacking(nearest)

func _process_attacking(delta: float) -> void:
	# Check if we should give up chase (target too far from where we started)
	if target_attacker and is_instance_valid(target_attacker):
		var dist_from_spawn = global_position.distance_to(spawn_position)
		if dist_from_spawn > CHASE_GIVE_UP_DISTANCE:
			# Give up and return to spawn area
			attack_target = null
			target_attacker = null
			current_state = State.IDLE
			nav_agent.target_position = spawn_position
			current_state = State.WANDERING
			return

	super._process_attacking(delta)
