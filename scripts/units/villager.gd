extends Unit
class_name Villager

enum State { IDLE, MOVING, GATHERING, RETURNING }

@export var carry_capacity: int = 10
@export var gather_time: float = 1.0  # seconds per resource unit

var current_state: State = State.IDLE
var carried_resource_type: String = ""
var carried_amount: int = 0
var target_resource: ResourceNode = null
var town_center: Node2D = null
var gather_timer: float = 0.0
var move_target: Vector2 = Vector2.ZERO

func _ready() -> void:
	super._ready()
	add_to_group("villagers")
	# Find town center reference matching our team
	await get_tree().process_frame
	_find_town_center()

func _find_town_center() -> void:
	var tcs = get_tree().get_nodes_in_group("town_centers")
	for tc in tcs:
		if tc.team == team:
			town_center = tc
			return
	# Fallback to first TC if none matches (shouldn't happen)
	if tcs.size() > 0:
		town_center = tcs[0]

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
			_return_to_tc()
		else:
			current_state = State.IDLE
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
			_return_to_tc()

func _process_returning(delta: float) -> void:
	if town_center == null or not is_instance_valid(town_center):
		_find_town_center()  # Retry lookup
		if town_center == null:
			current_state = State.IDLE
			return

	# Check if close enough to deposit
	var distance = global_position.distance_to(town_center.global_position)
	if distance < 60:
		_deposit_resources()
		return

	# Keep moving toward TC
	var direction = global_position.direction_to(town_center.global_position)
	velocity = direction * move_speed
	move_and_slide()

func _return_to_tc() -> void:
	if town_center:
		current_state = State.RETURNING

func _deposit_resources() -> void:
	if team == 0:  # Player
		if carried_resource_type == "wood":
			GameManager.add_wood(carried_amount)
		elif carried_resource_type == "food":
			GameManager.add_food(carried_amount)
	else:  # AI
		if carried_resource_type == "wood":
			GameManager.ai_add_wood(carried_amount)
		elif carried_resource_type == "food":
			GameManager.ai_add_food(carried_amount)

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
		if carried_resource_type == "wood":
			sprite.modulate = Color(0.6, 0.4, 0.2, 1)  # Brown for wood
		elif carried_resource_type == "food":
			sprite.modulate = Color(0.9, 0.8, 0.3, 1)  # Yellow for food
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
