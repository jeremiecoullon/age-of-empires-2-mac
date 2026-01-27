extends Animal
class_name Wolf

## Wolves are hostile animals that attack units on sight.
## They yield no food - purely an environmental hazard.

func _ready() -> void:
	team = NEUTRAL_TEAM  # Wild animal
	food_amount = 0  # No food!
	max_hp = 25
	current_hp = max_hp
	move_speed = 100.0  # Fast predator
	wander_range = 200.0
	wander_interval = 4.0

	# Combat stats
	is_aggressive = true  # Attack on sight!
	attack_damage = 5
	attack_range = 25.0
	attack_cooldown = 1.0
	aggro_range = 180.0  # Detect from fairly far

	super._ready()
	add_to_group("wolves")
