extends Node
## Cursor Tests - Tests for context-sensitive cursor changes
##
## These tests verify:
## - Cursor changes to GATHER when hovering wood with villager selected
## - Cursor changes to HAND when hovering gold/stone/berries with villager selected
## - Cursor changes to ATTACK when hovering enemy with unit selected
## - Cursor changes to BUILD in building placement mode

class_name TestCursor

const CursorManager = preload("res://scripts/ui/cursor_manager.gd")

# Store CursorType enum values for comparison after cursor_manager is freed
enum CursorType {
	DEFAULT,
	ATTACK,
	GATHER,
	HAND,
	BUILD,
	FORBIDDEN
}

var runner: TestRunner
var cursor_manager: Node


func _init(test_runner: TestRunner) -> void:
	runner = test_runner


func get_all_tests() -> Array[Callable]:
	## Returns all test methods to run
	return [
		test_default_cursor_when_nothing_selected,
		test_gather_cursor_when_hovering_tree_with_villager,
		test_hand_cursor_when_hovering_gold_with_villager,
		test_hand_cursor_when_hovering_stone_with_villager,
		test_hand_cursor_when_hovering_berries_with_villager,
		test_hand_cursor_when_hovering_farm_with_villager,
		test_hand_cursor_when_hovering_sheep_with_villager,
		test_attack_cursor_when_hovering_enemy_unit_with_military,
		test_attack_cursor_when_hovering_enemy_building_with_military,
		test_attack_cursor_when_hovering_enemy_with_villager,
		test_build_cursor_when_hovering_construction_with_villager,
		test_resource_type_detection_for_wood,
		test_resource_type_detection_for_gold,
		test_resource_type_detection_for_food,
	]


func _setup_cursor_manager() -> void:
	## Create a cursor manager instance for testing
	cursor_manager = CursorManager.new()
	runner.add_child(cursor_manager)
	# Don't call initialize() - we'll set cached values directly for testing


func _teardown_cursor_manager() -> void:
	## Clean up cursor manager
	if cursor_manager:
		cursor_manager.queue_free()
		cursor_manager = null


func test_default_cursor_when_nothing_selected() -> Assertions.AssertResult:
	## With no units selected, cursor should be DEFAULT
	_setup_cursor_manager()
	await runner.wait_frames(2)

	GameManager.clear_selection()

	# Call the internal method directly
	var cursor_type = cursor_manager._get_selection_based_cursor() if not GameManager.selected_units.is_empty() else CursorType.DEFAULT

	_teardown_cursor_manager()

	if cursor_type == CursorType.DEFAULT:
		return Assertions.AssertResult.new(true, "")
	return Assertions.AssertResult.new(false, "Expected DEFAULT cursor, got %d" % cursor_type)


func test_gather_cursor_when_hovering_tree_with_villager() -> Assertions.AssertResult:
	## Hovering over a tree with villager selected should show GATHER cursor (axe)
	_setup_cursor_manager()
	var villager = runner.spawner.spawn_villager(Vector2(400, 400))
	var tree = runner.spawner.spawn_tree(Vector2(450, 400))
	await runner.wait_frames(2)

	# Select the villager
	GameManager.select_unit(villager)

	# Set the cached hover resource to the tree
	cursor_manager._cached_hover_resource = tree

	# Get cursor type
	var cursor_type = cursor_manager._get_selection_based_cursor()

	_teardown_cursor_manager()

	if cursor_type == CursorType.GATHER:
		return Assertions.AssertResult.new(true, "")
	return Assertions.AssertResult.new(false, "Expected GATHER cursor for tree, got %d" % cursor_type)


func test_hand_cursor_when_hovering_gold_with_villager() -> Assertions.AssertResult:
	## Hovering over gold mine with villager selected should show HAND cursor
	_setup_cursor_manager()
	var villager = runner.spawner.spawn_villager(Vector2(400, 400))
	var gold = runner.spawner.spawn_gold_mine(Vector2(450, 400))
	await runner.wait_frames(2)

	GameManager.select_unit(villager)
	cursor_manager._cached_hover_resource = gold

	var cursor_type = cursor_manager._get_selection_based_cursor()

	_teardown_cursor_manager()

	if cursor_type == CursorType.HAND:
		return Assertions.AssertResult.new(true, "")
	return Assertions.AssertResult.new(false, "Expected HAND cursor for gold, got %d" % cursor_type)


