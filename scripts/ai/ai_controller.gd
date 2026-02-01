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

const PLAYER_TEAM: int = 0
const AI_TEAM: int = 1
const AI_BASE_POSITION: Vector2 = Vector2(1700, 1700)
const PLAYER_BASE_POSITION: Vector2 = Vector2(480, 480)  # Approximate player start
const DECISION_INTERVAL: float = 1.0  # Faster decisions for competitive AI
const IDLE_CHECK_INTERVAL: float = 0.3  # Fast idle villager reassignment
const SCOUT_UPDATE_INTERVAL: float = 0.5  # How often to update scout behavior

# Economic thresholds
const TARGET_VILLAGERS: int = 30  # Higher target for competitive AI
const MIN_VILLAGERS_FOR_ATTACK: int = 15  # Minimum villagers before considering attack
const MIN_MILITARY_FOR_ATTACK: int = 5  # Minimum military before attacking
const TARGET_FARMS: int = 8  # More farms for sustainable food

# Production queue targets
const TC_QUEUE_TARGET: int = 2  # Keep 2 villagers queued at TC for continuous production
const MILITARY_QUEUE_TARGET: int = 2  # Keep 2 units queued at military buildings

# Villager allocation targets (approximate ratios for late game)
const FOOD_VILLAGERS: int = 10
const WOOD_VILLAGERS: int = 8
const GOLD_VILLAGERS: int = 6
const STONE_VILLAGERS: int = 2

# Production building scaling thresholds
const SECOND_BARRACKS_THRESHOLD: int = 18  # Villagers before 2nd barracks
const THIRD_BARRACKS_THRESHOLD: int = 25  # Villagers before 3rd barracks
const SECOND_RANGE_THRESHOLD: int = 22  # Villagers before 2nd archery range
const SECOND_STABLE_THRESHOLD: int = 25  # Villagers before 2nd stable

# Scouting constants
const SCOUT_CIRCLE_RADIUS: float = 300.0  # Initial scouting radius around base
const SCOUT_EXPAND_RADIUS: float = 150.0  # How much to expand each patrol cycle
const SCOUT_MAX_RADIUS: float = 1200.0  # Maximum scouting distance
const SHEEP_SEARCH_RADIUS: float = 500.0  # How far to look for sheep
const RESOURCE_SEARCH_RADIUS: float = 800.0  # How far to look for resources

# Threat assessment constants
const THREAT_MINOR: int = 1  # 1-2 enemy units
const THREAT_MODERATE: int = 2  # 3-5 enemy units
const THREAT_MAJOR: int = 3  # 6+ enemy units or siege

var ai_tc: TownCenter = null
var ai_barracks: Array[Barracks] = []  # Support multiple barracks
var ai_archery_ranges: Array[ArcheryRange] = []  # Support multiple ranges
var ai_stables: Array[Stable] = []  # Support multiple stables
var ai_lumber_camp: LumberCamp = null
var ai_mining_camp: MiningCamp = null
var ai_mill: Mill = null
var ai_market: Market = null
var decision_timer: float = 0.0
var idle_check_timer: float = 0.0  # Faster timer for idle villager checks
var attack_cooldown: float = 0.0  # Time until AI can attack again
const ATTACK_COOLDOWN_TIME: float = 30.0  # Seconds between attacks
var defending: bool = false  # True if AI military is responding to a threat

# Buildings under construction that need villagers
var buildings_under_construction: Array[Building] = []

# Build order system
var build_order: BuildOrder = null
var build_order_step: int = 0
var build_order_complete: bool = false
var pending_villager_assignments: Array[String] = []  # Resources to assign new villagers to
var last_villager_count: int = 0  # Track when new villager spawns

# Scouting system
enum ScoutState { IDLE, CIRCLING_BASE, EXPANDING, SEARCHING_ENEMY, RETURNING, COMBAT }
var scout_unit: ScoutCavalry = null  # Primary scout
var scout_state: ScoutState = ScoutState.IDLE
var scout_timer: float = 0.0
var current_scout_radius: float = SCOUT_CIRCLE_RADIUS
var scout_patrol_angle: float = 0.0  # Current angle in patrol circle
var scout_waypoint: Vector2 = Vector2.ZERO
var scout_found_enemy_base: bool = false

# Enemy tracking
var known_enemy_tc_position: Vector2 = Vector2.ZERO
var known_enemy_buildings: Array[Dictionary] = []  # [{position, type, last_seen_time}]
var estimated_enemy_army: Dictionary = {
	"militia": 0,
	"spearman": 0,
	"archer": 0,
	"skirmisher": 0,
	"scout_cavalry": 0,
	"cavalry_archer": 0,
	"villagers": 0,
	"total_military": 0
}
var last_enemy_sighting_time: float = 0.0
var enemy_army_last_position: Vector2 = Vector2.ZERO

# Resource locations discovered by scouting
var known_sheep_locations: Array[Vector2] = []
var known_gold_locations: Array[Vector2] = []
var known_stone_locations: Array[Vector2] = []

# Threat assessment
var current_threat_level: int = 0  # 0=none, 1=minor, 2=moderate, 3=major
var threat_position: Vector2 = Vector2.ZERO
var threat_units: Array[Node2D] = []  # Typed array for consistency

func _ready() -> void:
	# Wait a frame for the scene to be fully loaded
	await get_tree().process_frame
	_spawn_ai_base()
	_initialize_build_order()

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

	last_villager_count = 3

func _initialize_build_order() -> void:
	# Use the standard Dark Age build order for competitive AI
	build_order = BuildOrder.create_dark_age_build_order()
	build_order_step = 0
	build_order_complete = false
	pending_villager_assignments.clear()

func _process(delta: float) -> void:
	if GameManager.game_ended:
		return

	# Update attack cooldown
	if attack_cooldown > 0:
		attack_cooldown -= delta

	# Fast idle villager check (every 0.3s)
	idle_check_timer += delta
	if idle_check_timer >= IDLE_CHECK_INTERVAL:
		idle_check_timer = 0.0
		_check_idle_villagers()
		_check_new_villagers()

	# Scouting update (faster than decision loop for responsive scouts)
	scout_timer += delta
	if scout_timer >= SCOUT_UPDATE_INTERVAL:
		scout_timer = 0.0
		_update_scouting()
		_update_enemy_tracking()
		_assess_threats()

	# Regular decision loop
	decision_timer += delta
	if decision_timer >= DECISION_INTERVAL:
		decision_timer = 0.0
		if not build_order_complete:
			_execute_build_order()
		_make_decisions()

