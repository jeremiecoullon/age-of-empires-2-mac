# Godot rule-based AI implementation

**Status:** Design complete, ready for implementation
**Date:** 2026-02-03

---

## Overview

We're implementing an AoE2-style rule-based AI system in GDScript. Rules are independent, all matching rules fire each tick, and strategic numbers control behavior thresholds.

**Key decisions:**
- Rules as GDScript code (not a data interpreter)
- Direct class/method calls (no LISP parsing)
- Start with AoE2 defaults for strategic numbers, adjust as needed
- Test by playing, add debug tooling only if needed

---

## Architecture

```
ai_controller.gd          # Entry point, owns rule engine
├── ai_game_state.gd      # Wrapper exposing game state to rules
├── ai_rules.gd           # All rules in one file (refactor later if needed)
└── strategic_numbers     # Dictionary in ai_controller.gd
```

### Update loop

```gdscript
# ai_controller.gd
func _process(delta: float) -> void:
    decision_timer += delta
    if decision_timer < DECISION_INTERVAL:
        return
    decision_timer = 0.0

    game_state.refresh()  # Update cached game state
    _evaluate_rules()
    game_state.execute_actions()  # Execute queued actions
```

**DECISION_INTERVAL**: ~0.5 seconds (AoE2 runs "several times per second")

---

## AIGameState

The `AIGameState` class wraps game state and provides a clean interface for rules. Rules don't access game objects directly - they go through this layer.

### Condition helpers (read-only queries)

```gdscript
class_name AIGameState

# Resources
func get_resource(type: String) -> int
func can_afford(costs: Dictionary) -> bool

# Population
func get_civilian_population() -> int
func get_military_population() -> int
func get_population() -> int
func get_population_cap() -> int
func get_housing_headroom() -> int  # cap - current (room before hitting current cap)
func get_population_headroom() -> int  # max_possible - current (room before game limit, e.g. 200)

# Unit/building counts
func get_unit_count(unit_type: String) -> int
func get_building_count(building_type: String) -> int
func get_idle_villager_count() -> int

# Training/building checks
func can_train(unit_type: String) -> bool  # resources + pop space + building exists
func can_build(building_type: String) -> bool  # resources + prerequisites

# Game state
func is_under_attack() -> bool
func get_game_time() -> float

# Strategic numbers
func get_sn(sn_name: String) -> int
func set_sn(sn_name: String, value: int) -> void

# Goals (state variables)
func get_goal(goal_id: int) -> int
func set_goal(goal_id: int, value: int) -> void

# Timers
func is_timer_triggered(timer_id: int) -> bool
func enable_timer(timer_id: int, seconds: float) -> void
func disable_timer(timer_id: int) -> void
```

### Action methods (queue intentions)

Actions don't execute immediately - they're queued and de-duplicated at end of tick.

```gdscript
# Training
func train(unit_type: String) -> void

# Building
func build(building_type: String) -> void
func build_near_resource(building_type: String, resource_type: String) -> void

# Military
func attack_now() -> void

# Villager assignment (handled by strategic number percentages)
# The engine auto-assigns based on sn-food-gatherer-percentage, etc.
```

### Action de-duplication

```gdscript
var _pending_trains: Dictionary = {}  # unit_type -> count (max 1 per tick)
var _pending_builds: Dictionary = {}  # building_type -> count (max 1 per tick)
var _attack_requested: bool = false

func execute_actions() -> void:
    for unit_type in _pending_trains:
        _do_train(unit_type)
    for building_type in _pending_builds:
        _do_build(building_type)
    if _attack_requested:
        _do_attack()
    _clear_pending()
```

---

## Rule structure

All rules live in `ai_rules.gd`. Each rule is a class with `conditions()` and `actions()` methods.

