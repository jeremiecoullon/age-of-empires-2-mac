extends Building
class_name StoneWall

func _ready() -> void:
	max_hp = 1800
	melee_armor = 8
	pierce_armor = 10
	building_name = "Stone Wall"
	size = Vector2i(1, 1)
	stone_cost = 5
	build_time = 10.0
	sight_range = 64.0  # 2 tiles
	super._ready()
	add_to_group("stone_walls")
	add_to_group("walls")
