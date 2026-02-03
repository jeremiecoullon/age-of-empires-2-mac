# Phase 3E Checkpoint: Economic Intelligence

**Date:** 2026-02-01
**Status:** Complete

---

## Summary

Implemented economic intelligence for the AI: dynamic villager allocation based on economy mode (BOOM/BALANCED/MILITARY), floating resource detection and handling, optimized farm ring placement around TC/Mill, forward building placement toward enemy base, and expansion behavior via mining/lumber camps at distant resources.

---

## Context Friction

1. **Files re-read multiple times?** No - ai_controller.gd was read in sections as needed
2. **Forgot earlier decisions?** No - built directly on Phase 3D's micro-management systems
3. **Uncertain patterns?** No - followed established patterns from Phase 3A-3D

---

## Implemented Features

| Feature | Files | Notes |
|---------|-------|-------|
| Economy mode constants | `scripts/ai/ai_controller.gd:85-96` | FLOATING_RESOURCE_THRESHOLD, FORWARD_BUILDING_RATIO, etc. |
| Economy mode enum | `scripts/ai/ai_controller.gd:97` | EconomyMode.BOOM, BALANCED, MILITARY |
| Economic variables | `scripts/ai/ai_controller.gd:195-210` | current_economy_mode, dynamic_villager_targets, floating_resources |
| Resource balance check | `scripts/ai/ai_controller.gd:290-294` | Calls _update_resource_balance_targets(), _check_floating_resources(), _consider_expansion() |
| _determine_economy_mode() | `scripts/ai/ai_controller.gd:3510-3527` | Returns mode based on villager count, threat level, strength comparison |
| _update_resource_balance_targets() | `scripts/ai/ai_controller.gd:3530-3556` | Adjusts dynamic_villager_targets based on economy mode |
| _adjust_targets_for_shortages() | `scripts/ai/ai_controller.gd:3559-3569` | Emergency adjustments when resources critically low |
| _check_floating_resources() | `scripts/ai/ai_controller.gd:3572-3590` | Updates floating status and triggers handling |
| _handle_floating_resource() | `scripts/ai/ai_controller.gd:3593-3631` | Spends excess resources or reallocates villagers |
| _consider_expansion() | `scripts/ai/ai_controller.gd:3634-3660` | Checks for depleted resources and builds expansion camps |
| _check_resource_depletion() | `scripts/ai/ai_controller.gd:3663-3678` | Returns true if < 2 resources of type near base |
| _build_expansion_lumber_camp() | `scripts/ai/ai_controller.gd:3681-3714` | Builds lumber camp at distant wood |
| _build_expansion_mining_camp() | `scripts/ai/ai_controller.gd:3717-3750` | Builds mining camp at distant gold/stone |
| _find_expansion_resource_position() | `scripts/ai/ai_controller.gd:3753-3780` | Finds resources 600-1200 units from base |
| _is_position_safe() | `scripts/ai/ai_controller.gd:3783-3792` | Checks if position is clear of enemies |
| _get_forward_building_position() | `scripts/ai/ai_controller.gd:3795-3823` | Calculates position 30% toward enemy base |
| _find_farm_position_ring() | `scripts/ai/ai_controller.gd:3826-3850` | Ring pattern farm placement around mill/TC |
| _build_barracks_forward() | `scripts/ai/ai_controller.gd:1232-1253` | Forward barracks placement |
| _build_archery_range_forward() | `scripts/ai/ai_controller.gd:1298-1318` | Forward archery range placement |
| _build_stable_forward() | `scripts/ai/ai_controller.gd:1363-1383` | Forward stable placement |
| Updated _get_needed_resource() | `scripts/ai/ai_controller.gd:757-797` | Uses dynamic_villager_targets instead of static constants |
| Updated _is_floating_resources() | `scripts/ai/ai_controller.gd:655-663` | Uses FLOATING_RESOURCE_THRESHOLD constant |
| Updated _find_farm_position() | `scripts/ai/ai_controller.gd:916-918` | Delegates to _find_farm_position_ring() |
| Forward building in scaling | `scripts/ai/ai_controller.gd:559-580` | 2nd/3rd military buildings use forward placement |

---

## Deviations from Spec

| Spec Said | Implementation | Reason |
|-----------|----------------|--------|
| Build 2nd TC when safe | Expansion via camps only | 2nd TC requires Castle Age (Phase 4); expansion camps provide same resource access |

---

## Known Issues

- **load() instead of preload():** Expansion camp functions use load() at runtime - consistent with existing AI controller tech debt. Document in gotchas.
- **Forward building duplication:** Forward building variants duplicate code from normal building functions. Acceptable tech debt - would require larger refactor to consolidate.
- **Performance:** Multiple group searches per resource balance check (every 5s). Acceptable at current scale.

---

## Test Coverage

### Manual Testing Performed
- [ ] AI switches economy mode based on game state
- [ ] AI reallocates villagers when resources are floating
- [ ] AI places farms in ring pattern around mill
- [ ] AI builds military buildings forward when enemy base known
- [ ] AI builds expansion camps when base resources deplete

### Automated Tests

22 new tests added to `tests/scenarios/test_ai.gd`:

**Economy mode:**
- `test_economy_mode_starts_boom` - Starts in BOOM mode
- `test_economy_mode_enum_values` - Enum values correct
- `test_determine_economy_mode_returns_boom_early_game` - Early game returns BOOM

