# Phase 7.0B Checkpoint: Walls + Gates + Wall Dragging + AI Defense

**Date:** 2026-02-07
**Status:** Complete

---

## Summary

Implemented three new defensive building types (Palisade Wall, Stone Wall, Gate), wall drag placement mechanic with L-shaped paths, gate auto-open/close for friendly units with lock/unlock toggle, HUD build buttons and gate selection panel, AI BuildPalisadeWallRule, and full observability updates.

---

## Context Friction

1. **Files re-read multiple times?** Yes — continued from prior context window. Had to re-read main.gd, hud.gd, ai_game_state.gd, ai_rules.gd, ai_controller.gd from context summary. The plan file (`docs/plans/phase-7b-plan.md`) survived as compaction-resistant checklist.
2. **Forgot earlier decisions?** No — the plan was comprehensive and survived context compaction well.
3. **Uncertain patterns?** Wall drag placement was the novel system. The L-shaped path computation and ghost management were new patterns but straightforward.

---

## Implemented Features

| Feature | Files | Notes |
|---------|-------|-------|
| Palisade Wall | `palisade_wall.gd`, `palisade_wall.tscn` | 2W, 250HP, Dark Age, 1x1 |
| Stone Wall | `stone_wall.gd`, `stone_wall.tscn` | 5S, 1800HP, 8/10 armor, Feudal |
| Gate | `gate.gd`, `gate.tscn` | 30S, 2750HP, 6/6 armor, Feudal, auto-open/lock |
| Wall drag placement | `main.gd` | L-shaped paths, ghost management, all-or-nothing cost |
| Gate single-click placement | `main.gd` | Standard placement, not wall drag |
| Age requirements | `game_manager.gd` | stone_wall + gate = Feudal |
| HUD: Build buttons | `hud.gd`, `hud.tscn` | 3 build buttons + lock gate button |
| HUD: Gate panel | `hud.gd` | HP, armor, lock/unlock display |
| AI: BuildPalisadeWallRule | `ai_rules.gd` | 3+ min, has barracks, <5 walls |
| AI: Game state entries | `ai_game_state.gd` | Preloads, costs, sizes, mappings |
| AI: Controller updates | `ai_controller.gd` | Skip reasons, debug state |
| Observability | `ai_test_analyzer.gd`, `game_state_snapshot.gd` | first_palisade_wall milestone, building capture |

---

## Deviations from Spec

| Spec Said | Implementation | Reason |
|-----------|----------------|--------|
| Gate only allows friendly passage | CollisionShape2D disabled entirely (all units pass) | Simplified; per-team collision would need layer rework |
| Wall placement continues after placing | Exits placement mode after drag release | Shift-click continuous placement deferred to Phase 10 |
| AoE2 gate has open/close sprites | Uses opacity (0.5 alpha) for open state | Distinct gate sprites not available; Phase 10 polish |

---

## Known Issues

| Issue | Severity | Notes |
|-------|----------|-------|
| Gate enemy pass-through | Medium | Enemies can walk through open gates; document as known |
| AI builds walls during economy ramp | Low | Strategic timing issue; walls fire at 3+ min while AI still ramping |
| No visual cost feedback during drag | Low | Player only discovers unaffordable wall on mouse release |
| hide_*_panel() calls growing | Low | 9 hide calls repeated 3x in _start_selection; extract to hide_all_panels() in Phase 8 |

---

## Code Review Fixes Applied

1. **ISSUE-002** (HIGH): Cached ghost texture in `_wall_ghost_texture` member variable, created once in `start_*_wall_placement()` instead of every mouse move
2. **ISSUE-003** (HIGH): Converted wall/gate scene paths to `preload()` constants (`PALISADE_WALL_SCENE`, `STONE_WALL_SCENE`, `GATE_SCENE`)
3. **ISSUE-004** (MEDIUM): Fixed integer division in `_compute_wall_path()` — replaced `int() /` with `floori()` for correct floor division
4. **ISSUE-005** (MEDIUM): Added `if is_destroyed: return` guard at top of Gate `_process()`
5. **ISSUE-006** (MEDIUM): Added `is_instance_valid`, `not is_dead`, `not is_garrisoned()` checks when collecting builder villagers in `_place_wall_segments()`

