extends Node
## Test Spawner - Creates entities at known positions for testing
##
## Usage:
##   var spawner = TestSpawner.new()
##   add_child(spawner)
##   spawner.setup(units_container, buildings_container, resources_container)
##   var villager = spawner.spawn_villager(Vector2(100, 100))

class_name TestSpawner

# Scene paths - Units
const VILLAGER_SCENE = preload("res://scenes/units/villager.tscn")
const MILITIA_SCENE = preload("res://scenes/units/militia.tscn")
const ARCHER_SCENE = preload("res://scenes/units/archer.tscn")
const TRADE_CART_SCENE = preload("res://scenes/units/trade_cart.tscn")
const SCOUT_CAVALRY_SCENE = preload("res://scenes/units/scout_cavalry.tscn")
const SPEARMAN_SCENE = preload("res://scenes/units/spearman.tscn")
const SKIRMISHER_SCENE = preload("res://scenes/units/skirmisher.tscn")
const CAVALRY_ARCHER_SCENE = preload("res://scenes/units/cavalry_archer.tscn")

# Scene paths - Buildings
const TOWN_CENTER_SCENE = preload("res://scenes/buildings/town_center.tscn")
const HOUSE_SCENE = preload("res://scenes/buildings/house.tscn")
const BARRACKS_SCENE = preload("res://scenes/buildings/barracks.tscn")
const MILL_SCENE = preload("res://scenes/buildings/mill.tscn")
const LUMBER_CAMP_SCENE = preload("res://scenes/buildings/lumber_camp.tscn")
const MINING_CAMP_SCENE = preload("res://scenes/buildings/mining_camp.tscn")
const MARKET_SCENE = preload("res://scenes/buildings/market.tscn")
const FARM_SCENE = preload("res://scenes/buildings/farm.tscn")
const ARCHERY_RANGE_SCENE = preload("res://scenes/buildings/archery_range.tscn")
const STABLE_SCENE = preload("res://scenes/buildings/stable.tscn")
const BLACKSMITH_SCENE = preload("res://scenes/buildings/blacksmith.tscn")

# Scene paths - Resources
const TREE_SCENE = preload("res://scenes/resources/tree.tscn")
const BERRY_BUSH_SCENE = preload("res://scenes/resources/berry_bush.tscn")
const GOLD_MINE_SCENE = preload("res://scenes/resources/gold_mine.tscn")
const STONE_MINE_SCENE = preload("res://scenes/resources/stone_mine.tscn")
const FOOD_CARCASS_SCENE = preload("res://scenes/resources/food_carcass.tscn")

# Scene paths - Animals
const SHEEP_SCENE = preload("res://scenes/units/sheep.tscn")
const DEER_SCENE = preload("res://scenes/units/deer.tscn")
const BOAR_SCENE = preload("res://scenes/units/boar.tscn")
const WOLF_SCENE = preload("res://scenes/units/wolf.tscn")

# Container references
var units_container: Node2D
var buildings_container: Node2D
var resources_container: Node2D

# Track spawned entities for cleanup
var spawned_entities: Array[Node] = []


func setup(units: Node2D, buildings: Node2D, resources: Node2D = null) -> void:
	units_container = units
	buildings_container = buildings
	resources_container = resources


func spawn_villager(position: Vector2, team: int = 0) -> Node:
	var villager = VILLAGER_SCENE.instantiate()
	villager.global_position = position
	villager.team = team
	units_container.add_child(villager)
	spawned_entities.append(villager)
	return villager


func spawn_militia(position: Vector2, team: int = 0) -> Node:
	var militia = MILITIA_SCENE.instantiate()
	militia.global_position = position
	militia.team = team
	units_container.add_child(militia)
	spawned_entities.append(militia)
	return militia


func spawn_trade_cart(position: Vector2, team: int = 0, home_market: Node = null) -> Node:
	var cart = TRADE_CART_SCENE.instantiate()
	cart.global_position = position
	cart.team = team
	if home_market:
		cart.home_market = home_market
	units_container.add_child(cart)
	spawned_entities.append(cart)
	return cart


func spawn_archer(position: Vector2, team: int = 0) -> Node:
	var archer = ARCHER_SCENE.instantiate()
	archer.global_position = position
	archer.team = team
	units_container.add_child(archer)
	spawned_entities.append(archer)
	return archer


func spawn_scout_cavalry(position: Vector2, team: int = 0) -> Node:
	var scout = SCOUT_CAVALRY_SCENE.instantiate()
	scout.global_position = position
	scout.team = team
	units_container.add_child(scout)
	spawned_entities.append(scout)
	return scout


func spawn_spearman(position: Vector2, team: int = 0) -> Node:
	var spearman = SPEARMAN_SCENE.instantiate()
	spearman.global_position = position
	spearman.team = team
	units_container.add_child(spearman)
	spawned_entities.append(spearman)
	return spearman


func spawn_skirmisher(position: Vector2, team: int = 0) -> Node:
	var skirmisher = SKIRMISHER_SCENE.instantiate()
	skirmisher.global_position = position
	skirmisher.team = team
	units_container.add_child(skirmisher)
	spawned_entities.append(skirmisher)
	return skirmisher


func spawn_cavalry_archer(position: Vector2, team: int = 0) -> Node:
	var cavalry_archer = CAVALRY_ARCHER_SCENE.instantiate()
	cavalry_archer.global_position = position
	cavalry_archer.team = team
	units_container.add_child(cavalry_archer)
	spawned_entities.append(cavalry_archer)
	return cavalry_archer


