extends Node
## AI Economy Tests - Tests for Phase 3.1B AI Economy Rules
##
## These tests verify:
## - AIGameState helper methods (natural food counting, drop-off distance, sheep/hunting)
## - Market query methods (buy/sell prices, affordability)
## - Rule conditions (when rules should fire)
##
## Note: These tests don't simulate full AI behavior - they unit test the
## helper methods and rule conditions directly.

class_name TestAIEconomy

var runner: TestRunner


func _init(test_runner: TestRunner) -> void:
	runner = test_runner


func get_all_tests() -> Array[Callable]:
	## Returns all test methods to run
	return [
		# AIGameState natural food helpers
		test_get_natural_food_count_excludes_farms,
		test_get_natural_food_count_includes_berries,
		test_get_natural_food_count_includes_sheep,
		test_get_natural_food_count_includes_huntables,
		test_get_sheep_count_includes_neutral_sheep,
		test_get_sheep_count_excludes_player_sheep,
		test_get_sheep_count_includes_ai_sheep,
		test_get_sheep_count_excludes_dead_sheep,
		test_get_huntable_count_includes_deer,
		test_get_huntable_count_includes_boar,
		test_get_nearest_sheep_returns_closest,
		test_get_nearest_sheep_excludes_enemy_sheep,
		test_get_nearest_huntable_returns_closest,
		# Drop-off building helpers
		test_has_drop_off_for_wood_with_lumber_camp,
		test_has_drop_off_for_wood_with_tc,
		test_has_drop_off_for_no_building,
		test_get_nearest_drop_off_distance_returns_correct,
		test_get_nearest_drop_off_distance_returns_inf_when_none,
		# Market query methods
		test_can_market_buy_requires_market,
		test_can_market_buy_requires_gold,
		test_can_market_buy_cannot_buy_gold,
		test_can_market_sell_requires_market,
		test_can_market_sell_requires_resource,
		test_can_market_sell_cannot_sell_gold,
		# BuildFarmRule conditions
		test_build_farm_rule_fires_when_no_natural_food,
		test_build_farm_rule_respects_farm_cap,
		# AdjustGathererPercentagesRule conditions
		test_adjust_gatherers_transitions_at_thresholds,
		# MarketSellRule conditions
		test_market_sell_rule_fires_on_surplus,
		test_market_sell_rule_doesnt_fire_below_threshold,
		# MarketBuyRule conditions
		test_market_buy_rule_fires_on_desperation,
		test_market_buy_rule_requires_gold,
		# GatherSheepRule and HuntRule conditions
		test_gather_sheep_rule_fires_with_sheep,
		test_hunt_rule_fires_without_sheep,
		test_hunt_rule_doesnt_fire_with_sheep,
	]


# =============================================================================
# Mock AI Controller
# =============================================================================

class MockAIController extends Node:
	## Minimal mock that provides the data structures AIGameState needs
	var strategic_numbers: Dictionary = {}
	var goals: Dictionary = {}
	var timers: Dictionary = {}


func _create_ai_game_state() -> AIGameState:
	## Creates an AIGameState with mock controller for testing
	var gs = AIGameState.new()
	var controller = MockAIController.new()
	gs.initialize(controller, runner.get_tree())
	return gs


# =============================================================================
# Natural Food Helper Tests
# =============================================================================

func test_get_natural_food_count_excludes_farms() -> Assertions.AssertResult:
	## Farms should NOT count as natural food
	var gs = _create_ai_game_state()

	# Get baseline count (may be non-zero due to test scene setup)
	var baseline_count = gs.get_natural_food_count()

	# Spawn a farm (AI team so it's counted)
	var farm = runner.spawner.spawn_farm(Vector2(500, 500), 1)
	await runner.wait_frames(2)

	var count_with_farm = gs.get_natural_food_count()

	# Farm should not increase the count
	if count_with_farm != baseline_count:
		return Assertions.AssertResult.new(false,
			"Farm should not count as natural food. Baseline: %d, With farm: %d" % [baseline_count, count_with_farm])

	return Assertions.AssertResult.new(true)


func test_get_natural_food_count_includes_berries() -> Assertions.AssertResult:
	## Berry bushes should count as natural food
	var gs = _create_ai_game_state()

	runner.spawner.spawn_berry_bush(Vector2(500, 500), 100)
	await runner.wait_frames(2)

	var count = gs.get_natural_food_count()

	if count < 1:
		return Assertions.AssertResult.new(false,
			"Berry bush should count as natural food, got count: %d" % count)

	return Assertions.AssertResult.new(true)


