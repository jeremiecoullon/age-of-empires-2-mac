extends Building
class_name TownCenter

const VILLAGER_COST: int = 50
const TRAIN_TIME: float = 3.0
const VILLAGER_SCENE_PATH: String = "res://scenes/units/villager.tscn"

var is_training: bool = false
var train_timer: float = 0.0
var spawn_point_offset: Vector2 = Vector2(0, 80)

signal training_started
signal training_completed
signal training_progress(progress: float)

func _ready() -> void:
	super._ready()
	add_to_group("town_centers")
	building_name = "Town Center"
	size = Vector2i(3, 3)
	max_hp = 500
	current_hp = max_hp
	accepts_resources = ["wood", "food", "gold", "stone"]

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
	if is_training:
		return false

	if not GameManager.can_add_population(team):
		return false

	if not GameManager.can_afford("food", VILLAGER_COST, team):
		return false

	GameManager.spend_resource("food", VILLAGER_COST, team)
	is_training = true
	train_timer = 0.0
	training_started.emit()
	return true

func _complete_training() -> void:
	is_training = false
	train_timer = 0.0

	var villager_scene = load(VILLAGER_SCENE_PATH)
	if villager_scene:
		var villager = villager_scene.instantiate()
		villager.global_position = global_position + spawn_point_offset
		villager.team = team
		get_parent().add_child(villager)
		GameManager.add_population(1, team)

	training_completed.emit()

func get_train_progress() -> float:
	if not is_training:
		return 0.0
	return train_timer / TRAIN_TIME
