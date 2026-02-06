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

# Age research state
var is_researching_age: bool = false
var age_research_timer: float = 0.0
var age_research_target: int = -1  # Target age being researched
var age_research_time: float = 0.0  # Total research time for current age

signal training_started
signal training_completed
signal training_progress(progress: float)
signal queue_changed(queue_size: int)  # Emitted when queue changes
signal age_research_started(target_age: int)
signal age_research_completed(new_age: int)

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
	if is_researching_age:
		cancel_age_research()
	destroyed.emit()
	# Defer victory check to ensure we're removed from the group first
	call_deferred("_check_victory_deferred")
	queue_free()

func _check_victory_deferred() -> void:
	GameManager.check_victory()

func _process(delta: float) -> void:
	if is_destroyed:
		return
	if is_researching_age:
		age_research_timer += delta
		if age_research_timer >= age_research_time:
			_complete_age_research()
	elif is_training:
		train_timer += delta
		training_progress.emit(train_timer / TRAIN_TIME)

		if train_timer >= TRAIN_TIME:
			_complete_training()

func train_villager() -> bool:
	# Block training during age research
	if is_researching_age:
		return false

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

# Age research functions
func start_age_research(target_age: int) -> bool:
	if is_researching_age:
		return false
	if target_age <= GameManager.get_age(team):
		return false
	if target_age != GameManager.get_age(team) + 1:
		return false  # Can only advance one age at a time
	if not GameManager.can_afford_age(target_age, team):
		return false
	if GameManager.get_qualifying_building_count(target_age, team) < GameManager.AGE_REQUIRED_QUALIFYING_COUNT:
		return false

	# Spend resources
	GameManager.spend_age_cost(target_age, team)

	# Start research
	is_researching_age = true
	age_research_timer = 0.0
	age_research_target = target_age
	age_research_time = GameManager.AGE_RESEARCH_TIMES[target_age]
	age_research_started.emit(target_age)
	return true

func cancel_age_research() -> bool:
	if not is_researching_age:
		return false

	# Refund resources
	GameManager.refund_age_cost(age_research_target, team)

	is_researching_age = false
	age_research_timer = 0.0
	age_research_target = -1
	age_research_time = 0.0
	return true

func _complete_age_research() -> void:
	var new_age = age_research_target
	is_researching_age = false
	age_research_timer = 0.0
	age_research_target = -1
	age_research_time = 0.0

	# Set the new age
	GameManager.set_age(new_age, team)
	age_research_completed.emit(new_age)

	# Resume training if queue was waiting
	if not training_queue.is_empty() and not is_training:
		_start_next_training()

func get_age_research_progress() -> float:
	if not is_researching_age or age_research_time <= 0.0:
		return 0.0
	return age_research_timer / age_research_time
