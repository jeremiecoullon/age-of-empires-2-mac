extends Building
class_name ArcheryRange

const ARCHER_WOOD_COST: int = 25
const ARCHER_GOLD_COST: int = 45
const SKIRMISHER_FOOD_COST: int = 25
const SKIRMISHER_WOOD_COST: int = 35
const TRAIN_TIME: float = 4.0
const ARCHER_SCENE: PackedScene = preload("res://scenes/units/archer.tscn")
const SKIRMISHER_SCENE: PackedScene = preload("res://scenes/units/skirmisher.tscn")

enum TrainingType { NONE, ARCHER, SKIRMISHER }

var is_training: bool = false
var train_timer: float = 0.0
var training_type: TrainingType = TrainingType.NONE
var spawn_point_offset: Vector2 = Vector2(0, 60)

signal training_started
signal training_completed
signal training_progress(progress: float)

func _ready() -> void:
	super._ready()
	add_to_group("archery_ranges")
	building_name = "Archery Range"
	size = Vector2i(3, 3)
	wood_cost = 175
	max_hp = 1500
	current_hp = max_hp

func _process(delta: float) -> void:
	if is_training:
		train_timer += delta
		training_progress.emit(train_timer / TRAIN_TIME)

		if train_timer >= TRAIN_TIME:
			_complete_training()

func train_archer() -> bool:
	if is_training:
		return false

	if not GameManager.can_add_population(team):
		return false
	if not GameManager.can_afford("wood", ARCHER_WOOD_COST, team):
		return false
	if not GameManager.can_afford("gold", ARCHER_GOLD_COST, team):
		return false

	GameManager.spend_resource("wood", ARCHER_WOOD_COST, team)
	GameManager.spend_resource("gold", ARCHER_GOLD_COST, team)

	is_training = true
	train_timer = 0.0
	training_type = TrainingType.ARCHER
	training_started.emit()
	return true

func train_skirmisher() -> bool:
	if is_training:
		return false

	if not GameManager.can_add_population(team):
		return false
	if not GameManager.can_afford("food", SKIRMISHER_FOOD_COST, team):
		return false
	if not GameManager.can_afford("wood", SKIRMISHER_WOOD_COST, team):
		return false

	GameManager.spend_resource("food", SKIRMISHER_FOOD_COST, team)
	GameManager.spend_resource("wood", SKIRMISHER_WOOD_COST, team)

	is_training = true
	train_timer = 0.0
	training_type = TrainingType.SKIRMISHER
	training_started.emit()
	return true

func _complete_training() -> void:
	var unit_scene: PackedScene
	match training_type:
		TrainingType.ARCHER:
			unit_scene = ARCHER_SCENE
		TrainingType.SKIRMISHER:
			unit_scene = SKIRMISHER_SCENE
		_:
			is_training = false
			train_timer = 0.0
			training_type = TrainingType.NONE
			return

	var unit = unit_scene.instantiate()
	unit.global_position = global_position + spawn_point_offset
	unit.team = team
	get_parent().add_child(unit)
	GameManager.add_population(1, team)

	is_training = false
	train_timer = 0.0
	training_type = TrainingType.NONE
	training_completed.emit()

func get_train_progress() -> float:
	if not is_training:
		return 0.0
	return train_timer / TRAIN_TIME
