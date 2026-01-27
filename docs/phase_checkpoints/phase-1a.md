# Phase 1A Checkpoint: Core Economy

**Date:** 2026-01-27
**Status:** Complete

---

## Summary

Implemented 4-resource economy (wood, food, gold, stone) with drop-off buildings (Mill, Lumber Camp, Mining Camp). Refactored GameManager to dictionary-based resources. AI updated to gather all resources and build camps.

---

## Implemented Features

| Feature | Files | Notes |
|---------|-------|-------|
| Dictionary-based resources | `scripts/game_manager.gd:4-8, 28-49` | Unified add/spend/can_afford/get_resource functions with team parameter |
| Drop-off interface | `scripts/buildings/building.gd:14, 39-40` | accepts_resources array and is_drop_off_for() method |
| Mill building | `scripts/buildings/mill.gd`, `scenes/buildings/mill.tscn` | Food drop-off, 100 wood cost, 1000 HP |
| Lumber Camp | `scripts/buildings/lumber_camp.gd`, `scenes/buildings/lumber_camp.tscn` | Wood drop-off, 100 wood cost, 1000 HP |
| Mining Camp | `scripts/buildings/mining_camp.gd`, `scenes/buildings/mining_camp.tscn` | Gold/stone drop-off, 100 wood cost, 1000 HP |
| Gold mine resource | `scenes/resources/gold_mine.tscn` | 800 total, yellow visual |
| Stone mine resource | `scenes/resources/stone_mine.tscn` | 350 total, gray visual |
| Villager drop-off logic | `scripts/units/villager.gd:21-39, 100-121` | Finds nearest valid drop-off for carried resource type |
| Villager carry visuals | `scripts/units/villager.gd:136-149` | Gold = bright yellow, Stone = gray |
| HUD 4-resource display | `scripts/ui/hud.gd:3-6, 38-42`, `scenes/ui/hud.tscn` | Shows wood, food, gold, stone |
| New build buttons | `scenes/ui/hud.tscn`, `scripts/ui/hud.gd:131-147` | Mill, Lumber Camp, Mining Camp placement |
| AI resource priority | `scripts/ai/ai_controller.gd:114-130` | Prioritizes food > wood > gold > stone |
| AI camp building | `scripts/ai/ai_controller.gd:169-272` | Builds camps near resources when villagers are gathering |

---

## Deviations from Spec

| Spec Said | Implementation | Reason |
|-----------|----------------|--------|
| Starting gold: 0 | Starting gold: 0 | As specified |
| Starting stone: 0 | Starting stone: 0 | As specified |

None - implemented as specified

---

## Known Issues

- **No Mill prerequisite for Farm:** Per plan, didn't enforce Mill as Farm prerequisite. Farm already existed pre-phase.
- **Performance at scale:** AI searches all units/buildings each decision interval. OK for MVP, may need optimization later.

---

## Test Coverage

### Manual Testing Performed
- [ ] Launch game, verify 4 resources display
- [ ] Build Lumber Camp near trees, verify wood deposits there
- [ ] Build Mining Camp near gold, send villager, verify gold collected
- [ ] Build Mill near berries, verify food deposited there
- [ ] Verify TC still accepts all resource types
- [ ] Verify villager chooses nearest valid drop-off
- [ ] Watch AI - should build camps and gather all 4 resources

### Automated Tests
- None yet

---

## AI Behavior Updates

- AI now prioritizes resources based on current needs (food > wood > gold > stone)
- AI builds Lumber Camp when villagers are gathering wood far from TC
- AI builds Mining Camp when villagers are gathering gold/stone
- AI considers all 4 resource types when assigning idle villagers

---

## Lessons Learned

(Added to docs/gotchas.md)

- Always pass team parameter when refactoring to unified functions
- Villagers should wait in RETURNING state if no drop-off exists (don't lose resources)
- Building placement validation must check resource collision, not just buildings
- TownCenter training must use its own team for resources/population

---

## Context for Next Phase

Critical information for Phase 1B (Trading and food sources):

- Resource types are defined as strings: "wood", "food", "gold", "stone"
- Drop-off buildings use `accepts_resources` array to define what they accept
- Villager finds drop-off via `_find_drop_off(resource_type)` - returns nearest valid building
- AI tracks camps via `ai_lumber_camp`, `ai_mining_camp`, `ai_mill` variables
- GameManager functions: `add_resource()`, `spend_resource()`, `can_afford()`, `get_resource()` - all take team parameter

---

## Git Reference

- **Commits:** See git log after phase-1a-complete tag
- **Tag:** phase-1a-complete (to be created)
