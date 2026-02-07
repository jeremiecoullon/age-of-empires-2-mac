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

const MAX_QUEUE_SIZE: int = 15

enum TrainingType { NONE, ARCHER, SKIRMISHER }

var is_training: bool = false
var train_timer: float = 0.0
var current_training: TrainingType = TrainingType.NONE
var spawn_point_offset: Vector2 = Vector2(0, 60)
var training_queue: Array[int] = []

signal training_started
signal training_completed
signal training_progress(progress: float)
signal queue_changed(queue_size: int)

func _ready() -> void:
	super._ready()
	add_to_group("archery_ranges")
	building_name = "Archery Range"
	size = Vector2i(3, 3)
	wood_cost = 175  # AoE2 spec
	build_time = 50.0

func _process(delta: float) -> void:
	if is_researching:
		_process_research(delta)
		return  # Research blocks training
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
	if training_queue.size() >= MAX_QUEUE_SIZE:
		return false

	if not GameManager.can_add_population(team):
		return false
	if not GameManager.can_afford("wood", ARCHER_WOOD_COST, team):
		return false
	if not GameManager.can_afford("gold", ARCHER_GOLD_COST, team):
		return false

	GameManager.spend_resource("wood", ARCHER_WOOD_COST, team)
	GameManager.spend_resource("gold", ARCHER_GOLD_COST, team)

	training_queue.append(TrainingType.ARCHER)
	queue_changed.emit(training_queue.size())

	if not is_training:
		_start_next_training()
	return true

func train_skirmisher() -> bool:
	if training_queue.size() >= MAX_QUEUE_SIZE:
		return false

	if not GameManager.can_add_population(team):
		return false
	if not GameManager.can_afford("food", SKIRMISHER_FOOD_COST, team):
		return false
	if not GameManager.can_afford("wood", SKIRMISHER_WOOD_COST, team):
		return false

	GameManager.spend_resource("food", SKIRMISHER_FOOD_COST, team)
	GameManager.spend_resource("wood", SKIRMISHER_WOOD_COST, team)

	training_queue.append(TrainingType.SKIRMISHER)
	queue_changed.emit(training_queue.size())

	if not is_training:
		_start_next_training()
	return true

func cancel_training() -> bool:
	if training_queue.is_empty():
		return false

	var cancelled_type = training_queue.pop_back()
	queue_changed.emit(training_queue.size())

	match cancelled_type:
		TrainingType.ARCHER:
			GameManager.add_resource("wood", ARCHER_WOOD_COST, team)
			GameManager.add_resource("gold", ARCHER_GOLD_COST, team)
		TrainingType.SKIRMISHER:
			GameManager.add_resource("food", SKIRMISHER_FOOD_COST, team)
			GameManager.add_resource("wood", SKIRMISHER_WOOD_COST, team)

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
		TrainingType.ARCHER:
			scene = ARCHER_SCENE
		TrainingType.SKIRMISHER:
			scene = SKIRMISHER_SCENE

	if scene:
		var unit = scene.instantiate()
		unit.global_position = global_position + spawn_point_offset
		unit.team = team
		get_parent().add_child(unit)
		GameManager.add_population(1, team)

	training_completed.emit()

	if not training_queue.is_empty():
		_start_next_training()
	else:
		is_training = false
		train_timer = 0.0
		current_training = TrainingType.NONE

func _destroy() -> void:
	if is_researching:
		cancel_research()
	super._destroy()

func _complete_research() -> void:
	super._complete_research()
	if not training_queue.is_empty() and not is_training:
		_start_next_training()

func get_train_progress() -> float:
	if not is_training:
		return 0.0
	return train_timer / _get_current_train_time()

func get_queue_size() -> int:
	return training_queue.size()