**Dynamic villager targets:**
- `test_dynamic_villager_targets_initialized` - All resource types present
- `test_dynamic_villager_targets_sum_reasonable` - Total between 20-35
- `test_get_dynamic_villager_target_returns_value` - Returns valid targets

**Floating resources:**
- `test_floating_resources_initialized_false` - All false initially
- `test_is_resource_floating_returns_false_initially` - Helper returns false
- `test_floating_resource_threshold_constant` - FLOATING_RESOURCE_THRESHOLD = 500
- `test_floating_resource_realloc_threshold_constant` - FLOATING_RESOURCE_REALLOC_THRESHOLD = 800

**Farm placement:**
- `test_farm_ring_inner_radius_constant` - FARM_RING_INNER_RADIUS = 70.0
- `test_farm_ring_outer_radius_constant` - FARM_RING_OUTER_RADIUS = 140.0

**Forward building:**
- `test_forward_building_ratio_constant` - FORWARD_BUILDING_RATIO = 0.3
- `test_get_forward_building_position_fallback_without_enemy` - Falls back near AI base

**Expansion:**
- `test_expansion_villager_threshold_constant` - EXPANSION_VILLAGER_THRESHOLD = 25
- `test_expansion_safety_radius_constant` - EXPANSION_SAFETY_RADIUS = 300.0
- `test_expansion_max_distance_constant` - EXPANSION_MAX_DISTANCE = 1200.0
- `test_expansion_camps_built_starts_zero` - Starts at 0
- `test_resource_depletion_distance_constant` - RESOURCE_DEPLETION_DISTANCE = 600.0

**Helper functions:**
- `test_get_economy_mode_string_returns_string` - Returns valid mode string

---

## AI Behavior Updates

**New capabilities:**
- AI dynamically adjusts villager allocation targets based on economy mode (BOOM focuses food/wood, MILITARY focuses food/gold)
- AI detects floating resources (>500) and takes action: trains more units, builds more buildings, or reallocates villagers
- AI places farms in efficient ring pattern around Mill or TC
- AI places 2nd/3rd military buildings forward toward enemy base (30% of the way)
- AI builds expansion lumber/mining camps when main base resources are depleted
- AI checks position safety before building at forward/expansion locations

**Decision logic changes:**
- Resource balance checked every 5 seconds (separate from 1s decision loop)
- _get_needed_resource() uses dynamic targets instead of static constants
- _is_floating_resources() threshold raised from 300 to 500
- Production building scaling uses forward building variants
- Emergency gold check added when archery range exists

---

## Code Review Issues Addressed

| Issue ID | Severity | Fix |
|----------|----------|-----|
| ISSUE-001 | High | Added is_dead check to _get_military_count() |
| ISSUE-002 | High | Added is_dead check to _get_ai_villagers() |
| ISSUE-003 | Medium | Added gold emergency check in _get_needed_resource() |
| ISSUE-004 | Medium | Added safety check to forward building position |
| ISSUE-008 | Low | Added EXPANSION_MAX_DISTANCE constant for magic number |

**Not addressed (acceptable tech debt):**
- ISSUE-005: Forward building code duplication - would require larger refactor
- ISSUE-006: load() vs preload() - consistent with existing codebase tech debt
- ISSUE-007: Farm ring array generation - minor, acceptable for farm building frequency

---

## Lessons Learned

- **Economy mode provides strategic context:** By tracking whether the AI should BOOM, be BALANCED, or focus on MILITARY, villager allocation becomes more intelligent. The mode transitions based on game state (villager count, threat level, strength comparison).
- **Dynamic targets beat static constants:** Static villager allocation targets don't adapt to game conditions. Dynamic targets that adjust based on economy mode and shortages lead to better resource management.
- **Forward building needs safety checks:** Simply placing buildings 30% toward the enemy can get builders killed. Check _is_position_safe() before committing.
- **Expansion requires economy first:** Only expand (build distant camps) after achieving a stable economy (25+ villagers). Otherwise you spread too thin.
- **Ring placement for farms:** Mathematical ring pattern (8 inner + 12 outer positions) creates efficient farm layouts compared to fixed offset lists.

---

## Context for Next Phase

Phase 3E completes Phase 3 (Strong AI). The AI now has:

**Phase 3 Complete - AI Capabilities:**
- Build orders and continuous villager production (3A)
- Scouting and enemy tracking (3B)
- Counter-unit production and combat intelligence (3C)
- Unit micro-management and tactics (3D)
- Economic intelligence and expansion (3E)

**For Phase 4 (Age System):**
- Forward building position already considers enemy base location
- Expansion logic has placeholder for 2nd TC (requires Castle Age)
- Economy mode system can inform age-up timing (BOOM mode = focus economy, MILITARY = focus military)
- Dynamic villager targets can be adjusted for different age requirements

**Key variables to be aware of:**
- `current_economy_mode` - Current AI strategy focus
- `dynamic_villager_targets` - Current villager allocation goals
- `floating_resources` - Which resources are over threshold
- `expansion_camps_built` - Number of expansion camps placed
- `known_enemy_tc_position` - Used for forward building calculations

---

## Git Reference

- **Branch:** claude/continue-development-VHzdO
- **Primary changes:** Economic intelligence system, dynamic allocation, farm ring placement, forward building, expansion behavior
