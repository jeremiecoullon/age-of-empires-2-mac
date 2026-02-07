extends Node

# Age constants
const AGE_DARK: int = 0
const AGE_FEUDAL: int = 1
const AGE_CASTLE: int = 2
const AGE_IMPERIAL: int = 3

const AGE_NAMES: Array[String] = ["Dark Age", "Feudal Age", "Castle Age", "Imperial Age"]

# Age advancement costs and research times
const AGE_COSTS: Array[Dictionary] = [
	{},  # Dark Age (starting age, no cost)
	{"food": 500},  # Feudal Age
	{"food": 800, "gold": 200},  # Castle Age
	{"food": 1000, "gold": 800},  # Imperial Age
]

const AGE_RESEARCH_TIMES: Array[float] = [
	0.0,   # Dark Age
	130.0, # Feudal Age (AoE2: ~130 seconds)
	160.0, # Castle Age (AoE2: ~160 seconds)
	190.0, # Imperial Age (AoE2: ~190 seconds)
]

# Qualifying building groups per target age
# To advance to Feudal: need 2 from Dark Age qualifying buildings
# To advance to Castle: need 2 from Feudal Age qualifying buildings
# To advance to Imperial: need 2 from Castle Age qualifying buildings
const AGE_QUALIFYING_GROUPS: Array[Array] = [
	[],  # Dark Age (starting age)
	["barracks", "mills", "lumber_camps", "mining_camps"],  # For Feudal
	["archery_ranges", "stables", "markets"],  # For Castle
	["monasteries", "universities"],  # For Imperial - Castle Age qualifying buildings
]

const AGE_REQUIRED_QUALIFYING_COUNT: int = 2

# Age requirements for buildings and units
# Buildings/units not listed here are available from Dark Age
const BUILDING_AGE_REQUIREMENTS: Dictionary = {
	"archery_range": AGE_FEUDAL,
	"stable": AGE_FEUDAL,
	"market": AGE_FEUDAL,
	"blacksmith": AGE_FEUDAL,
	"watch_tower": AGE_FEUDAL,
	"stone_wall": AGE_FEUDAL,
	"gate": AGE_FEUDAL,
	"monastery": AGE_CASTLE,
	"university": AGE_CASTLE,
	"siege_workshop": AGE_CASTLE,
}

const UNIT_AGE_REQUIREMENTS: Dictionary = {
	"archer": AGE_FEUDAL,
	"skirmisher": AGE_FEUDAL,
	"spearman": AGE_FEUDAL,
	"scout_cavalry": AGE_FEUDAL,
	"trade_cart": AGE_FEUDAL,
	"cavalry_archer": AGE_CASTLE,
	"knight": AGE_CASTLE,
	"monk": AGE_CASTLE,
	"battering_ram": AGE_CASTLE,
	"mangonel": AGE_CASTLE,
	"scorpion": AGE_CASTLE,
}

# Age state per player
var player_age: int = AGE_DARK
var ai_age: int = AGE_DARK

# ===== TECHNOLOGY SYSTEM =====

