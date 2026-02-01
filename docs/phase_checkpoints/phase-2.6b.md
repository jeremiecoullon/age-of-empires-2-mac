# Phase 2.6B Checkpoint: Cursor System

**Date:** 2026-02-01
**Status:** Complete

---

## Summary

Implemented AoE2-style context-sensitive cursor system that changes the mouse cursor based on what's selected and what the user is hovering over.

---

## Context Friction

1. **Files re-read multiple times?** No - fresh session, clear checkpoint from 2.6A
2. **Forgot earlier decisions?** No - followed established patterns
3. **Uncertain patterns?** No - cursor behavior well-defined in roadmap

---

## Implemented Features

| Feature | Files | Notes |
|---------|-------|-------|
| Cursor manager | `scripts/ui/cursor_manager.gd` | New script handles all cursor logic |
| Default cursor | cursor_default.png | Arrow for normal state |
| Attack cursor | cursor_attack.png | Sword when hovering enemy with unit selected |
| Gather cursor | cursor_gather.png | Axe when hovering trees with villager |
| Hand cursor | cursor_hand.png | Hand when hovering gold/stone/farm/animals with villager |
| Build cursor | cursor_build.png | Hammer in placement mode or hovering unfinished building |
| Forbidden cursor | cursor_forbidden.png | Circle when invalid placement location |
| Throttled hover detection | 0.1s interval | Prevents expensive group searches every frame |
| main.gd integration | `scripts/main.gd` | Initializes cursor manager on ready |

---

## Cursor Logic

```
Building Placement Mode?
├── Yes → Valid position? → BUILD / FORBIDDEN
└── No → Units selected?
    ├── No → DEFAULT
    └── Yes → Selection contains:
        ├── Villager?
        │   ├── Hovering tree → GATHER (axe)
        │   ├── Hovering gold/stone/berry/farm → HAND
        │   ├── Hovering animal → HAND
        │   ├── Hovering friendly under-construction building → BUILD
        │   ├── Hovering enemy unit/building → ATTACK
        │   └── Otherwise → DEFAULT
        ├── Military?
        │   ├── Hovering enemy unit/building → ATTACK
        │   └── Otherwise → DEFAULT
        └── Otherwise → DEFAULT
```

---

## Code Review Issues Addressed

| Issue ID | Severity | Fix |
|----------|----------|-----|
| ISSUE-001 | High | Added throttling (0.1s interval) for hover cache updates |
| ISSUE-003 | Medium | Reused main.gd's position lookup methods instead of duplicating |
| ISSUE-004 | Medium | Added is_instance_valid() checks for all hover targets |
| ISSUE-005 | Medium | Now uses main_scene.TILE_SIZE instead of hardcoded 32 |
| ISSUE-006 | Medium | Uses group check (is_in_group("trees")) instead of string comparison |
| ISSUE-007 | Low | Fixed by reusing main.gd methods (consistent click radii) |

**Not addressed:**
- ISSUE-002 (hardcoded team 0): Kept as-is because only player units (team 0) can be selected in this game. The team check is semantically correct.

---

## Known Issues

None. All tests pass (263/263).

---

## Test Coverage

### Manual Testing Performed
- [x] Default cursor shows when nothing selected
- [x] Attack cursor shows when hovering enemy unit with military selected
- [x] Attack cursor shows when hovering enemy building with military selected
- [x] Attack cursor shows when hovering enemy with villager selected
- [x] Gather (axe) cursor shows when hovering tree with villager selected
- [x] Hand cursor shows when hovering gold mine with villager selected
- [x] Hand cursor shows when hovering stone mine with villager selected
- [x] Hand cursor shows when hovering berry bush with villager selected
- [x] Hand cursor shows when hovering farm with villager selected
- [x] Hand cursor shows when hovering sheep with villager selected
- [x] Build cursor shows in building placement mode on valid location
- [x] Forbidden cursor shows in building placement mode on invalid location
- [x] Build cursor shows when hovering under-construction building with villager
- [x] Cursor updates smoothly when moving mouse (throttling not noticeable)
- [x] Cursor resets to default after deselecting units

### Automated Tests

No new automated tests. Cursor system is UI-dependent and best tested manually. All 263 existing tests still pass.

---

## Lessons Learned

(Added to docs/gotchas.md if significant)

- **Cursor system throttling**: Like fog of war, cursor hover detection should be throttled to avoid expensive group searches every frame. 0.1s (10 updates/second) feels responsive.
- **Reuse position lookup methods**: main.gd already has `_get_X_at_position()` methods. Cursor manager calls these instead of duplicating logic.
- **Hotspot positions vary by cursor**: Arrow cursors use top-left (0,0), centered cursors like forbidden use center (16,16), tools like axe use the "impact point" near top.

---

## Context for Next Phase

Critical information for Phase 3 (Strong AI):

- **AI already has basic behavior**: Builds economy, trains military, attacks when ready
- **All military units exist**: Militia, Archer, Spearman, Scout Cavalry, Skirmisher, Cavalry Archer
- **Fog of war is active**: AI can only see what its units reveal
- **Stances implemented**: AGG/DEF/SG/NA affect unit behavior
- **Key AI file**: `scripts/ai/ai_controller.gd`

---

## Files Changed

**New:**
- `scripts/ui/cursor_manager.gd` - Cursor management and context detection

**Modified:**
- `scripts/main.gd` - Added cursor manager initialization

---

## Git Reference

- **Primary changes:** Context-sensitive cursor system
- **New patterns:** Throttled hover detection with cached targets
