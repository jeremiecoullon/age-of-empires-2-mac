extends Building
class_name TownCenter

const VILLAGER_COST: int = 50
const TRAIN_TIME: float = 3.0
const VillagerScene: PackedScene = preload("res://scenes/units/villager.tscn")
const MAX_QUEUE_SIZE: int = 15

var is_training: bool = false
var train_timer: float = 0.0
var spawn_point_offset: Vector2 = Vector2(0, 80)
var training_queue: Array[String] = []  # Array of "villager" strings (for future unit types)

signal training_started
signal training_completed
signal training_progress(progress: float)
signal queue_changed(queue_size: int)  # Emitted when queue changes

func _ready() -> void:
	max_hp = 500  # Set before super._ready() so it uses correct max
	super._ready()
	add_to_group("town_centers")
	building_name = "Town Center"
	size = Vector2i(3, 3)
	build_time = 150.0  # TCs take a long time to build
	sight_range = 256.0  # Town Centers have large LOS (~8 tiles)
	accepts_resources.assign(["wood", "food", "gold", "stone"])

func _destroy() -> void:
	if is_destroyed:
		return
	is_destroyed = true
	destroyed.emit()
	# Defer victory check to ensure we're removed from the group first
	call_deferred("_check_victory_deferred")
	queue_free()

func _check_victory_deferred() -> void:
	GameManager.check_victory()

func _process(delta: float) -> void:
	if is_training:
		train_timer += delta
		training_progress.emit(train_timer / TRAIN_TIME)

		if train_timer >= TRAIN_TIME:
			_complete_training()

func train_villager() -> bool:
	# Check queue capacity
	if training_queue.size() >= MAX_QUEUE_SIZE:
		return false

	# Check population (only need headroom for 1 unit - the one being trained/queued)
	if not GameManager.can_add_population(team):
		return false

	if not GameManager.can_afford("food", VILLAGER_COST, team):
		return false

	# Deduct resources immediately (will refund on cancel)
	GameManager.spend_resource("food", VILLAGER_COST, team)
	training_queue.append("villager")
	queue_changed.emit(training_queue.size())

	# Start training if not already training
	if not is_training:
		_start_next_training()
	return true

## Cancel the last queued unit (refunds resources)
func cancel_training() -> bool:
	if training_queue.is_empty():
		return false

	# Remove last item from queue
	var cancelled_type = training_queue.pop_back()
	queue_changed.emit(training_queue.size())

	# Refund resources
	if cancelled_type == "villager":
		GameManager.add_resource("food", VILLAGER_COST, team)

	# If queue is now empty, stop training
	if training_queue.is_empty():
		is_training = false
		train_timer = 0.0

	return true

func _start_next_training() -> void:
	if training_queue.is_empty():
		is_training = false
		return

	is_training = true
	train_timer = 0.0
	training_started.emit()

func _complete_training() -> void:
	if training_queue.is_empty():
		is_training = false
		train_timer = 0.0
		return

	# Check population cap at spawn time (may have filled since queue time)
	# If pop-capped, hold timer and retry next frame (AoE2 pauses training at cap)
	if not GameManager.can_add_population(team):
		train_timer = TRAIN_TIME  # Keep timer at max so we retry immediately
		return

	# Pop the completed unit from queue
	var completed_type = training_queue.pop_front()
	queue_changed.emit(training_queue.size())

	# Spawn the unit
	if completed_type == "villager":
		var villager = VillagerScene.instantiate()
		villager.global_position = global_position + spawn_point_offset
		villager.team = team
		get_parent().add_child(villager)
		GameManager.add_population(1, team)

	training_completed.emit()

	# Start next training if queue not empty
	if not training_queue.is_empty():
		_start_next_training()
	else:
		is_training = false
		train_timer = 0.0

func get_train_progress() -> float:
	if not is_training:
		return 0.0
	return train_timer / TRAIN_TIME

func get_queue_size() -> int:
	return training_queue.size()
