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
const MARKET_SCENE_PATH = "res://scenes/buildings/market.tscn"
const FARM_SCENE_PATH = "res://scenes/buildings/farm.tscn"
const ARCHERY_RANGE_SCENE_PATH = "res://scenes/buildings/archery_range.tscn"
const STABLE_SCENE_PATH = "res://scenes/buildings/stable.tscn"

const AI_TEAM: int = 1
const AI_BASE_POSITION: Vector2 = Vector2(1700, 1700)
const DECISION_INTERVAL: float = 1.5

# Economic thresholds
const TARGET_VILLAGERS: int = 20  # Target villager count before heavy military
const MIN_VILLAGERS_FOR_ATTACK: int = 15  # Minimum villagers before considering attack
const MIN_MILITARY_FOR_ATTACK: int = 5  # Minimum military before attacking
const TARGET_FARMS: int = 6  # Target number of farms for sustainable food

# Villager allocation targets (approximate ratios)
const FOOD_VILLAGERS: int = 6
const WOOD_VILLAGERS: int = 5
const GOLD_VILLAGERS: int = 3
const STONE_VILLAGERS: int = 1

var ai_tc: TownCenter = null
var ai_barracks: Array[Barracks] = []  # Support multiple barracks
var ai_archery_range: ArcheryRange = null
var ai_stable: Stable = null
var ai_lumber_camp: LumberCamp = null
var ai_mining_camp: MiningCamp = null
var ai_mill: Mill = null
var ai_market: Market = null
var decision_timer: float = 0.0
var attack_cooldown: float = 0.0  # Time until AI can attack again
const ATTACK_COOLDOWN_TIME: float = 30.0  # Seconds between attacks
var defending: bool = false  # True if AI military is responding to a threat

# Buildings under construction that need villagers
var buildings_under_construction: Array[Building] = []

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

	# Update attack cooldown
	if attack_cooldown > 0:
		attack_cooldown -= delta

	decision_timer += delta
	if decision_timer >= DECISION_INTERVAL:
		decision_timer = 0.0
		_make_decisions()

func _make_decisions() -> void:
	# Check if AI TC still exists - try to find it if we lost reference
	if not is_instance_valid(ai_tc) or ai_tc.is_destroyed:
		ai_tc = _find_ai_tc()
		if ai_tc == null:
			return  # No TC, AI has lost

	var villager_count = _get_ai_villagers().size()
	var military_count = _get_military_count()

	# === CONSTRUCTION PHASE (Priority 0) ===
	# Assign idle villagers to buildings under construction
	_manage_construction()

	# === ECONOMY PHASE (Priority 1) ===

	# 1. Train villagers continuously (critical for economy)
	if villager_count < TARGET_VILLAGERS:
		_train_villager()

	# 2. Build house if pop capped or close to cap
	var pop = GameManager.get_population(AI_TEAM)
	var cap = GameManager.get_population_cap(AI_TEAM)
	if pop >= cap - 2 and GameManager.can_afford("wood", 25, AI_TEAM):
		_build_house()

	# 3. Assign idle villagers to gather
	_assign_idle_villagers()

	# 4. Build mill for food drop-off efficiency (before farms)
	if not _has_mill() and GameManager.can_afford("wood", 100, AI_TEAM):
		if villager_count >= 6:  # Wait until we have some villagers
			_build_mill()

	# 5. Build farms for sustainable food
	if _should_build_farm():
		_build_farm()

	# 6. Build camps near resources
	_consider_building_camps()

	# === MILITARY PHASE (Priority 2) ===

	# 7. Build barracks (first military building)
	if not _has_barracks() and GameManager.can_afford("wood", 100, AI_TEAM):
		if villager_count >= 8:  # Wait for basic economy
			_build_barracks()

	# 8. Build archery range (after barracks, for mixed army)
	if not _has_archery_range() and _has_barracks() and GameManager.can_afford("wood", 175, AI_TEAM):
		if villager_count >= 12:
			_build_archery_range()

	# 9. Build stable (after archery range, for full army composition)
	if not _has_stable() and _has_archery_range() and GameManager.can_afford("wood", 175, AI_TEAM):
		if villager_count >= 15:
			_build_stable()

	# 10. Build second barracks for production scaling
	if _count_barracks() < 2 and villager_count >= 18 and GameManager.can_afford("wood", 100, AI_TEAM):
		if GameManager.get_resource("wood", AI_TEAM) > 200:  # Only if floating resources
			_build_barracks()

	# 11. Train military units (mixed composition)
	_train_military()

	# === ECONOMY SUPPORT (Priority 3) ===

	# 12. Build market if beneficial
	if not _has_market() and GameManager.can_afford("wood", 175, AI_TEAM):
		if villager_count >= 15 and _should_build_market():
			_build_market()

	# 13. Use market to balance resources
	if _has_market():
		_use_market()

	# 14. Rebuild destroyed critical buildings
	_consider_rebuilding()

	# === DEFENSE PHASE (Priority 4) ===

	# 15. Check for threats and defend
	_check_and_defend()

	# === ATTACK PHASE (Priority 5) ===

	# 16. Attack when economy is established and military is ready
	if not defending and _should_attack():
		_attack_player()

