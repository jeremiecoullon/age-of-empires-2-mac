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

const KNIGHT_FOOD_COST: int = 60
const KNIGHT_GOLD_COST: int = 75
const KNIGHT_TRAIN_TIME: float = 6.0
const KNIGHT_SCENE: PackedScene = preload("res://scenes/units/knight.tscn")

const MAX_QUEUE_SIZE: int = 15

enum TrainingType { NONE, SCOUT_CAVALRY, CAVALRY_ARCHER, KNIGHT }

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
	max_hp = 1500  # AoE2 spec - set before super to ensure current_hp is correct
	super._ready()
	add_to_group("stables")
	building_name = "Stable"
	size = Vector2i(3, 3)
	wood_cost = 175  # AoE2 spec
	build_time = 50.0
	garrison_capacity = 10

func _process(delta: float) -> void:
	if is_functional():
		_process_garrison_healing(delta)
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
		TrainingType.SCOUT_CAVALRY:
			return SCOUT_CAVALRY_TRAIN_TIME
		TrainingType.CAVALRY_ARCHER:
			return CAVALRY_ARCHER_TRAIN_TIME
		TrainingType.KNIGHT:
			return KNIGHT_TRAIN_TIME
		_:
			return 1.0

func train_scout_cavalry() -> bool:
	if training_queue.size() >= MAX_QUEUE_SIZE:
		return false

	if not GameManager.can_add_population(team):
		return false
	if not GameManager.can_afford("food", SCOUT_CAVALRY_FOOD_COST, team):
		return false

	GameManager.spend_resource("food", SCOUT_CAVALRY_FOOD_COST, team)

	training_queue.append(TrainingType.SCOUT_CAVALRY)
	queue_changed.emit(training_queue.size())

	if not is_training:
		_start_next_training()
	return true

func train_cavalry_archer() -> bool:
	if training_queue.size() >= MAX_QUEUE_SIZE:
		return false

	if not GameManager.can_add_population(team):
		return false
	if not GameManager.can_afford("wood", CAVALRY_ARCHER_WOOD_COST, team):
		return false
	if not GameManager.can_afford("gold", CAVALRY_ARCHER_GOLD_COST, team):
		return false

	GameManager.spend_resource("wood", CAVALRY_ARCHER_WOOD_COST, team)
	GameManager.spend_resource("gold", CAVALRY_ARCHER_GOLD_COST, team)

	training_queue.append(TrainingType.CAVALRY_ARCHER)
	queue_changed.emit(training_queue.size())

	if not is_training:
		_start_next_training()
	return true

func train_knight() -> bool:
	if training_queue.size() >= MAX_QUEUE_SIZE:
		return false

	if not GameManager.can_add_population(team):
		return false
	if not GameManager.can_afford("food", KNIGHT_FOOD_COST, team):
		return false
	if not GameManager.can_afford("gold", KNIGHT_GOLD_COST, team):
		return false

	GameManager.spend_resource("food", KNIGHT_FOOD_COST, team)
	GameManager.spend_resource("gold", KNIGHT_GOLD_COST, team)

	training_queue.append(TrainingType.KNIGHT)
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
		TrainingType.SCOUT_CAVALRY:
			GameManager.add_resource("food", SCOUT_CAVALRY_FOOD_COST, team)
		TrainingType.CAVALRY_ARCHER:
			GameManager.add_resource("wood", CAVALRY_ARCHER_WOOD_COST, team)
			GameManager.add_resource("gold", CAVALRY_ARCHER_GOLD_COST, team)
		TrainingType.KNIGHT:
			GameManager.add_resource("food", KNIGHT_FOOD_COST, team)
			GameManager.add_resource("gold", KNIGHT_GOLD_COST, team)

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
		TrainingType.SCOUT_CAVALRY:
			scene = SCOUT_CAVALRY_SCENE
		TrainingType.CAVALRY_ARCHER:
			scene = CAVALRY_ARCHER_SCENE
		TrainingType.KNIGHT:
			scene = KNIGHT_SCENE

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
	# Resume training if queue is waiting
	if not training_queue.is_empty() and not is_training:
		_start_next_training()

func get_train_progress() -> float:
	if not is_training:
		return 0.0
	return train_timer / _get_current_train_time()

func get_queue_size() -> int:
	return training_queue.size()
