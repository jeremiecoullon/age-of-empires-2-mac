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

## Town Bell
var bell_active: bool = false
var _bell_garrisoned: Array = []  # Tracks villagers garrisoned by bell (not manually)

## TC attack properties
const TC_BASE_ATTACK: int = 5
const TC_ATTACK_RANGE: float = 192.0  # 6 tiles
const TC_ATTACK_COOLDOWN: float = 2.0
const TC_MIN_RANGE: float = 0.0  # TC has no minimum range
var _attack_cooldown_timer: float = 0.0

func _ready() -> void:
	max_hp = 500  # Set before super._ready() so it uses correct max
	super._ready()
	add_to_group("town_centers")
	building_name = "Town Center"
	size = Vector2i(3, 3)
	build_time = 150.0  # TCs take a long time to build
	sight_range = 256.0  # Town Centers have large LOS (~8 tiles)
	garrison_capacity = 15
	garrison_adds_arrows = true
	accepts_resources.assign(["wood", "food", "gold", "stone"])

func _destroy() -> void:
	if is_destroyed:
		return
	is_destroyed = true
	ungarrison_all()
	if is_researching_age:
		cancel_age_research()
	if is_researching:
		cancel_research()
	destroyed.emit()
	# Defer victory check to ensure we're removed from the group first
	call_deferred("_check_victory_deferred")
	queue_free()

func _check_victory_deferred() -> void:
	GameManager.check_victory()

func _process(delta: float) -> void:
	if is_destroyed:
		return
	# TC attack - fires regardless of training/research
	if is_functional():
		_process_tc_attack(delta)
		_process_garrison_healing(delta)
	# Priority: age research > tech research (Loom) > training
	if is_researching_age:
		age_research_timer += delta
		if age_research_timer >= age_research_time:
			_complete_age_research()
	elif is_researching:
		_process_research(delta)
	elif is_training:
		train_timer += delta
		training_progress.emit(train_timer / TRAIN_TIME)

		if train_timer >= TRAIN_TIME:
			_complete_training()

func train_villager() -> bool:
	# Block training during age research or tech research (Loom)
	if is_researching_age or is_researching:
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

## Start Loom research. Blocks training while active.
func start_loom_research() -> bool:
	if is_researching_age or is_researching:
		return false
	return start_research("loom")

## Override to resume training after Loom completes
func _complete_research() -> void:
	super._complete_research()
	# Resume training if queue was waiting
	if not training_queue.is_empty() and not is_training:
		_start_next_training()

# ===== TC ATTACK =====

func _process_tc_attack(delta: float) -> void:
	_attack_cooldown_timer -= delta
	if _attack_cooldown_timer > 0:
		return

	# Find nearest enemy in range
	var attack_range = TC_ATTACK_RANGE + GameManager.get_tech_bonus("archer_range", team) * 32.0
	var target = _find_attack_target(attack_range)
	if not target:
		_attack_cooldown_timer = 0.5  # Don't scan every frame when idle
		return

	# Fire arrow
	var attack_damage = TC_BASE_ATTACK + GameManager.get_tech_bonus("archer_attack", team) + get_garrison_arrow_bonus()
	target.take_damage(attack_damage, "pierce", 0, self)
	_attack_cooldown_timer = TC_ATTACK_COOLDOWN

func _find_attack_target(attack_range: float) -> Node:
	## Find nearest enemy unit or building in range
	var nearest: Node = null
	var nearest_dist: float = attack_range

	for unit in get_tree().get_nodes_in_group("units"):
		if unit.team == team or unit.is_dead:
			continue
		if unit is Animal:
			continue
		var dist = global_position.distance_to(unit.global_position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = unit

	# Also check enemy buildings (e.g., rams in future)
	for building in get_tree().get_nodes_in_group("buildings"):
		if building.team == team or building.is_destroyed:
			continue
		var dist = global_position.distance_to(building.global_position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = building

	return nearest

# ===== TOWN BELL =====

func ring_town_bell() -> void:
	if bell_active:
		return
	bell_active = true
	_bell_garrisoned.clear()

	# Find all player villagers and garrison them in nearest building with capacity
	var villagers = get_tree().get_nodes_in_group("units").filter(
		func(u): return u is Villager and u.team == team and not u.is_dead and not u.is_garrisoned()
	)

	# Collect all garrisonable buildings for this team
	var garrison_buildings: Array = []
	for b in get_tree().get_nodes_in_group("buildings"):
		if b.team == team and b.garrison_capacity > 0 and b.is_functional() and not b.is_destroyed:
			garrison_buildings.append(b)

	for villager in villagers:
		# Find nearest building with capacity
		var best_building: Building = null
		var best_dist: float = INF
		for b in garrison_buildings:
			if b.get_garrisoned_count() >= b.garrison_capacity:
				continue
			var dist = villager.global_position.distance_to(b.global_position)
			if dist < best_dist:
				best_dist = dist
				best_building = b
		if best_building and best_building.can_garrison(villager):
			best_building.garrison_unit(villager)
			_bell_garrisoned.append(villager)

func ring_all_clear() -> void:
	if not bell_active:
		return
	bell_active = false

	# Ungarrison only bell-garrisoned villagers (not manually garrisoned ones)
	for villager in _bell_garrisoned:
		if is_instance_valid(villager) and villager.is_garrisoned():
			var building = villager.garrisoned_in
			if is_instance_valid(building):
				building.ungarrison_unit(villager)
	_bell_garrisoned.clear()
