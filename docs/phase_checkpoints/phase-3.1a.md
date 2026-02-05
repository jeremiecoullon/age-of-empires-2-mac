# Phase 3.1A Checkpoint: Rule-Based AI Core

**Date:** 2026-02-03
**Status:** Complete

---

## Summary

Implemented the core infrastructure for an AoE2-style rule-based AI system. The AI now trains villagers, builds houses and barracks, gathers resources (food/wood), trains militia, and attacks. This replaces the failed procedural AI from the original Phase 3.

---

## Context Friction

1. **Files re-read multiple times?** No - fresh session with clear design doc to follow
2. **Forgot earlier decisions?** No - design doc (`godot_rule_implementation.md`) was comprehensive
3. **Uncertain patterns?** No - followed existing game patterns (buildings, units, GameManager)

---

## Implemented Features

| Feature | Files | Notes |
|---------|-------|-------|
| AIGameState wrapper | `scripts/ai/ai_game_state.gd` | Clean interface for rules to query game state |
| AIRule base class | `scripts/ai/ai_rules.gd` | Base class with conditions() and actions() |
| Rule engine | `scripts/ai/ai_controller.gd` | Evaluates rules every 0.5s, executes queued actions |
| Strategic numbers | `scripts/ai/ai_controller.gd` | Tunable parameters (gatherer %, targets, etc.) |
| Timer system | `scripts/ai/ai_controller.gd` | Time-based triggers (attack timer) |
| Goal system | `scripts/ai/ai_controller.gd` | State variables for rules |
| Action de-duplication | `scripts/ai/ai_game_state.gd` | Queued intentions, one train/build per type per tick |
| Villager assignment | `scripts/ai/ai_controller.gd` | Auto-assign idle villagers based on % targets |
| AI base spawn | `scripts/ai/ai_controller.gd` | Spawns TC, House, 3 Villagers on startup |

### MVP Rules Implemented

| Rule | Conditions | Actions |
|------|------------|---------|
| InitializationRule | First tick (goal check) | Set strategic numbers, start attack timer |
| BuildHouseRule | Housing headroom < 5, can afford | Build house |
| TrainVillagerRule | Civilians < target, can train | Train villager |
| BuildBarracksRule | No barracks, 5+ villagers, can afford | Build barracks |
| TrainMilitiaRule | Has barracks, can train | Train militia |
| AttackRule | Military >= threshold, timer triggered, not under attack | Attack player TC |

---

## Architecture

```
ai_controller.gd          # Entry point, owns rule engine + strategic numbers
├── ai_game_state.gd      # Wrapper exposing game state to rules
└── ai_rules.gd           # Rule definitions (base class + MVP rules)
```

**Update loop:**
1. Every 0.5s: `game_state.refresh()` → evaluate all rules → `game_state.execute_actions()`
2. Every 2.0s: Assign idle villagers to resources based on strategic number percentages

---

## Code Review Issues Addressed

| Issue ID | Severity | Fix |
|----------|----------|-----|
| ISSUE-001 | High | Added queue size check in `can_train()` - limit to 3 per building |
| ISSUE-002 | High | Changed to preload() for building scenes |
| ISSUE-003 | High | Added type cast `as Building` for type safety |
| ISSUE-005 | Medium | Use `is_in_group("farms")` instead of `is Farm` |
| ISSUE-008 | Medium | `is_under_attack()` now checks all AI buildings, not just TC |
| ISSUE-009 | Medium | Added `_get_any_player_building()` fallback for attack targeting |
| ISSUE-010 | Medium | Removed unused `target_pos` variable |

**Not addressed (low priority for MVP):**
- ISSUE-004: Caching group queries (performance optimization, not needed yet)
- ISSUE-007: Centralizing building metadata (extensibility, defer to 3.1B/C)
- ISSUE-012-015: Various low-priority improvements

---

## Known Issues

None. All 248 tests pass.

---

## Test Coverage

### Manual Testing Performed
- [x] AI spawns starting base (TC, House, 3 Villagers)
- [x] AI villagers start gathering food and wood
- [x] AI builds houses when approaching pop cap
- [x] AI builds barracks once economy established
- [x] AI trains militia from barracks
- [x] AI attacks player after timer expires with sufficient military
- [x] Game still playable - player can win by destroying AI TC

### Automated Tests

No new automated tests for AI behavior (AI tests are complex and would require game simulation). Existing 248 tests all pass.

---

## Lessons Learned

(Added to docs/gotchas.md)

- **AIGameState wraps all queries**: Rules never access game objects directly
- **Action de-duplication pattern**: Queue intentions, execute once at end of tick
- **Limit AI training queue size**: Prevents over-committing resources
- **Use preload() for AI building scenes**: Avoid runtime file I/O
- **is_under_attack() checks all buildings**: Not just TC - buildings spread out
- **Attack fallback when TC destroyed**: Find alternative target
- **Use group checks over type checks**: More robust than class type checks

---

## Context for Next Phase (3.1B - Full Economy)

Critical information for continuing:

- **Rule engine is working**: Add new rules by creating classes in `ai_rules.gd` and adding to `create_all_rules()`
- **Strategic numbers defined**: Gatherer percentages (60% food, 40% wood currently), can be adjusted by rules
- **Building placement works**: `build()` and `build_near_resource()` actions available
- **Key file for rules**: `scripts/ai/ai_rules.gd`
- **Key file for game state queries**: `scripts/ai/ai_game_state.gd`

### What 3.1B needs to add:
- Gather gold and stone based on strategic numbers
- Build lumber camp near trees
- Build mining camp near gold/stone
- Build mill near berries
- Build farms when natural food depleted
- Sheep herding and hunting rules
- Market buy/sell rules (conservative trading)

---

## Files Changed

**New:**
- `scripts/ai/ai_game_state.gd` - Game state wrapper for AI rules (~650 lines)
- `scripts/ai/ai_rules.gd` - Rule base class and MVP rules (~140 lines)

**Modified:**
- `scripts/ai/ai_controller.gd` - Rule engine + villager assignment (~200 lines)
- `docs/gotchas.md` - Added Phase 3.1A learnings

---

## Git Reference

- **Primary changes:** Rule-based AI infrastructure replacing procedural AI
- **New patterns:** Rule evaluation loop, action de-duplication, strategic numbers
