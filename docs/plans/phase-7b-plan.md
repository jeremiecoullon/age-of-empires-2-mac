# Phase 7B: Walls + Gates + Wall Dragging + AI Defense

## Context

Phase 7A (Garrison System + Outpost + Watch Tower + Town Bell) is complete. Phase 7B adds defensive walls, gates with auto-open/lock mechanics, and a wall drag-placement system for building wall lines.

**Phase 8 look-ahead:** Fortified Wall (Stone Wall upgrade, 3000 HP) researched at University. Stone Wall just needs to support HP upgrade — no special architecture now. Guard Tower is a Watch Tower upgrade. Neither requires structural changes in 7B.

## Refactoring identified

None needed. Wall dragging is a new code path alongside existing single-click placement — no modification of existing placement logic required.

## AoE2 specs

| Entity | Age | Cost | HP | Armor (M/P) | Notes |
|--------|-----|------|----|-------------|-------|
| Palisade Wall | Dark | 2W | 250 | 0/0 | No attack, no garrison |
| Stone Wall | Feudal | 5S | 1800 | 8/10 | No attack, no garrison |
| Gate | Feudal | 30S | 2750 | 6/6 | Auto-open for friendlies, lock/unlock |

Walls/gates don't count for age advancement or conquest victory (already handled — not in `AGE_QUALIFYING_GROUPS`).

## Sprites

All exist in `images/AoE-all_sprites/Buildings/`:
- `Woodwall1.png` → `assets/sprites/buildings/palisade_wall_aoe.png`
- `Stonewall1.png` → `assets/sprites/buildings/stone_wall_aoe.png`
- `Gate1.png` → `assets/sprites/buildings/gate_aoe.png`

---

## Implementation steps

### Step 1: Copy sprites
Copy the 3 PNGs from `images/AoE-all_sprites/Buildings/` to `assets/sprites/buildings/`.

### Step 2: Palisade Wall building
**Create:** `scripts/buildings/palisade_wall.gd`, `scenes/buildings/palisade_wall.tscn`
- Follow outpost pattern (simplest 1x1 building)
- Stats: 2W, 250HP, size 1x1, build_time 5s, sight_range 64px (2 tiles)
- Groups: "palisade_walls", "walls"
- No attack, no garrison, no special behavior

### Step 3: Stone Wall building
**Create:** `scripts/buildings/stone_wall.gd`, `scenes/buildings/stone_wall.tscn`
- Same pattern as palisade wall
- Stats: 5S, 1800HP, melee_armor 8, pierce_armor 10, build_time 10s, sight_range 64px
- Groups: "stone_walls", "walls"

### Step 4: Gate building
**Create:** `scripts/buildings/gate.gd`, `scenes/buildings/gate.tscn`
- Stats: 30S, 2750HP, melee_armor 6, pierce_armor 6, build_time 70s, sight_range 96px
- Groups: "gates", "walls"
- Properties: `is_locked: bool`, `is_open: bool`
- Auto-open: in `_process()`, throttled every 0.3s, scan units within 64px (2 tiles). Friendly unit nearby + not locked → open (disable CollisionShape2D). No friendlies → close.
- `toggle_lock()`: flip is_locked, force close if locking
- `_open_gate()` / `_close_gate()`: toggle CollisionShape2D.disabled via set_deferred

### Step 5: GameManager age requirements
**Modify:** `scripts/game_manager.gd`
- Add `"stone_wall": AGE_FEUDAL` and `"gate": AGE_FEUDAL` to `BUILDING_AGE_REQUIREMENTS`
- Palisade wall = Dark Age (default, no entry needed)

### Step 6: main.gd — enum, scene paths, sizes
**Modify:** `scripts/main.gd`
- Add scene path constants: `PALISADE_WALL_SCENE_PATH`, `STONE_WALL_SCENE_PATH`, `GATE_SCENE_PATH`
- Add to `BuildingType` enum: `PALISADE_WALL`, `STONE_WALL`, `GATE`
- Add to `_get_building_size()`: all three return `Vector2(32, 32)`

### Step 7: main.gd — wall drag placement mechanic
**Modify:** `scripts/main.gd`

This is the most complex part. New variables:
```
var is_wall_placement: bool = false
var wall_drag_active: bool = false
var wall_drag_start: Vector2 = Vector2.ZERO
var wall_ghosts: Array[Sprite2D] = []
var wall_scene_path: String = ""
```

New functions:
- `start_palisade_wall_placement()` / `start_stone_wall_placement()`: set `is_wall_placement = true`, `wall_scene_path`, create initial ghost, set `current_building_type`
- `_handle_wall_placement_input(event)`: separate from existing `_handle_building_placement_input`
  - MouseButton LEFT pressed → record `wall_drag_start` (snapped to grid), `wall_drag_active = true`
  - MouseMotion while drag active → compute L-shaped path, update ghost array
  - MouseButton LEFT released → validate all positions, check total cost, place segments, assign builders
  - RIGHT/ESC → cancel
- `_compute_wall_path(start, end) -> Array[Vector2]`: L-shaped (horizontal first, then vertical). Work in snapped tile-center coordinates.
- `_update_wall_ghosts(positions)`: reuse/create/remove ghost sprites to match position array. Skip positions with existing buildings.
- `_clear_wall_ghosts()`: free all ghost sprites
- `_place_wall_segments()`: instantiate one building per position, check+spend total cost (all-or-nothing), start construction on each, assign selected villagers to first segment