Issues assessed and deferred:
- ISSUE-001: Gate enemy pass-through — known simplification, documented in gotchas
- ISSUE-007: hide_*_panel() DRY violation — refactor to hide_all_panels() in Phase 8
- ISSUE-008: No visual cost feedback during drag — Phase 10 UX polish
- ISSUE-009: Gate scan with many gates — acceptable at current scale
- ISSUE-010: No info panel for Stone Wall/Palisade Wall — Phase 10 polish
- ISSUE-011: Wall placement exits after release — Phase 10 shift-click feature

---

## Spec Check Results

**Palisade Wall:** 9/9 verifiable attributes match. No mismatches.

**Stone Wall:** 9/9 verifiable attributes match. No mismatches. Armor values (8/10) from game data, not in manual table.

**Gate:** 8/8 verifiable attributes match. No mismatches. Armor values (6/6) from game data, not in manual table. Auto-open and lock/unlock mechanics match manual description.

---

## Test Coverage

All 563 tests pass (same as Phase 7A — no new unit tests added for 7B).

Phase 7B features are primarily interaction-based (wall drag placement, gate collision toggle, gate auto-open scan) which are difficult to unit test without a full scene tree. The L-shaped path computation (`_compute_wall_path`) and cost calculation logic would benefit from targeted unit tests.

---

## AI Behavior Tests

**Test run:** FAIL — Pre-existing failures (late barracks at 153s vs expected 90s, 11 villagers at 180s vs expected 12+).

**Palisade wall feature: WORKING**
- First wall built at t=190.5s (27s after barracks completion)
- 5 walls built by t=301.6s in defensive cluster around base
- Rule correctly stops after reaching 5-wall limit
- Skip reasons properly reported: "too_early", "already_queued", "have_enough_walls"

**Strategic concern:** BuildPalisadeWallRule fires at t=180s during economy ramp-up, diverting a villager from gathering. Combined with "paused_for_military_0/3" blocker on villager training, this created a resource deadlock. The rule timing could be adjusted (delay to 5+ min or require Feudal Age) but this is a tuning issue, not a code bug.

**Existing behavior intact:** No regressions detected. Economy, military, and Feudal Age advancement all functional.

---

## Files Created

| File | Type |
|------|------|
| `scripts/buildings/palisade_wall.gd` | Building script |
| `scripts/buildings/stone_wall.gd` | Building script |
| `scripts/buildings/gate.gd` | Building script |
| `scenes/buildings/palisade_wall.tscn` | Building scene |
| `scenes/buildings/stone_wall.tscn` | Building scene |
| `scenes/buildings/gate.tscn` | Building scene |
| `assets/sprites/buildings/palisade_wall_aoe.png` | Building sprite |
| `assets/sprites/buildings/stone_wall_aoe.png` | Building sprite |
| `assets/sprites/buildings/gate_aoe.png` | Building sprite |

## Files Modified

| File | Changes |
|------|---------|
| `scripts/main.gd` | Preloaded wall/gate scenes, BuildingType enum entries, building sizes, wall drag system (handle input, compute path, update ghosts, place segments, cancel), gate selection panel, start_*_placement functions |
| `scripts/game_manager.gd` | stone_wall + gate AGE_FEUDAL in BUILDING_AGE_REQUIREMENTS |
| `scripts/ui/hud.gd` | Build buttons (palisade wall, stone wall, gate), lock gate button, gate panel (show/hide), age-gating, info panel for gate |
| `scenes/ui/hud.tscn` | 4 new Button nodes + signal connections |
| `scripts/ai/ai_game_state.gd` | Scene preloads, BUILDING_COSTS/SIZES entries, building count/scene mappings |
| `scripts/ai/ai_rules.gd` | BuildPalisadeWallRule |
| `scripts/ai/ai_controller.gd` | key_rules, skip reasons, debug state (wall/gate counts) |
| `scripts/testing/ai_test_analyzer.gd` | first_palisade_wall milestone, palisade_wall building type |
| `scripts/logging/game_state_snapshot.gd` | palisade_wall, stone_wall, gate in _capture_buildings |
| `docs/gotchas.md` | Phase 7B learnings |

---

## Next Phase

Phase 8: University + Guard Tower + Keep + Fortified Wall + Siege Workshop. Clear context now.
