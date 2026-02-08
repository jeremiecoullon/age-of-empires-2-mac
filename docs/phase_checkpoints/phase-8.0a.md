# Phase 8.0A Checkpoint: University + Building Upgrades + University Techs + AI

**Date:** 2026-02-07
**Status:** Complete

---

## Summary

Implemented the University building (Castle Age, research-only), building upgrade system (in-place stat transformation mirroring unit upgrades), 6 University technologies (Masonry, Murder Holes, Treadmill Crane, Ballistics, Guard Tower, Fortified Wall), building tech bonus system, HUD `hide_all_panels()` refactor, AI rules, and full observability updates.

---

## Context Friction

1. **Files re-read multiple times?** Yes — continued from prior context window across two sessions. Had to re-read game_manager.gd, building.gd, hud.gd, main.gd, ai_game_state.gd, ai_controller.gd, ai_rules.gd. The plan file (`docs/plans/phase-8-plan.md`) survived as compaction-resistant checklist.
2. **Forgot earlier decisions?** No — Steps 2-3 (University building + TECHNOLOGIES entries) were completed in the prior session and carried forward correctly via context summary.
3. **Uncertain patterns?** Building upgrade system was new. Had to ensure two upgrade paths (runtime via GameManager and spawn-time via building._ready()) maintained the same invariants. Code review caught a base-stat drift bug between them.

---

## Implemented Features

| Feature | Files | Notes |
|---------|-------|-------|
| HUD `hide_all_panels()` refactor | `hud.gd`, `main.gd` | Replaced 9+ repeated hide calls in 3 places |
| University building | `university.gd`, `university.tscn` | 200W, 2100HP, Castle Age, 3x3, research-only |
| University techs (TECHNOLOGIES) | `game_manager.gd` | 4 techs + 2 building upgrades |
| Building upgrade system | `game_manager.gd` | `_apply_building_upgrade()` with HP delta, base stat updates |
| Building tech bonus system | `building.gd` | Base stats + Masonry HP%/armor/LOS bonuses |
| Murder Holes integration | `watch_tower.gd` | Skip min range check when tech researched |
| Treadmill Crane integration | `building.gd` | +20% build speed multiplier in `progress_construction()` |
| Guard Tower upgrade | `game_manager.gd`, `watch_tower.gd` | HP 1020->1500, attack 5->6, pierce_armor 7->9 |
| Fortified Wall upgrade | `game_manager.gd` | HP 1800->3000, armor 8/10->12/12 |
| University HUD panel | `hud.gd`, `hud.tscn` | 6 tech buttons, research progress, cancel |
| University placement | `main.gd` | BuildingType.UNIVERSITY, click handling |
| AI: BuildUniversityRule | `ai_rules.gd` | Castle Age, 15+ vills, queue timeout pattern |
| AI: ResearchUniversityTechRule | `ai_rules.gd` | Priority-based tech selection |
| AI game state | `ai_game_state.gd` | Preloads, costs, sizes, building mappings |
| AI controller | `ai_controller.gd` | Skip reasons, key_rules, debug state |
| Observability | `ai_test_analyzer.gd`, `game_state_snapshot.gd` | first_university milestone, building count |

---

## Deviations from Spec

| Spec Said | Implementation | Reason |
|-----------|----------------|--------|
| Ballistics improves projectile tracking | No-op (effect key stored but unused) | No projectile system yet; hitscan combat |
| Masonry +3 LOS (per AoE2 wiki) | Applied as +96px sight_range | Manual doesn't give exact number; wiki value used |
| Treadmill Crane cost 200W 300S (manual) | 200W 300S | Initially implemented as 200W 300F; fixed in code review |

---

## Known Issues

| Issue | Severity | Notes |
|-------|----------|-------|
| AI can't reach Castle Age in 600s test | Pre-existing | Economy/barracks timing issue from Phase 7B blocks University testing |
| HUD tower info doesn't show tech range bonuses | Low | Shows base range; effective attack shown correctly after ISSUE-002 fix |
| main.gd uses load() not preload() for university | Low | Pre-existing tech debt across all buildings in main.gd |