## Manage construction of buildings - assign idle villagers to incomplete buildings
func _manage_construction() -> void:
	# Clean up completed or destroyed buildings
	buildings_under_construction = buildings_under_construction.filter(func(b):
		return is_instance_valid(b) and not b.is_destroyed and not b.is_constructed
	)

	if buildings_under_construction.is_empty():
		return

	# Get idle villagers (not gathering, not building, not hunting)
	var idle_villagers: Array[Villager] = []
	for villager in _get_ai_villagers():
		if villager.current_state == Villager.State.IDLE:
			idle_villagers.append(villager)

	if idle_villagers.is_empty():
		return

	# Assign idle villagers to buildings that need more builders
	for building in buildings_under_construction:
		if idle_villagers.is_empty():
			break

		# Assign villagers to buildings with fewer than 2 builders
		while building.get_builder_count() < 2 and not idle_villagers.is_empty():
			var villager = idle_villagers.pop_back()
			villager.command_build(building)

func _train_villager() -> void:
	if not is_instance_valid(ai_tc) or ai_tc.is_destroyed:
		return
	if not ai_tc.is_functional():  # Only train from functional buildings
		return
	if ai_tc.is_training:
		return
	if not GameManager.can_add_population(AI_TEAM):
		return
	if not GameManager.can_afford("food", 50, AI_TEAM):
		return
	ai_tc.train_villager()

func _assign_idle_villagers() -> void:
	var ai_villagers = _get_ai_villagers()
	var idle_villagers = []

	for villager in ai_villagers:
		if villager.current_state == Villager.State.IDLE:
			idle_villagers.append(villager)

	if idle_villagers.is_empty():
		return

	# Count current villager allocation
	var allocation = _count_villager_allocation()

	for villager in idle_villagers:
		# Determine what resource this villager should gather based on allocation
		var needed_resource = _get_needed_resource(allocation)

		# First priority: hunt nearby animals for food (if we need food)
		if needed_resource == "food":
			var animal = _find_huntable_animal(villager.global_position)
			if animal:
				villager.command_hunt(animal)
				allocation["food"] += 1
				continue

		var resource = _find_resource_of_type(villager.global_position, needed_resource)
		if resource:
			villager.command_gather(resource)
			allocation[needed_resource] += 1
		else:
			# Fallback to any nearby resource
			resource = _find_nearest_resource(villager.global_position)
			if resource:
				villager.command_gather(resource)
				var res_type = resource.get_resource_type()
				allocation[res_type] += 1

func _count_villager_allocation() -> Dictionary:
	var allocation = {"food": 0, "wood": 0, "gold": 0, "stone": 0}
	var ai_villagers = _get_ai_villagers()

	for villager in ai_villagers:
		# Hunting always means food
		if villager.current_state == Villager.State.HUNTING:
			allocation["food"] += 1
		elif villager.current_state == Villager.State.GATHERING or villager.current_state == Villager.State.RETURNING:
			var res_type = villager.carried_resource_type
			if res_type in allocation:
				allocation[res_type] += 1

	return allocation

