# Phase 2.5B Checkpoint: Villager-Based Building Construction

**Date:** 2026-01-31
**Status:** Complete

---

## Summary

Implemented AoE2-style villager-based building construction where buildings start as foundations, villagers physically walk to and construct them over time, and construction progress is visible through HP scaling.

---

## Context Friction

1. **Files re-read multiple times?** Yes - context cleared after starting, required re-reading of main.gd, villager.gd, building.gd, hud.gd
2. **Forgot earlier decisions?** No - session summary preserved construction implementation pattern
3. **Uncertain patterns?** No - followed established patterns from similar mechanics (gathering, hunting)

---

## Implemented Features

| Feature | Files | Notes |
|---------|-------|-------|
| Construction state system | `scripts/buildings/building.gd:start_construction()` | Buildings start at 0% progress, 1 HP |
| Construction progress | `scripts/buildings/building.gd:progress_construction()` | Increments progress, scales HP with progress |
| Multi-builder support | `scripts/buildings/building.gd:add_builder(), remove_builder()` | Tracks villagers, emits worker_count_changed signal |
| Diminishing returns | `scripts/buildings/building.gd:progress_construction()` | Harmonic series: 1x, 1.5x, 1.75x, 1.83x... |
| is_functional() pattern | `scripts/buildings/building.gd:is_functional()` | Returns true only if constructed AND not destroyed |
| Villager BUILDING state | `scripts/units/villager.gd:State.BUILDING` | New state for construction behavior |
| command_build() | `scripts/units/villager.gd:command_build()` | Command villager to construct a building |
| Builder cleanup on death | `scripts/units/villager.gd:die()` | Removes self from building's builder list |
| Villager-only build panel | `scripts/ui/hud.gd` | Build panel only visible when villager selected |
| Construction placement | `scripts/main.gd:_place_building()` | Buildings start construction, villagers assigned |
| Cancel with partial refund | `scripts/ui/hud.gd:delete_selected_building()` | Refunds unbuilt portion of resources |
| AI construction management | `scripts/ai/ai_controller.gd:_manage_construction()` | AI assigns villagers to build foundations |
| Build time per building | All building subclasses | House: 25s, Farm: 15s, Camps: 35s, Military: 50s, Market: 60s, TC: 150s |

---

## Construction System Details

### Multi-Builder Diminishing Returns

| Builders | Speed Multiplier | Calculation |
|----------|------------------|-------------|
| 1 | 1.0x | Base speed |
| 2 | 1.5x | 1 + 0.5 |
| 3 | 1.75x | 1 + 0.5 + 0.25 |
| 4 | 1.83x | 1 + 0.5 + 0.25 + 0.125 |
| n | Harmonic(n) | Sum of 0.5^(i-1) for i=1..n |

### HP Scaling During Construction

HP scales linearly from 1 to max_hp as construction progresses:
```
current_hp = 1 + int(construction_progress * (max_hp - 1))
```

### Cancellation Refund

AoE2 refunds the unbuilt portion:
```
refund = cost * (1.0 - construction_progress)
```
Currently only wood costs are refunded (primary building resource).

---

## AI Behavior Updates

- AI now tracks `buildings_under_construction` array
- `_manage_construction()` assigns up to 2 idle villagers per unfinished building
- AI checks `is_functional()` before using buildings for drop-off, training, etc.
- AI building placement immediately starts construction and assigns builder

---

## Deviations from Spec

| Spec Said | Implementation | Reason |
|-----------|----------------|--------|
| Initial implementation had no refund | Partial refund on cancel | Spec-check agent found AoE2 manual says "resources from the unbuilt portion are returned" - fixed |

---

## Code Review Improvements Applied

| Issue | Fix |
|-------|-----|
| ISSUE-001: Villager death doesn't clean up builder list | Added `die()` override to call `remove_builder(self)` before `super.die()` |
| ISSUE-003: HUD delete doesn't release builders | Added `building.remove_builder(builder)` before clearing villager state |
| ISSUE-009: No idle notification after construction | Added `GameManager.villager_idle.emit(self, "Construction complete")` |

