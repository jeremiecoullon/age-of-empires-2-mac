extends Node
## Economy Tests - Tests for Phase 1A Core Economy features and Phase 1E Market & Trading
##
## These tests verify:
## - GameManager resource API (add, spend, can_afford)
## - Market buy/sell with dynamic pricing
## - Market price bounds and spread
## - Trade Cart gold generation formula
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
		# Market system tests (basic)
		test_market_buy_exchanges_gold_for_resource,
		test_market_sell_exchanges_resource_for_gold,
		test_market_buy_increases_price,
		test_market_sell_decreases_price,
		# Market system tests (Phase 1E - advanced)
		test_market_price_change_exact_amount,
		test_market_price_min_bound,
		test_market_price_max_bound,
		test_market_sell_price_spread,
		test_market_cannot_buy_gold,
		test_market_cannot_sell_gold,
		test_market_buy_fails_without_gold,
		test_market_sell_fails_without_resource,
		test_market_prices_changed_signal,
		# Trade Cart gold formula tests
		test_trade_cart_gold_formula,
		test_trade_cart_gold_minimum_one,
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


# === Market Advanced Tests (Phase 1E) ===

func test_market_price_change_exact_amount() -> Assertions.AssertResult:
	## Price should change by exactly PRICE_CHANGE_PER_TRADE (3) per trade
	GameManager.reset_market_prices()
	GameManager.resources["gold"] = 1000
	GameManager.resources["wood"] = 500

	var initial_price = GameManager.get_market_buy_price("wood")
	GameManager.market_buy("wood")
	var price_after_buy = GameManager.get_market_buy_price("wood")

	# Buy should increase by 3
	if price_after_buy != initial_price + GameManager.PRICE_CHANGE_PER_TRADE:
		return Assertions.AssertResult.new(false,
			"Buy should increase price by %d: was %d, now %d (expected %d)" % [
				GameManager.PRICE_CHANGE_PER_TRADE, initial_price, price_after_buy,
				initial_price + GameManager.PRICE_CHANGE_PER_TRADE])

	# Sell should decrease by 3
	var price_before_sell = GameManager.get_market_buy_price("wood")
	GameManager.market_sell("wood")
	var price_after_sell = GameManager.get_market_buy_price("wood")

	if price_after_sell != price_before_sell - GameManager.PRICE_CHANGE_PER_TRADE:
		return Assertions.AssertResult.new(false,
			"Sell should decrease price by %d: was %d, now %d (expected %d)" % [
				GameManager.PRICE_CHANGE_PER_TRADE, price_before_sell, price_after_sell,
				price_before_sell - GameManager.PRICE_CHANGE_PER_TRADE])

	return Assertions.AssertResult.new(true)


func test_market_price_min_bound() -> Assertions.AssertResult:
	## Price should not go below MIN_MARKET_PRICE (20)
	GameManager.reset_market_prices()
	GameManager.resources["wood"] = 10000

	# Sell many times to drive price down
	for i in range(50):
		GameManager.resources["wood"] = 1000  # Refill each iteration
		GameManager.market_sell("wood")

	var final_price = GameManager.get_market_buy_price("wood")

	if final_price < GameManager.MIN_MARKET_PRICE:
		return Assertions.AssertResult.new(false,
			"Price should not go below %d, got: %d" % [GameManager.MIN_MARKET_PRICE, final_price])

	if final_price != GameManager.MIN_MARKET_PRICE:
		return Assertions.AssertResult.new(false,
			"Price should hit exactly %d after many sells, got: %d" % [GameManager.MIN_MARKET_PRICE, final_price])

	return Assertions.AssertResult.new(true)


func test_market_price_max_bound() -> Assertions.AssertResult:
	## Price should not go above MAX_MARKET_PRICE (300)
	GameManager.reset_market_prices()
	GameManager.resources["gold"] = 100000

	# Buy many times to drive price up
	for i in range(100):
		GameManager.resources["gold"] = 10000  # Refill each iteration
		GameManager.market_buy("wood")

	var final_price = GameManager.get_market_buy_price("wood")

	if final_price > GameManager.MAX_MARKET_PRICE:
		return Assertions.AssertResult.new(false,
			"Price should not go above %d, got: %d" % [GameManager.MAX_MARKET_PRICE, final_price])

	if final_price != GameManager.MAX_MARKET_PRICE:
		return Assertions.AssertResult.new(false,
			"Price should hit exactly %d after many buys, got: %d" % [GameManager.MAX_MARKET_PRICE, final_price])

	return Assertions.AssertResult.new(true)


func test_market_sell_price_spread() -> Assertions.AssertResult:
	## Sell price should be ~70% of buy price (AoE2-style spread)
	GameManager.reset_market_prices()

	var buy_price = GameManager.get_market_buy_price("wood")
	var sell_price = GameManager.get_market_sell_price("wood")
	var expected_sell = int(buy_price * 0.7)

	if sell_price != expected_sell:
		return Assertions.AssertResult.new(false,
			"Sell price should be 70%% of buy price. Buy: %d, Sell: %d, Expected: %d" % [
				buy_price, sell_price, expected_sell])

	return Assertions.AssertResult.new(true)


