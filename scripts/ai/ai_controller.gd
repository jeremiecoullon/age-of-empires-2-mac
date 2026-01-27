extends Node
class_name AIController

const TC_SCENE_PATH = "res://scenes/buildings/town_center.tscn"
const VILLAGER_SCENE_PATH = "res://scenes/units/villager.tscn"
const HOUSE_SCENE_PATH = "res://scenes/buildings/house.tscn"
const BARRACKS_SCENE_PATH = "res://scenes/buildings/barracks.tscn"
const MILITIA_SCENE_PATH = "res://scenes/units/militia.tscn"

const AI_TEAM: int = 1
const AI_BASE_POSITION: Vector2 = Vector2(1700, 1700)
const DECISION_INTERVAL: float = 1.5
const ATTACK_THRESHOLD: int = 3

var ai_tc: TownCenter = null
var ai_barracks: Barracks = null
var decision_timer: float = 0.0
var has_attacked: bool = false

func _ready() -> void:
	# Wait a frame for the scene to be fully loaded
	await get_tree().process_frame
	_spawn_ai_base()

func _spawn_ai_base() -> void:
	# Spawn AI Town Center
	var tc_scene = load(TC_SCENE_PATH)
	ai_tc = tc_scene.instantiate()
	ai_tc.global_position = AI_BASE_POSITION
	ai_tc.team = AI_TEAM
	get_parent().get_node("Buildings").add_child(ai_tc)
	# Team color handled by Building._ready()

	# Spawn 3 AI villagers
	var villager_scene = load(VILLAGER_SCENE_PATH)
	var offsets = [Vector2(-40, 60), Vector2(0, 80), Vector2(40, 60)]

	for offset in offsets:
		var villager = villager_scene.instantiate()
		villager.global_position = AI_BASE_POSITION + offset
		villager.team = AI_TEAM
		get_parent().get_node("Units").add_child(villager)
		GameManager.ai_add_population(1)

func _process(delta: float) -> void:
	if GameManager.game_ended:
		return

	decision_timer += delta
	if decision_timer >= DECISION_INTERVAL:
		decision_timer = 0.0
		_make_decisions()

func _make_decisions() -> void:
	# Check if AI TC still exists
	if not is_instance_valid(ai_tc) or ai_tc.is_destroyed:
		return

	# 1. Send idle villagers to gather
	_assign_idle_villagers()

	# 2. Build house if pop capped
	if _is_pop_capped() and GameManager.ai_can_afford_wood(25):
		_build_house()

	# 3. Build barracks if we don't have one
	if not _has_barracks() and GameManager.ai_can_afford_wood(100):
		_build_barracks()

	# 4. Train militia if we have barracks and can afford
	if _has_barracks() and _can_train_militia():
		_train_militia()

	# 5. Attack when we have enough military (reset flag if military depleted)
	var military_count = _get_military_count()
	if military_count < ATTACK_THRESHOLD:
		has_attacked = false
	if military_count >= ATTACK_THRESHOLD and not has_attacked:
		_attack_player()

func _assign_idle_villagers() -> void:
	var ai_villagers = _get_ai_villagers()

	for villager in ai_villagers:
		if villager.current_state == Villager.State.IDLE:
			var nearest_resource = _find_nearest_resource(villager.global_position)
			if nearest_resource:
				villager.command_gather(nearest_resource)