# Technology definitions (Feudal + Castle only; Imperial deferred to Phase 9)
# Effects: keys map to bonus categories applied to units via apply_tech_bonuses()
const TECHNOLOGIES: Dictionary = {
	# Loom (Town Center, Dark Age)
	"loom": {
		"name": "Loom", "age": AGE_DARK, "building": "town_center",
		"cost": {"gold": 50}, "research_time": 25.0,
		"effects": {"villager_hp": 15, "villager_melee_armor": 1, "villager_pierce_armor": 1},
		"requires": ""
	},
	# Blacksmith - Infantry/Cavalry Attack line (Forging affects both)
	"forging": {
		"name": "Forging", "age": AGE_FEUDAL, "building": "blacksmith",
		"cost": {"food": 150}, "research_time": 50.0,
		"effects": {"infantry_attack": 1, "cavalry_attack": 1},
		"requires": ""
	},
	"iron_casting": {
		"name": "Iron Casting", "age": AGE_CASTLE, "building": "blacksmith",
		"cost": {"food": 220, "gold": 120}, "research_time": 75.0,
		"effects": {"infantry_attack": 1, "cavalry_attack": 1},
		"requires": "forging"
	},
	# Blacksmith - Infantry Armor line
	"scale_mail_armor": {
		"name": "Scale Mail Armor", "age": AGE_FEUDAL, "building": "blacksmith",
		"cost": {"food": 100}, "research_time": 40.0,
		"effects": {"infantry_melee_armor": 1, "infantry_pierce_armor": 1},
		"requires": ""
	},
	"chain_mail_armor": {
		"name": "Chain Mail Armor", "age": AGE_CASTLE, "building": "blacksmith",
		"cost": {"food": 200, "gold": 100}, "research_time": 55.0,
		"effects": {"infantry_melee_armor": 1, "infantry_pierce_armor": 1},
		"requires": "scale_mail_armor"
	},
	# Blacksmith - Cavalry Armor line
	"scale_barding_armor": {
		"name": "Scale Barding Armor", "age": AGE_FEUDAL, "building": "blacksmith",
		"cost": {"food": 150}, "research_time": 45.0,
		"effects": {"cavalry_melee_armor": 1, "cavalry_pierce_armor": 1},
		"requires": ""
	},
	"chain_barding_armor": {
		"name": "Chain Barding Armor", "age": AGE_CASTLE, "building": "blacksmith",
		"cost": {"food": 250, "gold": 150}, "research_time": 60.0,
		"effects": {"cavalry_melee_armor": 1, "cavalry_pierce_armor": 1},
		"requires": "scale_barding_armor"
	},
	# Blacksmith - Archer Attack line (Fletching also affects TCs/towers in future)
	"fletching": {
		"name": "Fletching", "age": AGE_FEUDAL, "building": "blacksmith",
		"cost": {"food": 100, "gold": 50}, "research_time": 30.0,
		"effects": {"archer_attack": 1, "archer_range": 1},
		"requires": ""
	},
	"bodkin_arrow": {
		"name": "Bodkin Arrow", "age": AGE_CASTLE, "building": "blacksmith",
		"cost": {"food": 200, "gold": 100}, "research_time": 60.0,
		"effects": {"archer_attack": 1, "archer_range": 1},
		"requires": "fletching"
	},
	# Blacksmith - Archer Armor line
	"padded_archer_armor": {
		"name": "Padded Archer Armor", "age": AGE_FEUDAL, "building": "blacksmith",
		"cost": {"food": 100}, "research_time": 40.0,
		"effects": {"archer_melee_armor": 1, "archer_pierce_armor": 1},
		"requires": ""
	},
	"leather_archer_armor": {
		"name": "Leather Archer Armor", "age": AGE_CASTLE, "building": "blacksmith",
		"cost": {"food": 150, "gold": 150}, "research_time": 55.0,
		"effects": {"archer_melee_armor": 1, "archer_pierce_armor": 1},
		"requires": "padded_archer_armor"
	},
	# ===== UNIT UPGRADES =====
	# Barracks line
	"man_at_arms": {
		"name": "Man-at-Arms", "age": AGE_FEUDAL, "building": "barracks",
		"cost": {"food": 100, "gold": 40}, "research_time": 40.0,
		"effects": {}, "requires": "",
		"type": "unit_upgrade", "from_group": "militia", "to_group": "man_at_arms",
		"to_name": "Man-at-Arms",
		"new_stats": {"max_hp": 45, "attack_damage": 6, "melee_armor": 0, "pierce_armor": 0}
	},
	"long_swordsman": {
		"name": "Long Swordsman", "age": AGE_CASTLE, "building": "barracks",
		"cost": {"food": 200, "gold": 65}, "research_time": 45.0,
		"effects": {}, "requires": "man_at_arms",
		"type": "unit_upgrade", "from_group": "man_at_arms", "to_group": "long_swordsmen",
		"to_name": "Long Swordsman",
		"new_stats": {"max_hp": 55, "attack_damage": 9, "melee_armor": 0, "pierce_armor": 0}
	},
	"pikeman": {
		"name": "Pikeman", "age": AGE_CASTLE, "building": "barracks",
		"cost": {"food": 215, "gold": 90}, "research_time": 45.0,
		"effects": {}, "requires": "",
		"type": "unit_upgrade", "from_group": "spearmen", "to_group": "pikemen",
		"to_name": "Pikeman",
		"new_stats": {"max_hp": 55, "attack_damage": 4, "melee_armor": 1, "pierce_armor": 0, "bonus_vs_cavalry": 22}
	},
	# Archery Range line
	"crossbowman": {
		"name": "Crossbowman", "age": AGE_CASTLE, "building": "archery_range",
		"cost": {"food": 125, "gold": 75}, "research_time": 35.0,
		"effects": {}, "requires": "",
		"type": "unit_upgrade", "from_group": "archers_line", "to_group": "crossbowmen",
		"to_name": "Crossbowman",
		"new_stats": {"max_hp": 35, "attack_damage": 5, "attack_range": 160.0}
	},
	"elite_skirmisher": {
		"name": "Elite Skirmisher", "age": AGE_CASTLE, "building": "archery_range",
		"cost": {"wood": 200, "gold": 100}, "research_time": 50.0,
		"effects": {}, "requires": "",
		"type": "unit_upgrade", "from_group": "skirmishers", "to_group": "elite_skirmishers",
		"to_name": "Elite Skirmisher",
		"new_stats": {"max_hp": 35, "attack_damage": 3, "pierce_armor": 4, "bonus_vs_archers": 5, "attack_range": 160.0}
	},
	"heavy_cavalry_archer": {
		"name": "Heavy Cav Archer", "age": AGE_CASTLE, "building": "archery_range",
		"cost": {"food": 900, "gold": 500}, "research_time": 50.0,
		"effects": {}, "requires": "",
		"type": "unit_upgrade", "from_group": "cavalry_archers", "to_group": "heavy_cavalry_archers",
		"to_name": "Heavy Cav Archer",
		"new_stats": {"max_hp": 60, "attack_damage": 7, "melee_armor": 1, "pierce_armor": 0, "attack_range": 128.0}
	},
	# Stable line
	"light_cavalry": {
		"name": "Light Cavalry", "age": AGE_CASTLE, "building": "stable",
		"cost": {"food": 150, "gold": 50}, "research_time": 45.0,
		"effects": {}, "requires": "",
		"type": "unit_upgrade", "from_group": "scout_cavalry", "to_group": "light_cavalry",
		"to_name": "Light Cavalry",
		"new_stats": {"max_hp": 60, "attack_damage": 7, "melee_armor": 0, "pierce_armor": 2}
	},
	# ===== SIEGE WORKSHOP UNIT UPGRADES =====
	"capped_ram": {
		"name": "Capped Ram", "age": AGE_CASTLE, "building": "siege_workshop",
		"cost": {"food": 300}, "research_time": 50.0,
		"effects": {}, "requires": "",
		"type": "unit_upgrade", "from_group": "battering_rams", "to_group": "capped_rams",
		"to_name": "Capped Ram",
		"new_stats": {"max_hp": 200, "attack_damage": 3, "pierce_armor": 190}
	},
	"onager": {
		"name": "Onager", "age": AGE_IMPERIAL, "building": "siege_workshop",
		"cost": {"food": 800, "gold": 500}, "research_time": 75.0,
		"effects": {}, "requires": "",
		"type": "unit_upgrade", "from_group": "mangonels", "to_group": "onagers",
		"to_name": "Onager",
		"new_stats": {"max_hp": 60, "attack_damage": 50, "pierce_armor": 7, "attack_range": 256.0}
	},
	"heavy_scorpion": {
		"name": "Heavy Scorpion", "age": AGE_IMPERIAL, "building": "siege_workshop",
		"cost": {"food": 1000, "wood": 800}, "research_time": 75.0,
		"effects": {}, "requires": "",
		"type": "unit_upgrade", "from_group": "scorpions", "to_group": "heavy_scorpions",
		"to_name": "Heavy Scorpion",
		"new_stats": {"max_hp": 50, "attack_damage": 16, "pierce_armor": 7}
	},
	# ===== MONASTERY TECHNOLOGIES =====
	"fervor": {
		"name": "Fervor", "age": AGE_CASTLE, "building": "monastery",
		"cost": {"gold": 140}, "research_time": 50.0,
		"effects": {"monk_speed": 15},
		"requires": ""
	},
	"sanctity": {
		"name": "Sanctity", "age": AGE_CASTLE, "building": "monastery",
		"cost": {"gold": 120}, "research_time": 60.0,
		"effects": {"monk_hp": 15},
		"requires": ""
	},
	"redemption": {
		"name": "Redemption", "age": AGE_CASTLE, "building": "monastery",
		"cost": {"gold": 475}, "research_time": 50.0,
		"effects": {"redemption": 1},
		"requires": ""
	},
	"atonement": {
		"name": "Atonement", "age": AGE_CASTLE, "building": "monastery",
		"cost": {"gold": 325}, "research_time": 40.0,
		"effects": {"atonement": 1},
		"requires": ""
	},
	"illumination": {
		"name": "Illumination", "age": AGE_IMPERIAL, "building": "monastery",
		"cost": {"gold": 120}, "research_time": 65.0,
		"effects": {"illumination": 1},
		"requires": ""
	},
	"faith": {
		"name": "Faith", "age": AGE_IMPERIAL, "building": "monastery",
		"cost": {"food": 750, "gold": 1000}, "research_time": 60.0,
		"effects": {"faith": 1},
		"requires": ""
	},
	"block_printing": {
		"name": "Block Printing", "age": AGE_IMPERIAL, "building": "monastery",
		"cost": {"gold": 200}, "research_time": 55.0,
		"effects": {"monk_range": 96},
		"requires": ""
	},
	# ===== UNIVERSITY TECHNOLOGIES =====
	"masonry": {
		"name": "Masonry", "age": AGE_CASTLE, "building": "university",
		"cost": {"wood": 175, "stone": 150}, "research_time": 50.0,
		"effects": {"building_hp_percent": 10, "building_melee_armor": 1, "building_pierce_armor": 1, "building_los": 3},
		"requires": ""
	},
	"murder_holes": {
		"name": "Murder Holes", "age": AGE_CASTLE, "building": "university",
		"cost": {"food": 200, "stone": 200}, "research_time": 60.0,
		"effects": {"murder_holes": 1},
		"requires": ""
	},
	"treadmill_crane": {
		"name": "Treadmill Crane", "age": AGE_CASTLE, "building": "university",
		"cost": {"wood": 200, "stone": 300}, "research_time": 50.0,
		"effects": {"treadmill_crane": 1},
		"requires": ""
	},
	"ballistics": {
		"name": "Ballistics", "age": AGE_CASTLE, "building": "university",
		"cost": {"wood": 300, "gold": 175}, "research_time": 60.0,
		"effects": {"ballistics": 1},
		"requires": ""
	},
	# ===== BUILDING UPGRADES (University) =====
	"guard_tower": {
		"name": "Guard Tower", "age": AGE_CASTLE, "building": "university",
		"cost": {"food": 100, "wood": 250}, "research_time": 30.0,
		"effects": {}, "requires": "",
		"type": "building_upgrade", "from_group": "watch_towers", "to_group": "guard_towers",
		"to_name": "Guard Tower",
		"new_stats": {"max_hp": 1500, "pierce_armor": 9, "tower_base_attack": 6}
	},
	"fortified_wall": {
		"name": "Fortified Wall", "age": AGE_CASTLE, "building": "university",
		"cost": {"food": 200, "stone": 100}, "research_time": 50.0,
		"effects": {}, "requires": "",
		"type": "building_upgrade", "from_group": "stone_walls", "to_group": "fortified_walls",
		"to_name": "Fortified Wall",
		"new_stats": {"max_hp": 3000, "melee_armor": 12, "pierce_armor": 12}
	},
}

