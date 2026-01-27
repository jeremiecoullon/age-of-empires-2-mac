extends Building
class_name Barracks

const MILITIA_FOOD_COST: int = 60
const MILITIA_WOOD_COST: int = 20
const TRAIN_TIME: float = 4.0
const MILITIA_SCENE_PATH: String = "res://scenes/units/militia.tscn"

var is_training: bool = false
var train_timer: float = 0.0
var spawn_point_offset: Vector2 = Vector2(0, 60)

signal training_started
signal training_completed
signal training_progress(progress: float)

func _ready() -> void:
	super._ready()
	add_to_group("barracks")
	building_name = "Barracks"
	size = Vector2i(3, 3)
	wood_cost = 100

func _process(delta: float) -> void:
	if is_training:
		train_timer += delta
		training_progress.emit(train_timer / TRAIN_TIME)

		if train_timer >= TRAIN_TIME:
			_complete_training()

func train_militia() -> bool:
	if is_training:
		return false

	# Check resources based on team
	if team == 0:
		if not GameManager.can_add_population():
			return false
		if not GameManager.can_afford_food(MILITIA_FOOD_COST):
			return false
		if not GameManager.can_afford_wood(MILITIA_WOOD_COST):
			return false
		GameManager.spend_food(MILITIA_FOOD_COST)
		GameManager.spend_wood(MILITIA_WOOD_COST)
	else:
		if not GameManager.ai_can_add_population():
			return false
		if not GameManager.ai_can_afford_food(MILITIA_FOOD_COST):
			return false
		if not GameManager.ai_can_afford_wood(MILITIA_WOOD_COST):
			return false
		GameManager.ai_spend_food(MILITIA_FOOD_COST)
		GameManager.ai_spend_wood(MILITIA_WOOD_COST)

	is_training = true
	train_timer = 0.0
	training_started.emit()
	return true

func _complete_training() -> void:
	is_training = false
	train_timer = 0.0

	var militia_scene = load(MILITIA_SCENE_PATH)
	if militia_scene:
		var militia = militia_scene.instantiate()
		militia.global_position = global_position + spawn_point_offset
		militia.team = team  # Inherit team from barracks
		get_parent().add_child(militia)
		# Team color handled by Unit._ready()
		if team == 0:
			GameManager.add_population(1)
		else:
			GameManager.ai_add_population(1)

	training_completed.emit()

func get_train_progress() -> float:
	if not is_training:
		return 0.0
	return train_timer / TRAIN_TIME