## Execute the current build order step
func _execute_build_order() -> void:
	if build_order == null or build_order_step >= build_order.size():
		build_order_complete = true
		return

	var step = build_order.get_step(build_order_step)
	if step == null:
		build_order_complete = true
		return

	var step_complete = false

	match step.type:
		BuildOrder.StepType.QUEUE_VILLAGER:
			step_complete = _execute_queue_villager(step.target_resource)

		BuildOrder.StepType.BUILD_BUILDING:
			step_complete = _execute_build_building(step.building_type)

		BuildOrder.StepType.WAIT_VILLAGERS:
			var current_vils = _get_ai_villagers().size()
			step_complete = current_vils >= step.count

		BuildOrder.StepType.WAIT_RESOURCES:
			var current_res = GameManager.get_resource(step.resource_type, AI_TEAM)
			step_complete = current_res >= step.count

		BuildOrder.StepType.ASSIGN_VILLAGERS:
			step_complete = _execute_assign_villagers(step.target_resource, step.count)

	if step_complete:
		build_order_step += 1

## Queue a villager with a pending resource assignment
func _execute_queue_villager(target_resource: String) -> bool:
	if not is_instance_valid(ai_tc) or ai_tc.is_destroyed:
		return false
	if not ai_tc.is_functional():
		return false
	if not GameManager.can_add_population(AI_TEAM):
		# Need house first - don't advance step
		return false
	if not GameManager.can_afford("food", 50, AI_TEAM):
		return false

	# Queue is full - wait for it to drain before advancing build order
	if ai_tc.get_queue_size() >= TC_QUEUE_TARGET:
		return false

	if ai_tc.train_villager():
		pending_villager_assignments.append(target_resource)
		return true

	return false

## Build a specific building type
func _execute_build_building(building_type: String) -> bool:
	var builder = _find_idle_builder()
	if not builder:
		return false  # Wait for builder

	match building_type:
		"house":
			if GameManager.can_afford("wood", 25, AI_TEAM):
				_build_house()
				return true
		"lumber_camp":
			if GameManager.can_afford("wood", 100, AI_TEAM):
				var wood_pos = _find_resource_cluster_position("wood")
				if wood_pos != Vector2.ZERO:
					_build_lumber_camp(wood_pos)
					return true
				else:
					# No wood cluster found, skip this step
					return true
		"mining_camp":
			if GameManager.can_afford("wood", 100, AI_TEAM):
				var gold_pos = _find_resource_cluster_position("gold")
				if gold_pos != Vector2.ZERO:
					_build_mining_camp(gold_pos)
					return true
				else:
					var stone_pos = _find_resource_cluster_position("stone")
					if stone_pos != Vector2.ZERO:
						_build_mining_camp(stone_pos)
						return true
					else:
						return true  # Skip if no minerals
		"mill":
			if GameManager.can_afford("wood", 100, AI_TEAM):
				_build_mill()
				return true
		"barracks":
			if GameManager.can_afford("wood", 100, AI_TEAM):
				_build_barracks()
				return true
		"archery_range":
			if GameManager.can_afford("wood", 175, AI_TEAM):
				_build_archery_range()
				return true
		"stable":
			if GameManager.can_afford("wood", 175, AI_TEAM):
				_build_stable()
				return true
		"farm":
			if GameManager.can_afford("wood", 50, AI_TEAM):
				_build_farm()
				return true
		"market":
			if GameManager.can_afford("wood", 175, AI_TEAM):
				_build_market()
				return true

	return false  # Not enough resources, wait

## Assign villagers to a specific resource
func _execute_assign_villagers(target_resource: String, count: int) -> bool:
	var allocation = _count_villager_allocation()
	var current_on_resource = allocation.get(target_resource, 0)

	if current_on_resource >= count:
		return true

	# Find idle villagers and assign them
	var idle_villagers = []
	for villager in _get_ai_villagers():
		if villager.current_state == Villager.State.IDLE:
			idle_villagers.append(villager)

	for villager in idle_villagers:
		if current_on_resource >= count:
			break
		var resource = _find_resource_of_type(villager.global_position, target_resource)
		if resource:
			villager.command_gather(resource)
			current_on_resource += 1

	return current_on_resource >= count

## Check for new villagers and assign them based on pending assignments
func _check_new_villagers() -> void:
	var villagers = _get_ai_villagers()
	var current_count = villagers.size()

	if current_count > last_villager_count and not pending_villager_assignments.is_empty():
		# New villager spawned! Assign based on pending
		# Find the newest idle villager (should be the one that just spawned)
		for villager in villagers:
			if villager.current_state == Villager.State.IDLE:
				var target_resource = pending_villager_assignments.pop_front()
				if target_resource:
					_assign_villager_to_resource(villager, target_resource)
				break

	last_villager_count = current_count

## Check and immediately reassign idle villagers
## Note: This only reassigns existing idle villagers, not newly spawned ones
## (newly spawned villagers are handled by _check_new_villagers with pending assignments)
func _check_idle_villagers() -> void:
	var villagers = _get_ai_villagers()
	var current_count = villagers.size()

	# Skip if we just spawned a new villager - let _check_new_villagers handle it
	if current_count > last_villager_count and not pending_villager_assignments.is_empty():
		return

	var allocation = _count_villager_allocation()

	for villager in villagers:
		if villager.current_state == Villager.State.IDLE:
			# Assign based on current allocation needs
			var needed = _get_needed_resource(allocation)
			_assign_villager_to_resource(villager, needed)
			allocation[needed] += 1  # Update allocation for next idle villager

