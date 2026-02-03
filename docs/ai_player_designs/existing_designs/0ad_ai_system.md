# 0AD Petra bot AI system

This document describes how the 0AD Petra bot AI works. The goal is to understand an alternative AI architecture for comparison with the AoE2 rule-based system.

## Overview

0AD's Petra bot uses a **hierarchical priority-queue system**. Unlike AoE2's declarative rule-based approach, Petra is imperative JavaScript code organized into specialized managers that coordinate through a central headquarters.

Key characteristics:
- Written in JavaScript (~19,000 lines across 43 files)
- Managers execute in a fixed order each tick
- Priority queues allocate resources to competing needs
- Personality traits modulate decision thresholds
- No "rules" that fire independently - all logic is procedural

## Architecture

```
PetraBot (entry point)
├── Config (tunable parameters + personality)
├── QueueManager (resource allocation)
└── Headquarters (strategic coordination)
    ├── EmergencyManager (crisis response)
    ├── ResearchManager (tech upgrades)
    ├── TradeManager (trade routes)
    ├── GarrisonManager (unit housing)
    ├── DefenseManager (base defense)
    ├── BasesManager (economy per base)
    │   └── BaseManager[] (individual bases)
    │       └── Worker (unit tasking)
    ├── NavalManager (ships and docks)
    ├── AttackManager (offensive operations)
    │   └── AttackPlan[] (individual attacks)
    ├── DiplomacyManager (ally coordination)
    └── VictoryManager (win conditions)
```

## Update loop

The AI runs on a throttled schedule to save CPU:

```javascript
// In _petrabot.js, line 110
if (!this.playedTurn || (this.turn + this.player) % 8 == 5)
```

