# Phase 9.0A Checkpoint: Imperial Age Advancement + Imperial Blacksmith Techs + Unit Upgrades

**Date:** 2026-02-07
**Status:** Complete

---

## Summary

Implemented Imperial Age advancement (AI rule + should_save_for_age), 5 Imperial Blacksmith techs (Blast Furnace, Plate Mail Armor, Plate Barding Armor, Bracer, Ring Archer Armor), 6 deferred unit upgrades (Two-Handed Swordsman, Champion, Arbalester, Cavalier, Paladin, Siege Ram), HUD updates for all new tech/upgrade buttons, AI rules for researching Imperial content, and full observability updates. All changes are purely additive — no refactoring was needed.

---

## Context Friction

1. **Files re-read multiple times?** Yes — continued from a context compaction. Re-read game_manager.gd, hud.gd, ai_rules.gd, ai_game_state.gd, ai_controller.gd, game_state_snapshot.gd, ai_test_analyzer.gd. The plan file survived compaction and served as the checklist.
2. **Forgot earlier decisions?** No — the context summary was detailed enough to resume without issues.
3. **Uncertain patterns?** No — all changes followed established patterns from Phases 5A/5B (blacksmith techs, unit upgrades).

---

## Implemented Features

| Feature | Files | Notes |
|---------|-------|-------|
| 5 Imperial Blacksmith techs | `game_manager.gd` | blast_furnace (275F+225G, +2 atk), plate_mail_armor (300F+150G, +1/+2P), plate_barding_armor (350F+200G, +1/+2P), bracer (300F+200G, +1 atk/range), ring_archer_armor (250F+250G, +1/+2P) |
| Two-Handed Swordsman upgrade | `game_manager.gd` | 300F+100G, HP 60, atk 11, Barracks |
| Champion upgrade | `game_manager.gd` | 750F+350G, HP 70, atk 13, 1/0 armor, Barracks |
| Arbalester upgrade | `game_manager.gd` | 350F+300G, HP 40, atk 6, range 160, Archery Range |
| Cavalier upgrade | `game_manager.gd` | 300F+300G, HP 120, atk 12, 2/2 armor, Stable |
| Paladin upgrade | `game_manager.gd` | 1300F+750G, HP 160, atk 14, 2/3 armor, Stable |
| Siege Ram upgrade | `game_manager.gd` | 1000F+800G, HP 270, atk 4, 0/195 armor, Siege Workshop |
| HUD Blacksmith tech lines | `hud.gd` | 5 tech lines extended with Imperial tier |
| HUD upgrade buttons | `hud.gd` | 8 locations updated (Barracks, Archery Range, Stable, Siege Workshop × 2) |
| AdvanceToImperialAgeRule | `ai_rules.gd` | Castle Age, 20+ vills, 2 qualifying buildings (monasteries/universities) |
| AI blacksmith tech research | `ai_rules.gd` | Imperial tier added to all 5 tech arrays + fallback |
| AI unit upgrade research | `ai_rules.gd` | 6 Imperial upgrades added to upgrade_groups |
| should_save_for_age() update | `ai_game_state.gd` | 3-way check: Feudal=10, Castle=15, Imperial=20 villagers |
| Unit count mappings | `ai_game_state.gd` | cavalier, paladin, two_handed_swordsman, champion, arbalester, capped_ram, siege_ram, onager, heavy_scorpion |
| AI controller observability | `ai_controller.gd` | advance_to_imperial in key_rules + skip reasons, siege_workshop in research lookup |
| Game state snapshot | `game_state_snapshot.gd` | 6 new unit types in result dict + elif chain |
| AI test milestones | `ai_test_analyzer.gd` | reached_imperial_age, first_imperial_upgrade |

---

## Deviations from Spec

| Spec Said | Implementation | Reason |
|-----------|----------------|--------|
| Arbalester research time ~50s (AoK) | 75.0s | AoE2 manual doesn't specify research times for unit upgrades; 75s is a reasonable default used for other Imperial techs. Minor discrepancy. |

---

## Known Issues

| Issue | Severity | Notes |
|-------|----------|-------|
| AI can't reach Feudal Age in 600s test | Pre-existing | Economy bottleneck from Phase 7B+ prevents testing Imperial features |
| load() not preload() for building scenes | Pre-existing | Accumulated tech debt across main.gd |

---

## Code Review Fixes Applied