## Assign a single villager to gather a specific resource type
func _assign_villager_to_resource(villager: Villager, resource_type: String) -> void:
	# For food, try hunting first
	if resource_type == "food":
		var animal = _find_huntable_animal(villager.global_position)
		if animal:
			villager.command_hunt(animal)
			return

	var resource = _find_resource_of_type(villager.global_position, resource_type)
	if resource:
		villager.command_gather(resource)
	else:
		# Fallback to any resource
		resource = _find_nearest_resource(villager.global_position)
		if resource:
			villager.command_gather(resource)

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

	# 1. CONTINUOUS VILLAGER PRODUCTION - keep TC queue at target level
	# This is critical: never idle the TC!
	_maintain_villager_production()

	# 2. Build house PROACTIVELY (before we're pop capped)
	# Check if we'll be capped soon (pop + queue >= cap - 2)
	var pop = GameManager.get_population(AI_TEAM)
	var cap = GameManager.get_population_cap(AI_TEAM)
	var queue_size = ai_tc.get_queue_size() if is_instance_valid(ai_tc) else 0
	if pop + queue_size >= cap - 2 and GameManager.can_afford("wood", 25, AI_TEAM):
		_build_house()

	# 3. Assign idle villagers (now handled by fast check, but backup here)
	if build_order_complete:
		_assign_idle_villagers()

	# 4. Build mill for food drop-off efficiency (before farms)
	if build_order_complete and not _has_mill() and GameManager.can_afford("wood", 100, AI_TEAM):
		if villager_count >= 6:
			_build_mill()

	# 5. Build farms for sustainable food
	if _should_build_farm():
		_build_farm()

	# 6. Build camps near resources
	if build_order_complete:
		_consider_building_camps()

	# === MILITARY PHASE (Priority 2) ===

	# 7. Build barracks (first military building) - after build order
	if build_order_complete and not _has_barracks() and GameManager.can_afford("wood", 100, AI_TEAM):
		if villager_count >= 8:
			_build_barracks()

	# 8. Build archery range (after barracks, for mixed army)
	if not _has_archery_range() and _has_barracks() and GameManager.can_afford("wood", 175, AI_TEAM):
		if villager_count >= 12:
			_build_archery_range()

	# 9. Build stable (after archery range, for full army composition)
	if not _has_stable() and _has_archery_range() and GameManager.can_afford("wood", 175, AI_TEAM):
		if villager_count >= 15:
			_build_stable()

	# === PRODUCTION BUILDING SCALING ===
	# Scale up military production when floating resources

	# 10. Build second barracks
	if _count_barracks() < 2 and villager_count >= SECOND_BARRACKS_THRESHOLD:
		if _is_floating_resources() and GameManager.can_afford("wood", 100, AI_TEAM):
			_build_barracks()

	# 11. Build third barracks (late game)
	if _count_barracks() < 3 and villager_count >= THIRD_BARRACKS_THRESHOLD:
		if _is_floating_resources() and GameManager.can_afford("wood", 100, AI_TEAM):
			_build_barracks()

	# 12. Build second archery range
	if _count_archery_ranges() < 2 and villager_count >= SECOND_RANGE_THRESHOLD:
		if _is_floating_resources() and GameManager.can_afford("wood", 175, AI_TEAM):
			_build_archery_range()

	# 13. Build second stable
	if _count_stables() < 2 and villager_count >= SECOND_STABLE_THRESHOLD:
		if _is_floating_resources() and GameManager.can_afford("wood", 175, AI_TEAM):
			_build_stable()

	# 14. Train military units (mixed composition) with queue maintenance
	_train_military()

	# === ECONOMY SUPPORT (Priority 3) ===

	# 15. Build market if beneficial
	if not _has_market() and GameManager.can_afford("wood", 175, AI_TEAM):
		if villager_count >= 15 and _should_build_market():
			_build_market()

	# 16. Use market to balance resources
	if _has_market():
		_use_market()

	# 17. Rebuild destroyed critical buildings
	_consider_rebuilding()

	# === DEFENSE PHASE (Priority 4) ===

	# 18. Check for threats and defend
	_check_and_defend()

	# === ATTACK PHASE (Priority 5) ===

	# 19. Attack when economy is established and military is ready
	if not defending and _should_attack():
		_attack_player()

## Maintain continuous villager production - keep TC queue at target level
func _maintain_villager_production() -> void:
	if not is_instance_valid(ai_tc) or ai_tc.is_destroyed:
		return
	if not ai_tc.is_functional():
		return

	var villager_count = _get_ai_villagers().size()

	# Keep producing until we hit target (very difficult AI aims for 30)
	if villager_count >= TARGET_VILLAGERS:
		return

	# Keep queue at target level (usually 2)
	var current_queue = ai_tc.get_queue_size()
	while current_queue < TC_QUEUE_TARGET:
		# Check population capacity each iteration (queue reservations)
		if not GameManager.can_add_population(AI_TEAM):
			break
		if not GameManager.can_afford("food", 50, AI_TEAM):
			break
		if ai_tc.train_villager():
			current_queue += 1
			# Track resource assignment for post-build-order villagers
			if build_order_complete:
				var allocation = _count_villager_allocation()
				var needed = _get_needed_resource(allocation)
				pending_villager_assignments.append(needed)
		else:
			break

## Check if AI is floating resources (should spend more)
func _is_floating_resources() -> bool:
	var wood = GameManager.get_resource("wood", AI_TEAM)
	var food = GameManager.get_resource("food", AI_TEAM)
	var gold = GameManager.get_resource("gold", AI_TEAM)

	# Floating if any resource exceeds 300 (should be spending it)
	return wood > 300 or food > 300 or gold > 300

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

# Archery Range functions (supports multiple)
func _has_archery_range() -> bool:
	return _count_archery_ranges() > 0

func _count_archery_ranges() -> int:
	_refresh_archery_ranges_list()
	var count = 0
	for r in ai_archery_ranges:
		if r.is_functional():
			count += 1
	return count

func _refresh_archery_ranges_list() -> void:
	ai_archery_ranges = ai_archery_ranges.filter(func(r): return is_instance_valid(r) and not r.is_destroyed)
	var ranges = get_tree().get_nodes_in_group("archery_ranges")
	for r in ranges:
		if r.team == AI_TEAM and not r.is_destroyed:
			if not ai_archery_ranges.has(r):
				ai_archery_ranges.append(r)