# Per-team technology state
var player_researched_techs: Array[String] = []
var ai_researched_techs: Array[String] = []
var player_tech_bonuses: Dictionary = {}
var ai_tech_bonuses: Dictionary = {}

signal tech_researched(team: int, tech_id: String)

func has_tech(tech_id: String, team: int = 0) -> bool:
	var techs = player_researched_techs if team == 0 else ai_researched_techs
	return techs.has(tech_id)

func can_research_tech(tech_id: String, team: int = 0) -> bool:
	if tech_id not in TECHNOLOGIES:
		return false
	if has_tech(tech_id, team):
		return false
	var tech = TECHNOLOGIES[tech_id]
	# Check age requirement
	if get_age(team) < tech["age"]:
		return false
	# Check prerequisite
	var prereq = tech["requires"]
	if prereq != "" and not has_tech(prereq, team):
		return false
	# Check cost
	var pool = resources if team == 0 else ai_resources
	for resource_type in tech["cost"]:
		if pool[resource_type] < tech["cost"][resource_type]:
			return false
	return true

func spend_tech_cost(tech_id: String, team: int = 0) -> bool:
	if tech_id not in TECHNOLOGIES:
		return false
	var tech = TECHNOLOGIES[tech_id]
	var pool = resources if team == 0 else ai_resources
	for resource_type in tech["cost"]:
		if pool[resource_type] < tech["cost"][resource_type]:
			return false
	for resource_type in tech["cost"]:
		spend_resource(resource_type, tech["cost"][resource_type], team)
	return true

