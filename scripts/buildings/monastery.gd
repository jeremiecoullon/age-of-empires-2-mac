extends Building
class_name Monastery

# AoE2 spec: 175W cost, 2100 HP, trains monks
const MONK_GOLD_COST: int = 100
const MONK_TRAIN_TIME: float = 12.0
const MONK_SCENE: PackedScene = preload("res://scenes/units/monk.tscn")

const MAX_QUEUE_SIZE: int = 15

enum TrainingType { NONE, MONK }

var is_training: bool = false
var train_timer: float = 0.0
var current_training: TrainingType = TrainingType.NONE
var spawn_point_offset: Vector2 = Vector2(0, 60)
var training_queue: Array[int] = []

# Relic storage
var garrisoned_relics: Array = []
var _gold_accumulator: float = 0.0
const RELIC_GOLD_RATE: float = 0.5  # Gold per second per relic

signal training_started
signal training_completed
signal training_progress(progress: float)
signal queue_changed(queue_size: int)

func _ready() -> void:
	max_hp = 2100  # AoE2 spec - set before super to ensure current_hp is correct
	super._ready()
	add_to_group("monasteries")
	building_name = "Monastery"
	size = Vector2i(3, 3)
	wood_cost = 175  # AoE2 spec
	build_time = 40.0
	garrison_capacity = 10

func _process(delta: float) -> void:
	if is_destroyed:
		return
	if not is_constructed:
		return
	# Garrison healing (runs even during research/training)
	_process_garrison_healing(delta)
	# Relic gold generation (runs even during research/training)
	if garrisoned_relics.size() > 0:
		_gold_accumulator += RELIC_GOLD_RATE * garrisoned_relics.size() * delta
		if _gold_accumulator >= 1.0:
			var gold = int(_gold_accumulator)
			GameManager.add_resource("gold", gold, team)
			_gold_accumulator -= gold
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
		TrainingType.MONK:
			return MONK_TRAIN_TIME
		_:
			return 1.0

func train_monk() -> bool:
	if training_queue.size() >= MAX_QUEUE_SIZE:
		return false

	if not GameManager.can_add_population(team):
		return false
	if not GameManager.can_afford("gold", MONK_GOLD_COST, team):
		return false

	GameManager.spend_resource("gold", MONK_GOLD_COST, team)

	training_queue.append(TrainingType.MONK)
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
		TrainingType.MONK:
			GameManager.add_resource("gold", MONK_GOLD_COST, team)

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

	if completed_type == TrainingType.MONK:
		var unit = MONK_SCENE.instantiate()
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

func garrison_relic(relic: Node) -> bool:
	if not is_instance_valid(relic):
		return false
	garrisoned_relics.append(relic)
	relic.garrison(self)
	return true

func get_relic_count() -> int:
	return garrisoned_relics.size()

func eject_relics() -> void:
	for i in range(garrisoned_relics.size()):
		var relic = garrisoned_relics[i]
		if is_instance_valid(relic):
			var offset = Vector2(30 * (i - 2), 60)  # Spread relics around building
			relic.ungarrison(global_position + offset)
	garrisoned_relics.clear()
	_gold_accumulator = 0.0

func _destroy() -> void:
	eject_relics()
	if is_researching:
		cancel_research()
	# Refund training queue
	while not training_queue.is_empty():
		cancel_training()
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