func _build_archery_range() -> void:
	var builder = _find_idle_builder()
	if not builder:
		return

	if not GameManager.spend_resource("wood", 175, AI_TEAM):
		return

	var scene = load(ARCHERY_RANGE_SCENE_PATH)
	var new_range = scene.instantiate()

	var offset = _find_building_spot(Vector2(96, 96))
	new_range.global_position = AI_BASE_POSITION + offset
	new_range.team = AI_TEAM

	get_parent().get_node("Buildings").add_child(new_range)
	ai_archery_ranges.append(new_range)

	# Start construction
	new_range.start_construction()
	builder.command_build(new_range)
	buildings_under_construction.append(new_range)

# Stable functions (supports multiple)
func _has_stable() -> bool:
	return _count_stables() > 0

func _count_stables() -> int:
	_refresh_stables_list()
	var count = 0
	for s in ai_stables:
		if s.is_functional():
			count += 1
	return count

func _refresh_stables_list() -> void:
	ai_stables = ai_stables.filter(func(s): return is_instance_valid(s) and not s.is_destroyed)
	var stables = get_tree().get_nodes_in_group("stables")
	for s in stables:
		if s.team == AI_TEAM and not s.is_destroyed:
			if not ai_stables.has(s):
				ai_stables.append(s)

func _build_stable() -> void:
	var builder = _find_idle_builder()
	if not builder:
		return

	if not GameManager.spend_resource("wood", 175, AI_TEAM):
		return

	var scene = load(STABLE_SCENE_PATH)
	var new_stable = scene.instantiate()

	var offset = _find_building_spot(Vector2(96, 96))
	new_stable.global_position = AI_BASE_POSITION + offset
	new_stable.team = AI_TEAM

	get_parent().get_node("Buildings").add_child(new_stable)
	ai_stables.append(new_stable)

	# Start construction
	new_stable.start_construction()
	builder.command_build(new_stable)
	buildings_under_construction.append(new_stable)

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

	# PRIORITY: Get at least one scout early for scouting duty
	# This is critical for Phase 3B scouting system
	if scout_count == 0 and _has_stable():
		_refresh_stables_list()
		for stable in ai_stables:
			if not is_instance_valid(stable) or not stable.is_functional():
				continue
			if stable.get_queue_size() >= MILITARY_QUEUE_TARGET:
				continue
			if GameManager.can_afford("food", 80, AI_TEAM):
				stable.train_scout_cavalry()
				scout_count += 1
				return  # Prioritize getting the scout

	# Training priority based on what we have:
	# - Militia: baseline infantry (from Barracks)
	# - Spearman: anti-cavalry (from Barracks)
	# - Archer: ranged damage (from Archery Range)
	# - Skirmisher: anti-archer (from Archery Range)
	# - Scout Cavalry: fast harass (from Stable)
	# - Cavalry Archer: mobile ranged (from Stable)

	# Target composition: 40% infantry, 40% ranged (archers+skirms), 20% cavalry

	# Refresh all building lists
	_refresh_barracks_list()
	_refresh_archery_ranges_list()
	_refresh_stables_list()

	var total_ranged = archer_count + skirmisher_count
	var total_cavalry = scout_count + cavalry_archer_count
	var total_military = militia_count + spearman_count + total_ranged + total_cavalry

	# Train from ALL archery ranges (maintain queue on each)
	for archery_range in ai_archery_ranges:
		if not is_instance_valid(archery_range) or not archery_range.is_functional():
			continue
		# Maintain queue at target level
		if archery_range.get_queue_size() >= MILITARY_QUEUE_TARGET:
			continue
		if total_military == 0 or total_ranged < total_military * 0.4:
			# Decide between archer and skirmisher
			if skirmisher_count < archer_count * 0.5 and skirmisher_count < 2:
				if GameManager.can_afford("food", 25, AI_TEAM) and GameManager.can_afford("wood", 35, AI_TEAM):
					archery_range.train_skirmisher()
					skirmisher_count += 1
			else:
				if GameManager.can_afford("wood", 25, AI_TEAM) and GameManager.can_afford("gold", 45, AI_TEAM):
					archery_range.train_archer()
					archer_count += 1

	# Train from ALL stables (maintain queue on each)
	for stable in ai_stables:
		if not is_instance_valid(stable) or not stable.is_functional():
			continue
		if stable.get_queue_size() >= MILITARY_QUEUE_TARGET:
			continue
		if total_cavalry < 2 or (total_military > 0 and total_cavalry < total_military * 0.2):
			# Decide between scout and cavalry archer
			if cavalry_archer_count < scout_count and cavalry_archer_count < 2:
				if GameManager.can_afford("wood", 40, AI_TEAM) and GameManager.can_afford("gold", 70, AI_TEAM):
					stable.train_cavalry_archer()
					cavalry_archer_count += 1
			else:
				if GameManager.can_afford("food", 80, AI_TEAM):
					stable.train_scout_cavalry()
					scout_count += 1

	# Train from ALL barracks (maintain queue on each)
	for barracks in ai_barracks:
		if not is_instance_valid(barracks) or not barracks.is_functional():
			continue
		if barracks.get_queue_size() >= MILITARY_QUEUE_TARGET:
			continue

		# Decide between militia and spearman
		# For now, train mostly militia with some spearmen mixed in
		if spearman_count < militia_count * 0.5 and spearman_count < 3:
			if GameManager.can_afford("food", 35, AI_TEAM) and GameManager.can_afford("wood", 25, AI_TEAM):
				barracks.train_spearman()
				spearman_count += 1
		else:
			if GameManager.can_afford("food", 60, AI_TEAM) and GameManager.can_afford("wood", 20, AI_TEAM):
				barracks.train_militia()
				militia_count += 1

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

	# Send all idle AI military to attack
	var military_units = get_tree().get_nodes_in_group("military")
	for unit in military_units:
		if unit.team != AI_TEAM:
			continue
		if unit.is_dead:
			continue
		# Don't pull scout from scouting duty
		if unit == scout_unit:
			continue
		# Only send units that aren't actively defending
		if _is_unit_idle_or_patrolling(unit):
			if target:
				unit.command_attack(target)
			else:
				# No specific target, but move to enemy base area
				var enemy_base = get_enemy_base_position()
				unit.move_to(enemy_base)