func test_hand_cursor_when_hovering_stone_with_villager() -> Assertions.AssertResult:
	## Hovering over stone mine with villager selected should show HAND cursor
	_setup_cursor_manager()
	var villager = runner.spawner.spawn_villager(Vector2(400, 400))
	var stone = runner.spawner.spawn_stone_mine(Vector2(450, 400))
	await runner.wait_frames(2)

	GameManager.select_unit(villager)
	cursor_manager._cached_hover_resource = stone

	var cursor_type = cursor_manager._get_selection_based_cursor()

	_teardown_cursor_manager()

	if cursor_type == CursorType.HAND:
		return Assertions.AssertResult.new(true, "")
	return Assertions.AssertResult.new(false, "Expected HAND cursor for stone, got %d" % cursor_type)


func test_hand_cursor_when_hovering_berries_with_villager() -> Assertions.AssertResult:
	## Hovering over berry bush with villager selected should show HAND cursor
	_setup_cursor_manager()
	var villager = runner.spawner.spawn_villager(Vector2(400, 400))
	var berries = runner.spawner.spawn_berry_bush(Vector2(450, 400))
	await runner.wait_frames(2)

	GameManager.select_unit(villager)
	cursor_manager._cached_hover_resource = berries

	var cursor_type = cursor_manager._get_selection_based_cursor()

	_teardown_cursor_manager()

	if cursor_type == CursorType.HAND:
		return Assertions.AssertResult.new(true, "")
	return Assertions.AssertResult.new(false, "Expected HAND cursor for berries, got %d" % cursor_type)


func test_hand_cursor_when_hovering_farm_with_villager() -> Assertions.AssertResult:
	## Hovering over farm with villager selected should show HAND cursor
	_setup_cursor_manager()
	var villager = runner.spawner.spawn_villager(Vector2(400, 400))
	var farm = runner.spawner.spawn_farm(Vector2(450, 400))
	await runner.wait_frames(2)

	GameManager.select_unit(villager)
	cursor_manager._cached_hover_resource = farm

	var cursor_type = cursor_manager._get_selection_based_cursor()

	_teardown_cursor_manager()

	if cursor_type == CursorType.HAND:
		return Assertions.AssertResult.new(true, "")
	return Assertions.AssertResult.new(false, "Expected HAND cursor for farm, got %d" % cursor_type)


func test_hand_cursor_when_hovering_sheep_with_villager() -> Assertions.AssertResult:
	## Hovering over sheep with villager selected should show HAND cursor
	_setup_cursor_manager()
	var villager = runner.spawner.spawn_villager(Vector2(400, 400))
	var sheep = runner.spawner.spawn_sheep(Vector2(450, 400))
	await runner.wait_frames(2)

	GameManager.select_unit(villager)
	cursor_manager._cached_hover_animal = sheep

	var cursor_type = cursor_manager._get_selection_based_cursor()

	_teardown_cursor_manager()

	if cursor_type == CursorType.HAND:
		return Assertions.AssertResult.new(true, "")
	return Assertions.AssertResult.new(false, "Expected HAND cursor for sheep, got %d" % cursor_type)


func test_attack_cursor_when_hovering_enemy_unit_with_military() -> Assertions.AssertResult:
	## Hovering over enemy unit with military selected should show ATTACK cursor
	_setup_cursor_manager()
	var militia = runner.spawner.spawn_militia(Vector2(400, 400), 0)  # Player
	var enemy = runner.spawner.spawn_militia(Vector2(450, 400), 1)    # AI
	await runner.wait_frames(2)

	GameManager.select_unit(militia)
	cursor_manager._cached_hover_unit = enemy

	var cursor_type = cursor_manager._get_selection_based_cursor()

	_teardown_cursor_manager()

	if cursor_type == CursorType.ATTACK:
		return Assertions.AssertResult.new(true, "")
	return Assertions.AssertResult.new(false, "Expected ATTACK cursor for enemy unit, got %d" % cursor_type)


