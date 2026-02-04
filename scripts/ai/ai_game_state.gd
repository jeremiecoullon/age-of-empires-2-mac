extends RefCounted
class_name AIGameState

# =============================================================================
# AIGameState - Wrapper exposing game state to AI rules
# =============================================================================
#
# Rules don't access game objects directly - they go through this layer.
# This provides a clean interface and allows action de-duplication.
#
# Condition helpers: read-only queries about game state
# Action methods: queue intentions (de-duplicated, executed at end of tick)
#
# =============================================================================

const AI_TEAM: int = 1
const TILE_SIZE: int = 32

# Building scenes (preloaded to avoid runtime file I/O)
const HOUSE_SCENE: PackedScene = preload("res://scenes/buildings/house.tscn")
const BARRACKS_SCENE: PackedScene = preload("res://scenes/buildings/barracks.tscn")
const FARM_SCENE: PackedScene = preload("res://scenes/buildings/farm.tscn")
const MILL_SCENE: PackedScene = preload("res://scenes/buildings/mill.tscn")
const LUMBER_CAMP_SCENE: PackedScene = preload("res://scenes/buildings/lumber_camp.tscn")
const MINING_CAMP_SCENE: PackedScene = preload("res://scenes/buildings/mining_camp.tscn")
const MARKET_SCENE: PackedScene = preload("res://scenes/buildings/market.tscn")
const ARCHERY_RANGE_SCENE: PackedScene = preload("res://scenes/buildings/archery_range.tscn")
const STABLE_SCENE: PackedScene = preload("res://scenes/buildings/stable.tscn")

# Building costs (wood only for MVP)
const BUILDING_COSTS: Dictionary = {
	"house": {"wood": 25},
	"barracks": {"wood": 100},
	"farm": {"wood": 50},
	"mill": {"wood": 100},
	"lumber_camp": {"wood": 100},
	"mining_camp": {"wood": 100},
	"market": {"wood": 175},
	"archery_range": {"wood": 175},
	"stable": {"wood": 175}
}

# Building sizes (in pixels)
const BUILDING_SIZES: Dictionary = {
	"house": Vector2(64, 64),
	"barracks": Vector2(96, 96),
	"farm": Vector2(64, 64),
	"mill": Vector2(64, 64),
	"lumber_camp": Vector2(64, 64),
	"mining_camp": Vector2(64, 64),
	"market": Vector2(96, 96),
	"archery_range": Vector2(96, 96),
	"stable": Vector2(96, 96)
}

# Reference to controller (for accessing strategic numbers, timers, etc.)
var controller: Node = null

# Scene tree reference (set by controller)
var scene_tree: SceneTree = null

# Pending actions (de-duplicated)
var _pending_trains: Dictionary = {}  # unit_type -> count (max 1 per tick)
var _pending_builds: Dictionary = {}  # building_type -> placement_info
var _attack_requested: bool = false
var _pending_market_buys: Array[String] = []  # resource types to buy
var _pending_market_sells: Array[String] = []  # resource types to sell
var _pending_villager_assignments: Array = []  # [villager, target, assignment_type] tuples
var _assigned_villagers_this_tick: Dictionary = {}  # Track villagers already assigned to prevent double-assignment

# =============================================================================
# INITIALIZATION
# =============================================================================

func initialize(ai_controller: Node, tree: SceneTree) -> void:
	controller = ai_controller
	scene_tree = tree


func refresh() -> void:
	# Called at start of each tick to update cached state if needed
	# Currently no caching - all queries are live
	pass


# =============================================================================
# CONDITION HELPERS - Resources
# =============================================================================

func get_resource(type: String) -> int:
	return GameManager.get_resource(type, AI_TEAM)


func can_afford(costs: Dictionary) -> bool:
	for resource_type in costs:
		if get_resource(resource_type) < costs[resource_type]:
			return false
	return true


# =============================================================================
# CONDITION HELPERS - Population
# =============================================================================

