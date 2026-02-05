# Phase 3A Checkpoint: Macro & Build Orders

**Date:** 2026-02-01
**Status:** Complete

---

## Summary

Implemented the first sub-phase of Strong AI: Macro & Build Orders. The AI now follows a structured build order during early game, maintains continuous villager production, scales production buildings when floating resources, and immediately reassigns idle villagers.

---

## Context Friction

1. **Files re-read multiple times?** No - ai_controller.gd read once thoroughly
2. **Forgot earlier decisions?** No - build order design was consistent throughout
3. **Uncertain patterns?** Slightly - the pending villager assignment tracking needed refinement after code review caught edge cases

---

## Implemented Features

| Feature | Files | Notes |
|---------|-------|-------|
| Build order system | `scripts/ai/build_order.gd` | New class with StepType enum, Step class, factory methods |
| Dark Age build order | `scripts/ai/build_order.gd` | 30+ step build order covering early economy and military |
| Continuous villager production | `scripts/ai/ai_controller.gd` | `_maintain_villager_production()` keeps TC queue at 2 |
| Production building scaling | `scripts/ai/ai_controller.gd` | Multiple barracks/archery ranges/stables based on thresholds |
| Fast idle villager reassignment | `scripts/ai/ai_controller.gd` | 0.3s check interval, immediate reassignment |
| Pending villager assignments | `scripts/ai/ai_controller.gd` | Track resource assignment for newly spawned villagers |
| Floating resource detection | `scripts/ai/ai_controller.gd` | `_is_floating_resources()` triggers building scaling |

---

## Build Order System Design

The build order system uses a step-based approach:

```
StepType:
  QUEUE_VILLAGER      - Queue villager, track resource assignment
  BUILD_BUILDING      - Build specific building type
  WAIT_VILLAGERS      - Wait for villager count
  WAIT_RESOURCES      - Wait for resource amount
  ASSIGN_VILLAGERS    - Reassign villagers to resource
```

**Dark Age Build Order** (abbreviated):
1. Queue 3 villagers → food (sheep/berries)
2. Build house at pop 4
3. Queue 4 villagers → wood
4. Build lumber camp
5. Build house at pop 9
6. Queue 3 villagers → food
7. Build mill
8. Queue 3 villagers → gold
9. Build mining camp
10. Build barracks at 15 villagers
11. Build archery range at 18 villagers
12. Build stable
13. Build farms
14. Target: 22 villagers, then military focus

---

## Production Building Scaling

| Building | Count | Threshold |
|----------|-------|-----------|
| Barracks | 2nd | 18 villagers + floating resources |
| Barracks | 3rd | 25 villagers + floating resources |
| Archery Range | 2nd | 22 villagers + floating resources |
| Stable | 2nd | 25 villagers + floating resources |

"Floating resources" = any resource > 300 (wood, food, or gold).

---

## Code Review Issues Addressed

| Issue ID | Severity | Fix |
|----------|----------|-----|
| ISSUE-001 | High | Fixed build order step completing without queueing villager |
| ISSUE-002 | High | Fixed idle villager reassignment being blocked by pending assignments |
| ISSUE-005 | Medium | Moved population check inside while loop for queue maintenance |
| ISSUE-006 | Medium | Cached _get_ai_villagers() result to avoid duplicate calls |
| ISSUE-009 | Low | Added PLAYER_TEAM constant for consistency |

**Not addressed (lower priority):**
- ISSUE-003, ISSUE-004: load() vs preload() and typed array filter() - tech debt for future
- ISSUE-007: Villager count desync on death - rare edge case, acceptable
- ISSUE-008, ISSUE-010, ISSUE-011: Extensibility improvements - not critical for 3A

---

## Key Constants Changed

| Constant | Old Value | New Value | Reason |
|----------|-----------|-----------|--------|
| TARGET_VILLAGERS | 20 | 30 | More competitive AI |
| TARGET_FARMS | 6 | 8 | Support larger economy |
| DECISION_INTERVAL | 1.5s | 1.0s | Faster reactions |
| IDLE_CHECK_INTERVAL | (new) | 0.3s | Fast idle reassignment |
| TC_QUEUE_TARGET | (new) | 2 | Continuous production |
| MILITARY_QUEUE_TARGET | (new) | 2 | Continuous production |

---

## Known Issues

- Villager count tracking can desync if villager dies while new one spawns (rare)
- Build order skips camp building if no resource cluster found (acceptable for edge maps)

---

## Test Coverage

### Manual Testing Performed
- [x] AI follows build order sequence during early game
- [x] AI transitions from build order to reactive decisions
- [x] TC maintains queue of 2 villagers
- [x] Idle villagers reassigned within ~0.3s
- [x] AI builds 2nd/3rd barracks when floating resources
- [x] AI builds 2nd archery range when floating resources
- [x] Newly spawned villagers assigned to correct resource from pending list

### Automated Tests

7 new tests added to `tests/scenarios/test_ai.gd`:
- `test_build_order_creates_steps` - Build order step creation
- `test_build_order_dark_age_has_villager_steps` - Dark Age starts with villager queuing
- `test_build_order_dark_age_has_building_steps` - Dark Age includes key buildings
- `test_is_floating_resources_false_when_low` - Floating detection when low
- `test_is_floating_resources_true_when_high` - Floating detection when high
- `test_count_archery_ranges_counts_ai_only` - Archery range counting
- `test_count_stables_counts_ai_only` - Stable counting

---

## Files Changed

**New:**
- `scripts/ai/build_order.gd` - Build order system class

**Modified:**
- `scripts/ai/ai_controller.gd` - Extensive changes for build order execution, continuous production, scaling
- `tests/scenarios/test_ai.gd` - Added Phase 3A tests
- `docs/roadmap.md` - Added Phase 3 sub-phase breakdown

---

## Context for Next Phase

Critical information for Phase 3B (Scouting & Information):

- **Build order system is in place**: Phase 3B can add scouting steps to build order
- **AI has scout cavalry**: Exists from Phase 2B, can be used for scouting
- **Key functions to extend**:
  - Add `_scout_with_cavalry()` for exploration
  - Add enemy base tracking variables
  - Add `_track_enemy_army()` for composition estimation
- **Fog of war is active**: AI already respects visibility from Phase 2E
- **Pending work**: AI doesn't actively scout yet - just trains scout cavalry and attacks with them

---

## Git Reference

- **Branch:** claude/continue-development-Z8xDT
- **Primary changes:** Build order system, continuous production, production scaling
