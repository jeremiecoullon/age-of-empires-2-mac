extends Unit
class_name Villager

enum State { IDLE, MOVING, GATHERING, RETURNING }

@export var carry_capacity: int = 10
@export var gather_time: float = 1.0  # seconds per resource unit

var current_state: State = State.IDLE
var carried_resource_type: String = ""
var carried_amount: int = 0
var target_resource: ResourceNode = null
var drop_off_building: Building = null
var gather_timer: float = 0.0
var move_target: Vector2 = Vector2.ZERO

func _ready() -> void:
	super._ready()
	add_to_group("villagers")

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
			velocity = Vector2.ZERO
		State.MOVING:
			_process_moving(delta)
		State.GATHERING:
			_process_gathering(delta)
		State.RETURNING:
			_process_returning(delta)

func _process_moving(delta: float) -> void:
	var distance = global_position.distance_to(move_target)
	if distance < 5:
		current_state = State.IDLE
		velocity = Vector2.ZERO
		return

	var direction = global_position.direction_to(move_target)
	velocity = direction * move_speed
	move_and_slide()

func _process_gathering(delta: float) -> void:
	if not is_instance_valid(target_resource) or not target_resource.has_resources():
		# Resource depleted, find another or go idle
		if carried_amount > 0:
			_return_to_drop_off()
		else:
			current_state = State.IDLE
			carried_resource_type = ""
			target_resource = null
		return

	# Check if we're close enough to gather
	var distance = global_position.distance_to(target_resource.global_position)
	if distance > 40:
		# Move closer
		var direction = global_position.direction_to(target_resource.global_position)
		velocity = direction * move_speed
		move_and_slide()
		return

	# We're close enough, gather
	velocity = Vector2.ZERO
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
			velocity = Vector2.ZERO
			return

	# Check if close enough to deposit
	var distance = global_position.distance_to(drop_off_building.global_position)
	if distance < 60:
		_deposit_resources()
		return

	# Keep moving toward drop-off
	var direction = global_position.direction_to(drop_off_building.global_position)
	velocity = direction * move_speed
	move_and_slide()

func _return_to_drop_off() -> void:
	drop_off_building = _find_drop_off(carried_resource_type)
	current_state = State.RETURNING  # Always transition, will wait if no drop-off

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

func command_gather(resource: ResourceNode) -> void:
	target_resource = resource
	carried_resource_type = resource.get_resource_type()
	current_state = State.GATHERING
	gather_timer = 0.0

func move_to(target_position: Vector2) -> void:
	target_resource = null
	current_state = State.MOVING
	move_target = target_position