func _get_needed_resource(allocation: Dictionary) -> String:
	# Calculate how far each resource is from its target ratio
	var total_gatherers = allocation["food"] + allocation["wood"] + allocation["gold"] + allocation["stone"]
	if total_gatherers == 0:
		return "food"  # Default to food if no one is gathering

	# Calculate deficit for each resource (target - current)
	var food_deficit = FOOD_VILLAGERS - allocation["food"]
	var wood_deficit = WOOD_VILLAGERS - allocation["wood"]
	var gold_deficit = GOLD_VILLAGERS - allocation["gold"]
	var stone_deficit = STONE_VILLAGERS - allocation["stone"]

	# Also consider absolute resource levels (emergency needs)
	var food = GameManager.get_resource("food", AI_TEAM)
	var wood = GameManager.get_resource("wood", AI_TEAM)
	var gold = GameManager.get_resource("gold", AI_TEAM)

	# Emergency thresholds - override normal allocation
	if food < 50:
		return "food"
	if wood < 50:
		return "wood"

	# Return resource with highest deficit
	var max_deficit = food_deficit
	var needed = "food"

	if wood_deficit > max_deficit:
		max_deficit = wood_deficit
		needed = "wood"
	if gold_deficit > max_deficit:
		max_deficit = gold_deficit
		needed = "gold"
	if stone_deficit > max_deficit:
		max_deficit = stone_deficit
		needed = "stone"

	return needed

# Mill and Farm building functions
func _has_mill() -> bool:
	if is_instance_valid(ai_mill) and ai_mill.is_functional():
		return true
	var mills = get_tree().get_nodes_in_group("mills")
	for m in mills:
		if m.team == AI_TEAM and m.is_functional():
			ai_mill = m
			return true
	return false

func _build_mill() -> void:
	var builder = _find_idle_builder()
	if not builder:
		return

	if not GameManager.spend_resource("wood", 100, AI_TEAM):
		return

	var scene = load(MILL_SCENE_PATH)
	ai_mill = scene.instantiate()

	# Build mill near TC for farm clustering
	var offset = _find_building_spot(Vector2(64, 64))
	ai_mill.global_position = AI_BASE_POSITION + offset
	ai_mill.team = AI_TEAM

	get_parent().get_node("Buildings").add_child(ai_mill)

	# Start construction
	ai_mill.start_construction()
	builder.command_build(ai_mill)
	buildings_under_construction.append(ai_mill)

func _count_farms() -> int:
	var count = 0
	var farms = get_tree().get_nodes_in_group("farms")
	for farm in farms:
		if farm.team == AI_TEAM and not farm.is_destroyed:
			count += 1
	return count

func _should_build_farm() -> bool:
	# Don't build too many farms
	if _count_farms() >= TARGET_FARMS:
		return false

	# Need wood for farm (50)
	if not GameManager.can_afford("wood", 50, AI_TEAM):
		return false

	# Build farms when:
	# 1. Natural food sources are depleted
	# 2. We have villagers but low food income
	var food = GameManager.get_resource("food", AI_TEAM)
	var villager_count = _get_ai_villagers().size()

	# Check if natural food sources are scarce
	var has_natural_food = _has_natural_food_sources()

	# Build farm if: no natural food, or we have 10+ villagers and fewer farms than needed
	if not has_natural_food:
		return true
	if villager_count >= 10 and _count_farms() < 4:
		return true
	if villager_count >= 15 and _count_farms() < 6:
		return true

	return false

func _has_natural_food_sources() -> bool:
	# Check for huntable animals
	var animals = get_tree().get_nodes_in_group("animals")
	for animal in animals:
		if animal.is_dead:
			continue
		if animal is Wolf:
			continue
		# Check if animal is reasonably close to AI base
		if animal.global_position.distance_to(AI_BASE_POSITION) < 600:
			return true

	# Check for berry bushes
	var resources = get_tree().get_nodes_in_group("resources")
	for resource in resources:
		if resource is Farm:
			continue
		if resource.get_resource_type() == "food" and resource.has_resources():
			if resource.global_position.distance_to(AI_BASE_POSITION) < 500:
				return true

	return false