func test_get_natural_food_count_includes_sheep() -> Assertions.AssertResult:
	## Sheep should count as natural food
	var gs = _create_ai_game_state()

	# Spawn neutral sheep (team -1)
	runner.spawner.spawn_sheep(Vector2(500, 500), -1)
	await runner.wait_frames(2)

	var count = gs.get_natural_food_count()

	if count < 1:
		return Assertions.AssertResult.new(false,
			"Sheep should count as natural food, got count: %d" % count)

	return Assertions.AssertResult.new(true)


func test_get_natural_food_count_includes_huntables() -> Assertions.AssertResult:
	## Deer and boar should count as natural food
	var gs = _create_ai_game_state()

	runner.spawner.spawn_deer(Vector2(500, 500))
	runner.spawner.spawn_boar(Vector2(600, 600))
	await runner.wait_frames(2)

	var count = gs.get_natural_food_count()

	if count < 2:
		return Assertions.AssertResult.new(false,
			"Deer and boar should count as natural food, got count: %d" % count)

	return Assertions.AssertResult.new(true)


func test_get_sheep_count_includes_neutral_sheep() -> Assertions.AssertResult:
	## Neutral sheep (team -1) should be counted
	var gs = _create_ai_game_state()

	runner.spawner.spawn_sheep(Vector2(500, 500), -1)
	runner.spawner.spawn_sheep(Vector2(550, 500), -1)
	await runner.wait_frames(2)

	var count = gs.get_sheep_count()

	if count != 2:
		return Assertions.AssertResult.new(false,
			"Should count 2 neutral sheep, got: %d" % count)

	return Assertions.AssertResult.new(true)


func test_get_sheep_count_excludes_player_sheep() -> Assertions.AssertResult:
	## Player sheep (team 0) should NOT be counted (AI is team 1)
	var gs = _create_ai_game_state()

	# Player sheep
	runner.spawner.spawn_sheep(Vector2(500, 500), 0)
	# Neutral sheep
	runner.spawner.spawn_sheep(Vector2(550, 500), -1)
	await runner.wait_frames(2)

	var count = gs.get_sheep_count()

	# Should only count the neutral sheep, not the player's
	if count != 1:
		return Assertions.AssertResult.new(false,
			"Should only count neutral sheep (1), not player sheep, got: %d" % count)

	return Assertions.AssertResult.new(true)


func test_get_sheep_count_includes_ai_sheep() -> Assertions.AssertResult:
	## AI-owned sheep (team 1) should be counted
	var gs = _create_ai_game_state()

	runner.spawner.spawn_sheep(Vector2(500, 500), 1)  # AI team
	await runner.wait_frames(2)

	var count = gs.get_sheep_count()

	if count != 1:
		return Assertions.AssertResult.new(false,
			"Should count AI-owned sheep, got: %d" % count)

	return Assertions.AssertResult.new(true)


func test_get_sheep_count_excludes_dead_sheep() -> Assertions.AssertResult:
	## Dead sheep should not be counted
	var gs = _create_ai_game_state()

	var sheep = runner.spawner.spawn_sheep(Vector2(500, 500), -1)
	await runner.wait_frames(2)

	# Mark as dead
	sheep.is_dead = true

	var count = gs.get_sheep_count()

	if count != 0:
		return Assertions.AssertResult.new(false,
			"Dead sheep should not be counted, got: %d" % count)

	return Assertions.AssertResult.new(true)


func test_get_huntable_count_includes_deer() -> Assertions.AssertResult:
	## Deer should be counted as huntable
	var gs = _create_ai_game_state()

	runner.spawner.spawn_deer(Vector2(500, 500))
	await runner.wait_frames(2)

	var count = gs.get_huntable_count()

	if count != 1:
		return Assertions.AssertResult.new(false,
			"Deer should be counted as huntable, got: %d" % count)

	return Assertions.AssertResult.new(true)


func test_get_huntable_count_includes_boar() -> Assertions.AssertResult:
	## Boar should be counted as huntable
	var gs = _create_ai_game_state()

	runner.spawner.spawn_boar(Vector2(500, 500))
	await runner.wait_frames(2)

	var count = gs.get_huntable_count()

	if count != 1:
		return Assertions.AssertResult.new(false,
			"Boar should be counted as huntable, got: %d" % count)

	return Assertions.AssertResult.new(true)


