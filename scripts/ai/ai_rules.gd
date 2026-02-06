extends RefCounted
class_name AIRules

# =============================================================================
# AIRules - Rule definitions for the AI system
# =============================================================================
#
# Each rule has:
# - conditions(gs: AIGameState) -> bool: Return true if rule should fire
# - actions(gs: AIGameState) -> void: Execute the rule's behavior
#
# Rules are independent - they don't call each other.
# All matching rules fire each tick.
#
# =============================================================================

# Timer IDs
const TIMER_ATTACK = 1

# Goal IDs
const GOAL_INITIALIZED = 1


# =============================================================================
# BASE CLASS
# =============================================================================

class AIRule:
	var enabled: bool = true
	var rule_name: String = ""

	func conditions(_gs: AIGameState) -> bool:
		return false

	func actions(_gs: AIGameState) -> void:
		pass

	func disable_self() -> void:
		enabled = false


# =============================================================================
# INITIALIZATION (runs once)
# =============================================================================

class InitializationRule extends AIRule:
	func _init():
		rule_name = "initialization"

	func conditions(gs: AIGameState) -> bool:
		# Only run once
		return gs.get_goal(GOAL_INITIALIZED) == 0

	func actions(gs: AIGameState) -> void:
		# Resource allocation (must sum to 100)
		# Start with heavy food/wood focus for early economy
		gs.set_sn("sn_food_gatherer_percentage", 60)
		gs.set_sn("sn_wood_gatherer_percentage", 40)
		gs.set_sn("sn_gold_gatherer_percentage", 0)
		gs.set_sn("sn_stone_gatherer_percentage", 0)

		# Villager targets
		gs.set_sn("sn_target_villagers", 20)

		# Building placement
		gs.set_sn("sn_maximum_town_size", 24)

		# Attack settings
		gs.set_sn("sn_minimum_attack_group_size", 5)

		# Start attack timer (first attack after 120 seconds)
		gs.enable_timer(TIMER_ATTACK, 120)

		# Mark as initialized
		gs.set_goal(GOAL_INITIALIZED, 1)


# Goal for tracking economy phases
const GOAL_ECONOMY_PHASE = 2


class AdjustGathererPercentagesRule extends AIRule:
	## Dynamically adjust gatherer percentages based on game state
	## Phase 0: Early game - heavy food/wood for economy
	## Phase 1: Mid game - add gold for market/upgrades
	## Phase 2: Late game - add stone for walls/castles (future phases)

	func _init():
		rule_name = "adjust_gatherer_percentages"

	func conditions(gs: AIGameState) -> bool:
		# Check every tick but only change when thresholds crossed
		var current_phase = gs.get_goal(GOAL_ECONOMY_PHASE)
		var vill_count = gs.get_civilian_population()
		var has_barracks = gs.get_building_count("barracks") >= 1

		# Transition to Phase 1 when economy is established AND we have a
		# gold-spending building. Without this gate, 15% of villagers mine
		# gold that sits idle (militia only costs food/wood).
		var has_archery_range = gs.get_building_count("archery_range") >= 1
		if current_phase == 0 and vill_count >= 10 and has_barracks and has_archery_range:
			return true

		# Future: Phase 2 transitions can be added here

		return false

	func actions(gs: AIGameState) -> void:
		var current_phase = gs.get_goal(GOAL_ECONOMY_PHASE)

		if current_phase == 0:
			# Transition to mid-game economy
			# Add gold gathering, reduce food slightly
			gs.set_sn("sn_food_gatherer_percentage", 50)
			gs.set_sn("sn_wood_gatherer_percentage", 35)
			gs.set_sn("sn_gold_gatherer_percentage", 15)
			gs.set_sn("sn_stone_gatherer_percentage", 0)
			gs.set_goal(GOAL_ECONOMY_PHASE, 1)


# =============================================================================
# HOUSING
# =============================================================================

class BuildHouseRule extends AIRule:
	func _init():
		rule_name = "build_house"

	func conditions(gs: AIGameState) -> bool:
		# Build house when housing headroom < 5 and we have room to grow
		return gs.get_housing_headroom() < 5 \
			and gs.get_population_headroom() > 0 \
			and gs.can_build("house")

	func actions(gs: AIGameState) -> void:
		gs.build("house")


