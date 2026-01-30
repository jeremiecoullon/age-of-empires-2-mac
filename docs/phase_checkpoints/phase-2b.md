# Phase 2B Checkpoint: Cavalry & Counter-Units

**Date:** 2026-01-30
**Status:** Complete

---

## Summary

Implemented the armor system (melee/pierce), Stable building, Scout Cavalry unit, and Spearman unit with anti-cavalry bonus damage. Established the foundation for the combat triangle with counter-unit mechanics.

---

## Context Friction

1. **Files re-read multiple times?** No
2. **Forgot earlier decisions?** No
3. **Uncertain patterns?** Yes - preload() vs load() for new assets caused initial test failures. Resolved by using load() until assets are imported, then converting to preload(). Documented in gotchas.md.

---

## Implemented Features

| Feature | Files | Notes |
|---------|-------|-------|
| Armor system (Unit) | `scripts/units/unit.gd:11-12, 41-49` | melee_armor, pierce_armor, damage reduction formula |
| Armor system (Building) | `scripts/buildings/building.gd:11-12, 35-44` | Same pattern as Unit |
| Stable building | `scripts/buildings/stable.gd`, `scenes/buildings/stable.tscn` | 175W cost, 1500 HP, trains cavalry |
| Scout Cavalry unit | `scripts/units/scout_cavalry.gd`, `scenes/units/scout_cavalry.tscn` | 80F, 45 HP, 3 attack, 0/2 armor, fast |
| Spearman unit | `scripts/units/spearman.gd`, `scenes/units/spearman.tscn` | 35F+25W, 45 HP, 3 attack, +15 vs cavalry |
| Barracks trains Spearman | `scripts/buildings/barracks.gd:10-14, 72-91` | TrainingType.SPEARMAN added |
| Stable UI panel | `scripts/ui/hud.gd`, `scenes/ui/hud.tscn` | Train Scout Cavalry button |
| Build Stable button | `scripts/ui/hud.gd`, `scenes/ui/hud.tscn` | Added to build panel |
| SVG placeholders | `assets/sprites/buildings/stable.svg`, `assets/sprites/units/scout_cavalry.svg`, `assets/sprites/units/spearman.svg` | Documented in gotchas.md |
| Cavalry group | `scripts/units/scout_cavalry.gd:23` | For bonus damage targeting |
| Infantry group | `scripts/units/spearman.gd:24`, `scripts/units/militia.gd:17` | Consistency for future bonuses |

---

## Deviations from Spec

| Spec Said | Implementation | Reason |
|-----------|----------------|--------|
| Scout speed "M" (medium) | 150 move_speed | Relative to militia (100), this is medium. Knight will be faster (~200) |
| Spearman bonus vs War Elephants | Only vs cavalry group | War Elephants not yet implemented, will add them to cavalry group or separate check |

---

## Known Issues

- **Duplicated _load_static_sprite method:** Archer, ScoutCavalry, and Spearman each have identical helper. Could be moved to base Unit class. Low priority - code works correctly.

---

## Test Coverage

### Manual Testing Performed
- [x] Build Stable (175 wood deducted)
- [x] Click Stable shows panel with Train Scout Cavalry button
- [x] Train Scout Cavalry (80F deducted)
- [x] Scout Cavalry appears with correct team color, moves fast
- [x] Train Spearman from Barracks (35F + 25W deducted)
- [x] Spearman attacks enemy units
- [x] Spearman deals extra damage to cavalry

### Automated Tests

**New test file: `tests/scenarios/test_armor.gd`** (15 tests)
- Armor reducing damage correctly (melee vs pierce)
- Minimum 1 damage even with high armor
- Bonus damage bypassing armor
- Scout Cavalry pierce armor resistance
- Spearman bonus vs cavalry group

**Updated: `tests/scenarios/test_combat.gd`** (+12 tests)
- Scout Cavalry stats, groups, attack behavior
- Spearman stats, groups, attack behavior

**Updated: `tests/scenarios/test_buildings.gd`** (+9 tests)
- Stable cost, HP, training
- Barracks Spearman training

### Test Summary

- **Tests written:** 36 new tests across 3 files (132 → 168 total)
- **Coverage focus:** Armor system damage calculation, unit stats matching AoE2 specs, training costs, group membership for bonus targeting
- **Notable edge cases:** Minimum 1 damage with high armor, bonus damage order (after armor reduction), cross-type armor isolation

---

## AI Behavior Updates

No AI changes this phase. AI will be updated in a later phase to build Stables and train cavalry/infantry.

---

## Lessons Learned

(Added to docs/gotchas.md)

- **preload() vs load() for new assets:** New asset files that haven't been imported by Godot will cause preload() to fail at parse time. Use load() at runtime for newly created assets until they're imported. Run `godot --headless --import --path .` to force Godot to import all assets before running tests.
- **Armor system signature:** `take_damage(amount, attack_type, bonus_damage)` where attack_type is "melee" or "pierce". Armor reduces base damage (min 1), then bonus damage is added.
- **Bonus damage via groups:** Spearman's anti-cavalry bonus checks `target.is_in_group("cavalry")`. Add units to appropriate groups (cavalry, infantry, archer, siege) for bonus damage targeting.

---

## Context for Next Phase

Critical information for Phase 2C (AI Economic Foundation) and beyond:

- **Next sub-phase (2C):** AI catch-up phase - make AI train villagers, build farms, use all existing buildings. See roadmap for full 2C spec.
- **After 2C:** Phase 2D adds Skirmisher + Cavalry Archer to complete the combat triangle.
- **Armor system established:** Units have melee_armor and pierce_armor. Damage formula: `final = max(1, base - armor) + bonus`. All existing units updated.
- **Group-based bonus damage:** Check `target.is_in_group("group_name")` for applying bonus damage. Current groups: cavalry, infantry, military, archers.
- **Building panels:** Stable panel added following same pattern. Use explicit panels per building type.
- **Training pattern:** Buildings use TrainingType enum, train_X() function, _complete_training() spawns unit. See barracks.gd for two-unit building example.
- **Speed reference:** Militia ~100, Scout Cavalry 150, Archer 96. Use these as baseline for future units.

---

## Git Reference

- **Commits:** Phase 2B cavalry and counter-units implementation
