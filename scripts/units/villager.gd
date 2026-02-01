extends Unit
class_name Villager
## Villager unit - gathers resources and constructs buildings
##
## Gatherable Resource Interface (duck-typed):
## Objects passed to command_gather() must implement:
##   - harvest(amount: int) -> int
##   - get_resource_type() -> String
##   - has_resources() -> bool
##   - global_position: Vector2
##   - (optional) gather_rate: float - defaults to 1.0 if not present
## Both ResourceNode and Farm implement this interface.

enum State { IDLE, MOVING, GATHERING, RETURNING, HUNTING, BUILDING }

@export var carry_capacity: int = 10
@export var gather_time: float = 1.0  # seconds per resource unit
@export var attack_damage: int = 3  # Villager attack for hunting
@export var attack_range: float = 25.0
@export var attack_cooldown: float = 1.5
@export var build_range: float = 50.0  # Distance to stand from building while constructing

var current_state: State = State.IDLE
var carried_resource_type: String = ""
var carried_amount: int = 0
var target_resource: Node = null  # ResourceNode or Farm (both implement harvest/get_resource_type/has_resources)
var target_animal: Animal = null  # For hunting
var last_animal_position: Vector2 = Vector2.ZERO  # For finding carcass after animal dies
var drop_off_building: Building = null
var target_construction: Building = null  # Building we're constructing
var gather_timer: float = 0.0
var attack_timer: float = 0.0
var move_target: Vector2 = Vector2.ZERO

func _ready() -> void:
	super._ready()
	add_to_group("villagers")
	# 75 frames total, 8 directions = ~9 frames per direction
	_load_directional_animations("res://assets/sprites/units/villager_frames", "Villagerstand", 75)

func die() -> void:
	# Clean up construction assignment before dying
	if target_construction and is_instance_valid(target_construction):
		target_construction.remove_builder(self)
		target_construction = null
	super.die()

