# Phase 5.0B Checkpoint: Unit Upgrade System + Knight

**Date:** 2026-02-07
**Status:** Complete

---

## Summary

Implemented the unit upgrade system (7 upgrades through Castle Age) and the Knight as a new Castle Age melee cavalry unit. Upgrades transform existing units in-place by overwriting stats, swapping Godot groups, and setting display names. The system reuses Phase 5A's generic research infrastructure in the Building base class. AI rules added for researching upgrades (prioritized by army composition) and training Knights. Full observability: skip reasons, milestones, game state snapshot expansion.

---

## Context Friction

1. **Files re-read multiple times?** Yes — context compaction occurred twice. Had to re-read game_manager.gd, unit.gd, hud.gd, ai_controller.gd, ai_rules.gd, ai_game_state.gd, stable.gd after each compaction. The plan file (`docs/plans/phase-5b-plan.md`) was critical as the compaction-resistant checklist.
2. **Forgot earlier decisions?** No — the 17-step plan was detailed enough. Each step had clear file targets and implementation details.
3. **Uncertain patterns?** The `set()` dynamic property access pattern was needed because the base Unit class can't directly reference subclass properties (`attack_damage`, `attack_range`, `bonus_vs_cavalry`, `bonus_vs_archers`). This caused a compile error on first attempt; fixed by using `unit.set(stat_key, value)` for dynamic access. Added to gotchas.md.

---

## Implemented Features

| Feature | Files | Notes |
|---------|-------|-------|
| 7 upgrade entries in TECHNOLOGIES | `scripts/game_manager.gd` | Man-at-Arms, Long Swordsman, Pikeman, Crossbowman, Elite Skirmisher, Heavy Cav Archer, Light Cavalry |
| `_apply_unit_upgrade()` | `scripts/game_manager.gd` | Transforms existing units: stats, groups, display name |
| `_apply_researched_upgrades()` | `scripts/units/unit.gd` | Auto-applies upgrades to newly spawned units, handles chains |
| `unit_display_name` property | `scripts/units/unit.gd` | Used by HUD to show upgraded unit names |
| "archers_line" group on Archer | `scripts/units/archer.gd` | Separates archers from skirmishers/cav archers for Crossbowman upgrade |
| Militia stats fix to AoE2 spec | `scripts/units/militia.gd` | 50HP/5atk → 40HP/4atk (prerequisite for Man-at-Arms chain) |
| Knight unit | `scripts/units/knight.gd`, `scenes/units/knight.tscn` | 100HP, 10atk, 2/2 armor, speed 140, melee cavalry |
| Knight SVG placeholder | `assets/sprites/units/knight.svg` | Mounted figure with shield |
| Knight training at Stable | `scripts/buildings/stable.gd` | 60F+75G, 6.0s train time |
| Research blocks training | `barracks.gd`, `archery_range.gd`, `stable.gd` | `is_researching` check in `_process()` |
| Building `_destroy()` cancels research | `barracks.gd`, `archery_range.gd`, `stable.gd` | Prevents orphaned research |
| Building `_complete_research()` resumes training | `barracks.gd`, `archery_range.gd`, `stable.gd` | Resumes queue after research done |
| Barracks upgrade buttons (3) | `scripts/ui/hud.gd`, `scenes/ui/hud.tscn` | Man-at-Arms, Long Swordsman, Pikeman |
| Archery Range upgrade buttons (3) | `scripts/ui/hud.gd`, `scenes/ui/hud.tscn` | Crossbowman, Elite Skirmisher, Heavy Cav Archer |
| Stable upgrade + Knight buttons | `scripts/ui/hud.gd`, `scenes/ui/hud.tscn` | Light Cavalry upgrade, Knight train |
| HUD display names for upgraded units | `scripts/ui/hud.gd` | Uses `unit_display_name` when set |
| AI: TrainKnightRule | `scripts/ai/ai_rules.gd` | Castle Age, stable, can afford, ≥3 military |
| AI: ResearchUnitUpgradeRule | `scripts/ai/ai_rules.gd` | Picks best upgrade by army composition |
| AI game state: knight training | `scripts/ai/ai_game_state.gd` | can_train, get_can_train_reason, _do_train |
| AI game state: training building research | `scripts/ai/ai_game_state.gd` | barracks/archery_range/stable research support |
| AI controller integration | `scripts/ai/ai_controller.gd` | Skip reasons, knight in military dict, research status |
| AI milestones | `scripts/testing/ai_test_analyzer.gd` | first_knight, first_unit_upgrade |
| Game state snapshot expansion | `scripts/logging/game_state_snapshot.gd` | All upgrade groups + knight in military classification |

---

## Deviations from Spec

| Spec Said | Implementation | Reason |
|-----------|----------------|--------|
| Imperial upgrades (Champion, Arbalester, etc.) | Deferred | Moved to Phase 9 per plan |
| Knight line upgrades (Cavalier, Paladin) | Deferred | Moved to Phase 9 per plan |
| Man-at-Arms bonus vs buildings | Not implemented | Building damage bonus system not yet built |

---

## Known Issues

| Issue | Severity | Notes |
|-------|----------|-------|
| Knight uses SVG placeholder | Low | Deferred to Phase 9 (Polish) |
| `get_unit_count("ranged")` may double-count cav archers | Low | Pre-existing, not worsened by Phase 5B |

