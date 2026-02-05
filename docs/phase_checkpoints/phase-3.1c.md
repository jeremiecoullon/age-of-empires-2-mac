# Phase 3.1C Checkpoint: Full Military + Intelligence

**Date:** 2026-02-05
**Status:** Complete

---

## Summary

Extended the rule-based AI with full military production and tactical intelligence: archery range and stable building rules, training rules for all military unit types (archer, spearman, skirmisher, scout cavalry, cavalry archer), counter-unit logic (react to enemy army composition), scouting behavior, and defense rules.

---

## Context Friction

1. **Files re-read multiple times?** Yes - context compaction required re-reading CLAUDE.md and understanding current state
2. **Forgot earlier decisions?** No - checkpoint from 3.1B provided clear continuation guidance
3. **Uncertain patterns?** No - followed established rule structure from 3.1A/3.1B

---

## Implemented Features

| Feature | Files | Notes |
|---------|-------|-------|
| Enemy counting helpers | `scripts/ai/ai_game_state.gd:264-294` | Count enemy cavalry, archers, infantry for counter-unit logic |
| Scouting helpers | `scripts/ai/ai_game_state.gd:559-580` | `scout_to()` sends idle scout, `get_idle_scout()` finds available scout |
| Defense helpers | `scripts/ai/ai_game_state.gd:582-620` | `get_nearest_threat()`, `defend_against()` |
| BuildArcheryRangeRule | `scripts/ai/ai_rules.gd:458-480` | Build after barracks at 8+ villagers |
| BuildStableRule | `scripts/ai/ai_rules.gd:483-506` | Build after barracks at 10+ villagers |
| TrainArcherRule | `scripts/ai/ai_rules.gd:525-556` | Train archers, balance with infantry count |
| TrainSpearmanRule | `scripts/ai/ai_rules.gd:559-586` | Counter enemy cavalry |
| TrainSkirmisherRule | `scripts/ai/ai_rules.gd:618-647` | Counter enemy archers |
| TrainScoutCavalryRule | `scripts/ai/ai_rules.gd:650-680` | Ensure at least one scout exists |
| TrainCavalryArcherRule | `scripts/ai/ai_rules.gd:683-717` | Expensive mobile ranged unit |
| DefendBaseRule | `scripts/ai/ai_rules.gd:720-746` | Respond to threats near base |
| ScoutingRule | `scripts/ai/ai_rules.gd:749-798` | Send scouts to explore map positions |

---

## Deviations from Spec

| Spec Said | Implementation | Reason |
|-----------|----------------|--------|
| Scouting explores fog | Scouting uses hardcoded target positions | Fog-based exploration would require pathfinding through unknown areas - deferred |
| Counter-units reactive | AI only trains counters when enemies exist | Prevents premature unit composition without intel |

---

## Known Issues

| Issue | Severity | Notes |
|-------|----------|-------|
| Stable rarely built | Medium | AI often wood-constrained, "insufficient_wood" blocks stable. Known efficiency issue with high wood drop distances. |
| Scouting targets hardcoded | Low | Assumes fixed map layout (player base at 480,480, AI at 1700,1700) |

---

## Test Coverage

### Manual Testing Performed
- [x] AI builds archery range after barracks
- [x] AI trains archers
- [x] AI reaches 20 villagers target
- [x] Short test (300s) passes all checks
- [x] All 327 unit tests pass

### Automated Tests

**Existing coverage:** `tests/scenarios/test_ai_military.gd` (41 tests) already covered Phase 3.1C features comprehensively.

**New tests added:** `tests/scenarios/test_units.gd` (4 tests)

| Category | Tests | Description |
|----------|-------|-------------|
| Skirmisher stats | 1 | Correct HP, attack, armor per AoE2 spec |
| Skirmisher groups | 1 | In military, archers, skirmishers groups |
| Cavalry archer stats | 1 | Correct HP, attack, armor per AoE2 spec |
| Cavalry archer groups | 1 | In military, cavalry, archers, cavalry_archers groups |

All 327 tests pass (323 before + 4 new).

---

## AI Behavior Updates

**New military capabilities:**
- AI builds archery range after establishing barracks (8+ villagers)
- AI builds stable after archery range (10+ villagers, when wood available)
- AI trains archers, balancing ranged vs infantry count (floor of 3 to prevent deadlock)
- AI trains spearmen when detecting enemy cavalry
- AI trains skirmishers when detecting enemy archers
- AI ensures at least one scout cavalry exists
- AI trains cavalry archers as expensive late-game option

**Tactical intelligence:**
- Counter-unit production reacts to enemy army composition
- Defense rule responds when enemies are within 300px of any AI building
- Scouting sends idle scouts to explore predefined map positions (player base, corners)

---

## Lessons Learned

(Added to docs/gotchas.md)

- **Units must be in specific groups for AI counting**: Add units to their own groups (skirmishers, cavalry_archers) for AI counting
- **Avoid double-counting when iterating groups**: If units belong to multiple groups, track seen IDs or iterate only one
- **AI test timeout is mandatory**: Always use `timeout` with headless tests. Formula: `timeout_seconds = (duration / timescale) * 2`

---

## Code Review Issues Addressed

| Issue ID | Severity | Fix |
|----------|----------|-----|
| ISSUE-001 | High | Added `add_to_group("skirmishers")` to skirmisher.gd |
| ISSUE-002 | High | Added `add_to_group("cavalry_archers")` to cavalry_archer.gd |
| ISSUE-006 | Medium | Updated docstring for `get_enemy_archer_count()` |
| ISSUE-007 | Low | Removed redundant cavalry_archers iteration (double-counting fix) |

---

## Context for Next Phase

Phase 3.1 (Rule-Based AI) is now complete. The AI can:
- Build a complete economy (all drop-off buildings, farms)
- Produce varied military (infantry, archers, cavalry, counter-units)
- Scout the map and respond to threats

### Potential future improvements (not next phase):
- Fog-of-war-based scouting (currently hardcoded positions)
- More aggressive stable building (wood economy needs improvement)
- Attack timing refinement based on army strength
- Technology research rules

---

## Files Changed

**Modified:**
- `scripts/ai/ai_rules.gd` - Added 9 new rules (~300 lines added)
- `scripts/ai/ai_game_state.gd` - Added enemy counting, scouting, defense helpers (~100 lines added)
- `scripts/ai/ai_controller.gd` - Added skip reason helpers for new rules
- `scripts/units/skirmisher.gd` - Added skirmishers group membership
- `scripts/units/cavalry_archer.gd` - Added cavalry_archers group membership
- `docs/gotchas.md` - Added Phase 3.1C learnings
- `docs/ai_player_designs/ai_testing.md` - Added timeout guidance
- `.claude/agents/ai-observer.md` - Added timeout guidance

**New:**
- `docs/phase_checkpoints/phase-3.1c.md` - This checkpoint

---

## Git Reference

- **Primary changes:** Full military production and tactical AI rules
- **New patterns:** Counter-unit logic, scouting behavior, defense rules
- **Bug fixes:** Unit group membership for AI counting, double-counting in enemy archer count
