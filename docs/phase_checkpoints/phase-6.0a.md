# Phase 6.0A Checkpoint: Monastery + Monk + Healing + Conversion

**Date:** 2026-02-07
**Status:** Complete

---

## Summary

Implemented the Monastery building (Castle Age, 175W, 2100 HP), Monk unit (100G, 30 HP, slow speed), healing mechanic (1 HP/sec with accumulator), conversion mechanic (probability ramp: 0-4s=0%, 4-10s=~28%/sec, 10+=guaranteed), rejuvenation cooldown (62s), conversion immunity system, 7 monastery technologies, scout cavalry conversion resistance, basic AI rules (build monastery, train monks), and full HUD integration. Monks are support units — not in "military" group, use NO_ATTACK stance.

---

## Context Friction

1. **Files re-read multiple times?** Yes — this is a continuation from a previous context window that ran out of context. Had to re-read monk.gd, monastery.gd, hud.gd from the context summary. The plan file (`docs/plans/phase-6-plan.md`) survived as the compaction-resistant checklist.
2. **Forgot earlier decisions?** No — the detailed plan had clear file targets and implementation notes for each step.
3. **Uncertain patterns?** The healing HP accumulator pattern was initially wrong (using `ceil()` gave 1 HP/frame). Code review caught this. The accumulator pattern (track fractional, apply when >= 1.0) matches building repair.

---

## Implemented Features

| Feature | Files | Notes |
|---------|-------|-------|
| Monastery building | `scripts/buildings/monastery.gd`, `scenes/buildings/monastery.tscn` | 175W, 2100HP, 3x3, trains monks |
| Monastery sprite | `assets/sprites/buildings/monastery_aoe.png` | From AoE2 sprites, scale 0.5 |
| Monastery in build menu | `scripts/main.gd`, `scripts/ui/hud.gd`, `scenes/ui/hud.tscn` | BuildMonasteryButton, age-gated Castle |
| Monastery tech research | `scripts/ui/hud.gd` | Dynamic tech buttons, following Blacksmith pattern |
| Monk unit | `scripts/units/monk.gd`, `scenes/units/monk.tscn` | 30HP, 0atk, speed 70, NO_ATTACK stance |
| Monk sprite (8-dir) | `assets/sprites/units/monk_frames/` | 30 PNGs from AoE2 sprites |
| Healing mechanic | `scripts/units/monk.gd` | 1 HP/sec via accumulator, auto-scan 0.5s, heal range 128px |
| Conversion mechanic | `scripts/units/monk.gd` | Probability ramp, 288px range, team change, rejuvenation |
| Conversion immunity | `scripts/units/monk.gd` `can_convert()` | TC/Castle/Monastery/Farm/walls/gates/wonders/fish traps immune |
| Monk→building conversion | `scripts/units/monk.gd` | Requires Redemption tech (checked in `can_convert()`) |
| Monk→monk conversion | `scripts/units/monk.gd` | Requires Atonement tech (checked in `can_convert()`) |
| Pop-capped conversion | `scripts/units/monk.gd` | Unit dies if converting team is pop-capped (AoE2 behavior) |
| Scout cavalry resistance | `scripts/units/scout_cavalry.gd` | `conversion_resistance = 0.5` halves conversion chance |
| 7 monastery technologies | `scripts/game_manager.gd` | Fervor, Sanctity, Redemption, Atonement, Illumination, Faith, Block Printing |
| Monk tech bonuses | `scripts/units/monk.gd` `apply_tech_bonuses()` | Speed, HP, range, rejuvenation, immunity checks |
| Right-click monk commands | `scripts/main.gd` `_issue_command()` | Monk+enemy=convert, monk+friendly wounded=heal |
| HUD monk info | `scripts/ui/hud.gd` | HP, conversion range, status text |
| HUD monastery panel | `scripts/ui/hud.gd` | Train monk, tech buttons, research progress, cancel |
| AI: BuildMonasteryRule | `scripts/ai/ai_rules.gd` | Castle Age, 15+ vills, no existing monastery |
| AI: TrainMonkRule | `scripts/ai/ai_rules.gd` | Has monastery, 100G, monks < 3 |
| AI game state | `scripts/ai/ai_game_state.gd` | Monastery/monk counts, training, research support |
| AI controller | `scripts/ai/ai_controller.gd` | Skip reasons, debug state, research tracking |
| GameManager registration | `scripts/game_manager.gd` | Age requirements, qualifying groups |

