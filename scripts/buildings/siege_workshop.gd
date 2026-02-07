extends Building
class_name SiegeWorkshop

# AoE2 spec: 200W cost, 2100 HP, trains siege units
const BATTERING_RAM_WOOD_COST: int = 160
const BATTERING_RAM_GOLD_COST: int = 75
const BATTERING_RAM_TRAIN_TIME: float = 8.0

const MANGONEL_WOOD_COST: int = 160
const MANGONEL_GOLD_COST: int = 135
const MANGONEL_TRAIN_TIME: float = 8.0

const SCORPION_WOOD_COST: int = 75
const SCORPION_GOLD_COST: int = 75
const SCORPION_TRAIN_TIME: float = 8.0

var BATTERING_RAM_SCENE: PackedScene = null
var MANGONEL_SCENE: PackedScene = null
var SCORPION_SCENE: PackedScene = null

const MAX_QUEUE_SIZE: int = 15

enum TrainingType { NONE, BATTERING_RAM, MANGONEL, SCORPION }

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
	max_hp = 2100  # AoE2 spec - set before super to ensure current_hp is correct
	super._ready()
	add_to_group("siege_workshops")
	building_name = "Siege Workshop"
	size = Vector2i(3, 3)
	wood_cost = 200  # AoE2 spec
	build_time = 60.0
	garrison_capacity = 10
	# Use load() for new scenes
	BATTERING_RAM_SCENE = load("res://scenes/units/battering_ram.tscn")
	MANGONEL_SCENE = load("res://scenes/units/mangonel.tscn")
	SCORPION_SCENE = load("res://scenes/units/scorpion.tscn")

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
		TrainingType.BATTERING_RAM:
			return BATTERING_RAM_TRAIN_TIME
		TrainingType.MANGONEL:
			return MANGONEL_TRAIN_TIME
		TrainingType.SCORPION:
			return SCORPION_TRAIN_TIME
		_:
			return 1.0

func train_battering_ram() -> bool:
	if training_queue.size() >= MAX_QUEUE_SIZE:
		return false

	if not GameManager.can_add_population(team):
		return false
	if not GameManager.can_afford("wood", BATTERING_RAM_WOOD_COST, team):
		return false
	if not GameManager.can_afford("gold", BATTERING_RAM_GOLD_COST, team):
		return false

	GameManager.spend_resource("wood", BATTERING_RAM_WOOD_COST, team)
	GameManager.spend_resource("gold", BATTERING_RAM_GOLD_COST, team)

	training_queue.append(TrainingType.BATTERING_RAM)
	queue_changed.emit(training_queue.size())

	if not is_training:
		_start_next_training()
	return true

func train_mangonel() -> bool:
	if training_queue.size() >= MAX_QUEUE_SIZE:
		return false

	if not GameManager.can_add_population(team):
		return false
	if not GameManager.can_afford("wood", MANGONEL_WOOD_COST, team):
		return false
	if not GameManager.can_afford("gold", MANGONEL_GOLD_COST, team):
		return false

	GameManager.spend_resource("wood", MANGONEL_WOOD_COST, team)
	GameManager.spend_resource("gold", MANGONEL_GOLD_COST, team)

	training_queue.append(TrainingType.MANGONEL)
	queue_changed.emit(training_queue.size())

	if not is_training:
		_start_next_training()
	return true

func train_scorpion() -> bool:
	if training_queue.size() >= MAX_QUEUE_SIZE:
		return false

	if not GameManager.can_add_population(team):
		return false
	if not GameManager.can_afford("wood", SCORPION_WOOD_COST, team):
		return false
	if not GameManager.can_afford("gold", SCORPION_GOLD_COST, team):
		return false

	GameManager.spend_resource("wood", SCORPION_WOOD_COST, team)
	GameManager.spend_resource("gold", SCORPION_GOLD_COST, team)

	training_queue.append(TrainingType.SCORPION)
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
		TrainingType.BATTERING_RAM:
			GameManager.add_resource("wood", BATTERING_RAM_WOOD_COST, team)
			GameManager.add_resource("gold", BATTERING_RAM_GOLD_COST, team)
		TrainingType.MANGONEL:
			GameManager.add_resource("wood", MANGONEL_WOOD_COST, team)
			GameManager.add_resource("gold", MANGONEL_GOLD_COST, team)
		TrainingType.SCORPION:
			GameManager.add_resource("wood", SCORPION_WOOD_COST, team)
			GameManager.add_resource("gold", SCORPION_GOLD_COST, team)

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

	# Check population cap at spawn time
	if not GameManager.can_add_population(team):
		train_timer = _get_current_train_time()
		return

	var completed_type = training_queue.pop_front()
	queue_changed.emit(training_queue.size())

	var scene: PackedScene = null
	match completed_type:
		TrainingType.BATTERING_RAM:
			scene = BATTERING_RAM_SCENE
		TrainingType.MANGONEL:
			scene = MANGONEL_SCENE
		TrainingType.SCORPION:
			scene = SCORPION_SCENE

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
	# Refund all queued training resources
	for queued_type in training_queue:
		match queued_type:
			TrainingType.BATTERING_RAM:
				GameManager.add_resource("wood", BATTERING_RAM_WOOD_COST, team)
				GameManager.add_resource("gold", BATTERING_RAM_GOLD_COST, team)
			TrainingType.MANGONEL:
				GameManager.add_resource("wood", MANGONEL_WOOD_COST, team)
				GameManager.add_resource("gold", MANGONEL_GOLD_COST, team)
			TrainingType.SCORPION:
				GameManager.add_resource("wood", SCORPION_WOOD_COST, team)
				GameManager.add_resource("gold", SCORPION_GOLD_COST, team)
	training_queue.clear()
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
