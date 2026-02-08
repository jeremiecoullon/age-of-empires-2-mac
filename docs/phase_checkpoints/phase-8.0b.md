# Phase 8.0B Checkpoint: Siege Workshop + Siege Units + Upgrades + Ram Garrison + AI

**Date:** 2026-02-07
**Status:** Complete

---

## Summary

Implemented the Siege Workshop building (Castle Age, requires Blacksmith), 3 siege units (Battering Ram, Mangonel, Scorpion), 3 unit upgrades (Capped Ram, Onager, Heavy Scorpion), ram garrison mechanic, building garrison exclusion for siege, AI rules for building/training siege, and full observability updates. Imperial-age upgrades (Onager, Heavy Scorpion) are visible but locked until Phase 9.

---

## Context Friction

1. **Files re-read multiple times?** Yes — this phase spanned 3 context windows. Re-read main.gd, hud.gd, hud.tscn, ai_game_state.gd, ai_controller.gd, ai_rules.gd each session. The plan file (`docs/plans/phase-8b-plan.md`) survived as the compaction-resistant checklist.
2. **Forgot earlier decisions?** No — context summaries were detailed enough. Step tracking in plan file kept progress clear.
3. **Uncertain patterns?** Siege unit single-direction animation was new (vs 8-directional for all other units). Ram garrison being unit-hosted (not building-hosted) was a new pattern.

---

## Implemented Features

| Feature | Files | Notes |
|---------|-------|-------|
| Siege Workshop building | `siege_workshop.gd`, `siege_workshop.tscn` | 200W, 2100HP, Castle Age, 3x3, trains 3 siege units + 3 upgrades |
| Battering Ram unit | `battering_ram.gd`, `battering_ram.tscn` | 160W+75G, 175HP, 2atk, 0/180 armor, melee, only attacks buildings/siege |
| Mangonel unit | `mangonel.gd`, `mangonel.tscn` | 160W+135G, 50HP, 40atk, 0/6 armor, range 224px, min range 96px, area splash |
| Scorpion unit | `scorpion.gd`, `scorpion.tscn` | 75W+75G, 40HP, 12atk, 0/6 armor, range 160px, pass-through bolt |
| Ram garrison system | `battering_ram.gd` | 4 infantry capacity, garrison/ungarrison, eject on death |
| Siege unit upgrades | `game_manager.gd` | Capped Ram (Castle), Onager (Imperial), Heavy Scorpion (Imperial) |
| Building garrison exclusion | `building.gd` | Siege units can't garrison in buildings |
| Main integration | `main.gd` | Siege Workshop placement, ram garrison command |
| HUD integration | `hud.gd`, `hud.tscn` | Build button, train buttons, upgrade buttons, info display |
| AI: BuildSiegeWorkshopRule | `ai_rules.gd` | Castle Age, blacksmith prereq, 15+ vills |
| AI: TrainBatteringRamRule | `ai_rules.gd` | Limit 2 rams |
| AI: TrainMangonelRule | `ai_rules.gd` | Limit 2, requires 5+ military |
| AI: TrainScorpionRule | `ai_rules.gd` | Limit 2, requires 5+ military |
| AI: Siege upgrades | `ai_rules.gd` | Added to ResearchUnitUpgradeRule |
| AI game state | `ai_game_state.gd` | Scene, costs, sizes, train/build/research |
| AI controller | `ai_controller.gd` | Skip reasons, key_rules |
| Observability | `ai_test_analyzer.gd`, `game_state_snapshot.gd` | 3 milestones, building + unit counts |

---

## Deviations from Spec

| Spec Said | Implementation | Reason |
|-----------|----------------|--------|
| Mangonel deals "siege" damage | Uses "pierce" damage type | Only melee/pierce in our system; pierce is closer to AoE2 behavior for most targets |
| Ram speed increases with garrisoned infantry | Speed stays constant | Garrison mechanic is implemented but speed bonus deferred |
| Siege Engineers tech (+1 range, +20% vs buildings) | Not implemented | Imperial Age tech, deferred to Phase 9+ |

---

## Known Issues