func _build_farm() -> void:
	var builder = _find_idle_builder()
	if not builder:
		return

	if not GameManager.spend_resource("wood", 50, AI_TEAM):
		return

	var scene = load(FARM_SCENE_PATH)
	var farm = scene.instantiate()

	# Find position near mill (if exists) or TC
	var base_pos = AI_BASE_POSITION
	if is_instance_valid(ai_mill) and not ai_mill.is_destroyed and ai_mill.is_functional():
		base_pos = ai_mill.global_position

	var pos = _find_farm_position(base_pos)
	farm.global_position = pos
	farm.team = AI_TEAM

	get_parent().get_node("Buildings").add_child(farm)

	# Start construction
	farm.start_construction()
	builder.command_build(farm)
	buildings_under_construction.append(farm)

func _find_farm_position(near_pos: Vector2) -> Vector2:
	# Farms are 2x2 (64x64 pixels)
	var farm_size = Vector2(64, 64)

	# Try positions in a grid around the base position
	var offsets = [
		Vector2(70, 0), Vector2(-70, 0), Vector2(0, 70), Vector2(0, -70),
		Vector2(70, 70), Vector2(-70, 70), Vector2(70, -70), Vector2(-70, -70),
		Vector2(140, 0), Vector2(-140, 0), Vector2(0, 140), Vector2(0, -140),
		Vector2(140, 70), Vector2(-140, 70), Vector2(140, -70), Vector2(-140, -70),
	]

	for offset in offsets:
		var pos = near_pos + offset
		if _is_valid_building_position(pos, farm_size):
			return pos

	# Fallback
	return near_pos + Vector2(80, 80)

func _find_resource_of_type(from_pos: Vector2, resource_type: String) -> Node:  # Returns ResourceNode or Farm
	var resources = get_tree().get_nodes_in_group("resources")
	var nearest: Node = null
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

func _find_nearest_resource(from_pos: Vector2) -> Node:  # Returns ResourceNode or Farm
	var resources = get_tree().get_nodes_in_group("resources")
	var nearest: Node = null
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
	if is_instance_valid(ai_lumber_camp) and ai_lumber_camp.is_functional():
		return true
	var camps = get_tree().get_nodes_in_group("lumber_camps")
	for c in camps:
		if c.team == AI_TEAM and c.is_functional():
			ai_lumber_camp = c
			return true
	return false

func _has_mining_camp() -> bool:
	if is_instance_valid(ai_mining_camp) and ai_mining_camp.is_functional():
		return true
	var camps = get_tree().get_nodes_in_group("mining_camps")
	for c in camps:
		if c.team == AI_TEAM and c.is_functional():
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
	var builder = _find_idle_builder()
	if not builder:
		return

	if not GameManager.spend_resource("wood", 100, AI_TEAM):
		return

	var scene = load(LUMBER_CAMP_SCENE_PATH)
	ai_lumber_camp = scene.instantiate()

	# Find valid position near the resource
	var pos = _find_valid_camp_position(near_pos, Vector2(64, 64))
	ai_lumber_camp.global_position = pos
	ai_lumber_camp.team = AI_TEAM

	get_parent().get_node("Buildings").add_child(ai_lumber_camp)

	# Start construction
	ai_lumber_camp.start_construction()
	builder.command_build(ai_lumber_camp)
	buildings_under_construction.append(ai_lumber_camp)

func _build_mining_camp(near_pos: Vector2) -> void:
	var builder = _find_idle_builder()
	if not builder:
		return

	if not GameManager.spend_resource("wood", 100, AI_TEAM):
		return

	var scene = load(MINING_CAMP_SCENE_PATH)
	ai_mining_camp = scene.instantiate()

	var pos = _find_valid_camp_position(near_pos, Vector2(64, 64))
	ai_mining_camp.global_position = pos
	ai_mining_camp.team = AI_TEAM

	get_parent().get_node("Buildings").add_child(ai_mining_camp)

	# Start construction
	ai_mining_camp.start_construction()
	builder.command_build(ai_mining_camp)
	buildings_under_construction.append(ai_mining_camp)

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
	# Find an idle villager to build
	var builder = _find_idle_builder()
	if not builder:
		return  # No available builder

	if not GameManager.spend_resource("wood", 25, AI_TEAM):
		return

	var house_scene = load(HOUSE_SCENE_PATH)
	var house = house_scene.instantiate()

	# Find a spot near the TC
	var offset = _find_building_spot(Vector2(64, 64))
	house.global_position = AI_BASE_POSITION + offset
	house.team = AI_TEAM

	get_parent().get_node("Buildings").add_child(house)

	# Start construction and assign builder
	house.start_construction()
	builder.command_build(house)
	buildings_under_construction.append(house)

