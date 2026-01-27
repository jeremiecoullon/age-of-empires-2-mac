extends Node
class_name AIController

const TC_SCENE_PATH = "res://scenes/buildings/town_center.tscn"
const VILLAGER_SCENE_PATH = "res://scenes/units/villager.tscn"
const HOUSE_SCENE_PATH = "res://scenes/buildings/house.tscn"
const BARRACKS_SCENE_PATH = "res://scenes/buildings/barracks.tscn"
const MILITIA_SCENE_PATH = "res://scenes/units/militia.tscn"
const LUMBER_CAMP_SCENE_PATH = "res://scenes/buildings/lumber_camp.tscn"
const MINING_CAMP_SCENE_PATH = "res://scenes/buildings/mining_camp.tscn"
const MILL_SCENE_PATH = "res://scenes/buildings/mill.tscn"

const AI_TEAM: int = 1
const AI_BASE_POSITION: Vector2 = Vector2(1700, 1700)
const DECISION_INTERVAL: float = 1.5
const ATTACK_THRESHOLD: int = 3

var ai_tc: TownCenter = null
var ai_barracks: Barracks = null
var ai_lumber_camp: LumberCamp = null
var ai_mining_camp: MiningCamp = null
var ai_mill: Mill = null
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
		GameManager.add_population(1, AI_TEAM)

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

	# 1. Send idle villagers to gather (with priority)
	_assign_idle_villagers()

	# 2. Build house if pop capped
	if _is_pop_capped() and GameManager.can_afford("wood", 25, AI_TEAM):
		_build_house()

	# 3. Build camps near resources if villagers are gathering far from drop-offs
	_consider_building_camps()

	# 4. Build barracks if we don't have one
	if not _has_barracks() and GameManager.can_afford("wood", 100, AI_TEAM):
		_build_barracks()

	# 5. Train militia if we have barracks and can afford
	if _has_barracks() and _can_train_militia():
		_train_militia()

	# 6. Attack when we have enough military (reset flag if military depleted)
	var military_count = _get_military_count()
	if military_count < ATTACK_THRESHOLD:
		has_attacked = false
	if military_count >= ATTACK_THRESHOLD and not has_attacked:
		_attack_player()

func _assign_idle_villagers() -> void:
	var ai_villagers = _get_ai_villagers()
	var idle_villagers = []

	for villager in ai_villagers:
		if villager.current_state == Villager.State.IDLE:
			idle_villagers.append(villager)

	if idle_villagers.is_empty():
		return

	# Determine what we need most (priority: food > wood > gold > stone)
	var needed_resource = _get_priority_resource()

	for villager in idle_villagers:
		# First priority: hunt nearby animals for food (if we need food)
		if needed_resource == "food":
			var animal = _find_huntable_animal(villager.global_position)
			if animal:
				villager.command_hunt(animal)
				continue

		var resource = _find_resource_of_type(villager.global_position, needed_resource)
		if resource:
			villager.command_gather(resource)
		else:
			# Fallback to any nearby resource
			resource = _find_nearest_resource(villager.global_position)
			if resource:
				villager.command_gather(resource)

func _get_priority_resource() -> String:
	# Food is always priority for villagers and military
	var food = GameManager.get_resource("food", AI_TEAM)
	var wood = GameManager.get_resource("wood", AI_TEAM)
	var gold = GameManager.get_resource("gold", AI_TEAM)

	# Need food for villagers (50) and militia (60)
	if food < 100:
		return "food"
	# Need wood for buildings and militia
	if wood < 150:
		return "wood"
	# Gold for advanced units (less important in MVP)
	if gold < 50:
		return "gold"
	# Default to food
	return "food"