func refund_tech_cost(tech_id: String, team: int = 0) -> void:
	if tech_id not in TECHNOLOGIES:
		return
	var tech = TECHNOLOGIES[tech_id]
	for resource_type in tech["cost"]:
		add_resource(resource_type, tech["cost"][resource_type], team)

func complete_tech_research(tech_id: String, team: int = 0) -> void:
	var techs = player_researched_techs if team == 0 else ai_researched_techs
	if not techs.has(tech_id):
		techs.append(tech_id)
	_recalculate_tech_bonuses(team)
	# Apply unit upgrade if this is a unit_upgrade tech
	if tech_id in TECHNOLOGIES and TECHNOLOGIES[tech_id].get("type", "") == "unit_upgrade":
		_apply_unit_upgrade(tech_id, team)
	# Apply building upgrade if this is a building_upgrade tech
	if tech_id in TECHNOLOGIES and TECHNOLOGIES[tech_id].get("type", "") == "building_upgrade":
		_apply_building_upgrade(tech_id, team)
	tech_researched.emit(team, tech_id)

func _apply_unit_upgrade(tech_id: String, team_id: int) -> void:
	var tech = TECHNOLOGIES[tech_id]
	var from_group: String = tech["from_group"]
	var to_group: String = tech["to_group"]
	var to_name: String = tech["to_name"]
	var new_stats: Dictionary = tech["new_stats"]

	for unit in get_tree().get_nodes_in_group(from_group):
		if unit.team != team_id:
			continue
		# Apply new stats — use set() for subclass properties
		if "max_hp" in new_stats:
			var old_max = unit.max_hp
			unit.max_hp = new_stats["max_hp"]
			# Increase current HP by delta if upgraded, clamp if downgraded
			if unit.max_hp > old_max:
				unit.current_hp += unit.max_hp - old_max
			else:
				unit.current_hp = min(unit.current_hp, unit.max_hp)
		for stat_key in new_stats:
			if stat_key == "max_hp":
				continue  # Already handled above
			unit.set(stat_key, new_stats[stat_key])
		# Swap groups
		unit.remove_from_group(from_group)
		unit.add_to_group(to_group)
		# Set display name
		unit.unit_display_name = to_name
		# Re-store base stats and reapply tech bonuses
		unit._store_base_stats()
		unit.apply_tech_bonuses()