func get_civilian_population() -> int:
	var count = 0
	for villager in scene_tree.get_nodes_in_group("villagers"):
		if villager.team == AI_TEAM and not villager.is_dead:
			count += 1
	return count


func get_military_population() -> int:
	var count = 0
	for unit in scene_tree.get_nodes_in_group("military"):
		if unit.team == AI_TEAM and not unit.is_dead:
			count += 1
	return count


func get_population() -> int:
	return GameManager.get_population(AI_TEAM)


func get_population_cap() -> int:
	return GameManager.get_population_cap(AI_TEAM)


func get_housing_headroom() -> int:
	# Room before hitting current cap
	return get_population_cap() - get_population()


func get_population_headroom() -> int:
	# Room before game limit (200 in AoE2, we'll use a simpler cap for now)
	const MAX_POPULATION = 200
	return MAX_POPULATION - get_population()


# =============================================================================
# CONDITION HELPERS - Unit/Building Counts
# =============================================================================

func get_unit_count(unit_type: String) -> int:
	var group_name = unit_type + "s" if not unit_type.ends_with("s") else unit_type
	# Handle special cases
	match unit_type:
		"villager":
			group_name = "villagers"
		"militia":
			group_name = "militia"  # Already plural-ish
		"spearman":
			group_name = "spearmen"
		"archer":
			group_name = "archers"
		"scout_cavalry", "scout":
			group_name = "scout_cavalry"
		"skirmisher":
			group_name = "skirmishers"
		"cavalry_archer":
			group_name = "cavalry_archers"

	var count = 0
	for unit in scene_tree.get_nodes_in_group(group_name):
		if unit.team == AI_TEAM and not unit.is_dead:
			count += 1
	return count


func get_building_count(building_type: String) -> int:
	var group_name = building_type
	# Handle plural group names
	match building_type:
		"house":
			group_name = "houses"
		"barracks":
			group_name = "barracks"
		"farm":
			group_name = "farms"
		"mill":
			group_name = "mills"
		"lumber_camp":
			group_name = "lumber_camps"
		"mining_camp":
			group_name = "mining_camps"
		"market":
			group_name = "markets"
		"archery_range":
			group_name = "archery_ranges"
		"stable":
			group_name = "stables"
		"town_center":
			group_name = "town_centers"

	var count = 0
	for building in scene_tree.get_nodes_in_group(group_name):
		if building.team == AI_TEAM and building.is_functional():
			count += 1
	return count


func get_idle_villager_count() -> int:
	var count = 0
	for villager in scene_tree.get_nodes_in_group("villagers"):
		if villager.team == AI_TEAM and not villager.is_dead:
			if villager.current_state == villager.State.IDLE:
				count += 1
	return count


# =============================================================================
# CONDITION HELPERS - Training/Building Checks
# =============================================================================

func can_train(unit_type: String) -> bool:
	# Check population space
	if not GameManager.can_add_population(AI_TEAM):
		return false

	# Check building exists, can train, and queue isn't too full
	# Limit AI queue to 3 to prevent over-committing resources
	const MAX_AI_QUEUE: int = 3

	match unit_type:
		"villager":
			var tc = _get_ai_town_center()
			if tc and tc.is_functional():
				if tc.get_queue_size() >= MAX_AI_QUEUE:
					return false
				return GameManager.can_afford("food", tc.VILLAGER_COST, AI_TEAM)
		"militia":
			var barracks = _get_ai_building("barracks")
			if barracks and barracks.is_functional():
				if barracks.get_queue_size() >= MAX_AI_QUEUE:
					return false
				return GameManager.can_afford("food", barracks.MILITIA_FOOD_COST, AI_TEAM) \
					and GameManager.can_afford("wood", barracks.MILITIA_WOOD_COST, AI_TEAM)
		"spearman":
			var barracks = _get_ai_building("barracks")
			if barracks and barracks.is_functional():
				if barracks.get_queue_size() >= MAX_AI_QUEUE:
					return false
				return GameManager.can_afford("food", barracks.SPEARMAN_FOOD_COST, AI_TEAM) \
					and GameManager.can_afford("wood", barracks.SPEARMAN_WOOD_COST, AI_TEAM)

	return false