```gdscript
# ai_rules.gd
class_name AIRules

# Base class for rules
class AIRule:
    var enabled: bool = true
    var rule_name: String = ""

    func conditions(_gs: AIGameState) -> bool:
        return false

    func actions(_gs: AIGameState) -> void:
        pass

    func disable_self() -> void:
        enabled = false


# ============================================
# HOUSING
# ============================================

class BuildHouseRule extends AIRule:
    func _init():
        rule_name = "build_house"

    func conditions(gs: AIGameState) -> bool:
        # housing_headroom = cap - current (room before hitting cap)
        # population_headroom = max_possible - current (room before game limit)
        return gs.get_housing_headroom() < 5 \
            and gs.get_population_headroom() > 0 \
            and gs.can_build("house")

    func actions(gs: AIGameState) -> void:
        gs.build("house")


# ============================================
# VILLAGER PRODUCTION
# ============================================

class TrainVillagerRule extends AIRule:
    func _init():
        rule_name = "train_villager"

    func conditions(gs: AIGameState) -> bool:
        var target = gs.get_sn("sn_target_villagers")
        return gs.get_civilian_population() < target \
            and gs.can_train("villager")

    func actions(gs: AIGameState) -> void:
        gs.train("villager")


# ============================================
# MILITARY BUILDINGS
# ============================================

class BuildBarracksRule extends AIRule:
    func _init():
        rule_name = "build_barracks"

    func conditions(gs: AIGameState) -> bool:
        return gs.get_building_count("barracks") == 0 \
            and gs.can_build("barracks")

    func actions(gs: AIGameState) -> void:
        gs.build("barracks")


# ============================================
# MILITARY TRAINING
# ============================================

class TrainMilitiaRule extends AIRule:
    func _init():
        rule_name = "train_militia"

    func conditions(gs: AIGameState) -> bool:
        return gs.get_building_count("barracks") >= 1 \
            and gs.can_train("militia")

    func actions(gs: AIGameState) -> void:
        gs.train("militia")


# ============================================
# ATTACK
# ============================================

class AttackRule extends AIRule:
    func _init():
        rule_name = "attack"

    func conditions(gs: AIGameState) -> bool:
        var min_military = gs.get_sn("sn_minimum_attack_group_size")
        return gs.get_military_population() >= min_military \
            and not gs.is_under_attack() \
            and gs.is_timer_triggered(1)  # Attack timer

    func actions(gs: AIGameState) -> void:
        gs.attack_now()
        gs.disable_timer(1)
        gs.enable_timer(1, 60)  # Reset attack timer


# ============================================
# INITIALIZATION (runs once)
# ============================================

class InitializationRule extends AIRule:
    func _init():
        rule_name = "initialization"

    func conditions(_gs: AIGameState) -> bool:
        return true  # Always fires first time

    func actions(gs: AIGameState) -> void:
        # Resource allocation
        gs.set_sn("sn_food_gatherer_percentage", 60)
        gs.set_sn("sn_wood_gatherer_percentage", 40)
        gs.set_sn("sn_gold_gatherer_percentage", 0)
        gs.set_sn("sn_stone_gatherer_percentage", 0)

        # Targets
        gs.set_sn("sn_target_villagers", 25)
        gs.set_sn("sn_minimum_attack_group_size", 5)

        # Start attack timer
        gs.enable_timer(1, 90)  # First attack at 90 seconds

        disable_self()
```

### Rule evaluation

```gdscript
# ai_controller.gd
var rules: Array[AIRules.AIRule] = []

func _ready() -> void:
    _init_rules()

func _init_rules() -> void:
    # Order matters for resource priority - earlier rules get first access
    rules = [
        AIRules.InitializationRule.new(),
        AIRules.BuildHouseRule.new(),
        AIRules.TrainVillagerRule.new(),
        AIRules.BuildBarracksRule.new(),
        AIRules.TrainMilitiaRule.new(),
        AIRules.AttackRule.new(),
    ]

func _evaluate_rules() -> void:
    for rule in rules:
        if rule.enabled and rule.conditions(game_state):
            rule.actions(game_state)
```

---

## Strategic numbers

We use a subset of AoE2's strategic numbers. Start with these defaults:

```gdscript
# ai_controller.gd
var strategic_numbers: Dictionary = {
    # Resource gathering allocation (must sum to 100)
    "sn_food_gatherer_percentage": 60,
    "sn_wood_gatherer_percentage": 40,
    "sn_gold_gatherer_percentage": 0,
    "sn_stone_gatherer_percentage": 0,

    # Civilian distribution
    "sn_percent_civilian_gatherers": 85,
    "sn_percent_civilian_builders": 15,

    # Targets
    "sn_target_villagers": 25,
    "sn_target_farms": 6,

    # Building placement
    "sn_maximum_town_size": 24,
    "sn_camp_max_distance": 10,

    # Attack settings
    "sn_minimum_attack_group_size": 5,
    "sn_percent_attack_soldiers": 100,
    "sn_attack_intelligence": 1,  # Smart pathfinding
    "sn_task_ungrouped_soldiers": 0,  # Don't let soldiers wander

    # Defense
    "sn_percent_enemy_sighted_response": 100,
    "sn_gather_defense_units": 1,  # Gather units for defense when attacked
}
```

Rules can read/modify these via `gs.get_sn()` and `gs.set_sn()`.

---

## Goals (state variables)

Goals are integer variables for tracking AI state. We use a dictionary with integer keys (matching AoE2's goal numbering).

```gdscript
var goals: Dictionary = {}  # goal_id (int) -> value (int)

# Example usage in rules:
# gs.set_goal(1, 1)  # Goal 1 = "has barracks"
# if gs.get_goal(1) == 1: ...
```

For readability, we can define constants:

```gdscript
const GOAL_HAS_BARRACKS = 1
const GOAL_ECONOMY_MODE = 2
const GOAL_UNDER_ATTACK = 3
```

---

## Timers

Timers enable time-based triggers. Dictionary of timer_id -> expiry_time.

```gdscript
var timers: Dictionary = {}  # timer_id (int) -> expiry_time (float)

func is_timer_triggered(timer_id: int) -> bool:
    if timer_id not in timers:
        return false
    return Time.get_ticks_msec() / 1000.0 >= timers[timer_id]

func enable_timer(timer_id: int, seconds: float) -> void:
    timers[timer_id] = Time.get_ticks_msec() / 1000.0 + seconds

func disable_timer(timer_id: int) -> void:
    timers.erase(timer_id)
```

---

## Villager assignment

AoE2 uses strategic numbers to auto-assign villagers to resources. We'll implement this in the rule engine:

```gdscript
# Called each tick after rules evaluate
func _assign_villagers() -> void:
    var idle_villagers = _get_idle_ai_villagers()
    if idle_villagers.is_empty():
        return

    var food_pct = strategic_numbers["sn_food_gatherer_percentage"]
    var wood_pct = strategic_numbers["sn_wood_gatherer_percentage"]
    var gold_pct = strategic_numbers["sn_gold_gatherer_percentage"]
    var stone_pct = strategic_numbers["sn_stone_gatherer_percentage"]

    # Calculate current distribution
    var current = _get_villager_distribution()

    # Assign idle villagers to resources below target percentage
    for villager in idle_villagers:
        var target_resource = _get_most_needed_resource(current, food_pct, wood_pct, gold_pct, stone_pct)
        _assign_villager_to_resource(villager, target_resource)
        current[target_resource] += 1
```

---

## File organization

```
scripts/ai/
├── ai_controller.gd      # Entry point, rule engine, strategic numbers
├── ai_game_state.gd      # Game state wrapper for rules
└── ai_rules.gd           # All rule definitions
```

For Phase 3.1A, all rules go in `ai_rules.gd`. If it grows unwieldy in later sub-phases, we can split into:
- `ai_rules_economy.gd`
- `ai_rules_military.gd`
- `ai_rules_defense.gd`

---

## Implementation order (Phase 3.1A)

1. **ai_game_state.gd** - Create wrapper with condition helpers
2. **ai_rules.gd** - Create base class and MVP rules
3. **ai_controller.gd** - Rule engine, strategic numbers, evaluation loop
4. **Villager assignment** - Auto-assign based on percentages
5. **Action execution** - Connect rules to actual game commands
6. **Test by playing** - Verify AI trains villagers, builds, attacks

---

## Reference

- `aoe2_ai_rule_system.md` - How real AoE2 AI works
- `aoe2_strategic_numbers.md` - Full list of strategic numbers
- `phase3_failure_summary.md` - Why procedural approach failed
