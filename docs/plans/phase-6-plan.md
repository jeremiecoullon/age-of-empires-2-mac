# Phase 6: Monks, Relics & Monastery

## Context

Phase 5B (Unit Upgrades + Knight) is complete. Phase 6 adds the Monastery building, Monk unit with healing/conversion mechanics, relics with garrisoning/gold generation, relic victory condition, and 7 monastery technologies. This creates a new tactical dimension and an alternative victory condition.

## Refactor check

No refactoring needed. The building training pattern (Stable/Barracks/ArcheryRange) is established by DD-005 (explicit panels). Monastery follows the same pattern. The conversion immunity system uses forward-compatible group checks that will work when Phase 7 adds walls/gates.

## Sub-phase split

- **6A**: Monastery building + Monk unit + Healing + Conversion + basic AI + HUD
- **6B**: Relics + Relic Victory + Monk Technologies + full AI + observability

---

## Sub-phase 6A: Monastery + Monk + Healing + Conversion

### Sprite availability (verified)
- **Monk**: `images/AoE-all_sprites/Units/Monk/Stand Ground/` — 30 PNGs (8-dir idle)
- **Monastery**: `images/AoE-all_sprites/Buildings/Monastary1.png` (note spelling "Monastary")
- **Relic**: `images/AoE-all_sprites/Units/Relic/Relic 1 A.png` (Phase 6B)
- **Monk w. Relic**: `images/AoE-all_sprites/Units/Monk w. Relic/Stand/` — 5 PNGs (single-dir, Phase 6B)

### Step 1: Register Monastery & Monk in GameManager
**Modify:** `scripts/game_manager.gd`
- Add `"monastery": AGE_CASTLE` to `BUILDING_AGE_REQUIREMENTS`
- Add `"monk": AGE_CASTLE` to `UNIT_AGE_REQUIREMENTS`
- Add `"monasteries"` to `AGE_QUALIFYING_GROUPS[3]` (Imperial qualifying)
- Add `conversion_resistance` property handling to reset if needed

### Step 2: Monastery building
**Create:** `scripts/buildings/monastery.gd`, `scenes/buildings/monastery.tscn`
- Copy `Monastary1.png` → `assets/sprites/buildings/monastery_aoe.png`, scale 0.5
- Stats: 175 wood, 2100 HP, 3x3 tiles, Castle Age, build_time ~40s
- Group: "monasteries"
- Follow Stable pattern: TrainingType enum (MONK only), train_monk(), cancel_training(), _complete_training()
- Research system: inherit from Building base class (same as Blacksmith)
- Relic storage: `var garrisoned_relics: Array = []` — simple array for Phase 6B
- `_process()`: research priority > training (same as all training buildings)
- `_destroy()`: cancel research, refund queue, eject relics (Phase 6B)

### Step 3: Monastery sprites and scene setup
- Copy sprite, create .tscn with StaticBody2D + Sprite2D + CollisionShape2D (96x96 for 3x3)
- Run `godot --headless --import` to register asset

### Step 4: Monastery in build menu and placement
**Modify:** `scripts/main.gd`
- Add MONASTERY_SCENE constant, BuildingType entry, placement function
- Add monastery handling in `_start_selection()` for building click

**Modify:** `scripts/ui/hud.gd`, `scenes/ui/hud.tscn`
- Add BuildMonasteryButton in military build category (Castle Age building)
- Add monastery_panel with TrainMonkButton + CancelButton
- Show/hide logic following Blacksmith panel pattern
- Age-gating: grey out if not Castle Age

### Step 5: Monk unit
**Create:** `scripts/units/monk.gd`, `scenes/units/monk.tscn`
- Copy `Monk/Stand Ground/` frames → `assets/sprites/units/monk_frames/`
- `_load_directional_animations()` with 30 frames

**Stats (AoE2 spec):**
- 30 HP, 0 attack, 0/0 armor, speed 70.0, sight 352 (11 tiles)
- conversion_range: 288.0 (9 tiles), heal_range: 128.0 (4 tiles)
- heal_rate: 1.0 HP/sec per monk