func can_build(building_type: String) -> bool:
	if building_type not in BUILDING_COSTS:
		return false

	# Check resources
	if not can_afford(BUILDING_COSTS[building_type]):
		return false

	# Check if we have a villager to build
	if get_idle_villager_count() == 0:
		# Also check villagers that could be reassigned (gathering)
		if get_civilian_population() == 0:
			return false

	return true


# =============================================================================
# CONDITION HELPERS - Game State
# =============================================================================

func is_under_attack() -> bool:
	# Check if enemy military units are near any AI building
	const THREAT_DISTANCE: float = 300.0
	for building in scene_tree.get_nodes_in_group("buildings"):
		if building.team == AI_TEAM and not building.is_destroyed:
			for unit in scene_tree.get_nodes_in_group("military"):
				if unit.team != AI_TEAM and not unit.is_dead:
					if unit.global_position.distance_to(building.global_position) < THREAT_DISTANCE:
						return true
	return false


func get_game_time() -> float:
	return Time.get_ticks_msec() / 1000.0


# =============================================================================
# CONDITION HELPERS - Strategic Numbers
# =============================================================================

func get_sn(sn_name: String) -> int:
	return controller.strategic_numbers.get(sn_name, 0)


func set_sn(sn_name: String, value: int) -> void:
	controller.strategic_numbers[sn_name] = value


# =============================================================================
# CONDITION HELPERS - Goals (state variables)
# =============================================================================

func get_goal(goal_id: int) -> int:
	return controller.goals.get(goal_id, 0)


func set_goal(goal_id: int, value: int) -> void:
	controller.goals[goal_id] = value


# =============================================================================
# CONDITION HELPERS - Timers
# =============================================================================

func is_timer_triggered(timer_id: int) -> bool:
	if timer_id not in controller.timers:
		return false
	return get_game_time() >= controller.timers[timer_id]


func enable_timer(timer_id: int, seconds: float) -> void:
	controller.timers[timer_id] = get_game_time() + seconds


func disable_timer(timer_id: int) -> void:
	controller.timers.erase(timer_id)


# =============================================================================
# ACTION METHODS - Queue intentions (de-duplicated)
# =============================================================================

func train(unit_type: String) -> void:
	# Only queue one train per unit type per tick
	if unit_type not in _pending_trains:
		_pending_trains[unit_type] = 1


func build(building_type: String) -> void:
	# Only queue one build per building type per tick
	if building_type not in _pending_builds:
		_pending_builds[building_type] = {"near_resource": null}


func build_near_resource(building_type: String, resource_type: String) -> void:
	# Only queue one build per building type per tick
	if building_type not in _pending_builds:
		_pending_builds[building_type] = {"near_resource": resource_type}


func attack_now() -> void:
	_attack_requested = true


func market_buy(resource_type: String) -> void:
	## Queue a market buy action (will execute at end of tick)
	if resource_type not in _pending_market_buys:
		_pending_market_buys.append(resource_type)


func market_sell(resource_type: String) -> void:
	## Queue a market sell action (will execute at end of tick)
	if resource_type not in _pending_market_sells:
		_pending_market_sells.append(resource_type)


func assign_villager_to_sheep(villager: Node, sheep: Node) -> void:
	## Queue villager assignment to herd sheep
	# Prevent double-assignment of same villager
	if villager in _assigned_villagers_this_tick:
		return
	_assigned_villagers_this_tick[villager] = true
	_pending_villager_assignments.append([villager, sheep, "sheep"])


func assign_villager_to_hunt(villager: Node, animal: Node) -> void:
	## Queue villager assignment to hunt animal
	# Prevent double-assignment of same villager
	if villager in _assigned_villagers_this_tick:
		return
	_assigned_villagers_this_tick[villager] = true
	_pending_villager_assignments.append([villager, animal, "hunt"])