# =============================================================================
# VILLAGER PRODUCTION
# =============================================================================

class TrainVillagerRule extends AIRule:
	func _init():
		rule_name = "train_villager"

	func conditions(gs: AIGameState) -> bool:
		var target = gs.get_sn("sn_target_villagers")
		if target <= 0:
			target = 20  # Default
		# Pause villager production until we have a small military force.
		# Militia costs 60 food; villagers cost 50 — without this pause,
		# villager training consumes all food before it reaches 60.
		# Threshold of 3 builds a small defensive force before resuming
		# villager production (~180s pause at typical food income).
		if gs.get_building_count("barracks") >= 1 \
			and gs.get_military_population() < 3 \
			and gs.get_civilian_population() >= 10:
			return false
		# Don't pause villagers for age saving — more villagers = more food income = faster saving
		return gs.get_civilian_population() < target \
			and gs.can_train("villager")

	func actions(gs: AIGameState) -> void:
		gs.train("villager")


# =============================================================================
# ECONOMY BUILDINGS (Phase 3.1B)
# =============================================================================

class BuildLumberCampRule extends AIRule:
	var _lumber_camp_queued: bool = false

	func _init():
		rule_name = "build_lumber_camp"

	func conditions(gs: AIGameState) -> bool:
		# Reset flag if building now exists (construction succeeded)
		if gs.get_building_count("lumber_camp") > 0:
			_lumber_camp_queued = false
			return false

		# Build lumber camp when wood is too far from drop-offs
		return not _lumber_camp_queued \
			and gs.needs_lumber_camp() \
			and gs.can_build("lumber_camp")

	func actions(gs: AIGameState) -> void:
		gs.build_near_resource("lumber_camp", "wood")
		_lumber_camp_queued = true


class BuildMiningCampRule extends AIRule:
	var _mining_camp_queued: bool = false

	func _init():
		rule_name = "build_mining_camp"

	func conditions(gs: AIGameState) -> bool:
		# Reset flag if building now exists (construction succeeded)
		if gs.get_building_count("mining_camp") > 0:
			_mining_camp_queued = false
			return false

		# Build mining camp when gold or stone is too far
		return not _mining_camp_queued \
			and (gs.needs_mining_camp_for_gold() or gs.needs_mining_camp_for_stone()) \
			and gs.can_build("mining_camp")

	func actions(gs: AIGameState) -> void:
		# Prefer gold (more useful generally)
		if gs.needs_mining_camp_for_gold():
			gs.build_near_resource("mining_camp", "gold")
		else:
			gs.build_near_resource("mining_camp", "stone")
		_mining_camp_queued = true


class BuildMillRule extends AIRule:
	var _mill_queued: bool = false

	func _init():
		rule_name = "build_mill"

	func conditions(gs: AIGameState) -> bool:
		# Reset flag if building now exists (construction succeeded)
		if gs.get_building_count("mill") > 0:
			_mill_queued = false
			return false

		# Build mill when natural food is far from drop-offs
		return not _mill_queued \
			and gs.needs_mill() \
			and gs.can_build("mill")

	func actions(gs: AIGameState) -> void:
		gs.build_near_resource("mill", "food")
		_mill_queued = true


class BuildFarmRule extends AIRule:
	func _init():
		rule_name = "build_farm"

	func conditions(gs: AIGameState) -> bool:
		# Build farms when natural food is low/depleted
		# Natural food includes: berries, sheep, deer, boar
		var natural_food = gs.get_natural_food_count()

		# Start building farms when natural food is getting low
		# or when we have enough villagers to need sustainable food
		var vill_count = gs.get_civilian_population()

		# Build farms if:
		# 1. Natural food is depleted and we have some villagers
		# 2. Natural food is low (< 3) and we have a decent economy
		# 3. We have many villagers (10+) and want sustainable food
		var should_build = (natural_food == 0 and vill_count >= 3) \
			or (natural_food < 3 and vill_count >= 6) \
			or (vill_count >= 10 and gs.get_building_count("farm") < 4)

		# Cap farms at a reasonable number based on villager count
		# Roughly 1 farm per 2-3 food gatherers
		var food_pct = gs.get_sn("sn_food_gatherer_percentage")
		var target_food_villagers = int(vill_count * food_pct / 100.0)
		var max_farms = max(4, target_food_villagers)
		var current_farms = gs.get_building_count("farm")

		return should_build \
			and current_farms < max_farms \
			and gs.can_build("farm")

	func actions(gs: AIGameState) -> void:
		# Build farm near TC or mill
		gs.build("farm")