func _apply_building_upgrade(tech_id: String, team_id: int) -> void:
	var tech = TECHNOLOGIES[tech_id]
	var from_group: String = tech["from_group"]
	var to_group: String = tech["to_group"]
	var to_name: String = tech["to_name"]
	var new_stats: Dictionary = tech["new_stats"]

	for building in get_tree().get_nodes_in_group(from_group):
		if building.team != team_id:
			continue
		# Apply new stats with HP delta scaling
		if "max_hp" in new_stats:
			var old_max = building.max_hp
			building.max_hp = new_stats["max_hp"]
			building._base_max_hp = new_stats["max_hp"]
			if building.is_constructed:
				# Scale current HP up by the delta
				var hp_delta = building.max_hp - old_max
				if hp_delta > 0:
					building.current_hp += hp_delta
				else:
					building.current_hp = min(building.current_hp, building.max_hp)
		for stat_key in new_stats:
			if stat_key == "max_hp":
				continue
			building.set(stat_key, new_stats[stat_key])
			# Update base stats for armor so tech bonuses recalculate correctly
			if stat_key == "melee_armor":
				building._base_melee_armor = new_stats[stat_key]
			elif stat_key == "pierce_armor":
				building._base_pierce_armor = new_stats[stat_key]
		# Swap groups
		building.remove_from_group(from_group)
		building.add_to_group(to_group)
		# Update display name
		building.building_name = to_name
		# Reapply tech bonuses from updated base values
		building.apply_building_tech_bonuses()

func get_tech_bonus(bonus_key: String, team: int = 0) -> int:
	var bonuses = player_tech_bonuses if team == 0 else ai_tech_bonuses
	return bonuses.get(bonus_key, 0)

func _recalculate_tech_bonuses(team: int = 0) -> void:
	var techs = player_researched_techs if team == 0 else ai_researched_techs
	var bonuses: Dictionary = {}
	for tech_id in techs:
		if tech_id not in TECHNOLOGIES:
			continue
		var effects = TECHNOLOGIES[tech_id]["effects"]
		for key in effects:
			bonuses[key] = bonuses.get(key, 0) + effects[key]
	if team == 0:
		player_tech_bonuses = bonuses
	else:
		ai_tech_bonuses = bonuses

# Resource pools - dictionary-based for extensibility
var resources: Dictionary = {"wood": 200, "food": 200, "gold": 0, "stone": 0}
var ai_resources: Dictionary = {"wood": 200, "food": 200, "gold": 0, "stone": 0}

# Market system - dynamic pricing based on buy/sell activity
# Base prices: how much gold to buy 100 of each resource (AoE2-style)
const BASE_MARKET_PRICES: Dictionary = {"wood": 100, "food": 100, "stone": 130}
const MIN_MARKET_PRICE: int = 20  # Minimum price (100 resource costs 20 gold)
const MAX_MARKET_PRICE: int = 300  # Maximum price (100 resource costs 300 gold)
const PRICE_CHANGE_PER_TRADE: int = 3  # Price change per 100-unit trade

# Current market prices (shared globally - all players see same prices)
var market_prices: Dictionary = {"wood": 100, "food": 100, "stone": 130}

# Population
var population: int = 4
var population_cap: int = 5
var ai_population: int = 0
var ai_population_cap: int = 5