# =============================================================================
# ACTION EXECUTION
# =============================================================================

func execute_actions() -> void:
	# Execute training
	for unit_type in _pending_trains:
		_do_train(unit_type)

	# Execute building
	for building_type in _pending_builds:
		var info = _pending_builds[building_type]
		_do_build(building_type, info.get("near_resource"))

	# Execute attack
	if _attack_requested:
		_do_attack()

	# Execute market trades
	for resource_type in _pending_market_buys:
		_do_market_buy(resource_type)
	for resource_type in _pending_market_sells:
		_do_market_sell(resource_type)

	# Execute villager assignments
	for assignment in _pending_villager_assignments:
		var villager = assignment[0]
		var target = assignment[1]
		var assignment_type = assignment[2]
		_do_villager_assignment(villager, target, assignment_type)

	_clear_pending()


func _clear_pending() -> void:
	_pending_trains.clear()
	_pending_builds.clear()
	_attack_requested = false
	_pending_market_buys.clear()
	_pending_market_sells.clear()
	_pending_villager_assignments.clear()
	_assigned_villagers_this_tick.clear()


# =============================================================================
# ACTION IMPLEMENTATION
# =============================================================================

func _do_train(unit_type: String) -> void:
	match unit_type:
		"villager":
			var tc = _get_ai_town_center()
			if tc and tc.is_functional():
				tc.train_villager()
		"militia":
			var barracks = _get_ai_building("barracks")
			if barracks and barracks.is_functional():
				barracks.train_militia()
		"spearman":
			var barracks = _get_ai_building("barracks")
			if barracks and barracks.is_functional():
				barracks.train_spearman()


func _do_build(building_type: String, near_resource: Variant = null) -> void:
	# Find a position to build
	var pos = _find_build_position(building_type, near_resource)
	if pos == Vector2.ZERO:
		return  # No valid position found

	# Check cost
	if not can_afford(BUILDING_COSTS[building_type]):
		return

	# Get preloaded scene
	var scene = _get_building_scene(building_type)
	if not scene:
		return

	# Spend resources
	for resource_type in BUILDING_COSTS[building_type]:
		var amount = BUILDING_COSTS[building_type][resource_type]
		GameManager.spend_resource(resource_type, amount, AI_TEAM)

	# Instantiate building
	var building: Building = scene.instantiate() as Building
	building.global_position = pos
	building.team = AI_TEAM

	# Add to scene - find Buildings container
	var buildings_container = _get_buildings_container()
	buildings_container.add_child(building)

	# Start construction
	building.start_construction()

	# Assign a villager to build it
	_assign_builder(building)


func _get_buildings_container() -> Node:
	# Try to find the Buildings container in the scene
	var main = scene_tree.current_scene
	if main.has_node("Buildings"):
		return main.get_node("Buildings")
	# Fallback to root
	return main


func _do_attack() -> void:
	# Find attack target - prefer TC, fallback to any player building
	var target = _get_player_town_center()
	if not target:
		target = _get_any_player_building()
	if not target:
		return

	# Send all military to attack
	for unit in scene_tree.get_nodes_in_group("military"):
		if unit.team == AI_TEAM and not unit.is_dead:
			if unit.has_method("command_attack"):
				unit.command_attack(target)


func _get_any_player_building() -> Node:
	for building in scene_tree.get_nodes_in_group("buildings"):
		if building.team == 0 and not building.is_destroyed:
			return building
	return null


func _do_market_buy(resource_type: String) -> void:
	if not can_market_buy(resource_type):
		return
	# Use GameManager directly
	GameManager.market_buy(resource_type, AI_TEAM)


func _do_market_sell(resource_type: String) -> void:
	if not can_market_sell(resource_type):
		return
	GameManager.market_sell(resource_type, AI_TEAM)