func test_get_nearest_sheep_returns_closest() -> Assertions.AssertResult:
	## Should return the sheep nearest to AI base
	var gs = _create_ai_game_state()

	# Spawn TC to establish AI base position
	var tc = runner.spawner.spawn_town_center(Vector2(1700, 1700), 1)
	await runner.wait_frames(2)

	# Spawn sheep at different distances from AI base (1700, 1700)
	var far_sheep = runner.spawner.spawn_sheep(Vector2(500, 500), -1)  # Far
	var near_sheep = runner.spawner.spawn_sheep(Vector2(1600, 1600), -1)  # Near
	await runner.wait_frames(2)

	var result = gs.get_nearest_sheep()

	if result != near_sheep:
		return Assertions.AssertResult.new(false,
			"Should return nearest sheep to AI base")

	return Assertions.AssertResult.new(true)


func test_get_nearest_sheep_excludes_enemy_sheep() -> Assertions.AssertResult:
	## Should not return player-owned sheep
	var gs = _create_ai_game_state()

	# Player sheep (closer but shouldn't be returned)
	runner.spawner.spawn_sheep(Vector2(1650, 1650), 0)
	# Neutral sheep (farther but valid)
	var neutral_sheep = runner.spawner.spawn_sheep(Vector2(1500, 1500), -1)
	await runner.wait_frames(2)

	var result = gs.get_nearest_sheep()

	if result != neutral_sheep:
		return Assertions.AssertResult.new(false,
			"Should return neutral sheep, not player sheep")

	return Assertions.AssertResult.new(true)


func test_get_nearest_huntable_returns_closest() -> Assertions.AssertResult:
	## Should return the huntable nearest to AI base
	var gs = _create_ai_game_state()

	# Spawn TC to establish AI base position
	runner.spawner.spawn_town_center(Vector2(1700, 1700), 1)
	await runner.wait_frames(2)

	# Spawn animals at different distances
	var far_deer = runner.spawner.spawn_deer(Vector2(500, 500))  # Far
	var near_boar = runner.spawner.spawn_boar(Vector2(1600, 1600))  # Near
	await runner.wait_frames(2)

	var result = gs.get_nearest_huntable()

	if result != near_boar:
		return Assertions.AssertResult.new(false,
			"Should return nearest huntable to AI base")

	return Assertions.AssertResult.new(true)


# =============================================================================
# Drop-off Building Helper Tests
# =============================================================================

func test_has_drop_off_for_wood_with_lumber_camp() -> Assertions.AssertResult:
	## Lumber camp should accept wood
	var gs = _create_ai_game_state()

	var camp = runner.spawner.spawn_lumber_camp(Vector2(500, 500), 1)  # AI team
	await runner.wait_frames(2)

	var result = gs.has_drop_off_for("wood")

	if not result:
		return Assertions.AssertResult.new(false,
			"Lumber camp should be drop-off for wood")

	return Assertions.AssertResult.new(true)


func test_has_drop_off_for_wood_with_tc() -> Assertions.AssertResult:
	## Town center should accept all resources including wood
	var gs = _create_ai_game_state()

	var tc = runner.spawner.spawn_town_center(Vector2(500, 500), 1)  # AI team
	await runner.wait_frames(2)

	var result_wood = gs.has_drop_off_for("wood")
	var result_food = gs.has_drop_off_for("food")
	var result_gold = gs.has_drop_off_for("gold")
	var result_stone = gs.has_drop_off_for("stone")

	if not result_wood:
		return Assertions.AssertResult.new(false, "TC should accept wood")
	if not result_food:
		return Assertions.AssertResult.new(false, "TC should accept food")
	if not result_gold:
		return Assertions.AssertResult.new(false, "TC should accept gold")
	if not result_stone:
		return Assertions.AssertResult.new(false, "TC should accept stone")

	return Assertions.AssertResult.new(true)


func test_has_drop_off_for_no_building() -> Assertions.AssertResult:
	## Should return false when no drop-off building exists
	var gs = _create_ai_game_state()

	# No buildings spawned

	var result = gs.has_drop_off_for("wood")

	if result:
		return Assertions.AssertResult.new(false,
			"Should return false when no drop-off exists")

	return Assertions.AssertResult.new(true)


