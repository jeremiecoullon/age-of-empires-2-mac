# Phase 3B Checkpoint: Scouting & Information

**Date:** 2026-02-01
**Status:** Complete

---

## Summary

Implemented the scouting and information gathering system for AI. The AI now uses scout cavalry to explore the map, tracks enemy base and building locations, estimates enemy army composition, and uses threat assessment to scale defense responses appropriately.

---

## Context Friction

1. **Files re-read multiple times?** No - ai_controller.gd was read once thoroughly at the start
2. **Forgot earlier decisions?** No - scout state machine design was consistent throughout
3. **Uncertain patterns?** No - followed existing Phase 3A patterns for extending AI behavior

---

## Implemented Features

| Feature | Files | Notes |
|---------|-------|-------|
| Scout state machine | `scripts/ai/ai_controller.gd:84-117` | ScoutState enum with IDLE, CIRCLING_BASE, EXPANDING, SEARCHING_ENEMY, RETURNING, COMBAT states |
| Scout patrol patterns | `scripts/ai/ai_controller.gd:1806-1944` | Circle base → expand outward → search for enemy; configurable radius |
| Scout assignment | `scripts/ai/ai_controller.gd:1783-1810` | Auto-assign first available scout cavalry; prioritize idle but accept moving scouts |
| Scout combat detection | `scripts/ai/ai_controller.gd:1763-1773` | Detects when scout is fighting or damaged, triggers flee behavior |
| Enemy base tracking | `scripts/ai/ai_controller.gd:2013-2050` | Records enemy TC position and all seen enemy buildings |
| Building type identification | `scripts/ai/ai_controller.gd:2052-2071` | Type-safe building identification instead of get_class() |
| Known buildings cleanup | `scripts/ai/ai_controller.gd:2076-2102` | Removes stale building entries after 60 seconds if position is visible and empty |
| Enemy army estimation | `scripts/ai/ai_controller.gd:2108-2167` | Counts visible enemy units by type |
| Threat assessment | `scripts/ai/ai_controller.gd:2202-2250` | Three-tier system (MINOR/MODERATE/MAJOR) based on enemy presence |
| Improved defense response | `scripts/ai/ai_controller.gd:1601-1649` | Defense scales with threat level, prioritizes targets |
| Improved attack targeting | `scripts/ai/ai_controller.gd:1357-1419` | Uses scouted enemy location for better targeting |
| Scout training priority | `scripts/ai/ai_controller.gd:1268-1282` | AI prioritizes getting one scout early for scouting |

---

## Deviations from Spec

None - implemented as specified in roadmap.

---

## Known Issues

- **Performance concern:** Multiple group searches per scout update cycle (every 0.5s). Acceptable at current game scale but may need optimization for larger battles. See code review ISSUE-001, ISSUE-004.
- **Scout patrol near map edges:** When AI base is near corner (1700,1700), patrol waypoints may clamp to similar positions. Functional but not ideal coverage.

---

## Test Coverage

### Manual Testing Performed
- [x] Scout is assigned when stable trains first scout cavalry
- [x] Scout patrols around base in expanding circles
- [x] Scout finds and records enemy base position
- [x] Scout flees when damaged
- [x] AI uses scouted enemy location for attack targeting
- [x] Threat assessment triggers appropriate defense response
- [x] Enemy army composition tracking updates during combat

### Automated Tests

12 new tests added to `tests/scenarios/test_ai.gd`:

**Scouting system tests:**
- `test_scout_state_starts_idle` - Initial scout state
- `test_scout_found_enemy_base_initially_false` - Enemy base flag initialization
- `test_has_scouted_enemy_base_returns_false_initially` - Scouting status helper
- `test_get_enemy_base_position_returns_default_when_not_scouted` - Default enemy position fallback

**Enemy tracking tests:**
- `test_estimated_enemy_army_starts_zero` - Army estimation initialization
- `test_get_enemy_dominant_unit_type_defaults_to_militia` - Dominant unit type helper
- `test_known_enemy_buildings_starts_empty` - Building tracking initialization

**Threat assessment tests:**
- `test_threat_level_starts_zero` - Threat level initialization
- `test_get_threat_level_returns_current_value` - Threat level getter
- `test_enemy_has_more_returns_false_when_equal` - Comparative check (equal)
- `test_enemy_has_more_returns_true_when_enemy_has_more` - Comparative check (enemy advantage)
- `test_building_type_string_returns_correct_types` - Building type identification

---

## AI Behavior Updates

**New capabilities:**
- AI scout cavalry explores map systematically instead of sitting idle until attack
- AI remembers enemy base location and uses it for attack targeting
- AI tracks enemy army composition (foundation for Phase 3C counter-play)
- AI defense response scales with threat severity

**Decision logic changes:**
- Attack decision considers whether enemy base has been scouted
- Attack requires larger army if enemy base not yet found
- Attack uses numerical advantage check based on enemy army estimates
- Defense sends proportional forces: 2 units for minor threat, 5 for moderate, all for major

---

## Code Review Issues Addressed

| Issue ID | Severity | Fix |
|----------|----------|-----|
| ISSUE-002 | High | Added combat detection for scout - checks ATTACKING state and HP |
| ISSUE-003 | High | Added _cleanup_known_buildings() to remove stale entries |
| ISSUE-005 | Medium | Replaced hardcoded team == 0 with PLAYER_TEAM constant |
| ISSUE-006 | Medium | Added _get_building_type_string() instead of unreliable get_class() |
| ISSUE-007 | Medium | Scout assignment now accepts non-idle scouts as fallback |
| ISSUE-010 | Medium | Changed threat_units to typed Array[Node2D] |
| ISSUE-011 | Medium | Clear dictionary values instead of recreating dict |

**Not addressed (acceptable tech debt):**
- ISSUE-001, ISSUE-004: Performance optimizations for group searches - acceptable at current scale
- ISSUE-009: load() vs preload() - existing tech debt, not made worse
- ISSUE-012, ISSUE-013, ISSUE-014: Low severity edge cases

---

## Lessons Learned

(Added to docs/gotchas.md would be appropriate, but content below is the key learnings)

- **Scout state machine integration:** When adding states like COMBAT, remember to add transitions INTO that state, not just the handler. Easy to define a state but never enter it.
- **Building type identification:** GDScript's `get_class()` can be unreliable - use explicit `is` checks or a custom method for type identification.
- **Dictionary clearing:** When resetting a tracking dictionary, clear values instead of reassigning. Reassignment breaks external references.
- **Typed arrays for consistency:** Use `Array[Node2D]` for entity lists to match existing codebase patterns and improve type safety.

---

## Context for Next Phase

Critical information for Phase 3C (Combat Intelligence):

- **Enemy tracking is in place:** `estimated_enemy_army` dictionary tracks enemy unit counts by type
- **get_enemy_dominant_unit_type():** Returns most common enemy unit type for counter-play
- **enemy_has_more(unit_type):** Checks if enemy has numerical advantage in specific unit type
- **Key functions to use:**
  - Use enemy tracking to produce counter-units
  - Use threat assessment for attack timing decisions
  - Use `get_enemy_base_position()` for coordinated attacks
- **Scouting provides intel:** Scout should continue running during Phase 3C to provide updated intel
- **Scout is excluded from attack:** Scout unit is not sent with attack waves to preserve scouting

---

## Git Reference

- **Branch:** claude/continue-development-GmgKa
- **Primary changes:** Scouting system, enemy tracking, threat assessment, defense improvements
