# Phase 1C Checkpoint: Basic Sprites

**Date:** 2026-01-27
**Status:** Complete

---

## Summary

Replaced placeholder colored rectangles with actual sprites from the Tiny Swords asset pack. Set up standardized sprite paths (`assets/sprites/`) for easy future replacement. Created SVG placeholders for missing assets (deer, boar, wolf, farm).

---

## Implemented Features

| Feature | Files | Notes |
|---------|-------|-------|
| Sprite folder structure | `assets/sprites/{units,buildings,resources}/` | Standardized paths for easy replacement |
| Villager sprite | `scenes/units/villager.tscn`, `assets/sprites/units/villager.png` | Uses Pawn from Tiny Swords, region_rect for first frame |
| Militia sprite | `scenes/units/militia.tscn`, `assets/sprites/units/militia.png` | Uses Warrior from Tiny Swords |
| Sheep sprite | `scenes/units/sheep.tscn`, `assets/sprites/units/sheep.png` | From Tiny Swords Meat/Sheep |
| Deer placeholder | `scenes/units/deer.tscn`, `assets/sprites/units/deer.svg` | SVG placeholder |
| Boar placeholder | `scenes/units/boar.tscn`, `assets/sprites/units/boar.svg` | SVG placeholder |
| Wolf placeholder | `scenes/units/wolf.tscn`, `assets/sprites/units/wolf.svg` | SVG placeholder |
| Town Center sprite | `scenes/buildings/town_center.tscn`, `assets/sprites/buildings/town_center.png` | Uses Castle from Tiny Swords |
| House sprite | `scenes/buildings/house.tscn`, `assets/sprites/buildings/house.png` | Uses House1 from Tiny Swords |
| Barracks sprite | `scenes/buildings/barracks.tscn`, `assets/sprites/buildings/barracks.png` | Uses Tower from Tiny Swords |
| Mill sprite | `scenes/buildings/mill.tscn`, `assets/sprites/buildings/mill.png` | Uses House2 from Tiny Swords |
| Lumber Camp sprite | `scenes/buildings/lumber_camp.tscn`, `assets/sprites/buildings/lumber_camp.png` | Uses House3 from Tiny Swords |
| Mining Camp sprite | `scenes/buildings/mining_camp.tscn`, `assets/sprites/buildings/mining_camp.png` | Uses House3 from Tiny Swords |
| Farm placeholder | `scenes/buildings/farm.tscn`, `assets/sprites/buildings/farm.svg` | SVG placeholder (crop field pattern) |
| Tree sprite | `scenes/resources/tree.tscn`, `assets/sprites/resources/tree.png` | Uses Tree1 from Tiny Swords |
| Berry Bush sprite | `scenes/resources/berry_bush.tscn`, `assets/sprites/resources/berry_bush.png` | Uses Bushe1 from Tiny Swords |
| Gold Mine sprite | `scenes/resources/gold_mine.tscn`, `assets/sprites/resources/gold_mine.png` | Uses Gold_Resource from Tiny Swords |
| Stone Mine sprite | `scenes/resources/stone_mine.tscn`, `assets/sprites/resources/stone_mine.png` | Uses Rock1 from Tiny Swords |
| Food Carcass sprite | `scenes/resources/food_carcass.tscn`, `assets/sprites/resources/food_carcass.png` | Uses Meat Resource from Tiny Swords |

---

## Deviations from Spec

| Spec Said | Implementation | Reason |
|-----------|----------------|--------|
| Team-specific sprites | Modulate tinting on single sprite set | Simpler; proper team sprites deferred |
| Animation support | Static single frames only | Phase 1C is basic sprites; animation in Phase 9 |

---

## Known Issues

- **AI units look purple-ish**: AI team uses red modulate on blue-tinted Tiny Swords sprites, resulting in purple appearance. Fix: load team-specific sprites (Red Units folder exists). Deferred to later phase.
- **Scale values are approximations**: Sprite scales were set to roughly match original collision sizes. May need tweaking after visual testing.
- **SVG placeholders are flat**: Deer, boar, wolf, farm use simple SVG shapes. Look different from pixel art sprites. Replace with proper sprites when available.

---

## Test Coverage

### Manual Testing Performed
- [ ] Launch game, verify sprites display instead of colored rectangles
- [ ] Verify villagers and militia are distinguishable
- [ ] Verify buildings have distinct appearances
- [ ] Verify resources (trees, gold, stone, berries) look correct
- [ ] Verify sheep sprite displays
- [ ] Verify SVG placeholders (deer, boar, wolf, farm) load without errors
- [ ] Verify team color tinting still applies (player=blue tint, AI=purple-ish)
- [ ] Verify selection indicators still work

### Automated Tests
- None yet

---

## AI Behavior Updates

No AI changes this phase.

---

## Lessons Learned

(Added to docs/gotchas.md)

- Sprite sheets need region_rect to display single frames
- Standardized paths enable easy sprite replacement later
- Team colors + pre-colored sprites = tinted result (needs proper fix later)
- SVGs work as functional placeholders

---

## Context for Next Phase

Critical information for Phase 1D (Trading) or Phase 2:

- **Sprite paths are standardized**: `assets/sprites/{units,buildings,resources}/entity_name.{png,svg}`
- **To replace a sprite**: Drop new file with same name, Godot handles import automatically
- **Team color system unchanged**: Still uses modulate in `_apply_team_color()`. Future refactor needed for clean team sprites.
- **Tiny Swords has more assets**: Red Units folder has team variants. Buildings have multiple House variants. Could use for upgrades or variety.
- **Animation-ready structure**: Sprite sheets exist with multiple frames. AnimatedSprite2D setup would enable animation in Phase 9.

---

## Git Reference

- **Commits:** Phase 1C basic sprites implementation