# Signals
signal resources_changed
signal population_changed
signal game_over(winner: int)  # 0 = player wins, 1 = AI wins
signal villager_idle(villager: Node, reason: String)  # Emitted when player villager goes idle
signal market_prices_changed  # Emitted when market prices update
signal player_under_attack(attack_type: String)  # "military", "villager", or "building"
signal age_changed(team: int, new_age: int)  # Emitted when a player advances to a new age
signal relic_countdown_started(team: int)
signal relic_countdown_updated(team: int, time_remaining: float)
signal relic_countdown_cancelled()

var game_ended: bool = false

# Relic victory
const RELIC_VICTORY_TIME: float = 200.0  # Seconds to hold all relics for victory
const TOTAL_RELICS: int = 5
var relic_victory_timer: float = 0.0
var relic_victory_team: int = -1

# Attack notification throttling
const ATTACK_NOTIFY_COOLDOWN: float = 5.0  # Don't spam notifications
var _last_military_attack_time: float = -ATTACK_NOTIFY_COOLDOWN
var _last_civilian_attack_time: float = -ATTACK_NOTIFY_COOLDOWN

# Selected units
var selected_units: Array = []

# Building placement mode
var is_placing_building: bool = false
var building_to_place: PackedScene = null
var building_ghost: Node2D = null

# Unified resource functions
func add_resource(type: String, amount: int, team: int = 0) -> void:
	if team == 0:
		resources[type] += amount
	else:
		ai_resources[type] += amount
	resources_changed.emit()

func spend_resource(type: String, amount: int, team: int = 0) -> bool:
	var pool = resources if team == 0 else ai_resources
	if pool[type] >= amount:
		pool[type] -= amount
		resources_changed.emit()
		return true
	return false

func can_afford(type: String, amount: int, team: int = 0) -> bool:
	var pool = resources if team == 0 else ai_resources
	return pool[type] >= amount

func get_resource(type: String, team: int = 0) -> int:
	return resources[type] if team == 0 else ai_resources[type]

# Market functions
func get_market_buy_price(resource_type: String) -> int:
	# Returns gold cost to buy 100 of the resource
	if resource_type == "gold":
		return 0  # Can't buy gold with gold
	return market_prices.get(resource_type, 100)

func get_market_sell_price(resource_type: String) -> int:
	# Returns gold gained from selling 100 of the resource
	# Sell price is slightly lower than buy price (spread)
	if resource_type == "gold":
		return 0  # Can't sell gold for gold
	var buy_price = market_prices.get(resource_type, 100)
	# Sell price is ~70% of buy price (AoE2-style spread)
	return int(buy_price * 0.7)

func market_buy(resource_type: String, team: int = 0) -> bool:
	# Buy 100 of resource_type for gold
	if resource_type == "gold":
		return false
	var gold_cost = get_market_buy_price(resource_type)
	if not can_afford("gold", gold_cost, team):
		return false

	spend_resource("gold", gold_cost, team)
	add_resource(resource_type, 100, team)

	# Buying increases the price (demand)
	_adjust_market_price(resource_type, PRICE_CHANGE_PER_TRADE)
	return true

func market_sell(resource_type: String, team: int = 0) -> bool:
	# Sell 100 of resource_type for gold
	if resource_type == "gold":
		return false
	if not can_afford(resource_type, 100, team):
		return false

	var gold_gained = get_market_sell_price(resource_type)
	spend_resource(resource_type, 100, team)
	add_resource("gold", gold_gained, team)

	# Selling decreases the price (supply)
	_adjust_market_price(resource_type, -PRICE_CHANGE_PER_TRADE)
	return true

func _adjust_market_price(resource_type: String, change: int) -> void:
	if resource_type not in market_prices:
		return
	market_prices[resource_type] = clampi(
		market_prices[resource_type] + change,
		MIN_MARKET_PRICE,
		MAX_MARKET_PRICE
	)
	market_prices_changed.emit()

func reset_market_prices() -> void:
	market_prices = BASE_MARKET_PRICES.duplicate()
	market_prices_changed.emit()

# Population functions
func add_population(amount: int, team: int = 0) -> void:
	if team == 0:
		population += amount
	else:
		ai_population += amount
	population_changed.emit()

func remove_population(amount: int, team: int = 0) -> void:
	if team == 0:
		population -= amount
	else:
		ai_population -= amount
	population_changed.emit()

func increase_population_cap(amount: int, team: int = 0) -> void:
	if team == 0:
		population_cap += amount
	else:
		ai_population_cap += amount
	population_changed.emit()

func can_add_population(team: int = 0) -> bool:
	if team == 0:
		return population < population_cap
	else:
		return ai_population < ai_population_cap

func get_population(team: int = 0) -> int:
	return population if team == 0 else ai_population

func get_population_cap(team: int = 0) -> int:
	return population_cap if team == 0 else ai_population_cap

