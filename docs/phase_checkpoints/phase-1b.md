# Phase 1B Checkpoint: Animals & Food Sources

**Date:** 2026-01-27
**Status:** Complete

---

## Summary

Implemented huntable animals (sheep, deer, boar) and environmental hazards (wolves). Added villager hunting behavior, carcass system with decay, and resource depletion notifications. AI updated to gather animals as food sources.

---

## Implemented Features

| Feature | Files | Notes |
|---------|-------|-------|
| Animal base class | `scripts/units/animal.gd` | Extends Unit. Wandering, fleeing, attacking states. Spawns carcass on death |
| Food carcass | `scripts/resources/food_carcass.gd`, `scenes/resources/food_carcass.tscn` | Decays over time (loses food), visual feedback |
| Sheep | `scripts/units/sheep.gd`, `scenes/units/sheep.tscn` | 100 food, ownership mechanic (neutral until spotted, can be stolen) |
| Deer | `scripts/units/deer.gd`, `scenes/units/deer.tscn` | 140 food, flees when attacked |
| Boar | `scripts/units/boar.gd`, `scenes/units/boar.tscn` | 340 food, fights back (8 damage), limited chase range |
| Wolf | `scripts/units/wolf.gd`, `scenes/units/wolf.tscn` | No food, aggressive hazard, attacks on sight |
| Villager hunting | `scripts/units/villager.gd:16, 136-185, 223-228` | HUNTING state, chases and kills animals, gathers from carcass |
| Resource depletion notification | `scripts/game_manager.gd:17`, `scripts/ui/hud.gd:29, 172-181` | Signal when villager goes idle, yellow HUD notification |
| AI animal gathering | `scripts/ai/ai_controller.gd:104-112, 193-252` | Prioritizes sheep > deer > boar. Gathers carcasses first |
| Animal info panel | `scripts/ui/hud.gd:184-201, 263-273` | Shows HP, food amount, owner for animals |
| Map animals | `scenes/main.tscn` | 8 sheep, 4 deer, 2 boar, 2 wolves placed on map |

---

## Deviations from Spec

| Spec Said | Implementation | Reason |
|-----------|----------------|--------|
| HP not specified | Sheep 7, Deer 5, Boar 25, Wolf 25 | Animals aren't in Unit Attributes appendix - used reasonable values |
| Line-of-sight ownership | Proximity-based (200 range) | Simpler for MVP, similar gameplay effect |
| Deer flee from attacker | Deer flee in random direction | Attacker tracking not implemented yet (noted for future) |

---

## Known Issues

- **Deer flee direction**: Deer flee randomly instead of away from attacker. Would need attacker tracking in Unit.take_damage() to fix properly.
- **Sheep ownership can flip-flop**: If both teams have units near a sheep, ownership could change rapidly. Could add hysteresis/delay.

---

## Test Coverage

### Manual Testing Performed
- [x] Sheep spawn neutral, turn blue when player villager approaches
- [x] Sheep can be stolen by AI if player units not nearby
- [x] Villagers can hunt sheep/deer/boar, carcass spawns on death
- [x] Carcass decays over time, visual feedback works
- [x] Deer flee when attacked
- [x] Boar attacks back, limited chase range works
- [x] Wolves attack on sight
- [x] AI hunts animals for food
- [x] Resource depletion notification shows in HUD

### Automated Tests
- None yet

---

## AI Behavior Updates

- AI prioritizes animals for food when food is needed: sheep (owned/neutral) > deer > boar
- AI prioritizes gathering from carcasses before hunting new animals (carcasses decay!)
- AI only hunts boar when desperately low on food (< 50) due to danger

---

## Lessons Learned

(Added to docs/gotchas.md)

- Animals don't use population - override die() completely
- Neutral team = -1 for wild animals
- Preload scenes for runtime spawning
- Throttle expensive tree searches (aggro, ownership)
- Store last known position before target dies

---

## Context for Next Phase

Critical information for Phase 1C (Trading):

- Animals use `team = -1` for neutral/wild state
- Carcasses are in "carcasses" group, gatherable as ResourceNodes
- Villager has HUNTING state for killing animals before gathering
- AI's `_find_huntable_animal()` returns Animals, not ResourceNodes
- `GameManager.villager_idle` signal notifies HUD when player villagers go idle

**Phase 1C scope (Trading):**
- Market building (buy/sell resources)
- Dynamic market pricing
- Trade Cart unit (passive gold via trade routes)
- Trade distance scaling
- Tribute system (30% fee) - could defer to Phase 13

---

## Git Reference

- **Commits:** Phase 1B implementation (animals, hunting, AI)
