extends Building
class_name Outpost

func _ready() -> void:
	max_hp = 500
	super._ready()
	add_to_group("outposts")
	building_name = "Outpost"
	size = Vector2i(1, 1)
	wood_cost = 25
	stone_cost = 25
	build_time = 15.0
	sight_range = 320.0  # 10 tiles - main purpose is LOS
