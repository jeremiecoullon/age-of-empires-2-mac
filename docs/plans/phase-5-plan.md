# Phase 5: Tech Research & Upgrades — Implementation Plan

## Context

Phase 4 (Age System) is complete. 437 tests pass. The game has Dark → Feudal → Castle age progression with age-gating for buildings and units. Phase 5 adds the technology and upgrade system: Blacksmith building, 18 Blacksmith techs, Loom at TC, unit upgrade lines (Militia → Man-at-Arms → Long Swordsman, etc.), and the Knight as a new unit.

This is a large phase. Proposed split into two sub-phases.

---

## Sub-phase split

**5A: Tech research system + Blacksmith + Loom + Feudal/Castle Blacksmith techs**
- Core: Generic research system in Building base class + tech definitions in GameManager
- Blacksmith building (Feudal, 150W, 2100HP, researches attack/armor techs)
- Loom at TC (Dark Age, 50G, +15 villager HP, +1/+1 armor)
- 12 Blacksmith techs (6 Feudal + 6 Castle). Imperial techs deferred to Phase 9.
- Tech effect system: per-team bonuses applied to units via signal
- AI: BuildBlacksmithRule + ResearchBlacksmithTechRule + ResearchLoomRule
- Observability: AI_STATE logging, milestones, game state snapshots, skip reasons
- HUD: Blacksmith panel, Loom button in TC panel, research progress

**5B: Unit upgrade system + Knight + Castle-and-below unit upgrades**
- Unit upgrade system (research at training building → all existing units transform in-place)
- All unit upgrades through Castle Age: Man-at-Arms, Long Swordsman, Pikeman, Crossbowman, Elite Skirmisher, Heavy Cavalry Archer, Light Cavalry
- Knight (new Castle Age unit at Stable)
- Upgrade buttons in Barracks/Archery Range/Stable panels
- AI: Research upgrade rules based on army composition
- Observability: upgrade milestones, snapshot updates

**Imperial content deferred to Phase 9:** Two-Handed Swordsman, Champion, Arbalester, Cavalier, Paladin, Blast Furnace, Plate Mail Armor, Plate Barding Armor, Bracer, Ring Archer Armor. Update `docs/roadmap.md` Phase 9 to include these.

---

## 5A: Detailed implementation plan

### Refactoring identified

**Add generic research system to Building base class** (`scripts/buildings/building.gd`):
- Research logic (start, timer, cancel, complete, refund) would be duplicated across Blacksmith, TC (Loom), and training buildings (5B). Extract into Building base class (~50 lines).
- TC's existing age research stays separate (it blocks training, different signals). Loom at TC uses the new generic system.
- Pattern: `is_researching`, `research_timer`, `current_research_id`, `research_time`, `start_research()`, `cancel_research()`, `_process_research()`, `_complete_research()`, `get_research_progress()`, signal `research_completed`.

### Implementation order

#### 1. Tech definitions in GameManager
**File:** `scripts/game_manager.gd`

Add `TECHNOLOGIES` dict with 13 techs (12 Blacksmith + Loom). Imperial techs deferred to Phase 9. Each entry:
```
"forging": {
    "name": "Forging", "age": AGE_FEUDAL, "building": "blacksmith",
    "cost": {"food": 150}, "research_time": 50.0,
    "effects": {"infantry_attack": 1, "cavalry_attack": 1},
    "requires": ""  # prerequisite tech_id, empty if none
}
```

Per-team state:
- `player_researched_techs: Array[String]` / `ai_researched_techs: Array[String]`
- `player_tech_bonuses: Dictionary` / `ai_tech_bonuses: Dictionary` (additive bonuses recalculated from researched techs)

Signal: `tech_researched(team: int, tech_id: String)`

Helper methods:
- `has_tech(tech_id, team) -> bool`
- `can_research_tech(tech_id, team) -> bool` (not already researched, age met, prereq met, can afford)
- `spend_tech_cost(tech_id, team)` / `refund_tech_cost(tech_id, team)`
- `complete_tech_research(tech_id, team)` (adds to researched set, recalculates bonuses, emits signal)
- `get_tech_bonus(bonus_key, team) -> int`
- `_recalculate_tech_bonuses(team)` (sums effects of all researched techs)
- Reset in `reset()`

#### 2. Tech effect application in Unit
**File:** `scripts/units/unit.gd`

