# Phase 8: Advanced Defense & Siege

## Context

Phase 7B (Walls & Gates) is complete. The next phase adds University, building upgrades (Guard Tower, Fortified Wall), Siege Workshop, siege units (Battering Ram, Mangonel, Scorpion), and siege unit upgrades. This creates the attack/defense dynamic: walls/towers defend, siege breaks through.

**Imperial content deferred to Phase 9:** Keep, Siege Ram, Siege Onager, Chemistry, Architecture, Siege Engineers. Onager and Heavy Scorpion ARE implemented in Phase 8 but gated to AGE_IMPERIAL (buttons visible but locked until Phase 9 adds Imperial advancement).

---

## Sub-phase split

### 8A: University + Building Upgrade System + University Techs + AI
- University building (Castle Age, research-only like Blacksmith)
- **Building upgrade system** (new — in-place transformation like unit upgrades)
- Guard Tower (Watch Tower upgrade via University research)
- Fortified Wall (Stone Wall upgrade via University research)
- 4 Castle Age techs: Masonry, Murder Holes, Treadmill Crane, Ballistics
- AI: BuildUniversityRule, ResearchUniversityTechRule
- HUD refactor: `hide_all_panels()` (from 7B ISSUE-007)

### 8B: Siege Workshop + Siege Units + Upgrades + Ram Garrison + AI
- Siege Workshop building (Castle Age, requires Blacksmith)
- 3 siege units: Battering Ram, Mangonel, Scorpion
- 3 upgrades: Capped Ram (Castle), Onager (Imperial), Heavy Scorpion (Imperial)
- Area damage mechanic (Mangonel), pass-through mechanic (Scorpion)
- Ram garrison (4 infantry can garrison inside rams)
- AI: BuildSiegeWorkshopRule, siege training rules

---

## Phase 8A: Detailed plan

### Refactoring

1. **`hide_all_panels()` in HUD** — Extract 9+ repeated `hide_*_panel()` calls into one method. Required before adding 2 more panels.

### Building upgrade system design

Mirror the unit upgrade system from Phase 5B:
- Add `"type": "building_upgrade"` entries to TECHNOLOGIES dict
- Add `_apply_building_upgrade(tech_id, team_id)` to GameManager — iterates all buildings in `from_group`, applies `new_stats` via `set()`, swaps groups, updates `building_name`
- Buildings call `_apply_researched_building_upgrades()` in `_ready()` so new buildings placed after upgrade auto-apply
- Handle current_hp scaling: increase current_hp by (new_max_hp - old_max_hp) delta

Guard Tower does NOT create a new scene — it reuses watch_tower.gd/tscn. Only stats change (HP 1020→1500, attack 5→6). Same for Fortified Wall reusing stone_wall.

### Ordered feature list

**Step 1: HUD `hide_all_panels()` refactor**
- `scripts/ui/hud.gd` — Extract all hide calls, use everywhere

**Step 2: University building**
- Create: `scripts/buildings/university.gd`, `scenes/buildings/university.tscn`
- Pattern: Follows Blacksmith (research-only, no training)
- Sprite: `images/AoE-all_sprites/Buildings/University1.png` → `assets/sprites/buildings/university_aoe.png`, scale 0.5
- Stats: 200W, 2100HP, Castle Age, 3x3 (96x96px)
- Modify: `game_manager.gd` (age req), `main.gd` (BuildingType enum, size, placement), `hud.gd` (build button + selection panel)

**Step 3: University techs in TECHNOLOGIES dict**
- `game_manager.gd` — Add 6 tech entries:
  - `"masonry"`: Castle, 175W+150S, building HP/armor bonus
  - `"murder_holes"`: Castle, 200F+200S, removes tower minimum range
  - `"treadmill_crane"`: Castle, 200W+300S, +20% build speed
  - `"ballistics"`: Castle, 300W+175G, improved accuracy (no-op for now — hitscan combat)
  - `"guard_tower"`: Castle, building_upgrade, Watch Tower → Guard Tower
  - `"fortified_wall"`: Castle, building_upgrade, Stone Wall → Fortified Wall

**Step 4: Building upgrade system in GameManager**
- `_apply_building_upgrade(tech_id, team_id)` — iterate `from_group` buildings, apply stats, swap groups
- In `complete_tech_research()` — dispatch to `_apply_building_upgrade()` for `"building_upgrade"` type

**Step 5: Building tech bonus system**
- `building.gd` — Add `_base_max_hp`, `_base_melee_armor`, `_base_pierce_armor` fields
- `apply_building_tech_bonuses()` — recalculate from base + Masonry bonuses
- Connect to `tech_researched` signal for live updates
- `_apply_researched_building_upgrades()` — check for Guard Tower / Fortified Wall upgrades on spawn

