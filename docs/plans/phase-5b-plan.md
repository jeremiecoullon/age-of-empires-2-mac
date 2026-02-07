# Phase 5B: Unit Upgrade System + Knight — Implementation Plan

## Context

Phase 5A (tech research + Blacksmith + Loom) is complete. 496 tests pass. The game has a working tech system with per-team bonuses applied via signal. Phase 5B adds the unit upgrade system (7 upgrades through Castle Age), the Knight as a new unit, and AI rules for upgrading and training Knights. Imperial upgrades deferred to Phase 9.

---

## Refactoring identified

**Fix Militia stats to AoE2 spec.** Current: 50HP/5atk. AoE2 manual: 40HP/4atk. Without this fix, Man-at-Arms (45HP/6atk) would be an HP *downgrade* from Militia, which makes the upgrade chain feel broken. This is a 2-line change in `militia.gd`.

No other refactoring needed. The generic research system in Building base class works for upgrade research.

---

## Architecture: how upgrades work

**Upgrades are entries in `GameManager.TECHNOLOGIES` with `"type": "unit_upgrade"`.** This reuses the entire existing research system (Building's `start_research()`, `cancel_research()`, `_process_research()`, `_complete_research()`) without modification. On `complete_tech_research()`, if the tech has type `"unit_upgrade"`, also call `_apply_unit_upgrade()` which transforms existing units in-place (change stats, swap groups, set display name).

**In-place transformation, not node replacement.** When an upgrade completes, all existing units of the base type get their stats overwritten, groups swapped, and display name changed. No new scenes/scripts needed per upgrade. Newly spawned units after the upgrade auto-apply it in `_ready()` via `_apply_researched_upgrades()`.

**Research blocks training.** Each training building checks `is_researching` before processing training in `_process()`. Matches AoE2 behavior.

---

## Upgrade definitions (AoE2 manual stats)

| Upgrade | From Group | Age | Building | Research Cost | HP | Atk | Armor | Range | Special |
|---------|-----------|-----|----------|--------------|-----|-----|-------|-------|---------|
| Man-at-Arms | militia | Feudal | barracks | 100F+40G | 45 | 6 | 0/0 | - | bonus vs buildings |
| Long Swordsman | man_at_arms | Castle | barracks | 200F+65G | 55 | 9 | 0/0 | - | bonus vs buildings |
| Pikeman | spearmen | Castle | barracks | 215F+90G | 55 | 4 | 1/0 | - | +22 bonus vs cavalry |
| Crossbowman | archers_line | Castle | archery_range | 125F+75G | 35 | 5 | 0/0 | 160px (5 tiles) | - |
| Elite Skirmisher | skirmishers | Castle | archery_range | 200W+100G | 35 | 3 | 0/4 | 160px (5 tiles) | +5 bonus vs archers |
| Heavy Cav Archer | cavalry_archers | Castle | archery_range | 900F+500G | 60 | 7 | 1/0 | 128px (4 tiles) | - |
| Light Cavalry | scout_cavalry | Castle | stable | 150F+50G | 60 | 7 | 0/2 | - | - |

**Knight (new unit, not an upgrade):** Castle Age, Stable, 60F+75G, 100HP, 10atk, 2/2 armor, melee, fast (140 speed).

**Chain dependency:** Long Swordsman requires Man-at-Arms. All others are first-in-line (no prerequisite).

---

## Implementation order (17 steps)

### Step 1: Fix Militia stats to AoE2 spec
**File:** `scripts/units/militia.gd`
- Change `attack_damage: int = 5` to `4`, `max_hp = 50` to `40`

### Step 2: Add upgrade entries to TECHNOLOGIES dict
**File:** `scripts/game_manager.gd`
- Add 7 upgrade entries to `TECHNOLOGIES` with `"type": "unit_upgrade"` plus fields: `from_group`, `to_group`, `to_name`, `new_stats`, `chain_from` (empty string or prerequisite upgrade_id)
- The `requires` field (existing) handles chain: Long Swordsman `requires: "man_at_arms"`
- The `effects` field is `{}` for upgrades (stat changes go in `new_stats`)

### Step 3: Upgrade application in GameManager
**File:** `scripts/game_manager.gd`
- Add `_apply_unit_upgrade(tech_id, team)` — iterates units in `from_group` on that team, applies new_stats, swaps groups, sets display name
- Modify `complete_tech_research()` — after existing logic, check if `type == "unit_upgrade"` and call `_apply_unit_upgrade()`
- HP handling: if new max_hp > old, increase current_hp by delta. If new max_hp < old, clamp current_hp.
- After stat changes: call `unit._store_base_stats()` then `unit.apply_tech_bonuses()`
- Add `"knight": AGE_CASTLE` to `UNIT_AGE_REQUIREMENTS`
- Update `reset()` to clear upgrade state

### Step 4: Unit base class upgrade support
**File:** `scripts/units/unit.gd`
- Add `var unit_display_name: String = ""`
- Add `_apply_researched_upgrades()` — called in unit `_ready()` before `_store_base_stats()`. Loops through TECHNOLOGIES for unit_upgrade entries, applies any researched upgrades matching this unit's groups. Handles chains (loop until no more apply).

### Step 5: Add "archers_line" group to Archer
**File:** `scripts/units/archer.gd`
- Add `add_to_group("archers_line")` in `_ready()`. Needed because "archers" group includes skirmishers and cavalry archers — Crossbowman upgrade must only target archers.

### Step 6: Update all upgradeable unit subclasses
**Files:** `militia.gd`, `spearman.gd`, `archer.gd`, `skirmisher.gd`, `scout_cavalry.gd`, `cavalry_archer.gd`
- Add `_apply_researched_upgrades()` call between stat setup and `_store_base_stats()` in each `_ready()`

### Step 7: Knight unit (new)
**New files:**
- `scripts/units/knight.gd` — extends Unit, melee cavalry pattern (copy from scout_cavalry). Groups: military, cavalry, knights. Stats: 100HP, 10atk, 2/2 armor, speed 140, range 30 (melee). Tech bonuses: cavalry_attack.
- `scenes/units/knight.tscn` — CharacterBody2D + AnimatedSprite2D + CollisionShape2D + NavigationAgent2D + SelectionIndicator
- `assets/sprites/units/knight.svg` — mounted figure with shield, distinct from scout cavalry

### Step 8: Knight training in Stable
**File:** `scripts/buildings/stable.gd`
- Add KNIGHT to TrainingType enum
- Add `const KNIGHT_FOOD_COST: int = 60`, `KNIGHT_GOLD_COST: int = 75`, `KNIGHT_TRAIN_TIME: float = 6.0`
- Add `const KNIGHT_SCENE` (use `load()` initially, switch to `preload()` after import)
- Add `train_knight() -> bool` method
- Update `_get_current_train_time()`, `cancel_training()`, `_complete_training()` match blocks

### Step 9: Research integration in training buildings
**Files:** `barracks.gd`, `archery_range.gd`, `stable.gd`

Each building needs:
1. `_process()` — add research priority check before training: `if is_researching: _process_research(delta); return`
2. Override `_complete_research()` — call `super._complete_research()`, then resume training if queue waiting
3. Override `_destroy()` — cancel active research before `super._destroy()`

### Step 10: HUD upgrade buttons for Barracks
**Files:** `scripts/ui/hud.gd`, `scenes/ui/hud.tscn`
- Add 3 upgrade buttons to barracks panel: Man-at-Arms, Long Swordsman, Pikeman
- Button states: available (show cost), researched ("[Done]"), locked (show age/prereq), can't afford (disabled)
- On press: `selected_building.start_research(upgrade_id)`
- Update `_show_barracks_buttons()` and `_update_barracks_button_states()`

### Step 11: HUD upgrade buttons for Archery Range
**Files:** `scripts/ui/hud.gd`, `scenes/ui/hud.tscn`
- Add 3 upgrade buttons: Crossbowman, Elite Skirmisher, Heavy Cavalry Archer
- Same pattern as barracks

### Step 12: HUD upgrade + train buttons for Stable
**Files:** `scripts/ui/hud.gd`, `scenes/ui/hud.tscn`
- Add 1 upgrade button: Light Cavalry
- Add Knight train button (age-gated to Castle)
- Wire `train_knight` to `stable.train_knight()`

### Step 13: HUD display names for upgraded units
**File:** `scripts/ui/hud.gd`
- In `show_info()`, use `unit.unit_display_name` when set (for Man-at-Arms, Long Swordsman, etc.)
- Add Knight case: `elif entity is Knight: _show_military_info(entity, "Knight")`
- Show research progress for training buildings (same pattern as Blacksmith)

### Step 14: AI TrainKnightRule
**File:** `scripts/ai/ai_rules.gd`
- Conditions: Castle Age, has stable, can afford 60F+75G, not saving for age, has >= 3 military
- Actions: `gs.train("knight")`

### Step 15: AI ResearchUnitUpgradeRule
**File:** `scripts/ai/ai_rules.gd`
- Single rule that picks the best available upgrade based on army composition
- Priority: upgrade the unit type the AI has most of
- Check: building exists, not already researching, age met, can afford, not saving for age
- Actions: `gs.research_tech(upgrade_id)` (reuses existing research action)

### Step 16: AI game state + controller updates
**File:** `scripts/ai/ai_game_state.gd`
- Add knight to `can_train`/`get_can_train_reason`/`_do_train` (cost: 60F+75G, building: stable)
- Add knight to `get_unit_count` (group: "knights")
- Update `_do_research()` to handle barracks/archery_range/stable (currently only blacksmith + tc)

**File:** `scripts/ai/ai_controller.gd`
- Register TrainKnightRule and ResearchUnitUpgradeRule
- Add skip reasons for train_knight, research_unit_upgrade
- Add knight to AI_STATE military dict
- Add upgrade research status to AI_STATE tech dict

### Step 17: Observability
**File:** `scripts/testing/ai_test_analyzer.gd`
- Add milestones: `first_knight`, `first_unit_upgrade`

**File:** `scripts/logging/game_state_snapshot.gd`
- Add knight + all upgrade groups (man_at_arms, long_swordsman, pikemen, crossbowmen, elite_skirmishers, heavy_cavalry_archers, light_cavalry) to military snapshot

---

## Key gotchas

1. **Militia stat fix required first** — without it, Man-at-Arms is an HP downgrade (50→45)
2. **Crossbowman needs "archers_line" group** on Archer — "archers" group includes skirmishers and cav archers
3. **Chained upgrades**: militia spawned after both Man-at-Arms + Long Swordsman researched must apply both in order — `_apply_researched_upgrades()` loop handles this
4. **Elite Skirmisher cost is 200W+100G** (wood, not food) — unusual among upgrades
5. **Research blocks training** in the building — check `is_researching` first in `_process()`
6. **Building destruction during upgrade research must refund** — override `_destroy()`
7. **Use `load()` for knight assets initially** until import, then switch to `preload()`
8. **Pikeman bonus vs cavalry increases from +15 to +22** — must update `bonus_vs_cavalry` field
9. **Group swap means AI unit counts change** — `get_unit_count("militia")` returns 0 after Man-at-Arms researched; AI training rules need to check total infantry count

---

## Files created

| File | Type |
|------|------|
| `scripts/units/knight.gd` | Unit script |
| `scenes/units/knight.tscn` | Unit scene |
| `assets/sprites/units/knight.svg` | SVG placeholder |

## Files modified

| File | Changes |
|------|---------|
| `scripts/game_manager.gd` | 7 upgrade entries in TECHNOLOGIES, `_apply_unit_upgrade()`, knight age requirement, reset |
| `scripts/units/unit.gd` | `unit_display_name`, `_apply_researched_upgrades()` |
| `scripts/units/militia.gd` | Fix stats to 40HP/4atk, add `_apply_researched_upgrades()` call |
| `scripts/units/spearman.gd` | Add `_apply_researched_upgrades()` call |
| `scripts/units/archer.gd` | Add "archers_line" group, add `_apply_researched_upgrades()` call |
| `scripts/units/skirmisher.gd` | Add `_apply_researched_upgrades()` call |
| `scripts/units/scout_cavalry.gd` | Add `_apply_researched_upgrades()` call |
| `scripts/units/cavalry_archer.gd` | Add `_apply_researched_upgrades()` call |
| `scripts/buildings/barracks.gd` | Research priority in `_process`, `_destroy` + `_complete_research` overrides |
| `scripts/buildings/archery_range.gd` | Same pattern |
| `scripts/buildings/stable.gd` | Same + Knight training |
| `scripts/ui/hud.gd` | Upgrade buttons for 3 buildings, Knight button, display names, research progress |
| `scenes/ui/hud.tscn` | New upgrade + Knight buttons |
| `scripts/ai/ai_rules.gd` | TrainKnightRule, ResearchUnitUpgradeRule |
| `scripts/ai/ai_game_state.gd` | Knight training, upgrade research for training buildings |
| `scripts/ai/ai_controller.gd` | Register rules, skip reasons, AI_STATE updates |
| `scripts/testing/ai_test_analyzer.gd` | Knight + upgrade milestones |
| `scripts/logging/game_state_snapshot.gd` | Knight + upgrade groups in military snapshot |
| `tests/helpers/test_spawner.gd` | `spawn_knight` |
| `tests/test_main.gd` | Register new test suite |
| `docs/gotchas.md` | Phase 5B learnings, Knight in missing sprites |

---

## Post-phase checklist

1. Self-report context friction in checkpoint doc
2. Run code-reviewer agent
3. Run test agent → update checkpoint "Test Coverage"
4. Run ai-observer agent → add to checkpoint "AI Behavior Tests"
5. Update `docs/gotchas.md` with Phase 5B learnings
6. Write `docs/phase_checkpoints/phase-5.0b.md`
7. Run spec-check on Knight + all upgrade stats
8. Verify game launches and plays

## Verification

1. `/Applications/Godot.app/Contents/MacOS/Godot --headless --import --path .`
2. `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . tests/test_scene.tscn`
3. Spec-check on Knight and all 7 upgrades
4. AI observer test (focus: does AI research upgrades, train knights)
5. Manual: advance to Feudal, research Man-at-Arms at barracks, verify militia transform. Advance to Castle, research Long Swordsman, verify chain upgrade. Train Knight at stable.
