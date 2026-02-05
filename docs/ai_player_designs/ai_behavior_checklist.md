# AI behavior reference

Expected AI behaviors for reference and debugging. Use this to understand what the AI should do and to identify issues when behavior seems wrong.

This is reference documentation, not a checklist to tick off. The automated tests in `ai_test_analyzer.gd` verify key behaviors; this document provides broader context.

---

## Villager assignment

### Clustering prevention
- Max 2 villagers per resource node (except farms)
- Farms can have unlimited villagers (they're renewable)
- RETURNING villagers are counted toward gatherer limits (they'll return to same target)
- Pending assignments within same tick are tracked to prevent double-assignment

### Distance efficiency
- Don't assign villagers to resources > 400px away if closer "full" resources exist (< 200px)
- Prefer nearby "full" resource over distant "available" resource
- Don't herd sheep > 500px from base
- Don't hunt animals > 200px from base (HuntRule threshold)
- Animals that flee should not be chased across the map

### Farm preference
- HuntRule should NOT fire when huntables are > 200px from base
- Farms should be preferred over distant berries/carcasses
- Villagers on farms should have low drop-off distance (farms near TC)
- Mill should be built to reduce food drop-off distance when berries are far

---

## Building placement

### Drop-off buildings
- Lumber camps placed near trees that are FAR from existing drop-offs (> 200px)
- Mining camps placed near gold/stone that are FAR from existing drop-offs
- Mills placed near natural food (berries) that are FAR from existing drop-offs
- Don't build lumber camp right next to TC (useless - TC already accepts wood)

### Farms
- Farms built near TC (for efficient food drop-off)
- Farms built when natural food (sheep, berries, huntables) is depleted or far

---

## Resource gathering

### Priority order
1. Sheep (can be stolen by enemy)
2. Berries/huntables (if closer than farms)
3. Farms (renewable, efficient)
4. Distant hunting (last resort)

### Depletion handling
- When resource depletes, villager becomes IDLE (not stuck)
- Idle villagers get reassigned by next assignment tick
- Don't assign villagers to depleted resource types (allocation = 0%)

### Stockpile caps
- When stockpile > 400, reduce allocation for that resource to 0%
- If ALL resources capped, allow gathering lowest stockpile (prevent all idle)

---

## Economy phases

### Early game (< 10 villagers)
- 60% food, 40% wood allocation
- No gold/stone gathering yet

### Mid game (10+ villagers with barracks)
- 50% food, 35% wood, 15% gold allocation
- Mining camp built near gold

---

## Construction

### Builder assignment
- Idle villager assigned to new construction
- If no idle, reassign a gatherer
- Max ~2 builders per building (diminishing returns)
- Builders not stolen by gather rules (race condition fix)

---

## Combat and military

### Attack timing
- Don't attack until minimum military count reached (5 units)
- Don't attack while under attack (defend first)

---

## Observability (AI_STATE output)

### Efficiency metrics
- `avg_food_drop_dist` should be < 300 when farms are being used
- `avg_wood_drop_dist` should be < 200 when lumber camp is built
- `max_on_same_food` should be ≤ 2 for non-farm food sources
- `max_on_same_wood` should be ≤ 2

### Economy status
- `economy.depleted` correctly reflects resource availability
- `economy.capped` correctly reflects stockpile > 400

---

## Known edge cases

### Resource transitions
- When sheep run out, transition smoothly to berries/hunting
- When natural food runs out, transition smoothly to farms
- When wood runs out, villagers don't stay stuck trying to gather

### Building destruction
- When lumber camp destroyed, villagers can still drop off at TC
- When farm destroyed, villager becomes idle and gets reassigned