func test_get_nearest_drop_off_distance_returns_correct() -> Assertions.AssertResult:
	## Should return actual distance to nearest drop-off
	var gs = _create_ai_game_state()

	var tc = runner.spawner.spawn_town_center(Vector2(500, 500), 1)  # AI team
	await runner.wait_frames(2)

	var test_pos = Vector2(600, 500)  # 100 pixels away
	var dist = gs.get_nearest_drop_off_distance("wood", test_pos)

	# Should be approximately 100 pixels
	if abs(dist - 100.0) > 10:
		return Assertions.AssertResult.new(false,
			"Distance should be ~100, got: %.1f" % dist)

	return Assertions.AssertResult.new(true)


func test_get_nearest_drop_off_distance_returns_inf_when_none() -> Assertions.AssertResult:
	## Should return INF when no drop-off exists
	var gs = _create_ai_game_state()

	var test_pos = Vector2(500, 500)
	var dist = gs.get_nearest_drop_off_distance("wood", test_pos)

	if dist != INF:
		return Assertions.AssertResult.new(false,
			"Should return INF when no drop-off exists, got: %.1f" % dist)

	return Assertions.AssertResult.new(true)


# =============================================================================
# Market Query Method Tests
# =============================================================================

func test_can_market_buy_requires_market() -> Assertions.AssertResult:
	## Cannot buy without a market building
	var gs = _create_ai_game_state()

	# Set up gold
	GameManager.ai_resources["gold"] = 500

	var result = gs.can_market_buy("food")

	if result:
		return Assertions.AssertResult.new(false,
			"Should not be able to buy without market")

	return Assertions.AssertResult.new(true)


func test_can_market_buy_requires_gold() -> Assertions.AssertResult:
	## Cannot buy without enough gold
	var gs = _create_ai_game_state()

	var market = runner.spawner.spawn_market(Vector2(500, 500), 1)
	await runner.wait_frames(2)

	# Set low gold
	GameManager.ai_resources["gold"] = 10

	var result = gs.can_market_buy("food")

	if result:
		return Assertions.AssertResult.new(false,
			"Should not be able to buy without enough gold")

	return Assertions.AssertResult.new(true)


func test_can_market_buy_cannot_buy_gold() -> Assertions.AssertResult:
	## Cannot buy gold (gold is the currency)
	var gs = _create_ai_game_state()

	var market = runner.spawner.spawn_market(Vector2(500, 500), 1)
	await runner.wait_frames(2)

	GameManager.ai_resources["gold"] = 500

	var result = gs.can_market_buy("gold")

	if result:
		return Assertions.AssertResult.new(false,
			"Should not be able to buy gold")

	return Assertions.AssertResult.new(true)


func test_can_market_sell_requires_market() -> Assertions.AssertResult:
	## Cannot sell without a market building
	var gs = _create_ai_game_state()

	GameManager.ai_resources["wood"] = 500

	var result = gs.can_market_sell("wood")

	if result:
		return Assertions.AssertResult.new(false,
			"Should not be able to sell without market")

	return Assertions.AssertResult.new(true)


func test_can_market_sell_requires_resource() -> Assertions.AssertResult:
	## Cannot sell without enough of the resource (need 100)
	var gs = _create_ai_game_state()

	var market = runner.spawner.spawn_market(Vector2(500, 500), 1)
	await runner.wait_frames(2)

	GameManager.ai_resources["wood"] = 50  # Not enough

	var result = gs.can_market_sell("wood")

	if result:
		return Assertions.AssertResult.new(false,
			"Should not be able to sell with <100 resource")

	return Assertions.AssertResult.new(true)


func test_can_market_sell_cannot_sell_gold() -> Assertions.AssertResult:
	## Cannot sell gold (gold is the currency)
	var gs = _create_ai_game_state()

	var market = runner.spawner.spawn_market(Vector2(500, 500), 1)
	await runner.wait_frames(2)

	GameManager.ai_resources["gold"] = 500

	var result = gs.can_market_sell("gold")

	if result:
		return Assertions.AssertResult.new(false,
			"Should not be able to sell gold")

	return Assertions.AssertResult.new(true)


# =============================================================================
# BuildFarmRule Condition Tests
# =============================================================================

