extends Animal
class_name Deer

## Deer are huntable animals that flee when attacked.
## Villagers must chase and kill them to get food.

var last_attacker_position: Vector2 = Vector2.ZERO

func _ready() -> void:
	team = NEUTRAL_TEAM  # Wild animal
	food_amount = 140
	max_hp = 5
	current_hp = max_hp
	move_speed = 120.0  # Fast when fleeing
	wander_range = 150.0
	wander_interval = 6.0
	is_aggressive = false

	super._ready()
	add_to_group("deer")
	# 25 frames total, 8 directions = ~3 frames per direction
	_load_directional_animations("res://assets/sprites/units/deer_frames", "Deerstand", 25)

func take_damage(amount: int, attack_type: String = "melee", bonus_damage: int = 0, attacker: Node2D = null) -> void:
	# Store position of attacker before taking damage (keep as ZERO if no attacker)
	if is_instance_valid(attacker):
		last_attacker_position = attacker.global_position
	# Don't set to global_position - leave as ZERO so _flee_from_danger uses random direction

	super.take_damage(amount, attack_type, bonus_damage, attacker)

	# Flee if still alive
	if not is_dead and current_state != State.FLEEING:
		_flee_from_danger()

func _flee_from_danger() -> void:
	# Flee away from the attacker position
	var flee_direction: Vector2
	if last_attacker_position != Vector2.ZERO:
		# Flee away from attacker
		flee_direction = global_position.direction_to(last_attacker_position).rotated(PI)
	else:
		# No attacker known, flee in random direction
		flee_direction = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()

	var flee_distance = 250.0
	var flee_target_pos = global_position + flee_direction * flee_distance

	# Clamp to map bounds
	flee_target_pos.x = clamp(flee_target_pos.x, 50, 1870)
	flee_target_pos.y = clamp(flee_target_pos.y, 50, 1870)

	nav_agent.target_position = flee_target_pos
	current_state = State.FLEEING
