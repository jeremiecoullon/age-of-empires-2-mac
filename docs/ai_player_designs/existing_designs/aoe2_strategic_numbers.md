# AoE2 strategic numbers reference

This document lists strategic numbers (SNs) used in Age of Empires 2 AI scripting, with descriptions and recommended values.

Strategic numbers are tunable parameters that control AI behavior. There are 512 strategic numbers (numbered 0-511), with approximately 300 currently in use by the engine.

**Usage:**
```lisp
(set-strategic-number sn-food-gatherer-percentage 60)
```

**Sources:**
- [AoE2 AI Scripting Encyclopedia - Strategic Numbers Index](https://airef.github.io/strategic-numbers/sn-index.html)
- [Steam AI Scripting Guide](https://steamcommunity.com/sharedfiles/filedetails/?id=1238296169)
- [UserPatch Scripting Reference](https://userpatch.aiscripters.net/reference.html)
- Community AI scripts and forum discussions

---

## Resource gathering allocation

These control what percentage of villagers gather each resource. **Must sum to 100** or villagers may idle.

| Strategic Number | Description | Recommended |
|------------------|-------------|-------------|
| `sn-food-gatherer-percentage` | Percentage of villagers assigned to food | 60 (Dark Age), varies by strategy |
| `sn-wood-gatherer-percentage` | Percentage of villagers assigned to wood | 30 (Dark Age), varies by strategy |
| `sn-gold-gatherer-percentage` | Percentage of villagers assigned to gold | 0 (Dark Age), 20-30 (Feudal+) |
| `sn-stone-gatherer-percentage` | Percentage of villagers assigned to stone | 0-10 depending on strategy |

**Example allocations by age:**

```lisp
; Dark Age - focus food and wood
(set-strategic-number sn-food-gatherer-percentage 60)
(set-strategic-number sn-wood-gatherer-percentage 40)
(set-strategic-number sn-gold-gatherer-percentage 0)
(set-strategic-number sn-stone-gatherer-percentage 0)

; Feudal Age - add gold for military
(set-strategic-number sn-food-gatherer-percentage 50)
(set-strategic-number sn-wood-gatherer-percentage 30)
(set-strategic-number sn-gold-gatherer-percentage 20)
(set-strategic-number sn-stone-gatherer-percentage 0)

; Castle Age - balanced with some stone
(set-strategic-number sn-food-gatherer-percentage 40)
(set-strategic-number sn-wood-gatherer-percentage 25)
(set-strategic-number sn-gold-gatherer-percentage 25)
(set-strategic-number sn-stone-gatherer-percentage 10)
```

---

## Civilian labor distribution

These control what villagers do (gather, build, explore). **Should sum to 100.**

| Strategic Number | Description | Recommended |
|------------------|-------------|-------------|
| `sn-percent-civilian-gatherers` | Percentage of villagers gathering resources | 80-90 |
| `sn-percent-civilian-builders` | Percentage of villagers available for building | 10-20 |
| `sn-percent-civilian-explorers` | Percentage of villagers scouting | 0-5 |

```lisp
; Typical setup - most gather, some build, don't scout with villagers
(set-strategic-number sn-percent-civilian-gatherers 85)
(set-strategic-number sn-percent-civilian-builders 15)
(set-strategic-number sn-percent-civilian-explorers 0)
```

---

## Exploration and scouting

| Strategic Number | Description | Recommended |
|------------------|-------------|-------------|
| `sn-percent-civilian-explorers` | Percentage of villagers used for scouting | 0 (use scout unit instead) |
| `sn-cap-civilian-explorers` | Maximum number of civilian explorers | 0 |
| `sn-total-number-explorers` | Total scout units to use for exploration | 1 |
| `sn-number-explore-groups` | Number of exploration groups | 1 |
| `sn-initial-exploration-required` | Whether to explore before building (0=no, 1=yes) | 0 |
| `sn-minimum-explore-group-size` | Minimum units per exploration group | 1 |
| `sn-maximum-explore-group-size` | Maximum units per exploration group | 1 |

```lisp
; Scout with scout cavalry, not villagers
(set-strategic-number sn-percent-civilian-explorers 0)
(set-strategic-number sn-cap-civilian-explorers 0)
(set-strategic-number sn-total-number-explorers 1)
(set-strategic-number sn-number-explore-groups 1)
(set-strategic-number sn-initial-exploration-required 0)
```

---

## Drop-off distances

Control how far villagers will travel to gather resources before building a new drop-off.

| Strategic Number | Description | Recommended |
|------------------|-------------|-------------|
| `sn-maximum-wood-drop-distance` | Max tiles from lumber camp to trees (-1 = unlimited) | -1 or 8 |
| `sn-maximum-food-drop-distance` | Max tiles from mill/TC to food | 8 |
| `sn-maximum-gold-drop-distance` | Max tiles from mining camp to gold | 8 |
| `sn-maximum-stone-drop-distance` | Max tiles from mining camp to stone | 8 |
| `sn-maximum-hunt-drop-distance` | Max tiles for hunting (boar, deer) | 48 |
| `sn-mill-max-distance` | Max distance to build mill from food | 25 |
| `sn-camp-max-distance` | Max distance to build lumber/mining camp from resource | 25 |
| `sn-dropsite-separation-distance` | Minimum distance between drop-off buildings | 5 |
| `sn-allow-adjacent-dropsites` | Allow building camps next to each other (0=no, 1=yes) | 1 |

```lisp
(set-strategic-number sn-maximum-wood-drop-distance -1)
(set-strategic-number sn-maximum-food-drop-distance 8)
(set-strategic-number sn-maximum-gold-drop-distance 8)
(set-strategic-number sn-maximum-stone-drop-distance 8)
(set-strategic-number sn-maximum-hunt-drop-distance 48)
(set-strategic-number sn-mill-max-distance 25)
(set-strategic-number sn-camp-max-distance 25)
(set-strategic-number sn-dropsite-separation-distance 5)
(set-strategic-number sn-allow-adjacent-dropsites 1)
```

---

## Building placement

| Strategic Number | Description | Recommended |
|------------------|-------------|-------------|
| `sn-maximum-town-size` | Radius (tiles) for building placement around TC | 24 (expand for attacks) |
| `sn-minimum-town-size` | Minimum town radius | 12 |
| `sn-safe-town-size` | Safe zone radius for defensive buildings | 20 |
| `sn-percent-building-cancellation` | Percentage chance to cancel stuck buildings | 25 |
| `sn-cap-civilian-builders` | Maximum villagers that can build simultaneously | 4 |

```lisp
(set-strategic-number sn-maximum-town-size 24)
(set-strategic-number sn-minimum-town-size 12)
(set-strategic-number sn-safe-town-size 20)
(set-strategic-number sn-percent-building-cancellation 25)
(set-strategic-number sn-cap-civilian-builders 4)
```

---

## Military - attack settings

| Strategic Number | Description | Recommended |
|------------------|-------------|-------------|
| `sn-percent-attack-soldiers` | Percentage of military to send when attacking | 100 |
| `sn-percent-attack-boats` | Percentage of navy to send when attacking | 100 |
| `sn-number-attack-groups` | Number of attack groups (0 = don't attack, 200 = attack) | 0 (wait) or 200 (attack) |
| `sn-minimum-attack-group-size` | Minimum units before forming attack group | 5 |
| `sn-maximum-attack-group-size` | Maximum units per attack group | 20 |
| `sn-attack-intelligence` | Enable smart pathfinding (0=off, 1=on) | 1 |
| `sn-task-ungrouped-soldiers` | Let ungrouped soldiers wander (0=no, 1=yes) | 0 |
| `sn-gather-defense-units` | Gather units for defense when attacked | 1 |
| `sn-enable-patrol-attack` | Use patrol command for attacks | 1 |
| `sn-consecutive-idle-unit-limit` | Idle units before reassigning | 1 |
| `sn-target-evaluation-distance` | Distance to evaluate targets | 10 |
| `sn-target-evaluation-hitpoints` | Weight for HP in target selection | 100 |
| `sn-target-evaluation-damage-capability` | Weight for damage in target selection | 100 |
| `sn-target-evaluation-kills` | Weight for kills in target selection | 0 |
| `sn-target-evaluation-threat-source` | Weight for threat source | 0 |
| `sn-target-evaluation-randomness` | Random factor in target selection | 0 |

```lisp
; Attack configuration
(set-strategic-number sn-percent-attack-soldiers 100)
(set-strategic-number sn-percent-attack-boats 100)
(set-strategic-number sn-minimum-attack-group-size 5)
(set-strategic-number sn-maximum-attack-group-size 20)
(set-strategic-number sn-attack-intelligence 1)
(set-strategic-number sn-task-ungrouped-soldiers 0)
(set-strategic-number sn-gather-defense-units 1)
(set-strategic-number sn-enable-patrol-attack 1)
(set-strategic-number sn-consecutive-idle-unit-limit 1)
```

---

## Military - defense settings

| Strategic Number | Description | Recommended |
|------------------|-------------|-------------|
| `sn-sentry-distance` | Distance sentries patrol from base | 10 |
| `sn-percent-enemy-sighted-response` | Percentage of army to respond to threats | 100 |
| `sn-enemy-sighted-response-distance` | Distance to respond to enemy sightings | 20 |
| `sn-blot-exploration-map` | Clear explored areas when enemy spotted | 0 |
| `sn-blot-size` | Size of area to clear | 10 |
| `sn-defend-priority` | Priority for defensive actions | 0 |
| `sn-number-defend-groups` | Number of defense groups | 1 |
| `sn-minimum-defend-group-size` | Minimum units per defense group | 3 |
| `sn-maximum-defend-group-size` | Maximum units per defense group | 10 |

```lisp
(set-strategic-number sn-sentry-distance 10)
(set-strategic-number sn-percent-enemy-sighted-response 100)
(set-strategic-number sn-enemy-sighted-response-distance 20)
(set-strategic-number sn-number-defend-groups 1)
(set-strategic-number sn-minimum-defend-group-size 3)
(set-strategic-number sn-maximum-defend-group-size 10)
```

---

## Military - group formation

| Strategic Number | Description | Recommended |
|------------------|-------------|-------------|
| `sn-group-commander-selection-method` | How group leaders are chosen (0=closest, 1=strongest) | 0 |
| `sn-group-form-distance` | Distance units travel to form groups | 999 (large = less reforming) |
| `sn-scale-minimum-attack-group-size` | Scale attack group size with game time | 0 |
| `sn-attack-group-size-randomness` | Random variation in attack group size | 0 |

```lisp
(set-strategic-number sn-group-commander-selection-method 0)
(set-strategic-number sn-group-form-distance 999)
(set-strategic-number sn-scale-minimum-attack-group-size 0)
```

---

## Military - garrison and rams

| Strategic Number | Description | Recommended |
|------------------|-------------|-------------|
| `sn-garrison-rams` | Garrison infantry in rams (0=no, 1=yes) | 1 |
| `sn-number-boat-attack-groups` | Number of naval attack groups | 1 |
| `sn-minimum-boat-attack-group-size` | Minimum ships per attack group | 5 |
| `sn-maximum-boat-attack-group-size` | Maximum ships per attack group | 10 |

```lisp
(set-strategic-number sn-garrison-rams 1)
```

---

## Special behaviors

| Strategic Number | Description | Recommended |
|------------------|-------------|-------------|
| `sn-enable-boar-hunting` | Hunt boars (0=no, 1=yes) | 1 |
| `sn-minimum-boar-hunt-group-size` | Minimum villagers for boar hunting | 3 |
| `sn-defer-dropsite-update` | Prevent villager suicide runs to distant resources | 1 |
| `sn-do-not-scale-for-difficulty-level` | Ignore difficulty bonuses (0=scale, 1=don't) | 0 |
| `sn-enable-offensive-priority` | Prioritize offensive actions | 1 |
| `sn-zero-priority-distance` | Distance at which priority becomes zero | 255 |
| `sn-retask-gather-amount` | Resources gathered before retasking villager | 10 |

```lisp
(set-strategic-number sn-enable-boar-hunting 1)
(set-strategic-number sn-minimum-boar-hunt-group-size 3)
(set-strategic-number sn-defer-dropsite-update 1)
(set-strategic-number sn-enable-offensive-priority 1)
(set-strategic-number sn-zero-priority-distance 255)
```

---

## Difficulty and cheats

| Strategic Number | Description | Recommended |
|------------------|-------------|-------------|
| `sn-do-not-scale-for-difficulty-level` | Disable difficulty scaling | 0 |
| `sn-allow-civilian-offense` | Allow villagers to attack | 0 |
| `sn-allow-civilian-defense` | Allow villagers to defend | 1 |

---

## Town bell and retreat

| Strategic Number | Description | Recommended |
|------------------|-------------|-------------|
| `sn-hits-before-alliance-change` | Hits before breaking alliance | 5 |
| `sn-attack-diplomacy-impact` | How attacks affect diplomacy | 0 |
| `sn-minimum-peace-like-level` | Minimum diplomacy level for peace | 50 |

---

## Complete initialization example

Here's a comprehensive initialization rule that sets up most important strategic numbers:

```lisp
(defrule
  (true)
=>
  ; === Resource allocation (Dark Age) ===
  (set-strategic-number sn-food-gatherer-percentage 60)
  (set-strategic-number sn-wood-gatherer-percentage 40)
  (set-strategic-number sn-gold-gatherer-percentage 0)
  (set-strategic-number sn-stone-gatherer-percentage 0)

  ; === Civilian distribution ===
  (set-strategic-number sn-percent-civilian-gatherers 85)
  (set-strategic-number sn-percent-civilian-builders 15)
  (set-strategic-number sn-percent-civilian-explorers 0)
  (set-strategic-number sn-cap-civilian-builders 4)

  ; === Exploration ===
  (set-strategic-number sn-cap-civilian-explorers 0)
  (set-strategic-number sn-total-number-explorers 1)
  (set-strategic-number sn-number-explore-groups 1)
  (set-strategic-number sn-initial-exploration-required 0)

  ; === Drop-off distances ===
  (set-strategic-number sn-maximum-wood-drop-distance -1)
  (set-strategic-number sn-maximum-food-drop-distance 8)
  (set-strategic-number sn-maximum-gold-drop-distance 8)
  (set-strategic-number sn-maximum-stone-drop-distance 8)
  (set-strategic-number sn-maximum-hunt-drop-distance 48)
  (set-strategic-number sn-mill-max-distance 25)
  (set-strategic-number sn-camp-max-distance 25)
  (set-strategic-number sn-dropsite-separation-distance 5)
  (set-strategic-number sn-allow-adjacent-dropsites 1)

  ; === Building placement ===
  (set-strategic-number sn-maximum-town-size 24)
  (set-strategic-number sn-minimum-town-size 12)
  (set-strategic-number sn-percent-building-cancellation 25)

  ; === Attack settings ===
  (set-strategic-number sn-percent-attack-soldiers 100)
  (set-strategic-number sn-percent-attack-boats 100)
  (set-strategic-number sn-minimum-attack-group-size 5)
  (set-strategic-number sn-maximum-attack-group-size 20)
  (set-strategic-number sn-attack-intelligence 1)
  (set-strategic-number sn-task-ungrouped-soldiers 0)
  (set-strategic-number sn-gather-defense-units 1)
  (set-strategic-number sn-enable-patrol-attack 1)
  (set-strategic-number sn-consecutive-idle-unit-limit 1)
  (set-strategic-number sn-group-commander-selection-method 0)
  (set-strategic-number sn-group-form-distance 999)

  ; === Defense settings ===
  (set-strategic-number sn-sentry-distance 10)
  (set-strategic-number sn-percent-enemy-sighted-response 100)
  (set-strategic-number sn-enemy-sighted-response-distance 20)

  ; === Special behaviors ===
  (set-strategic-number sn-enable-boar-hunting 1)
  (set-strategic-number sn-minimum-boar-hunt-group-size 3)
  (set-strategic-number sn-defer-dropsite-update 1)
  (set-strategic-number sn-garrison-rams 1)
  (set-strategic-number sn-enable-offensive-priority 1)
  (set-strategic-number sn-zero-priority-distance 255)

  (disable-self)
)
```

---

## Notes for implementation

1. **Not all strategic numbers have documented defaults.** The engine has internal defaults that may differ from what's shown here. These recommendations are based on community scripts.

2. **Some strategic numbers are version-specific.** UserPatch and Definitive Edition added many new SNs. Check [airef.github.io](https://airef.github.io/strategic-numbers/sn-index.html) for version compatibility.

3. **Strategic numbers can be overwritten by the game engine** in certain situations (e.g., difficulty settings).

4. **For custom SNs (if extending the system):** Start from ID 510 and work downward to avoid conflicts with future official additions.

5. **The full list has 300+ active strategic numbers.** This document covers the most commonly used ones. See the references for the complete list.