# Age functions
func get_age(team: int = 0) -> int:
	return player_age if team == 0 else ai_age

func set_age(age: int, team: int = 0) -> void:
	if team == 0:
		player_age = age
	else:
		ai_age = age
	age_changed.emit(team, age)

func get_age_name(team: int = 0) -> String:
	var age = get_age(team)
	return AGE_NAMES[age] if age < AGE_NAMES.size() else "Unknown"


func is_building_unlocked(building_type: String, team: int = 0) -> bool:
	var required_age = BUILDING_AGE_REQUIREMENTS.get(building_type, AGE_DARK)
	return get_age(team) >= required_age


func is_unit_unlocked(unit_type: String, team: int = 0) -> bool:
	var required_age = UNIT_AGE_REQUIREMENTS.get(unit_type, AGE_DARK)
	return get_age(team) >= required_age


func get_required_age_name(entity_type: String, is_building: bool = false) -> String:
	var reqs = BUILDING_AGE_REQUIREMENTS if is_building else UNIT_AGE_REQUIREMENTS
	var required_age = reqs.get(entity_type, AGE_DARK)
	return AGE_NAMES[required_age] if required_age < AGE_NAMES.size() else "Unknown"

func can_advance_age(team: int = 0) -> bool:
	var current_age = get_age(team)
	if current_age >= AGE_IMPERIAL:
		return false  # Already at max age
	var target_age = current_age + 1
	# Check qualifying building count
	if get_qualifying_building_count(target_age, team) < AGE_REQUIRED_QUALIFYING_COUNT:
		return false
	# Check resources
	if not can_afford_age(target_age, team):
		return false
	return true

func get_qualifying_building_count(target_age: int, team: int = 0) -> int:
	# Counts distinct building types (groups) with at least one functional building.
	# AoE2 requires 2 *different* building types, not 2 buildings of the same type.
	if target_age <= 0 or target_age >= AGE_QUALIFYING_GROUPS.size():
		return 0
	var qualifying_groups: Array = AGE_QUALIFYING_GROUPS[target_age]
	var distinct_count: int = 0
	for group_name in qualifying_groups:
		for building in get_tree().get_nodes_in_group(group_name):
			if building.team == team and building.is_functional():
				distinct_count += 1
				break
	return distinct_count

func can_afford_age(target_age: int, team: int = 0) -> bool:
	if target_age <= 0 or target_age >= AGE_COSTS.size():
		return false
	var costs: Dictionary = AGE_COSTS[target_age]
	var pool = resources if team == 0 else ai_resources
	for resource_type in costs:
		if pool[resource_type] < costs[resource_type]:
			return false
	return true

func spend_age_cost(target_age: int, team: int = 0) -> bool:
	if not can_afford_age(target_age, team):
		return false
	var costs: Dictionary = AGE_COSTS[target_age]
	for resource_type in costs:
		spend_resource(resource_type, costs[resource_type], team)
	return true

func refund_age_cost(target_age: int, team: int = 0) -> void:
	if target_age <= 0 or target_age >= AGE_COSTS.size():
		return
	var costs: Dictionary = AGE_COSTS[target_age]
	for resource_type in costs:
		add_resource(resource_type, costs[resource_type], team)

var _relic_check_timer: float = 0.0
const RELIC_CHECK_INTERVAL: float = 1.0

func _process(delta: float) -> void:
	if relic_victory_team >= 0:
		# Active countdown — check every frame for accurate timer
		_check_relic_victory(delta)
	else:
		# No active countdown — throttle to 1s intervals
		_relic_check_timer += delta
		if _relic_check_timer >= RELIC_CHECK_INTERVAL:
			_relic_check_timer = 0.0
			_check_relic_victory(delta)

func _check_relic_victory(delta: float) -> void:
	if game_ended:
		return
	# Count garrisoned relics per team
	var team_relic_counts: Dictionary = {}
	for monastery in get_tree().get_nodes_in_group("monasteries"):
		if monastery.is_destroyed:
			continue
		var count = monastery.get_relic_count()
		if count > 0:
			team_relic_counts[monastery.team] = team_relic_counts.get(monastery.team, 0) + count

	# Check if any team has all relics
	var controlling_team: int = -1
	for team_id in team_relic_counts:
		if team_relic_counts[team_id] >= TOTAL_RELICS:
			controlling_team = team_id
			break

	if controlling_team >= 0:
		if relic_victory_team != controlling_team:
			# New team took control of all relics
			relic_victory_team = controlling_team
			relic_victory_timer = 0.0
			relic_countdown_started.emit(controlling_team)
		relic_victory_timer += delta
		var time_remaining = RELIC_VICTORY_TIME - relic_victory_timer
		relic_countdown_updated.emit(controlling_team, time_remaining)
		if relic_victory_timer >= RELIC_VICTORY_TIME:
			game_ended = true
			game_over.emit(controlling_team)
	else:
		if relic_victory_team >= 0:
			# Lost control
			relic_victory_team = -1
			relic_victory_timer = 0.0
			relic_countdown_cancelled.emit()