**State machine:** `enum State { IDLE, MOVING, HEALING, CONVERTING }`

**Groups:** "units", "monks" — NOT "military" (monks don't auto-attack)

**Key properties:**
- `var heal_target: Node2D = null`
- `var conversion_target: Node2D = null`
- `var conversion_timer: float = 0.0`
- `var is_rejuvenating: bool = false`
- `var rejuvenation_timer: float = 0.0`
- `var rejuvenation_time: float = 62.0` (AoE2 base)
- `var carrying_relic: Node = null` (Phase 6B)
- `var conversion_resistance: float = 0.0` (base — scouts get 0.5)

**Conversion mechanic (`_process_converting()`):**
- Range check: if target moved out of range → follow (MOVING sub-state)
- Probability ramp: 0-4s = 0%, 4-10s = ~28%/sec, 10+ = guaranteed
- On success: change target team, re-color, update pop, enter rejuvenation
- Adjacency: buildings need distance < 48px (adjacent), regular units use 288px
- Immunity check via `can_convert(target) -> bool`:
  - Groups: "town_centers", "castles", "monasteries", "farms", "walls", "gates", "wonders", "fish_traps"
  - Same team (allied)
  - Monks (unless has_tech("atonement") — Phase 6B tech)
  - Buildings (unless has_tech("redemption") — Phase 6B tech)
  - Default: only villagers + non-siege military can be converted

**Healing mechanic (`_process_healing()`):**
- Auto-heal: in IDLE, check for nearby wounded friendlies every 0.5s
- Move to target if out of heal_range
- Heal rate: 1 HP/sec, capped at target.max_hp
- No rejuvenation needed
- Cannot heal buildings or siege
- Multiple monks stack linearly

**Commands:**
- `command_convert(target)`: set conversion_target, enter CONVERTING
- `command_heal(target)`: set heal_target, enter HEALING
- `move_to(pos)`: standard movement, clear targets

### Step 6: Conversion team-change logic
**Modify:** `scripts/units/monk.gd` (or helper in `game_manager.gd`)
- Change `target.team` to `monk.team`
- Re-apply team color: `target._apply_team_color()`
- Update population: remove from old team, add to new team
- If pop-capped on converting team: unit is lost (AoE2 behavior)
- Deselect from old owner if selected
- Re-store base stats + re-apply tech bonuses for new team

### Step 7: Scout Cavalry conversion resistance
**Modify:** `scripts/units/scout_cavalry.gd`
- Add `var conversion_resistance: float = 0.5` in `_ready()`
- This halves conversion probability when targeted

### Step 8: Right-click command dispatch for monks
**Modify:** `scripts/main.gd` `_issue_command()`
- Before the generic enemy attack dispatch, check for monks in selection:
  - Monk + enemy unit → `monk.command_convert(target)`, non-monks attack
  - Monk + friendly wounded unit → `monk.command_heal(target)`
- Mixed group: monks convert, military attacks (AoE2 behavior)

### Step 9: HUD info for monks
**Modify:** `scripts/ui/hud.gd`
- Unit info: show "Monk" name, HP, no attack stat, show conversion range
- Status text: "Healing", "Converting", "Rejuvenating"
- Monastery panel: train monk button with cost (100G), queue display, cancel button

### Step 10: AI rules for monastery and monk
**Modify:** `scripts/ai/ai_rules.gd`
- `BuildMonasteryRule`: Castle Age, no existing monastery, 15+ villagers, can afford
- `TrainMonkRule`: has monastery, 100G, monk count < 3, not saving for age

**Modify:** `scripts/ai/ai_game_state.gd`
- Add monastery scene (use `load()` not `preload()`), costs, sizes
- `can_train("monk")`, `get_can_train_reason("monk")`, `_do_train("monk")`
- `get_building_count("monastery")` support (just group query)
- `_get_ai_monastery()` helper

**Modify:** `scripts/ai/ai_controller.gd`
- Register new rules
- Add skip reasons: "no_monastery", "monk_limit", "saving_for_age"
- Update AI_STATE with monk count, monastery count

### Step 11: Post-6A checklist
- [ ] Run `godot --headless --import --path .` to register new assets
- [ ] Run test suite
- [ ] Run spec-check agent on Monk and Monastery
- [ ] Run code-reviewer agent
- [ ] Update `docs/gotchas.md` with Phase 6A learnings
- [ ] Write checkpoint doc `docs/phase_checkpoints/phase-6.0a.md`
- [ ] Signal for context clear

---

## Sub-phase 6B: Relics + Relic Victory + Monk Technologies + full AI

### Step 1: Relic object
**Create:** `scripts/objects/relic.gd`, `scenes/objects/relic.tscn`
- Copy `Relic 1 A.png` → `assets/sprites/objects/relic_aoe.png`
- Extends StaticBody2D or Area2D (need click detection, no physics)
- Groups: "relics" (NOT "resources")
- Properties: `is_carried`, `carrier`, `is_garrisoned`, `garrison_building`
- `func pickup(monk)`: hide sprite, set carrier
- `func drop(position)`: show sprite, clear carrier
- `func garrison(monastery)`: mark garrisoned
- Cannot be destroyed

### Step 2: Relic map spawning
**Modify:** `scripts/main.gd` or new `_spawn_relics()` function
- Spawn 5 relics at semi-random positions (neutral area, spread out)
- Minimum 300px between relics, avoid bases and resource clusters
- Add `_get_relic_at_position(pos)` for click detection

### Step 3: Monk relic carrying
**Modify:** `scripts/units/monk.gd`
- Add `CARRYING_RELIC` to state or use flag
- `command_pickup_relic(relic)`: move to relic, pick up on arrival
- When carrying: cannot convert or heal, can only move
- Swap sprite: load "Monk w. Relic" frames (5 PNGs, single-dir)
- On die(): `relic.drop(global_position)` before `super.die()`

### Step 4: Relic garrisoning in Monastery
**Modify:** `scripts/buildings/monastery.gd`
- `garrison_relic(relic) -> bool`: add to array, start gold generation
- Gold generation: 0.5 gold/sec per relic, fractional accumulator in `_process()`
- `get_relic_count() -> int`
- On destruction: drop all relics at monastery position

**Modify:** `scripts/main.gd` `_issue_command()`
- Monk carrying relic + right-click friendly monastery → garrison relic

### Step 5: Relic victory condition
**Modify:** `scripts/game_manager.gd`
- Add `var relic_victory_timer: float = 0.0`, `var relic_victory_team: int = -1`
- `const RELIC_VICTORY_TIME: float = 200.0` (game seconds)
- In `check_victory()` or new `_check_relic_victory()`:
  - Count garrisoned relics per team
  - If one team has ALL relics: start/continue countdown
  - If not: reset countdown
  - When countdown hits 200: that team wins
- Add signals: `relic_victory_countdown(team, time_remaining)`, `relic_victory_reset()`
- Timer uses `delta` (respects Engine.time_scale for tests)

**Modify:** `scripts/ui/hud.gd`
- Display relic victory countdown in top bar when active

### Step 6: Monastery technologies (7 techs)
**Modify:** `scripts/game_manager.gd` TECHNOLOGIES dict

| ID | Name | Age | Cost | Time | Effects |
|----|------|-----|------|------|---------|
| `fervor` | Fervor | Castle | 140G | 50s | `{"monk_speed": 15}` |
| `sanctity` | Sanctity | Castle | 120G | 60s | `{"monk_hp": 15}` |
| `redemption` | Redemption | Castle | 475G | 50s | `{"redemption": 1}` |
| `atonement` | Atonement | Castle | 325G | 40s | `{"atonement": 1}` |
| `illumination` | Illumination | Imperial | 120G | 65s | `{"illumination": 1}` |
| `faith` | Faith | Imperial | 750F+1000G | 60s | `{"faith": 1}` |
| `block_printing` | Block Printing | Imperial | 200G | 55s | `{"monk_range": 96}` |

Imperial techs (Illumination, Faith, Block Printing) defined but unresearchable until Phase 9.

**Modify:** `scripts/units/monk.gd` `apply_tech_bonuses()`
- Fervor: speed = base * 1.15 (if bonus > 0)
- Sanctity: max_hp = base + 15 (50% of 30)
- Block Printing: conversion_range = base + 96 (+3 tiles)
- Illumination: rejuvenation_time = base * 0.67 (50% faster)
- Redemption/Atonement: checked in `can_convert()` via `GameManager.has_tech()`

**Modify:** `scripts/units/unit.gd` `apply_tech_bonuses()`
- Faith: add 0.5 to conversion_resistance for all units on team with Faith researched

**Modify:** `scripts/ui/hud.gd`
- Monastery tech buttons following Blacksmith pattern
- Research progress bar, cancel button

### Step 7: Full AI behavior
**Modify:** `scripts/ai/ai_rules.gd`
- `CollectRelicsRule`: has idle monk, uncollected relics exist → send to collect + garrison
- `ConvertHighValueRule`: has idle non-rejuvenating monk, expensive enemy unit nearby → convert
- `ResearchMonasteryTechRule`: Sanctity > Fervor > Redemption > Atonement priority

**Modify:** `scripts/ai/ai_game_state.gd`
- `get_nearest_uncollected_relic()`, `get_idle_monk()`, `get_enemy_high_value_target()`
- `command_monk_collect_relic(monk, relic)`, `command_monk_convert(monk, target)`

**Modify:** `scripts/ai/ai_controller.gd`
- Register new rules, skip reasons, AI_STATE updates

### Step 8: Observability
**Modify:** `scripts/testing/ai_test_analyzer.gd`
- Milestones: `first_monk`, `first_relic_garrisoned`, `first_conversion`

**Modify:** `scripts/logging/game_state_snapshot.gd`
- Add monk to unit classification, add relic counts per team

### Step 9: Post-6B checklist
- [ ] Run import + test suite
- [ ] Run spec-check on all new entities/techs
- [ ] Run code-reviewer agent
- [ ] Run ai-observer agent (focus on relic collection)
- [ ] Update `docs/gotchas.md`
- [ ] Write checkpoint doc `docs/phase_checkpoints/phase-6.0b.md`
- [ ] Update `docs/roadmap.md` with sub-phase breakdown
- [ ] Verify game launches and plays correctly

---

## Key implementation notes

1. **Monks are NOT military**: "monks" group but NOT "military". Don't count for AI attack thresholds. Don't send with attack groups.

2. **Conversion probability model**: 0-4s = 0%, 4-10s = ~28%/sec, 10+ = guaranteed. Apply `conversion_resistance` as multiplier: `effective_chance = base_chance * (1.0 - target.conversion_resistance)`.

3. **Relic is NOT a resource**: "relics" group only. Villagers must not interact with them.

4. **Relic garrisoning != unit garrisoning**: Simple array on Monastery. Phase 7 adds full garrison system separately.

5. **Team change cleanup on conversion**: deselect from old owner, update pop, re-color, recalculate tech bonuses for new team.

6. **Forward-compatible immunity checks**: Use group names ("walls", "gates", "castles", "wonders") that don't exist yet — checks harmlessly return false.

7. **Use `load()` not `preload()` for new scenes** until after the import step.

8. **Monk w. Relic sprite has only 5 frames** — use single-direction animation, not 8-dir.

---

## Verification

1. **Import**: `godot --headless --import --path .`
2. **Tests**: `godot --headless --path . tests/test_scene.tscn`
3. **Manual play**: Build monastery in Castle Age, train monk, test healing on wounded friendlies, test conversion on enemy units, verify rejuvenation cooldown
4. **Spec-check**: Run on Monk unit and Monastery building
5. **AI observer**: Verify AI builds monastery, trains monks, collects relics (6B)
