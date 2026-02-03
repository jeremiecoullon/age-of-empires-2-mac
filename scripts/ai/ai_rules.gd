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
		return gs.get_civilian_population() < target \
			and gs.can_train("villager")

	func actions(gs: AIGameState) -> void:
		gs.train("villager")


# =============================================================================
# MILITARY BUILDINGS
# =============================================================================

class BuildBarracksRule extends AIRule:
	var _barracks_queued: bool = false

	func _init():
		rule_name = "build_barracks"

	func conditions(gs: AIGameState) -> bool:
		# Build barracks when we have none and have some economy going
		# Only queue once (avoid building multiple while first is under construction)
		return not _barracks_queued \
			and gs.get_building_count("barracks") == 0 \
			and gs.get_civilian_population() >= 5 \
			and gs.can_build("barracks")

	func actions(gs: AIGameState) -> void:
		gs.build("barracks")
		_barracks_queued = true


# =============================================================================
# MILITARY TRAINING
# =============================================================================

class TrainMilitiaRule extends AIRule:
	func _init():
		rule_name = "train_militia"

	func conditions(gs: AIGameState) -> bool:
		# Train militia when we have a barracks
		return gs.get_building_count("barracks") >= 1 \
			and gs.can_train("militia")

	func actions(gs: AIGameState) -> void:
		gs.train("militia")


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
		BuildHouseRule.new(),
		TrainVillagerRule.new(),
		BuildBarracksRule.new(),
		TrainMilitiaRule.new(),
		AttackRule.new(),
	]