**Step 6: Tech effect integration**
- `watch_tower.gd` — Murder Holes: skip min range check if tech researched; call `_apply_researched_building_upgrades()` in `_ready()`
- `stone_wall.gd` — call `_apply_researched_building_upgrades()` in `_ready()`
- `building.gd` — Treadmill Crane: multiply build speed by 1.2 in `progress_construction()`

**Step 7: University HUD panel**
- `hud.gd` — `show_university_panel()` with 6 tech buttons (Masonry, Murder Holes, Treadmill Crane, Ballistics, Guard Tower, Fortified Wall)
- Follow Blacksmith panel pattern

**Step 8: AI rules**
- `ai_rules.gd` — `BuildUniversityRule` (Castle Age, 15+ vills), `ResearchUniversityTechRule` (priority-based tech selection)
- `ai_game_state.gd` — UNIVERSITY_SCENE preload, costs, sizes, `_get_ai_university()`, building count mapping
- `ai_controller.gd` — key_rules, skip reasons, debug state

**Step 9: Observability**
- `ai_test_analyzer.gd` — `first_university` milestone
- `game_state_snapshot.gd` — university building count

### Key specs (from AoE2 manual)

| Tech | Age | Cost | Effect |
|------|-----|------|--------|
| Masonry | III | 175W, 150S | +10% building HP, +1/+1 armor, +3 LOS |
| Murder Holes | III | 200F, 200S | No minimum tower range |
| Treadmill Crane | III | 200W, 300S | +20% villager build speed |
| Ballistics | III | 300W, 175G | Track moving targets (no-op until projectile system) |
| Guard Tower | III | ~100F, 250W | Watch Tower → 1500HP, 6 attack |
| Fortified Wall | III | ~200F, 100S | Stone Wall → 3000HP |

### Post-phase checklist
- [ ] Spec-check: University, Guard Tower, Fortified Wall
- [ ] `godot --headless --import --path .`
- [ ] Run test suite
- [ ] Code-reviewer agent
- [ ] Test agent
- [ ] AI-observer agent
- [ ] Update gotchas.md
- [ ] Write checkpoint `docs/phase_checkpoints/phase-8.0a.md`

---

## Phase 8B: Detailed plan

### Siege Workshop building
- Create: `scripts/buildings/siege_workshop.gd`, `scenes/buildings/siege_workshop.tscn`
- Pattern: Follows Barracks (training building with production queue + research for upgrades)
- Sprite: `images/AoE-all_sprites/Buildings/Siegeworkshop1.png` → `assets/sprites/buildings/siege_workshop_aoe.png`, scale 0.5
- Stats: 200W, 2100HP, Castle Age, 3x3, garrison_capacity=10
- **Prerequisite:** Must have Blacksmith to build (per AoE2 manual)

### Siege units

| Unit | Cost | HP | Atk | Armor | Range | Speed | Special |
|------|------|----|-----|-------|-------|-------|---------|
| Battering Ram | 160W, 75G | 175 | 2 | 0/180 | 0 (melee) | ~50 | Bonus vs buildings; garrison 4 infantry |
| Mangonel | 160W, 135G | 50 | 40 | 0/6 | 224px (7 tiles) | ~60 | Area damage (48px radius), friendly fire, min range 96px |
| Scorpion | 75W, 75G | 40 | 12 | 0/6 | 160px (5 tiles) | ~60 | Pass-through bolt hits all enemies in line |

### Siege unit upgrades

| Upgrade | Age | Building | Cost | New stats |
|---------|-----|----------|------|-----------|
| Capped Ram | Castle | Siege Workshop | 300F | 200HP, 3atk, 0/190 armor |
| Onager | Imperial | Siege Workshop | 800F, 500G | 60HP, 50atk, 0/7, range 256px |
| Heavy Scorpion | Imperial | Siege Workshop | 1000F, 800W | 50HP, 16atk, 0/7 |

### Ordered feature list

**Step 1: Siege Workshop building**
- Create script + scene (Barracks pattern)
- Blacksmith prerequisite check in `can_build()` and HUD
- Modify: `game_manager.gd`, `main.gd`, `hud.gd`

**Step 2: Battering Ram unit**
- Create: `scripts/units/battering_ram.gd`, `scenes/units/battering_ram.tscn`
- Groups: "military", "siege", "battering_rams"
- Sprite: `images/AoE-all_sprites/Units/Battering Ram/Stand/` → `assets/sprites/units/battering_ram_frames/` (5 frames, single-direction animation)
- **Rams only attack buildings and siege** — command_attack rejects regular units, no auto-aggro on units
- Bonus vs buildings: ~+125 bonus damage
- Infantry get bonus vs rams: add "rams" group, spearman/militia get bonus_vs_rams

**Step 3: Ram garrison mechanic**
- Add garrison to battering_ram.gd directly (not extracted to base class — only rams need unit-garrison)
- `garrison_capacity = 4`, only foot infantry can garrison
- `ungarrison_all()` on ram death ejects units
- main.gd: right-click friendly ram with infantry selected → garrison command

