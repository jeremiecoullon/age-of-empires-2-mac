extends Building
class_name ArcheryRange

# AoE2 spec: 175W cost, trains archers (25W, 45G) and skirmishers (25F, 35W)
const ARCHER_WOOD_COST: int = 25
const ARCHER_GOLD_COST: int = 45
const ARCHER_TRAIN_TIME: float = 6.0
const ARCHER_SCENE: PackedScene = preload("res://scenes/units/archer.tscn")

const SKIRMISHER_FOOD_COST: int = 25
const SKIRMISHER_WOOD_COST: int = 35
const SKIRMISHER_TRAIN_TIME: float = 5.0
const SKIRMISHER_SCENE: PackedScene = preload("res://scenes/units/skirmisher.tscn")

enum TrainingType { NONE, ARCHER, SKIRMISHER }

var is_training: bool = false
var train_timer: float = 0.0
var current_training: TrainingType = TrainingType.NONE
var spawn_point_offset: Vector2 = Vector2(0, 60)

signal training_started
signal training_completed
signal training_progress(progress: float)

func _ready() -> void:
	super._ready()
	add_to_group("archery_ranges")
	building_name = "Archery Range"
	size = Vector2i(3, 3)
	wood_cost = 175  # AoE2 spec

func _process(delta: float) -> void:
	if is_training:
		train_timer += delta
		training_progress.emit(train_timer / _get_current_train_time())

		if train_timer >= _get_current_train_time():
			_complete_training()

func _get_current_train_time() -> float:
	match current_training:
		TrainingType.ARCHER:
			return ARCHER_TRAIN_TIME
		TrainingType.SKIRMISHER:
			return SKIRMISHER_TRAIN_TIME
		_:
			return 1.0

func train_archer() -> bool:
	if is_training:
		return false

	# Check resources based on team
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
	current_training = TrainingType.ARCHER
	training_started.emit()
	return true

func train_skirmisher() -> bool:
	if is_training:
		return false

	# Check resources based on team
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
	current_training = TrainingType.SKIRMISHER
	training_started.emit()
	return true

func _complete_training() -> void:
	var scene: PackedScene = null

	match current_training:
		TrainingType.ARCHER:
			scene = ARCHER_SCENE
		TrainingType.SKIRMISHER:
			scene = SKIRMISHER_SCENE

	is_training = false
	train_timer = 0.0
	current_training = TrainingType.NONE

	if scene:
		var unit = scene.instantiate()
		unit.global_position = global_position + spawn_point_offset
		unit.team = team  # Inherit team from building
		get_parent().add_child(unit)
		GameManager.add_population(1, team)

	training_completed.emit()

func get_train_progress() -> float:
	if not is_training:
		return 0.0
	return train_timer / _get_current_train_time()