func spawn_town_center(position: Vector2, team: int = 0) -> Node:
	var tc = TOWN_CENTER_SCENE.instantiate()
	tc.global_position = position
	tc.team = team
	buildings_container.add_child(tc)
	spawned_entities.append(tc)
	return tc


func spawn_house(position: Vector2, team: int = 0) -> Node:
	var house = HOUSE_SCENE.instantiate()
	house.global_position = position
	house.team = team
	buildings_container.add_child(house)
	spawned_entities.append(house)
	return house


func spawn_barracks(position: Vector2, team: int = 0) -> Node:
	var barracks = BARRACKS_SCENE.instantiate()
	barracks.global_position = position
	barracks.team = team
	buildings_container.add_child(barracks)
	spawned_entities.append(barracks)
	return barracks


func spawn_mill(position: Vector2, team: int = 0) -> Node:
	var mill = MILL_SCENE.instantiate()
	mill.global_position = position
	mill.team = team
	buildings_container.add_child(mill)
	spawned_entities.append(mill)
	return mill


func spawn_lumber_camp(position: Vector2, team: int = 0) -> Node:
	var camp = LUMBER_CAMP_SCENE.instantiate()
	camp.global_position = position
	camp.team = team
	buildings_container.add_child(camp)
	spawned_entities.append(camp)
	return camp


func spawn_mining_camp(position: Vector2, team: int = 0) -> Node:
	var camp = MINING_CAMP_SCENE.instantiate()
	camp.global_position = position
	camp.team = team
	buildings_container.add_child(camp)
	spawned_entities.append(camp)
	return camp


func spawn_market(position: Vector2, team: int = 0) -> Node:
	var market = MARKET_SCENE.instantiate()
	market.global_position = position
	market.team = team
	buildings_container.add_child(market)
	spawned_entities.append(market)
	return market


func spawn_farm(position: Vector2, team: int = 0) -> Node:
	var farm = FARM_SCENE.instantiate()
	farm.global_position = position
	farm.team = team
	buildings_container.add_child(farm)
	spawned_entities.append(farm)
	return farm


func spawn_archery_range(position: Vector2, team: int = 0) -> Node:
	var archery_range = ARCHERY_RANGE_SCENE.instantiate()
	archery_range.global_position = position
	archery_range.team = team
	buildings_container.add_child(archery_range)
	spawned_entities.append(archery_range)
	return archery_range


func spawn_stable(position: Vector2, team: int = 0) -> Node:
	var stable = STABLE_SCENE.instantiate()
	stable.global_position = position
	stable.team = team
	buildings_container.add_child(stable)
	spawned_entities.append(stable)
	return stable


func spawn_blacksmith(position: Vector2, team: int = 0) -> Node:
	var blacksmith = BLACKSMITH_SCENE.instantiate()
	blacksmith.global_position = position
	blacksmith.team = team
	buildings_container.add_child(blacksmith)
	spawned_entities.append(blacksmith)
	return blacksmith


func spawn_tree(position: Vector2, amount: int = 100) -> Node:
	var tree = TREE_SCENE.instantiate()
	tree.global_position = position
	tree.total_amount = amount
	resources_container.add_child(tree)
	spawned_entities.append(tree)
	return tree


func spawn_berry_bush(position: Vector2, amount: int = 100) -> Node:
	var bush = BERRY_BUSH_SCENE.instantiate()
	bush.global_position = position
	bush.total_amount = amount
	resources_container.add_child(bush)
	spawned_entities.append(bush)
	return bush


func spawn_gold_mine(position: Vector2, amount: int = 800) -> Node:
	var mine = GOLD_MINE_SCENE.instantiate()
	mine.global_position = position
	mine.total_amount = amount
	resources_container.add_child(mine)
	spawned_entities.append(mine)
	return mine


func spawn_stone_mine(position: Vector2, amount: int = 350) -> Node:
	var mine = STONE_MINE_SCENE.instantiate()
	mine.global_position = position
	mine.total_amount = amount
	resources_container.add_child(mine)
	spawned_entities.append(mine)
	return mine


func spawn_food_carcass(position: Vector2, amount: int = 100) -> Node:
	var carcass = FOOD_CARCASS_SCENE.instantiate()
	carcass.global_position = position
	carcass.total_amount = amount
	carcass.current_amount = amount
	resources_container.add_child(carcass)
	spawned_entities.append(carcass)
	return carcass


func spawn_sheep(position: Vector2, team: int = -1) -> Node:
	var sheep = SHEEP_SCENE.instantiate()
	sheep.global_position = position
	units_container.add_child(sheep)
	# Set team after adding to tree (sheep starts neutral by default)
	if team != -1:
		sheep.team = team
		sheep._apply_team_color()
	spawned_entities.append(sheep)
	return sheep


func spawn_deer(position: Vector2) -> Node:
	var deer = DEER_SCENE.instantiate()
	deer.global_position = position
	units_container.add_child(deer)
	spawned_entities.append(deer)
	return deer


func spawn_boar(position: Vector2) -> Node:
	var boar = BOAR_SCENE.instantiate()
	boar.global_position = position
	units_container.add_child(boar)
	spawned_entities.append(boar)
	return boar


func spawn_wolf(position: Vector2) -> Node:
	var wolf = WOLF_SCENE.instantiate()
	wolf.global_position = position
	units_container.add_child(wolf)
	spawned_entities.append(wolf)
	return wolf


func clear_all() -> void:
	for entity in spawned_entities:
		if is_instance_valid(entity):
			entity.queue_free()
	spawned_entities.clear()

	# Also clear GameManager selection state
	GameManager.clear_selection()