1. **ISSUE-001 (HIGH)**: Added explicit `onager` and `heavy_scorpion` mappings to `get_unit_count()` in ai_game_state.gd — worked by accident via fallback, now explicit for consistency
2. **ISSUE-002 (HIGH, false positive)**: Ranged count was flagged as missing upgraded groups, but the "archers" category group survives upgrades. Verified: upgrade system only swaps specific line groups, not category groups. No change needed.
3. **ISSUE-005 (MEDIUM)**: Updated stale comment in game_manager.gd from "Feudal + Castle only; Imperial deferred" to "all ages: Dark through Imperial"
4. **ISSUE-007 (MEDIUM)**: Added `onager` and `heavy_scorpion` to `imperial_techs` milestone list in ai_test_analyzer.gd

Issues assessed and accepted:
- ISSUE-003: Cavalry count relies on "cavalry" group surviving upgrades — verified correct
- ISSUE-004: Cavalier upgrade count logic — two-pass logic handles edge case correctly
- ISSUE-008 (LOW): Duplicate tech lists in AI rules — acceptable, bounded duplication
- ISSUE-009 (LOW): Age advancement rule duplication — YAGNI (no more ages to add)

---

## Spec Check Results

**82/85 attributes match** across 11 entities:

**5 Blacksmith techs:** All costs, effects, prerequisites match AoE2 manual exactly.

**6 Unit upgrades:**
- Two-Handed Swordsman: All match (300F+100G, HP 60, atk 11)
- Champion: All match (750F+350G, HP 70, atk 13, 1/0 armor)
- Arbalester: All match except research time (75s vs ~50s AoK)
- Cavalier: All match (300F+300G, HP 120, atk 12, 2/2 armor, no tech prereq)
- Paladin: All match (1300F+750G, HP 160, atk 14, 2/3 armor)
- Siege Ram: Fixed during post-phase — cost corrected from {food: 1000} to {food: 1000, gold: 800}

---

## Test Coverage

All 695 tests pass (640 pre-existing + 55 new).

**New tests** (`tests/test_phase_9a.gd` — 55 tests):

| Area | Tests | What's covered |
|------|-------|----------------|
| Blacksmith tech definitions | 5 | Cost, age, building, effects, requires for all 5 Imperial techs |
| Tech prerequisites | 5 | blast_furnace→iron_casting, plate_mail→chain_mail, plate_barding→chain_barding, bracer→bodkin, ring_archer→leather_archer |
| Age gating | 2 | Imperial techs blocked in Castle Age, available in Imperial Age |
| Tech effect bonuses | 6 | Infantry attack, cavalry attack, infantry armor, cavalry armor, archer attack+range, archer armor |
| Stacked bonuses | 2 | Full infantry attack line (Forging+Iron+Blast=4), full archer armor line |
| Unit upgrade definitions | 6 | Cost, age, prereqs for all 6 Imperial upgrades |
| Upgrade stat changes | 7 | Stat deltas for two_handed_swordsman, champion, arbalester, cavalier, paladin, siege_ram + group swaps |
| Upgrade chains | 3 | Champion full chain from militia, paladin from knight, arbalester from archer |
| Spawn-as-upgraded | 3 | New militia spawns as two_handed/champion, team isolation |
| Tech bonus after upgrade | 1 | Blacksmith bonuses reapplied after upgrade |
| Imperial age advancement | 5 | Cost, qualifying buildings, requirements check |
| AI Imperial rule | 4 | Fires when ready, blocks on wrong age/vills/buildings/resources |
| should_save_for_age | 3 | Imperial needs 20 vills, false when already Imperial, false when can afford |

---

## AI Behavior Tests

**Test run:** FAIL — Pre-existing failures (AI can't reach Feudal Age in 600s).

**Imperial features: COULD NOT VALIDATE** — AI never reached Feudal Age due to pre-existing economy bottleneck.

**Code inspection confirms:**
- `AdvanceToImperialAgeRule` correctly registered with skip reason chain (not_castle_age → need_20_villagers → already_researching → need_qualifying → cannot_afford)
- `ResearchBlacksmithTechRule._get_best_tech()` includes all 5 Imperial tech arrays
- `ResearchUnitUpgradeRule._get_best_upgrade()` includes all 6 Imperial upgrades
- `reached_imperial_age` and `first_imperial_upgrade` milestones tracked
- All new unit counts tracked in game_state_snapshot.gd
- `should_save_for_age()` correctly handles Imperial with 20 villager minimum

**Not a Phase 9A regression** — the economy timing issue dates to Phase 7B and predates all Imperial changes.
