extends ResourceNode
class_name FoodCarcass

## A food carcass left behind when an animal dies.
## Decays over time, losing food until it disappears.

@export var decay_rate: float = 0.5  # Food lost per second
@export var decay_delay: float = 5.0  # Seconds before decay starts

var decay_timer: float = 0.0
var is_decaying: bool = false

func _ready() -> void:
	resource_type = "food"
	gather_rate = 1.0
	current_amount = total_amount
	initial_scale = sprite.scale if sprite else Vector2.ONE
	add_to_group("resources")
	add_to_group("food_resources")
	add_to_group("carcasses")

func _process(delta: float) -> void:
	# Delay before decay starts
	if not is_decaying:
		decay_timer += delta
		if decay_timer >= decay_delay:
			is_decaying = true
		return

	# Decay food over time
	var food_lost = decay_rate * delta
	current_amount -= food_lost

	if current_amount <= 0:
		current_amount = 0
		depleted.emit()
		queue_free()
	else:
		_update_visual()

func _update_visual() -> void:
	if sprite:
		var ratio = float(current_amount) / float(total_amount)
		# Scale down as food depletes
		var scale_factor = 0.3 + (ratio * 0.7)
		sprite.scale = initial_scale * scale_factor
		# Fade and turn grayish as it decays
		sprite.modulate = Color(0.8, 0.6, 0.5, 0.5 + (ratio * 0.5))
