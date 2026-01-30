# Phase 2C Checkpoint: AI Economic Foundation

**Date:** 2026-01-30
**Status:** Complete

---

## Summary

Made the AI functional by implementing economic growth, farm building, all military buildings, and smart attack thresholds. The AI now grows to 20+ villagers, builds farms for sustainable food, constructs all military buildings (Barracks, Archery Range, Stable), trains mixed armies, and only attacks when economically ready.

---

## Context Friction

1. **Files re-read multiple times?** No
2. **Forgot earlier decisions?** No
3. **Uncertain patterns?** No - patterns from Phase 2A/2B were clear

---

## Implemented Features

| Feature | Files | Notes |
|---------|-------|-------|
| Villager training | `scripts/ai/ai_controller.gd:162-171` | AI trains villagers until 20+ count |
| Farm building | `scripts/ai/ai_controller.gd:295-382` | AI builds farms when natural food depleted |
| Mill building | `scripts/ai/ai_controller.gd:262-285` | AI builds mill before farms for efficiency |
| Archery Range building | `scripts/ai/ai_controller.gd:651-673` | AI builds after barracks established |
| Stable building | `scripts/ai/ai_controller.gd:675-697` | AI builds after archery range established |
| Mixed army training | `scripts/ai/ai_controller.gd:699-769` | AI trains militia, spearmen, archers, scouts |
| Multiple barracks support | `scripts/ai/ai_controller.gd:34, 617-649` | Array tracking for production scaling |
| Attack thresholds | `scripts/ai/ai_controller.gd:919-937` | 15+ villagers AND 5+ military required |
| Villager allocation ratios | `scripts/ai/ai_controller.gd:211-260` | 6 food, 5 wood, 3 gold, 1 stone |
| Building rebuilding | `scripts/ai/ai_controller.gd:939-968` | AI rebuilds destroyed critical buildings |
| Natural food detection | `scripts/ai/ai_controller.gd:323-344` | Checks for nearby animals/berries |
| Emergency resource thresholds | `scripts/ai/ai_controller.gd:240-244` | Override ratios when <50 food/wood |

---

## AI Behavior Summary

**Economic Phase (Priority 1):**
1. Train villagers continuously (target: 20+)
2. Build houses when 2 away from pop cap
3. Assign idle villagers based on allocation ratios
4. Build mill when 6+ villagers
5. Build farms when natural food depleted
6. Build camps near resource clusters

**Military Phase (Priority 2):**
7. Build barracks when 8+ villagers
8. Build archery range when 12+ villagers
9. Build stable when 15+ villagers
10. Build 2nd barracks when 18+ villagers and floating resources
11. Train mixed army: archers (40%), infantry (40%), cavalry (20%)

**Economy Support (Priority 3):**
12. Build market when 15+ villagers and surplus/low gold
13. Use market to balance resources
14. Rebuild destroyed critical buildings

**Attack Phase (Priority 4):**
15. Attack when 15+ villagers AND 5+ military

---

## Deviations from Spec

| Spec Said | Implementation | Reason |
|-----------|----------------|--------|
| 20+ villagers target | Uses TARGET_VILLAGERS constant (20) | As planned |
| Trade cart usage | Not implemented | Low priority, requires two markets |

---

## Known Issues

- **load() vs preload()**: AI controller still uses load() for scenes at runtime. Known tech debt from gotchas.md - works but causes file I/O during gameplay.
- **Repeated group queries**: Multiple get_nodes_in_group() calls per decision cycle. Performance is acceptable at 1.5s intervals but could be optimized.

---

## Test Coverage

### Manual Testing Performed
- [x] AI trains villagers continuously
- [x] AI builds houses before pop cap reached
- [x] AI builds mill, then farms
- [x] AI builds barracks, archery range, stable in sequence
- [x] AI trains mixed army (militia, spearmen, archers, scouts)
- [x] AI waits until economy established before attacking
- [x] AI attacks with full military force
- [x] AI rebuilds destroyed barracks

### Automated Tests

**New test file: `tests/scenarios/test_ai.gd`** (20 tests)
- Resource allocation logic (_get_needed_resource)
- Emergency thresholds (<50 food/wood override)
- Farm building decisions
- Attack threshold checks (villagers + military requirements)
- Building detection (barracks, archery range, stable, mill)
- Market building decisions

### Test Summary

- **Tests written:** 20 new tests in test_ai.gd (168 → 188 total)
- **Coverage focus:** AI decision logic functions
- **Notable edge cases:** Emergency resource thresholds, team filtering for building detection, has_attacked flag logic

---

## AI Behavior Updates

This phase **is** the AI behavior update. Key changes from Phase 2B:

| Before (Phase 2B) | After (Phase 2C) |
|-------------------|------------------|
| Never trained villagers | Trains villagers continuously |
| No farms | Builds farms when natural food depleted |
| No mill | Builds mill for food drop-off |
| Only barracks | Builds barracks, archery range, stable |
| Only militia | Trains militia, spearmen, archers, scouts |
| Attacked with 3 militia | Attacks with 5+ military after 15+ villagers |
| Single barracks | Supports multiple barracks for scaling |
| No rebuilding | Rebuilds destroyed critical buildings |

---

## Lessons Learned

(Added to docs/gotchas.md - none new, existing patterns applied)

---

## Context for Next Phase

Critical information for Phase 2D (Skirmisher + Cavalry Archer) and beyond:

- **AI now functional**: Will use any new units added to archery range/stable without code changes
- **Train priorities**: Archers ~40%, infantry ~40%, cavalry ~20% - adjust in _train_military() if needed
- **Attack thresholds**: MIN_VILLAGERS_FOR_ATTACK (15), MIN_MILITARY_FOR_ATTACK (5) - configurable
- **Villager ratios**: FOOD_VILLAGERS (6), WOOD_VILLAGERS (5), GOLD_VILLAGERS (3), STONE_VILLAGERS (1)
- **Mixed army pattern**: Check unit type with `is Militia`, `is Archer`, etc. and adjust training based on composition

---

## Git Reference

- **Commits:** Phase 2C AI economic foundation implementation
