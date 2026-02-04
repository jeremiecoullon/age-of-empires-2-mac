# Phase 3.1B Checkpoint: Full Economy Rules

**Date:** 2026-02-03
**Status:** Complete

---

## Summary

Extended the rule-based AI with full economy management: 4-resource gathering, drop-off buildings (lumber camp, mining camp, mill), farm building, food gathering priorities (sheep herding, hunting), and conservative market trading.

---

## Context Friction

1. **Files re-read multiple times?** No - Phase 3.1A checkpoint provided clear context
2. **Forgot earlier decisions?** No - rule pattern was well-established
3. **Uncertain patterns?** No - followed existing rule structure consistently

---

## Implemented Features

| Feature | Files | Notes |
|---------|-------|-------|
| Natural food detection | `scripts/ai/ai_game_state.gd:743-790` | Count berries/sheep/deer/boar (not farms) |
| Sheep gathering helper | `scripts/ai/ai_game_state.gd:792-821` | Find nearest sheep AI can claim |
| Huntable detection | `scripts/ai/ai_game_state.gd:823-851` | Find nearest deer/boar to hunt |
| Drop-off distance checks | `scripts/ai/ai_game_state.gd:858-942` | Detect when resources too far from drop-offs |
| Market query methods | `scripts/ai/ai_game_state.gd:949-973` | Check buy/sell prices and affordability |
| Market actions | `scripts/ai/ai_game_state.gd:363-373` | Queue market buy/sell with de-duplication |
| Villager assignment actions | `scripts/ai/ai_game_state.gd:376-392` | Queue sheep/hunt assignments with de-duplication |
| AdjustGathererPercentagesRule | `scripts/ai/ai_rules.gd:82-116` | Dynamic economy phase transitions |
| BuildLumberCampRule | `scripts/ai/ai_rules.gd:159-176` | Build near trees when too far from drop-off |
| BuildMiningCampRule | `scripts/ai/ai_rules.gd:179-201` | Build near gold/stone when gathering them |
| BuildMillRule | `scripts/ai/ai_rules.gd:204-219` | Build near berries for food drop-off |
| BuildFarmRule | `scripts/ai/ai_rules.gd:222-256` | Build farms when natural food depleted |
| GatherSheepRule | `scripts/ai/ai_rules.gd:263-284` | Prioritize sheep herding |
| HuntRule | `scripts/ai/ai_rules.gd:287-309` | Hunt deer/boar when no sheep |
| MarketSellRule | `scripts/ai/ai_rules.gd:316-358` | Sell surplus resources (>400) |
| MarketBuyRule | `scripts/ai/ai_rules.gd:361-395` | Emergency buying when desperate (<50) |

---

## Deviations from Spec

| Spec Said | Implementation | Reason |
|-----------|----------------|--------|
| Market trading | Conservative thresholds (400 sell, 50 buy) | Prevents AI from making poor economic decisions |

---

## Known Issues

None identified.

---

## Test Coverage

### Manual Testing Performed
- [x] AI builds lumber camps near trees
- [x] AI builds farms when natural food depleted
- [x] AI transitions to mid-game economy (adds gold gathering)
- [x] All 248 tests still pass

### Automated Tests

**File:** `tests/scenarios/test_ai_economy.gd` (34 tests)

| Category | Tests | Description |
|----------|-------|-------------|
| Natural food helpers | 8 | `get_natural_food_count()` excludes farms, includes berries/sheep/huntables |
| Sheep counting | 5 | Counts neutral/AI sheep, excludes player/dead sheep |
| Huntable counting | 2 | Counts deer and boar |
| Nearest sheep/huntable | 3 | Returns closest valid animal to AI base |
| Drop-off helpers | 5 | `has_drop_off_for()`, `get_nearest_drop_off_distance()` |
| Market queries | 6 | `can_market_buy()`, `can_market_sell()` with various conditions |
| BuildFarmRule | 2 | Fires at 10+ villagers, respects farm cap |
| AdjustGathererPercentagesRule | 1 | Transitions at thresholds |
| MarketSellRule | 2 | Fires on surplus (>400), not below |
| MarketBuyRule | 2 | Fires on desperation (<50), requires gold |
| GatherSheepRule | 1 | Fires when sheep available |
| HuntRule | 2 | Fires without sheep, doesn't fire with sheep |

All 282 tests pass (248 existing + 34 new).

---

## AI Behavior Updates

**New economy capabilities:**
- AI now gathers all 4 resources (food, wood, gold, stone) with dynamic percentage adjustment
- AI builds drop-off buildings (lumber camp, mining camp, mill) when resources are too far
- AI builds farms when natural food (berries, sheep, deer, boar) is depleted
- AI prioritizes sheep herding over other food sources (prevents enemy stealing)
- AI hunts deer/boar when no sheep available
- AI sells resources when surplus > 400
- AI buys food/wood in emergencies (< 50 resource, > 150 gold)

**Economy phase system:**
- Phase 0 (early): 60% food, 40% wood - focus on economy
- Phase 1 (mid): 50% food, 35% wood, 15% gold - add gold for market/upgrades
- Transition at 10+ villagers with barracks built

---

## Lessons Learned

(Added to docs/gotchas.md)

- **_queued flags must reset**: Building rules need to reset their flags when buildings are completed
- **Villager assignment de-duplication**: Track assigned villagers to prevent double-assignment
- **Mills should be near natural food**: Use exclude_farms parameter to find berries, not farms
- **Natural food count excludes farms**: Filter farms when counting natural food sources
- **Conservative market trading**: High thresholds prevent poor AI trades

---

## Code Review Issues Addressed

| Issue ID | Severity | Fix |
|----------|----------|-----|
| ISSUE-001 | High | Added villager de-duplication tracking |
| ISSUE-002 | High | Added flag reset when buildings exist |
| ISSUE-003 | Medium | Related to ISSUE-001 |
| ISSUE-005 | Medium | Removed unused MIN_GOLD_TO_KEEP constant |
| ISSUE-007 | Medium | Added exclude_farms parameter for mill placement |

---

## Context for Next Phase (3.1C - Full Military + Intelligence)

Critical information for continuing:

- **Rule engine stable**: Add new rules by creating classes in `ai_rules.gd` and adding to `create_all_rules()`
- **Economy phase system**: GOAL_ECONOMY_PHASE tracks progression, can add Phase 2 for late game
- **Villager assignment de-duplication**: Pattern established - use `_assigned_villagers_this_tick` dictionary
- **Building rules pattern**: Use `_queued` flag with reset in conditions() when building exists

### What 3.1C needs to add:
- Build archery range rule
- Build stable rule
- Train archer, spearman, scout cavalry, skirmisher, cavalry archer rules
- Scouting behavior (send scout to explore)
- Defense rules (respond to threats)
- Mixed army composition (counter enemy army makeup)
- Attack timing refinement

---

## Files Changed

**Modified:**
- `scripts/ai/ai_game_state.gd` - Added economy helpers, market actions, villager assignments (~250 lines added)
- `scripts/ai/ai_rules.gd` - Added 10 new rules (~220 lines added)
- `docs/gotchas.md` - Added Phase 3.1B learnings

---

## Git Reference

- **Primary changes:** Full economy rules for AI
- **New patterns:** Economy phases, drop-off distance checks, villager de-duplication