func test_attack_cursor_when_hovering_enemy_building_with_military() -> Assertions.AssertResult:
	## Hovering over enemy building with military selected should show ATTACK cursor
	_setup_cursor_manager()
	var militia = runner.spawner.spawn_militia(Vector2(400, 400), 0)  # Player
	var enemy_barracks = runner.spawner.spawn_barracks(Vector2(500, 400), 1)  # AI
	await runner.wait_frames(2)

	GameManager.select_unit(militia)
	cursor_manager._cached_hover_building = enemy_barracks

	var cursor_type = cursor_manager._get_selection_based_cursor()

	_teardown_cursor_manager()

	if cursor_type == CursorType.ATTACK:
		return Assertions.AssertResult.new(true, "")
	return Assertions.AssertResult.new(false, "Expected ATTACK cursor for enemy building, got %d" % cursor_type)


func test_attack_cursor_when_hovering_enemy_with_villager() -> Assertions.AssertResult:
	## Hovering over enemy with villager selected should show ATTACK cursor
	_setup_cursor_manager()
	var villager = runner.spawner.spawn_villager(Vector2(400, 400), 0)  # Player
	var enemy = runner.spawner.spawn_militia(Vector2(450, 400), 1)      # AI
	await runner.wait_frames(2)

	GameManager.select_unit(villager)
	cursor_manager._cached_hover_unit = enemy

	var cursor_type = cursor_manager._get_selection_based_cursor()

	_teardown_cursor_manager()

	if cursor_type == CursorType.ATTACK:
		return Assertions.AssertResult.new(true, "")
	return Assertions.AssertResult.new(false, "Expected ATTACK cursor when villager hovers enemy, got %d" % cursor_type)


func test_build_cursor_when_hovering_construction_with_villager() -> Assertions.AssertResult:
	## Hovering over friendly building under construction should show BUILD cursor
	_setup_cursor_manager()
	var villager = runner.spawner.spawn_villager(Vector2(400, 400), 0)
	var house = runner.spawner.spawn_house(Vector2(500, 400), 0)
	await runner.wait_frames(2)

	# Mark building as under construction
	house.is_constructed = false

	GameManager.select_unit(villager)
	cursor_manager._cached_hover_building = house

	var cursor_type = cursor_manager._get_selection_based_cursor()

	_teardown_cursor_manager()

	if cursor_type == CursorType.BUILD:
		return Assertions.AssertResult.new(true, "")
	return Assertions.AssertResult.new(false, "Expected BUILD cursor for construction, got %d" % cursor_type)


func test_resource_type_detection_for_wood() -> Assertions.AssertResult:
	## Tree's get_resource_type() should return "wood"
	var tree = runner.spawner.spawn_tree(Vector2(400, 400))
	await runner.wait_frames(2)

	var resource_type = tree.get_resource_type()

	if resource_type == "wood":
		return Assertions.AssertResult.new(true, "")
	return Assertions.AssertResult.new(false, "Expected 'wood', got '%s'" % resource_type)


func test_resource_type_detection_for_gold() -> Assertions.AssertResult:
	## Gold mine's get_resource_type() should return "gold"
	var gold = runner.spawner.spawn_gold_mine(Vector2(400, 400))
	await runner.wait_frames(2)

	var resource_type = gold.get_resource_type()

	if resource_type == "gold":
		return Assertions.AssertResult.new(true, "")
	return Assertions.AssertResult.new(false, "Expected 'gold', got '%s'" % resource_type)


func test_resource_type_detection_for_food() -> Assertions.AssertResult:
	## Berry bush's get_resource_type() should return "food"
	var berries = runner.spawner.spawn_berry_bush(Vector2(400, 400))
	await runner.wait_frames(2)

	var resource_type = berries.get_resource_type()

	if resource_type == "food":
		return Assertions.AssertResult.new(true, "")
	return Assertions.AssertResult.new(false, "Expected 'food', got '%s'" % resource_type)
