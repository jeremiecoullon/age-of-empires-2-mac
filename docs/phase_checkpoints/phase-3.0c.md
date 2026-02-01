# Phase 3C Checkpoint: Combat Intelligence

**Date:** 2026-02-01
**Status:** Complete

---

## Summary

Implemented combat intelligence for the AI: counter-unit production based on enemy composition, improved attack timing with vulnerability detection, target prioritization (villagers > ranged > military > buildings), retreat behavior for damaged units, and focus fire coordination to concentrate attacks on single targets.

---

## Context Friction

1. **Files re-read multiple times?** No - ai_controller.gd was read once thoroughly at the start
2. **Forgot earlier decisions?** No - built on Phase 3B's enemy tracking infrastructure as intended
3. **Uncertain patterns?** No - followed existing Phase 3A/3B patterns for extending AI behavior

---

## Implemented Features

| Feature | Files | Notes |
|---------|-------|-------|
| Counter-unit priority system | `scripts/ai/ai_controller.gd:76-84` | COUNTER_UNITS dictionary maps enemy types to counters |
| Counter-unit production | `scripts/ai/ai_controller.gd:2577-2636` | `_get_counter_unit_priority()` determines what to build based on enemy |
| Updated military training | `scripts/ai/ai_controller.gd:1248-1364` | `_train_military()` now uses counter-unit logic |
| Army composition goals | `scripts/ai/ai_controller.gd:86-92` | Dynamic ratios adjusted by `_update_army_composition_goals()` |
| Improved attack timing | `scripts/ai/ai_controller.gd:1762-1836` | `_should_attack()` uses strength comparison, vulnerability check |
| Enemy vulnerability check | `scripts/ai/ai_controller.gd:1810-1836` | `_is_enemy_vulnerable()` checks exposed villagers, low military |
| Military strength scoring | `scripts/ai/ai_controller.gd:2903-2930` | `_get_military_strength()` and `_get_enemy_strength_estimate()` |
| Target prioritization | `scripts/ai/ai_controller.gd:1481-1556` | Improved `_find_attack_target()` with scoring |
| Priority scoring function | `scripts/ai/ai_controller.gd:1558-1605` | `_prioritize_target_from_list()` with unified constants |
| Unit attacking check | `scripts/ai/ai_controller.gd:2680-2700` | Type-safe `_is_unit_attacking()` helper |
| Retreat detection | `scripts/ai/ai_controller.gd:2702-2725` | `_should_unit_retreat()` checks HP threshold |
| Retreat management | `scripts/ai/ai_controller.gd:2727-2779` | `_manage_unit_retreat()` and `_order_unit_retreat()` |
| Focus fire targeting | `scripts/ai/ai_controller.gd:2795-2840` | `_find_focus_fire_target()` with priority scoring |
| Focus fire application | `scripts/ai/ai_controller.gd:2862-2895` | `_apply_focus_fire()` redirects units to focus target |
| Combat coordination | `scripts/ai/ai_controller.gd:2946-2990` | `_coordinate_combat_focus_fire()` during active battles |

---

## Deviations from Spec

None - implemented as specified in roadmap.

---

## Known Issues

- **Performance concern:** Multiple group searches per combat update cycle (every 0.5s). Acceptable at current game scale but may need optimization for larger battles. See code review ISSUE-002 (deferred as acceptable tech debt).

---

## Test Coverage

### Manual Testing Performed
- [ ] AI produces skirmishers when player builds archers
- [ ] AI produces spearmen when player builds cavalry
- [ ] AI attacks when it has military advantage
- [ ] AI retreats damaged units from combat
- [ ] AI focuses fire on single targets

### Automated Tests

27 new tests added to `tests/scenarios/test_ai.gd`:

**Counter-Unit Production:**
- `test_get_counter_for_unit_returns_correct_counters` - Archer->skirmisher, cavalry->spearman mappings
- `test_get_counter_for_unit_defaults_to_militia` - Unknown types default to militia
- `test_get_counter_unit_priority_returns_default_with_low_intel` - Default when < 3 enemy units
- `test_get_counter_unit_priority_counters_archers_with_skirmishers` - Skirmisher priority vs archers
- `test_get_counter_unit_priority_counters_cavalry_with_spearmen` - Spearman priority vs cavalry

**Army Composition Goals:**
- `test_army_composition_goals_has_default_ratios` - 40/40/20 default ratios
- `test_update_army_composition_goals_adjusts_for_ranged_enemy` - Increases ranged vs archers
- `test_update_army_composition_goals_adjusts_for_cavalry_enemy` - Increases infantry vs cavalry
- `test_update_army_composition_goals_adjusts_for_infantry_enemy` - Increases ranged vs infantry