func _find_drop_off(resource_type: String) -> Building:
	var buildings = get_tree().get_nodes_in_group("buildings")
	var nearest: Building = null
	var nearest_dist: float = INF

	for building in buildings:
		if building.team != team:
			continue
		if building.is_destroyed:
			continue
		if not building.is_drop_off_for(resource_type):
			continue

		var dist = global_position.distance_to(building.global_position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = building

	return nearest

func _physics_process(delta: float) -> void:
	match current_state:
		State.IDLE:
			_stop_and_stay()
		State.MOVING:
			_process_moving(delta)
		State.GATHERING:
			_process_gathering(delta)
		State.RETURNING:
			_process_returning(delta)
		State.HUNTING:
			_process_hunting(delta)
		State.BUILDING:
			_process_building(delta)

func _process_moving(delta: float) -> void:
	var distance = global_position.distance_to(move_target)
	if distance < 5:
		current_state = State.IDLE
		velocity = Vector2.ZERO
		return

	var direction = global_position.direction_to(move_target)
	_resume_movement()
	_apply_movement(direction * move_speed)

func _process_gathering(delta: float) -> void:
	if not is_instance_valid(target_resource) or not target_resource.has_resources():
		# Resource depleted, find another or go idle
		if carried_amount > 0:
			_return_to_drop_off()
		else:
			current_state = State.IDLE
			carried_resource_type = ""
			target_resource = null
			# Notify player about idle villager (only for player team)
			if team == 0:
				GameManager.villager_idle.emit(self, "Resource depleted")
		return

	# Check if we're close enough to gather
	var distance = global_position.distance_to(target_resource.global_position)
	if distance > 40:
		# Move closer
		var direction = global_position.direction_to(target_resource.global_position)
		_resume_movement()
		_apply_movement(direction * move_speed)
		return

	# We're close enough, gather - stop completely to prevent avoidance drift
	_stop_and_stay()
	gather_timer += delta

	# Use resource's gather rate if available (farms are slower)
	var effective_gather_time = gather_time
	if "gather_rate" in target_resource:
		effective_gather_time = 1.0 / target_resource.gather_rate

	if gather_timer >= effective_gather_time:
		gather_timer = 0.0
		var harvested = target_resource.harvest(1)
		carried_amount += harvested
		carried_resource_type = target_resource.get_resource_type()
		_update_carry_visual()

		if carried_amount >= carry_capacity:
			_return_to_drop_off()

func _process_returning(delta: float) -> void:
	if drop_off_building == null or not is_instance_valid(drop_off_building):
		drop_off_building = _find_drop_off(carried_resource_type)
		if drop_off_building == null:
			# No drop-off available, wait in place (don't lose resources)
			_stop_and_stay()
			return

	# Check if close enough to deposit
	var distance = global_position.distance_to(drop_off_building.global_position)
	if distance < 60:
		_deposit_resources()
		return

	# Keep moving toward drop-off
	var direction = global_position.direction_to(drop_off_building.global_position)
	_resume_movement()
	_apply_movement(direction * move_speed)

func _return_to_drop_off() -> void:
	drop_off_building = _find_drop_off(carried_resource_type)
	current_state = State.RETURNING  # Always transition, will wait if no drop-off

func _process_hunting(delta: float) -> void:
	# Check if animal is still valid and alive
	if not is_instance_valid(target_animal) or target_animal.is_dead:
		# Animal died - look for carcass at last known position
		var carcass = _find_carcass_near(last_animal_position)
		target_animal = null
		if carcass:
			target_resource = carcass
			carried_resource_type = "food"
			current_state = State.GATHERING
		else:
			current_state = State.IDLE
		return

	# Store last known position for carcass finding
	last_animal_position = target_animal.global_position

	var distance = global_position.distance_to(target_animal.global_position)

	if distance > attack_range:
		# Chase the animal
		nav_agent.target_position = target_animal.global_position
		var next_path_position = nav_agent.get_next_path_position()
		var direction = global_position.direction_to(next_path_position)
		_resume_movement()
		_apply_movement(direction * move_speed)
		return

	# In range, attack - stop completely to prevent avoidance drift
	_stop_and_stay()
	attack_timer += delta

	if attack_timer >= attack_cooldown:
		attack_timer = 0.0
		target_animal.take_damage(attack_damage, "melee", 0, self)

func _find_carcass_near(pos: Vector2) -> ResourceNode:
	var carcasses = get_tree().get_nodes_in_group("carcasses")
	var nearest: ResourceNode = null
	var nearest_dist: float = 100.0  # Search radius

	for carcass in carcasses:
		if not carcass.has_resources():
			continue
		var dist = pos.distance_to(carcass.global_position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = carcass

	return nearest

func _deposit_resources() -> void:
	GameManager.add_resource(carried_resource_type, carried_amount, team)

	carried_amount = 0
	_update_carry_visual()

	# Go back to gathering if resource still exists
	if is_instance_valid(target_resource) and target_resource.has_resources():
		current_state = State.GATHERING
	else:
		current_state = State.IDLE
		target_resource = null

func _update_carry_visual() -> void:
	if carried_amount > 0:
		match carried_resource_type:
			"wood":
				sprite.modulate = Color(0.6, 0.4, 0.2, 1)  # Brown for wood
			"food":
				sprite.modulate = Color(0.9, 0.8, 0.3, 1)  # Yellow for food
			"gold":
				sprite.modulate = Color(1.0, 0.85, 0.0, 1)  # Bright yellow for gold
			"stone":
				sprite.modulate = Color(0.6, 0.6, 0.6, 1)  # Gray for stone
	else:
		# Reset to team color
		_apply_team_color()

func command_gather(resource: Node) -> void:  # Accepts ResourceNode or Farm
	# If we were building, leave that job
	if target_construction and is_instance_valid(target_construction):
		target_construction.remove_builder(self)
	target_construction = null
	target_resource = resource
	carried_resource_type = resource.get_resource_type()
	current_state = State.GATHERING
	gather_timer = 0.0

func move_to(target_position: Vector2) -> void:
	# If we were building, leave that job
	if target_construction and is_instance_valid(target_construction):
		target_construction.remove_builder(self)
	target_resource = null
	target_animal = null
	target_construction = null
	current_state = State.MOVING
	move_target = target_position

func command_hunt(animal: Animal) -> void:
	# If we were building, leave that job
	if target_construction and is_instance_valid(target_construction):
		target_construction.remove_builder(self)
	target_construction = null
	target_animal = animal
	last_animal_position = animal.global_position
	target_resource = null
	carried_resource_type = "food"
	current_state = State.HUNTING
	attack_timer = 0.0

func command_build(building: Building) -> void:
	# If we were building something else, leave that job
	if target_construction and is_instance_valid(target_construction):
		target_construction.remove_builder(self)

	target_construction = building
	target_resource = null
	target_animal = null
	current_state = State.BUILDING
	building.add_builder(self)

func _process_building(delta: float) -> void:
	# Check if building still exists and needs construction
	if not is_instance_valid(target_construction) or target_construction.is_destroyed:
		target_construction = null
		current_state = State.IDLE
		return

	# Check if construction is complete
	if target_construction.is_constructed:
		target_construction.remove_builder(self)
		target_construction = null
		current_state = State.IDLE
		return

	# Check if we're close enough to build
	var distance = global_position.distance_to(target_construction.global_position)
	if distance > build_range:
		# Move closer
		nav_agent.target_position = target_construction.global_position
		var next_path_position = nav_agent.get_next_path_position()
		var direction = global_position.direction_to(next_path_position)
		_resume_movement()
		_apply_movement(direction * move_speed)
		return

	# We're close enough - stop and build (prevent avoidance drift)
	_stop_and_stay()

	# Progress construction
	var completed = target_construction.progress_construction(delta)

	if completed:
		target_construction = null
		current_state = State.IDLE
		# Notify player about idle villager
		if team == 0:
			GameManager.villager_idle.emit(self, "Construction complete")
