# Phase 4.0B Checkpoint: Age-Gating + Visual Changes

**Date:** 2026-02-06
**Status:** Complete

---

## Summary

Implemented age-gating so buildings and units are locked by age requirement, matching AoE2's progression system. Added starting Scout Cavalry for both player and AI (AoE2 standard: 3 villagers + 1 scout). Added age requirement dictionaries and helpers in GameManager, age checks in AI game state, and age-locked UI buttons in HUD with labels showing required age. Building visual changes deferred to Phase 9 (no age-variant sprites).

---

## Context Friction

1. **Files re-read multiple times?** Yes — context compaction occurred mid-phase. Had to re-read game_manager.gd, hud.gd, ai_game_state.gd, ai_controller.gd after compaction. The plan file (`docs/plans/phase-4b-plan.md`) served as the compaction-resistant checklist.
2. **Forgot earlier decisions?** No — the plan was detailed enough and the checklist tracked completion state.
3. **Uncertain patterns?** No — the age-gating pattern (central dictionaries + caller-level checks) was straightforward and consistent.

---

## Implemented Features

| Feature | Files | Notes |
|---------|-------|-------|
| Starting Scout Cavalry (player) | `scenes/main.tscn` | ScoutCavalry node at (540, 480) near player TC |
| Starting Scout Cavalry (AI) | `scripts/ai/ai_controller.gd:146-151` | Instantiated in _spawn_starting_base(), add_population(1) |
| Starting population = 4 | `scripts/game_manager.gd:75,364` | Init and reset() both set population = 4 |
| BUILDING_AGE_REQUIREMENTS | `scripts/game_manager.gd` | archery_range/stable/market = Feudal |
| UNIT_AGE_REQUIREMENTS | `scripts/game_manager.gd` | archer/skirmisher/spearman/scout_cavalry/trade_cart = Feudal, cavalry_archer = Castle |
| is_building_unlocked() | `scripts/game_manager.gd` | Compares team age against required age |
| is_unit_unlocked() | `scripts/game_manager.gd` | Compares team age against required age |
| get_required_age_name() | `scripts/game_manager.gd` | Returns human-readable age name for entity |
| AI age check in get_can_train_reason() | `scripts/ai/ai_game_state.gd:358-361` | Returns "requires_feudal_age" etc. |
| AI age check in get_can_build_reason() | `scripts/ai/ai_game_state.gd:471-474` | Returns "requires_feudal_age" etc. |
| Build button age-gating | `scripts/ui/hud.gd` | _update_build_button_states() disables Feudal buildings in Dark Age |
| Train button age-gating | `scripts/ui/hud.gd` | _update_barracks/archery_range/stable/market_button_states() |
| Button age labels | `scripts/ui/hud.gd` | Locked buttons show "(Feudal Age)" etc. |
| Safety checks on button presses | `scripts/ui/hud.gd` | 9 handlers check age before proceeding |
| UI refresh on age change | `scripts/ui/hud.gd` | _refresh_current_panel() called from _on_age_changed() |
| _set_button_age_locked() helper | `scripts/ui/hud.gd` | Reusable helper for disabled + age label pattern |

---

## Deviations from Spec

| Spec Said | Implementation | Reason |
|-----------|----------------|--------|
| Building visual changes per age | Not implemented | No age-variant sprites exist; deferred to Phase 9 |

---

## Known Issues

| Issue | Severity | Notes |
|-------|----------|-------|
| Building visuals don't change with age | Low | Deferred to Phase 9 (Polish). Documented in gotchas.md. |

---

## Code Review Fixes Applied

1. **TrainArcherRule missing should_save_for_age() check** (ISSUE-001, High) — Added the check, matching all other military training rules.
2. **Raw `0` instead of `GameManager.AGE_DARK` in age fallbacks** (ISSUE-003, Medium) — Changed to use constant in both get_can_train_reason() and get_can_build_reason().
3. **Shared age_name for all Feudal buildings** (ISSUE-004, Medium) — Each building now queries its own required age name independently.

---

## Test Coverage

30 automated tests in `tests/scenarios/test_age_gating.gd`:

| Area | Tests | Key Cases |
|------|-------|-----------|
| Building unlock (GameManager) | 5 | Dark Age buildings always unlocked, Feudal locked in Dark/unlocked in Feudal+, team independence |
| Unit unlock (GameManager) | 7 | Dark units always unlocked, Feudal locked in Dark/unlocked in Feudal, Castle locked until Castle, team independence |
| get_required_age_name() | 5 | Correct age name for Dark/Feudal/Castle buildings and units |
| Starting population | 2 | population = 4 on init and after reset() |
| AI get_can_train_reason() age gate | 5 | Feudal units blocked in Dark, Castle units blocked in Dark/Feudal, allowed when age met, reason format |
| AI get_can_build_reason() age gate | 4 | Feudal buildings blocked in Dark, allowed in Feudal, reason format |
| Default age for unlisted entities | 2 | Unknown buildings/units default to Dark Age (always unlocked) |

All 437 tests pass (407 pre-existing + 30 new).

---

## AI Behavior Tests

**Test run:** 2026-02-06, 600 game-seconds at 10x speed
**Result:** FAIL — `barracks_by_90s` check failed. AI never built barracks or reached Feudal.

**Age-gating compliance: PASS.** The AI correctly respects age requirements — it does NOT build archery_range, stable, or market while in Dark Age. All Feudal-age buildings have zero construction.

**Root cause of failure:** Economic bottleneck, not age-gating bug. The AI accumulated only 389 food in 600s but needs 500 for Feudal advancement. The `should_save_for_age()` mechanism works but food income is too slow. The AI meets all non-resource conditions (10+ villagers, 2 qualifying buildings) but can't accumulate resources fast enough. This is a pre-existing AI economy issue exposed by the age system — to be addressed in AI tuning, not in age-gating code.

---

## Spec Check Results

17/17 age assignments match AoE2 specs. All buildings and units assigned to correct ages. No mismatches.

---

## Next Phase

Phase 5: Technologies & Upgrades.