---

## Bugs Fixed

1. **`set()` for dynamic property access** — `_apply_researched_upgrades()` in unit.gd originally referenced subclass properties directly (`attack_damage`, `attack_range`, etc.), causing compile errors. Fixed by using `set(stat_key, value)` for dynamic access. Same fix applied to `_apply_unit_upgrade()` in game_manager.gd.
2. **Militia test expected old stats** — `test_militia_initial_hp` expected 50 HP (MVP value) but militia was changed to 40 HP (AoE2 spec). Updated test.
3. **AI scouting breaks after Light Cavalry upgrade** — `scout_to()` and `get_idle_scout()` only checked "scout_cavalry" group. After upgrade, scouts move to "light_cavalry" group. Fixed both methods to check both groups.
4. **Long Swordsman group name mismatch** — Upgrade system used `to_group: "long_swordsman"` (singular) but snapshot checked `is_in_group("long_swordsmen")` (plural). Fixed `to_group` to `"long_swordsmen"` for consistency.
5. **`_do_train()` didn't capture return values** — Non-villager training methods set `success = true` before calling the train method, ignoring the actual return value. Fixed all cases to use `success = method_call()`.
6. **KNIGHT_SCENE used `load()` instead of `preload()`** — Changed to `const` with `preload()` now that the scene is imported.

---

## Code Review Fixes Applied

1. AI scouting after Light Cavalry upgrade: check both "scout_cavalry" and "light_cavalry" groups (HIGH)
2. Long Swordsman `to_group` singular→plural: `"long_swordsman"` → `"long_swordsmen"` (HIGH)
3. `_do_train()` return value capture for all non-villager training (HIGH)
4. KNIGHT_SCENE: `load()` → `preload()` as const (MEDIUM)

Issues assessed and skipped:
- Training building `_process()` is_destroyed guard (MEDIUM) — `_destroy()` calls `queue_free()`, at most 1 extra frame, not worth adding guards
- `get_unit_count("ranged")` double-counting (MEDIUM) — pre-existing, architectural, not worsened
- `_destroy()` training queue refund (MEDIUM) — AoE2 doesn't refund on destruction, correct behavior
- Knight copy-paste of Militia (MEDIUM) — acknowledged tech debt, deferred
- ResearchUnitUpgradeRule imprecise counts (LOW) — no functional bug

---

## Test Coverage

_To be filled after test-writer agent completes._

---

## AI Behavior Tests

_To be filled after AI observer agent completes._

---

## Spec Check Results

68/68 attributes match AoE2 specs. No mismatches found. Covers all 7 upgrades and Knight stats.

---

## Files Created

| File | Type |
|------|------|
| `scripts/units/knight.gd` | Unit script |
| `scenes/units/knight.tscn` | Unit scene |
| `assets/sprites/units/knight.svg` | SVG placeholder |
| `docs/plans/phase-5b-plan.md` | Plan file |

## Files Modified

| File | Changes |
|------|---------|
| `scripts/game_manager.gd` | 7 upgrade entries in TECHNOLOGIES, `_apply_unit_upgrade()`, knight age requirement, reset |
| `scripts/units/unit.gd` | `unit_display_name`, `_apply_researched_upgrades()` |
| `scripts/units/militia.gd` | Stats fix (40HP/4atk), `_apply_researched_upgrades()` call |
| `scripts/units/spearman.gd` | `_apply_researched_upgrades()` call |
| `scripts/units/archer.gd` | "archers_line" group, `_apply_researched_upgrades()` call |
| `scripts/units/skirmisher.gd` | `_apply_researched_upgrades()` call |
| `scripts/units/scout_cavalry.gd` | `_apply_researched_upgrades()` call |
| `scripts/units/cavalry_archer.gd` | `_apply_researched_upgrades()` call |
| `scripts/buildings/barracks.gd` | Research priority in `_process`, `_destroy` + `_complete_research` overrides |
| `scripts/buildings/archery_range.gd` | Same pattern |
| `scripts/buildings/stable.gd` | Same + Knight training (train_knight, KNIGHT constants) |
| `scripts/ui/hud.gd` | Upgrade buttons for 3 buildings, Knight button, display names, research progress |
| `scenes/ui/hud.tscn` | New upgrade + Knight buttons |
| `scripts/ai/ai_rules.gd` | TrainKnightRule, ResearchUnitUpgradeRule |
| `scripts/ai/ai_game_state.gd` | Knight training, upgrade research for training buildings, scouting fix |
| `scripts/ai/ai_controller.gd` | Register rules, skip reasons, AI_STATE updates |
| `scripts/testing/ai_test_analyzer.gd` | Knight + upgrade milestones |
| `scripts/logging/game_state_snapshot.gd` | Knight + upgrade groups in military snapshot |
| `tests/scenarios/test_units.gd` | Militia HP test fix (50→40) |
| `tests/helpers/test_spawner.gd` | `spawn_knight()` |
| `tests/test_main.gd` | Register new test suite |
| `docs/gotchas.md` | Phase 5B learnings, Knight in missing sprites |

---

## Next Phase

Phase 6: Formation and group movement (per roadmap.md).
