# Phase 9: Imperial Age & Advanced — Sub-phase split + Phase 9A plan

## Context

Phase 8 (University + Siege Workshop + Siege Units) is complete. Phase 9 adds Imperial Age content: the 4th age, Castle building, Trebuchet, Wonder victory, gunpowder units, and all Imperial-tier upgrades/techs deferred from earlier phases. This is the largest remaining phase.

## Sub-phase split

**9A: Imperial Age Advancement + Imperial Blacksmith Techs + All Deferred Unit Upgrades**
- AI AdvanceToImperialAgeRule
- 5 Imperial Blacksmith techs (Blast Furnace, Plate Mail, Plate Barding, Bracer, Ring Archer)
- 6 Imperial unit upgrades (Two-Handed Swordsman, Champion, Arbalester, Cavalier, Paladin, Siege Ram)
- Existing Onager/Heavy Scorpion unlocked by reaching Imperial
- HUD: Blacksmith Imperial tech buttons, upgrade buttons in Barracks/Archery Range/Stable/Siege Workshop
- AI: Research techs + upgrades

**9B: Castle Building + Trebuchet + Keep**
- Castle building (650S, 4800HP, attack, garrison 20, trains Trebuchets)
- Trebuchet unit (pack/unpack mechanic)
- Keep building upgrade (Guard Tower → Keep, University)

**9C: Chemistry + Gunpowder Units + Camel**
- Chemistry tech (University, enables gunpowder)
- Bombard Cannon (Siege Workshop, requires Chemistry)
- Hand Cannoneer (Archery Range, requires Chemistry)
- Camel + Heavy Camel (Stable)

**9D: Bombard Tower + Wonder + Wonder Victory + Forest Cutting**
- Bombard Tower (requires Chemistry)
- Wonder + Wonder victory condition (200 years)
- Forest cutting (Siege Onager/Trebuchet destroy trees)

---

## Phase 9A: Detailed execution plan

### Refactoring check
**No refactoring needed.** All systems (TECHNOLOGIES dict, upgrade system, blacksmith tech system, HUD button creation) are already generic and extensible. Purely additive changes.

### Ordered feature list

#### Step 1: Add 5 Imperial Blacksmith techs to TECHNOLOGIES
**File:** `scripts/game_manager.gd`

Add after existing Castle-tier blacksmith techs:
- `blast_furnace`: 275F+225G, requires `iron_casting`, effects: `{infantry_attack: 2, cavalry_attack: 2}` (note: +2, not +1 like earlier tiers)
- `plate_mail_armor`: 300F+150G, requires `chain_mail_armor`, effects: `{infantry_melee_armor: 1, infantry_pierce_armor: 2}`
- `plate_barding_armor`: 350F+200G, requires `chain_barding_armor`, effects: `{cavalry_melee_armor: 1, cavalry_pierce_armor: 2}`
- `bracer`: 300F+200G, requires `bodkin_arrow`, effects: `{archer_attack: 1, archer_range: 1}`
- `ring_archer_armor`: 250F+250G, requires `leather_archer_armor`, effects: `{archer_melee_armor: 1, archer_pierce_armor: 2}`

All age: AGE_IMPERIAL, building: "blacksmith", research_time: 75.0s

#### Step 2: Add 6 Imperial unit upgrades to TECHNOLOGIES
**File:** `scripts/game_manager.gd`

Barracks line:
- `two_handed_swordsman`: 300F+100G, requires `long_swordsman`, from `long_swordsmen` → `two_handed_swordsmen`, stats: HP 60, attack 11, 0/0 armor
- `champion`: 750F+350G, requires `two_handed_swordsman`, from `two_handed_swordsmen` → `champions`, stats: HP 70, attack 13, 1/0 armor

Archery Range line:
- `arbalester`: 350F+300G, requires `crossbowman`, from `crossbowmen` → `arbalesters`, stats: HP 40, attack 6, 0/0 armor, range 160px

Stable line:
- `cavalier`: 300F+300G, requires `""` (just needs Imperial), from `knights` → `cavaliers`, stats: HP 120, attack 12, 2/2 armor
- `paladin`: 1300F+750G, requires `cavalier`, from `cavaliers` → `paladins`, stats: HP 160, attack 14, 2/3 armor

Siege Workshop line:
- `siege_ram`: 1000F, requires `capped_ram`, from `capped_rams` → `siege_rams`, stats: HP 270, attack 4, pierce_armor 195

All age: AGE_IMPERIAL, research_time: 75-170s

#### Step 3: Update Blacksmith HUD tech lines
**File:** `scripts/ui/hud.gd` (line ~1699)

Extend each tech_line array with its Imperial tier:
```
["forging", "iron_casting", "blast_furnace"]
["scale_mail_armor", "chain_mail_armor", "plate_mail_armor"]
["scale_barding_armor", "chain_barding_armor", "plate_barding_armor"]
["fletching", "bodkin_arrow", "bracer"]
["padded_archer_armor", "leather_archer_armor", "ring_archer_armor"]
```

Existing button creation code already handles age-gating and prerequisites — no other changes needed.

#### Step 4: Update HUD upgrade button arrays (8 locations)
**File:** `scripts/ui/hud.gd`

Each building has upgrade buttons in 2 places: the `_show_*_buttons()` function and `_refresh_current_panel()`.