# Victory check
func check_victory() -> void:
	if game_ended:
		return

	var player_tc_exists = false
	var ai_tc_exists = false

	for tc in get_tree().get_nodes_in_group("town_centers"):
		# Skip destroyed TCs (still in group until queue_free completes)
		if tc.is_destroyed:
			continue
		if tc.team == 0:
			player_tc_exists = true
		elif tc.team == 1:
			ai_tc_exists = true

	if not player_tc_exists:
		game_ended = true
		game_over.emit(1)  # AI wins
	elif not ai_tc_exists:
		game_ended = true
		game_over.emit(0)  # Player wins

func select_unit(unit: Node2D) -> void:
	if unit not in selected_units:
		selected_units.append(unit)
		unit.set_selected(true)

func deselect_unit(unit: Node2D) -> void:
	if unit in selected_units:
		selected_units.erase(unit)
		unit.set_selected(false)

func clear_selection() -> void:
	for unit in selected_units:
		if is_instance_valid(unit):
			unit.set_selected(false)
	selected_units.clear()

func start_building_placement(building_scene: PackedScene, ghost: Node2D) -> void:
	is_placing_building = true
	building_to_place = building_scene
	building_ghost = ghost

func cancel_building_placement() -> void:
	is_placing_building = false
	building_to_place = null
	if building_ghost:
		building_ghost.queue_free()
		building_ghost = null

func complete_building_placement() -> void:
	is_placing_building = false
	building_to_place = null
	building_ghost = null

func reset() -> void:
	resources = {"wood": 200, "food": 200, "gold": 0, "stone": 0}
	ai_resources = {"wood": 200, "food": 200, "gold": 0, "stone": 0}
	population = 4
	population_cap = 5
	ai_population = 0
	ai_population_cap = 5
	player_age = AGE_DARK
	ai_age = AGE_DARK
	player_researched_techs.clear()
	ai_researched_techs.clear()
	player_tech_bonuses.clear()
	ai_tech_bonuses.clear()
	game_ended = false
	relic_victory_timer = 0.0
	relic_victory_team = -1
	clear_selection()
	is_placing_building = false
	building_to_place = null
	building_ghost = null
	reset_market_prices()
	_last_military_attack_time = -ATTACK_NOTIFY_COOLDOWN
	_last_civilian_attack_time = -ATTACK_NOTIFY_COOLDOWN
	# Reset fog of war if it exists
	var fog = get_tree().get_first_node_in_group("fog_of_war") if get_tree() else null
	if fog and fog.has_method("reset"):
		fog.reset()

## Called when a unit takes damage. Emits player_under_attack signal if player unit attacked.
## Automatically connected to unit.damaged signal when units are registered.
func notify_unit_damaged(unit: Node, amount: int, attacker: Node2D) -> void:
	if not is_instance_valid(unit):
		return
	if unit.team != 0:  # Only notify for player units
		return
	if game_ended:
		return
	# Don't notify for friendly fire (e.g. villager hunting own sheep)
	if is_instance_valid(attacker) and "team" in attacker and attacker.team == unit.team:
		return

	var current_time = Time.get_ticks_msec() / 1000.0
	var attack_type: String

	# Determine attack type based on unit type
	if unit.is_in_group("military"):
		attack_type = "military"
		if current_time - _last_military_attack_time < ATTACK_NOTIFY_COOLDOWN:
			return  # Throttled
		_last_military_attack_time = current_time
	else:
		attack_type = "villager"
		if current_time - _last_civilian_attack_time < ATTACK_NOTIFY_COOLDOWN:
			return  # Throttled
		_last_civilian_attack_time = current_time

	player_under_attack.emit(attack_type)

## Called when a building takes damage. Emits player_under_attack signal if player building attacked.
func notify_building_damaged(building: Node, amount: int, attacker: Node2D) -> void:
	if not is_instance_valid(building):
		return
	if building.team != 0:  # Only notify for player buildings
		return
	if game_ended:
		return
	# Don't notify for friendly fire
	if is_instance_valid(attacker) and "team" in attacker and attacker.team == building.team:
		return

	var current_time = Time.get_ticks_msec() / 1000.0

	# Buildings use civilian attack notification
	if current_time - _last_civilian_attack_time < ATTACK_NOTIFY_COOLDOWN:
		return  # Throttled
	_last_civilian_attack_time = current_time

	player_under_attack.emit("building")