# =============================================================================
# FOOD GATHERING PRIORITIES (Phase 3.1B)
# =============================================================================

class GatherSheepRule extends AIRule:
	func _init():
		rule_name = "gather_sheep"

	func conditions(gs: AIGameState) -> bool:
		# Assign villager to gather sheep if available
		# Sheep are high priority - they can be stolen by enemies
		return gs.get_sheep_count() > 0 \
			and gs.get_idle_villager_count() > 0

	func actions(gs: AIGameState) -> void:
		var sheep = gs.get_nearest_sheep()
		if not sheep:
			return

		# Find an idle villager
		var villagers = gs.get_villagers_by_task()
		if villagers["idle"].is_empty():
			return

		var villager = villagers["idle"][0]
		gs.assign_villager_to_sheep(villager, sheep)


class HuntRule extends AIRule:
	const MAX_HUNT_DISTANCE = 200.0  # Don't hunt animals further than this - prefer other food sources

	func _init():
		rule_name = "hunt"

	func conditions(gs: AIGameState) -> bool:
		# Assign villager to hunt if animals available and sheep are being handled
		# Hunting is efficient food but deer run away and boar fight back
		if gs.get_huntable_count() == 0:
			return false
		if gs.get_idle_villager_count() == 0:
			return false
		if gs.get_sheep_count() > 0:
			return false  # Prioritize sheep first

		# Don't hunt if animals are too far - let general assignment find better food
		# (berries, farms, or closer natural food)
		var hunt_dist = gs.get_nearest_huntable_distance()
		if hunt_dist > MAX_HUNT_DISTANCE:
			return false

		return true

	func actions(gs: AIGameState) -> void:
		var animal = gs.get_nearest_huntable()
		if not animal:
			return

		# Find an idle villager
		var villagers = gs.get_villagers_by_task()
		if villagers["idle"].is_empty():
			return

		var villager = villagers["idle"][0]
		gs.assign_villager_to_hunt(villager, animal)


# =============================================================================
# MARKET TRADING (Phase 3.1B)
# =============================================================================

class MarketSellRule extends AIRule:
	## Conservative selling: only sell when we have a large surplus
	const SURPLUS_THRESHOLD: int = 400

	func _init():
		rule_name = "market_sell"

	func conditions(gs: AIGameState) -> bool:
		# Need a market
		if gs.get_building_count("market") == 0:
			return false

		# Check for surplus in any sellable resource
		var food = gs.get_resource("food")
		var wood = gs.get_resource("wood")
		var stone = gs.get_resource("stone")

		return food > SURPLUS_THRESHOLD \
			or wood > SURPLUS_THRESHOLD \
			or stone > SURPLUS_THRESHOLD

	func actions(gs: AIGameState) -> void:
		# Sell the most surplus resource
		var food = gs.get_resource("food")
		var wood = gs.get_resource("wood")
		var stone = gs.get_resource("stone")

		# Find resource with most surplus
		var best_resource = ""
		var best_surplus = 0

		if food > SURPLUS_THRESHOLD and food > best_surplus:
			best_surplus = food
			best_resource = "food"
		if wood > SURPLUS_THRESHOLD and wood > best_surplus:
			best_surplus = wood
			best_resource = "wood"
		if stone > SURPLUS_THRESHOLD and stone > best_surplus:
			best_surplus = stone
			best_resource = "stone"

		if best_resource != "" and gs.can_market_sell(best_resource):
			gs.market_sell(best_resource)