- **Barracks** (lines 399, 665): `["man_at_arms", "long_swordsman", "two_handed_swordsman", "champion", "pikeman"]`
- **Archery Range** (lines 414, 668): `["crossbowman", "arbalester", "elite_skirmisher", "heavy_cavalry_archer"]`
- **Stable** (lines 429, 671): `["light_cavalry", "cavalier", "paladin"]`
- **Siege Workshop** (lines 486, 681): `["capped_ram", "siege_ram", "onager", "heavy_scorpion"]`

#### Step 5: Add AdvanceToImperialAgeRule
**File:** `scripts/ai/ai_rules.gd`

Pattern: same as AdvanceToCastleAgeRule. Conditions: Castle Age, 20+ villagers, 2 qualifying Imperial buildings (monasteries + universities), can afford. Register in `create_all_rules()`.

#### Step 6: Update should_save_for_age() for Imperial
**File:** `scripts/ai/ai_game_state.gd` (line ~140)

Change `var min_vills = 10 if target_age == AGE_FEUDAL else 15` to explicit 3-way with 20 villagers for Imperial target.

#### Step 7: Extend AI ResearchBlacksmithTechRule._get_best_tech()
**File:** `scripts/ai/ai_rules.gd` (line ~831)

Append Imperial tier to each tech array:
- `["forging", "iron_casting", "blast_furnace"]`
- `["fletching", "bodkin_arrow", "bracer"]`
- `["scale_mail_armor", "chain_mail_armor", "plate_mail_armor"]`
- `["scale_barding_armor", "chain_barding_armor", "plate_barding_armor"]`
- `["padded_archer_armor", "leather_archer_armor", "ring_archer_armor"]`

Also update the fallback array (line ~869) to include all Imperial techs.

#### Step 8: Extend AI ResearchUnitUpgradeRule._get_best_upgrade()
**File:** `scripts/ai/ai_rules.gd` (line ~920)

Add to upgrade_groups array:
- `["two_handed_swordsman", gs.get_unit_count("infantry")]`
- `["champion", gs.get_unit_count("infantry")]`
- `["arbalester", gs.get_unit_count("archer")]`
- `["cavalier", gs.get_unit_count("knight")]`
- `["paladin", gs.get_unit_count("cavalier")]`
- `["siege_ram", gs.get_unit_count("capped_ram")]`

#### Step 9: Update game_state_snapshot.gd
**File:** `scripts/logging/game_state_snapshot.gd`

Add to result dict: `two_handed_swordsman`, `champion`, `arbalester`, `cavalier`, `paladin`, `siege_ram` (all initialized to 0).

Add to elif chain (most-specific first):
- `champions` before `two_handed_swordsmen` before `long_swordsmen`
- `arbalesters` before `crossbowmen`
- `paladins` before `cavaliers` before `knights`
- `siege_rams` before `capped_rams`

#### Step 10: Add unit count mappings in ai_game_state.gd
**File:** `scripts/ai/ai_game_state.gd`

Add to `get_unit_count()` match statement:
- `"two_handed_swordsman"` → `"two_handed_swordsmen"`
- `"champion"` → `"champions"`
- `"arbalester"` → `"arbalesters"`
- `"cavalier"` → `"cavaliers"`
- `"paladin"` → `"paladins"`
- `"siege_ram"` → `"siege_rams"`

#### Step 11: Update ai_controller.gd observability
**File:** `scripts/ai/ai_controller.gd`

- Add `"advance_to_imperial"` to key_rules array
- Add skip reason logic for advance_to_imperial (not_castle_age, need_20_vills, need_qualifying, cannot_afford)
- Add `"siege_workshop"` to `_get_current_research_name()` building type loop

#### Step 12: Update ai_test_analyzer.gd milestones
**File:** `scripts/testing/ai_test_analyzer.gd`

Add milestones: `reached_imperial_age`, `first_imperial_upgrade`. Check for Imperial age in `_check_milestones()`.

#### Step 13: Update docs/gotchas.md
Add Phase 9A section.

### Key gotchas
1. **Blast Furnace gives +2 attack** (not +1 like earlier tiers). Effect system handles this — value is the raw bonus.
2. **Plate armor is asymmetric**: +1 melee / +2 pierce (earlier tiers give +1/+1). Separate effect keys handle this.
3. **elif chain ordering**: Most-specific (upgraded) groups must come before base groups in game_state_snapshot.gd.
4. **Unit upgrades preserve base groups**: `_apply_unit_upgrade()` only swaps the line-specific group. "infantry", "military", "cavalry" etc. stay. Aggregate counts still work.
5. **Cavalier has no tech prereq** (`requires: ""`). Just needs Imperial Age. Paladin requires Cavalier.
6. **Arbalester range**: Keep attack_range at 160.0 (same as Crossbowman/Archer base). Tech bonuses add on top.

### Post-phase checklist
1. Run `godot --headless --import --path .` to verify no syntax errors
2. Run test suite
3. Run spec-check agent on Imperial Blacksmith techs and unit upgrades
4. Run code-review agent
5. Run test agent for automated tests
6. Run ai-observer agent (focus: "Does AI advance to Imperial? Research Imperial techs?")
7. Update docs/gotchas.md
8. Write checkpoint doc `docs/phase_checkpoints/phase-9.0a.md`
9. Update docs/roadmap.md with sub-phase breakdown
10. Self-report context friction
