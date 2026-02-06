extends Building
class_name Barracks

# Militia: 60F + 20W (originally 60F + 20G in AoE2, but we use wood for MVP)
const MILITIA_FOOD_COST: int = 60
const MILITIA_WOOD_COST: int = 20
const MILITIA_TRAIN_TIME: float = 4.0
const MILITIA_SCENE: PackedScene = preload("res://scenes/units/militia.tscn")

# Spearman: 35F + 25W
const SPEARMAN_FOOD_COST: int = 35
const SPEARMAN_WOOD_COST: int = 25
const SPEARMAN_TRAIN_TIME: float = 5.0
const SPEARMAN_SCENE: PackedScene = preload("res://scenes/units/spearman.tscn")

const MAX_QUEUE_SIZE: int = 15

enum TrainingType { NONE, MILITIA, SPEARMAN }

var is_training: bool = false
var train_timer: float = 0.0
var current_training: TrainingType = TrainingType.NONE
var spawn_point_offset: Vector2 = Vector2(0, 60)
var training_queue: Array[int] = []  # Array of TrainingType values

signal training_started
signal training_completed
signal training_progress(progress: float)
signal queue_changed(queue_size: int)

func _ready() -> void:
	super._ready()
	add_to_group("barracks")
	building_name = "Barracks"
	size = Vector2i(3, 3)
	wood_cost = 100
	build_time = 50.0

func _process(delta: float) -> void:
	if is_training:
		train_timer += delta
		training_progress.emit(train_timer / _get_current_train_time())

		if train_timer >= _get_current_train_time():
			_complete_training()

func _get_current_train_time() -> float:
	match current_training:
		TrainingType.MILITIA:
			return MILITIA_TRAIN_TIME
		TrainingType.SPEARMAN:
			return SPEARMAN_TRAIN_TIME
		_:
			return 1.0

func train_militia() -> bool:
	if training_queue.size() >= MAX_QUEUE_SIZE:
		return false

	if not GameManager.can_add_population(team):
		return false
	if not GameManager.can_afford("food", MILITIA_FOOD_COST, team):
		return false
	if not GameManager.can_afford("wood", MILITIA_WOOD_COST, team):
		return false

	GameManager.spend_resource("food", MILITIA_FOOD_COST, team)
	GameManager.spend_resource("wood", MILITIA_WOOD_COST, team)

	training_queue.append(TrainingType.MILITIA)
	queue_changed.emit(training_queue.size())

	if not is_training:
		_start_next_training()
	return true

func train_spearman() -> bool:
	if training_queue.size() >= MAX_QUEUE_SIZE:
		return false

	if not GameManager.can_add_population(team):
		return false
	if not GameManager.can_afford("food", SPEARMAN_FOOD_COST, team):
		return false
	if not GameManager.can_afford("wood", SPEARMAN_WOOD_COST, team):
		return false

	GameManager.spend_resource("food", SPEARMAN_FOOD_COST, team)
	GameManager.spend_resource("wood", SPEARMAN_WOOD_COST, team)

	training_queue.append(TrainingType.SPEARMAN)
	queue_changed.emit(training_queue.size())

	if not is_training:
		_start_next_training()
	return true

func cancel_training() -> bool:
	if training_queue.is_empty():
		return false

	var cancelled_type = training_queue.pop_back()
	queue_changed.emit(training_queue.size())

	# Refund resources
	match cancelled_type:
		TrainingType.MILITIA:
			GameManager.add_resource("food", MILITIA_FOOD_COST, team)
			GameManager.add_resource("wood", MILITIA_WOOD_COST, team)
		TrainingType.SPEARMAN:
			GameManager.add_resource("food", SPEARMAN_FOOD_COST, team)
			GameManager.add_resource("wood", SPEARMAN_WOOD_COST, team)

	if training_queue.is_empty():
		is_training = false
		train_timer = 0.0
		current_training = TrainingType.NONE

	return true

func _start_next_training() -> void:
	if training_queue.is_empty():
		is_training = false
		current_training = TrainingType.NONE
		return

	current_training = training_queue[0] as TrainingType
	is_training = true
	train_timer = 0.0
	training_started.emit()

func _complete_training() -> void:
	if training_queue.is_empty():
		is_training = false
		train_timer = 0.0
		current_training = TrainingType.NONE
		return

	# Check population cap at spawn time (may have filled since queue time)
	# If pop-capped, hold timer and retry next frame (AoE2 pauses training at cap)
	if not GameManager.can_add_population(team):
		train_timer = _get_current_train_time()
		return

	var completed_type = training_queue.pop_front()
	queue_changed.emit(training_queue.size())

	var scene: PackedScene = null
	match completed_type:
		TrainingType.MILITIA:
			scene = MILITIA_SCENE
		TrainingType.SPEARMAN:
			scene = SPEARMAN_SCENE

	if scene:
		var unit = scene.instantiate()
		unit.global_position = global_position + spawn_point_offset
		unit.team = team
		get_parent().add_child(unit)
		GameManager.add_population(1, team)

	training_completed.emit()

	# Start next training if queue not empty
	if not training_queue.is_empty():
		_start_next_training()
	else:
		is_training = false
		train_timer = 0.0
		current_training = TrainingType.NONE

func get_train_progress() -> float:
	if not is_training:
		return 0.0
	return train_timer / _get_current_train_time()

func get_queue_size() -> int:
	return training_queue.size()
