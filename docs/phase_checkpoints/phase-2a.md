# Phase 2A Checkpoint: Ranged Combat Foundation

**Date:** 2026-01-30
**Status:** Complete

---

## Summary

Implemented the Archery Range building and Archer unit with ranged combat mechanics. Established the foundation for Phase 2's combat triangle with the first ranged unit that attacks from distance.

---

## Context Friction

1. **Files re-read multiple times?** No
2. **Forgot earlier decisions?** No
3. **Uncertain patterns?** No

No friction observed - patterns from Phase 1 were clear and easy to follow.

---

## Implemented Features

| Feature | Files | Notes |
|---------|-------|-------|
| Archery Range building | `scripts/buildings/archery_range.gd`, `scenes/buildings/archery_range.tscn` | 175W cost, trains archers |
| Archer unit | `scripts/units/archer.gd`, `scenes/units/archer.tscn` | 25W+45G, 30 HP, 4 attack, range 128px (~4 tiles) |
| Ranged combat | `scripts/units/archer.gd:73-97` | Hitscan attack from distance, doesn't close to melee |
| Archery Range UI panel | `scripts/ui/hud.gd:141-170`, `scenes/ui/hud.tscn` | Train Archer button, progress bar |
| Build Archery Range button | `scripts/ui/hud.gd:232-236`, `scenes/ui/hud.tscn` | Added to build panel |
| Military group-based attack dispatch | `scripts/main.gd:178-193` | Uses group check instead of type check for extensibility |
| SVG placeholders | `assets/sprites/units/archer.svg`, `assets/sprites/buildings/archery_range.svg` | Documented in gotchas.md |

---

## Deviations from Spec

| Spec Said | Implementation | Reason |
|-----------|----------------|--------|
| Projectile visuals | Hitscan (instant) | Projectile visuals deferred to Phase 9 (Polish) |
| Armor system (0/0) | Not implemented | Armor system deferred to Phase 2B with combat triangle |
| Terrain elevation bonuses | Not implemented | Deferred to Phase 9 per DD-006 (requires map elevation system) |

---

## Known Issues

- **No 8-directional sprites for Archer:** Archer uses single static SVG. Will look different from militia/villager until proper sprites are added.
- **Tech debt: preload() pattern:** Barracks still uses load() at runtime. Should be updated to match ArcheryRange's preload() pattern.

---

## Test Coverage

### Manual Testing Performed
- [x] Build Archery Range (175 wood deducted)
- [x] Click Archery Range shows panel with Train Archer button
- [x] Train Archer (25W + 45G deducted)
- [x] Archer appears after training, has correct team color
- [x] Right-click enemy to attack - Archer attacks from distance
- [x] Archer state transitions (IDLE → ATTACKING → IDLE when target dies)

### Automated Tests

Tests in `tests/scenarios/test_combat.gd` (8 new tests):
- Archer stats: HP=30, attack=4, range=128px
- command_attack sets target and state
- Archer attacks from range without closing
- Archer deals damage to units and buildings
- Archer stops attacking when target dies
- Archer group membership (military, archers)

Tests in `tests/scenarios/test_buildings.gd` (7 new tests):
- Archery Range cost (175W)
- Training costs (25W + 45G)
- Training fails with insufficient resources
- Training fails at population cap
- Cannot train while already training
- Spawned archer has correct team

### Test Summary

- **Tests written:** 15 tests across 2 files
- **Coverage focus:** Archer stats, ranged attack behavior, state machine, training/spawning
- **Notable edge cases:** Archer staying at range, team inheritance for trained units

---

## AI Behavior Updates

No AI changes this phase. AI will be updated in Phase 2D to build Archery Ranges and train archers.

---

## Lessons Learned

(Added to docs/gotchas.md)

- **Preload textures for static sprites:** Use `const TEXTURE = preload("path")` instead of `load()` at runtime to avoid file I/O during gameplay.
- **Group-based attack dispatch:** Use `unit.is_in_group("military")` instead of explicit type checks (`is Militia`) for more extensible attack command handling.

---

## Context for Next Phase

Critical information for Phase 2B (Cavalry & Counter-Units):

- **Ranged attack pattern established:** Archer shows how to implement ranged units. Key difference from melee: attack from distance, don't close to target.
- **Military group convention:** All military units should be added to "military" group. Attack commands in main.gd now use group check, so new military units automatically work.
- **TrainingType enum in ArcheryRange:** Ready for Skirmisher addition - just add SKIRMISHER to enum and implement train_skirmisher().
- **Bonus damage not yet implemented:** Phase 2B will need to add bonus damage system (skirmisher vs archer, spearman vs cavalry).
- **Building panel pattern unchanged:** Continue using explicit panels per building type (stable_panel for Stable).

---

## Git Reference

- **Commits:** Phase 2A ranged combat implementation