class MarketBuyRule extends AIRule:
	## Emergency buying: only buy when desperate for a resource
	const DESPERATION_THRESHOLD: int = 50
	const MIN_GOLD_FOR_BUYING: int = 150

	func _init():
		rule_name = "market_buy"

	func conditions(gs: AIGameState) -> bool:
		# Need a market
		if gs.get_building_count("market") == 0:
			return false

		# Need enough gold to buy without going broke
		if gs.get_resource("gold") < MIN_GOLD_FOR_BUYING:
			return false

		# Check if any resource is critically low
		var food = gs.get_resource("food")
		var wood = gs.get_resource("wood")

		# Only buy food or wood in emergencies (stone rarely urgent)
		return food < DESPERATION_THRESHOLD or wood < DESPERATION_THRESHOLD

	func actions(gs: AIGameState) -> void:
		var food = gs.get_resource("food")
		var wood = gs.get_resource("wood")

		# Buy the most desperately needed resource
		if food < wood and food < DESPERATION_THRESHOLD:
			if gs.can_market_buy("food"):
				gs.market_buy("food")
		elif wood < DESPERATION_THRESHOLD:
			if gs.can_market_buy("wood"):
				gs.market_buy("wood")


# =============================================================================
# MILITARY BUILDINGS
# =============================================================================

class BuildBarracksRule extends AIRule:
	var _barracks_queued: bool = false

	func _init():
		rule_name = "build_barracks"

	func conditions(gs: AIGameState) -> bool:
		# Reset flag if building now exists (construction succeeded)
		if gs.get_building_count("barracks") > 0:
			_barracks_queued = false
			return false

		# Build barracks when we have none and have some economy going
		# Only queue once (avoid building multiple while first is under construction)
		return not _barracks_queued \
			and gs.get_civilian_population() >= 5 \
			and gs.can_build("barracks")

	func actions(gs: AIGameState) -> void:
		gs.build("barracks")
		_barracks_queued = true


class BuildArcheryRangeRule extends AIRule:
	var _archery_range_queued: bool = false

	func _init():
		rule_name = "build_archery_range"

	func conditions(gs: AIGameState) -> bool:
		# Reset flag if building now exists
		if gs.get_building_count("archery_range") > 0:
			_archery_range_queued = false
			return false

		# Build archery range when we have barracks and 8+ villagers
		# This gives us ranged options in addition to infantry
		return not _archery_range_queued \
			and gs.get_building_count("barracks") >= 1 \
			and gs.get_civilian_population() >= 8 \
			and gs.can_build("archery_range")

	func actions(gs: AIGameState) -> void:
		gs.build("archery_range")
		_archery_range_queued = true


class BuildStableRule extends AIRule:
	var _stable_queued: bool = false

	func _init():
		rule_name = "build_stable"

	func conditions(gs: AIGameState) -> bool:
		# Reset flag if building now exists
		if gs.get_building_count("stable") > 0:
			_stable_queued = false
			return false

		# Build stable when we have barracks and 10+ villagers
		# Cavalry is more expensive, so wait for stronger economy
		return not _stable_queued \
			and gs.get_building_count("barracks") >= 1 \
			and gs.get_civilian_population() >= 10 \
			and gs.can_build("stable")

	func actions(gs: AIGameState) -> void:
		gs.build("stable")
		_stable_queued = true


# =============================================================================
# MILITARY TRAINING
# =============================================================================

class TrainMilitiaRule extends AIRule:
	func _init():
		rule_name = "train_militia"

	func conditions(gs: AIGameState) -> bool:
		if gs.should_save_for_age():
			return false
		return gs.get_building_count("barracks") >= 1 \
			and gs.can_train("militia")

	func actions(gs: AIGameState) -> void:
		gs.train("militia")


class TrainSpearmanRule extends AIRule:
	func _init():
		rule_name = "train_spearman"

	func conditions(gs: AIGameState) -> bool:
		if gs.should_save_for_age():
			return false
		if gs.get_building_count("barracks") < 1:
			return false
		if not gs.can_train("spearman"):
			return false
		return gs.get_enemy_cavalry_count() > 0

	func actions(gs: AIGameState) -> void:
		gs.train("spearman")