func _has_barracks() -> bool:
	return _count_functional_barracks() > 0

func _count_barracks() -> int:
	return _count_functional_barracks()

func _refresh_barracks_list() -> void:
	# Remove invalid/destroyed barracks from list
	ai_barracks = ai_barracks.filter(func(b): return is_instance_valid(b) and not b.is_destroyed)

	# Add any barracks we don't have in our list
	var barracks_list = get_tree().get_nodes_in_group("barracks")
	for b in barracks_list:
		if b.team == AI_TEAM and not b.is_destroyed:
			if not ai_barracks.has(b):
				ai_barracks.append(b)

## Count only functional barracks (not under construction)
func _count_functional_barracks() -> int:
	_refresh_barracks_list()
	var count = 0
	for b in ai_barracks:
		if b.is_functional():
			count += 1
	return count

func _build_barracks() -> void:
	var builder = _find_idle_builder()
	if not builder:
		return

	if not GameManager.spend_resource("wood", 100, AI_TEAM):
		return

	var barracks_scene = load(BARRACKS_SCENE_PATH)
	var new_barracks = barracks_scene.instantiate()

	# Find a spot near the TC
	var offset = _find_building_spot(Vector2(96, 96))
	new_barracks.global_position = AI_BASE_POSITION + offset
	new_barracks.team = AI_TEAM

	get_parent().get_node("Buildings").add_child(new_barracks)
	ai_barracks.append(new_barracks)

	# Start construction
	new_barracks.start_construction()
	builder.command_build(new_barracks)
	buildings_under_construction.append(new_barracks)

# Archery Range functions
func _has_archery_range() -> bool:
	if is_instance_valid(ai_archery_range) and ai_archery_range.is_functional():
		return true
	var ranges = get_tree().get_nodes_in_group("archery_ranges")
	for r in ranges:
		if r.team == AI_TEAM and r.is_functional():
			ai_archery_range = r
			return true
	return false

func _build_archery_range() -> void:
	var builder = _find_idle_builder()
	if not builder:
		return

	if not GameManager.spend_resource("wood", 175, AI_TEAM):
		return

	var scene = load(ARCHERY_RANGE_SCENE_PATH)
	ai_archery_range = scene.instantiate()

	var offset = _find_building_spot(Vector2(96, 96))
	ai_archery_range.global_position = AI_BASE_POSITION + offset
	ai_archery_range.team = AI_TEAM

	get_parent().get_node("Buildings").add_child(ai_archery_range)

	# Start construction
	ai_archery_range.start_construction()
	builder.command_build(ai_archery_range)
	buildings_under_construction.append(ai_archery_range)

# Stable functions
func _has_stable() -> bool:
	if is_instance_valid(ai_stable) and ai_stable.is_functional():
		return true
	var stables = get_tree().get_nodes_in_group("stables")
	for s in stables:
		if s.team == AI_TEAM and s.is_functional():
			ai_stable = s
			return true
	return false

func _build_stable() -> void:
	var builder = _find_idle_builder()
	if not builder:
		return

	if not GameManager.spend_resource("wood", 175, AI_TEAM):
		return

	var scene = load(STABLE_SCENE_PATH)
	ai_stable = scene.instantiate()

	var offset = _find_building_spot(Vector2(96, 96))
	ai_stable.global_position = AI_BASE_POSITION + offset
	ai_stable.team = AI_TEAM

	get_parent().get_node("Buildings").add_child(ai_stable)

	# Start construction
	ai_stable.start_construction()
	builder.command_build(ai_stable)
	buildings_under_construction.append(ai_stable)

