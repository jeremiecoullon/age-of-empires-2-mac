# Phase 2.5A Checkpoint: UX Polish

**Date:** 2026-01-31
**Status:** Complete

---

## Summary

Implemented four UX improvements: enemy building labels in info panel, live unit status updates, pathfinding avoidance to prevent unit stacking, and production queue for all training buildings.

---

## Context Friction

1. **Files re-read multiple times?** Yes - context was cleared mid-phase, requiring re-read of market.gd, stable.gd, hud.gd, and hud.tscn
2. **Forgot earlier decisions?** No - session summary captured queue implementation pattern
3. **Uncertain patterns?** No - production queue pattern from TownCenter was applied consistently

---

## Implemented Features

| Feature | Files | Notes |
|---------|-------|-------|
| Enemy building label | `scripts/ui/hud.gd:_show_building_info()` | Shows "(Enemy)" suffix for non-player buildings |
| Live unit status updates | `scripts/ui/hud.gd:_process(), _update_selected_entity_info()` | Info panel updates HP/state in real-time |
| Pathfinding avoidance | `scripts/units/unit.gd`, all unit `.tscn` files | NavigationAgent2D avoidance prevents unit stacking |
| Production queue (TC) | `scripts/buildings/town_center.gd` | Queue up to 15 villagers |
| Production queue (Barracks) | `scripts/buildings/barracks.gd` | Queue militia and spearman |
| Production queue (ArcheryRange) | `scripts/buildings/archery_range.gd` | Queue archers and skirmishers |
| Production queue (Stable) | `scripts/buildings/stable.gd` | Queue scout cavalry and cavalry archers |
| Production queue (Market) | `scripts/buildings/market.gd` | Queue trade carts |
| Queue UI | `scenes/ui/hud.tscn`, `scripts/ui/hud.gd` | QueueLabel and CancelButton for each training panel |

---

## Production Queue Details

All training buildings use consistent queue pattern:

| Behavior | Implementation |
|----------|----------------|
| Max queue size | 15 units (MAX_QUEUE_SIZE constant) |
| Resource timing | Deducted immediately on queue |
| Cancel behavior | Removes last queued (not currently training), refunds resources |
| Queue signal | `queue_changed(queue_size: int)` emitted on add/remove/complete |
| Progress tracking | `get_train_progress()` returns 0.0-1.0 for current unit |
| Queue size | `get_queue_size()` returns current queue length |

This matches AoE2 behavior where you can shift-queue units and cancel from the end of the queue.

---

## Avoidance System Details

NavigationAgent2D avoidance added to all units:

| Property | Value | Purpose |
|----------|-------|---------|
| avoidance_enabled | true | Enable collision avoidance |
| radius | 12.0 | Unit's avoidance radius |
| neighbor_distance | 50.0 | Distance to detect nearby units |
| max_neighbors | 10 | Max units to consider for avoidance |
| max_speed | 100.0 | Used by avoidance calculations |

Movement pattern changed from direct velocity assignment to:
1. Call `_apply_movement(desired_velocity)`
2. If avoidance enabled, nav_agent computes safe velocity
3. `_on_velocity_computed(safe_velocity)` callback handles actual movement

---

## Deviations from Spec

| Spec Said | Implementation | Reason |
|-----------|----------------|--------|
| N/A | N/A | UX polish phase - no AoE2 spec deviations |

---

## Code Review Improvements Applied

| Issue | Fix |
|-------|-----|
| Dead code in TownCenter.cancel_training() | Removed redundant `elif training_queue.size() == 0` check |
| Duplicated `_load_static_sprite()` across units | Moved to base Unit class with optional scale parameter |
| Trade Cart not in gotchas.md | Added to Missing Sprites table |

---

## Known Issues

None. All tests pass (263/263).

---

## Test Coverage

### Manual Testing Performed
- [x] Enemy buildings show "(Enemy)" in info panel title
- [x] Unit HP updates in real-time in info panel
- [x] Units spread out rather than stacking on same position
- [x] Can queue multiple villagers at TC
- [x] Cancel button removes last queued and refunds resources
- [x] Queue label shows current queue size
- [x] All training buildings support queue (TC, Barracks, ArcheryRange, Stable, Market)
- [x] Game launches and runs without errors

### Automated Tests

**Updated tests:** 5 tests in `tests/scenarios/test_buildings.gd` renamed and updated to test queue behavior:
- `test_tc_can_queue_while_training` (was: test_tc_cannot_train_while_training)
- `test_archery_range_can_queue_while_training`
- `test_stable_can_queue_while_training`
- `test_archery_range_can_queue_skirmisher_while_training`
- `test_stable_can_queue_cavalry_archer_while_training`

**New tests:** 8 tests added for production queue system:
- `test_tc_queue_max_capacity` - Queue limited to 15 units
- `test_tc_cancel_training_refunds_resources` - Cancel returns food cost
- `test_tc_cancel_empty_queue_returns_false` - cancel_training() on empty queue
- `test_barracks_queue_mixed_unit_types` - Mixed militia and spearman in queue
- `test_stable_queue_max_capacity` - Stable queue also limited to 15
- `test_archery_range_cancel_refunds_correct_resources` - Correct refund per unit type
- `test_market_can_queue_trade_carts` - Market queue works
- `test_market_cancel_training_refunds_resources` - Market cancel refunds wood+gold

### Test Summary

- **Tests updated:** 5 (behavior changed from "cannot train" to "can queue")
- **Tests added:** 8 new queue tests
- **Test results:** 263 passed, 0 failed
- **Net improvement:** All tests passing

---

## Lessons Learned

(Added to docs/gotchas.md where applicable)

- NavigationAgent2D avoidance requires both scene properties (avoidance_enabled, radius, etc.) AND script changes (use `_apply_movement()` helper, connect `velocity_computed` signal)
- Production queue pattern: resources deducted on queue, refunded on cancel - this is the AoE2 model and prevents queue-and-cancel exploits
- Live UI updates via `_process()` work but could be throttled for performance if needed

---

## Context for Next Phase

Critical information for Phase 2.5B (or Phase 3):

- **Queue system**: All training buildings support 15-unit queues with consistent API
- **Avoidance**: Units use `_apply_movement()` for movement with avoidance support
- **Info panel**: `selected_info_entity` tracks currently displayed entity for live updates
- **Enemy label**: Buildings with `team != 0` show "(Enemy)" prefix

**Phase 2.5B will add:**
- More UX improvements as defined in roadmap

---

## Git Reference

- **Files changed:** 18 files
- **New patterns:** Production queue, avoidance movement helper
