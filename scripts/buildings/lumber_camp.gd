extends Building
class_name LumberCamp

func _ready() -> void:
	super._ready()
	add_to_group("lumber_camps")
	building_name = "Lumber Camp"
	size = Vector2i(2, 2)
	wood_cost = 100
	max_hp = 1000
	current_hp = max_hp
	accepts_resources = ["wood"]