# Military training (mixed army composition)
func _train_military() -> void:
	if not GameManager.can_add_population(AI_TEAM):
		return

	# Get current military composition
	var militia_count = 0
	var spearman_count = 0
	var archer_count = 0
	var skirmisher_count = 0
	var scout_count = 0
	var cavalry_archer_count = 0

	var military = get_tree().get_nodes_in_group("military")
	for unit in military:
		if unit.team != AI_TEAM:
			continue
		if unit is Militia:
			militia_count += 1
		elif unit is Spearman:
			spearman_count += 1
		elif unit is Skirmisher:
			skirmisher_count += 1
		elif unit is Archer:
			archer_count += 1
		elif unit is CavalryArcher:
			cavalry_archer_count += 1
		elif unit is ScoutCavalry:
			scout_count += 1

	# Training priority based on what we have:
	# - Militia: baseline infantry (from Barracks)
	# - Spearman: anti-cavalry (from Barracks)
	# - Archer: ranged damage (from Archery Range)
	# - Skirmisher: anti-archer (from Archery Range)
	# - Scout Cavalry: fast harass (from Stable)
	# - Cavalry Archer: mobile ranged (from Stable)

	# Try to maintain rough balance: 40% infantry, 40% ranged (archers+skirms), 20% cavalry

	# Train from available buildings
	_refresh_barracks_list()

	var total_ranged = archer_count + skirmisher_count
	var total_cavalry = scout_count + cavalry_archer_count
	var total_military = militia_count + spearman_count + total_ranged + total_cavalry

	# Train from archery range (archers or skirmishers)
	if _has_archery_range() and ai_archery_range.is_functional() and not ai_archery_range.is_training:
		if total_military == 0 or total_ranged < total_military * 0.4:
			# Decide between archer and skirmisher
			# Mix in some skirmishers (about 1/3 of ranged units)
			if skirmisher_count < archer_count * 0.5 and skirmisher_count < 2:
				if GameManager.can_afford("food", 25, AI_TEAM) and GameManager.can_afford("wood", 35, AI_TEAM):
					ai_archery_range.train_skirmisher()
					return
			else:
				if GameManager.can_afford("wood", 25, AI_TEAM) and GameManager.can_afford("gold", 45, AI_TEAM):
					ai_archery_range.train_archer()
					return

	# Train from stable (scouts or cavalry archers)
	if _has_stable() and ai_stable.is_functional() and not ai_stable.is_training:
		if total_cavalry < 2 or (total_military > 0 and total_cavalry < total_military * 0.2):
			# Decide between scout and cavalry archer
			# Mix in some cavalry archers for ranged harassment
			if cavalry_archer_count < scout_count and cavalry_archer_count < 2:
				if GameManager.can_afford("wood", 40, AI_TEAM) and GameManager.can_afford("gold", 70, AI_TEAM):
					ai_stable.train_cavalry_archer()
					return
			else:
				if GameManager.can_afford("food", 80, AI_TEAM):
					ai_stable.train_scout_cavalry()
					return

	# Train from barracks (militia or spearman)
	for barracks in ai_barracks:
		if not is_instance_valid(barracks) or not barracks.is_functional():
			continue
		if barracks.is_training:
			continue

		# Decide between militia and spearman
		# Spearmen are good vs cavalry, militia is general purpose
		# For now, train mostly militia with some spearmen mixed in
		if spearman_count < militia_count * 0.5 and spearman_count < 3:
			# Train spearman
			if GameManager.can_afford("food", 35, AI_TEAM) and GameManager.can_afford("wood", 25, AI_TEAM):
				barracks.train_spearman()
				return
		else:
			# Train militia
			if GameManager.can_afford("food", 60, AI_TEAM) and GameManager.can_afford("wood", 20, AI_TEAM):
				barracks.train_militia()
				return

func _get_military_count() -> int:
	var count = 0
	var military_units = get_tree().get_nodes_in_group("military")
	for unit in military_units:
		if unit.team == AI_TEAM:
			count += 1
	return count

func _attack_player() -> void:
	attack_cooldown = ATTACK_COOLDOWN_TIME

	# Find primary attack target
	var target = _find_attack_target()
	if not target:
		return

	# Send all idle AI military to attack
	var military_units = get_tree().get_nodes_in_group("military")
	for unit in military_units:
		if unit.team != AI_TEAM:
			continue
		if unit.is_dead:
			continue
		# Only send units that aren't actively defending
		if _is_unit_idle_or_patrolling(unit):
			unit.command_attack(target)