func _do_villager_assignment(villager: Node, target: Node, assignment_type: String) -> void:
	if not is_instance_valid(villager) or villager.is_dead:
		return
	if not is_instance_valid(target):
		return

	match assignment_type:
		"sheep":
			# Herd sheep - use command_hunt (sheep are animals, not resources)
			villager.command_hunt(target)
		"hunt":
			# Hunt animal - use command_hunt
			villager.command_hunt(target)


# =============================================================================
# HELPER METHODS
# =============================================================================

func _get_ai_town_center() -> Node:
	for tc in scene_tree.get_nodes_in_group("town_centers"):
		if tc.team == AI_TEAM and not tc.is_destroyed:
			return tc
	return null


func _get_player_town_center() -> Node:
	for tc in scene_tree.get_nodes_in_group("town_centers"):
		if tc.team == 0 and not tc.is_destroyed:
			return tc
	return null


func _get_ai_building(building_type: String) -> Node:
	var group_name = building_type
	match building_type:
		"barracks":
			group_name = "barracks"
		"archery_range":
			group_name = "archery_ranges"
		"stable":
			group_name = "stables"
		"market":
			group_name = "markets"
		"mill":
			group_name = "mills"
		"lumber_camp":
			group_name = "lumber_camps"
		"mining_camp":
			group_name = "mining_camps"

	for building in scene_tree.get_nodes_in_group(group_name):
		if building.team == AI_TEAM and not building.is_destroyed:
			return building
	return null


func _get_ai_base_position() -> Vector2:
	var tc = _get_ai_town_center()
	if tc:
		return tc.global_position
	return Vector2(1700, 1700)  # Default AI base position


func _find_build_position(building_type: String, near_resource: Variant = null) -> Vector2:
	var base_pos = _get_ai_base_position()
	var size = BUILDING_SIZES.get(building_type, Vector2(64, 64))

	# If building near a resource, find a good spot near that resource
	if near_resource is String:
		# For mills, exclude farms to find natural food sources (berries)
		var exclude_farms = (building_type == "mill")
		var resource_pos = _find_nearest_resource_position(near_resource, exclude_farms)
		if resource_pos != Vector2.ZERO:
			base_pos = resource_pos

	# Try positions in expanding circles around base
	var max_radius = get_sn("sn_maximum_town_size") * TILE_SIZE
	if max_radius <= 0:
		max_radius = 24 * TILE_SIZE  # Default

	for radius in range(TILE_SIZE, max_radius, TILE_SIZE):
		for angle in range(0, 360, 45):
			var offset = Vector2(radius, 0).rotated(deg_to_rad(angle))
			var pos = base_pos + offset
			# Snap to grid
			pos.x = snapped(pos.x, TILE_SIZE) + TILE_SIZE / 2
			pos.y = snapped(pos.y, TILE_SIZE) + TILE_SIZE / 2

			if _is_valid_build_position(pos, size):
				return pos

	return Vector2.ZERO


func _find_nearest_resource_position(resource_type: String, exclude_farms: bool = false) -> Vector2:
	var base_pos = _get_ai_base_position()
	var nearest_pos = Vector2.ZERO
	var nearest_dist = INF

	var group_name = resource_type + "_resources"
	for resource in scene_tree.get_nodes_in_group(group_name):
		# Skip farms when looking for natural food sources (e.g., for mill placement)
		if exclude_farms and resource.is_in_group("farms"):
			continue
		if resource.has_resources():
			var dist = base_pos.distance_to(resource.global_position)
			if dist < nearest_dist:
				nearest_dist = dist
				nearest_pos = resource.global_position

	return nearest_pos