func _find_resource_of_type(from_pos: Vector2, resource_type: String) -> ResourceNode:
	var resources = get_tree().get_nodes_in_group("resources")
	var nearest: ResourceNode = null
	var nearest_dist: float = INF

	# For food, prioritize carcasses (they decay!)
	if resource_type == "food":
		var carcasses = get_tree().get_nodes_in_group("carcasses")
		for carcass in carcasses:
			if not carcass.has_resources():
				continue
			var dist = from_pos.distance_to(carcass.global_position)
			if dist < nearest_dist:
				nearest_dist = dist
				nearest = carcass
		if nearest:
			return nearest
		# Reset for regular search
		nearest_dist = INF

	for resource in resources:
		if resource is Farm:
			if resource.team != AI_TEAM:
				continue
		if not resource.has_resources():
			continue
		if resource.get_resource_type() != resource_type:
			continue
		var dist = from_pos.distance_to(resource.global_position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = resource

	return nearest

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

func _find_huntable_animal(from_pos: Vector2) -> Animal:
	# Find nearest animal that AI can hunt
	# Priority: sheep (owned by AI or neutral) > deer > boar (dangerous, avoid unless necessary)
	var animals = get_tree().get_nodes_in_group("animals")

	# First pass: look for owned or neutral sheep
	var nearest_sheep: Animal = null
	var nearest_sheep_dist: float = 800.0  # Max hunt distance

	for animal in animals:
		if animal.is_dead:
			continue
		if animal is Wolf:
			continue  # Never hunt wolves
		if animal is Sheep:
			# Only hunt if we own it or it's neutral
			if animal.team == AI_TEAM or animal.team == Animal.NEUTRAL_TEAM:
				var dist = from_pos.distance_to(animal.global_position)
				if dist < nearest_sheep_dist:
					nearest_sheep_dist = dist
					nearest_sheep = animal

	if nearest_sheep:
		return nearest_sheep

	# Second pass: look for deer
	var nearest_deer: Animal = null
	var nearest_deer_dist: float = 600.0

	for animal in animals:
		if animal.is_dead:
			continue
		if animal is Deer:
			var dist = from_pos.distance_to(animal.global_position)
			if dist < nearest_deer_dist:
				nearest_deer_dist = dist
				nearest_deer = animal

	if nearest_deer:
		return nearest_deer

	# Third pass: boar (only if close and we really need food)
	var food = GameManager.get_resource("food", AI_TEAM)
	if food < 50:  # Desperate for food
		var nearest_boar: Animal = null
		var nearest_boar_dist: float = 400.0

		for animal in animals:
			if animal.is_dead:
				continue
			if animal is Boar:
				var dist = from_pos.distance_to(animal.global_position)
				if dist < nearest_boar_dist:
					nearest_boar_dist = dist
					nearest_boar = animal

		if nearest_boar:
			return nearest_boar

	return null

func _is_pop_capped() -> bool:
	return GameManager.get_population(AI_TEAM) >= GameManager.get_population_cap(AI_TEAM)

func _consider_building_camps() -> void:
	if not GameManager.can_afford("wood", 100, AI_TEAM):
		return

	# Check if we need a lumber camp near trees
	if not _has_lumber_camp() and _has_villagers_gathering("wood"):
		var wood_pos = _find_resource_cluster_position("wood")
		if wood_pos != Vector2.ZERO:
			_build_lumber_camp(wood_pos)
			return

	# Check if we need a mining camp near gold/stone
	if not _has_mining_camp():
		if _has_villagers_gathering("gold") or _has_villagers_gathering("stone"):
			var gold_pos = _find_resource_cluster_position("gold")
			if gold_pos != Vector2.ZERO:
				_build_mining_camp(gold_pos)
				return
			var stone_pos = _find_resource_cluster_position("stone")
			if stone_pos != Vector2.ZERO:
				_build_mining_camp(stone_pos)
				return

func _has_lumber_camp() -> bool:
	if is_instance_valid(ai_lumber_camp) and not ai_lumber_camp.is_destroyed:
		return true
	var camps = get_tree().get_nodes_in_group("lumber_camps")
	for c in camps:
		if c.team == AI_TEAM and not c.is_destroyed:
			ai_lumber_camp = c
			return true
	return false

func _has_mining_camp() -> bool:
	if is_instance_valid(ai_mining_camp) and not ai_mining_camp.is_destroyed:
		return true
	var camps = get_tree().get_nodes_in_group("mining_camps")
	for c in camps:
		if c.team == AI_TEAM and not c.is_destroyed:
			ai_mining_camp = c
			return true
	return false

func _has_villagers_gathering(resource_type: String) -> bool:
	var ai_villagers = _get_ai_villagers()
	for v in ai_villagers:
		if v.current_state == Villager.State.GATHERING:
			if v.carried_resource_type == resource_type:
				return true
	return false

func _find_resource_cluster_position(resource_type: String) -> Vector2:
	var resources = get_tree().get_nodes_in_group("resources")
	for resource in resources:
		if resource.get_resource_type() == resource_type and resource.has_resources():
			# Find a spot near this resource
			return resource.global_position + Vector2(80, 0)
	return Vector2.ZERO

func _build_lumber_camp(near_pos: Vector2) -> void:
	if not GameManager.spend_resource("wood", 100, AI_TEAM):
		return

	var scene = load(LUMBER_CAMP_SCENE_PATH)
	ai_lumber_camp = scene.instantiate()

	# Find valid position near the resource
	var pos = _find_valid_camp_position(near_pos, Vector2(64, 64))
	ai_lumber_camp.global_position = pos
	ai_lumber_camp.team = AI_TEAM

	get_parent().get_node("Buildings").add_child(ai_lumber_camp)

func _build_mining_camp(near_pos: Vector2) -> void:
	if not GameManager.spend_resource("wood", 100, AI_TEAM):
		return

	var scene = load(MINING_CAMP_SCENE_PATH)
	ai_mining_camp = scene.instantiate()

	var pos = _find_valid_camp_position(near_pos, Vector2(64, 64))
	ai_mining_camp.global_position = pos
	ai_mining_camp.team = AI_TEAM

	get_parent().get_node("Buildings").add_child(ai_mining_camp)

func _find_valid_camp_position(near_pos: Vector2, size: Vector2) -> Vector2:
	var offsets = [
		Vector2(80, 0), Vector2(-80, 0), Vector2(0, 80), Vector2(0, -80),
		Vector2(80, 80), Vector2(-80, 80), Vector2(80, -80), Vector2(-80, -80),
	]

	for offset in offsets:
		var pos = near_pos + offset
		if _is_valid_building_position(pos, size):
			return pos

	# Fallback to just the offset position
	return near_pos + Vector2(80, 0)

func _build_house() -> void:
	if not GameManager.spend_resource("wood", 25, AI_TEAM):
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
	if not GameManager.spend_resource("wood", 100, AI_TEAM):
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
	if not GameManager.can_add_population(AI_TEAM):
		return false
	if not GameManager.can_afford("food", 60, AI_TEAM):
		return false
	if not GameManager.can_afford("wood", 20, AI_TEAM):
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

	# Check collision with resources
	var resources = get_tree().get_nodes_in_group("resources")
	for resource in resources:
		if not resource is Farm:
			if pos.distance_to(resource.global_position) < half_size.x + 20:
				return false

	return true