## Find the best target to attack
func _find_attack_target() -> Node2D:
	# Priority 1: Player military units near AI base (threats)
	var threats = _get_player_units_near_base(300.0)
	if not threats.is_empty():
		return threats[0]

	# Priority 2: Player villagers (cripple economy)
	var player_villagers = _get_player_villagers()
	if not player_villagers.is_empty():
		# Find closest villager to AI base
		var nearest: Node2D = null
		var nearest_dist: float = INF
		for v in player_villagers:
			var dist = v.global_position.distance_to(AI_BASE_POSITION)
			if dist < nearest_dist:
				nearest_dist = dist
				nearest = v
		if nearest:
			return nearest

	# Priority 3: Player TC (win condition)
	var tcs = get_tree().get_nodes_in_group("town_centers")
	for tc in tcs:
		if tc.team == 0 and not tc.is_destroyed:
			return tc

	# Priority 4: Any player building
	var buildings = get_tree().get_nodes_in_group("buildings")
	for building in buildings:
		if building.team == 0 and not building.is_destroyed:
			return building

	return null

## Check if a unit is idle or just standing around
func _is_unit_idle_or_patrolling(unit: Node2D) -> bool:
	if unit.has_method("get") and "current_state" in unit:
		var state = unit.current_state
		# Most military units have State.IDLE = 0
		return state == 0  # IDLE state
	return true  # Assume idle if we can't check

func _get_ai_villagers() -> Array:
	var result = []
	var villagers = get_tree().get_nodes_in_group("villagers")
	for v in villagers:
		if v.team == AI_TEAM:
			result.append(v)
	return result

## Find an idle villager to use as a builder
func _find_idle_builder() -> Villager:
	var villagers = _get_ai_villagers()
	for v in villagers:
		if v.current_state == Villager.State.IDLE:
			return v
	return null

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

# Market functions
func _has_market() -> bool:
	if is_instance_valid(ai_market) and ai_market.is_functional():
		return true
	var markets = get_tree().get_nodes_in_group("markets")
	for m in markets:
		if m.team == AI_TEAM and m.is_functional():
			ai_market = m
			return true
	return false

func _should_build_market() -> bool:
	# Build market if we have significant surplus in some resources but not gold
	var wood = GameManager.get_resource("wood", AI_TEAM)
	var food = GameManager.get_resource("food", AI_TEAM)
	var gold = GameManager.get_resource("gold", AI_TEAM)
	var stone = GameManager.get_resource("stone", AI_TEAM)

	# Want market if we have surplus resources (>300) but low gold (<100)
	var has_surplus = (wood > 300 or food > 300 or stone > 200)
	var needs_gold = (gold < 100)

	return has_surplus and needs_gold

func _build_market() -> void:
	var builder = _find_idle_builder()
	if not builder:
		return

	if not GameManager.spend_resource("wood", 175, AI_TEAM):
		return

	var market_scene = load(MARKET_SCENE_PATH)
	ai_market = market_scene.instantiate()

	var offset = _find_building_spot(Vector2(96, 96))
	ai_market.global_position = AI_BASE_POSITION + offset
	ai_market.team = AI_TEAM

	get_parent().get_node("Buildings").add_child(ai_market)

	# Start construction
	ai_market.start_construction()
	builder.command_build(ai_market)
	buildings_under_construction.append(ai_market)

func _use_market() -> void:
	if not is_instance_valid(ai_market):
		return

	var wood = GameManager.get_resource("wood", AI_TEAM)
	var food = GameManager.get_resource("food", AI_TEAM)
	var gold = GameManager.get_resource("gold", AI_TEAM)
	var stone = GameManager.get_resource("stone", AI_TEAM)

	# Sell surplus resources for gold
	# Sell if we have > 400 of a resource
	if wood > 400 and GameManager.can_afford("wood", 100, AI_TEAM):
		ai_market.sell_resource("wood")
		return  # One transaction per decision cycle

	if food > 400 and GameManager.can_afford("food", 100, AI_TEAM):
		ai_market.sell_resource("food")
		return

	if stone > 300 and GameManager.can_afford("stone", 100, AI_TEAM):
		ai_market.sell_resource("stone")
		return

	# Buy resources we desperately need (if we have gold)
	# Only buy if gold > 150 (keep some reserve)
	if gold > 150:
		if wood < 50:
			ai_market.buy_resource("wood")
			return
		if food < 50:
			ai_market.buy_resource("food")
			return