## Find the best target to attack
func _find_attack_target() -> Node2D:
	# Priority 1: Player military units near AI base (threats)
	var threats = _get_player_units_near_base(300.0)
	if not threats.is_empty():
		return threats[0]

	# Priority 2: Use scouted enemy location if known
	var enemy_base = get_enemy_base_position()

	# Priority 3: Player villagers near enemy base (cripple economy)
	var player_villagers = _get_player_villagers()
	if not player_villagers.is_empty():
		# Find villager closest to enemy base (where they likely are)
		var nearest: Node2D = null
		var nearest_dist: float = INF
		for v in player_villagers:
			var dist = v.global_position.distance_to(enemy_base)
			if dist < nearest_dist:
				nearest_dist = dist
				nearest = v
		if nearest:
			return nearest

	# Priority 4: Player TC at known location (win condition)
	if known_enemy_tc_position != Vector2.ZERO:
		var tcs = get_tree().get_nodes_in_group("town_centers")
		for tc in tcs:
			if tc.team == PLAYER_TEAM and not tc.is_destroyed:
				# Prefer the TC we scouted
				if tc.global_position.distance_to(known_enemy_tc_position) < 100.0:
					return tc
				return tc

	# Priority 5: Any known enemy building
	if not known_enemy_buildings.is_empty():
		# Attack most recently seen building
		var best_building: Node2D = null
		var best_time: float = 0.0
		for known in known_enemy_buildings:
			if known.last_seen_time > best_time:
				# Find the actual building at this position
				var buildings = get_tree().get_nodes_in_group("buildings")
				for b in buildings:
					if b.team == PLAYER_TEAM and not b.is_destroyed:
						if b.global_position.distance_to(known.position) < 50.0:
							best_building = b
							best_time = known.last_seen_time
							break
		if best_building:
			return best_building

	# Priority 6: Any player building we can find
	var buildings = get_tree().get_nodes_in_group("buildings")
	for building in buildings:
		if building.team == PLAYER_TEAM and not building.is_destroyed:
			return building

	# Priority 7: If all else fails, attack towards enemy base position
	# Return null and let units move to enemy base area
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
	# Use threat assessment from Phase 3B
	if current_threat_level == 0:
		defending = false
		return

	# We have threats! Response depends on threat level
	defending = true

	# Find the best target to defend against
	var defend_target = _find_priority_defend_target()
	if not defend_target:
		defending = false
		return

	# Determine how many units to send based on threat level
	var military_units = get_tree().get_nodes_in_group("military")
	var units_to_send = 0

	match current_threat_level:
		THREAT_MINOR:
			units_to_send = 2  # Send a couple units
		THREAT_MODERATE:
			units_to_send = 5  # Send a squad
		THREAT_MAJOR:
			units_to_send = 999  # Send everyone!

	var sent_count = 0
	for unit in military_units:
		if sent_count >= units_to_send:
			break
		if unit.team != AI_TEAM:
			continue
		if unit.is_dead:
			continue
		# Don't pull scout from scouting duty unless major threat
		if unit == scout_unit and current_threat_level < THREAT_MAJOR:
			continue
		# Only redirect idle units
		if _is_unit_idle_or_patrolling(unit):
			unit.command_attack(defend_target)
			sent_count += 1

## Find priority target for defense
func _find_priority_defend_target() -> Node2D:
	if threat_units.is_empty():
		return null

	# Priority: military > villagers
	# Within military: closest to TC first
	var best_target: Node2D = null
	var best_score: float = INF  # Lower is better

	var tc_pos = AI_BASE_POSITION
	if is_instance_valid(ai_tc):
		tc_pos = ai_tc.global_position

	for unit in threat_units:
		if not is_instance_valid(unit) or unit.is_dead:
			continue

		var dist = unit.global_position.distance_to(tc_pos)
		var score = dist

		# Military units are higher priority (lower score)
		if unit.is_in_group("military"):
			score -= 500.0

		if score < best_score:
			best_score = score
			best_target = unit

	return best_target

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
		if unit.team == PLAYER_TEAM and not unit.is_dead:
			for pos in ai_building_positions:
				if unit.global_position.distance_to(pos) < radius:
					threats.append(unit)
					break  # Don't add same unit twice

	# Check player villagers near buildings (could be scouting or building)
	var villagers = get_tree().get_nodes_in_group("villagers")
	for v in villagers:
		if v.team == PLAYER_TEAM and not v.is_dead:
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
		if v.team == PLAYER_TEAM and not v.is_dead:
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

	# Prefer to attack if we've scouted the enemy base
	if has_scouted_enemy_base():
		# We know where to attack - be more aggressive
		if military_count >= MIN_MILITARY_FOR_ATTACK:
			return true

	# If we haven't found enemy base, require larger army
	if not has_scouted_enemy_base():
		if military_count < MIN_MILITARY_FOR_ATTACK + 3:
			return false

	# Check if we have numerical advantage based on scouting
	if estimated_enemy_army.total_military > 0:
		# Only attack if we have more military
		if military_count <= estimated_enemy_army.total_military:
			return false

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

# ========================================
# SCOUTING SYSTEM (Phase 3B)
# ========================================

## Main scouting update - called every SCOUT_UPDATE_INTERVAL
func _update_scouting() -> void:
	# Ensure we have a scout assigned
	if not is_instance_valid(scout_unit) or scout_unit.is_dead:
		_assign_scout()
		if not is_instance_valid(scout_unit):
			return  # No scout available

	# Check if scout is in combat or under attack (ISSUE-002 fix)
	if scout_unit.current_state == ScoutCavalry.State.ATTACKING:
		scout_state = ScoutState.COMBAT
	elif scout_unit.current_hp < scout_unit.max_hp * 0.8 and scout_state != ScoutState.COMBAT and scout_state != ScoutState.RETURNING:
		# Scout took damage, likely under attack - flee
		scout_state = ScoutState.COMBAT

	# Handle scout based on current state
	match scout_state:
		ScoutState.IDLE:
			_scout_start_patrol()
		ScoutState.CIRCLING_BASE:
			_scout_circle_base()
		ScoutState.EXPANDING:
			_scout_expand()
		ScoutState.SEARCHING_ENEMY:
			_scout_search_enemy()
		ScoutState.RETURNING:
			_scout_return_to_base()
		ScoutState.COMBAT:
			_scout_handle_combat()

	# Record any sightings while scouting
	_record_sightings()

