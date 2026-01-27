extends Building
class_name House

const POPULATION_BONUS: int = 5

func _ready() -> void:
	super._ready()
	add_to_group("houses")
	building_name = "House"
	size = Vector2i(2, 2)
	wood_cost = 25
	GameManager.increase_population_cap(POPULATION_BONUS, team)
