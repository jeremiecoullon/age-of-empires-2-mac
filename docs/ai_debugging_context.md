# AI debugging session context

**Date:** 2026-02-04
**Status:** In progress - context dump for next session

---

## Summary

Debugging AI player behavior. Added observability metrics, identified multiple bugs. AI is fundamentally broken in several ways.

---

## Observability added

Added new debug metrics to `ai_controller.gd` and `ai_game_state.gd`:

```json
"efficiency": {
  "avg_food_drop_dist": 1029,    // Average distance food gatherers → drop-off
  "avg_wood_drop_dist": 32,      // Average distance wood gatherers → drop-off
  "avg_gold_drop_dist": -1,      // -1 means no gatherers
  "avg_stone_drop_dist": -1,
  "max_on_same_food": 7,         // Max villagers on same food target
  "max_on_same_wood": 2,
  "max_on_same_gold": 0,
  "max_on_same_stone": 0
}
```

**Files changed:**
- `scripts/ai/ai_game_state.gd` - Added `get_gatherer_distances()` and `get_villagers_per_target()`
- `scripts/ai/ai_controller.gd` - Added efficiency metrics to debug output, also added `game_time_elapsed` tracking

---

## Bugs identified

### 1. Food gatherers walking forever
- **Symptom:** `avg_food_drop_dist` reaches 800-1000+ pixels
- **Expected:** Should be <200 pixels (mill should be built)
- **Evidence:** Logs show distance climbing from 213 → 1029 over time

### 2. Villager clustering (multiple villagers on same target)
- **Symptom:** `max_on_same_food` reaches 6-7 (7 villagers on ONE sheep)
- **Expected:** Max 1-2 villagers per resource node
- **Evidence:** Logs show `max_on_same_food: 7` at t=41.5s

### 3. Mill not being built
- **Symptom:** No mill built despite food distance >200 (the threshold in `needs_mill()`)
- **Expected:** BuildMillRule should fire when food gatherers are far from drop-off
- **Root cause:** Unknown - rule conditions need investigation

### 4. Barracks not being built
- **Symptom:** `can_afford.barracks: true` at t=156.1s but barracks count stays 0
- **Expected:** BuildBarracksRule should fire with 5+ villagers and 100 wood
- **Root cause:** Unknown - rule conditions need investigation

### 5. Villager ratio doesn't match strategic numbers
- **Symptom:** 90% food / 10% wood gatherers when strategic numbers say 60/40
- **Expected:** Ratio should roughly match sn_food_gatherer_percentage / sn_wood_gatherer_percentage
- **Root cause:** Assignment logic may be broken, or villagers not being reassigned

### 6. Lumber camp built next to only 1 tree
- **Symptom:** AI built lumber camp in bad location with only 1 tree nearby
- **Expected:** Should check resource density before building drop-off
- **Root cause:** No density check in BuildLumberCampRule

### 7. AI cheats through fog of war
- **Symptom:** AI sends villagers to resources across the map it shouldn't know about
- **Evidence:** AI queries `scene_tree.get_nodes_in_group("wood_resources")` with no visibility filter
- **Root cause:** AI code has no fog of war integration at all

---

## Fog of war fix plan

**Current state:**
- `scripts/fog_of_war.gd` only tracks PLAYER visibility
- Has helper methods: `is_position_visible()`, `is_explored()`, `get_visibility_at()`
- AI has no visibility grid - it sees everything

**Fix needed:**

1. **Add AI visibility tracking** to `fog_of_war.gd`:
   - Add second visibility grid for AI team, OR
   - Make system per-team: `visibility_grids[team_id][x][y]`
   - Update `_reveal_around()` to work for AI units/buildings too
   - Add `is_explored_by_team(world_pos, team)` method

2. **Filter AI resource queries** in `ai_game_state.gd`:
   ```gdscript
   for resource in scene_tree.get_nodes_in_group("wood_resources"):
       if not fog_of_war.is_explored_by_team(resource.global_position, AI_TEAM):
           continue
   ```

3. **Add AI scouting behavior** (separate feature):
   - Without scouting, AI only knows resources near its base
   - Scout units should explore the map

**Difficulty:** Medium (~50-100 lines across 2-3 files)

---

## Important design note

**Fog of war should be purely an advantage, not a crutch.**

The AI should function correctly WITHOUT relying on fog of war to limit its knowledge. Meaning:
- AI should make good decisions about WHERE to gather (nearby resources first)
- AI should build drop-offs near resources it's actually using
- AI should not cluster villagers on single targets

Fog of war is a BONUS feature that prevents cheating. It should not be required for the AI to behave sensibly. If we fix fog of war but the AI still sends villagers far away (just within explored area), the core bugs remain.

**Fix priority:**
1. First: Fix core AI logic bugs (clustering, drop-off placement, rule firing)
2. Then: Add fog of war integration as additional constraint

---

## Files to investigate

- `scripts/ai/ai_rules.gd` - Why aren't BuildMillRule, BuildBarracksRule firing?
- `scripts/ai/ai_game_state.gd` - Resource assignment logic, `needs_mill()`, `needs_lumber_camp()`
- `scripts/ai/ai_controller.gd` - Villager assignment logic (`_assign_villagers`, `_get_most_needed_resource`)

---

## Next steps

1. **Investigate why rules aren't firing** - Add logging to rule conditions to see which specific condition fails
2. **Fix villager clustering** - Limit villagers per resource node
3. **Fix drop-off building logic** - Check resource density, not just distance
4. **Fix villager ratio** - Debug why assignment doesn't match strategic numbers
5. **Add fog of war for AI** - After core bugs are fixed

---

## Test commands

```bash
# Run tests
/Applications/Godot.app/Contents/MacOS/Godot --headless --path /Users/jeremiecoullon/Documents/code/age_of_empires tests/test_scene.tscn

# Validate project import
/Applications/Godot.app/Contents/MacOS/Godot --headless --import --path /Users/jeremiecoullon/Documents/code/age_of_empires
```

All 282 tests currently pass.
