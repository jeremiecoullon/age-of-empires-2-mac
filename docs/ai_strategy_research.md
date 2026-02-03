# AI strategy research

Research on optimal AoE2 build orders and strategies for implementing competitive AI.

**Sources:**
- [AoE Companion Build Guides](https://aoecompanion.com/build-guides)
- [Age of Notes - Scout Rush](https://ageofnotes.com/strategies/scout-rush-build-order-secrets-step-step/)
- [Age of Notes - Fast Castle Boom](https://ageofnotes.com/build-orders/fc-boom-build-order-aoe2/)
- [AoE Builds](https://www.aoebuilds.com/main-build-orders)
- [AoE Substack - Scout Rush Guide](https://ageofempires.substack.com/p/aoe2-scout-rush-guide)

---

## Key principles

### 1. Never idle the Town Center
The TC should always be producing villagers until you have 100+ villagers (late game). Every second of TC idle time is lost economy.

### 2. Villager allocation follows predictable patterns
All competitive build orders use similar early-game allocation:
- First 6 villagers → sheep/food under TC
- Next 3-4 villagers → wood (with lumber camp)
- Lure boar for burst food
- 3-4 villagers → berries (with mill)
- More wood villagers
- Gold villagers only when needed for specific units

### 3. Sheep > Berries > Farms for food
- **Sheep/Boar**: Fastest gather rate, gathered under TC (safe)
- **Berries**: Medium rate, requires mill
- **Farms**: Slowest rate, but infinite and controllable

**Critical insight**: Farms are built AFTER sheep/boar are depleted, not before. The current AI should prioritize sheep/berries first.

### 4. Boar luring is essential
Two boars provide ~700 food total. Luring them to TC means:
- Fast gather rate (many villagers can gather)
- Safe (under TC protection)
- Frees up sheep for later

### 5. Build orders target specific timings
| Strategy | Feudal Age Time | Pop Count |
|----------|-----------------|-----------|
| Scout Rush | 9:42-10:00 | 20-21 |
| Archer Rush | ~10:00 | 22 |
| Fast Castle | 10:05-10:30 | 27 |

---

## Standard build orders

### Scout Rush (21 pop) - Aggressive
**Goal**: Pressure enemy economy with fast cavalry in early Feudal Age

**Dark Age:**
```
Villagers 1-6:  Sheep (food under TC)
Villager 7:     Build lumber camp, then wood
Villagers 8-9:  Wood
Villager 10:    Build house, lure boar #1
Villagers 11-12: Boar/sheep under TC
Villager 13:    Build mill at berries
Villagers 14-15: Berries
Villagers 16-17: Boar/sheep under TC
Villager 18:    Build 2nd lumber camp
Villagers 19-21: Wood at 2nd lumber camp
```

**At ~21 pop**: Click Feudal Age
- Move boar/sheep villagers to lumber camps (5 each)
- Build barracks with 1 villager

**Feudal Age:**
- Build stable immediately
- Research Double-Bit Axe, Horse Collar
- Produce 3-4 scouts, attack enemy woodlines/gold
- Start farms as sheep run out

**Resource split at Feudal**: ~14 food, ~10 wood, 0 gold

---

### Archer Rush (22 pop) - Aggressive
**Goal**: Mass archers from 2 archery ranges to harass enemy

**Dark Age:**
```
Villagers 1-6:  Sheep
Villagers 7-10: Wood (with lumber camp)
Villager 11:    Lure boar #1
Villagers 12-15: Berries (with mill)
Villager 16:    Lure boar #2
Villagers 17-19: Wood (2nd lumber camp)
Villagers 20-22: Gold (with mining camp)
```

**At ~22 pop**: Click Feudal Age
- Build barracks during age-up

**Feudal Age:**
- 3 villagers build 2 archery ranges
- Continuous archer production
- Research Fletching at blacksmith

**Resource split at Feudal**: ~10 food, ~12 wood, ~3 gold

---

### Fast Castle Boom (27+2 pop) - Economic
**Goal**: Skip Feudal military, rush to Castle Age for economic boom

**Dark Age:**
```
Villagers 1-6:  Sheep
Villagers 7-10: Wood (with lumber camp)
Villager 11:    Lure boar #1
Villagers 12-16: Berries (with mill)
Villager 17:    Lure boar #2
Villagers 18-21: More food (sheep/boar)
Villagers 22-24: Wood (2nd lumber camp)
Villagers 25-27: Gold (with mining camp)
```

**At 27 pop**: Click Feudal Age, queue 2 more villagers

**Feudal Age:**
- Build market + blacksmith immediately (need both for Castle Age)
- 8 sheep/boar villagers → build farms
- Research Double-Bit Axe, Horse Collar

**Castle Age:**
- Build 2 additional Town Centers immediately
- Boom to 60+ villagers
- Research Bow Saw, Wheelbarrow

---

## Implications for our AI

### What we're doing wrong

1. **Hunting is inefficient without boar luring**
   - Our villagers chase animals across the map
   - Real strategy: lure boar TO the TC, gather there
   - Multiple villagers on one boar under TC = fast + safe

2. **Farms too late in build order**
   - Current build order: farms at step 37-38
   - Should be: farms when sheep/boar depleted (~8-10 villagers)
   - Farms should be fallback, not planned late-game

3. **No lumber camp early enough**
   - Should build lumber camp at ~7 pop
   - Current AI waits until step 10 (8 villagers)

4. **Builder availability**
   - AI has no idle villagers because all are hunting
   - Need to reserve or interrupt villagers for building

5. **Gold too early or too late**
   - Scout rush: no gold needed early
   - Archer rush: gold at ~20 pop
   - Current AI varies

### Recommended changes

1. **Implement boar luring** (if we have boars)
   - Villager attacks boar once, runs to TC
   - Other food villagers gather boar under TC

2. **Build farms when natural food depletes**
   - Track sheep/berry/boar counts
   - When food sources < 2, start farms
   - Don't wait for build order step

3. **Limit hunting villagers**
   - Max 2 villagers chasing deer/distant food
   - Rest should be on sheep (if available) or farms

4. **Guarantee builder availability**
   - Keep 1 villager "soft reserved" for building
   - Or interrupt a wood villager when building needed

5. **Faster lumber camp**
   - Build at 6-7 pop, not 8

---

## Features we don't have yet

Some optimal strategies require features we haven't implemented:

| Feature | Used For | Our Status |
|---------|----------|------------|
| Boar luring | Fast safe food | Not implemented |
| Villager garrison in TC | Safety during raids | Not implemented |
| Age advancement | Feudal/Castle timing | Phase 4 |
| Blacksmith upgrades | Unit improvements | Phase 5 |
| Walls | Base defense | Phase 7 |

For now, the AI should focus on:
- Efficient sheep/berry gathering
- Early lumber camp
- Farms when natural food runs out
- Continuous villager production
- Don't over-commit to hunting