class TrainArcherRule extends AIRule:
	func _init():
		rule_name = "train_archer"

	func conditions(gs: AIGameState) -> bool:
		if gs.should_save_for_age():
			return false
		# Train archers - good general ranged unit
		if gs.get_building_count("archery_range") < 1:
			return false
		if not gs.can_train("archer"):
			return false
		# Train archers if we don't have many ranged units
		# Ensure at least 3 archers can be trained, or up to infantry+2 for balanced army
		var ranged_count = gs.get_unit_count("ranged")
		var infantry_count = gs.get_unit_count("infantry")
		return ranged_count < max(3, infantry_count + 2)

	func actions(gs: AIGameState) -> void:
		gs.train("archer")


class TrainSkirmisherRule extends AIRule:
	func _init():
		rule_name = "train_skirmisher"

	func conditions(gs: AIGameState) -> bool:
		if gs.should_save_for_age():
			return false
		if gs.get_building_count("archery_range") < 1:
			return false
		if not gs.can_train("skirmisher"):
			return false
		return gs.get_enemy_archer_count() > 0

	func actions(gs: AIGameState) -> void:
		gs.train("skirmisher")


class TrainScoutCavalryRule extends AIRule:
	func _init():
		rule_name = "train_scout_cavalry"

	func conditions(gs: AIGameState) -> bool:
		if gs.should_save_for_age():
			return false
		if gs.get_building_count("stable") < 1:
			return false
		if not gs.can_train("scout_cavalry"):
			return false
		var scout_count = gs.get_unit_count("scout_cavalry")
		if scout_count < 1:
			return true
		return scout_count < 3 and gs.get_resource("food") > 150

	func actions(gs: AIGameState) -> void:
		gs.train("scout_cavalry")


class TrainCavalryArcherRule extends AIRule:
	func _init():
		rule_name = "train_cavalry_archer"

	func conditions(gs: AIGameState) -> bool:
		if gs.should_save_for_age():
			return false
		if gs.get_building_count("stable") < 1:
			return false
		if not gs.can_train("cavalry_archer"):
			return false
		return gs.get_resource("gold") > 150 \
			and gs.get_military_population() >= 3

	func actions(gs: AIGameState) -> void:
		gs.train("cavalry_archer")


# =============================================================================
# AGE ADVANCEMENT (Phase 4A)
# =============================================================================

class AdvanceToFeudalAgeRule extends AIRule:
	## Advance to Feudal Age when economy is established
	## Requirements: Dark Age, 10+ villagers, 2 qualifying buildings, 500 food

	func _init():
		rule_name = "advance_to_feudal"

	func conditions(gs: AIGameState) -> bool:
		if gs.get_age() != GameManager.AGE_DARK:
			return false
		if gs.get_civilian_population() < 10:
			return false
		var target_age = GameManager.AGE_FEUDAL
		if gs.get_qualifying_building_count(target_age) < GameManager.AGE_REQUIRED_QUALIFYING_COUNT:
			return false
		if not gs.can_advance_age():
			return false
		return true

	func actions(gs: AIGameState) -> void:
		gs.research_age(GameManager.AGE_FEUDAL)


class AdvanceToCastleAgeRule extends AIRule:
	## Advance to Castle Age when Feudal economy is running
	## Requirements: Feudal Age, 15+ villagers, 2 qualifying Feudal buildings, 800 food + 200 gold

	func _init():
		rule_name = "advance_to_castle"

	func conditions(gs: AIGameState) -> bool:
		if gs.get_age() != GameManager.AGE_FEUDAL:
			return false
		if gs.get_civilian_population() < 15:
			return false
		var target_age = GameManager.AGE_CASTLE
		if gs.get_qualifying_building_count(target_age) < GameManager.AGE_REQUIRED_QUALIFYING_COUNT:
			return false
		if not gs.can_advance_age():
			return false
		return true

	func actions(gs: AIGameState) -> void:
		gs.research_age(GameManager.AGE_CASTLE)