Route in `_unhandled_input`: if `GameManager.is_placing_building` and `is_wall_placement` → call `_handle_wall_placement_input` instead of `_handle_building_placement_input`.

### Step 8: main.gd — gate single-click placement
**Modify:** `scripts/main.gd`
- `start_gate_placement()`: standard single-click pattern (like outpost), NOT wall drag
- Gate uses existing `_handle_building_placement_input` and `_place_building()` — no special handling needed

### Step 9: HUD — build buttons + gate controls
**Modify:** `scripts/ui/hud.gd`, `scenes/ui/hud.tscn`
- Add 3 buttons to ActionGrid: `BuildPalisadeWallButton`, `BuildStoneWallButton`, `BuildGateButton`
- Add `LockGateButton` for gate lock/unlock
- Add `@onready` refs in hud.gd, add to `build_buttons` array
- Connect signals to main.gd placement functions
- Gate panel: when selecting a friendly gate, show HP + lock/unlock button. Pattern: add to `show_garrison_building_panel` or create minimal gate-specific display.

### Step 10: main.gd — gate selection panel
**Modify:** `scripts/main.gd`
- In building selection logic (where TC, barracks, etc. are handled), add gate case showing lock/unlock button via HUD

### Step 11: AI — game state entries
**Modify:** `scripts/ai/ai_game_state.gd`
- Add scene preloads: `PALISADE_WALL_SCENE`, `STONE_WALL_SCENE`, `GATE_SCENE`
- Add `BUILDING_COSTS` entries: `"palisade_wall": {"wood": 2}`, `"stone_wall": {"stone": 5}`, `"gate": {"stone": 30}`
- Add `BUILDING_SIZES` entries: all `Vector2(32, 32)`
- Add building count group mappings: `"palisade_wall" → "palisade_walls"`, etc.
- Add `_get_building_scene()` and `_get_ai_building()` match cases

### Step 12: AI — BuildPalisadeWallRule
**Modify:** `scripts/ai/ai_rules.gd`
- New `BuildPalisadeWallRule`: conditions = 3+ min game time, has barracks, < 5 existing walls, can afford. Actions = build one palisade_wall segment near base.
- Register in `create_all_rules()`
- Simple approach: AI places individual wall segments (not drag lines). The expanding-ring placement naturally puts them near the base.

### Step 13: AI — controller updates
**Modify:** `scripts/ai/ai_controller.gd`
- Register BuildPalisadeWallRule
- Add `"build_palisade_wall"` to `key_rules` in `_get_rule_blockers()`
- Add skip reason in `_get_rule_skip_reason()`
- Add `palisade_wall_count`, `stone_wall_count`, `gate_count` to `_print_debug_state()`

### Step 14: Observability
**Modify:** `scripts/testing/ai_test_analyzer.gd`
- Add `first_palisade_wall` milestone
- Add `"palisade_wall"` to building_types array
- Add milestone check in `_check_milestones()`

**Modify:** `scripts/logging/game_state_snapshot.gd`
- Add `palisade_wall`, `stone_wall`, `gate` to `_capture_buildings()`

### Step 15: Post-7B checklist
- [ ] Run `godot --headless --import --path .` to register new assets
- [ ] Run test suite
- [ ] Run spec-check agent on Palisade Wall, Stone Wall, Gate
- [ ] Run code-reviewer agent
- [ ] Run ai-observer agent
- [ ] Update `docs/gotchas.md` with Phase 7B learnings
- [ ] Write checkpoint doc `docs/phase_checkpoints/phase-7.0b.md`
- [ ] Signal for context clear

---

## Key implementation notes

1. **Wall segments are individual buildings.** Each tile = one Building instance. A 10-tile wall = 10 nodes. Fine for 60x60 map.

2. **Wall drag is a new code path.** `is_wall_placement` flag routes to `_handle_wall_placement_input()`. The existing `_handle_building_placement_input()` stays unchanged.

3. **L-shaped path:** Horizontal first, then vertical. Positions are snapped tile-center coordinates.

4. **Ghost sprite management during drag:** Reuse existing sprites by repositioning. Only create/free when array length changes. Skip positions that already have buildings.

5. **Gate collision toggle:** `CollisionShape2D.set_deferred("disabled", true/false)` controls passability. Units use NavigationAgent2D avoidance, not nav mesh, so this should work without nav mesh changes. Verify by testing.

6. **Gate unit scan throttle:** Use accumulator pattern (like TC/tower idle scan from 7A) — scan every 0.3s, not every frame.

7. **Builder assignment for wall drag:** All selected villagers assigned to first segment. No auto-chaining to next segment (simplification). Player can manually assign more villagers.

8. **Cost during drag:** Total cost = per_segment_cost * valid_positions.size(). All-or-nothing spending on mouse-up.

## Verification

1. **Import:** `godot --headless --import --path .`
2. **Tests:** `godot --headless --path . tests/test_scene.tscn`
3. **Manual play:** Drag-place palisade walls in Dark Age, place stone walls in Feudal, place gate, verify gate auto-opens for friendly units, test lock/unlock, verify walls block enemy movement
4. **Spec-check:** Run on Palisade Wall, Stone Wall, Gate
5. **AI observer:** Verify AI builds palisade wall segments
