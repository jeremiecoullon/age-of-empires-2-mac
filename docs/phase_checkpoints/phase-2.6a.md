# Phase 2.6A Checkpoint: Bottom Panel + Minimap

**Date:** 2026-02-01
**Status:** Complete

---

## Summary

Implemented AoE2-style UI overhaul replacing scattered floating panels with a unified bottom panel layout. Added minimap with fog of war integration and click-to-pan functionality.

---

## Context Friction

1. **Files re-read multiple times?** No - fresh session with clear requirements from roadmap
2. **Forgot earlier decisions?** No - followed established patterns
3. **Uncertain patterns?** No - AoE2 screenshot provided clear visual reference

---

## Implemented Features

| Feature | Files | Notes |
|---------|-------|-------|
| Bottom panel layout | `scenes/ui/hud.tscn` | ~150px panel anchored to bottom with 3 sections |
| Left section - Info | `scripts/ui/hud.gd` | Unit name, HP bar, attack/armor stats |
| Center section - Actions | `scripts/ui/hud.gd` | Context-sensitive buttons (build, train, buy/sell) |
| Right section - Minimap | `scripts/ui/minimap.gd` | 60x60 grid scaled to 150x120 display |
| Top bar cleanup | `scenes/ui/hud.tscn` | Resources with icons, "Dark Age" placeholder |
| Minimap terrain rendering | `scripts/ui/minimap.gd` | Green base, dark green trees, gold/stone/berry colors |
| Minimap unit/building display | `scripts/ui/minimap.gd` | Blue = player, red = AI, yellow = neutral |
| Minimap fog of war overlay | `scripts/ui/minimap.gd` | Black = unexplored, dimmed = explored, clear = visible |
| Minimap camera indicator | `scripts/ui/minimap.gd` | White rectangle showing current viewport |
| Minimap click-to-pan | `scripts/ui/minimap.gd`, `scripts/camera.gd` | Click minimap to jump camera |
| Stance buttons in scene | `scenes/ui/hud.tscn` | AGG/DEF/SG/NA buttons (previously dynamic) |

---

## UI Layout Reference

```
+----------------------------------------------------------+
| 🪵 200  🍖 200  🪙 0  🪨 0    👤 3/5         Dark Age    | <- Top Bar
+----------------------------------------------------------+
|                                                          |
|                    GAME VIEWPORT                         |
|                                                          |
+----------------------------------------------------------+
| INFO PANEL  |      ACTION BUTTONS      |    MINIMAP      | <- Bottom Panel
| Unit name   | [Build] [Train] etc.     | [  terrain  ]   |
| HP bar      | [Stance buttons]         | [  + units  ]   |
| Attack/Armor| [Progress] [Queue]       | [  + fog    ]   |
| Status      |                          | [cam rect]      |
+----------------------------------------------------------+
```

---

## Key Changes to HUD Architecture

### Before (Phase 2.5B)
- Floating panels: BuildPanel, TCPanel, BarracksPanel, MarketPanel, ArcheryRangePanel, StablePanel, InfoPanel
- Each panel positioned independently on right side
- Stance buttons created dynamically in code

### After (Phase 2.6A)
- Unified BottomPanel with LeftSection, CenterSection, RightSection
- All buttons in ActionGrid (GridContainer) with visibility toggling
- Stance buttons in scene (not dynamic)
- Single `show_info(entity)` entry point handles all entity types

---

## Minimap Technical Details

### Rendering
- 60x60 grid (matching fog of war grid)
- Renders to Image → ImageTexture → Control._draw()
- Update interval: 0.25 seconds (throttled)

### Fog of War Integration
- Respects visibility states: UNEXPLORED, EXPLORED, VISIBLE
- Enemy units only drawn when VISIBLE
- Enemy buildings drawn when EXPLORED or VISIBLE
- Neutral units (animals) drawn when not UNEXPLORED

### Camera Indicator
- White rectangle showing current viewport bounds
- Updates every minimap refresh

### Click-to-Pan
- Signal: `minimap_clicked(world_position)` → `camera.jump_to()`
- Converts minimap coordinates to world coordinates

---

## Code Review Issues Addressed

| Issue ID | Severity | Fix |
|----------|----------|-----|
| ISSUE-001 | High | Added bounds checking for fog_of_war.visibility_grid access |
| ISSUE-002 | High | Minimap now respects fog of war for enemy entities |
| ISSUE-003 | Medium | Added notification counter to prevent race conditions |
| ISSUE-005 | Medium | Added PLAYER_TEAM, AI_TEAM, NEUTRAL_TEAM constants |
| ISSUE-006 | Medium | Added is_instance_valid() check for camera |
| ISSUE-007 | Medium | Fixed duplicate HP update in _update_selected_entity_info |
| ISSUE-008 | Medium | Added zero-zoom safety check |
| ISSUE-009 | Low | Removed unused scale variable in _draw |

---

## Known Issues

None. All tests pass (263/263).

---

## Test Coverage

### Manual Testing Performed
- [x] Bottom panel displays correctly at screen bottom
- [x] Left section shows unit/building info with HP bar
- [x] Center section shows context-appropriate buttons
- [x] Build buttons appear when villager selected
- [x] Train buttons appear when production building selected
- [x] Market buy/sell buttons update prices dynamically
- [x] Stance buttons appear for military units
- [x] Minimap displays terrain (green base)
- [x] Minimap shows resources (trees, gold, stone, berries)
- [x] Minimap shows player units (blue dots)
- [x] Minimap shows AI units only when visible (red dots)
- [x] Minimap shows buildings appropriately sized
- [x] Minimap fog of war overlay matches game fog
- [x] Minimap click pans camera to location
- [x] Camera indicator rectangle updates with camera position
- [x] Top bar shows resources with icons and Dark Age label
- [x] Error messages display above bottom panel
- [x] Game over panel displays correctly

### Automated Tests

No new tests written for UI (263 existing tests pass). UI testing is primarily manual.

---

## Lessons Learned

(Added to docs/gotchas.md if significant)

- **Minimap fog integration**: Must check fog of war visibility before drawing enemy entities on minimap, otherwise information leaks to player
- **Notification race conditions**: Use counter pattern when multiple async operations can set/clear same UI element
- **Control size vs grid size**: Minimap uses 60x60 grid scaled to 150x120 display - the draw_texture_rect handles scaling

---

## Context for Next Phase

Critical information for Phase 2.6B (Cursor System):

- **Cursor assets available**: `assets/sprites_extracted/cursors/` has cursor_default.png, cursor_attack.png, cursor_build.png, cursor_gather.png, cursor_hand.png, cursor_forbidden.png
- **Selection state in main.gd**: Check `selected_units` array to determine what's selected
- **Building placement mode**: Tracked in main.gd (`is_placing_building`, `placement_building_type`)
- **HUD methods preserved**: show_info(), hide_info() still work for integration

---

## Files Changed

**New:**
- `scripts/ui/minimap.gd` - Minimap rendering and click handling

**Modified:**
- `scripts/ui/hud.gd` - Complete rewrite for bottom panel architecture
- `scenes/ui/hud.tscn` - Complete restructure with bottom panel layout
- `scripts/camera.gd` - Added jump_to() method for minimap click

---

## Git Reference

- **Primary changes:** UI restructure from floating panels to AoE2-style bottom panel
- **New patterns:** Minimap rendering with fog integration, click-to-pan