---

## Deviations from Spec

| Spec Said | Implementation | Reason |
|-----------|----------------|--------|
| Relics spawn on map | Deferred to Phase 6B | Per sub-phase plan |
| Relic garrisoning + gold gen | Deferred to Phase 6B | Per sub-phase plan |
| Relic victory condition | Deferred to Phase 6B | Per sub-phase plan |
| AI collects relics, converts targets | Basic AI only (build/train) | Full AI deferred to 6B |
| AI researches monastery techs | Not yet | ResearchMonasteryTechRule in 6B |
| Imperial techs unresearchable | Defined but age-locked | Correct — Imperial Age not implemented |

---

## Known Issues

| Issue | Severity | Notes |
|-------|----------|-------|
| Building conversion doesn't handle training queue/pop cap | Low | Redemption requires explicit tech; deferred to 6B |
| Building deselection on conversion not handled | Low | Same deferral as above |
| AI doesn't use monks for conversion or healing | Low | Phase 6B adds ConvertHighValueRule and CollectRelicsRule |
| No ResearchMonasteryTechRule | Low | Planned for Phase 6B |
| Conversion resistance only on Units, not Buildings | Low | Buildings convert same speed as units; minor AoE2 deviation |

---

## Bugs Fixed

1. **Healing 60x too fast** — `ceil(heal_rate * delta)` at 60fps gives 1 HP/frame (60 HP/sec). Fixed with float accumulator: track fractional HP, apply integer portion when >= 1.0.
2. **avoidance_enabled=true in monk.tscn** — Known pitfall (see gotchas.md). Changed to false to match all other units.
3. **`_store_base_stats()` in conversion** — Calling this before `apply_tech_bonuses()` stores boosted values as base, causing stat drift. Removed the call.
4. **Illumination precision** — Changed `* 0.67` to `/ 1.5` for exact 50% faster rejuvenation.
5. **`load()` → `preload()`** — Monastery and monk scenes switched to preload after import confirmed.
6. **Missing `is_destroyed`/`is_constructed` guards** — Added to monastery `_process()`.

---

## Code Review Fixes Applied

1. Monk scene `avoidance_enabled = true` → `false` (CRITICAL)
2. Monastery `load()` → `preload()` for MONK_SCENE (HIGH)
3. Monastery `_process()` missing `is_destroyed`/`is_constructed` guards (HIGH)
4. Healing HP calculation: 1 HP/frame bug → accumulator pattern (HIGH)
5. Conversion `_store_base_stats()` stat drift → removed call (HIGH)
6. AI `load()` → `preload()` for MONASTERY_SCENE (MEDIUM)
7. Illumination `* 0.67` → `/ 1.5` (spec-check finding)

Issues assessed and deferred:
- Building conversion state (training queue, pop cap, deselection) — Redemption not practically usable yet
- Monks not in military group for AI attacks — correct design, 6B adds monk AI behavior
- No ResearchMonasteryTechRule — planned for 6B
- Building conversion resistance — minor AoE2 deviation, deferred
- Auto-heal O(n) scan — throttled at 0.5s, acceptable

---

## Spec Check Results

**Monk:** 22/22 matches. One cosmetic precision fix applied (Illumination `/ 1.5`).

**Monastery:** 28/28 matches. All tech costs, ages, and effects correct.

---

## Test Coverage

41 automated tests in `tests/scenarios/test_monastery.gd`:

| Area | Tests | Key Cases |
|------|-------|-----------|
| Monk stats | 6 | HP (30), armor (0/0), speed (70), NO_ATTACK stance, "monks" group, NOT "military" group |
| Monastery stats | 3 | HP (2100), wood_cost (175), "monasteries" group |
| Monk training | 5 | Gold deduction (100G), insufficient gold rejection, pop cap rejection, cancel refund, queue behavior |
| Conversion immunity | 8 | Enemy unit (yes), same team (no), building without redemption (no), building with redemption (yes), TC/monastery/farm immune even with redemption, monk without/with atonement |
| Conversion commands | 3 | Sets CONVERTING state, blocked by rejuvenation, blocked by immunity |
| Healing commands | 3 | Sets HEALING state, rejects enemy targets, rejects dead targets |
| Healing accumulator | 1 | Verifies healing doesn't apply instantly (accumulator pattern) |
| Tech bonuses | 4 | Sanctity (+15 HP→45), Fervor (+15% speed→80.5), Illumination (rejuvenation/1.5), Block Printing (+96 range→384) |
| Scout resistance | 1 | conversion_resistance = 0.5 |
| Rejuvenation | 2 | Starts after conversion completes, timer expires correctly |
| Monastery behavior | 2 | Research blocks training, destroyed blocks training |
| Status text | 2 | "Idle" in idle state, "Rejuvenating" when rejuvenating |

All 563 tests pass (522 pre-existing + 41 new).

---

## AI Behavior Tests

**Test run:** FAIL — economy-constrained, not Phase 6A bug.

AI barely reached Feudal Age at 546s (target ~150s), never reached Castle Age. Population stalled at 10-11 villagers (need 15 for Castle Age). Neither monastery nor monks were built/trained because the AI never progressed far enough. Same pre-existing economy issue as Phase 5A/5B.

**Phase 6A infrastructure verified working:**
- BuildMonasteryRule: registered, firing in 114 RULE_TICK entries, skip reasons accurate (`need_15_villagers_have_X`)
- TrainMonkRule: registered, firing, skip reasons accurate (`no_monastery`)
- AI_STATE: monk/monastery counts present, no crashes
- Milestones: `first_monastery` and `first_monk` defined and tracked (not hit)

**Assessment:** Infrastructure correct and will engage once AI economy improves. Same bottleneck as Phase 5.

---

## Files Created

| File | Type |
|------|------|
| `scripts/buildings/monastery.gd` | Building script |
| `scenes/buildings/monastery.tscn` | Building scene |
| `assets/sprites/buildings/monastery_aoe.png` | Building sprite |
| `scripts/units/monk.gd` | Unit script |
| `scenes/units/monk.tscn` | Unit scene |
| `assets/sprites/units/monk_frames/` | Unit sprite frames (30 PNGs) |
| `docs/plans/phase-6-plan.md` | Plan file |

## Files Modified

| File | Changes |
|------|---------|
| `scripts/game_manager.gd` | Age requirements, qualifying groups, 7 monastery technologies |
| `scripts/main.gd` | MONASTERY_SCENE, BuildingType.MONASTERY, placement, monk commands in `_issue_command()` |
| `scripts/ui/hud.gd` | BuildMonasteryButton, TrainMonkButton, monastery panel, monk info, tech buttons |
| `scenes/ui/hud.tscn` | New buttons and signal connections |
| `scripts/units/scout_cavalry.gd` | `conversion_resistance = 0.5` |
| `scripts/ai/ai_rules.gd` | BuildMonasteryRule, TrainMonkRule |
| `scripts/ai/ai_game_state.gd` | Monastery/monk support: scenes, costs, training, research |
| `scripts/ai/ai_controller.gd` | Skip reasons, debug state, research tracking |
| `docs/gotchas.md` | Phase 6A learnings |
| `docs/roadmap.md` | Sub-phase breakdown |

---

## Next Phase

Phase 6B: Relics + Relic Victory + Monk Technologies (full AI) + Observability.
