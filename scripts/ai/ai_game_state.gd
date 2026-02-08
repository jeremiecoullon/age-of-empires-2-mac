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
const BLACKSMITH_SCENE: PackedScene = preload("res://scenes/buildings/blacksmith.tscn")
const MONASTERY_SCENE: PackedScene = preload("res://scenes/buildings/monastery.tscn")
const UNIVERSITY_SCENE: PackedScene = preload("res://scenes/buildings/university.tscn")
const OUTPOST_SCENE: PackedScene = preload("res://scenes/buildings/outpost.tscn")
const WATCH_TOWER_SCENE: PackedScene = preload("res://scenes/buildings/watch_tower.tscn")
const PALISADE_WALL_SCENE: PackedScene = preload("res://scenes/buildings/palisade_wall.tscn")
const STONE_WALL_SCENE: PackedScene = preload("res://scenes/buildings/stone_wall.tscn")
const GATE_SCENE: PackedScene = preload("res://scenes/buildings/gate.tscn")
var SIEGE_WORKSHOP_SCENE: PackedScene = null  # Loaded at init (new scene)

# Building costs
const BUILDING_COSTS: Dictionary = {
	"house": {"wood": 25},
	"barracks": {"wood": 100},
	"farm": {"wood": 50},
	"mill": {"wood": 100},
	"lumber_camp": {"wood": 100},
	"mining_camp": {"wood": 100},
	"market": {"wood": 175},
	"archery_range": {"wood": 175},
	"stable": {"wood": 175},
	"blacksmith": {"wood": 150},
	"monastery": {"wood": 175},
	"university": {"wood": 200},
	"outpost": {"wood": 25, "stone": 25},
	"watch_tower": {"wood": 25, "stone": 125},
	"palisade_wall": {"wood": 2},
	"stone_wall": {"stone": 5},
	"gate": {"stone": 30},
	"siege_workshop": {"wood": 200}
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
	"stable": Vector2(96, 96),
	"blacksmith": Vector2(96, 96),
	"monastery": Vector2(96, 96),
	"university": Vector2(96, 96),
	"outpost": Vector2(32, 32),
	"watch_tower": Vector2(32, 32),
	"palisade_wall": Vector2(32, 32),
	"stone_wall": Vector2(32, 32),
	"gate": Vector2(32, 32),
	"siege_workshop": Vector2(96, 96)
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
var _assigned_targets_this_tick: Dictionary = {}  # Track {target_instance_id: count} for pending assignments
var _pending_researches: Dictionary = {}  # tech_id -> building_type ("blacksmith" or "town_center")

# =============================================================================
# INITIALIZATION
# =============================================================================

func initialize(ai_controller: Node, tree: SceneTree) -> void:
	controller = ai_controller
	scene_tree = tree
	SIEGE_WORKSHOP_SCENE = load("res://scenes/buildings/siege_workshop.tscn")


func refresh() -> void:
	# Called at start of each tick to update cached state if needed
	# Currently no caching - all queries are live
	pass


# =============================================================================
# CONDITION HELPERS - Age
# =============================================================================

func get_age() -> int:
	return GameManager.get_age(AI_TEAM)


func can_advance_age() -> bool:
	return GameManager.can_advance_age(AI_TEAM)


func get_qualifying_building_count(target_age: int) -> int:
	return GameManager.get_qualifying_building_count(target_age, AI_TEAM)


func should_save_for_age() -> bool:
	## Returns true when the AI should pause non-essential spending to save for age advancement.
	## True when: all non-resource conditions met, can't yet afford, not under attack.
	var current_age = get_age()
	if current_age >= GameManager.AGE_IMPERIAL:
		return false
	var target_age = current_age + 1
	# Check non-resource conditions
	var min_vills: int
	if target_age == GameManager.AGE_FEUDAL:
		min_vills = 10
	elif target_age == GameManager.AGE_CASTLE:
		min_vills = 15
	else:
		min_vills = 20  # Imperial
	if get_civilian_population() < min_vills:
		return false
	if get_qualifying_building_count(target_age) < GameManager.AGE_REQUIRED_QUALIFYING_COUNT:
		return false
	# Already researching or can already afford — no need to save
	var tc = _get_ai_town_center()
	if tc and tc.is_researching_age:
		return false
	if GameManager.can_afford_age(target_age, AI_TEAM):
		return false
	# Don't save if under attack — survival first
	if is_under_attack():
		return false
	return true


func research_age(target_age: int) -> bool:
	## Start age research at AI Town Center
	var tc = _get_ai_town_center()
	if not tc or not tc.is_functional():
		return false
	if tc.is_researching_age:
		return false
	return tc.start_age_research(target_age)


# =============================================================================
# CONDITION HELPERS - Technology
# =============================================================================

func has_tech(tech_id: String) -> bool:
	return GameManager.has_tech(tech_id, AI_TEAM)


func can_research(tech_id: String) -> bool:
	return get_can_research_reason(tech_id) == "ok"


func get_can_research_reason(tech_id: String) -> String:
	## Returns "ok" if tech can be researched, otherwise the reason why not.
	if tech_id not in GameManager.TECHNOLOGIES:
		return "unknown_tech"
	if has_tech(tech_id):
		return "already_researched"
	if tech_id in _pending_researches:
		return "already_queued"
	var tech = GameManager.TECHNOLOGIES[tech_id]
	if get_age() < tech["age"]:
		return "requires_%s" % GameManager.AGE_NAMES[tech["age"]].to_lower().replace(" ", "_")
	var prereq = tech["requires"]
	if prereq != "" and not has_tech(prereq):
		return "requires_" + prereq
	# Check if building exists and is not already researching
	var building_type = tech["building"]
	if building_type == "blacksmith":
		var bs = _get_ai_blacksmith()
		if not bs:
			return "no_blacksmith"
		if bs.is_researching:
			return "building_busy"
	elif building_type == "town_center":
		var tc = _get_ai_town_center()
		if not tc:
			return "no_town_center"
		if tc.is_researching_age or tc.is_researching:
			return "building_busy"
	elif building_type == "monastery":
		var mon = _get_ai_monastery()
		if not mon:
			return "no_monastery"
		if mon.is_researching:
			return "building_busy"
	elif building_type == "university":
		var uni = _get_ai_university()
		if not uni:
			return "no_university"
		if uni.is_researching:
			return "building_busy"
	elif building_type == "siege_workshop":
		var sw = _get_ai_siege_workshop()
		if not sw:
			return "no_siege_workshop"
		if sw.is_researching:
			return "building_busy"
	elif building_type in ["barracks", "archery_range", "stable"]:
		var bldg = _get_ai_building(building_type)
		if not bldg:
			return "no_" + building_type
		if bldg.is_researching:
			return "building_busy"
	# Check cost
	for resource_type in tech["cost"]:
		if get_resource(resource_type) < tech["cost"][resource_type]:
			return "insufficient_" + resource_type
	return "ok"


func research_tech(tech_id: String) -> void:
	## Queue a tech research action for this tick.
	if tech_id in _pending_researches:
		return  # Already queued
	var tech = GameManager.TECHNOLOGIES[tech_id]
	_pending_researches[tech_id] = tech["building"]


func _count_researched_techs() -> int:
	## Returns the number of technologies the AI has researched
	return GameManager.ai_researched_techs.size()


func _get_ai_blacksmith() -> Blacksmith:
	## Returns first functional AI blacksmith, or null
	for bs in scene_tree.get_nodes_in_group("blacksmiths"):
		if bs.team == AI_TEAM and bs.is_functional():
			return bs
	return null


func _get_ai_monastery() -> Monastery:
	## Returns first functional AI monastery, or null
	for mon in scene_tree.get_nodes_in_group("monasteries"):
		if mon.team == AI_TEAM and mon.is_functional():
			return mon
	return null


func _get_ai_university() -> University:
	## Returns first functional AI university, or null
	for uni in scene_tree.get_nodes_in_group("universities"):
		if uni.team == AI_TEAM and uni.is_functional():
			return uni
	return null


func _get_ai_siege_workshop() -> SiegeWorkshop:
	## Returns first functional AI siege workshop, or null
	for sw in scene_tree.get_nodes_in_group("siege_workshops"):
		if sw.team == AI_TEAM and sw.is_functional():
			return sw
	return null


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
		"knight":
			group_name = "knights"
		"cavalier":
			group_name = "cavaliers"
		"paladin":
			group_name = "paladins"
		"two_handed_swordsman":
			group_name = "two_handed_swordsmen"
		"champion":
			group_name = "champions"
		"arbalester":
			group_name = "arbalesters"
		"capped_ram":
			group_name = "capped_rams"
		"siege_ram":
			group_name = "siege_rams"
		"monk":
			group_name = "monks"
		"battering_ram":
			group_name = "battering_rams"
		"mangonel":
			group_name = "mangonels"
		"scorpion":
			group_name = "scorpions"
		"onager":
			group_name = "onagers"
		"heavy_scorpion":
			group_name = "heavy_scorpions"
		"infantry":
			# Count all infantry: militia + spearmen
			var count = 0
			for unit in scene_tree.get_nodes_in_group("infantry"):
				if unit.team == AI_TEAM and not unit.is_dead:
					count += 1
			return count
		"ranged":
			# Count all ranged: archers + skirmishers + cavalry archers
			var count = 0
			for group in ["archers", "skirmishers", "cavalry_archers"]:
				for unit in scene_tree.get_nodes_in_group(group):
					if unit.team == AI_TEAM and not unit.is_dead:
						count += 1
			return count
		"cavalry":
			# Count all cavalry: scout_cavalry + cavalry_archers
			var count = 0
			for unit in scene_tree.get_nodes_in_group("cavalry"):
				if unit.team == AI_TEAM and not unit.is_dead:
					count += 1
			return count

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
		"blacksmith":
			group_name = "blacksmiths"
		"monastery":
			group_name = "monasteries"
		"university":
			group_name = "universities"
		"outpost":
			group_name = "outposts"
		"watch_tower":
			group_name = "watch_towers"
		"palisade_wall":
			group_name = "palisade_walls"
		"stone_wall":
			group_name = "stone_walls"
		"gate":
			group_name = "gates"
		"siege_workshop":
			group_name = "siege_workshops"
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
# CONDITION HELPERS - Enemy Unit Counts (for counter-unit decisions)
# =============================================================================

func get_enemy_unit_count(unit_type: String) -> int:
	## Returns count of enemy (player) units of specified type
	var group_name = unit_type
	match unit_type:
		"villager":
			group_name = "villagers"
		"militia":
			group_name = "militia"
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
		if unit.team != AI_TEAM and unit.team >= 0 and not unit.is_dead:
			count += 1
	return count


func get_enemy_cavalry_count() -> int:
	## Returns count of enemy cavalry units (scout cavalry + cavalry archers)
	## Used to decide whether to train spearmen (anti-cavalry)
	var count = 0
	for unit in scene_tree.get_nodes_in_group("cavalry"):
		if unit.team != AI_TEAM and unit.team >= 0 and not unit.is_dead:
			count += 1
	return count


func get_enemy_archer_count() -> int:
	## Returns count of enemy ranged units in the archers group.
	## Includes: archers, skirmishers, cavalry archers.
	## Used to decide whether to train skirmishers (anti-archer).
	var count = 0
	for unit in scene_tree.get_nodes_in_group("archers"):
		if unit.team != AI_TEAM and unit.team >= 0 and not unit.is_dead:
			count += 1
	return count


func get_enemy_infantry_count() -> int:
	## Returns count of enemy infantry units (militia + spearmen)
	var count = 0
	for unit in scene_tree.get_nodes_in_group("infantry"):
		if unit.team != AI_TEAM and unit.team >= 0 and not unit.is_dead:
			count += 1
	return count


# =============================================================================
# CONDITION HELPERS - Training/Building Checks
# =============================================================================

func can_train(unit_type: String) -> bool:
	return get_can_train_reason(unit_type) == "ok"


func get_can_train_reason(unit_type: String) -> String:
	## Returns "ok" if can train, otherwise returns the reason why not.
	## Used for debugging rule evaluation.
	const MAX_AI_QUEUE: int = 3

	# Check age requirement
	if not GameManager.is_unit_unlocked(unit_type, AI_TEAM):
		var required_age = GameManager.UNIT_AGE_REQUIREMENTS.get(unit_type, GameManager.AGE_DARK)
		return "requires_%s" % GameManager.AGE_NAMES[required_age].to_lower().replace(" ", "_")

	# Check population space
	if not GameManager.can_add_population(AI_TEAM):
		return "no_pop_space"

	match unit_type:
		"villager":
			var tc = _get_ai_town_center()
			if not tc:
				return "no_town_center"
			if not tc.is_functional():
				return "tc_not_functional"
			if tc.is_researching_age:
				return "tc_researching_age"
			if tc.get_queue_size() >= MAX_AI_QUEUE:
				return "queue_full"
			if not GameManager.can_afford("food", tc.VILLAGER_COST, AI_TEAM):
				return "insufficient_food"
			return "ok"
		"militia":
			var barracks = _get_ai_building("barracks")
			if not barracks:
				return "no_barracks"
			if not barracks.is_functional():
				return "barracks_not_functional"
			if barracks.get_queue_size() >= MAX_AI_QUEUE:
				return "queue_full"
			if not GameManager.can_afford("food", barracks.MILITIA_FOOD_COST, AI_TEAM):
				return "insufficient_food"
			if not GameManager.can_afford("wood", barracks.MILITIA_WOOD_COST, AI_TEAM):
				return "insufficient_wood"
			return "ok"
		"spearman":
			var barracks = _get_ai_building("barracks")
			if not barracks:
				return "no_barracks"
			if not barracks.is_functional():
				return "barracks_not_functional"
			if barracks.get_queue_size() >= MAX_AI_QUEUE:
				return "queue_full"
			if not GameManager.can_afford("food", barracks.SPEARMAN_FOOD_COST, AI_TEAM):
				return "insufficient_food"
			if not GameManager.can_afford("wood", barracks.SPEARMAN_WOOD_COST, AI_TEAM):
				return "insufficient_wood"
			return "ok"
		"archer":
			var archery_range = _get_ai_building("archery_range")
			if not archery_range:
				return "no_archery_range"
			if not archery_range.is_functional():
				return "archery_range_not_functional"
			if archery_range.get_queue_size() >= MAX_AI_QUEUE:
				return "queue_full"
			if not GameManager.can_afford("wood", archery_range.ARCHER_WOOD_COST, AI_TEAM):
				return "insufficient_wood"
			if not GameManager.can_afford("gold", archery_range.ARCHER_GOLD_COST, AI_TEAM):
				return "insufficient_gold"
			return "ok"
		"skirmisher":
			var archery_range = _get_ai_building("archery_range")
			if not archery_range:
				return "no_archery_range"
			if not archery_range.is_functional():
				return "archery_range_not_functional"
			if archery_range.get_queue_size() >= MAX_AI_QUEUE:
				return "queue_full"
			if not GameManager.can_afford("food", archery_range.SKIRMISHER_FOOD_COST, AI_TEAM):
				return "insufficient_food"
			if not GameManager.can_afford("wood", archery_range.SKIRMISHER_WOOD_COST, AI_TEAM):
				return "insufficient_wood"
			return "ok"
		"scout_cavalry":
			var stable = _get_ai_building("stable")
			if not stable:
				return "no_stable"
			if not stable.is_functional():
				return "stable_not_functional"
			if stable.get_queue_size() >= MAX_AI_QUEUE:
				return "queue_full"
			if not GameManager.can_afford("food", stable.SCOUT_CAVALRY_FOOD_COST, AI_TEAM):
				return "insufficient_food"
			return "ok"
		"cavalry_archer":
			var stable = _get_ai_building("stable")
			if not stable:
				return "no_stable"
			if not stable.is_functional():
				return "stable_not_functional"
			if stable.get_queue_size() >= MAX_AI_QUEUE:
				return "queue_full"
			if not GameManager.can_afford("wood", stable.CAVALRY_ARCHER_WOOD_COST, AI_TEAM):
				return "insufficient_wood"
			if not GameManager.can_afford("gold", stable.CAVALRY_ARCHER_GOLD_COST, AI_TEAM):
				return "insufficient_gold"
			return "ok"
		"knight":
			var stable = _get_ai_building("stable")
			if not stable:
				return "no_stable"
			if not stable.is_functional():
				return "stable_not_functional"
			if stable.get_queue_size() >= MAX_AI_QUEUE:
				return "queue_full"
			if not GameManager.can_afford("food", stable.KNIGHT_FOOD_COST, AI_TEAM):
				return "insufficient_food"
			if not GameManager.can_afford("gold", stable.KNIGHT_GOLD_COST, AI_TEAM):
				return "insufficient_gold"
			return "ok"

		"monk":
			var monastery = _get_ai_monastery()
			if not monastery:
				return "no_monastery"
			if not monastery.is_functional():
				return "monastery_not_functional"
			if monastery.get_queue_size() >= MAX_AI_QUEUE:
				return "queue_full"
			if not GameManager.can_afford("gold", monastery.MONK_GOLD_COST, AI_TEAM):
				return "insufficient_gold"
			return "ok"

		"battering_ram":
			var sw = _get_ai_siege_workshop()
			if not sw:
				return "no_siege_workshop"
			if not sw.is_functional():
				return "siege_workshop_not_functional"
			if sw.get_queue_size() >= MAX_AI_QUEUE:
				return "queue_full"
			if not GameManager.can_afford("wood", SiegeWorkshop.BATTERING_RAM_WOOD_COST, AI_TEAM):
				return "insufficient_wood"
			if not GameManager.can_afford("gold", SiegeWorkshop.BATTERING_RAM_GOLD_COST, AI_TEAM):
				return "insufficient_gold"
			return "ok"

		"mangonel":
			var sw = _get_ai_siege_workshop()
			if not sw:
				return "no_siege_workshop"
			if not sw.is_functional():
				return "siege_workshop_not_functional"
			if sw.get_queue_size() >= MAX_AI_QUEUE:
				return "queue_full"
			if not GameManager.can_afford("wood", SiegeWorkshop.MANGONEL_WOOD_COST, AI_TEAM):
				return "insufficient_wood"
			if not GameManager.can_afford("gold", SiegeWorkshop.MANGONEL_GOLD_COST, AI_TEAM):
				return "insufficient_gold"
			return "ok"

		"scorpion":
			var sw = _get_ai_siege_workshop()
			if not sw:
				return "no_siege_workshop"
			if not sw.is_functional():
				return "siege_workshop_not_functional"
			if sw.get_queue_size() >= MAX_AI_QUEUE:
				return "queue_full"
			if not GameManager.can_afford("wood", SiegeWorkshop.SCORPION_WOOD_COST, AI_TEAM):
				return "insufficient_wood"
			if not GameManager.can_afford("gold", SiegeWorkshop.SCORPION_GOLD_COST, AI_TEAM):
				return "insufficient_gold"
			return "ok"

	return "unknown_unit_type"


func can_build(building_type: String) -> bool:
	return get_can_build_reason(building_type) == "ok"


func get_can_build_reason(building_type: String) -> String:
	## Returns "ok" if can build, otherwise returns the reason why not.
	## Used for debugging rule evaluation.
	if building_type not in BUILDING_COSTS:
		return "unknown_building_type"

	# Check age requirement
	if not GameManager.is_building_unlocked(building_type, AI_TEAM):
		var required_age = GameManager.BUILDING_AGE_REQUIREMENTS.get(building_type, GameManager.AGE_DARK)
		return "requires_%s" % GameManager.AGE_NAMES[required_age].to_lower().replace(" ", "_")

	# Siege workshop requires a blacksmith
	if building_type == "siege_workshop":
		if get_building_count("blacksmith") == 0:
			return "requires_blacksmith"

	# Check resources
	var costs = BUILDING_COSTS[building_type]
	for resource_type in costs:
		if get_resource(resource_type) < costs[resource_type]:
			return "insufficient_" + resource_type

	# Check if we have a villager to build
	if get_idle_villager_count() == 0:
		if get_civilian_population() == 0:
			return "no_villagers"
		# We have villagers but none idle - can still reassign one
		# This is ok, so fall through

	return "ok"


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


func get_nearest_threat() -> Node:
	## Returns the nearest enemy military unit threatening an AI building
	## Returns null if no threats
	const THREAT_DISTANCE: float = 300.0
	var nearest_threat: Node = null
	var nearest_dist: float = INF

	var base_pos = _get_ai_base_position()

	for unit in scene_tree.get_nodes_in_group("military"):
		if unit.team != AI_TEAM and unit.team >= 0 and not unit.is_dead:
			# Check if this unit is near any AI building
			for building in scene_tree.get_nodes_in_group("buildings"):
				if building.team == AI_TEAM and not building.is_destroyed:
					if unit.global_position.distance_to(building.global_position) < THREAT_DISTANCE:
						# This unit is a threat - check if it's the nearest
						var dist = base_pos.distance_to(unit.global_position)
						if dist < nearest_dist:
							nearest_dist = dist
							nearest_threat = unit
						break  # Already confirmed as threat, check next unit

	return nearest_threat


func defend_against(threat: Node) -> void:
	## Commands all AI military units to attack the threatening unit
	if not is_instance_valid(threat) or threat.is_dead:
		return

	var units_sent = 0
	for unit in scene_tree.get_nodes_in_group("military"):
		if unit.team == AI_TEAM and not unit.is_dead:
			if unit.has_method("command_attack"):
				unit.command_attack(threat)
				units_sent += 1

	_log_action("defend", {"units": units_sent, "target": threat.name})


func get_game_time() -> float:
	# Use controller's game_time_elapsed which respects Engine.time_scale
	# This ensures timers work correctly at any time scale (e.g., 10x in tests)
	return controller.game_time_elapsed


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


func scout_to(target_position: Vector2) -> void:
	## Send an idle scout cavalry to the target position
	## Checks both scout_cavalry and light_cavalry groups (scouts upgrade to light cavalry)
	for group in ["scout_cavalry", "light_cavalry"]:
		for unit in scene_tree.get_nodes_in_group(group):
			if unit.team != AI_TEAM or unit.is_dead:
				continue
			if unit.current_state == unit.State.IDLE:
				unit.move_to(target_position)
				_log_action("scout", {"target": [int(target_position.x), int(target_position.y)]})
				return


func get_idle_scout() -> Node:
	## Returns an idle scout cavalry unit, or null if none available
	## Checks both scout_cavalry and light_cavalry groups (scouts upgrade to light cavalry)
	for group in ["scout_cavalry", "light_cavalry"]:
		for unit in scene_tree.get_nodes_in_group(group):
			if unit.team != AI_TEAM or unit.is_dead:
				continue
			if unit.current_state == unit.State.IDLE:
				return unit
	return null


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
	# Track target for gatherer count checks within same tick
	var target_id = sheep.get_instance_id()
	if target_id not in _assigned_targets_this_tick:
		_assigned_targets_this_tick[target_id] = 0
	_assigned_targets_this_tick[target_id] += 1


func assign_villager_to_hunt(villager: Node, animal: Node) -> void:
	## Queue villager assignment to hunt animal
	# Prevent double-assignment of same villager
	if villager in _assigned_villagers_this_tick:
		return
	_assigned_villagers_this_tick[villager] = true
	_pending_villager_assignments.append([villager, animal, "hunt"])
	# Track target for gatherer count checks within same tick
	var target_id = animal.get_instance_id()
	if target_id not in _assigned_targets_this_tick:
		_assigned_targets_this_tick[target_id] = 0
	_assigned_targets_this_tick[target_id] += 1


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

	# Execute tech research
	for tech_id in _pending_researches:
		_do_research(tech_id)

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
	_assigned_targets_this_tick.clear()
	_pending_researches.clear()


# =============================================================================
# ACTION IMPLEMENTATION
# =============================================================================

func _log_action(action_type: String, data: Dictionary) -> void:
	## Log an AI action for debugging/observability
	var log_data = {"t": snappedf(controller.game_time_elapsed, 0.1), "action": action_type}
	log_data.merge(data)
	var message = "AI_ACTION|" + JSON.stringify(log_data)
	# Use controller's logging method if available
	if controller and controller.has_method("_log"):
		controller._log(message)
	else:
		print(message)


func _do_train(unit_type: String) -> void:
	var success = false
	match unit_type:
		"villager":
			var tc = _get_ai_town_center()
			if tc and tc.is_functional():
				success = tc.train_villager()
		"militia":
			var barracks = _get_ai_building("barracks")
			if barracks and barracks.is_functional():
				success = barracks.train_militia()
		"spearman":
			var barracks = _get_ai_building("barracks")
			if barracks and barracks.is_functional():
				success = barracks.train_spearman()
		"archer":
			var archery_range = _get_ai_building("archery_range")
			if archery_range and archery_range.is_functional():
				success = archery_range.train_archer()
		"skirmisher":
			var archery_range = _get_ai_building("archery_range")
			if archery_range and archery_range.is_functional():
				success = archery_range.train_skirmisher()
		"scout_cavalry":
			var stable = _get_ai_building("stable")
			if stable and stable.is_functional():
				success = stable.train_scout_cavalry()
		"cavalry_archer":
			var stable = _get_ai_building("stable")
			if stable and stable.is_functional():
				success = stable.train_cavalry_archer()
		"knight":
			var stable = _get_ai_building("stable")
			if stable and stable.is_functional():
				success = stable.train_knight()
		"monk":
			var monastery = _get_ai_monastery()
			if monastery and monastery.is_functional():
				success = monastery.train_monk()
		"battering_ram":
			var sw = _get_ai_siege_workshop()
			if sw and sw.is_functional():
				success = sw.train_battering_ram()
		"mangonel":
			var sw = _get_ai_siege_workshop()
			if sw and sw.is_functional():
				success = sw.train_mangonel()
		"scorpion":
			var sw = _get_ai_siege_workshop()
			if sw and sw.is_functional():
				success = sw.train_scorpion()

	if success:
		_log_action("train", {"unit": unit_type})


func _do_build(building_type: String, near_resource: Variant = null) -> void:
	# Find a position to build
	var pos = _find_build_position(building_type, near_resource)
	if pos == Vector2.ZERO:
		_log_action("build_failed", {"building": building_type, "reason": "no_valid_position"})
		return  # No valid position found

	# Check cost
	if not can_afford(BUILDING_COSTS[building_type]):
		_log_action("build_failed", {"building": building_type, "reason": "cannot_afford"})
		return

	# Get preloaded scene
	var scene = _get_building_scene(building_type)
	if not scene:
		_log_action("build_failed", {"building": building_type, "reason": "no_scene"})
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

	_log_action("build", {"building": building_type, "pos": [int(pos.x), int(pos.y)]})


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
		_log_action("attack_failed", {"reason": "no_target"})
		return

	# Send all military to attack
	var units_sent = 0
	for unit in scene_tree.get_nodes_in_group("military"):
		if unit.team == AI_TEAM and not unit.is_dead:
			if unit.has_method("command_attack"):
				unit.command_attack(target)
				units_sent += 1

	_log_action("attack", {"units": units_sent, "target": target.name})


func _get_any_player_building() -> Node:
	for building in scene_tree.get_nodes_in_group("buildings"):
		if building.team == 0 and not building.is_destroyed:
			return building
	return null


func _do_market_buy(resource_type: String) -> void:
	if not can_market_buy(resource_type):
		return
	var price = get_market_buy_price(resource_type)
	GameManager.market_buy(resource_type, AI_TEAM)
	_log_action("market_buy", {"resource": resource_type, "gold_spent": price})


func _do_market_sell(resource_type: String) -> void:
	if not can_market_sell(resource_type):
		return
	var price = get_market_sell_price(resource_type)
	GameManager.market_sell(resource_type, AI_TEAM)
	_log_action("market_sell", {"resource": resource_type, "gold_gained": price})


func _do_villager_assignment(villager: Node, target: Node, assignment_type: String) -> void:
	if not is_instance_valid(villager) or villager.is_dead:
		return
	if not is_instance_valid(target):
		return

	# Don't reassign villagers that were assigned to build this tick
	# This prevents race conditions where gather_sheep overwrites a builder assignment
	if villager.current_state == villager.State.BUILDING:
		return

	match assignment_type:
		"sheep":
			# Herd sheep - use command_hunt (sheep are animals, not resources)
			villager.command_hunt(target)
		"hunt":
			# Hunt animal - use command_hunt
			villager.command_hunt(target)


func _do_research(tech_id: String) -> void:
	if tech_id not in GameManager.TECHNOLOGIES:
		return
	var tech = GameManager.TECHNOLOGIES[tech_id]
	var building_type = tech["building"]

	if building_type == "blacksmith":
		var bs = _get_ai_blacksmith()
		if bs and not bs.is_researching:
			if bs.start_research(tech_id):
				_log_action("research", {"tech": tech_id})
	elif building_type == "town_center":
		var tc = _get_ai_town_center()
		if tc and not tc.is_researching_age and not tc.is_researching:
			if tc.start_research(tech_id):
				_log_action("research", {"tech": tech_id})
	elif building_type == "monastery":
		var mon = _get_ai_monastery()
		if mon and not mon.is_researching:
			if mon.start_research(tech_id):
				_log_action("research", {"tech": tech_id})
	elif building_type == "university":
		var uni = _get_ai_university()
		if uni and not uni.is_researching:
			if uni.start_research(tech_id):
				_log_action("research", {"tech": tech_id})
	elif building_type == "siege_workshop":
		var sw = _get_ai_siege_workshop()
		if sw and not sw.is_researching:
			if sw.start_research(tech_id):
				_log_action("research", {"tech": tech_id})
	elif building_type in ["barracks", "archery_range", "stable"]:
		var bldg = _get_ai_building(building_type)
		if bldg and not bldg.is_researching:
			if bldg.start_research(tech_id):
				_log_action("research", {"tech": tech_id})


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
		"monastery":
			group_name = "monasteries"
		"university":
			group_name = "universities"
		"siege_workshop":
			group_name = "siege_workshops"
		"outpost":
			group_name = "outposts"
		"watch_tower":
			group_name = "watch_towers"
		"palisade_wall":
			group_name = "palisade_walls"
		"stone_wall":
			group_name = "stone_walls"
		"gate":
			group_name = "gates"

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
		# For drop-off buildings, only consider resources that are far from existing drop-offs
		var is_dropoff_building = building_type in ["mill", "lumber_camp", "mining_camp"]
		var resource_pos = _find_nearest_resource_position(near_resource, exclude_farms, is_dropoff_building)
		if resource_pos != Vector2.ZERO:
			base_pos = resource_pos
		else:
			# No valid resource found (or all resources already have nearby drop-offs)
			# Don't build - a drop-off building near TC is useless since TC already accepts drops
			return Vector2.ZERO

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


func _find_nearest_resource_position(resource_type: String, exclude_farms: bool = false, for_dropoff_building: bool = false) -> Vector2:
	## Find nearest resource of type. If for_dropoff_building is true, only consider
	## resources that are far from existing drop-offs (since those are the ones that
	## actually need a new drop-off building nearby).
	const MIN_DROPOFF_DISTANCE: float = 200.0  # Resources closer than this don't need a new drop-off

	var base_pos = _get_ai_base_position()
	var nearest_pos = Vector2.ZERO
	var nearest_dist = INF

	var group_name = resource_type + "_resources"
	for resource in scene_tree.get_nodes_in_group(group_name):
		# Skip farms when looking for natural food sources (e.g., for mill placement)
		if exclude_farms and resource.is_in_group("farms"):
			continue
		if not resource.has_resources():
			continue

		# For drop-off buildings, skip resources that are already close to a drop-off
		if for_dropoff_building:
			var dropoff_dist = get_nearest_drop_off_distance(resource_type, resource.global_position)
			if dropoff_dist < MIN_DROPOFF_DISTANCE:
				continue  # This resource already has a nearby drop-off, skip it

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
		"blacksmith":
			return BLACKSMITH_SCENE
		"monastery":
			return MONASTERY_SCENE
		"university":
			return UNIVERSITY_SCENE
		"outpost":
			return OUTPOST_SCENE
		"watch_tower":
			return WATCH_TOWER_SCENE
		"palisade_wall":
			return PALISADE_WALL_SCENE
		"stone_wall":
			return STONE_WALL_SCENE
		"gate":
			return GATE_SCENE
		"siege_workshop":
			return SIEGE_WORKSHOP_SCENE
	return null


func _assign_builder(building: Node) -> void:
	# Find an idle villager to build
	var builder: Node = null
	var builder_source = ""

	for villager in scene_tree.get_nodes_in_group("villagers"):
		if villager.team == AI_TEAM and not villager.is_dead:
			if villager.current_state == villager.State.IDLE:
				builder = villager
				builder_source = "idle"
				break

	# If no idle villager, reassign a gatherer
	if not builder:
		for villager in scene_tree.get_nodes_in_group("villagers"):
			if villager.team == AI_TEAM and not villager.is_dead:
				if villager.current_state == villager.State.GATHERING:
					builder = villager
					builder_source = "gatherer"
					break

	if builder:
		builder.command_build(building)
		_log_action("assign_builder", {"building": building.name, "source": builder_source})
	else:
		_log_action("assign_builder_failed", {"building": building.name, "reason": "no_available_villager"})


# =============================================================================
# VILLAGER ASSIGNMENT
# =============================================================================

func _get_current_gatherer_counts() -> Dictionary:
	## Returns {target_instance_id: count} for all resources currently being gathered/hunted.
	## Used to avoid clustering multiple villagers on the same resource.
	## Also counts RETURNING villagers - they will return to the same resource after drop-off.
	## Also counts pending assignments from this tick (not yet executed).
	var counts: Dictionary = {}

	for villager in scene_tree.get_nodes_in_group("villagers"):
		if villager.team != AI_TEAM or villager.is_dead:
			continue

		var target: Node = null

		# Count villagers in HUNTING, GATHERING, or RETURNING states
		# RETURNING villagers will go back to their target after dropping off resources
		if villager.current_state in [villager.State.HUNTING, villager.State.GATHERING, villager.State.RETURNING]:
			# Check hunting target (sheep, deer, boar) - for HUNTING or RETURNING from hunting
			if is_instance_valid(villager.target_animal):
				target = villager.target_animal
			# Check gathering/returning target (trees, berries, farms, gold, stone)
			elif is_instance_valid(villager.target_resource):
				target = villager.target_resource

		if target:
			var target_id = target.get_instance_id()
			if target_id not in counts:
				counts[target_id] = 0
			counts[target_id] += 1

	# Also count pending assignments from this tick (villagers queued but not yet executing)
	for target_id in _assigned_targets_this_tick:
		if target_id not in counts:
			counts[target_id] = 0
		counts[target_id] += _assigned_targets_this_tick[target_id]

	return counts


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
	# Get current gatherer counts to avoid clustering
	var gatherer_counts = _get_current_gatherer_counts()
	var max_gatherers = controller.strategic_numbers.get("sn_max_gatherers_per_resource", 2)
	var base_pos = _get_ai_base_position()

	# Distance thresholds for smart assignment
	const MAX_EFFICIENT_DISTANCE = 400.0  # Don't walk further than this for an "available" resource
	const PREFER_FULL_WITHIN = 200.0  # Prefer a nearby "full" resource over a distant "available" one
	const PREFER_FARMS_DISTANCE = 300.0  # If non-farm food is further than this from base, prefer farms

	# Find nearest resource of type that isn't at capacity
	var nearest_available: Node = null
	var nearest_available_dist = INF
	var nearest_any: Node = null  # Fallback if all resources are full
	var nearest_any_dist = INF
	# For food: track nearest farm separately
	var nearest_farm: Node = null
	var nearest_farm_dist = INF

	var group_name = resource_type + "_resources"
	var resources_found = 0
	var skipped_full = 0

	for resource in scene_tree.get_nodes_in_group(group_name):
		if resource.has_resources():
			resources_found += 1
			var dist = villager.global_position.distance_to(resource.global_position)

			# Track absolute nearest (fallback)
			if dist < nearest_any_dist:
				nearest_any_dist = dist
				nearest_any = resource

			# Farms are renewable - exempt from max_gatherers limit
			var is_farm = resource.is_in_group("farms")
			if is_farm:
				# Track nearest farm for food preference logic
				if dist < nearest_farm_dist:
					nearest_farm_dist = dist
					nearest_farm = resource
			else:
				# Check if this resource has capacity
				var target_id = resource.get_instance_id()
				var current_gatherers = gatherer_counts.get(target_id, 0)
				if current_gatherers >= max_gatherers:
					skipped_full += 1
					continue

			# Track nearest with available capacity
			if dist < nearest_available_dist:
				nearest_available_dist = dist
				nearest_available = resource

	# Smart distance-based selection
	var chosen_resource: Node = null
	var chosen_dist: float = INF
	var used_distance_override = false
	var used_farm_preference = false

	if nearest_available:
		# For food: ALWAYS prefer farms over non-farm food if farms exist
		# Farms are renewable, near base, and have drop-offs - much better than distant berries
		if resource_type == "food" and nearest_farm:
			var chosen_is_farm = nearest_available.is_in_group("farms")
			if not chosen_is_farm:
				# The nearest available food is NOT a farm - check if we should use farm instead
				var farm_dist_from_base = base_pos.distance_to(nearest_farm.global_position)
				# If farm is reasonably close to base, prefer it over any non-farm food
				if farm_dist_from_base < PREFER_FARMS_DISTANCE:
					chosen_resource = nearest_farm
					chosen_dist = nearest_farm_dist
					used_farm_preference = true

		# Standard distance-based selection if farm preference didn't apply
		if not chosen_resource:
			if nearest_available_dist > MAX_EFFICIENT_DISTANCE and nearest_any_dist < PREFER_FULL_WITHIN:
				# Available resource is far, but there's something close - use the close one
				chosen_resource = nearest_any
				chosen_dist = nearest_any_dist
				used_distance_override = true
			else:
				chosen_resource = nearest_available
				chosen_dist = nearest_available_dist
	else:
		# All resources at capacity - use nearest anyway
		chosen_resource = nearest_any
		chosen_dist = nearest_any_dist

	if chosen_resource:
		villager.command_gather(chosen_resource)
		# Track target for gatherer count checks within same tick
		var target_id = chosen_resource.get_instance_id()
		if target_id not in _assigned_targets_this_tick:
			_assigned_targets_this_tick[target_id] = 0
		_assigned_targets_this_tick[target_id] += 1
		_log_action("assign_villager", {
			"resource": resource_type,
			"found": resources_found,
			"skipped_full": skipped_full,
			"dist": int(chosen_dist),
			"fallback": nearest_available == null,
			"dist_override": used_distance_override,
			"farm_pref": used_farm_preference
		})
	else:
		_log_action("assign_villager_failed", {"resource": resource_type, "found": 0})


# =============================================================================
# CONDITION HELPERS - Resource Availability
# =============================================================================

func has_gatherable_resources(resource_type: String) -> bool:
	## Returns true if any gatherable resources of this type exist on the map.
	## Used for depletion awareness - don't try to assign villagers to depleted resource types.
	var group_name = resource_type + "_resources"
	for resource in scene_tree.get_nodes_in_group(group_name):
		if resource.has_resources():
			return true
	return false


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
	## Returns nearest sheep to AI base that AI can claim, preferring sheep with fewer gatherers
	## Uses smart distance thresholds to avoid long walks for "available" resources
	## Returns null if all sheep are too far (better to farm than walk across map)
	var base_pos = _get_ai_base_position()
	var gatherer_counts = _get_current_gatherer_counts()
	var max_gatherers = controller.strategic_numbers.get("sn_max_gatherers_per_resource", 2)

	# Distance thresholds for smart assignment
	const MAX_EFFICIENT_DISTANCE = 400.0
	const PREFER_FULL_WITHIN = 200.0
	const MAX_SHEEP_DISTANCE = 500.0  # Don't herd sheep further than this - inefficient

	var nearest_available: Node = null
	var nearest_available_dist = INF
	var nearest_any: Node = null  # Fallback if all sheep are full
	var nearest_any_dist = INF

	for animal in scene_tree.get_nodes_in_group("sheep"):
		if animal.is_dead:
			continue
		if animal.team != -1 and animal.team != AI_TEAM:
			continue

		var dist = base_pos.distance_to(animal.global_position)

		# Track absolute nearest (fallback)
		if dist < nearest_any_dist:
			nearest_any_dist = dist
			nearest_any = animal

		# Check if this animal has capacity
		var target_id = animal.get_instance_id()
		var current_gatherers = gatherer_counts.get(target_id, 0)
		if current_gatherers >= max_gatherers:
			continue

		# Track nearest with available capacity
		if dist < nearest_available_dist:
			nearest_available_dist = dist
			nearest_available = animal

	# Smart selection: if available sheep is far but there's one close, prefer close one
	if nearest_available:
		# Don't herd if too far - better to farm or gather berries
		if nearest_available_dist > MAX_SHEEP_DISTANCE:
			return null
		if nearest_available_dist > MAX_EFFICIENT_DISTANCE and nearest_any_dist < PREFER_FULL_WITHIN:
			return nearest_any
		return nearest_available

	# Graceful degradation: if all sheep are at capacity, use nearest
	# But apply a hard cap to prevent excessive piling (2x normal limit)
	if nearest_any:
		# Don't herd if too far
		if nearest_any_dist > MAX_SHEEP_DISTANCE:
			return null
		var any_id = nearest_any.get_instance_id()
		var any_count = gatherer_counts.get(any_id, 0)
		if any_count >= max_gatherers * 2:
			return null  # Too crowded, don't pile more
	return nearest_any


func has_nearby_farms() -> bool:
	## Returns true if AI has functional farms near the base (within drop-off range of TC/mill)
	## Used to decide whether to hunt or farm
	var base_pos = _get_ai_base_position()
	const MAX_FARM_DISTANCE = 300.0  # Farms should be near base

	for farm in scene_tree.get_nodes_in_group("farms"):
		if farm.team != AI_TEAM:
			continue
		if not farm.is_functional():
			continue
		if not farm.has_resources():
			continue
		var dist = base_pos.distance_to(farm.global_position)
		if dist < MAX_FARM_DISTANCE:
			return true
	return false


func get_nearest_huntable_distance() -> float:
	## Returns distance to nearest huntable animal from AI base
	## Returns INF if no huntables exist
	var base_pos = _get_ai_base_position()
	var nearest_dist = INF

	for animal in scene_tree.get_nodes_in_group("deer"):
		if not animal.is_dead:
			var dist = base_pos.distance_to(animal.global_position)
			if dist < nearest_dist:
				nearest_dist = dist

	for animal in scene_tree.get_nodes_in_group("boar"):
		if not animal.is_dead:
			var dist = base_pos.distance_to(animal.global_position)
			if dist < nearest_dist:
				nearest_dist = dist

	return nearest_dist


func get_nearest_huntable() -> Node:
	## Returns nearest huntable animal (deer/boar) to AI base, preferring animals with fewer gatherers
	## Uses smart distance thresholds to avoid long walks for "available" resources
	## Returns null if all huntables are too far (better to farm than walk across map)
	var base_pos = _get_ai_base_position()
	var gatherer_counts = _get_current_gatherer_counts()
	var max_gatherers = controller.strategic_numbers.get("sn_max_gatherers_per_resource", 2)

	# Distance thresholds for smart assignment
	const MAX_EFFICIENT_DISTANCE = 400.0
	const PREFER_FULL_WITHIN = 200.0
	const MAX_HUNT_DISTANCE = 500.0  # Don't hunt animals further than this - inefficient

	var nearest_available: Node = null
	var nearest_available_dist = INF
	var nearest_any: Node = null  # Fallback if all animals are full
	var nearest_any_dist = INF

	# Check deer
	for animal in scene_tree.get_nodes_in_group("deer"):
		if animal.is_dead:
			continue

		var dist = base_pos.distance_to(animal.global_position)

		# Track absolute nearest (fallback)
		if dist < nearest_any_dist:
			nearest_any_dist = dist
			nearest_any = animal

		# Check if this animal has capacity
		var target_id = animal.get_instance_id()
		var current_gatherers = gatherer_counts.get(target_id, 0)
		if current_gatherers >= max_gatherers:
			continue

		# Track nearest with available capacity
		if dist < nearest_available_dist:
			nearest_available_dist = dist
			nearest_available = animal

	# Check boar
	for animal in scene_tree.get_nodes_in_group("boar"):
		if animal.is_dead:
			continue

		var dist = base_pos.distance_to(animal.global_position)

		# Track absolute nearest (fallback)
		if dist < nearest_any_dist:
			nearest_any_dist = dist
			nearest_any = animal

		# Check if this animal has capacity
		var target_id = animal.get_instance_id()
		var current_gatherers = gatherer_counts.get(target_id, 0)
		if current_gatherers >= max_gatherers:
			continue

		# Track nearest with available capacity
		if dist < nearest_available_dist:
			nearest_available_dist = dist
			nearest_available = animal

	# Smart selection: if available animal is far but there's one close, prefer close one
	if nearest_available:
		# Don't hunt if too far - better to farm or gather berries
		if nearest_available_dist > MAX_HUNT_DISTANCE:
			return null
		if nearest_available_dist > MAX_EFFICIENT_DISTANCE and nearest_any_dist < PREFER_FULL_WITHIN:
			return nearest_any
		return nearest_available

	# Graceful degradation: if all animals are at capacity, use nearest
	# But apply a hard cap to prevent excessive piling (2x normal limit)
	if nearest_any:
		# Don't hunt if too far
		if nearest_any_dist > MAX_HUNT_DISTANCE:
			return null
		var any_id = nearest_any.get_instance_id()
		var any_count = gatherer_counts.get(any_id, 0)
		if any_count >= max_gatherers * 2:
			return null  # Too crowded, don't pile more
	return nearest_any


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


# =============================================================================
# DEBUG HELPERS - Observability for automated testing
# =============================================================================

func get_gatherer_distances() -> Dictionary:
	## Returns average distance of each resource type's gatherers to their nearest drop-off
	## Format: {"food": 234.5, "wood": 847.2, ...} - INF if no gatherers
	var result = {"food": INF, "wood": INF, "gold": INF, "stone": INF}
	var totals = {"food": 0.0, "wood": 0.0, "gold": 0.0, "stone": 0.0}
	var counts = {"food": 0, "wood": 0, "gold": 0, "stone": 0}

	for villager in scene_tree.get_nodes_in_group("villagers"):
		if villager.team != AI_TEAM or villager.is_dead:
			continue

		# Only count villagers actively gathering or returning
		if villager.current_state != villager.State.GATHERING and \
		   villager.current_state != villager.State.RETURNING and \
		   villager.current_state != villager.State.HUNTING:
			continue

		var resource_type = villager.carried_resource_type
		if resource_type == "":
			resource_type = "food"  # Default for hunters

		if resource_type not in totals:
			continue

		var dist = get_nearest_drop_off_distance(resource_type, villager.global_position)
		if dist < INF:
			totals[resource_type] += dist
			counts[resource_type] += 1

	for resource_type in result:
		if counts[resource_type] > 0:
			result[resource_type] = totals[resource_type] / counts[resource_type]

	return result


func get_villagers_per_target() -> Dictionary:
	## Returns how many villagers are assigned to each unique target
	## Format: {"food_max": 6, "wood_max": 2, ...} - max villagers on same target per resource type
	## Useful for detecting inefficient clustering (e.g., 6 villagers on 1 sheep)
	## Also counts RETURNING villagers - they will return to their target after drop-off.
	var result = {"food_max": 0, "wood_max": 0, "gold_max": 0, "stone_max": 0}

	# Track targets by resource type: {resource_type: {target_id: count}}
	var target_counts: Dictionary = {
		"food": {},
		"wood": {},
		"gold": {},
		"stone": {}
	}

	for villager in scene_tree.get_nodes_in_group("villagers"):
		if villager.team != AI_TEAM or villager.is_dead:
			continue

		# Only count villagers actively working on resources
		if villager.current_state not in [villager.State.HUNTING, villager.State.GATHERING, villager.State.RETURNING]:
			continue

		var target: Node = null
		var resource_type: String = ""

		# Check hunting target (sheep, deer, boar) - for HUNTING or RETURNING from hunting
		if is_instance_valid(villager.target_animal):
			target = villager.target_animal
			resource_type = "food"
		# Check gathering target
		elif is_instance_valid(villager.target_resource):
			target = villager.target_resource
			resource_type = villager.carried_resource_type if villager.carried_resource_type != "" else "food"

		if target and resource_type in target_counts:
			var target_id = target.get_instance_id()
			if target_id not in target_counts[resource_type]:
				target_counts[resource_type][target_id] = 0
			target_counts[resource_type][target_id] += 1

	# Find max for each resource type
	for resource_type in target_counts:
		var max_count = 0
		for target_id in target_counts[resource_type]:
			if target_counts[resource_type][target_id] > max_count:
				max_count = target_counts[resource_type][target_id]
		result[resource_type + "_max"] = max_count

	return result


# =============================================================================
# RELIC HELPERS (Phase 6B)
# =============================================================================

func get_uncollected_relics() -> Array:
	## Returns relics that are not carried, not garrisoned, and not already targeted by an AI monk
	var targeted_relics: Dictionary = {}
	for unit in scene_tree.get_nodes_in_group("monks"):
		if unit.team == AI_TEAM and not unit.is_dead and is_instance_valid(unit.relic_target):
			targeted_relics[unit.relic_target.get_instance_id()] = true
	var result: Array = []
	for relic in scene_tree.get_nodes_in_group("relics"):
		if not relic.is_carried and not relic.is_garrisoned:
			if relic.get_instance_id() not in targeted_relics:
				result.append(relic)
	return result


func get_idle_monk() -> Node:
	## Returns an AI monk that is IDLE, not rejuvenating, not carrying a relic
	for unit in scene_tree.get_nodes_in_group("monks"):
		if unit.team != AI_TEAM or unit.is_dead:
			continue
		if unit.carrying_relic:
			continue
		if unit.is_rejuvenating:
			continue
		if unit.current_state == Monk.State.IDLE:
			return unit
	return null


func get_monk_carrying_relic() -> Node:
	## Returns an AI monk that is carrying a relic
	for unit in scene_tree.get_nodes_in_group("monks"):
		if unit.team != AI_TEAM or unit.is_dead:
			continue
		if unit.carrying_relic:
			return unit
	return null


func get_enemy_high_value_target(monk_position: Vector2) -> Node:
	## Returns a nearby enemy unit worth converting (most expensive first)
	var max_range: float = 576.0  # 2x conversion range
	var best_target: Node = null
	var best_value: int = 0

	# Value table for conversion targeting
	var unit_values: Dictionary = {
		"knights": 135,  # 60F + 75G
		"heavy_cavalry_archers": 110,  # 40W + 70G
		"cavalry_archers": 110,
		"light_cavalry": 80,
		"scout_cavalry": 80,
		"crossbowmen": 70,
		"archers_line": 70,
		"elite_skirmishers": 60,
		"skirmishers": 60,
		"long_swordsmen": 55,
		"man_at_arms": 50,
		"pikemen": 50,
		"militia": 40,
		"spearmen": 35,
	}

	for unit in scene_tree.get_nodes_in_group("units"):
		if unit.team == AI_TEAM or unit.is_dead:
			continue
		if unit is Villager:
			continue  # Don't prioritize villagers
		if not unit.is_in_group("military"):
			continue

		var dist = monk_position.distance_to(unit.global_position)
		if dist > max_range:
			continue

		# Get value from groups
		var value: int = 30  # default
		for group_name in unit_values:
			if unit.is_in_group(group_name):
				value = unit_values[group_name]
				break

		if value > best_value:
			best_value = value
			best_target = unit

	return best_target


func command_monk_pickup_relic(monk: Node, relic: Node) -> void:
	## Direct command: send monk to pick up a relic
	if is_instance_valid(monk) and is_instance_valid(relic):
		monk.command_pickup_relic(relic)
		_log_action("monk_pickup_relic", {})


func command_monk_garrison_relic(monk: Node, monastery: Node) -> void:
	## Direct command: send monk carrying relic to garrison at monastery
	if is_instance_valid(monk) and is_instance_valid(monastery):
		monk.command_garrison_relic(monastery)
		_log_action("monk_garrison_relic", {})


func command_monk_convert(monk: Node, target: Node) -> void:
	## Direct command: send monk to convert an enemy
	if is_instance_valid(monk) and is_instance_valid(target):
		monk.command_convert(target)
		_log_action("monk_convert", {})


# =============================================================================
# GARRISON HELPERS (Phase 7A)
# =============================================================================

func get_nearest_garrison_building(from_pos: Vector2) -> Building:
	## Returns nearest AI building with garrison capacity that isn't full
	var nearest: Building = null
	var nearest_dist: float = INF

	for building in scene_tree.get_nodes_in_group("buildings"):
		if building.team != AI_TEAM or building.is_destroyed:
			continue
		if building.garrison_capacity <= 0 or not building.is_functional():
			continue
		if building.get_garrisoned_count() >= building.garrison_capacity:
			continue
		var dist = from_pos.distance_to(building.global_position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = building
	return nearest


func garrison_villagers_under_attack() -> int:
	## Garrison AI villagers that are near enemy threats into nearby buildings.
	## Returns the number of villagers garrisoned.
	const THREAT_DISTANCE: float = 250.0
	var garrisoned_count: int = 0

	for villager in scene_tree.get_nodes_in_group("villagers"):
		if villager.team != AI_TEAM or villager.is_dead or villager.is_garrisoned():
			continue

		# Check if this villager is near an enemy threat
		var is_threatened = false
		for unit in scene_tree.get_nodes_in_group("military"):
			if unit.team == AI_TEAM or unit.is_dead:
				continue
			if villager.global_position.distance_to(unit.global_position) < THREAT_DISTANCE:
				is_threatened = true
				break

		if not is_threatened:
			continue

		# Find nearest building with garrison capacity
		var building = get_nearest_garrison_building(villager.global_position)
		if building and building.can_garrison(villager):
			building.garrison_unit(villager)
			garrisoned_count += 1

	return garrisoned_count
