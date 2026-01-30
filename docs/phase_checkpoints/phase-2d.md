# Phase 2D Checkpoint: Skirmisher + Cavalry Archer

**Date:** 2026-01-30
**Status:** Complete

---

## Summary

Implemented the Skirmisher (anti-archer ranged unit) and Cavalry Archer (mobile ranged cavalry) to complete the combat triangle. Both units are trainable from their respective buildings (Archery Range and Stable), the AI can train and use them, and the bonus damage system correctly applies (Skirmisher bonus vs archers, Spearman bonus vs cavalry including Cavalry Archer).

---

## Context Friction

1. **Files re-read multiple times?** No
2. **Forgot earlier decisions?** No
3. **Uncertain patterns?** No - combat and building patterns from Phase 2A/2B were clear

---

## Implemented Features

| Feature | Files | Notes |
|---------|-------|-------|
| Skirmisher unit | `scripts/units/skirmisher.gd`, `scenes/units/skirmisher.tscn` | 30 HP, 2 attack, 0/3 armor, range 4, +3 bonus vs archers |
| Cavalry Archer unit | `scripts/units/cavalry_archer.gd`, `scenes/units/cavalry_archer.tscn` | 50 HP, 6 attack, 0/0 armor, range 3, fast (140 speed) |
| Skirmisher training | `scripts/buildings/archery_range.gd:17-20, 69-85` | 25 food + 35 wood, 5 sec train time |
| Cavalry Archer training | `scripts/buildings/stable.gd:13-16, 65-83` | 40 wood + 70 gold, 7 sec train time |
| HUD train buttons | `scenes/ui/hud.tscn`, `scripts/ui/hud.gd:318-330, 332-342` | Train buttons and error handling |
| HUD info display | `scripts/ui/hud.gd:404-410, 496-519` | Info panel shows unit stats |
| AI trains new units | `scripts/ai/ai_controller.gd:702-772` | AI mixes skirmishers and cavalry archers into army |
| SVG placeholders | `assets/sprites/units/skirmisher.svg`, `assets/sprites/units/cavalry_archer.svg` | Visual placeholders |

---

## Combat Triangle Status

With Phase 2D complete, the basic combat triangle is functional:

| Unit | Counters | Countered By |
|------|----------|--------------|
| Militia/Infantry | Buildings | Archers |
| Archer | Infantry | Skirmishers, Cavalry |
| Skirmisher | Archers | Infantry |
| Spearman | Cavalry | Archers |
| Scout Cavalry | Archers, Siege | Spearmen |
| Cavalry Archer | Infantry, Archers | Spearmen (+15 bonus), Skirmishers (+3 bonus) |

Note: Cavalry Archer is vulnerable to both anti-cavalry (Spearman) AND anti-archer (Skirmisher) bonus damage since it's in both groups.

---

## Deviations from Spec

| Spec Said | Implementation | Reason |
|-----------|----------------|--------|
| All specs matched | N/A | Spec-check verified both units |

Cavalry Archer range was initially implemented as 4 tiles but corrected to 3 tiles per AoE2 manual spec.

---

## Known Issues

None new. Existing tech debt (AI using load() vs preload()) remains as documented in gotchas.md.

---

## Test Coverage

### Manual Testing Performed
- [x] Train Skirmisher from Archery Range
- [x] Train Cavalry Archer from Stable
- [x] Skirmisher attacks and deals bonus damage to Archer
- [x] Spearman deals bonus damage to Cavalry Archer
- [x] AI trains Skirmishers and Cavalry Archers
- [x] Game launches and runs without errors

### Automated Tests

**New test file additions:**

`tests/scenarios/test_combat.gd` - 15 new tests:
- Skirmisher stats, groups, command_attack, state machine, damage, target death
- Skirmisher bonus damage vs archers
- Cavalry Archer stats, groups, command_attack, state machine, damage, target death
- Cavalry Archer takes bonus from Spearman (cavalry group)
- Cavalry Archer takes bonus from Skirmisher (archers group)

`tests/scenarios/test_buildings.gd` - 11 new tests:
- Archery Range trains Skirmisher (cost check, resource fail checks, pop cap, queue)
- Stable trains Cavalry Archer (cost check, resource fail checks, pop cap, queue)
- Stable spawns Cavalry Archer with correct team

**Test helpers added:**
- `spawn_skirmisher()` and `spawn_cavalry_archer()` in test_spawner.gd
- `assert_skirmisher_state()` and `assert_cavalry_archer_state()` in assertions.gd

### Test Summary

- **Tests written:** 26 new tests (188 → 214 total)
- **Coverage focus:** New unit stats, behavior, group membership, bonus damage mechanics, building training
- **Notable edge cases:** Cavalry Archer dual-vulnerability (both spearman and skirmisher deal bonus damage)

---

## AI Behavior Updates

AI training logic updated to include new units:

| Unit Type | Training Logic |
|-----------|----------------|
| Skirmisher | Trained from Archery Range when ranged count is low, mixed 1:2 with Archers |
| Cavalry Archer | Trained from Stable when cavalry count is low, mixed 1:1 with Scout Cavalry |

Army composition targets remain ~40% infantry, ~40% ranged (including skirmishers), ~20% cavalry (including cavalry archers).

---

## Lessons Learned

(Added to docs/gotchas.md)

- None new - existing patterns from Phase 2A/2B applied cleanly

---

## Context for Next Phase

Critical information for Phase 2E (Fog of War + Stances + AI Military + Attack Notifications):

- **Combat triangle complete**: All counter-unit relationships now work
- **Group system**: Units correctly in groups for targeting (archers, cavalry, infantry, military)
- **Bonus damage pattern**: Use `target.is_in_group("X")` to apply bonus damage
- **AI training**: New units automatically mixed into army - no changes needed for new units added to existing buildings

**Phase 2E will add:**
- Fog of War system (unexplored = black, explored = fog, visible = clear)
- Basic stances (Aggressive, Defensive, Stand Ground, No Attack)
- AI military behavior improvements
- Attack notifications (horn for military, bell for villagers/buildings)

---

## Git Reference

- **Files changed:** 15 files (6 new, 9 modified)
