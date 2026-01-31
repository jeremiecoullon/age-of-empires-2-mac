extends Building
class_name Mill

func _ready() -> void:
	max_hp = 1000  # Set before super._ready() so it uses correct max
	super._ready()
	add_to_group("mills")
	building_name = "Mill"
	size = Vector2i(2, 2)
	wood_cost = 100
	build_time = 35.0
	accepts_resources.assign(["food"])
