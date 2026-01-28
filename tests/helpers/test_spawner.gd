extends Node
## Test Spawner - Creates entities at known positions for testing
##
## Usage:
##   var spawner = TestSpawner.new()
##   add_child(spawner)
##   spawner.setup(units_container, buildings_container)
##   var villager = spawner.spawn_villager(Vector2(100, 100))

class_name TestSpawner

# Scene paths
const VILLAGER_SCENE = preload("res://scenes/units/villager.tscn")
const MILITIA_SCENE = preload("res://scenes/units/militia.tscn")
const TOWN_CENTER_SCENE = preload("res://scenes/buildings/town_center.tscn")
const HOUSE_SCENE = preload("res://scenes/buildings/house.tscn")
const BARRACKS_SCENE = preload("res://scenes/buildings/barracks.tscn")

# Container references
var units_container: Node2D
var buildings_container: Node2D

# Track spawned entities for cleanup
var spawned_entities: Array[Node] = []


func setup(units: Node2D, buildings: Node2D) -> void:
	units_container = units
	buildings_container = buildings


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


func clear_all() -> void:
	for entity in spawned_entities:
		if is_instance_valid(entity):
			entity.queue_free()
	spawned_entities.clear()

	# Also clear GameManager selection state
	GameManager.clear_selection()