---

## Known Issues

| Issue | Status | Notes |
|-------|--------|-------|
| Combat test timing | Pre-existing | 5 combat tests fail - timing sensitive with avoidance |
| Hunting test timing | Pre-existing | 2 hunting tests fail - timing sensitive with avoidance |

These 7 test failures existed before Phase 2.5B and are timing-related, not construction-related.

---

## Test Coverage

### Manual Testing Performed
- [x] Buildings start as foundations (low HP, 0% progress)
- [x] Villagers walk to foundation and stand nearby
- [x] Construction progress visible via HP increase
- [x] Multiple villagers speed up construction (diminishing returns)
- [x] Construction completes, building becomes functional
- [x] Deleting under-construction building refunds resources proportionally
- [x] AI assigns villagers to build its buildings
- [x] Villager death during construction doesn't break building
- [x] Reassigning villager mid-construction works (remove from old, add to new)
- [x] Build panel only shows when villager is selected

### Automated Tests

**Tests created by test agent:** 23 tests in `tests/scenarios/test_construction.gd`

Construction progress tests:
- `test_building_starts_with_zero_progress`
- `test_construction_progress_increases`
- `test_construction_completes_at_full_progress`
- `test_hp_scales_with_progress`
- `test_building_starts_with_one_hp`

Builder management tests:
- `test_add_builder_increases_count`
- `test_remove_builder_decreases_count`
- `test_multiple_builders_speed_multiplier`
- `test_builder_count_signal_emitted`
- `test_building_tracks_builders_array`

Villager construction state tests:
- `test_villager_enters_building_state`
- `test_villager_clears_previous_construction`
- `test_villager_moves_toward_construction`
- `test_villager_stops_when_in_range`
- `test_villager_goes_idle_after_construction_complete`

is_functional() tests:
- `test_building_not_functional_while_constructing`
- `test_building_functional_after_construction`
- `test_building_not_functional_when_destroyed`

Cancellation and refund tests:
- `test_partial_refund_calculation`
- `test_full_refund_at_zero_progress`
- `test_no_refund_at_full_progress`
- `test_cancel_releases_builders`

Die cleanup test:
- `test_villager_die_removes_from_builders`

### Test Summary

- **Tests written:** 23 tests in `tests/scenarios/test_construction.gd`
- **Coverage focus:** Construction progress, multi-builder mechanics, HP scaling, villager state, cancellation refunds
- **Notable edge cases:** Villager death during construction, builder cleanup, partial refund at various progress levels

---

## Lessons Learned

(Added to docs/gotchas.md)

- **is_functional() pattern**: Use `is_functional()` instead of just `is_constructed` for building usability checks. A building may be constructed but destroyed, or vice versa.
- **Builder cleanup on death**: Villagers must clean up their construction assignment in `die()` before calling `super.die()`, otherwise the building's builder count is wrong.
- **AoE2 partial refund**: Construction cancellation refunds the unbuilt portion (`cost * (1 - progress)`), not nothing and not full cost.
- **Diminishing returns**: Multi-builder speed uses harmonic series, not linear scaling. This discourages stacking 5+ villagers on one building.
- **Build panel visibility**: Build panel should only show when a villager is selected, not always visible.

---

## Context for Next Phase

Critical information for future phases:

- **is_functional() API**: All code checking if buildings are usable should use `is_functional()`, not `is_constructed`
- **Construction signals**: `construction_completed` signal fires when construction finishes, `worker_count_changed(count)` when builders change
- **Builder tracking**: Buildings track their builders in `builders` array, call `add_builder()`/`remove_builder()` to update
- **AI construction**: AI uses `_manage_construction()` in decision loop, caps at 2 builders per building
- **Build times**: House 25s, Farm 15s, Camps 35s, Military 50s, Market 60s, TC 150s

---

## Git Reference

- **Files changed:** ~15 files
- **New patterns:** Construction progress system, is_functional() pattern, builder management