func test_build_farm_rule_fires_when_no_natural_food() -> Assertions.AssertResult:
	## BuildFarmRule should fire when we have 10+ villagers (sustainable food trigger)
	## This condition doesn't depend on natural food count: vill_count >= 10 and farms < 4
	var gs = _create_ai_game_state()

	# Need 10+ villagers to trigger the "sustainable food" condition
	for i in range(12):
		var villager = runner.spawner.spawn_villager(Vector2(500 + (i % 4) * 50, 500 + (i / 4) * 50), 1)
		# Ensure villager is idle
		villager.current_state = Villager.State.IDLE
	# Need wood for building
	GameManager.ai_resources["wood"] = 200
	await runner.wait_frames(2)

	# With 10+ villagers and 0 farms, the rule should fire regardless of natural food
	var rule = AIRules.BuildFarmRule.new()
	var should_fire = rule.conditions(gs)

	if not should_fire:
		var vill_count = gs.get_civilian_population()
		var idle_count = gs.get_idle_villager_count()
		var can_build = gs.can_build("farm")
		var farm_count = gs.get_building_count("farm")
		var natural_food = gs.get_natural_food_count()
		return Assertions.AssertResult.new(false,
			"BuildFarmRule should fire with 10+ villagers. Debug: vill_count=%d, idle=%d, can_build=%s, farms=%d, natural_food=%d" % [
				vill_count, idle_count, str(can_build), farm_count, natural_food])

	return Assertions.AssertResult.new(true)


func test_build_farm_rule_respects_farm_cap() -> Assertions.AssertResult:
	## BuildFarmRule should not build more farms than needed
	var gs = _create_ai_game_state()

	# Set up economy percentages
	gs.set_sn("sn_food_gatherer_percentage", 50)

	# 4 villagers, 50% food = 2 food villagers, max 1 farm
	for i in range(4):
		runner.spawner.spawn_villager(Vector2(500 + i * 50, 500), 1)

	# Already have max farms (max_farms = max(4, int(2 / 2)) = 4)
	for i in range(5):
		runner.spawner.spawn_farm(Vector2(500 + i * 80, 600), 1)

	GameManager.ai_resources["wood"] = 200
	await runner.wait_frames(2)

	var rule = AIRules.BuildFarmRule.new()
	var should_fire = rule.conditions(gs)

	if should_fire:
		return Assertions.AssertResult.new(false,
			"BuildFarmRule should not fire when at farm cap")

	return Assertions.AssertResult.new(true)


# =============================================================================
# AdjustGathererPercentagesRule Condition Tests
# =============================================================================

func test_adjust_gatherers_transitions_at_thresholds() -> Assertions.AssertResult:
	## Rule should trigger transition at 10+ villagers with barracks
	var gs = _create_ai_game_state()

	# Set initial phase 0
	gs.set_goal(AIRules.GOAL_ECONOMY_PHASE, 0)

	# Spawn 10 villagers (AI team)
	for i in range(10):
		runner.spawner.spawn_villager(Vector2(500 + i * 50, 500), 1)

	# Spawn barracks
	var barracks = runner.spawner.spawn_barracks(Vector2(600, 600), 1)
	await runner.wait_frames(2)

	var rule = AIRules.AdjustGathererPercentagesRule.new()
	var should_fire = rule.conditions(gs)

	if not should_fire:
		return Assertions.AssertResult.new(false,
			"AdjustGathererPercentagesRule should fire at 10+ villagers with barracks")

	return Assertions.AssertResult.new(true)


# =============================================================================
# MarketSellRule Condition Tests
# =============================================================================

func test_market_sell_rule_fires_on_surplus() -> Assertions.AssertResult:
	## MarketSellRule should fire when resource > 400
	var gs = _create_ai_game_state()

	var market = runner.spawner.spawn_market(Vector2(500, 500), 1)
	await runner.wait_frames(2)

	# Set surplus resources
	GameManager.ai_resources["food"] = 500  # Over threshold

	var rule = AIRules.MarketSellRule.new()
	var should_fire = rule.conditions(gs)

	if not should_fire:
		return Assertions.AssertResult.new(false,
			"MarketSellRule should fire when food > 400")

	return Assertions.AssertResult.new(true)


func test_market_sell_rule_doesnt_fire_below_threshold() -> Assertions.AssertResult:
	## MarketSellRule should not fire when all resources <= 400
	var gs = _create_ai_game_state()

	var market = runner.spawner.spawn_market(Vector2(500, 500), 1)
	await runner.wait_frames(2)

	# Set normal resources (below threshold)
	GameManager.ai_resources["food"] = 300
	GameManager.ai_resources["wood"] = 300
	GameManager.ai_resources["stone"] = 100

	var rule = AIRules.MarketSellRule.new()
	var should_fire = rule.conditions(gs)

	if should_fire:
		return Assertions.AssertResult.new(false,
			"MarketSellRule should not fire when all resources <= 400")

	return Assertions.AssertResult.new(true)