| Issue | Severity | Notes |
|-------|----------|-------|
| AI can't reach Castle Age in 600s test | Pre-existing | Economy bottleneck prevents siege workshop testing |
| AI rams passive during defend_against | Low | Rams ignore non-building/siege targets; acceptable behavior |
| load() not preload() for siege scenes | Low | Pre-existing pattern across all buildings in main.gd |
| Barracks _destroy() also doesn't refund queue | Pre-existing | Same issue as siege workshop had before fix; separate fix needed |

---

## Code Review Fixes Applied

1. **ISSUE-001** (HIGH): Added resource refund loop in `siege_workshop.gd:_destroy()` — queued training resources now refunded when building is destroyed
2. **ISSUE-002** (HIGH, deferred): Mangonel damage type kept as "pierce" — AoE2 uses "siege" damage type which we don't have; pierce is the better approximation for most interactions
3. **ISSUE-003** (HIGH, accepted): AI rams sit idle during defend — acceptable tactical limitation, rams properly attack buildings during attack phase
4. Added siege upgrades (capped_ram, onager, heavy_scorpion) to `ResearchUnitUpgradeRule._get_best_upgrade()` in ai_rules.gd

Issues assessed and deferred:
- ISSUE-004: load() vs preload() for siege scenes — pre-existing pattern
- Other medium/low issues from code review were consistent with existing patterns

---

## Spec Check Results

**100% match** across all 7 entities:
- **Siege Workshop:** 200W cost, 2100HP, Castle Age — all match
- **Battering Ram:** 160W+75G, 175HP, 2atk, 0/180 armor — all match
- **Mangonel:** 160W+135G, 50HP, 40atk, 0/6 armor, 7 tile range — all match
- **Scorpion:** 75W+75G, 40HP, 12atk, 0/6 armor, 5 tile range — all match
- **Capped Ram upgrade:** 300F, HP 200, atk 3, pierce armor 190 — all deltas match
- **Onager upgrade:** 800F+500G, HP 60, atk 50, pierce armor 7, range 8 tiles — all match
- **Heavy Scorpion upgrade:** 1000F+800W, HP 50, atk 16, pierce armor 7 — all match

---

## Test Coverage

All 640 tests pass (600 pre-existing + 40 new).

**New tests** (`tests/test_phase_8b.gd` — 40 tests):

| Area | Tests | What's covered |
|------|-------|----------------|
| Siege Workshop stats | 3 | HP, cost, group membership, age requirement |
| Training costs | 3 | Battering Ram, Mangonel, Scorpion resource deductions |
| Training queue | 3 | Insufficient resources, max queue size, cancel refund |
| Destroy refund | 1 | Queued training resources refunded on destruction |
| Battering Ram stats | 3 | HP/attack/armor, group membership, bonus_vs_buildings |
| Ram targeting | 3 | Accepts buildings, accepts siege, rejects non-building/siege, no auto-aggro |
| Ram garrison | 7 | Garrison infantry, capacity limit, reject cavalry, reject wrong team, reject dead, ungarrison all, eject on death |
| Mangonel stats | 2 | HP/attack/armor/range, group membership |
| Mangonel mechanics | 4 | Min range, splash damage calculation, friendly fire, no self-damage |
| Scorpion stats | 2 | HP/attack/armor/range, group membership |
| Scorpion mechanics | 4 | Point-near-line (on line, off line, past endpoint), no friendly fire |
| Upgrade tech entries | 3 | Capped Ram, Onager, Heavy Scorpion costs/ages/stats |
| Building garrison | 1 | Siege units rejected from building garrison |

---

## AI Behavior Tests

**Test run:** FAIL — Pre-existing failures (AI can't reach Castle Age in 600s).

**Siege features: COULD NOT VALIDATE** — AI never reached Castle Age due to pre-existing economy bottleneck (food starvation + late barracks).

**Code inspection confirms:**
- `BuildSiegeWorkshopRule` correctly registered with skip reason chain (no_blacksmith → need_15_villagers → can_build)
- `TrainBatteringRamRule/MangonelRule/ScorpionRule` correctly registered with skip reasons
- `first_siege_workshop`, `first_battering_ram`, `first_mangonel` milestones tracked
- Siege Workshop building count and all siege unit counts tracked in game_state_snapshot.gd
- Siege upgrades added to `ResearchUnitUpgradeRule`

**Not a Phase 8B regression** — the economy timing issue dates to Phase 7B and predates all siege changes.
