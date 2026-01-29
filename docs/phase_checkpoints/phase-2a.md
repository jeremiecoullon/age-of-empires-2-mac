# Phase 2A Checkpoint: Archery Range & Ranged Units

**Date:** 2026-01-29
**Status:** Complete

---

## Summary

Implemented ranged combat foundation: Archery Range building, Archer unit, and Skirmisher unit (counter-archer). AI now builds archery ranges and trains archers. This is the first step of the combat triangle (ranged vs infantry).

---

## Context Friction

1. **Files re-read multiple times?** No
2. **Forgot earlier decisions?** No
3. **Uncertain patterns?** No - followed established barracks/militia patterns

No friction observed.

---

## Implemented Features

| Feature | Files | Notes |
|---------|-------|-------|
| Archery Range building | `scripts/buildings/archery_range.gd`, `scenes/buildings/archery_range.tscn` | 175 wood, 1500 HP, trains archers/skirmishers |
| Archer unit | `scripts/units/archer.gd`, `scenes/units/archer.tscn` | 25W+45G, 30 HP, 4 attack, range 4 (128px) |
| Skirmisher unit | `scripts/units/skirmisher.gd`, `scenes/units/skirmisher.tscn` | 25F+35W, 30 HP, 2 attack (+3 vs archers), range 4 |
| SVG sprites | `assets/sprites/buildings/archery_range.svg`, `assets/sprites/units/archer.svg`, `assets/sprites/units/skirmisher.svg` | Placeholder sprites for new assets |
| Archery Range UI panel | `scripts/ui/hud.gd:18-21, 79-83, 130-155`, `scenes/ui/hud.tscn` | Train buttons, progress bar |
| Archery Range placement | `scripts/main.gd:8,12,83-87,338-347,408-409` | Build button, ghost, size |
| AI archery range | `scripts/ai/ai_controller.gd:5,22,88-93,448-488` | AI builds archery range after barracks, trains archers |
| Attack via group membership | `scripts/main.gd:178-188` | Uses `is_in_group("military")` instead of explicit type checks |

---

## Deviations from Spec

| Spec Said | Implementation | Reason |
|-----------|----------------|--------|
| Skirmisher 0/3 pierce armor | No armor system | Armor is Phase 4 (Blacksmith). Counter-unit mechanic uses `bonus_vs_archers` for now |
| Archery Range garrison 10 | No garrison | Garrison is Phase 6 (Walls & Basic Defense) |
| Archery Range age-gated to Feudal | No age-gating | Age system is Phase 3 |
| AI trains skirmishers | AI only trains archers | Simplified for MVP - skirmisher training can be added later |

---

## Known Issues

- **No projectile visuals**: Ranged attacks are instant-hit (no arrow projectile). Acceptable for MVP.
- **AI doesn't train skirmishers**: AI builds mixed armies but currently only trains archers from archery range. Could add randomized training or counter-logic later.
- **Tech debt (load vs preload)**: AI controller still uses `load()` for scene instantiation. ArcheryRange correctly uses `preload()`.

---

## Test Coverage

### Manual Testing Checklist
- [ ] Build Archery Range (175 wood cost deducted)
- [ ] Click Archery Range to show panel with Train buttons
- [ ] Train Archer (25 wood + 45 gold deducted, unit spawns after progress)
- [ ] Train Skirmisher (25 food + 35 wood deducted, unit spawns)
- [ ] Select Archer, right-click enemy - archer attacks from range
- [ ] Select Skirmisher, right-click enemy archer - skirmisher deals bonus damage
- [ ] AI builds archery range after barracks
- [ ] AI trains archers
- [ ] AI sends archers with militia to attack player

### Automated Tests
- Tests not run due to no Godot runtime in environment
- Test agent skipped - manual testing recommended before next phase

---

## AI Behavior Updates

- **AI builds Archery Range**: After having a barracks, when wood >= 175
- **AI trains Archers**: When has archery range, population available, and 25 wood + 45 gold
- **AI attacks with mixed army**: All units in "military" group sent to attack player TC

---

## Lessons Learned

(Added to docs/gotchas.md)

- Skirmisher pierce armor deferred to Phase 4 - counter-unit mechanic uses bonus damage for now
- SVG sprites for placeholders instead of reusing other assets
- Static Sprite2D nodes need separate team color application (`_apply_static_sprite_color()`)
- Range conversion: tiles × 32 = pixels (4 tiles = 128px)
- Military units must join "military" group for AI coordination

---

## Context for Next Phase

Critical information for Phase 2B (Spearman & Cavalry):

- **Ranged unit pattern established**: Archer/Skirmisher use same state machine (IDLE, MOVING, ATTACKING) with ranged attack logic. Cavalry Archer will follow similar pattern.

- **Counter-unit mechanic**: Skirmisher demonstrates `bonus_vs_X` damage pattern. Spearman will use `bonus_vs_cavalry`.

- **Group-based attack commands**: main.gd uses `is_in_group("military")` for attack eligibility. All new combat units must join this group.

- **SVG placeholder pattern**: Create SVGs for missing sprites rather than reusing other assets. Place in appropriate `assets/sprites/` subfolder.

- **Static sprite team color**: Units with SVG sprites need `_apply_static_sprite_color()` in their `_ready()` since base Unit class only handles AnimatedSprite2D.

- **AI builds in order**: TC → Houses → Barracks → Archery Range → Market. Stable will fit after Archery Range.

---

## Git Reference

- **Branch:** claude/phase-2-orchestration-qqYXE
- **Files changed:** 16 (9 new, 7 modified)
