extends Node
## Economy Tests - Tests for Phase 1A Core Economy features
##
## These tests verify:
## - GameManager resource API (add, spend, can_afford)
## - Market buy/sell with dynamic pricing
## - Villager gathering and deposit behavior

class_name TestEconomy

var runner: TestRunner


func _init(test_runner: TestRunner) -> void:
	runner = test_runner


func get_all_tests() -> Array[Callable]:
	## Returns all test methods to run
	return [
		# GameManager API tests (fast, no simulation)
		test_add_resource_increases_total,
		test_spend_resource_decreases_total,
		test_spend_resource_fails_if_insufficient,
		test_can_afford_checks_correctly,
		test_starting_resources_correct,
		# Market system tests
		test_market_buy_exchanges_gold_for_resource,
		test_market_sell_exchanges_resource_for_gold,
		test_market_buy_increases_price,
		test_market_sell_decreases_price,
		# Villager gathering tests (simulation)
		test_villager_gathers_wood_from_tree,
		test_villager_deposits_at_correct_building,
		test_villager_returns_to_gathering_after_deposit,
	]


# === GameManager API Tests ===

func test_add_resource_increases_total() -> Assertions.AssertResult:
	## Adding resources should increase the total
	var initial_wood = GameManager.get_resource("wood")
	GameManager.add_resource("wood", 50)

	var result = Assertions.assert_resource("wood", initial_wood + 50)
	return result


func test_spend_resource_decreases_total() -> Assertions.AssertResult:
	## Spending resources should decrease the total and return true
	GameManager.resources["gold"] = 100  # Set known amount
	var success = GameManager.spend_resource("gold", 30)

	if not success:
		return Assertions.AssertResult.new(false, "spend_resource returned false unexpectedly")

	return Assertions.assert_resource("gold", 70)


func test_spend_resource_fails_if_insufficient() -> Assertions.AssertResult:
	## Spending more than available should fail and not change the amount
	GameManager.resources["stone"] = 50  # Set known amount
	var success = GameManager.spend_resource("stone", 100)

	if success:
		return Assertions.AssertResult.new(false, "spend_resource should have returned false")

	return Assertions.assert_resource("stone", 50)


func test_can_afford_checks_correctly() -> Assertions.AssertResult:
	## can_afford should return correct boolean based on resource amount
	GameManager.resources["food"] = 75

	var can_afford_50 = GameManager.can_afford("food", 50)
	var can_afford_75 = GameManager.can_afford("food", 75)
	var can_afford_100 = GameManager.can_afford("food", 100)

	if not can_afford_50:
		return Assertions.AssertResult.new(false, "Should afford 50 when have 75")
	if not can_afford_75:
		return Assertions.AssertResult.new(false, "Should afford 75 when have 75 (exact)")
	if can_afford_100:
		return Assertions.AssertResult.new(false, "Should not afford 100 when have 75")

	return Assertions.AssertResult.new(true)


func test_starting_resources_correct() -> Assertions.AssertResult:
	## After reset, resources should match starting values
	# reset() is called in _before_each, so check the standard starting values
	var result = Assertions.assert_resource("wood", 200)
	if not result.passed:
		return result

	result = Assertions.assert_resource("food", 200)
	if not result.passed:
		return result

	result = Assertions.assert_resource("gold", 0)
	if not result.passed:
		return result

	return Assertions.assert_resource("stone", 0)


# === Market System Tests ===

func test_market_buy_exchanges_gold_for_resource() -> Assertions.AssertResult:
	## Buying from market should spend gold and gain resource
	GameManager.resources["gold"] = 200
	GameManager.resources["wood"] = 0

	var buy_price = GameManager.get_market_buy_price("wood")
	var success = GameManager.market_buy("wood")

	if not success:
		return Assertions.AssertResult.new(false, "market_buy returned false unexpectedly")

	# Should have gained 100 wood
	var result = Assertions.assert_resource("wood", 100)
	if not result.passed:
		return result

	# Should have spent the buy price in gold
	return Assertions.assert_resource("gold", 200 - buy_price)


func test_market_sell_exchanges_resource_for_gold() -> Assertions.AssertResult:
	## Selling to market should spend resource and gain gold
	GameManager.resources["food"] = 200
	GameManager.resources["gold"] = 0

	var sell_price = GameManager.get_market_sell_price("food")
	var success = GameManager.market_sell("food")

	if not success:
		return Assertions.AssertResult.new(false, "market_sell returned false unexpectedly")

	# Should have lost 100 food
	var result = Assertions.assert_resource("food", 100)
	if not result.passed:
		return result

	# Should have gained the sell price in gold
	return Assertions.assert_resource("gold", sell_price)