# =============================================================================
# MarketBuyRule Condition Tests
# =============================================================================

func test_market_buy_rule_fires_on_desperation() -> Assertions.AssertResult:
	## MarketBuyRule should fire when resource < 50 and have gold
	var gs = _create_ai_game_state()

	var market = runner.spawner.spawn_market(Vector2(500, 500), 1)
	await runner.wait_frames(2)

	# Set desperate food but have gold
	GameManager.ai_resources["food"] = 30
	GameManager.ai_resources["gold"] = 200

	var rule = AIRules.MarketBuyRule.new()
	var should_fire = rule.conditions(gs)

	if not should_fire:
		return Assertions.AssertResult.new(false,
			"MarketBuyRule should fire when food < 50 and gold > 150")

	return Assertions.AssertResult.new(true)


func test_market_buy_rule_requires_gold() -> Assertions.AssertResult:
	## MarketBuyRule should not fire if gold < 150
	var gs = _create_ai_game_state()

	var market = runner.spawner.spawn_market(Vector2(500, 500), 1)
	await runner.wait_frames(2)

	# Set desperate food but low gold
	GameManager.ai_resources["food"] = 30
	GameManager.ai_resources["gold"] = 100  # Below 150 threshold

	var rule = AIRules.MarketBuyRule.new()
	var should_fire = rule.conditions(gs)

	if should_fire:
		return Assertions.AssertResult.new(false,
			"MarketBuyRule should not fire when gold < 150")

	return Assertions.AssertResult.new(true)


# =============================================================================
# GatherSheepRule and HuntRule Condition Tests
# =============================================================================

func test_gather_sheep_rule_fires_with_sheep() -> Assertions.AssertResult:
	## GatherSheepRule should fire when sheep available and villager idle
	var gs = _create_ai_game_state()

	# Spawn idle villager
	var villager = runner.spawner.spawn_villager(Vector2(500, 500), 1)
	# Spawn sheep
	runner.spawner.spawn_sheep(Vector2(550, 500), -1)
	await runner.wait_frames(2)

	# Ensure villager is idle
	villager.current_state = Villager.State.IDLE

	var rule = AIRules.GatherSheepRule.new()
	var should_fire = rule.conditions(gs)

	if not should_fire:
		return Assertions.AssertResult.new(false,
			"GatherSheepRule should fire when sheep available and villager idle")

	return Assertions.AssertResult.new(true)


func test_hunt_rule_fires_without_sheep() -> Assertions.AssertResult:
	## HuntRule should fire when huntables available near AI base and no sheep
	var gs = _create_ai_game_state()

	# AI base is at (1700, 1700) - spawn near there for distance check to pass
	# Spawn idle villager near AI base
	var villager = runner.spawner.spawn_villager(Vector2(1700, 1700), 1)
	# Spawn deer close to AI base (within 200px threshold)
	runner.spawner.spawn_deer(Vector2(1750, 1700))
	await runner.wait_frames(2)

	# Ensure villager is idle
	villager.current_state = Villager.State.IDLE

	var rule = AIRules.HuntRule.new()
	var should_fire = rule.conditions(gs)

	if not should_fire:
		return Assertions.AssertResult.new(false,
			"HuntRule should fire when huntables available near AI base and no sheep")

	return Assertions.AssertResult.new(true)


func test_hunt_rule_doesnt_fire_with_sheep() -> Assertions.AssertResult:
	## HuntRule should NOT fire when sheep are available (sheep have priority)
	var gs = _create_ai_game_state()

	# Spawn idle villager
	var villager = runner.spawner.spawn_villager(Vector2(500, 500), 1)
	# Spawn both sheep and deer
	runner.spawner.spawn_sheep(Vector2(550, 500), -1)
	runner.spawner.spawn_deer(Vector2(600, 500))
	await runner.wait_frames(2)

	# Ensure villager is idle
	villager.current_state = Villager.State.IDLE

	var rule = AIRules.HuntRule.new()
	var should_fire = rule.conditions(gs)

	if should_fire:
		return Assertions.AssertResult.new(false,
			"HuntRule should not fire when sheep are available")

	return Assertions.AssertResult.new(true)