# Defense functions
func _check_and_defend() -> void:
	# Check if there are enemy units near our base or attacking our stuff
	var threats = _get_player_units_near_base(400.0)

	if threats.is_empty():
		defending = false
		return

	# We have threats! Rally military to defend
	defending = true

	# Find nearest threat
	var nearest_threat: Node2D = null
	var nearest_dist: float = INF
	for threat in threats:
		var dist = threat.global_position.distance_to(AI_BASE_POSITION)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest_threat = threat

	if not nearest_threat:
		defending = false
		return

	# Send military to defend
	var military_units = get_tree().get_nodes_in_group("military")
	for unit in military_units:
		if unit.team != AI_TEAM:
			continue
		if unit.is_dead:
			continue
		# Only redirect idle units or units far from threats
		if _is_unit_idle_or_patrolling(unit):
			unit.command_attack(nearest_threat)

## Get player units near any AI building (threats)
func _get_player_units_near_base(radius: float) -> Array:
	var threats = []
	var ai_buildings = get_tree().get_nodes_in_group("buildings")
	var ai_building_positions: Array[Vector2] = []

	# Collect AI building positions
	for building in ai_buildings:
		if building.team == AI_TEAM and not building.is_destroyed:
			ai_building_positions.append(building.global_position)

	# Also include the TC position as fallback
	if ai_building_positions.is_empty():
		ai_building_positions.append(AI_BASE_POSITION)

	# Check player military units near any AI building
	var military = get_tree().get_nodes_in_group("military")
	for unit in military:
		if unit.team == 0 and not unit.is_dead:
			for pos in ai_building_positions:
				if unit.global_position.distance_to(pos) < radius:
					threats.append(unit)
					break  # Don't add same unit twice

	# Check player villagers near buildings (could be scouting or building)
	var villagers = get_tree().get_nodes_in_group("villagers")
	for v in villagers:
		if v.team == 0 and not v.is_dead:
			for pos in ai_building_positions:
				if v.global_position.distance_to(pos) < radius:
					threats.append(v)
					break  # Don't add same villager twice

	return threats

## Get all player villagers
func _get_player_villagers() -> Array:
	var result = []
	var villagers = get_tree().get_nodes_in_group("villagers")
	for v in villagers:
		if v.team == 0 and not v.is_dead:
			result.append(v)
	return result

# Attack decision
func _should_attack() -> bool:
	var villager_count = _get_ai_villagers().size()
	var military_count = _get_military_count()

	# Don't attack if economy isn't established
	if villager_count < MIN_VILLAGERS_FOR_ATTACK:
		return false

	# Don't attack without sufficient military
	if military_count < MIN_MILITARY_FOR_ATTACK:
		return false

	# Don't attack if on cooldown
	if attack_cooldown > 0:
		return false

	# Attack if we have a good military force
	return true

# Rebuilding destroyed buildings
func _consider_rebuilding() -> void:
	# Check if critical buildings need rebuilding

	# Rebuild barracks if all destroyed
	if not _has_barracks() and GameManager.can_afford("wood", 100, AI_TEAM):
		var villager_count = _get_ai_villagers().size()
		if villager_count >= 5:  # Only rebuild if we have economy
			_build_barracks()
			return

	# Rebuild archery range if destroyed and we had one
	if not _has_archery_range() and _has_barracks() and GameManager.can_afford("wood", 175, AI_TEAM):
		var villager_count = _get_ai_villagers().size()
		if villager_count >= 10:
			_build_archery_range()
			return

	# Rebuild stable if destroyed and we had one
	if not _has_stable() and _has_archery_range() and GameManager.can_afford("wood", 175, AI_TEAM):
		var villager_count = _get_ai_villagers().size()
		if villager_count >= 12:
			_build_stable()
			return

	# Rebuild mill if destroyed
	if not _has_mill() and GameManager.can_afford("wood", 100, AI_TEAM):
		if _count_farms() > 0:  # Only if we have farms that need it
			_build_mill()
			return

# Find AI TC if we lost reference
func _find_ai_tc() -> TownCenter:
	var tcs = get_tree().get_nodes_in_group("town_centers")
	for tc in tcs:
		if tc.team == AI_TEAM and not tc.is_destroyed:
			return tc
	return null