func _is_valid_build_position(pos: Vector2, size: Vector2) -> bool:
	var half_size = size / 2

	# Check collision with existing buildings
	for building in scene_tree.get_nodes_in_group("buildings"):
		var building_half_size = Vector2(building.size.x * TILE_SIZE, building.size.y * TILE_SIZE) / 2
		if abs(pos.x - building.global_position.x) < (half_size.x + building_half_size.x) and \
		   abs(pos.y - building.global_position.y) < (half_size.y + building_half_size.y):
			return false

	# Check collision with resources (farms are buildings, not blockers)
	for resource in scene_tree.get_nodes_in_group("resources"):
		if not resource.is_in_group("farms"):
			if pos.distance_to(resource.global_position) < half_size.x + 20:
				return false

	# Check map bounds (1920x1920)
	if pos.x - half_size.x < 0 or pos.x + half_size.x > 1920:
		return false
	if pos.y - half_size.y < 0 or pos.y + half_size.y > 1920:
		return false

	return true


func _get_building_scene(building_type: String) -> PackedScene:
	match building_type:
		"house":
			return HOUSE_SCENE
		"barracks":
			return BARRACKS_SCENE
		"farm":
			return FARM_SCENE
		"mill":
			return MILL_SCENE
		"lumber_camp":
			return LUMBER_CAMP_SCENE
		"mining_camp":
			return MINING_CAMP_SCENE
		"market":
			return MARKET_SCENE
		"archery_range":
			return ARCHERY_RANGE_SCENE
		"stable":
			return STABLE_SCENE
	return null


func _assign_builder(building: Node) -> void:
	# Find an idle villager to build
	var builder: Node = null

	for villager in scene_tree.get_nodes_in_group("villagers"):
		if villager.team == AI_TEAM and not villager.is_dead:
			if villager.current_state == villager.State.IDLE:
				builder = villager
				break

	# If no idle villager, reassign a gatherer
	if not builder:
		for villager in scene_tree.get_nodes_in_group("villagers"):
			if villager.team == AI_TEAM and not villager.is_dead:
				if villager.current_state == villager.State.GATHERING:
					builder = villager
					break

	if builder:
		builder.command_build(building)


# =============================================================================
# VILLAGER ASSIGNMENT
# =============================================================================

func get_villagers_by_task() -> Dictionary:
	var result = {
		"idle": [],
		"food": [],
		"wood": [],
		"gold": [],
		"stone": [],
		"building": []
	}

	for villager in scene_tree.get_nodes_in_group("villagers"):
		if villager.team != AI_TEAM or villager.is_dead:
			continue

		match villager.current_state:
			villager.State.IDLE:
				result["idle"].append(villager)
			villager.State.GATHERING, villager.State.RETURNING:
				var resource_type = villager.carried_resource_type
				if resource_type == "":
					resource_type = "food"  # Default
				if resource_type in result:
					result[resource_type].append(villager)
			villager.State.HUNTING:
				result["food"].append(villager)
			villager.State.BUILDING:
				result["building"].append(villager)

	return result


func assign_villager_to_resource(villager: Node, resource_type: String) -> void:
	# Find nearest resource of type
	var nearest_resource: Node = null
	var nearest_dist = INF

	var group_name = resource_type + "_resources"
	for resource in scene_tree.get_nodes_in_group(group_name):
		if resource.has_resources():
			var dist = villager.global_position.distance_to(resource.global_position)
			if dist < nearest_dist:
				nearest_dist = dist
				nearest_resource = resource

	if nearest_resource:
		villager.command_gather(nearest_resource)


# =============================================================================
# CONDITION HELPERS - Natural Food (Phase 3.1B)
# =============================================================================

func get_natural_food_count() -> int:
	## Returns count of natural food sources: berries, sheep, deer, boar (NOT farms)
	var count = 0

	# Berry bushes
	for resource in scene_tree.get_nodes_in_group("food_resources"):
		# Skip farms - they're in food_resources but not "natural"
		if resource.is_in_group("farms"):
			continue
		if resource.has_resources():
			count += 1

	# Sheep (herdable animals)
	count += get_sheep_count()

	# Huntable animals (deer, boar)
	count += get_huntable_count()

	return count


