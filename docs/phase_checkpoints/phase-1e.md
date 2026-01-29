# Phase 1E Checkpoint: Market & Trading

**Date:** 2026-01-28
**Status:** Complete

---

## Summary

Implemented the Market building for buying/selling resources with dynamic pricing, and Trade Cart units for generating passive gold via trade routes. AI can now build markets and use them to balance resource imbalances.

---

## Implemented Features

| Feature | Files | Notes |
|---------|-------|-------|
| Market building | `scripts/buildings/market.gd`, `scenes/buildings/market.tscn` | 175 wood cost, buy/sell resources, train Trade Carts |
| Dynamic market pricing | `scripts/game_manager.gd:7-16, 54-99` | Prices change with trades: +3 on buy, -3 on sell. Min 20, max 300 |
| Buy/sell UI | `scripts/ui/hud.gd:13-23, 100-130, 173-211`, `scenes/ui/hud.tscn` | MarketPanel with price display, buy/sell buttons |
| Trade Cart unit | `scripts/units/trade_cart.gd`, `scenes/units/trade_cart.tscn` | Autonomous trade route, gold per tile distance |
| Trade distance scaling | `scripts/units/trade_cart.gd:57-70` | ~46 gold per 100 tiles (BASE_GOLD_PER_TILE = 0.46) |
| Market placement | `scripts/main.gd:7,12,62-64,296-307,371` | Build Market button, placement ghost, selection panel |
| AI market building | `scripts/ai/ai_controller.gd:10,24,76-80,496-513` | AI builds market when surplus resources + low gold |
| AI market usage | `scripts/ai/ai_controller.gd:515-544` | AI sells surplus (>400), buys when desperate (<50) |
| Market price signal | `scripts/game_manager.gd:23` | `market_prices_changed` signal for UI updates |

---

## Deviations from Spec

| Spec Said | Implementation | Reason |
|-----------|----------------|--------|
| Tribute system (30% fee) | Deferred to Phase 13 | Only useful with allied AI - no one to tribute to in 1v1 |
| Sheep herding AI | Not implemented | Nice-to-have, current hunting works. See DD-004 |
| Market sprite | Placeholder (barracks_aoe.png) | No AoE market sprite in asset pack |
| Trade Cart sprite | Placeholder (villager frames) | No AoE trade cart sprite in asset pack |

---

## Known Issues

- **Trade Carts need two markets**: A single market provides no trade destination. Trade Carts will be idle until a second allied market exists. AI doesn't train Trade Carts (would need two markets far apart).
- **Market panel wider than other panels**: MarketPanel is 520px wide (vs 300px for TC/Barracks) to fit buy/sell columns. May need UI polish in Phase 9.
- **No market sprite**: Using barracks sprite as placeholder. Visually confusing until replaced.

---

## Test Coverage

### Manual Testing Performed
- [ ] Build Market (175 wood cost deducted)
- [ ] Click Market to show MarketPanel with prices
- [ ] Buy wood/food/stone - gold deducted, resource added, price increases
- [ ] Sell wood/food/stone - resource deducted, gold added, price decreases
- [ ] Prices update on buttons after trades
- [ ] Train Trade Cart (100 wood + 50 gold)
- [ ] Trade Cart appears and follows trade route if two markets exist
- [ ] AI builds market when has surplus and needs gold
- [ ] AI uses market to sell surplus resources
- [ ] AI uses market to buy when desperate

### Automated Tests
- `tests/scenarios/test_economy.gd` - 11 new tests (23 total in file) covering:
  - Price change exact amount (+3 buy, -3 sell)
  - Price min bound (20) after many sells
  - Price max bound (300) after many buys
  - Sell price spread (70% of buy price)
  - Cannot buy/sell gold with gold
  - Buy fails without sufficient gold
  - Sell fails without sufficient resource
  - market_prices_changed signal emission
  - Trade Cart gold formula (distance_tiles * BASE_GOLD_PER_TILE)
  - Trade Cart minimum 1 gold for short distances

---

## AI Behavior Updates

- **AI builds Market**: When wood > 175, has surplus resources (>300 of any), and gold < 100
- **AI sells resources**: Sells when surplus > 400 (one transaction per decision cycle)
- **AI buys resources**: Buys when resource < 50 AND gold > 150 (keeps reserve)
- **AI doesn't train Trade Carts**: Would need two markets far apart, not worth the complexity for 1v1

---

## Lessons Learned

(Added to docs/gotchas.md)

- Market prices are global (all players share same prices)
- Sell price has ~30% spread from buy price (prevents arbitrage)
- Trade Cart gold formula: distance_tiles × 0.46
- AI market usage is conservative to prevent bankruptcy
- Explicit building panels (tc_panel, market_panel) preferred over generic abstraction

---

## Context for Next Phase

Critical information for Phase 2 (Military Foundation):

- **GameManager has market infrastructure**: `market_buy()`, `market_sell()`, `get_market_buy_price()`, `get_market_sell_price()`, `market_prices_changed` signal. Ready for any future market-related features.

- **Phase 1 Complete**: All 4 resources, all drop-off buildings, animals, trading. Economy foundation is solid.

- **HUD panel pattern**: Each building type gets its own panel (tc_panel, barracks_panel, market_panel). When adding Archery Range, Stable in Phase 2, follow same pattern.

- **AI decision loop structure**: `_make_decisions()` in ai_controller.gd has numbered steps. Add new behaviors at appropriate priority position.

- **Trade Cart is economic unit**: Not military. Uses "trade_carts" group, not "military". If implementing formations/groups in Phase 9, treat differently from combat units.

- **Deferred features**: Tribute system → Phase 13. Sheep herding AI → backlog.

---

## Git Reference

- **Commits:** Phase 1E Market & Trading implementation