Add base stat storage:
- `var _base_attack_damage: int`, `_base_melee_armor: int`, `_base_pierce_armor: int`, `_base_max_hp: int`, `_base_attack_range: float`
- `func _store_base_stats()` — copies current stats to `_base_*` fields
- `func apply_tech_bonuses()` — recalculates stats from base + team bonuses

`apply_tech_bonuses()` logic:
- Check unit groups (infantry, cavalry, archers, villagers)
- Map group to bonus keys (infantry → infantry_attack, infantry_melee_armor, infantry_pierce_armor)
- Sum applicable bonuses from GameManager
- Apply: `attack_damage = _base_attack_damage + attack_bonus`, etc.
- Special: villager HP bonus increases both max_hp AND current_hp (by the diff)
- Special: archer_range bonus increases attack_range

Connect `GameManager.tech_researched` signal in `_ready()` to trigger `apply_tech_bonuses()`.

**All unit subclasses** need updating (called after setting stats in `_ready()`):
- `militia.gd`, `spearman.gd`, `archer.gd`, `skirmisher.gd`, `scout_cavalry.gd`, `cavalry_archer.gd`, `villager.gd`
- Pattern: after setting base stats, call `_store_base_stats()` then `apply_tech_bonuses()`

#### 3. Generic research system in Building
**File:** `scripts/buildings/building.gd`

Add after repair system (~50 lines):
```gdscript
# Research system
var is_researching: bool = false
var research_timer: float = 0.0
var current_research_id: String = ""
var research_time: float = 0.0
signal research_started(tech_id: String)
signal research_completed(tech_id: String)

func start_research(tech_id: String) -> bool
func cancel_research() -> bool
func _process_research(delta: float) -> bool
func _complete_research() -> void
func get_research_progress() -> float
```

`_destroy()` override: call `cancel_research()` if `is_researching` (refund resources).

#### 4. Blacksmith building
**New files:**
- `scripts/buildings/blacksmith.gd` — extends Building, uses generic research, group "blacksmiths"
- `scenes/buildings/blacksmith.tscn` — StaticBody2D + Sprite2D + CollisionShape2D (3x3)
- `assets/sprites/buildings/blacksmith.svg` — dark grey rectangle with anvil icon

Stats: 2100 HP, 150 wood, size 3x3, build_time 40s, Feudal Age.

`_process()` calls `_process_research(delta)`. `_destroy()` cancels active research.

`get_available_techs() -> Array[String]` — returns tech IDs where `building == "blacksmith"`.

#### 5. Age-gating for Blacksmith
**File:** `scripts/game_manager.gd`

Add to `BUILDING_AGE_REQUIREMENTS`: `"blacksmith": AGE_FEUDAL`

#### 6. Blacksmith placement in main.gd
**File:** `scripts/main.gd`

Add `start_blacksmith_placement()` following existing pattern (preload scene, ghost, placement validation). Add Blacksmith build button to villager build panel.

#### 7. Loom at Town Center
**File:** `scripts/buildings/town_center.gd`

Add Loom research button support. TC's `_process()` priority: age research > tech research (Loom) > training. Loom blocks training while researching (matches AoE2).

Use the generic `start_research("loom")` from Building base class. TC already has `_process()` — add `_process_research(delta)` check between age research and training.

#### 8. Blacksmith HUD panel
**File:** `scripts/ui/hud.gd` + `scenes/ui/hud.tscn`

Add `blacksmith_buttons: Array[Button]` array. Create buttons for the 6 Feudal-tier techs (always visible when Blacksmith selected). Castle/Imperial tier buttons appear when prerequisite is researched.

Button states:
- Available: enabled, shows cost
- Researched: disabled, shows "[Done]"
- Locked (wrong age): disabled, shows age name
- Locked (prerequisite): disabled, shows "Requires X"

Add research progress bar (reuse existing `train_progress` / `queue_label` pattern).

Add `selected_building_type = "blacksmith"` case to `_show_building_info()`.

#### 9. Loom button in TC panel
Add Loom button alongside Train Villager and Advance Age. Shows "[Done]" once researched. Shows research progress when active.

#### 10. Blacksmith build button
Add to villager build panel: "Build Blacksmith (150W)" button. Age-gated to Feudal.

#### 11. AI: BuildBlacksmithRule
**File:** `scripts/ai/ai_rules.gd`

Pattern: same as BuildArcheryRangeRule. Build when Feudal Age, has military buildings, can afford.

#### 12. AI: ResearchBlacksmithTechRule
**File:** `scripts/ai/ai_rules.gd`

