# AI debugging context (temporary)

**Date:** 2026-02-04
**Status:** In progress - Bug 1 fixed, Bugs 2-3 remain

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

## Bug 2: Villager clustering (OPEN)

**Symptom:** `max_on_same_food: 11` - 11 villagers on ONE farm/sheep

**Expected:** Max 1-2 villagers per resource node

**Root cause:** No limit on villagers per target in assignment logic. `assign_villager_to_resource()` finds the nearest resource but doesn't check how many villagers are already on it.

**Fix approach:** Add villager count tracking per resource target and skip targets that already have max gatherers.

**Key files:**
- `scripts/ai/ai_game_state.gd` - `assign_villager_to_resource()` (line ~810)

---

## Bug 3: Insane drop-off distances (OPEN - partially mitigated)

**Symptom:** `avg_food_drop_dist: 1500+` pixels at late game

**Expected:** Should be <200 pixels (with drop-off buildings nearby)

**Root cause:** Combination of:
1. ~~Lumber camp/mill never built~~ (fixed by Bug 1 fix)
2. Villagers assigned to distant resources without considering distance
3. When nearby resources deplete, no reassignment happens

**Note:** With Bug 1 fixed, lumber camps now complete so wood drop distances should improve. Food drop distances are still high due to Bug 2 (clustering on distant resources) and lack of efficient resource selection.

---

## Economy logic gaps (design issues, not bugs)

### No stockpile cap
AI keeps 40% on wood even with 500+ stockpiled. The percentage system is rigid.

### No depletion awareness
When wood runs out, wood gatherers don't get reassigned. They stay assigned to "wood" but have nothing to gather.

### No needs-based allocation
AI doesn't think "I need barracks (100 wood), so prioritize wood until I have that." It just follows fixed percentages regardless of goals.

**Note:** These are design gaps, not bugs. Current system works for early game but breaks down as resources deplete or stockpiles grow.

---

## What's working

- Farms built and completed
- Houses built and completed
- **Lumber camps built and completed** (Bug 1 fix)
- **Barracks built and completed** (Bug 1 fix)
- Villager production
- Rule evaluation system
- Observability/logging

---

## Priority order

1. ~~Fix barracks/lumber_camp not completing~~ DONE
2. **Fix villager clustering** - Limit villagers per resource target
3. **Add resource depletion handling** - Reassign villagers when resource type runs out
4. **Add stockpile caps** - Don't over-gather when stockpile is high

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
