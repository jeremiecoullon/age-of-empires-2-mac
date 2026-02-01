# Phase 2E Checkpoint: Fog of War + Stances + AI Military + Notifications

**Date:** 2026-01-30
**Status:** Complete

---

## Summary

Implemented the Fog of War system with three visibility states (unexplored, explored, visible), combat stances for military units (Aggressive, Defensive, Stand Ground, No Attack), improved AI military behavior with defense and attack logic, and attack notifications for player units/buildings under attack.

---

## Context Friction

1. **Files re-read multiple times?** No
2. **Forgot earlier decisions?** No
3. **Uncertain patterns?** No - existing unit and building patterns from Phase 2A-2D were clear

---

## Implemented Features

| Feature | Files | Notes |
|---------|-------|-------|
| Fog of War system | `scripts/fog_of_war.gd`, `scenes/main.tscn` | 60x60 tile grid, 3 states (UNEXPLORED/EXPLORED/VISIBLE) |
| Building sight_range | `scripts/buildings/building.gd`, `scripts/buildings/town_center.gd` | Default 192px (~6 tiles), TC has 256px (~8 tiles) |
| Combat stances | `scripts/units/unit.gd:11-12, 24` | AGGRESSIVE, DEFENSIVE, STAND_GROUND, NO_ATTACK |
| Stance behavior | All military units | Auto-aggro logic respects stance settings |
| Stance UI | `scripts/ui/hud.gd` | Buttons in info panel when military unit selected |
| Attack notifications | `scripts/game_manager.gd:29, 34-37, 238-279` | Throttled signals for military/civilian attacks |
| Notification UI | `scripts/ui/hud.gd` | "Under Attack!" banner with 3 second display |
| damaged signal | `scripts/units/unit.gd:36`, `scripts/buildings/building.gd:23` | Emitted with amount and attacker |
| AI defense | `scripts/ai/ai_controller.gd:1003-1031` | AI defends when player units near buildings |
| AI attack cooldown | `scripts/ai/ai_controller.gd:40-41` | 30 second cooldown between attacks |
| AI target priority | `scripts/ai/ai_controller.gd:849-882` | Prioritizes threats > villagers > TC |

---

## Fog of War Details

| State | Color | Behavior |
|-------|-------|----------|
| UNEXPLORED | Black (opaque) | Never seen - enemy units and buildings hidden |
| EXPLORED | Gray (60% opacity) | Previously seen - enemy buildings visible (last known), enemy units hidden |
| VISIBLE | Transparent | Currently in sight - all entities visible |

Special cases:
- Neutral entities (team -1, wild animals) visible in EXPLORED or VISIBLE
- Player units/buildings always visible regardless of fog state
- Fog updates every 0.2 seconds (throttled for performance)

---

## Stance System Details

| Stance | Auto-Aggro | Chase | Notes |
|--------|------------|-------|-------|
| AGGRESSIVE | Yes | Unlimited | Default - units seek and pursue enemies |
| DEFENSIVE | Yes | Limited (200px) | Attack nearby, but return to original position |
| STAND_GROUND | In range only | No | Only attack what's within attack range |
| NO_ATTACK | Never | No | Completely passive - won't auto-attack |

All military units (Militia, Archer, Scout Cavalry, Spearman, Skirmisher, Cavalry Archer) implement this system.

---

## Deviations from Spec

| Spec Said | Implementation | Reason |
|-----------|----------------|--------|
| Terrain bonuses (elevation) | Deferred to Phase 10 | Requires elevation system not yet implemented |

---

## Known Issues

None new. Terrain bonuses deferred per above.

---

## Test Coverage

### Manual Testing Performed
- [x] Fog reveals around player units and buildings
- [x] Enemy units hidden in fog, appear when visible
- [x] Enemy buildings remain visible once explored
- [x] Stance buttons appear when military unit selected
- [x] Changing stance affects auto-aggro behavior
- [x] "Under Attack!" notification appears when player units attacked
- [x] AI defends when player units approach AI buildings
- [x] AI attacks player periodically (with cooldown)
- [x] Game launches and runs without errors

### Automated Tests

**New test file:** `tests/scenarios/test_fog_of_war.gd` - 21 tests

Tests cover:
- Fog grid initialization (size, default state)
- Constants verification (TILE_SIZE, MAP_SIZE, GRID_SIZE)
- is_visible() and is_explored() helper methods
- reveal_all() and reset() functionality
- Player unit/building reveal based on sight_range
- Building sight_range defaults (192px default, 256px for TC)
- AI attack cooldown blocking
- AI threat detection near buildings
- AI attack target prioritization

### Test Summary

- **Tests written:** 21 new tests (214 → 235 total)
- **Coverage focus:** Fog of War visibility states, building sight_range, AI military behavior
- **Notable edge cases:** Neutral entity visibility (wild animals), AI defense near spread-out buildings

---

## AI Behavior Updates

| Behavior | Logic |
|----------|-------|
| Defense | Rallies military to attack player units within 400px of any AI building |
| Attack cooldown | 30 seconds between attack waves |
| Target priority | Nearby threats (300px) > player villagers > player TC > any player building |
| Idle detection | Only sends idle units to attack; doesn't interrupt active defenders |

---

## Lessons Learned

(Added to docs/gotchas.md)

- Fog of war needs throttling (0.2s interval) to avoid per-frame performance issues
- Neutral entities (team -1) need special handling in fog visibility
- AI defense should check all building positions, not just spawn position

---

## Context for Next Phase

Critical information for Phase 3 (Strong AI):

- **Fog of War**: Player has limited visibility; AI should account for this
- **Stance system**: Units have configurable auto-attack behavior
- **AI military**: Basic defense/attack logic in place; can be expanded for smarter behavior
- **Attack notifications**: Player gets visual feedback when under attack
- **sight_range**: All units (128px default) and buildings (192px default, 256px for TC) have sight ranges

**Phase 3 will add:**
- Competitive AI with build orders
- Scouting behavior
- Counter-unit selection
- Unit micro (kiting, formations)

---

## Git Reference

- **Files changed:** 14 files (2 new, 12 modified)
- **New files:** `scripts/fog_of_war.gd`, `tests/scenarios/test_fog_of_war.gd`
