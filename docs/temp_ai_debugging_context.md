# AI debugging context (temporary)

**Date:** 2026-02-04
**Status:** Bugs 1-4 FIXED. Design gaps remain.

**See also:** `docs/temp_economy_fixes_plan.md` - Plan for fixing economy logic gaps (stockpile cap, depletion awareness)

---

## Bug 1: Barracks/lumber_camp placed but never complete - FIXED

### Root Cause (found and fixed)

**Race condition in rule execution:** When `build_lumber_camp` and `gather_sheep` rules fire in the same tick, both capture the same idle villager. The execution order in `execute_actions()` is:

1. `_do_build()` assigns villager A to build lumber_camp → villager now in BUILDING state
2. `_do_villager_assignment()` assigns same villager A to sheep → calls `command_hunt()` which removes the builder

The `command_hunt()` method at `villager.gd:258-268` clears `target_construction` and sets state to HUNTING, canceling the build.

### Fix Applied

Added guard in `ai_game_state.gd:_do_villager_assignment()`:

```gdscript
# Don't reassign villagers that were assigned to build this tick
# This prevents race conditions where gather_sheep overwrites a builder assignment
if villager.current_state == villager.State.BUILDING:
    return
```

### Verification

Before fix:
- t=10: `building_vill:0`, `barracks:0`, `lumber_camp:0`
- Buildings never completed

After fix:
- t=10: `building_vill:2` (villagers actively building)
- t=40: `lumber_camp:1` (completed)
- t=60: `barracks:1` (completed)

All 282 unit tests pass.

---

## Bug 2: Villager clustering - FIXED

**Symptom:** `max_on_same_food: 11` - 11 villagers on ONE farm/sheep

**Expected:** Max 1-2 villagers per resource node

**Root cause:** No limit on villagers per target in assignment logic. `assign_villager_to_resource()` finds the nearest resource but doesn't check how many villagers are already on it. Same issue affected `get_nearest_sheep()` and `get_nearest_huntable()`.

### Fix Applied

1. Added `sn_max_gatherers_per_resource: 2` strategic number in `ai_controller.gd`

2. Added `_get_current_gatherer_counts()` helper in `ai_game_state.gd` that returns `{target_instance_id: count}` for all resources being gathered/hunted

3. Modified three functions to check gatherer counts and prefer targets with capacity:
   - `assign_villager_to_resource()` - for static resources (trees, gold, stone, farms, berries)
   - `get_nearest_sheep()` - for sheep assignment
   - `get_nearest_huntable()` - for deer/boar assignment

4. Graceful degradation: if all resources of a type are at capacity, still assign to the nearest one (better than leaving villager idle)

### Verification

Before fix:
- `max_on_same_food: 5` by t=70
- `max_on_same_food: 7-8` by t=100-120

After fix:
- `max_on_same_food: 2` consistently from t=10 to t=120
- Only reaches 3-6 later as food sources deplete (expected graceful degradation)
- `max_on_same_wood: 1-2` throughout

All 282 unit tests pass.

---

## Bug 3: Insane drop-off distances - FIXED

**Symptom:** `avg_food_drop_dist: 1500+` pixels at late game

**Expected:** Should be <200 pixels (with drop-off buildings nearby)

### Root causes (all fixed)

1. **RETURNING villagers not counted** - Villagers walking back to drop-off weren't counted toward gatherer limits, causing over-assignment
2. **Distance not weighted against capacity** - An empty resource 1000px away beat a "full" resource 50px away
3. **Farms treated same as depletable resources** - Farms are renewable but had the same 2-gatherer limit as sheep

### Fixes Applied

1. `_get_current_gatherer_counts()` - Now counts villagers in RETURNING state (they will return to the same resource)
2. `assign_villager_to_resource()`, `get_nearest_sheep()`, `get_nearest_huntable()` - Added distance threshold: if nearest available > 400px but "full" resource < 200px, prefer the close one
3. `assign_villager_to_resource()` - Farms exempt from max_gatherers limit (renewable resource)
4. `get_villagers_per_target()` - Updated to also count RETURNING villagers for consistent metrics
5. `_assigned_targets_this_tick` - Track pending assignments within same tick to prevent multiple villagers being assigned to the same target before state updates
6. `get_nearest_sheep()`, `get_nearest_huntable()` - Added hard cap (2x max_gatherers) for graceful degradation to prevent excessive piling

### Verification

**Before fix (late game t=220-290):**
- `max_on_same_food: 8-10`
- `avg_food_drop_dist: 1500-1800`