## Assign a scout cavalry unit for scouting duty
func _assign_scout() -> void:
	var scouts = get_tree().get_nodes_in_group("cavalry")
	var best_scout: ScoutCavalry = null

	for unit in scouts:
		if unit.team != AI_TEAM:
			continue
		if unit.is_dead:
			continue
		if unit is ScoutCavalry:
			# Prefer idle scouts, but take any available scout
			if unit.current_state == ScoutCavalry.State.IDLE:
				# Found idle scout - perfect
				scout_unit = unit
				scout_state = ScoutState.IDLE
				return
			elif best_scout == null:
				# Keep track of non-idle scout as backup
				best_scout = unit

	# No idle scout found, use backup if available
	if best_scout != null:
		scout_unit = best_scout
		scout_state = ScoutState.IDLE  # Will be corrected on next update
		return

	# No scout available yet
	scout_unit = null

## Start patrol around base
func _scout_start_patrol() -> void:
	if not is_instance_valid(scout_unit):
		return

	# Start by circling own base to find nearby resources/sheep
	scout_state = ScoutState.CIRCLING_BASE
	scout_patrol_angle = 0.0
	current_scout_radius = SCOUT_CIRCLE_RADIUS
	_set_scout_waypoint_on_circle()

## Scout in a circle around own base
func _scout_circle_base() -> void:
	if not is_instance_valid(scout_unit):
		scout_state = ScoutState.IDLE
		return

	# Check if scout reached waypoint or is close enough
	var dist_to_waypoint = scout_unit.global_position.distance_to(scout_waypoint)
	if dist_to_waypoint < 50.0:
		# Move to next point on circle
		scout_patrol_angle += PI / 4.0  # 45 degrees per step (8 points around circle)

		if scout_patrol_angle >= 2 * PI:
			# Completed circle, expand outward
			scout_patrol_angle = 0.0
			current_scout_radius += SCOUT_EXPAND_RADIUS

			if current_scout_radius >= SCOUT_MAX_RADIUS:
				# Start actively searching for enemy
				scout_state = ScoutState.SEARCHING_ENEMY
				return
			else:
				scout_state = ScoutState.EXPANDING

		_set_scout_waypoint_on_circle()
	elif scout_unit.current_state == ScoutCavalry.State.IDLE:
		# Scout is idle but not at waypoint - send again
		scout_unit.move_to(scout_waypoint)

## Continue expanding patrol radius
func _scout_expand() -> void:
	if not is_instance_valid(scout_unit):
		scout_state = ScoutState.IDLE
		return

	# Check if scout reached waypoint
	var dist_to_waypoint = scout_unit.global_position.distance_to(scout_waypoint)
	if dist_to_waypoint < 50.0:
		# Move to next point on expanded circle
		scout_patrol_angle += PI / 4.0

		if scout_patrol_angle >= 2 * PI:
			# Completed this radius, expand again
			scout_patrol_angle = 0.0
			current_scout_radius += SCOUT_EXPAND_RADIUS

			if current_scout_radius >= SCOUT_MAX_RADIUS or scout_found_enemy_base:
				scout_state = ScoutState.SEARCHING_ENEMY
				return

		_set_scout_waypoint_on_circle()
	elif scout_unit.current_state == ScoutCavalry.State.IDLE:
		scout_unit.move_to(scout_waypoint)

## Actively search for enemy base
func _scout_search_enemy() -> void:
	if not is_instance_valid(scout_unit):
		scout_state = ScoutState.IDLE
		return

	# If we found the enemy base, periodically check on it
	if scout_found_enemy_base and known_enemy_tc_position != Vector2.ZERO:
		# Scout towards enemy base to update intel
		var dist_to_enemy = scout_unit.global_position.distance_to(known_enemy_tc_position)

		if dist_to_enemy < 200.0:
			# We're near enemy base, scout has done their job
			# Return to safety and do another patrol
			scout_state = ScoutState.RETURNING
			return
		elif scout_unit.current_state == ScoutCavalry.State.IDLE:
			# Move towards enemy base, but stay at safe distance
			var direction = AI_BASE_POSITION.direction_to(known_enemy_tc_position)
			var target = known_enemy_tc_position - direction * 150.0  # Stay 150px away
			scout_unit.move_to(target)
	else:
		# Haven't found enemy base yet - search the map
		# Head towards expected player base location
		if scout_unit.current_state == ScoutCavalry.State.IDLE:
			scout_unit.move_to(PLAYER_BASE_POSITION)

		# Check if we're near player starting area
		var dist_to_player_area = scout_unit.global_position.distance_to(PLAYER_BASE_POSITION)
		if dist_to_player_area < 400.0:
			# We've reached player area, return and report
			scout_state = ScoutState.RETURNING

## Scout returns to base
func _scout_return_to_base() -> void:
	if not is_instance_valid(scout_unit):
		scout_state = ScoutState.IDLE
		return

	var dist_to_base = scout_unit.global_position.distance_to(AI_BASE_POSITION)

	if dist_to_base < 200.0:
		# Back at base, start a new patrol
		scout_state = ScoutState.IDLE
	elif scout_unit.current_state == ScoutCavalry.State.IDLE:
		scout_unit.move_to(AI_BASE_POSITION)

## Handle scout in combat (flee back to base)
func _scout_handle_combat() -> void:
	if not is_instance_valid(scout_unit):
		scout_state = ScoutState.IDLE
		return

	# If scout is fighting, let it finish or flee if HP low
	if scout_unit.current_hp < scout_unit.max_hp * 0.3:
		# Low HP, flee!
		scout_unit.move_to(AI_BASE_POSITION)
		scout_state = ScoutState.RETURNING
	elif scout_unit.current_state == ScoutCavalry.State.IDLE:
		# Combat ended, return to scouting
		scout_state = ScoutState.RETURNING

