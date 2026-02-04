# Economy Logic Fixes Plan

**Date:** 2026-02-04
**Status:** Ready for implementation
**Related:** `docs/temp_AI_debugging_context.md` (bugs 1-2 fixed, bug 3 in progress by another agent)

---

## To-do list

### Implementation
- [x] **Bug 4: Mill placement** - In `_find_build_position()`, return `Vector2.ZERO` if `near_resource` specified but no resource found (FIXED)
- [ ] **Fix 1: Depletion awareness** - Add `has_gatherable_resources()` helper, skip depleted types in allocation (see details below)
- [ ] **Fix 2: Stockpile cap** - Add threshold check, reduce allocation to 0 when exceeded (see details below)
- [ ] **Investigate stranded gatherers** - Check villager.gd to see if villagers get stuck when resources deplete mid-gather. If yes, add detection. If they become idle naturally, skip this.
- [ ] **Add observability** - Add `economy.depleted` and `economy.capped` to AI_STATE output
- [ ] **Test** - Run AI test, verify metrics improve

### After implementation is verified
- [ ] **Update gotchas.md** - Add a brief entry documenting what was learned (e.g., "AI allocation needs depletion/stockpile checks")
- [ ] **Delete temp docs** - Remove `docs/temp_economy_fixes_plan.md` and `docs/temp_AI_debugging_context.md`

**Note:** This is not a new phase. These are reactive fixes, not planned features. No checkpoint doc needed.

---

## Overview

Two economy logic gaps need fixing:
1. **Stockpile cap** - AI over-gathers resources it doesn't need
2. **Depletion awareness** - AI doesn't handle resource exhaustion

These are design gaps, not bugs. The current percentage-based allocation works for early game but breaks down as resources deplete or stockpiles grow.

---

## Fix 1: Depletion Awareness

**Problem:** When wood runs out, AI still tries to assign villagers to wood. They either stay idle or get stuck.

**Solution:** Skip depleted resource types in allocation logic.

### Implementation

**In `ai_game_state.gd`, add helper:**

```gdscript
func has_gatherable_resources(resource_type: String) -> bool:
    ## Returns true if any gatherable resources of this type exist
    var group_name = resource_type + "_resources"
    for resource in scene_tree.get_nodes_in_group(group_name):
        if resource.has_resources():
            return true
    return false
```

**In `ai_controller.gd`, modify `_get_most_needed_resource()`:**

Before calculating deficits, check if resource type is depleted:

```gdscript
# Check which resources are available
var food_available = game_state.has_gatherable_resources("food")
var wood_available = game_state.has_gatherable_resources("wood")
var gold_available = game_state.has_gatherable_resources("gold")
var stone_available = game_state.has_gatherable_resources("stone")

# Treat depleted resources as 0% target
if not food_available:
    food_pct = 0
if not wood_available:
    wood_pct = 0
# ... etc
```

### Investigation needed: Stranded gatherers

Check villager behavior when their target resource depletes mid-gather:
- If they become IDLE → normal assignment loop handles them, no extra work needed
- If they get stuck in GATHERING state → need to detect and reassign them

To check: Look at `villager.gd` gathering logic. What happens when `target_resource.has_resources()` returns false?

If stranded gatherers are an issue, add detection in `get_villagers_by_task()`:
```gdscript
# In GATHERING case, check if target is still valid
if villager.current_state == villager.State.GATHERING:
    if not is_instance_valid(villager.target_resource) or not villager.target_resource.has_resources():
        result["idle"].append(villager)  # Treat as idle for reassignment
        continue
```

---

## Fix 2: Stockpile Cap

**Problem:** AI keeps 40% on wood even with 500+ stockpiled. Wastes villager time.

**Solution:** When stockpile exceeds threshold, reduce effective allocation to 0.

### Implementation

**In `ai_controller.gd`, add constant:**

```gdscript
const STOCKPILE_CAP: int = 400  # Stop gathering when stockpile exceeds this
```

**Modify `_get_most_needed_resource()`:**

```gdscript
# Cap stockpiles - don't over-gather
var food_capped = game_state.get_resource("food") > STOCKPILE_CAP
var wood_capped = game_state.get_resource("wood") > STOCKPILE_CAP
var gold_capped = game_state.get_resource("gold") > STOCKPILE_CAP
var stone_capped = game_state.get_resource("stone") > STOCKPILE_CAP

# Reduce effective percentage for capped resources
if food_capped:
    food_pct = 0
if wood_capped:
    wood_pct = 0
# ... etc

# Edge case: if ALL resources are capped, allow gathering the lowest stockpile
# (prevents all villagers going idle)
```

---

## Observability

### Add to AI_STATE output (in `_print_debug_state()`)

Under a new "economy" key:

```gdscript
"economy": {
    "depleted": {
        "food": not game_state.has_gatherable_resources("food"),
        "wood": not game_state.has_gatherable_resources("wood"),
        "gold": not game_state.has_gatherable_resources("gold"),
        "stone": not game_state.has_gatherable_resources("stone"),
    },
    "capped": {
        "food": game_state.get_resource("food") > STOCKPILE_CAP,
        "wood": game_state.get_resource("wood") > STOCKPILE_CAP,
        "gold": game_state.get_resource("gold") > STOCKPILE_CAP,
        "stone": game_state.get_resource("stone") > STOCKPILE_CAP,
    }
}
```

### Action logs (optional, add if useful for debugging)

```gdscript
# When resource type becomes depleted (first detection)
AI_ACTION|{"action":"resource_depleted","resource":"wood"}

# When stockpile cap reached/cleared
AI_ACTION|{"action":"stockpile_capped","resource":"wood","amount":423}
```

---

## What was explicitly NOT included

**Needs-based allocation / savings goals** - Considered but deemed overkill. The percentage system already works for building things. The AI successfully builds barracks, houses, farms. This would be premature optimization.

---

## Testing

After implementation, run the AI test and verify:

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . scenes/test_ai_solo.tscn 2>&1 | grep -E "^(AI_|RULE_)"
```

**Expected behavior:**
- When wood stockpile > 400, `economy.capped.wood: true` in AI_STATE
- When wood depletes, `economy.depleted.wood: true` in AI_STATE
- Villagers should redistribute to non-capped, non-depleted resources
- No villagers stuck trying to gather depleted resources

---

## Files to modify

1. `scripts/ai/ai_game_state.gd` - Add `has_gatherable_resources()`, possibly stranded gatherer detection
2. `scripts/ai/ai_controller.gd` - Add `STOCKPILE_CAP`, modify `_get_most_needed_resource()`, update `_print_debug_state()`
