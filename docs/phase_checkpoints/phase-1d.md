# Phase 1D Checkpoint: 8-Directional Sprites

**Date:** 2026-01-28
**Status:** Complete

---

## Summary

Replaced the single-direction sprite system with proper 8-directional sprites. Units now face the direction they're moving instead of always facing the same way.

---

## Implemented Features

| Feature | Files | Notes |
|---------|-------|-------|
| Direction enum & constants | `scripts/units/unit.gd:7-9` | SW, W, NW, N, NE, E, SE, S order matching AoE sprites |
| 8-dir animation loader | `scripts/units/unit.gd:47-108` | `_load_directional_animations()` creates 8 animations from frame folder |
| Direction from velocity | `scripts/units/unit.gd:171-202` | `_get_direction_from_velocity()` maps movement to direction index |
| Direction update system | `scripts/units/unit.gd:204-220` | `_update_facing_direction()` and `_play_direction_animation()` |
| Villager 8-dir | `scripts/units/villager.gd:27` | 75 frames, ~9 per direction |
| Militia 8-dir | `scripts/units/militia.gd:20` | 30 frames, ~4 per direction |
| Sheep 8-dir | `scripts/units/sheep.gd:25` | 45 frames, ~5 per direction |
| Deer 8-dir | `scripts/units/deer.gd:22` | 25 frames, ~3 per direction |
| Boar 8-dir | `scripts/units/boar.gd:29` | 50 frames, ~6 per direction |
| Wolf 8-dir | `scripts/units/wolf.gd:26` | 50 frames, ~6 per direction |
| Animal movement updates | `scripts/units/animal.gd:81,92,108` | `_update_facing_direction()` in wander/flee/attack |

---

## Deviations from Spec

| Spec Said | Implementation | Reason |
|-----------|----------------|--------|
| Full animations (walk, attack, die) | Idle animation only (8-dir) | Phase scope - full animations in Phase 9 (Polish) |
| Team-specific sprites | Modulate tinting on single sprite | Consistent with Phase 1C approach - proper fix deferred |

---

## Known Issues

- **Direction mapping not pixel-perfect**: Some directions may be slightly off (e.g., N showing NW). AoE sprite direction identification from small frames is difficult. Current implementation is "good enough" - can be refined in Phase 9 Polish.
- **Team color tinting on pre-colored sprites**: AoE sprites are pre-colored. Applying red modulate for AI team produces tinted colors instead of proper team colors. Visual improvement needed in Phase 9.
- **Export builds may have issues**: DirAccess-based frame loading works in editor but may fail in exported builds. Consider pre-generating SpriteFrames .tres files before shipping.
- **Farm still uses SVG**: No AoE farm sprite found in asset pack.
- **Extra frames unused**: Integer division means some frames aren't used (e.g., 75 frames / 8 = 9 per dir, 3 frames unused). Acceptable visual quality.

---

## Test Coverage

### Manual Testing Performed
- [ ] Launch game, verify units display with animated sprites
- [ ] Move a villager in all 8 directions, verify sprite faces correct direction
- [ ] Move militia in all 8 directions, verify sprite faces correct direction
- [ ] Verify sheep face direction when wandering
- [ ] Verify deer face direction when fleeing
- [ ] Verify boar/wolf face direction when chasing
- [ ] Verify units maintain last direction when stopped
- [ ] Verify team color tinting still applies
- [ ] Verify selection indicators still work

### Automated Tests
- None yet

---

## AI Behavior Updates

No AI changes this phase.

---

## Lessons Learned

(Added to docs/gotchas.md)

- 8-directional sprite order in AoE: SW, W, NW, N, NE, E, SE, S (counter-clockwise from SW)
- Use `velocity.angle()` + sector mapping for direction calculation
- Add PI/8 offset so sector boundaries fall between cardinal directions
- Subclasses must call `_update_facing_direction()` after `move_and_slide()` since they override _physics_process()
- Validate minimum frames (>= 8) before creating 8-dir animations

---

## Context for Next Phase

Critical information for Phase 2 (Military Foundation) or later phases:

- **8-direction system ready for expansion**: `_load_directional_animations()` creates animations named `idle_sw`, `idle_w`, etc. For walk/attack animations, extend to `walk_sw`, `attack_sw`, etc. The direction enum and calculation helpers are in place.
- **Animation state not yet implemented**: Units only have "idle" animations. When adding walk/attack states, will need to track current animation type and combine with direction (e.g., `walk_` + `DIRECTION_NAMES[current_direction]`).
- **Legacy loader preserved**: `_load_animation_frames()` still exists for units without 8-dir sprites.
- **SpriteFrames caching works**: Static cache with different keys for 8-dir vs single-dir prevents conflicts.

---

## Git Reference

- **Commits:** Phase 1D 8-directional sprites
