extends Building
class_name House

const POPULATION_BONUS: int = 5

func _ready() -> void:
	super._ready()
	add_to_group("houses")
	building_name = "House"
	size = Vector2i(2, 2)
	wood_cost = 25
	build_time = 25.0  # 25 seconds with 1 villager
	# Only increase pop cap if building is constructed (not under construction)
	if is_constructed:
		GameManager.increase_population_cap(POPULATION_BONUS, team)
	else:
		# Connect to construction completed signal
		construction_completed.connect(_on_construction_completed)

func _on_construction_completed() -> void:
	GameManager.increase_population_cap(POPULATION_BONUS, team)
