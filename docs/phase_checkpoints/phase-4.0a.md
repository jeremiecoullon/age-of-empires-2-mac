# Phase 4.0A Checkpoint: Age Infrastructure & Advancement

**Date:** 2026-02-06
**Status:** Complete

---

## Summary

Implemented the age advancement system: age state tracking in GameManager (Dark/Feudal/Castle/Imperial), age research mechanic at Town Center with timer and resource costs, qualifying building requirements (2 different building types per age), HUD integration (Advance Age button, progress display, age label, notifications), and AI advancement rules.

---

## Context Friction

1. **Files re-read multiple times?** Yes - context compaction occurred mid-phase. Had to re-read game_manager.gd, town_center.gd, hud.gd, ai_game_state.gd, ai_rules.gd, ai_controller.gd, ai_test_analyzer.gd after compaction.
2. **Forgot earlier decisions?** No - the plan was detailed enough that continuation was straightforward after compaction.
3. **Uncertain patterns?** No - the existing patterns (production queue, resource spending, AI rule structure) were well-established from prior phases.

---

## Implemented Features

| Feature | Files | Notes |
|---------|-------|-------|
| Age constants & costs | `scripts/game_manager.gd:9-37` | AGE_DARK through AGE_IMPERIAL, costs, research times, qualifying groups |
| Per-team age state | `scripts/game_manager.gd:42-43` | player_age, ai_age with age_changed signal |
| Age helpers | `scripts/game_manager.gd:210-267` | get_age, set_age, can_advance_age, get_qualifying_building_count, can_afford_age, spend/refund |
| Qualifying building count (distinct types) | `scripts/game_manager.gd:232-244` | Counts distinct groups with functional buildings, not total buildings |
| Age research system | `scripts/buildings/town_center.gd:162-216` | Timer-based research, blocks training, cancel with refund |
| TC destruction refund | `scripts/buildings/town_center.gd:40-41` | cancel_age_research() called in _destroy() |
| TC is_destroyed guard | `scripts/buildings/town_center.gd:52-53` | Prevents post-destruction processing |
| Advance Age button | `scenes/ui/hud.tscn`, `scripts/ui/hud.gd:834-886` | Button in TC panel, validation with error messages |
| Age label updates | `scripts/ui/hud.gd:887-898` | Top bar label updates on age change signal |
| Age research progress | `scripts/ui/hud.gd:175-184` | Reuses train_progress bar for age research |
| AI age helpers | `scripts/ai/ai_game_state.gd:92-110` | get_age, can_advance_age, qualifying count, research_age |
| AI resource saving | `scripts/ai/ai_game_state.gd:103-125` | should_save_for_age() pauses military training to accumulate food |
| AI training rules save check | `scripts/ai/ai_rules.gd` | Militia, spearman, skirmisher, scout cavalry, cavalry archer pause during saving |
| AI can_train research check | `scripts/ai/ai_game_state.gd:344-345` | tc_researching_age skip reason |
| AI _do_train return value | `scripts/ai/ai_game_state.gd:713` | success = tc.train_villager() instead of unconditional true |
| AdvanceToFeudalAgeRule | `scripts/ai/ai_rules.gd:622-642` | Dark Age, 10+ vills, 2 qualifying, 500F |
| AdvanceToCastleAgeRule | `scripts/ai/ai_rules.gd:645-666` | Feudal Age, 15+ vills, 2 qualifying, 800F+200G |
| AI skip reasons for age rules | `scripts/ai/ai_controller.gd:309-334` | Includes already_researching check |
| AI_STATE age logging | `scripts/ai/ai_controller.gd:632-633` | Age and age name in debug state |
| Age milestones | `scripts/testing/ai_test_analyzer.gd` | reached_feudal_age, reached_castle_age |
| Age info in test summary | `scripts/testing/ai_test_analyzer.gd` | final_state includes current_age, researching_age, research_progress |
| Debug logging in tests | `scripts/testing/ai_solo_test.gd:51` | debug_print_enabled = true for diagnostic logs |
| Roadmap sub-phase split | `docs/roadmap.md` | 4A/4B breakdown persisted |

---

## Deviations from Spec

| Spec Said | Implementation | Reason |
|-----------|----------------|--------|
| Dock qualifies for Feudal | Dock not in qualifying groups | Dock not yet implemented |
| Blacksmith qualifies for Castle | Blacksmith not in qualifying groups | Blacksmith not yet implemented |
| Imperial needs Castle/University/etc. | Imperial qualifying groups empty | Castle Age buildings not yet implemented |
| Castle counts as 2 for Imperial | Not implemented | Castle building not yet implemented |

---

## Known Issues

| Issue | Severity | Notes |
|-------|----------|-------|
| Imperial qualifying groups placeholder | Low | Empty array with comment. Will be filled when Castle Age buildings are implemented in future phases. |

---

## Test Coverage

41 automated tests in `tests/scenarios/test_age_advancement.gd`:

| Area | Tests | Key Cases |
|------|-------|-----------|
| Age state management | 6 | Start at Dark, set/get per team, reset, signal emission |
| Age advancement prerequisites | 4 | Can't skip ages, need buildings, need resources, all met |
| Qualifying building counting | 6 | Distinct types (2 barracks = 1), functional only, own team only, all groups |
| Cost management | 6 | Can/can't afford, spend deducts, spend fails safely, refund, invalid ages |
| TC age research lifecycle | 10 | Start/cancel/complete, blocks training, progress, signals, destruction refund |
| AI rule conditions | 7 | Feudal rule fires/blocks, Castle rule fires/blocks, can_train blocked during research |

All 407 tests pass (363 pre-existing + 41 new + 3 from framework changes).

---

## AI Behavior Tests

**Test run:** 2026-02-06, 600 game-seconds at 10x speed
**Result:** PASS — AI reaches Feudal Age at ~478s

The AI builds qualifying buildings (barracks, lumber_camp by ~60s), reaches 10 villagers by ~99s, then pauses military training to save food via `should_save_for_age()`. Food accumulates at ~2 food/sec (villager training continues for more gatherers). Research starts at ~340s when 500 food is reached. Feudal Age completed at ~478s. All 8 checks pass.

**Resource saving strategy:** Military training rules check `should_save_for_age()` and pause when all non-resource conditions are met. Villager training continues (more villagers = more food income = faster saving). Saving is skipped if under attack (survival first).

---

## Spec Check Results

Costs, research times, and mechanics all match AoE2 spec. Three missing qualifying building types (Dock, Blacksmith, Imperial buildings) are deferred because those buildings don't exist yet. The "distinct types" requirement was initially wrong (counted total buildings) and was fixed during spec-check.

---

## Code Review Fixes Applied

1. AI `can_train('villager')` now checks `tc.is_researching_age` (ISSUE-001)
2. TC `_destroy()` cancels age research with refund (ISSUE-003)
3. AI `_do_train('villager')` captures return value (ISSUE-005)
4. TC `_process()` has `is_destroyed` early return guard (ISSUE-007)
5. AI skip reasons include 'already_researching' for age rules (ISSUE-008)

---

## Next Phase

Phase 4B: Age-gating (lock buildings/units by age), UI for locked content, building visual changes.