Single rule that picks the best available tech to research. Priority:
1. Attack upgrades for existing army types (Forging if has infantry/cavalry, Fletching if has archers)
2. Armor upgrades for army types
3. Pause if should_save_for_age()

#### 13. AI: ResearchLoomRule
Research Loom early (when gold >= 50 and not saving for age). Low priority — many AoE2 players skip Loom in Dark Age.

#### 14. AI game state additions
**File:** `scripts/ai/ai_game_state.gd`

Add:
- `can_research(tech_id) -> bool` / `get_can_research_reason(tech_id) -> String`
- `research_tech(tech_id)` — queue pending action
- `has_tech(tech_id) -> bool`
- `_pending_researches` dict for de-duplication
- `_do_research()` in `execute_actions()`
- BUILDING_COSTS entry for blacksmith: `{"wood": 150}`

#### 15. AI controller additions
**File:** `scripts/ai/ai_controller.gd`

- Register new rules in `create_all_rules()`
- Add skip reasons for build_blacksmith, research_blacksmith_tech, research_loom
- Add blacksmith to debug state logging

#### 16. Observability (AI + human state logging)

**AI_STATE logging** (`scripts/ai/ai_controller.gd`):
- Add `blacksmith` to building counts dict (line ~630)
- Add `tech` section: `{"researched_count": N, "current_research": "forging" or "", "has_loom": bool}`
- Add `can_afford` entries: `"blacksmith": can_build("blacksmith")`
- Add `rule_blockers` entries for build_blacksmith, research_blacksmith_tech, research_loom

**AI milestones** (`scripts/testing/ai_test_analyzer.gd`):
- Add to milestones dict: `"first_blacksmith": null`, `"first_tech_researched": null`, `"first_loom": null`
- Add to `_check_milestones()`: check `state.get_building_count("blacksmith")` and `state.has_tech()` queries
- Add blacksmith to the building_types array (line ~101)

**Game state snapshots** (`scripts/logging/game_state_snapshot.gd`):
- Add `blacksmith` to `_capture_buildings()` building groups dict (line ~121)
- Add new `_capture_technologies(team)` function: returns `{"researched": [...], "current_research": "forging"/"", "loom": bool}`
- Add `"technologies"` key to `capture()` return dict

**Skip reasons** (`scripts/ai/ai_controller.gd:_get_rule_skip_reason()`):
- `build_blacksmith`: already_have_blacksmith, already_queued, need_barracks, not_feudal_age, + get_can_build_reason
- `research_blacksmith_tech`: no_blacksmith, already_researching, no_available_techs, saving_for_age, + get_can_research_reason
- `research_loom`: already_researched, no_tc, tc_busy, saving_for_age, insufficient_gold

#### 17. Update roadmap
**File:** `docs/roadmap.md`

Move Imperial techs and unit upgrades from Phase 5 to Phase 9:
- Imperial Blacksmith techs: Blast Furnace, Plate Mail Armor, Plate Barding Armor, Bracer, Ring Archer Armor
- Imperial unit upgrades: Two-Handed Swordsman, Champion, Arbalester, Cavalier, Paladin

### Key gotchas for 5A

1. **Forging/Iron Casting affect BOTH infantry AND cavalry attack** — shared upgrade line
2. **Fletching/Bodkin affect archers AND towers AND TCs** — towers don't exist yet (Phase 7), apply to archers only for now, document for future
3. **apply_tech_bonuses() must be idempotent** — always recalculate from base + bonuses, never increment
4. **Loom HP bonus**: increase both max_hp AND current_hp (unit gets tougher, not healed)
5. **TC Loom blocks training** — same as age research priority in `_process()`
6. **Building destruction during research must refund** — `_destroy()` calls `cancel_research()`
7. **Imperial techs NOT included** — deferred to Phase 9 entirely
8. **Use `load()` for new Blacksmith assets initially** — run import before switching to `preload()`

### Files created (5A)

| File | Type |
|------|------|
| `scripts/buildings/blacksmith.gd` | Building script |
| `scenes/buildings/blacksmith.tscn` | Building scene |
| `assets/sprites/buildings/blacksmith.svg` | SVG placeholder |
| `docs/plans/phase-5-plan.md` | Plan file (copy of this) |

### Files modified (5A)