# =============================================================================
# DEFENSE (Phase 3.1C)
# =============================================================================

class DefendBaseRule extends AIRule:
	## When under attack, pull military back to defend the base
	## This takes priority over attacking

	func _init():
		rule_name = "defend_base"

	func conditions(gs: AIGameState) -> bool:
		# Defend if under attack and we have military
		return gs.is_under_attack() \
			and gs.get_military_population() > 0

	func actions(gs: AIGameState) -> void:
		# Find the nearest threat and attack it
		var threat = gs.get_nearest_threat()
		if threat:
			gs.defend_against(threat)


# =============================================================================
# SCOUTING (Phase 3.1C)
# =============================================================================

class ScoutingRule extends AIRule:
	## Sends idle scouts to explore the map
	## Priority: 1) Player base area, 2) Map corners/edges
	var _scout_targets: Array[Vector2] = []
	var _current_target_index: int = 0

	func _init():
		rule_name = "scouting"
		# Define scout targets - player base is first priority
		# Map is 1920x1920, AI base is at (1700, 1700), Player base is near (480, 480)
		_scout_targets = [
			Vector2(500, 500),    # Player base area
			Vector2(200, 200),    # Top-left corner
			Vector2(1700, 200),   # Top-right corner
			Vector2(200, 1700),   # Bottom-left corner
			Vector2(960, 960),    # Center of map
			Vector2(960, 200),    # Top center
			Vector2(200, 960),    # Left center
		]

	func conditions(gs: AIGameState) -> bool:
		# Scout if we have an idle scout
		return gs.get_idle_scout() != null

	func actions(gs: AIGameState) -> void:
		# Get next target and cycle through
		var target = _scout_targets[_current_target_index]
		gs.scout_to(target)
		_current_target_index = (_current_target_index + 1) % _scout_targets.size()


# =============================================================================
# ATTACK
# =============================================================================

class AttackRule extends AIRule:
	func _init():
		rule_name = "attack"

	func conditions(gs: AIGameState) -> bool:
		var min_military = gs.get_sn("sn_minimum_attack_group_size")
		if min_military <= 0:
			min_military = 5  # Default

		# Attack when we have enough military and timer triggered
		return gs.get_military_population() >= min_military \
			and gs.is_timer_triggered(TIMER_ATTACK) \
			and not gs.is_under_attack()

	func actions(gs: AIGameState) -> void:
		gs.attack_now()
		# Reset attack timer for next attack
		gs.disable_timer(TIMER_ATTACK)
		gs.enable_timer(TIMER_ATTACK, 90)  # Attack again in 90 seconds


# =============================================================================
# FACTORY METHOD
# =============================================================================

static func create_all_rules() -> Array:
	return [
		InitializationRule.new(),
		AdjustGathererPercentagesRule.new(),  # Dynamic economy adjustment
		BuildHouseRule.new(),
		TrainVillagerRule.new(),
		# Economy buildings (Phase 3.1B)
		BuildLumberCampRule.new(),
		BuildMiningCampRule.new(),
		BuildMillRule.new(),
		BuildFarmRule.new(),
		# Food gathering priorities (Phase 3.1B)
		GatherSheepRule.new(),
		HuntRule.new(),
		# Market trading (Phase 3.1B)
		MarketSellRule.new(),
		MarketBuyRule.new(),
		# Military buildings (Phase 3.1C)
		BuildBarracksRule.new(),
		BuildArcheryRangeRule.new(),
		BuildStableRule.new(),
		# Military training (Phase 3.1C)
		TrainMilitiaRule.new(),
		TrainSpearmanRule.new(),
		TrainArcherRule.new(),
		TrainSkirmisherRule.new(),
		TrainScoutCavalryRule.new(),
		TrainCavalryArcherRule.new(),
		# Age advancement (Phase 4A)
		AdvanceToFeudalAgeRule.new(),
		AdvanceToCastleAgeRule.new(),
		# Defense (Phase 3.1C)
		DefendBaseRule.new(),
		# Scouting (Phase 3.1C)
		ScoutingRule.new(),
		# Attack
		AttackRule.new(),
	]