func get_sheep_count() -> int:
	## Returns count of sheep AI can gather (neutral or AI-owned, alive)
	var count = 0
	for animal in scene_tree.get_nodes_in_group("sheep"):
		if animal.is_dead:
			continue
		# Sheep are team -1 (neutral) until claimed, or owned by AI
		if animal.team == -1 or animal.team == AI_TEAM:
			count += 1
	return count


func get_huntable_count() -> int:
	## Returns count of huntable animals (deer, boar - alive)
	var count = 0

	# Deer
	for animal in scene_tree.get_nodes_in_group("deer"):
		if not animal.is_dead:
			count += 1

	# Boar
	for animal in scene_tree.get_nodes_in_group("boar"):
		if not animal.is_dead:
			count += 1

	return count


func get_nearest_sheep() -> Node:
	## Returns nearest sheep to AI base that AI can claim
	var base_pos = _get_ai_base_position()
	var nearest: Node = null
	var nearest_dist = INF

	for animal in scene_tree.get_nodes_in_group("sheep"):
		if animal.is_dead:
			continue
		if animal.team != -1 and animal.team != AI_TEAM:
			continue
		var dist = base_pos.distance_to(animal.global_position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = animal

	return nearest


func get_nearest_huntable() -> Node:
	## Returns nearest huntable animal (deer/boar) to AI base
	var base_pos = _get_ai_base_position()
	var nearest: Node = null
	var nearest_dist = INF

	for animal in scene_tree.get_nodes_in_group("deer"):
		if animal.is_dead:
			continue
		var dist = base_pos.distance_to(animal.global_position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = animal

	for animal in scene_tree.get_nodes_in_group("boar"):
		if animal.is_dead:
			continue
		var dist = base_pos.distance_to(animal.global_position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = animal

	return nearest


# =============================================================================
# CONDITION HELPERS - Drop-off Buildings (Phase 3.1B)
# =============================================================================

func has_drop_off_for(resource_type: String) -> bool:
	## Returns true if AI has any functional drop-off building for this resource
	for building in scene_tree.get_nodes_in_group("buildings"):
		if building.team != AI_TEAM:
			continue
		if building.is_destroyed or not building.is_functional():
			continue
		if building.is_drop_off_for(resource_type):
			return true
	return false


func get_nearest_drop_off_distance(resource_type: String, from_pos: Vector2) -> float:
	## Returns distance from position to nearest AI drop-off for resource type
	## Returns INF if no drop-off exists
	var nearest_dist = INF

	for building in scene_tree.get_nodes_in_group("buildings"):
		if building.team != AI_TEAM:
			continue
		if building.is_destroyed or not building.is_functional():
			continue
		if building.is_drop_off_for(resource_type):
			var dist = from_pos.distance_to(building.global_position)
			if dist < nearest_dist:
				nearest_dist = dist

	return nearest_dist


func get_average_wood_drop_distance() -> float:
	## Returns average distance from wood resources to nearest AI lumber drop-off
	## Used to decide if a new lumber camp is needed
	var total_dist = 0.0
	var count = 0

	for resource in scene_tree.get_nodes_in_group("wood_resources"):
		if not resource.has_resources():
			continue
		var dist = get_nearest_drop_off_distance("wood", resource.global_position)
		if dist < INF:
			total_dist += dist
			count += 1

	if count == 0:
		return INF
	return total_dist / count


func get_average_gold_drop_distance() -> float:
	## Returns average distance from gold to nearest AI mining drop-off
	var total_dist = 0.0
	var count = 0

	for resource in scene_tree.get_nodes_in_group("gold_resources"):
		if not resource.has_resources():
			continue
		var dist = get_nearest_drop_off_distance("gold", resource.global_position)
		if dist < INF:
			total_dist += dist
			count += 1

	if count == 0:
		return INF
	return total_dist / count


func get_average_stone_drop_distance() -> float:
	## Returns average distance from stone to nearest AI mining drop-off
	var total_dist = 0.0
	var count = 0

	for resource in scene_tree.get_nodes_in_group("stone_resources"):
		if not resource.has_resources():
			continue
		var dist = get_nearest_drop_off_distance("stone", resource.global_position)
		if dist < INF:
			total_dist += dist
			count += 1

	if count == 0:
		return INF
	return total_dist / count


func needs_lumber_camp() -> bool:
	## Returns true if AI should build a lumber camp (wood too far from drop-offs)
	const MAX_EFFICIENT_DISTANCE: float = 200.0  # pixels

	# Check if any wood resources exist
	var has_wood = false
	for resource in scene_tree.get_nodes_in_group("wood_resources"):
		if resource.has_resources():
			has_wood = true
			break

	if not has_wood:
		return false

	# Check if we have any wood drop-off
	if not has_drop_off_for("wood"):
		return true  # TC can accept wood but dedicated camp is better

	# Check if wood is too far from drop-offs
	return get_average_wood_drop_distance() > MAX_EFFICIENT_DISTANCE


func needs_mining_camp_for_gold() -> bool:
	## Returns true if AI should build a mining camp near gold
	const MAX_EFFICIENT_DISTANCE: float = 200.0

	# Only care if we're supposed to gather gold
	if get_sn("sn_gold_gatherer_percentage") <= 0:
		return false

	# Check if any gold exists
	var has_gold = false
	for resource in scene_tree.get_nodes_in_group("gold_resources"):
		if resource.has_resources():
			has_gold = true
			break

	if not has_gold:
		return false

	# Check distance
	return get_average_gold_drop_distance() > MAX_EFFICIENT_DISTANCE


func needs_mining_camp_for_stone() -> bool:
	## Returns true if AI should build a mining camp near stone
	const MAX_EFFICIENT_DISTANCE: float = 200.0

	# Only care if we're supposed to gather stone
	if get_sn("sn_stone_gatherer_percentage") <= 0:
		return false

	# Check if any stone exists
	var has_stone = false
	for resource in scene_tree.get_nodes_in_group("stone_resources"):
		if resource.has_resources():
			has_stone = true
			break

	if not has_stone:
		return false

	# Check distance
	return get_average_stone_drop_distance() > MAX_EFFICIENT_DISTANCE


func needs_mill() -> bool:
	## Returns true if AI should build a mill (food sources far from TC)
	const MAX_EFFICIENT_DISTANCE: float = 200.0

	# Check if natural food exists (berries primarily - mill is food drop-off)
	var nearest_food_dist = INF

	for resource in scene_tree.get_nodes_in_group("food_resources"):
		if resource.is_in_group("farms"):
			continue  # Skip farms
		if not resource.has_resources():
			continue
		var dist = get_nearest_drop_off_distance("food", resource.global_position)
		if dist < nearest_food_dist:
			nearest_food_dist = dist

	if nearest_food_dist == INF:
		return false  # No natural food

	return nearest_food_dist > MAX_EFFICIENT_DISTANCE


# =============================================================================
# CONDITION HELPERS - Market (Phase 3.1B)
# =============================================================================

func get_market_buy_price(resource_type: String) -> int:
	return GameManager.get_market_buy_price(resource_type)


func get_market_sell_price(resource_type: String) -> int:
	return GameManager.get_market_sell_price(resource_type)


func can_market_buy(resource_type: String) -> bool:
	## Returns true if AI can afford to buy this resource at market
	if resource_type == "gold":
		return false  # Can't buy gold

	# Need a market
	if get_building_count("market") == 0:
		return false

	var gold_cost = get_market_buy_price(resource_type)
	return get_resource("gold") >= gold_cost


func can_market_sell(resource_type: String) -> bool:
	## Returns true if AI has this resource to sell
	if resource_type == "gold":
		return false  # Can't sell gold for gold

	# Need a market
	if get_building_count("market") == 0:
		return false

	# Need at least 100 of the resource (standard trade amount)
	return get_resource(resource_type) >= 100
