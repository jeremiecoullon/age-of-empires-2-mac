# Cursor implementation notes (Phase 2.6B)

**Date:** 2026-02-01
**Status:** Awaiting manual verification

---

## Problem encountered

The cursor system logic was implemented correctly and all tests pass, but on **macOS with Godot 4.5.1 (Metal renderer)**, the visual cursor would not change after the initial set in `_ready()`.

### What worked:
- Cursor textures load correctly
- Cursor type logic correctly identifies GATHER, HAND, BUILD, ATTACK, etc.
- Debug logs confirmed correct cursor types being set (0=DEFAULT, 2=GATHER, 3=HAND, 4=BUILD, 5=FORBIDDEN)
- The initial cursor set in `_ready()` displays correctly (AoE2 arrow)

### What didn't work:
- `Input.set_custom_mouse_cursor()` - only worked on first call
- `DisplayServer.cursor_set_custom_image()` - same issue
- Resetting cursor shape before setting new cursor - same issue
- Using `DisplayServer.cursor_set_shape()` first - same issue

This appears to be a Godot 4.5.1 + macOS Metal renderer bug where custom cursors can only be set once.

---

## Solution implemented

Switched to a **sprite-based cursor** approach that completely bypasses Godot's cursor API:

1. Hide the system cursor with `Input.mouse_mode = Input.MOUSE_MODE_HIDDEN`
2. Create a `CanvasLayer` (layer 100) with a `Sprite2D` child
3. Update sprite position every frame to follow mouse (with hotspot offset)
4. Change sprite texture instead of calling cursor API

This approach:
- Works reliably on all platforms
- Handles hotspots correctly (click point varies by cursor)
- Restores system cursor when node exits tree

---

## Files involved

- `scripts/ui/cursor_manager.gd` - Main cursor logic (rewritten for sprite approach)
- `tests/scenarios/test_cursor.gd` - 14 automated tests
- `docs/phase_checkpoints/phase-2.6b.md` - Checkpoint documentation

---

## Current status

- **Tests:** All 277 pass
- **Needs:** Manual verification that cursors now visually change in-game

If the sprite-based approach works, this file can be deleted and the checkpoint doc updated. If issues persist, further investigation needed.

---

## Next steps if this doesn't work

1. Check if the sprite is being obscured by other UI elements
2. Verify CanvasLayer layer 100 is above all other layers in the game
3. Check if get_viewport().get_mouse_position() returns correct coordinates
4. Try using a TextureRect inside a Control node instead of Sprite2D