## Set scout waypoint on current patrol circle
func _set_scout_waypoint_on_circle() -> void:
	if not is_instance_valid(scout_unit):
		return

	var offset = Vector2(
		cos(scout_patrol_angle) * current_scout_radius,
		sin(scout_patrol_angle) * current_scout_radius
	)
	scout_waypoint = AI_BASE_POSITION + offset

	# Clamp to map bounds
	scout_waypoint.x = clampf(scout_waypoint.x, 50.0, 1870.0)
	scout_waypoint.y = clampf(scout_waypoint.y, 50.0, 1870.0)

	if is_instance_valid(scout_unit):
		scout_unit.move_to(scout_waypoint)

## Record sightings of resources, sheep, enemy units while scouting
func _record_sightings() -> void:
	if not is_instance_valid(scout_unit):
		return

	var scout_pos = scout_unit.global_position
	var sight_range = 200.0  # How far scout can "see"

	# Look for sheep
	_scan_for_sheep(scout_pos, sight_range)

	# Look for gold/stone deposits
	_scan_for_resources(scout_pos, sight_range)

	# Look for enemy base/buildings
	_scan_for_enemy_base(scout_pos, sight_range)

## Scan for sheep near scout
func _scan_for_sheep(scout_pos: Vector2, sight_range: float) -> void:
	var animals = get_tree().get_nodes_in_group("animals")
	for animal in animals:
		if not is_instance_valid(animal) or animal.is_dead:
			continue
		if animal is Sheep:
			var dist = scout_pos.distance_to(animal.global_position)
			if dist < sight_range:
				var pos = animal.global_position
				# Check if we already know about this location
				var known = false
				for known_pos in known_sheep_locations:
					if known_pos.distance_to(pos) < 50.0:
						known = true
						break
				if not known:
					known_sheep_locations.append(pos)

## Scan for gold/stone resources
func _scan_for_resources(scout_pos: Vector2, sight_range: float) -> void:
	var resources = get_tree().get_nodes_in_group("resources")
	for resource in resources:
		if not is_instance_valid(resource):
			continue
		if resource is Farm:
			continue

		var dist = scout_pos.distance_to(resource.global_position)
		if dist < sight_range:
			var pos = resource.global_position
			var res_type = resource.get_resource_type()

			if res_type == "gold":
				_add_known_location(known_gold_locations, pos)
			elif res_type == "stone":
				_add_known_location(known_stone_locations, pos)

## Add a location to a known locations array if not already known
func _add_known_location(locations: Array[Vector2], pos: Vector2) -> void:
	for known_pos in locations:
		if known_pos.distance_to(pos) < 50.0:
			return  # Already known
	locations.append(pos)

## Scan for enemy base and buildings
func _scan_for_enemy_base(scout_pos: Vector2, sight_range: float) -> void:
	var buildings = get_tree().get_nodes_in_group("buildings")
	for building in buildings:
		if not is_instance_valid(building) or building.is_destroyed:
			continue
		if building.team == PLAYER_TEAM:
			var dist = scout_pos.distance_to(building.global_position)
			if dist < sight_range:
				# Found enemy building!
				if building is TownCenter:
					known_enemy_tc_position = building.global_position
					scout_found_enemy_base = true

				# Add to known buildings
				_update_known_enemy_building(building)

## Update known enemy buildings list
func _update_known_enemy_building(building: Building) -> void:
	var pos = building.global_position
	var building_type = _get_building_type_string(building)
	var current_time = Time.get_ticks_msec() / 1000.0

	# Check if we already know about this building
	for i in range(known_enemy_buildings.size()):
		var known = known_enemy_buildings[i]
		if known.position.distance_to(pos) < 30.0:
			# Update last seen time
			known_enemy_buildings[i].last_seen_time = current_time
			return

	# New building discovered
	known_enemy_buildings.append({
		"position": pos,
		"type": building_type,
		"last_seen_time": current_time
	})

## Get building type as string (more reliable than get_class())
func _get_building_type_string(building: Building) -> String:
	if building is TownCenter:
		return "town_center"
	elif building is Barracks:
		return "barracks"
	elif building is ArcheryRange:
		return "archery_range"
	elif building is Stable:
		return "stable"
	elif building is Mill:
		return "mill"
	elif building is LumberCamp:
		return "lumber_camp"
	elif building is MiningCamp:
		return "mining_camp"
	elif building is Market:
		return "market"
	elif building is Farm:
		return "farm"
	elif building is House:
		return "house"
	return "unknown"

## Clean up stale known enemy buildings
func _cleanup_known_buildings() -> void:
	var current_time = Time.get_ticks_msec() / 1000.0
	var stale_threshold = 60.0  # Remove if not seen for 60 seconds

	var cleaned: Array[Dictionary] = []
	for known in known_enemy_buildings:
		# Keep if recently seen
		if current_time - known.last_seen_time < stale_threshold:
			cleaned.append(known)
			continue

		# If we can see that position now and building is gone, remove
		if _can_ai_see_position(known.position):
			# Check if building still exists at this position
			var found = false
			var buildings = get_tree().get_nodes_in_group("buildings")
			for b in buildings:
				if b.team == PLAYER_TEAM and not b.is_destroyed:
					if b.global_position.distance_to(known.position) < 50.0:
						found = true
						break
			if not found:
				continue  # Building is gone, don't add to cleaned list

		# Keep if we can't verify (fog of war)
		cleaned.append(known)

	known_enemy_buildings = cleaned

# ========================================
# ENEMY TRACKING (Phase 3B)
# ========================================