func _find_nearest_resource(from_pos: Vector2) -> ResourceNode:
	var resources = get_tree().get_nodes_in_group("resources")
	var nearest: ResourceNode = null
	var nearest_dist: float = INF

	for resource in resources:
		if resource is Farm:
			# Only use our own farms
			if resource.team != AI_TEAM:
				continue
		if not resource.has_resources():
			continue
		var dist = from_pos.distance_to(resource.global_position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = resource

	return nearest

func _is_pop_capped() -> bool:
	return GameManager.ai_population >= GameManager.ai_population_cap

func _build_house() -> void:
	if not GameManager.ai_spend_wood(25):
		return

	var house_scene = load(HOUSE_SCENE_PATH)
	var house = house_scene.instantiate()

	# Find a spot near the TC
	var offset = _find_building_spot(Vector2(64, 64))
	house.global_position = AI_BASE_POSITION + offset
	house.team = AI_TEAM

	get_parent().get_node("Buildings").add_child(house)
	# Team color and population cap handled by House._ready()

func _has_barracks() -> bool:
	if is_instance_valid(ai_barracks) and not ai_barracks.is_destroyed:
		return true

	# Check if we have any barracks
	var barracks_list = get_tree().get_nodes_in_group("barracks")
	for b in barracks_list:
		if b.team == AI_TEAM and not b.is_destroyed:
			ai_barracks = b
			return true
	return false

func _build_barracks() -> void:
	if not GameManager.ai_spend_wood(100):
		return

	var barracks_scene = load(BARRACKS_SCENE_PATH)
	ai_barracks = barracks_scene.instantiate()

	# Find a spot near the TC
	var offset = _find_building_spot(Vector2(96, 96))
	ai_barracks.global_position = AI_BASE_POSITION + offset
	ai_barracks.team = AI_TEAM

	get_parent().get_node("Buildings").add_child(ai_barracks)
	# Team color handled by Building._ready()

func _can_train_militia() -> bool:
	if not is_instance_valid(ai_barracks):
		return false
	if ai_barracks.is_training:
		return false
	if not GameManager.ai_can_add_population():
		return false
	if not GameManager.ai_can_afford_food(60):
		return false
	if not GameManager.ai_can_afford_wood(20):
		return false
	return true

func _train_militia() -> void:
	if not is_instance_valid(ai_barracks):
		return
	# Barracks handles resource spending and population based on team
	ai_barracks.train_militia()

func _get_military_count() -> int:
	var count = 0
	var militias = get_tree().get_nodes_in_group("military")
	for militia in militias:
		if militia.team == AI_TEAM:
			count += 1
	return count

func _attack_player() -> void:
	has_attacked = true

	# Find player TC
	var player_tc: TownCenter = null
	var tcs = get_tree().get_nodes_in_group("town_centers")
	for tc in tcs:
		if tc.team == 0:
			player_tc = tc
			break

	if not player_tc:
		return

	# Send all AI military to attack
	var militias = get_tree().get_nodes_in_group("military")
	for militia in militias:
		if militia.team == AI_TEAM:
			militia.command_attack(player_tc)

func _get_ai_villagers() -> Array:
	var result = []
	var villagers = get_tree().get_nodes_in_group("villagers")
	for v in villagers:
		if v.team == AI_TEAM:
			result.append(v)
	return result

func _find_building_spot(building_size: Vector2) -> Vector2:
	# Simple spiral search for a valid spot
	var offsets = [
		Vector2(-100, 0), Vector2(100, 0), Vector2(0, -100), Vector2(0, 100),
		Vector2(-100, -100), Vector2(100, -100), Vector2(-100, 100), Vector2(100, 100),
		Vector2(-150, 0), Vector2(150, 0), Vector2(0, -150), Vector2(0, 150),
	]

	for offset in offsets:
		var pos = AI_BASE_POSITION + offset
		if _is_valid_building_position(pos, building_size):
			return offset

	# Fallback
	return Vector2(-100, 0)

func _is_valid_building_position(pos: Vector2, size: Vector2) -> bool:
	var half_size = size / 2

	# Check map bounds (1920x1920 map)
	if pos.x - half_size.x < 0 or pos.x + half_size.x > 1920:
		return false
	if pos.y - half_size.y < 0 or pos.y + half_size.y > 1920:
		return false

	# Check collision with existing buildings
	var buildings = get_tree().get_nodes_in_group("buildings")
	for building in buildings:
		var building_half_size = Vector2(building.size.x * 32, building.size.y * 32) / 2
		if abs(pos.x - building.global_position.x) < (half_size.x + building_half_size.x) and \
		   abs(pos.y - building.global_position.y) < (half_size.y + building_half_size.y):
			return false

	return true