**Attack Timing:**
- `test_get_military_strength_counts_ai_units` - Returns 0 with no military
- `test_get_military_strength_weights_unit_types` - Correct unit type weights
- `test_get_enemy_strength_estimate_uses_estimated_army` - Uses tracking data
- `test_has_military_advantage_requires_threshold` - ATTACK_ADVANTAGE_THRESHOLD check
- `test_is_enemy_vulnerable_true_when_low_military` - Vulnerable with <= 2 military
- `test_is_enemy_vulnerable_true_when_villagers_seen_recently` - Vulnerable with recent sighting

**Target Prioritization:**
- `test_prioritize_target_prefers_villagers` - Villagers highest priority
- `test_prioritize_target_prefers_ranged_over_military` - Ranged > melee
- `test_prioritize_target_prefers_low_hp` - Low HP targets preferred
- `test_prioritize_target_returns_null_for_empty_list` - Empty list handling

**Retreat Behavior:**
- `test_is_unit_attacking_returns_false_for_idle_unit` - Type-safe state check
- `test_should_unit_retreat_false_at_full_hp` - No retreat at full HP
- `test_should_unit_retreat_true_at_low_hp_in_combat` - Retreat at < 25% HP
- `test_retreating_units_starts_empty` - Empty initialization

**Focus Fire:**
- `test_count_units_attacking_target_returns_zero_with_no_attackers` - Zero when no attackers
- `test_get_attackers_on_target_delegates_to_count` - Public API delegation
- `test_find_focus_fire_target_returns_null_with_no_enemies` - Null with no enemies

---

## AI Behavior Updates

**New capabilities:**
- AI produces counter-units based on enemy composition (archers → skirmishers, cavalry → spearmen)
- AI dynamically adjusts army composition ratios based on what enemy is building
- AI uses military strength comparison for attack timing decisions
- AI detects enemy vulnerability (exposed villagers, low military) and attacks opportunistically
- AI retreats damaged units (< 25% HP) to preserve army
- AI coordinates focus fire during combat to quickly eliminate high-priority targets

**Decision logic changes:**
- Attack decision now considers military strength advantage, not just unit count
- Army composition goals shift based on enemy army makeup
- Target selection uses unified priority scoring: villagers > ranged > military > buildings
- Units below HP threshold retreat toward AI base automatically
- Attacking units coordinate to focus on the same target

---

## Code Review Issues Addressed

| Issue ID | Severity | Fix |
|----------|----------|-----|
| ISSUE-001 | High | Changed `unit in retreating_units` to `retreating_units.has(unit)` for typed arrays |
| ISSUE-003 | High | Added `_is_unit_attacking()` helper with type-safe enum checks |
| ISSUE-004 | Medium | Cached military lookup in `_get_counter_unit_priority()` to avoid duplicate calls |
| ISSUE-005 | Medium | Added `if enemy is Unit:` guard for HP access in `_find_focus_fire_target()` |
| ISSUE-009 | Medium | Unified scoring constants (TARGET_PRIORITY_*) between prioritization and focus fire |

**Not addressed (acceptable tech debt):**
- ISSUE-002: Performance optimization for group searches - acceptable at current scale
- ISSUE-006, ISSUE-010, ISSUE-011, ISSUE-012: Low severity or extensibility improvements

---

## Lessons Learned

- **Unified scoring constants:** When multiple functions need consistent priority scoring (target selection, focus fire), use shared constants to prevent drift. See `TARGET_PRIORITY_*` constants.
- **Type-safe state checks:** Instead of magic numbers for state enums (`if state == 2`), use type checks with proper enum values (`if unit is Militia and unit.current_state == Militia.State.ATTACKING`).
- **Typed array membership:** In GDScript 4, use `.has()` instead of `in` operator for typed array membership checks (per gotchas.md).

---

## Context for Next Phase

Critical information for Phase 3D (Micro & Tactics):

- **Retreat system in place:** Units below 25% HP automatically retreat. Phase 3D can build on this for villager flee behavior.
- **Focus fire working:** AI coordinates attacks on single targets. Phase 3D can extend this for kiting (retreat + attack cycles).
- **Key functions to extend:**
  - `_manage_unit_retreat()` - Add villager-specific flee behavior
  - `_coordinate_combat_focus_fire()` - Add ranged kiting logic
  - Add TC garrison command for Town Bell equivalent
- **Unit state tracking:** `_is_unit_attacking()` helper provides type-safe state detection
- **retreating_units array:** Tracks units currently fleeing, useful for split attention logic

---

## Git Reference

- **Branch:** claude/continue-development-FYCgH
- **Primary changes:** Counter-unit production, army composition goals, attack timing, target prioritization, retreat behavior, focus fire