**After fix (late game t=220-290):**
- `max_on_same_food: 1-5`
- `avg_food_drop_dist: 122-351`

**Note:** Mid-game (t=70-180) still shows elevated food_dist (700-1500px) when natural food depletes and scatters. This is a design gap (no depletion awareness), not Bug 3. Once farms are built (t=200+), distances drop dramatically.

All 282 unit tests pass.

---

## Bug 4: Drop-off buildings placed next to Town Center - FIXED

**Symptom:** AI builds mills/lumber camps/mining camps right next to the TC instead of near distant resources.

**Expected:** Drop-off buildings should be placed near resources that are FAR from existing drop-offs.

### Root cause (found and fixed)

Two-part issue:

1. `needs_lumber_camp()` uses AVERAGE distance. If 3 trees are near TC (50px) and 10 trees are far (1000px), average = 781px > 200px threshold, so it triggers.

2. `_find_nearest_resource_position("wood")` finds the NEAREST resource to TC - the trees at 50px.

3. Lumber camp gets built near those trees, right next to TC - useless.

### Fix Applied

Modified `_find_nearest_resource_position()` to accept a `for_dropoff_building` parameter. When true, it skips resources that are already within 200px of an existing drop-off:

```gdscript
func _find_nearest_resource_position(resource_type: String, exclude_farms: bool = false, for_dropoff_building: bool = false) -> Vector2:
    const MIN_DROPOFF_DISTANCE: float = 200.0
    ...
    for resource in ...:
        # For drop-off buildings, skip resources that are already close to a drop-off
        if for_dropoff_building:
            var dropoff_dist = get_nearest_drop_off_distance(resource_type, resource.global_position)
            if dropoff_dist < MIN_DROPOFF_DISTANCE:
                continue  # This resource already has a nearby drop-off, skip it
```

In `_find_build_position()`, pass `for_dropoff_building=true` for mills, lumber camps, and mining camps.

This ensures drop-off buildings are only built near resources that actually need them.

---

## Economy logic gaps (design issues, not bugs)

**Full plan:** See `docs/temp_economy_fixes_plan.md`

Summary of gaps:
- **Stockpile cap** - AI keeps 40% on wood even with 500+ stockpiled
- **Depletion awareness** - When wood runs out, gatherers don't get reassigned

These are design gaps, not bugs. Current system works for early game but breaks down as resources deplete or stockpiles grow.

---

## What's working

- Farms built and completed
- Houses built and completed
- **Lumber camps built and completed** (Bug 1 fix)
- **Barracks built and completed** (Bug 1 fix)
- **Villager distribution across resources** (Bug 2 + Bug 3 fixes) - works throughout game
- **Efficient drop-off distances** (Bug 3 fix) - late game distances now reasonable
- Villager production
- Rule evaluation system
- Observability/logging

---

## Priority order

1. ~~Fix barracks/lumber_camp not completing~~ DONE (Bug 1)
2. ~~Fix villager clustering~~ DONE (Bug 2)
3. ~~Fix insane drop-off distances~~ DONE (Bug 3)
4. ~~Fix mill placement near TC~~ DONE (Bug 4)
5. Add resource depletion handling - Reassign villagers when resource type runs out (design gap)
6. Add stockpile caps - Don't over-gather when stockpile is high (design gap)

---

## Observability (added by previous agent)

### Rule evaluation logging
`RULE_TICK` output shows which rules fired and why others were skipped:
```
RULE_TICK|{"t":7.9,"fired":["gather_sheep","build_barracks"],"skipped":{"train_villager":"insufficient_food","build_house":"headroom_5",...}}
```

### Action logging
`AI_ACTION` output when actions execute:
```
AI_ACTION|{"t":7.9,"action":"build","building":"barracks","pos":[1616,1808]}
AI_ACTION|{"t":1.5,"action":"assign_builder","building":"LumberCamp","source":"idle"}
```

### Rule blockers in AI_STATE
Periodic snapshot shows why key rules can't fire:
```json
"rule_blockers": {
  "build_barracks": "already_have_barracks",
  "train_militia": "insufficient_food",
  "attack": "need_5_military_have_0"
}
```

### Efficiency metrics in AI_STATE
```json
"efficiency": {
  "avg_food_drop_dist": 150,
  "avg_wood_drop_dist": 47,
  "max_on_same_food": 5,
  "max_on_same_wood": 2
}
```

---

## Test commands

```bash
# Run 5-minute AI test
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . scenes/test_ai_solo.tscn 2>&1 | grep -E "^(AI_|RULE_)"

# Run unit tests
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . tests/test_scene.tscn
```

All 282 tests currently pass.