**Step 4: Mangonel unit (area damage)**
- Create: `scripts/units/mangonel.gd`, `scenes/units/mangonel.tscn`
- Groups: "military", "siege", "mangonels"
- Sprite: `images/AoE-all_sprites/Units/Mangonel/Stand Ground/` (5 frames, single-direction)
- Area damage: on attack, deal full damage to target + 50% to all units/buildings within 48px radius
- **Friendly fire** — hits own units in radius (faithful to AoE2)
- Minimum range: 96px (3 tiles)
- Attack cooldown: ~6s

**Step 5: Scorpion unit (pass-through damage)**
- Create: `scripts/units/scorpion.gd`, `scenes/units/scorpion.tscn`
- Groups: "military", "siege", "scorpions"
- Sprite: `images/AoE-all_sprites/Units/Scorpion/Stand Ground/` (5 frames, single-direction)
- Pass-through: trace line from scorpion through target, damage all enemies within ~20px of line
- No minimum range, no friendly fire

**Step 6: Siege unit upgrades in TECHNOLOGIES**
- `game_manager.gd` — 3 entries with `"type": "unit_upgrade"` following Phase 5B pattern
- Capped Ram (Castle), Onager (Imperial), Heavy Scorpion (Imperial)

**Step 7: Siege Workshop training + research**
- `siege_workshop.gd` — `train_battering_ram()`, `train_mangonel()`, `train_scorpion()` + production queue
- Research system for 3 upgrades (inherits from Building base)
- `_process()`: research > training priority

**Step 8: HUD updates**
- Siege Workshop build button, selection panel with train + upgrade buttons
- Age-gating display (Onager/Heavy Scorpion show "Requires Imperial Age")
- Siege unit info in info panel

**Step 9: Building base class — exclude siege from garrison**
- `building.gd` `can_garrison()` — reject units in "siege" group

**Step 10: AI siege rules**
- `BuildSiegeWorkshopRule`: Castle Age, have blacksmith, have barracks, 15+ vills
- `TrainBatteringRamRule`: build rams when enemy has walls/towers
- `TrainMangonelRule`: when enemy has massed infantry/archers
- `TrainScorpionRule`: when enemy has massed units
- AI game state: siege workshop support, siege unit training, enemy building counts

**Step 11: Observability**
- Milestones: first_siege_workshop, first_battering_ram, first_mangonel
- Snapshots: siege_workshop building, siege unit counts

### Key implementation notes

1. **Siege units don't benefit from Blacksmith techs** — no infantry_attack, cavalry_attack, archer_attack bonuses. Their `apply_tech_bonuses()` should be empty/minimal.
2. **All siege sprites are 5 frames** — use single-direction animation, not 8-dir.
3. **Rams can ONLY attack buildings and siege** — not regular units. This is AoE2 accurate.
4. **Mangonel friendly fire** creates tactical depth — can't fire into melee.
5. **Siege units are slow** (~50-60 speed vs ~100 normal). They're in "siege" group.
6. **Building garrison excludes siege** — add check in `can_garrison()`.
7. **Blacksmith prerequisite for Siege Workshop** — check in both HUD and AI `can_build()`.
8. **Onager/Heavy Scorpion gated to Imperial** — visible but locked until Phase 9.

### Post-phase checklist
- [ ] Spec-check: Siege Workshop, Battering Ram, Mangonel, Scorpion, Capped Ram, Onager, Heavy Scorpion
- [ ] `godot --headless --import --path .`
- [ ] Run test suite
- [ ] Code-reviewer agent
- [ ] Test agent
- [ ] AI-observer agent
- [ ] Update gotchas.md
- [ ] Write checkpoint `docs/phase_checkpoints/phase-8.0b.md`

---

## Critical files

| File | Changes |
|------|---------|
| `scripts/game_manager.gd` | Building upgrade system, TECHNOLOGIES entries, age requirements |
| `scripts/buildings/building.gd` | Building tech bonuses, `_apply_researched_building_upgrades()`, Treadmill Crane, siege garrison exclusion |
| `scripts/buildings/watch_tower.gd` | Murder Holes integration, building upgrade support |
| `scripts/buildings/stone_wall.gd` | Building upgrade support |
| `scripts/main.gd` | BuildingType enum entries, placement, siege commands |
| `scripts/ui/hud.gd` | `hide_all_panels()`, University panel, Siege Workshop panel |
| `scripts/ai/ai_game_state.gd` | New building/unit support |
| `scripts/ai/ai_rules.gd` | 6+ new rules |
| `scripts/ai/ai_controller.gd` | Rule registration, skip reasons |

## Verification

1. `godot --headless --import --path .` (catches scene errors)
2. `godot --headless --path . tests/test_scene.tscn` (all tests pass)
3. Spec-check agent on all new entities
4. AI-observer agent (AI builds university, researches techs, builds siege)
5. Manual playtest: build university → research Guard Tower → see towers upgrade; build siege workshop → train ram → attack enemy walls