func test_market_cannot_buy_gold() -> Assertions.AssertResult:
	## Cannot buy gold (gold is the trading currency)
	GameManager.resources["gold"] = 1000

	var result = GameManager.market_buy("gold")

	if result:
		return Assertions.AssertResult.new(false,
			"market_buy('gold') should return false")

	return Assertions.AssertResult.new(true)


func test_market_cannot_sell_gold() -> Assertions.AssertResult:
	## Cannot sell gold (gold is the trading currency)
	GameManager.resources["gold"] = 1000

	var result = GameManager.market_sell("gold")

	if result:
		return Assertions.AssertResult.new(false,
			"market_sell('gold') should return false")

	return Assertions.AssertResult.new(true)


func test_market_buy_fails_without_gold() -> Assertions.AssertResult:
	## market_buy should fail if player doesn't have enough gold
	GameManager.reset_market_prices()
	GameManager.resources["gold"] = 10  # Not enough (buy price is 100 for wood)

	var result = GameManager.market_buy("wood")

	if result:
		return Assertions.AssertResult.new(false,
			"market_buy should fail when gold is insufficient")

	# Verify gold wasn't spent
	if GameManager.resources["gold"] != 10:
		return Assertions.AssertResult.new(false,
			"Gold should be unchanged after failed buy")

	return Assertions.AssertResult.new(true)


func test_market_sell_fails_without_resource() -> Assertions.AssertResult:
	## market_sell should fail if player doesn't have enough of the resource
	GameManager.reset_market_prices()
	GameManager.resources["wood"] = 50  # Not enough (need 100 to sell)
	GameManager.resources["gold"] = 0

	var result = GameManager.market_sell("wood")

	if result:
		return Assertions.AssertResult.new(false,
			"market_sell should fail when resource is insufficient")

	# Verify wood wasn't spent
	if GameManager.resources["wood"] != 50:
		return Assertions.AssertResult.new(false,
			"Wood should be unchanged after failed sell")

	return Assertions.AssertResult.new(true)


func test_market_prices_changed_signal() -> Assertions.AssertResult:
	## market_prices_changed signal should emit when prices change
	GameManager.reset_market_prices()
	GameManager.resources["gold"] = 1000

	var signal_count = [0]
	var handler = func(): signal_count[0] += 1
	GameManager.market_prices_changed.connect(handler)

	# Buy should emit signal
	GameManager.market_buy("wood")

	# Disconnect to prevent affecting other tests
	GameManager.market_prices_changed.disconnect(handler)

	if signal_count[0] != 1:
		return Assertions.AssertResult.new(false,
			"market_prices_changed should emit once after buy, got: %d" % signal_count[0])

	return Assertions.AssertResult.new(true)


# === Trade Cart Gold Formula Tests ===

func test_trade_cart_gold_formula() -> Assertions.AssertResult:
	## Trade Cart gold earned should scale with distance: distance_tiles * BASE_GOLD_PER_TILE
	# Create two markets 320 pixels apart
	var market1 = runner.spawner.spawn_market(Vector2(400, 400))
	var market2 = runner.spawner.spawn_market(Vector2(720, 400))
	await runner.wait_frames(2)

	var cart = runner.spawner.spawn_trade_cart(Vector2(400, 400), 0, market1)
	await runner.wait_frames(2)

	cart.destination_market = market2
	GameManager.resources["gold"] = 0

	# Call _complete_trade directly to test the formula
	cart._complete_trade()

	# Formula: distance_tiles * BASE_GOLD_PER_TILE, truncated to int
	var distance_px = 320.0
	var distance_tiles = distance_px / TradeCart.TILE_SIZE
	var expected_gold = int(distance_tiles * TradeCart.BASE_GOLD_PER_TILE)
	var actual_gold = GameManager.resources["gold"]

	if actual_gold != expected_gold:
		return Assertions.AssertResult.new(false,
			"Trade gold: expected %d (%.1f tiles * %.2f), got: %d" % [
				expected_gold, distance_tiles, TradeCart.BASE_GOLD_PER_TILE, actual_gold])

	return Assertions.AssertResult.new(true)


func test_trade_cart_gold_minimum_one() -> Assertions.AssertResult:
	## Trade Cart should earn at least 1 gold even for very short distances
	# Create two markets very close (less than 1 tile apart)
	var market1 = runner.spawner.spawn_market(Vector2(400, 400))
	var market2 = runner.spawner.spawn_market(Vector2(410, 400))  # Only 10px = 0.3 tiles
	await runner.wait_frames(2)

	var cart = runner.spawner.spawn_trade_cart(Vector2(400, 400), 0, market1)
	await runner.wait_frames(2)

	cart.destination_market = market2

	GameManager.resources["gold"] = 0
	cart._complete_trade()

	# 0.3 tiles * 0.46 = 0.14, which would round to 0, but minimum is 1
	var actual_gold = GameManager.resources["gold"]

	if actual_gold < 1:
		return Assertions.AssertResult.new(false,
			"Trade should earn minimum 1 gold even for short distances, got: %d" % actual_gold)

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
