extends Building
class_name Farm

# Farm provides infinite food at a slower gather rate
@export var gather_rate: float = 0.5  # per second (slower than natural resources)
var resource_type: String = "food"

func _ready() -> void:
	super._ready()
	add_to_group("farms")
	add_to_group("resources")  # So villagers can target it
	add_to_group("food_resources")  # So AI can find farms when assigning food gatherers
	building_name = "Farm"
	size = Vector2i(2, 2)
	wood_cost = 50
	build_time = 15.0

# Resource node interface for villagers
func harvest(amount: int) -> int:
	# Farms provide infinite food (only when constructed)
	if not is_functional():
		return 0
	return amount

func get_resource_type() -> String:
	return resource_type

func has_resources() -> bool:
	# Farms always have resources (infinite) but only when constructed
	return is_functional()
