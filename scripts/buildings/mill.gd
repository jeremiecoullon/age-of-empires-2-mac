extends Building
class_name Mill

func _ready() -> void:
	super._ready()
	add_to_group("mills")
	building_name = "Mill"
	size = Vector2i(2, 2)
	wood_cost = 100
	max_hp = 1000
	current_hp = max_hp
	accepts_resources = ["food"]
