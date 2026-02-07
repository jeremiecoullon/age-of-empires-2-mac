extends Building
class_name PalisadeWall

func _ready() -> void:
	max_hp = 250
	super._ready()
	add_to_group("palisade_walls")
	add_to_group("walls")
	building_name = "Palisade Wall"
	size = Vector2i(1, 1)
	wood_cost = 2
	build_time = 5.0
	sight_range = 64.0  # 2 tiles