---

## Code Review Fixes Applied

1. **ISSUE-001** (HIGH): `_apply_building_upgrade()` now updates `_base_max_hp`, `_base_melee_armor`, `_base_pierce_armor` and calls `apply_building_tech_bonuses()` after upgrade — prevents stat drift with Masonry
2. **ISSUE-002** (HIGH): Changed `TOWER_BASE_ATTACK` from const to var `tower_base_attack`, added `tower_base_attack: 6` to Guard Tower new_stats — tower attack now correctly increases on upgrade
3. **ISSUE-003** (MEDIUM): Added `building_los` application in `apply_building_tech_bonuses()` — Masonry now correctly adds +96px sight range via `_base_sight_range`
4. **ISSUE-004** (MEDIUM): Fixed Treadmill Crane cost from `{wood: 200, food: 300}` to `{wood: 200, stone: 300}` per AoE2 manual
5. **ISSUE-005** (MEDIUM): Moved property assignments before `super._ready()` in university.gd, watch_tower.gd, and stone_wall.gd — ensures base stats are stored correctly

Issues assessed and deferred:
- ISSUE-006: `load()` vs `preload()` for university in main.gd — pre-existing tech debt across all buildings
- ISSUE-007: Merged into ISSUE-002 fix (HUD now shows actual tower attack)
- ISSUE-008: Private method access pattern for `_get_ai_university()` — pre-existing convention used by all similar rules

---

## Spec Check Results

**University:** All verifiable attributes match (200W cost, 2100HP, Castle Age, no attack, no garrison).

**Guard Tower upgrade:** Stats match after ISSUE-002 fix: 1500HP, 6 attack, pierce_armor 9.

**Fortified Wall upgrade:** Stats match: 3000HP, 12/12 armor. Research costs (200F, 100S) are plan values; manual doesn't list separate upgrade research costs.

**Treadmill Crane:** Cost corrected to 200W, 300S per manual. +20% build speed matches spec.

---

## Test Coverage

All 600 tests pass (563 pre-existing + 37 new).

**New tests** (`tests/test_phase_8a.gd` — 37 tests):

| Area | Tests | What's covered |
|------|-------|----------------|
| University tech entries | 6 | Costs, ages, effects for all 6 University techs |
| Guard Tower upgrade | 8 | HP delta, attack increase, stats, group swap, display name, base stats update |
| Fortified Wall upgrade | 5 | Stats, group swap, display name, base stats update |
| New building spawns upgraded | 1 | Building placed after upgrade auto-applies upgraded stats |
| Building upgrade team isolation | 1 | Upgrade only affects correct team |
| Masonry bonuses | 10 | HP%, armor, LOS, different buildings, idempotent, HP scaling |
| Masonry + Guard Tower stacking | 1 | Both bonuses apply correctly together |
| Murder Holes | 2 | Min range removal on tower targeting |
| Treadmill Crane | 2 | Construction speed multiplier |
| Guard Tower on damaged tower | 1 | HP delta applied to damaged tower correctly |

---

## AI Behavior Tests

**Test run:** FAIL — Pre-existing failures (late barracks at ~350s vs expected 90s).

**University feature: COULD NOT VALIDATE** — AI never reached Castle Age in 600s test window due to pre-existing economy bottleneck.

**Code inspection confirms:**
- `BuildUniversityRule` correctly registered with skip reason `"need_15_villagers_have_X"`
- `ResearchUniversityTechRule` correctly registered with skip reason `"no_university"`
- `first_university` milestone tracked in ai_test_analyzer.gd
- University building count tracked in game_state_snapshot.gd

**Not a Phase 8A regression** — the economy timing issue dates to Phase 7B and predates all University changes. Once the barracks timing is fixed, the University AI will be testable.