| File | Changes |
|------|---------|
| `scripts/game_manager.gd` | TECHNOLOGIES dict, per-team tech state, tech helpers, signal, reset |
| `scripts/buildings/building.gd` | Generic research system (~50 lines) |
| `scripts/buildings/town_center.gd` | Loom research, _process priority |
| `scripts/units/unit.gd` | Base stat storage, apply_tech_bonuses(), signal connection |
| `scripts/units/militia.gd` | _store_base_stats() + apply_tech_bonuses() in _ready() |
| `scripts/units/spearman.gd` | Same pattern |
| `scripts/units/archer.gd` | Same pattern |
| `scripts/units/skirmisher.gd` | Same pattern |
| `scripts/units/scout_cavalry.gd` | Same pattern |
| `scripts/units/cavalry_archer.gd` | Same pattern |
| `scripts/units/villager.gd` | Same pattern (Loom bonuses) |
| `scripts/ui/hud.gd` | Blacksmith panel, Loom button, build button, research progress |
| `scenes/ui/hud.tscn` | New buttons for Blacksmith techs + Loom + build blacksmith |
| `scripts/main.gd` | start_blacksmith_placement(), build button handler |
| `scripts/ai/ai_rules.gd` | BuildBlacksmithRule, ResearchBlacksmithTechRule, ResearchLoomRule |
| `scripts/ai/ai_game_state.gd` | can_research, research_tech, has_tech, blacksmith cost/scene |
| `scripts/ai/ai_controller.gd` | Register rules, skip reasons, debug state, AI_STATE tech logging |
| `scripts/testing/ai_test_analyzer.gd` | Blacksmith/tech milestones |
| `scripts/logging/game_state_snapshot.gd` | Blacksmith in buildings, new technologies section |
| `docs/roadmap.md` | Move Imperial techs/upgrades to Phase 9 |

---

## 5B: High-level plan (detailed plan written after 5A completion)

### Scope (Castle Age and below only)
- Man-at-Arms, Long Swordsman (Barracks)
- Pikeman (Barracks)
- Crossbowman (Archery Range)
- Elite Skirmisher (Archery Range)
- Heavy Cavalry Archer (Archery Range)
- Light Cavalry (Stable)
- Knight — new unit (Stable, Castle Age)

Imperial upgrades (Two-Handed Swordsman, Champion, Arbalester, Cavalier, Paladin) moved to Phase 9.

### Unit upgrade definitions in GameManager
`UNIT_UPGRADES` dict with entries like:
```
"man_at_arms": {
    "from": "militia", "age": AGE_FEUDAL, "building": "barracks",
    "cost": {"food": 100, "gold": 40}, "research_time": 40.0,
    "new_stats": {"max_hp": 55, "attack_damage": 7, "melee_armor": 0, "pierce_armor": 1},
    "new_name": "Man-at-Arms", "new_group": "man_at_arms"
}
```

### Unit upgrade mechanism
Modify stats in-place (not node replacement). When upgrade is researched:
1. Iterate all units in the "from" group, update stats, name, groups
2. Future units created from the same building spawn as the upgraded version
3. Store upgrade level per unit type per team in GameManager

### Knight (new unit)
60F + 75G, 100HP, 10 attack, 2/2 armor, Castle Age, Stable. New scene/script/SVG.

### Training building research
Barracks, Archery Range, Stable each get upgrade research buttons using the generic research system from Building base class. One active research at a time per building.

### AI upgrade rules
Research upgrades based on army composition. Prioritize upgrades for the unit types the AI has most of.

### Observability (5B)
- Game state snapshot: add knight to military, upgrade levels per unit type
- AI milestones: first_knight, first_unit_upgrade
- AI_STATE: upgrade research status, knight count
- Skip reasons for upgrade research rules

---

## Post-phase checklist (for both 5A and 5B)

1. Self-report on context friction in checkpoint doc
2. Run code-reviewer agent
3. Run test agent → update checkpoint doc's "Test Coverage"
4. Run ai-observer agent → add results to checkpoint doc
5. Update docs/gotchas.md with Phase 5 learnings
6. Write checkpoint doc (phase-5.0a.md / phase-5.0b.md)
7. Verify game launches and plays

## Verification

1. **Import validation**: `/Applications/Godot.app/Contents/MacOS/Godot --headless --import --path .`
2. **Test suite**: `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . tests/test_scene.tscn`
3. **Spec-check agent**: Run on Blacksmith and all techs to verify AoE2 accuracy
4. **AI observer**: Verify AI builds Blacksmith, researches techs, and techs affect combat
5. **Manual check**: Launch game, advance to Feudal, build Blacksmith, research Forging, verify unit attack increases