func test_market_buy_increases_price() -> Assertions.AssertResult:
	## Buying should increase the price (demand drives price up)
	GameManager.reset_market_prices()
	GameManager.resources["gold"] = 1000

	var initial_price = GameManager.get_market_buy_price("wood")
	GameManager.market_buy("wood")
	var new_price = GameManager.get_market_buy_price("wood")

	if new_price <= initial_price:
		return Assertions.AssertResult.new(false,
			"Price should increase after buy: was %d, now %d" % [initial_price, new_price])

	return Assertions.AssertResult.new(true)


func test_market_sell_decreases_price() -> Assertions.AssertResult:
	## Selling should decrease the price (supply drives price down)
	GameManager.reset_market_prices()
	GameManager.resources["stone"] = 500

	var initial_price = GameManager.get_market_buy_price("stone")
	GameManager.market_sell("stone")
	var new_price = GameManager.get_market_buy_price("stone")

	if new_price >= initial_price:
		return Assertions.AssertResult.new(false,
			"Price should decrease after sell: was %d, now %d" % [initial_price, new_price])

	return Assertions.AssertResult.new(true)


# === Villager Gathering Tests ===
# Note: These tests use direct state manipulation where possible to avoid
# relying on physics simulation timing, which can vary in headless mode.

func test_villager_gathers_wood_from_tree() -> Assertions.AssertResult:
	## Villager command_gather should set the correct state and target
	var villager = runner.spawner.spawn_villager(Vector2(400, 400))
	var tree = runner.spawner.spawn_tree(Vector2(420, 400), 100)
	await runner.wait_frames(2)

	# Command villager to gather
	villager.command_gather(tree)
	await runner.wait_frames(2)

	# Verify state changed to gathering and target is set
	var result = Assertions.assert_villager_state(villager, Villager.State.GATHERING)
	if not result.passed:
		return result

	# Verify the target resource is set correctly
	if villager.target_resource != tree:
		return Assertions.AssertResult.new(false,
			"Villager should target the tree, but target_resource is %s" % str(villager.target_resource))

	# Verify carried_resource_type is set for wood
	return Assertions.assert_true(villager.carried_resource_type == "wood",
		"Villager should have carried_resource_type = 'wood', got: %s" % villager.carried_resource_type)


func test_villager_deposits_at_correct_building() -> Assertions.AssertResult:
	## Villager with wood should choose lumber camp over closer mill (which doesn't accept wood)
	var villager = runner.spawner.spawn_villager(Vector2(400, 400))
	# Place mill CLOSER than lumber camp - villager should still choose lumber camp
	var mill = runner.spawner.spawn_mill(Vector2(380, 400))  # Closer to villager
	var lumber_camp = runner.spawner.spawn_lumber_camp(Vector2(500, 400))  # Further away
	await runner.wait_frames(2)

	# Set up villager with carried wood
	villager.carried_resource_type = "wood"
	villager.carried_amount = 10

	# Test _find_drop_off directly - should skip mill (doesn't accept wood) and find lumber_camp
	var drop_off = villager._find_drop_off("wood")

	if drop_off == null:
		return Assertions.AssertResult.new(false,
			"_find_drop_off should find a building for wood")

	if drop_off != lumber_camp:
		return Assertions.AssertResult.new(false,
			"_find_drop_off for wood should return lumber_camp (skipping closer mill), got: %s" % str(drop_off))

	# Verify mill is correctly chosen for food
	var food_drop_off = villager._find_drop_off("food")
	if food_drop_off != mill:
		return Assertions.AssertResult.new(false,
			"_find_drop_off for food should return mill, got: %s" % str(food_drop_off))

	return Assertions.AssertResult.new(true)


func test_villager_returns_to_gathering_after_deposit() -> Assertions.AssertResult:
	## After _deposit_resources with valid target_resource, villager should resume GATHERING
	var villager = runner.spawner.spawn_villager(Vector2(400, 400))
	var tree = runner.spawner.spawn_tree(Vector2(450, 400), 500)
	var lumber_camp = runner.spawner.spawn_lumber_camp(Vector2(350, 400))  # Needed for realistic state
	await runner.wait_frames(2)

	# Set up villager as if it just gathered and is at the drop-off
	villager.carried_resource_type = "wood"
	villager.carried_amount = 10
	villager.target_resource = tree
	villager.drop_off_building = lumber_camp
	villager.current_state = Villager.State.RETURNING

	# Record initial wood before deposit
	var initial_wood = GameManager.get_resource("wood")

	# Call _deposit_resources directly
	villager._deposit_resources()
	await runner.wait_frames(2)

	# Verify resources were deposited
	var result = Assertions.assert_resource("wood", initial_wood + 10)
	if not result.passed:
		return result

	# Verify carried amount is now 0
	if villager.carried_amount != 0:
		return Assertions.AssertResult.new(false,
			"Villager carried_amount should be 0 after deposit, got: %d" % villager.carried_amount)

	# Verify villager returned to gathering state (target_resource still valid)
	return Assertions.assert_villager_state(villager, Villager.State.GATHERING)