- `turn` increments every simulation tick (~20-30 per second)
- The AI only does full decision-making every 8th tick
- `+ this.player` offsets different AI players to avoid all computing simultaneously
- Result: AI updates roughly 2-3 times per second (similar to AoE2's "several times per second")

Each update cycle:
1. Collect events (unit deaths, construction finished, diplomacy changes)
2. `HQ.update()` - strategic decisions
3. `QueueManager.update()` - fund queued plans with resources

## Headquarters update order

`Headquarters.update()` executes managers in this fixed order:

```javascript
// headquarters.js, lines 2243-2350
this.emergencyManager.update(gameState);           // 1. Handle crises
// ... phase checking and worker training ...
this.researchManager.update(gameState, queues);    // 2. Tech research
this.tradeManager.update(gameState, events, queues); // 3. Trade
this.garrisonManager.update(gameState, events);    // 4. Garrisoning
this.defenseManager.update(gameState, events);     // 5. Defense
this.constructTrainingBuildings(gameState, queues); // 6. Military buildings
this.buildDefenses(gameState, queues);             // 7. Towers/walls
this.basesManager.update(gameState, queues, events); // 8. Economy
this.navalManager.update(gameState, queues, events); // 9. Naval
this.attackManager.update(gameState, queues, events); // 10. Attacks
this.diplomacyManager.update(gameState, events);   // 11. Diplomacy
this.victoryManager.update(gameState, events, queues); // 12. Victory
```

Some updates are staggered across turns to reduce load:
```javascript
if (gameState.ai.playedTurn % 4 == 0) this.trainMoreWorkers(gameState, queues);
if (gameState.ai.playedTurn % 4 == 1) this.buildMoreHouses(gameState, queues);
if (gameState.ai.playedTurn % 5 == 1) this.researchManager.update(...);
```

## Priority queue system

The `QueueManager` distributes resources based on priority weights:

```javascript
// config.js, lines 115-135
priorities = {
    "villager": 300,           // Worker training
    "citizenSoldier": 600,     // Combat unit training
    "trader": 1,               // Traders (low priority)
    "healer": 20,              // Support units
    "house": 250,              // Population buildings
    "dropsites": 950,          // Resource collection buildings (high)
    "field": 480,              // Farms
    "dock": 90,                // Naval buildings
    "economicBuilding": 700,   // Markets, temples
    "militaryBuilding": 330,   // Barracks, ranges
    "defenseBuilding": 70,     // Walls, towers (low by default)
    "civilCentre": 1,          // Expansion
    "majorTech": 700,          // Important research
    "minorTech": 250,          // Secondary tech
    "wonder": 1,               // Wonder
    "emergency": 1000          // Crisis response (highest)
}
```

### How resource distribution works

Each queue maintains its own resource account. When resources come in:

1. Calculate each queue's needs (cost of next item minus current account)
2. Distribute available resources proportionally by priority
3. If a queue has enough for its first item, halve its priority (prevents hogging)
4. Cap accounts at "first item + 60% of second item" to prevent excessive saving

```javascript
// queueManager.js, lines 243-330
QueueManager.prototype.distributeResources = function(gameState) {
    for (const res of Resources.GetCodes()) {
        let totalPriority = 0;
        for (const queue in this.queues) {
            const queueCost = this.queues[queue].maxAccountWanted(gameState, 0.6);
            if (this.accounts[queue][res] < queueCost[res]) {
                tempPrio[queue] = this.priorities[queue];
                // Halve priority if we already have enough for first item
                if (this.accounts[queue][res] >= this.queues[queue].getNext().getCost()[res])
                    tempPrio[queue] /= 2;
                totalPriority += tempPrio[queue];
            }
        }
        // Distribute proportionally
        for (const queue in tempPrio) {
            const toAdd = Math.floor(available * tempPrio[queue] / totalPriority);
            this.accounts[queue][res] += Math.min(toAdd, maxNeed[queue]);
        }
    }
}
```

### Queue pausing for recovery

If the AI loses many workers, it pauses non-essential queues:

```javascript
// queueManager.js, lines 431-491
if (numWorkers < workersMin / 3)
    // Only allow citizenSoldier, villager, emergency queues
if (numWorkers < workersMin * 2 / 3)
    // Pause civilCentre, economicBuilding, militaryBuilding, defenseBuilding, techs
if (numWorkers < workersMin)
    // Pause civilCentre, defenseBuilding, majorTech, siege, champions
```

## Configuration system

### Difficulty levels

```javascript
// difficultyLevel.js
SANDBOX = 0      // No attacks, 42% resource rate
VERY_EASY = 1    // 56% resource rate, slower building
EASY = 2         // 75% resource rate
MEDIUM = 3       // 100% baseline
HARD = 4         // 125% resource rate
VERY_HARD = 5    // 156% resource rate
```

Difficulty applies **cheating modifiers**:

```javascript
// config.js, lines 325-338
const rate = [ 0.42, 0.56, 0.75, 1.00, 1.25, 1.56 ];
const time = [ 1.40, 1.25, 1.10, 1.00, 1.00, 1.00 ];

SimEngine.QueryInterface(...).AddModifiers("AI Bonus", {
    "ResourceGatherer/BaseSpeed": [{ "multiply": rate[difficulty] }],
    "Trader/GainMultiplier": [{ "multiply": rate[difficulty] }],
    "Cost/BuildTime": [{ "multiply": time[difficulty] }]
}, ...);
```

### Personality system

At game start, personality traits are generated:

```javascript
// config.js, lines 210-227
const personalityList = {
    "random": { "min": 0, "max": 1 },
    "defensive": { "min": 0, "max": 0.27 },
    "balanced": { "min": 0.37, "max": 0.63 },
    "aggressive": { "min": 0.73, "max": 1 }
};

this.personality = {
    "aggressive": [0.0-1.0],   // Affects rush frequency, attack timing
    "defensive": [0.0-1.0],    // Affects tower/fortress building
    "cooperative": [0.0-1.0]   // Affects ally support
};
```

Personality affects many decisions:

```javascript
// Aggressive AI builds barracks earlier
if (this.personality.aggressive > this.personalityCut.strong) {
    this.Military.popForBarracks1 = 12;  // vs default 25
    this.Economy.popPhase2 = 50;
}

// Defensive AI builds more towers
this.Military.towerLapseTime *= (1.1 - 0.2 * this.personality.defensive);
this.priorities.defenseBuilding *= (0.9 + 0.2 * this.personality.defensive);
```

### Military parameters

```javascript
// config.js
Military: {
    towerLapseTime: 360,      // Seconds between building towers
    fortressLapseTime: 390,   // Seconds between fortresses
    popForBarracks1: 25,      // Population before first barracks
    popForBarracks2: 55,      // Population before second barracks
    popForForge: 65,          // Population before forge
    numSentryTowers: 1-2      // Towers to build (varies by difficulty)
}
```

### Economy parameters

```javascript
// config.js
Economy: {
    popPhase2: 150,           // Units before advancing to phase 2
    workPhase3: 180,          // Workers before phase 3
    workPhase4: 200,          // Workers before phase 4
    targetNumWorkers: 60,     // Target workforce (scales with difficulty)
    targetNumTraders: 1-6,    // Traders (1 + difficulty)
    supportRatio: 0.3,        // Support units as fraction of workers
    provisionFields: 2        // Number of farms
}
```

### Defense parameters

```javascript
// config.js
Defense: {
    defenseRatio: {
        "ally": 1.4,          // Defend allies with 1.4x enemy strength
        "neutral": 1.8,       // 1.8x in neutral territory
        "own": 2.0            // 2.0x in own territory
    },
    armyCompactSize: 2000,    // Squared distance for grouping units
    armyBreakawaySize: 3500,  // Distance before army splits
    armyMergeSize: 1400       // Distance for merging armies
}
```

## Worker system

Each unit is assigned a **role** and **subrole**:

```javascript
// worker.js, lines 17-33
Worker.ROLE_ATTACK = "attack";
Worker.ROLE_TRADER = "trader";
Worker.ROLE_WORKER = "worker";
Worker.ROLE_CRITICAL_ENT_GUARD = "criticalEntGuard";
Worker.ROLE_CRITICAL_ENT_HEALER = "criticalEntHealer";

Worker.SUBROLE_DEFENDER = "defender";
Worker.SUBROLE_IDLE = "idle";
Worker.SUBROLE_BUILDER = "builder";
Worker.SUBROLE_COMPLETING = "completing";
Worker.SUBROLE_WALKING = "walking";
Worker.SUBROLE_ATTACKING = "attacking";
Worker.SUBROLE_GATHERER = "gatherer";
Worker.SUBROLE_HUNTER = "hunter";
Worker.SUBROLE_FISHER = "fisher";
Worker.SUBROLE_GARRISONING = "garrisoning";
```

The `Worker.update()` function (1,148 lines) handles state transitions:

1. Check if waiting for transport
2. Handle combat state
3. For gatherers: find resources, return to dropsite
4. For builders: repair/construct buildings
5. For hunters: find animals
6. For fishers: find fish

Resource gathering priority:
1. Treasure (if any)
2. Hunt animals (for food gatherers)
3. Nearby resources in own base
4. Nearby resources in other accessible bases
5. Fields/farms
6. Medium-distance resources
7. Help build dropsites
8. Resources requiring transport
9. Faraway resources

## Attack system

### Attack types

```javascript
// attackPlan.js
TYPE_RUSH = "Rush"              // Early harassment (small, fast)
TYPE_RAID = "Raid"              // Destroy undefended structures
TYPE_DEFAULT = "Attack"         // Standard assault
TYPE_HUGE_ATTACK = "HugeAttack" // Massive army assault
```

### Attack states

```javascript
STATE_UNEXECUTED = "unexecuted"  // Being prepared
STATE_COMPLETING = "completing"  // Gathering units
STATE_ARRIVED = "arrived"        // Attacking
```

### Rush logic

Personality determines rush behavior:

```javascript
// attackManager.js, lines 45-62
AttackManager.prototype.setRushes = function(allowed) {
    if (this.Config.personality.aggressive > this.Config.personalityCut.strong && allowed > 2) {
        this.maxRushes = 3;
        this.rushSize = [ 16, 20, 24 ];  // 3 attacks
    }
    else if (this.Config.personality.aggressive > this.Config.personalityCut.medium && allowed > 1) {
        this.maxRushes = 2;
        this.rushSize = [ 18, 22 ];  // 2 attacks
    }
    else if (this.Config.personality.aggressive > this.Config.personalityCut.weak && allowed > 0) {
        this.maxRushes = 1;
        this.rushSize = [ 20 ];  // 1 attack
    }
}
```

### Attack creation

```javascript
// attackManager.js, lines 365-418
// Rush if we have a barracks and haven't done max rushes
if (this.rushNumber < this.maxRushes && barracksNb >= 1) {
    if (unexecutedAttacks[TYPE_RUSH] === 0) {
        const data = { "targetSize": this.rushSize[this.rushNumber] };
        const attackPlan = new AttackPlan(gameState, this.Config, this.totalNumber, TYPE_RUSH, data);
        // ...
    }
}
// Otherwise create regular attacks
else if (/* conditions for regular attack */) {
    const type = this.attackNumber < 2 ? TYPE_DEFAULT : TYPE_HUGE_ATTACK;
    const attackPlan = new AttackPlan(gameState, this.Config, this.totalNumber, type);
    // ...
}
```

### Target selection

1. Check victory conditions (wonder, relics)
2. Continue attacking previous target if still alive
3. Find nearest enemy civic center
4. Target strongest enemy (unit count + 500 if has civic center)

```javascript
// attackManager.js, lines 506-614
// Avoid rushing well-defended enemies (iberians)
if (attack.type === TYPE_RUSH) {
    let enemyDefense = 0;
    for (const ent of gameState.getEnemyStructures(i).values())
        if (ent.hasClasses(["Tower", "WallTower", "Fortress"]))
            enemyDefense++;
    if (enemyDefense > 6)
        veto[i] = true;
}
```

### Ally coordination

The AI responds to `AttackRequest` events from allies:

```javascript
// attackManager.js, lines 72-119
for (const evt of events.AttackRequest) {
    // ...
    if (available > 12) {  // Have enough units
        for (const attack of this.upcomingAttacks[attackType]) {
            if (attack.targetPlayer !== targetPlayer || attack.unitCollection.length < 3)
                continue;
            attack.forceStart();
            attack.requested = true;
        }
        answer = "join";
    }
}
```

## Defense system

The `DefenseManager` tracks enemy units and creates defensive "armies":

```javascript
// defenseManager.js, lines 10-24
DefenseManager = {
    armies: [],                    // Active defensive groups
    targetList: [],               // Enemy structures to destroy
    attackingArmies: {},          // enemies attacking allies
    attackingUnits: {},           // individual enemy units
    attackedAllies: {}            // allies under attack
}
```

### Threat detection

Units are considered dangerous if:
- In allied territory with attack capability
- Building enemy structures near our buildings
- Within attack range of our structures

```javascript
// defenseManager.js, lines 94-204
DefenseManager.prototype.isDangerous = function(gameState, entity) {
    // Check territory
    const territoryOwner = this.territoryMap.getOwner(entity.position());
    if (territoryOwner != 0 && !gameState.isPlayerAlly(territoryOwner))
        return false;

    // Check if building enemy base near us
    if (entity.unitAIState() == "INDIVIDUAL.REPAIR.REPAIRING") {
        // ... add to targetList
    }

    // Check attack range to our structures
    if (entity.attackTypes().indexOf("Ranged") != -1)
        dist2Min = (entity.attackRange("Ranged").max + 30)^2;

    for (const building of gameState.getOwnStructures().values()) {
        if (SquareVectorDistance(building.position(), entity.position()) < dist2Min)
            return true;
    }
}
```

### Defense response

Defense ratio determines how many units to assign:

```javascript
// config.js
defenseRatio: { "ally": 1.4, "neutral": 1.8, "own": 2 }
```

This means: to defend own base against 10 enemies, assign 20 defenders.

## Event system

The AI responds to game events rather than polling:

```javascript
// Events processed in checkEvents():
- TerritoriesChanged      // Territory boundaries changed
- DiplomacyChanged        // Alliance status changed
- ConstructionFinished    // Building completed
- OwnershipChanged        // Unit/building captured
- TrainingStarted         // Unit training began
- TrainingFinished        // Unit training completed
- TerritoryDecayChanged   // Structure decaying
- Attacked                // Entity attacked
- PlayerDefeated          // Player eliminated
- AttackRequest           // Ally requesting help
- EntityRenamed           // Entity ID changed (packing)
```

## Comparison with AoE2 rule system

| Aspect | AoE2 Rules | 0AD Petra |
|--------|------------|-----------|
| **Paradigm** | Declarative rules | Imperative code |
| **Decision model** | All matching rules fire | Managers execute in order |
| **State management** | Strategic numbers + goals | Config object + metadata |
| **Resource allocation** | Escrow + rule ordering | Priority-weighted queues |
| **Conflict resolution** | Engine limits + script order | Manager coordination |
| **Unit control** | Implicit via commands | Explicit role/subrole |
| **Extensibility** | Add new rules | Modify manager code |
| **Update frequency** | Several times/second | ~2-3 times/second |

### Key differences

1. **Independence**: AoE2 rules are independent - they don't call each other. 0AD managers explicitly coordinate.

2. **All rules fire**: In AoE2, every rule whose conditions are true will execute. In 0AD, managers have explicit control flow.

3. **First-class rules**: AoE2 rules can be enabled/disabled with `disable-self`, `enable-rule`. 0AD has no equivalent.

4. **Configuration**: AoE2 uses ~512 strategic numbers. 0AD uses ~350 config parameters with similar purpose.

5. **Personality**: 0AD's personality system is more explicit, with traits that multiply thresholds. AoE2 achieves similar effects through strategic numbers.

## Key source files

| File | Lines | Purpose |
|------|-------|---------|
| `_petrabot.js` | 172 | Entry point, update loop |
| `config.js` | 354 | All tunable parameters |
| `headquarters.js` | 2,459 | Strategic coordination |
| `queueManager.js` | 626 | Resource distribution |
| `attackManager.js` | 864 | Attack coordination |
| `attackPlan.js` | 2,286 | Individual attack execution |
| `defenseManager.js` | 988 | Defense logic |
| `baseManager.js` | 1,221 | Per-base economy |
| `worker.js` | 1,148 | Unit tasking |
| `basesManager.js` | 823 | Multi-base coordination |
| `navalManager.js` | 922 | Naval operations |

## What we can learn for our implementation

### Useful concepts to adopt

1. **Priority queue for resources**: Rather than rule ordering alone, explicit priority weights make resource allocation more transparent.

2. **Manager decomposition**: Separating attack, defense, economy into managers could help organize our rules into logical groups.

3. **Personality traits**: We could implement this via strategic numbers that shift thresholds (e.g., `sn-aggression-level` affecting attack timing).

4. **Recovery logic**: Queue pausing when workers are low is a good pattern - we could implement similar logic with goal variables.

5. **Starting analysis**: 0AD analyzes the map at game start to adjust strategy (water map, resource availability). We could do this with initialization rules.

### What to avoid

1. **Complexity**: 0AD's ~19k lines is much harder to modify than a rule file. The rule-based approach is more accessible.

2. **Tight coupling**: 0AD managers depend on each other. Independent rules are easier to reason about.

3. **Cheating modifiers**: Difficulty via resource multipliers feels unfair. Strategic number tuning is more elegant.

## References

- 0AD source: `binaries/data/mods/public/simulation/ai/petra/`
- 0AD common API: `binaries/data/mods/public/simulation/ai/common-api/`
- 0AD wiki: https://trac.wildfiregames.com/wiki/AI
