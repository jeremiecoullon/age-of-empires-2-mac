extends Building
class_name Stable

# AoE2 spec: 175W cost, 1500 HP, trains cavalry units
const SCOUT_CAVALRY_FOOD_COST: int = 80
const SCOUT_CAVALRY_TRAIN_TIME: float = 6.0
const SCOUT_CAVALRY_SCENE: PackedScene = preload("res://scenes/units/scout_cavalry.tscn")

const CAVALRY_ARCHER_WOOD_COST: int = 40
const CAVALRY_ARCHER_GOLD_COST: int = 70
const CAVALRY_ARCHER_TRAIN_TIME: float = 7.0
const CAVALRY_ARCHER_SCENE: PackedScene = preload("res://scenes/units/cavalry_archer.tscn")

# Knight will be added in Phase 4

enum TrainingType { NONE, SCOUT_CAVALRY, CAVALRY_ARCHER }

var is_training: bool = false
var train_timer: float = 0.0
var current_training: TrainingType = TrainingType.NONE
var spawn_point_offset: Vector2 = Vector2(0, 60)

signal training_started
signal training_completed
signal training_progress(progress: float)

func _ready() -> void:
	max_hp = 1500  # AoE2 spec - set before super to ensure current_hp is correct
	super._ready()
	add_to_group("stables")
	building_name = "Stable"
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
		TrainingType.SCOUT_CAVALRY:
			return SCOUT_CAVALRY_TRAIN_TIME
		TrainingType.CAVALRY_ARCHER:
			return CAVALRY_ARCHER_TRAIN_TIME
		_:
			return 1.0

func train_scout_cavalry() -> bool:
	if is_training:
		return false

	# Check resources based on team
	if not GameManager.can_add_population(team):
		return false
	if not GameManager.can_afford("food", SCOUT_CAVALRY_FOOD_COST, team):
		return false

	GameManager.spend_resource("food", SCOUT_CAVALRY_FOOD_COST, team)

	is_training = true
	train_timer = 0.0
	current_training = TrainingType.SCOUT_CAVALRY
	training_started.emit()
	return true

func train_cavalry_archer() -> bool:
	if is_training:
		return false

	# Check resources based on team
	if not GameManager.can_add_population(team):
		return false
	if not GameManager.can_afford("wood", CAVALRY_ARCHER_WOOD_COST, team):
		return false
	if not GameManager.can_afford("gold", CAVALRY_ARCHER_GOLD_COST, team):
		return false

	GameManager.spend_resource("wood", CAVALRY_ARCHER_WOOD_COST, team)
	GameManager.spend_resource("gold", CAVALRY_ARCHER_GOLD_COST, team)

	is_training = true
	train_timer = 0.0
	current_training = TrainingType.CAVALRY_ARCHER
	training_started.emit()
	return true

func _complete_training() -> void:
	var scene: PackedScene = null

	match current_training:
		TrainingType.SCOUT_CAVALRY:
			scene = SCOUT_CAVALRY_SCENE
		TrainingType.CAVALRY_ARCHER:
			scene = CAVALRY_ARCHER_SCENE

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
