# Farm preference bug (RESOLVED)

**Date:** 2026-02-04
**Status:** Fixed

---

## Problem

Villagers were gathering from distant berries/carcasses (800-1400px from drop-off) instead of using nearby farms.

## Root Cause

Farms were not added to the `food_resources` group. The `assign_villager_to_resource()` function searches for food in the `food_resources` group, but farms only added themselves to `farms` and `resources` groups.

**The bug was in `scripts/buildings/farm.gd`:**
```gdscript
func _ready() -> void:
    super._ready()
    add_to_group("farms")
    add_to_group("resources")  # Missing: add_to_group("food_resources")
```

## Fix

Added `add_to_group("food_resources")` to `scripts/buildings/farm.gd:_ready()`.

## Verification

Before fix:
- `avg_food_drop_dist: 800-1400+` px
- `nearest_farm: false` in all FARM_DEBUG logs

After fix:
- `avg_food_drop_dist: 87-177` px (after mill built)
- `nearest_farm: true` once farms are built
- Villagers correctly assigned to farms

## Files Changed

- `scripts/buildings/farm.gd` — Added `food_resources` group

## Tests

All 282 tests pass.

---

## Previous Investigation (for reference)

### What was tried before finding root cause

1. **HuntRule distance check** — WORKING. Added `MAX_HUNT_DISTANCE = 200px` so hunt rule doesn't fire when animals are far.

2. **Farm preference logic in assign_villager_to_resource** — Logic was correct but never triggered because farms weren't found.

### Debug approach that found the bug

Added `FARM_DEBUG` logging to `assign_villager_to_resource()` which revealed `nearest_farm: false` even after farms were built, indicating farms weren't in the `food_resources` group.