## Update enemy army tracking
func _update_enemy_tracking() -> void:
	# Reset estimates (clear existing dictionary instead of creating new one)
	for key in estimated_enemy_army:
		estimated_enemy_army[key] = 0

	# Periodically clean up stale building data
	_cleanup_known_buildings()

	# Count visible enemy units
	var military = get_tree().get_nodes_in_group("military")
	var enemy_military_positions: Array[Vector2] = []

	for unit in military:
		if not is_instance_valid(unit) or unit.is_dead:
			continue
		if unit.team != PLAYER_TEAM:
			continue

		# Check if we can "see" this unit (within sight of our units/buildings)
		if _can_ai_see_position(unit.global_position):
			enemy_military_positions.append(unit.global_position)
			estimated_enemy_army.total_military += 1

			# Categorize unit type
			if unit is Militia:
				estimated_enemy_army.militia += 1
			elif unit is Spearman:
				estimated_enemy_army.spearman += 1
			elif unit is Archer:
				estimated_enemy_army.archer += 1
			elif unit is Skirmisher:
				estimated_enemy_army.skirmisher += 1
			elif unit is ScoutCavalry:
				estimated_enemy_army.scout_cavalry += 1
			elif unit is CavalryArcher:
				estimated_enemy_army.cavalry_archer += 1

	# Track villagers separately
	var villagers = get_tree().get_nodes_in_group("villagers")
	for v in villagers:
		if not is_instance_valid(v) or v.is_dead:
			continue
		if v.team != PLAYER_TEAM:
			continue
		if _can_ai_see_position(v.global_position):
			estimated_enemy_army.villagers += 1

	# Update last position of enemy army
	if not enemy_military_positions.is_empty():
		# Calculate centroid of enemy military
		var sum = Vector2.ZERO
		for pos in enemy_military_positions:
			sum += pos
		enemy_army_last_position = sum / enemy_military_positions.size()
		last_enemy_sighting_time = Time.get_ticks_msec() / 1000.0

## Check if AI can "see" a position (within range of AI units/buildings)
func _can_ai_see_position(pos: Vector2) -> bool:
	var sight_range = 200.0  # Standard unit sight range

	# Check AI units
	var units = get_tree().get_nodes_in_group("units")
	for unit in units:
		if not is_instance_valid(unit) or unit.is_dead:
			continue
		if unit.team == AI_TEAM:
			if unit.global_position.distance_to(pos) < sight_range:
				return true

	# Check AI buildings
	var buildings = get_tree().get_nodes_in_group("buildings")
	for building in buildings:
		if not is_instance_valid(building) or building.is_destroyed:
			continue
		if building.team == AI_TEAM:
			if building.global_position.distance_to(pos) < sight_range:
				return true

	return false

## Get the dominant unit type in enemy army (for counter-play in Phase 3C)
func get_enemy_dominant_unit_type() -> String:
	var max_count = 0
	var dominant = "militia"  # Default

	if estimated_enemy_army.militia > max_count:
		max_count = estimated_enemy_army.militia
		dominant = "militia"
	if estimated_enemy_army.spearman > max_count:
		max_count = estimated_enemy_army.spearman
		dominant = "spearman"
	if estimated_enemy_army.archer > max_count:
		max_count = estimated_enemy_army.archer
		dominant = "archer"
	if estimated_enemy_army.skirmisher > max_count:
		max_count = estimated_enemy_army.skirmisher
		dominant = "skirmisher"
	if estimated_enemy_army.scout_cavalry > max_count:
		max_count = estimated_enemy_army.scout_cavalry
		dominant = "scout_cavalry"
	if estimated_enemy_army.cavalry_archer > max_count:
		max_count = estimated_enemy_army.cavalry_archer
		dominant = "cavalry_archer"

	return dominant

# ========================================
# THREAT ASSESSMENT (Phase 3B)
# ========================================

## Assess current threat level
func _assess_threats() -> void:
	threat_units.clear()
	current_threat_level = 0
	threat_position = Vector2.ZERO

	# Get all enemy units near AI base or buildings
	var all_threats = _get_all_threats_near_base(500.0)

	if all_threats.is_empty():
		return

	threat_units = all_threats

	# Calculate threat level based on unit count and composition
	var military_threats = 0
	var villager_threats = 0
	var threat_positions: Array[Vector2] = []

	for unit in all_threats:
		threat_positions.append(unit.global_position)
		if unit.is_in_group("military"):
			military_threats += 1
		else:
			villager_threats += 1

	# Calculate centroid of threats
	if not threat_positions.is_empty():
		var sum = Vector2.ZERO
		for pos in threat_positions:
			sum += pos
		threat_position = sum / threat_positions.size()

	# Determine threat level
	if military_threats >= 6:
		current_threat_level = THREAT_MAJOR
	elif military_threats >= 3:
		current_threat_level = THREAT_MODERATE
	elif military_threats >= 1:
		current_threat_level = THREAT_MINOR
	elif villager_threats >= 1:
		# Villagers scouting or attempting forward base
		current_threat_level = THREAT_MINOR

## Get all threats near any AI building
func _get_all_threats_near_base(radius: float) -> Array:
	var threats = []
	var ai_building_positions: Array[Vector2] = []

	# Collect AI building positions
	var buildings = get_tree().get_nodes_in_group("buildings")
	for building in buildings:
		if building.team == AI_TEAM and not building.is_destroyed:
			ai_building_positions.append(building.global_position)

	if ai_building_positions.is_empty():
		ai_building_positions.append(AI_BASE_POSITION)

	# Check all player units
	var units = get_tree().get_nodes_in_group("units")
	for unit in units:
		if not is_instance_valid(unit) or unit.is_dead:
			continue
		if unit.team != PLAYER_TEAM:
			continue

		for pos in ai_building_positions:
			if unit.global_position.distance_to(pos) < radius:
				threats.append(unit)
				break

	return threats

## Get the current threat level (for use in decision making)
func get_threat_level() -> int:
	return current_threat_level

## Check if enemy has more of a specific unit type than us
func enemy_has_more(unit_type: String) -> bool:
	var our_count = 0
	var their_count = estimated_enemy_army.get(unit_type, 0)

	var military = get_tree().get_nodes_in_group("military")
	for unit in military:
		if unit.team != AI_TEAM or unit.is_dead:
			continue

		match unit_type:
			"militia":
				if unit is Militia:
					our_count += 1
			"spearman":
				if unit is Spearman:
					our_count += 1
			"archer":
				if unit is Archer:
					our_count += 1
			"skirmisher":
				if unit is Skirmisher:
					our_count += 1
			"scout_cavalry":
				if unit is ScoutCavalry:
					our_count += 1
			"cavalry_archer":
				if unit is CavalryArcher:
					our_count += 1

	return their_count > our_count

## Get known enemy TC position (or estimate if not found)
func get_enemy_base_position() -> Vector2:
	if known_enemy_tc_position != Vector2.ZERO:
		return known_enemy_tc_position
	# Return estimated player start position
	return PLAYER_BASE_POSITION

## Check if we have scouted the enemy base
func has_scouted_enemy_base() -> bool:
	return scout_found_enemy_base
