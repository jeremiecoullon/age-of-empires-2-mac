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

func take_damage(amount: int) -> void:
	# Store position of attacker before taking damage
	# We'll use our current position since we don't have direct attacker reference
	last_attacker_position = global_position

	super.take_damage(amount)

	# Flee if still alive
	if not is_dead and current_state != State.FLEEING:
		_flee_from_danger()

func _flee_from_danger() -> void:
	# Flee in a random direction away from where damage came from
	# Since we don't know exact attacker position, flee in a random direction
	var flee_direction = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
	var flee_distance = 250.0
	var flee_target = global_position + flee_direction * flee_distance

	# Clamp to map bounds
	flee_target.x = clamp(flee_target.x, 50, 1870)
	flee_target.y = clamp(flee_target.y, 50, 1870)

	nav_agent.target_position = flee_target
	current_state = State.FLEEING
