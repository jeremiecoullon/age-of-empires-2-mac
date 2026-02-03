# AoE2 AI rule-based system

This document describes how the original Age of Empires 2 AI scripting system works. The goal is to implement a similar rule-based system in our Godot clone.

## Overview

The AoE2 AI uses a **rule-based expert system**. Instead of procedural code with nested if-else chains, the AI consists of many small, independent rules that are evaluated continuously.

Key characteristics:
- Rules are independent - they don't call each other
- All matching rules fire - there's no "first match wins"
- The game engine handles conflicts (resource limits, build limits, etc.)
- State is tracked via "strategic numbers" (tunable parameters) and "goals" (variables)

## Rule passes

The game engine evaluates all rules **several times per second**. Each complete evaluation cycle is called a "rule pass". The exact frequency is not documented - sources consistently say "several times per second" without specifying a precise number.

During each rule pass:
1. The engine reads the script from top to bottom
2. For each rule, it checks if all conditions are true
3. If true, all actions in that rule execute
4. Rules remain active for future passes unless explicitly disabled

**Important engine limits:**
- Training and research actions execute immediately, but **multiple identical commands in one pass don't stack** - issuing `(train villager)` three times still only trains one villager
- Only **one building can be placed per rule pass** (queued, built at end of pass)
- Rules continue firing every pass unless disabled with `(disable-self)`

## Resource conflicts and rule ordering

When multiple rules fire in the same pass and compete for the same limited resources, **rule order matters**. Rules earlier in the script file get first access to resources.

**How it works (inferred behavior - not explicitly documented):**

1. Conditions like `(can-build house)` check resource availability at **condition evaluation time**
2. Resources are **deducted when actions execute**, not when conditions are checked
3. If Rule A and Rule B both have `(can-build house)` as a condition, and you only have enough wood for one house:
   - Both rules' conditions evaluate to TRUE (resources existed when each was checked)
   - Rule A (earlier in file) executes `(build house)` → resources deducted
   - Rule B executes `(build house)` → **fails silently** (insufficient resources)

**Implications for script design:**
- Put higher-priority actions earlier in your script
- Use the escrow system to reserve resources for critical actions (like age advancement)
- Don't assume that passing `(can-build X)` guarantees the build will succeed

> **Note:** This ordering behavior is inferred from community documentation and script patterns. The official CPSB documentation doesn't explicitly describe this mechanism. We'll validate this behavior during implementation.

## Rule syntax

Rules use a LISP-like syntax:

```lisp
(defrule
  (condition-1)
  (condition-2)
  (condition-3)
=>
  (action-1)
  (action-2)
  (action-3)
)
```

- `defrule` starts a rule definition
- Conditions (facts) come before the `=>` symbol
- Actions come after `=>`
- ALL conditions must be true for actions to execute
- Parentheses are required around everything
- Semicolons `;` start comments

**Limits:**
- Maximum 16 lines per rule
- Maximum 999 rules total per AI script

## Conditions (facts)

Conditions check game state. Common ones:

### Unit and building counts
```lisp
(unit-type-count villager > 10)           ; More than 10 villagers
(unit-type-count-total militia >= 5)      ; At least 5 militia (including queued)
(building-type-count-total house < 4)     ; Fewer than 4 houses
(building-type-count barracks == 0)       ; No barracks built
(civilian-population < 30)                ; Fewer than 30 villagers
(military-population >= 10)               ; At least 10 military units
```

### Resources and economy
```lisp
(food-amount >= 200)                      ; Have at least 200 food
(wood-amount < 100)                       ; Have less than 100 wood
(can-afford-building house)               ; Can afford to build a house
(resource-found wood)                     ; Scouted wood on map
(resource-found gold)                     ; Scouted gold on map
(dropsite-min-distance wood > 3)          ; Nearest tree is more than 3 tiles from drop-off
(idle-farm-count >= 1)                    ; At least one idle farm
```

### Training and building
```lisp
(can-train villager)                      ; Can train villager (resources + pop space)
(can-train militia)                       ; Can train militia
(can-build house)                         ; Can build house (resources + prerequisites)
(can-build barracks)                      ; Can build barracks
(can-research feudal-age)                 ; Can research Feudal Age advancement
(can-research ri-loom)                    ; Can research Loom
```

### Game state
```lisp
(current-age == dark-age)                 ; Currently in Dark Age
(current-age >= feudal-age)               ; In Feudal Age or later
(game-time >= 600)                        ; At least 10 minutes elapsed
(population-headroom > 0)                 ; Have room for more population
(housing-headroom < 5)                    ; Within 5 of population cap
(town-under-attack)                       ; Base is being attacked
(enemy-buildings-in-town)                 ; Enemy buildings detected in our territory
```

### Special
```lisp
(true)                                    ; Always true - rule always fires
(goal 1 1)                                ; Goal variable 1 equals 1
(timer-triggered 1)                       ; Timer 1 has elapsed
```

### Comparison operators
- `>` greater than
- `>=` greater than or equal
- `<` less than
- `<=` less than or equal
- `==` equal (note: double equals)
- `!=` not equal

### Boolean operators
```lisp
(or (condition-1) (condition-2))          ; Either condition true
(and (condition-1) (condition-2))         ; Both conditions true (rarely needed - implicit)
(not (condition))                         ; Condition is false
```

## Actions

Actions are what the AI does when conditions are met.

### Building
```lisp
(build house)                             ; Build a house
(build barracks)                          ; Build a barracks
(build lumber-camp)                       ; Build a lumber camp
(build mill)                              ; Build a mill
(build farm)                              ; Build a farm
```

### Training units
```lisp
(train villager)                          ; Train a villager
(train militia)                           ; Train a militia
(train archer)                            ; Train an archer
(train spearman)                          ; Train a spearman
(train scout-cavalry)                     ; Train a scout cavalry
```

### Research
```lisp
(research feudal-age)                     ; Advance to Feudal Age
(research castle-age)                     ; Advance to Castle Age
(research ri-loom)                        ; Research Loom
(research ri-fletching)                   ; Research Fletching
```

### Military commands
```lisp
(attack-now)                              ; Send military to attack
(defend-target tc-location)               ; Defend the town center
```

### Strategic numbers
```lisp
(set-strategic-number sn-food-gatherer-percentage 60)
(set-strategic-number sn-wood-gatherer-percentage 30)
(set-strategic-number sn-percent-attack-soldiers 100)
```

### Rule control
```lisp
(disable-self)                            ; This rule won't fire again
(enable-rule my-rule)                     ; Enable a named rule
(disable-rule my-rule)                    ; Disable a named rule
```

### Goals (state variables)
```lisp
(set-goal 1 0)                            ; Set goal 1 to value 0
(set-goal 1 1)                            ; Set goal 1 to value 1
```

### Timers
```lisp
(enable-timer 1 30)                       ; Start timer 1 for 30 seconds
(disable-timer 1)                         ; Stop timer 1
```

### Escrow (resource reservation)

The escrow system allows reserving a percentage of incoming resources for high-priority actions (like age advancement). Resources in escrow are invisible to normal `can-build`/`can-train` checks.

```lisp
(set-escrow-percentage food 50)           ; Save 50% of food income
(release-escrow food)                     ; Release all saved food
(can-build-with-escrow barracks)          ; Check if can build including escrowed resources
```

**Common pattern for age advancement:**
```lisp
(defrule
  (can-research-with-escrow feudal-age)
=>
  (release-escrow food)
  (release-escrow gold)
  (research feudal-age)
)
```

### Debugging
```lisp
(chat-to-all "Message")                   ; Send message to all players
(chat-local-to-self "Debug")              ; Send message visible only to AI (debug)
```

## Strategic numbers

Strategic numbers are tunable parameters that control AI behavior. There are 512 strategic numbers (numbered 0-511), with approximately 300 currently in use by the engine.

For a comprehensive list of strategic numbers with descriptions and recommended values, see `aoe2_strategic_numbers.md`.

Here are the most important categories:

### Resource gathering allocation
```lisp
(set-strategic-number sn-food-gatherer-percentage 60)   ; 60% of villagers on food
(set-strategic-number sn-wood-gatherer-percentage 30)   ; 30% on wood
(set-strategic-number sn-gold-gatherer-percentage 10)   ; 10% on gold
(set-strategic-number sn-stone-gatherer-percentage 0)   ; 0% on stone
```
Note: These must sum to 100 or villagers may idle.

### Civilian labor distribution
```lisp
(set-strategic-number sn-percent-civilian-gatherers 80)  ; 80% gather resources
(set-strategic-number sn-percent-civilian-builders 15)   ; 15% build structures
(set-strategic-number sn-percent-civilian-explorers 5)   ; 5% explore
```

### Exploration
```lisp
(set-strategic-number sn-percent-civilian-explorers 0)   ; Don't scout with villagers
(set-strategic-number sn-total-number-explorers 1)       ; Use 1 scout unit
(set-strategic-number sn-number-explore-groups 1)        ; 1 exploration group
(set-strategic-number sn-initial-exploration-required 0) ; Don't wait for exploration before building
```

### Building placement
```lisp
(set-strategic-number sn-maximum-town-size 24)           ; Town radius for building placement
(set-strategic-number sn-minimum-town-size 12)           ; Minimum town radius
(set-strategic-number sn-camp-max-distance 10)           ; Max distance for resource camps
```

### Military and attack
```lisp
(set-strategic-number sn-percent-attack-soldiers 100)    ; Send 100% of army when attacking
(set-strategic-number sn-percent-attack-boats 100)       ; Send 100% of navy when attacking
(set-strategic-number sn-number-attack-groups 200)       ; Number of attack groups (high = attack)
(set-strategic-number sn-minimum-attack-group-size 5)    ; Minimum units before attacking
(set-strategic-number sn-maximum-attack-group-size 20)   ; Maximum units per attack group
(set-strategic-number sn-attack-intelligence 1)          ; Enable smart pathfinding
(set-strategic-number sn-gather-defense-units 1)         ; Gather units for defense
(set-strategic-number sn-enable-patrol-attack 1)         ; Use patrol for attacks
(set-strategic-number sn-task-ungrouped-soldiers 0)      ; Don't let soldiers wander (default is 1)
```

### Defense
```lisp
(set-strategic-number sn-sentry-distance 10)             ; How far sentries patrol
(set-strategic-number sn-percent-enemy-sighted-response 100)  ; Respond to all enemies
(set-strategic-number sn-enemy-sighted-response-distance 20)  ; Response radius
```

### Special behaviors
```lisp
(set-strategic-number sn-enable-boar-hunting 1)          ; Hunt boars
(set-strategic-number sn-intelligent-gathering 1)        ; Smart resource switching
(set-strategic-number sn-defer-dropsite-update 1)        ; Prevent villager suicide runs
```

## Goals (state variables)

Goals are integer variables for tracking AI state.

**Availability:**
- Original game (1.0c): 40 goals (numbered 1-40)
- UserPatch / Definitive Edition: 512 goals (numbered 1-512)

**Value range:** -32,768 to 32,767 (16-bit signed integer)

### Setting goals
```lisp
(set-goal 1 0)    ; Set goal 1 to 0
(set-goal 1 1)    ; Set goal 1 to 1
```

### Checking goals
```lisp
(goal 1 0)        ; True if goal 1 equals 0
(goal 1 1)        ; True if goal 1 equals 1
```

### Using constants for readability
```lisp
(defconst gl-attack-ready 1)              ; Goal 1 is "attack ready" flag
(defconst gl-economy-mode 2)              ; Goal 2 is "economy mode"

; Then use them:
(set-goal gl-attack-ready 1)
(goal gl-attack-ready 1)
```

## Constants

Constants make code readable and maintainable:

```lisp
(defconst my-target-villagers 30)
(defconst my-min-military 10)
(defconst timer-attack 1)
(defconst gl-has-barracks 1)

; Use them in rules:
(defrule
  (civilian-population >= my-target-villagers)
  (military-population >= my-min-military)
=>
  (set-goal gl-has-barracks 1)
)
```

Constants cannot be changed after definition - use goals for mutable state.

## Timers

Timers allow time-based actions:

```lisp
(defconst timer-attack 1)

; Start the timer (runs once)
(defrule
  (true)
=>
  (enable-timer timer-attack 60)    ; 60 seconds
  (disable-self)
)

; When timer fires
(defrule
  (timer-triggered timer-attack)
  (military-population >= 10)
=>
  (attack-now)
  (disable-timer timer-attack)
  (enable-timer timer-attack 60)    ; Restart for next attack
)
```

## Conditional compilation

Load different code based on civilization or game settings:

```lisp
#load-if-defined BRITON-CIV
  ; Briton-specific rules here
  (defrule
    (can-train longbowman)
  =>
    (train longbowman)
  )
#end-if

#load-if-defined HUNS-CIV
  ; Huns don't need houses
#else
  (defrule
    (housing-headroom < 5)
    (can-build house)
  =>
    (build house)
  )
#end-if
```

## How multiple matching rules work

When multiple rules' conditions are all true, **all of them fire** in the same pass.

Example:
```lisp
; Rule 1: Train villagers if we can
(defrule
  (can-train villager)
  (civilian-population < 30)
=>
  (train villager)
)

; Rule 2: Train villagers if under attack (redundant, but valid)
(defrule
  (can-train villager)
  (town-under-attack)
=>
  (train villager)
)

; Rule 3: Train militia if we can
(defrule
  (can-train militia)
=>
  (train militia)
)
```

If you can train villagers AND you're under attack AND you can train militia, ALL THREE rules fire.

**Why this doesn't cause problems:**
- The game engine handles resource checks at action time - you can't train without resources
- Training commands don't "stack" - multiple `(train villager)` commands in one pass still train only one villager
- Building is limited to one per pass regardless of how many rules request it

This means you can write rules that express **reasons** to do things, not exclusive commands:

```lisp
; Train militia because we have extra food
(defrule
  (food-amount >= 200)
  (can-train militia)
=>
  (train militia)
)

; Train militia because we're being attacked
(defrule
  (town-under-attack)
  (can-train militia)
=>
  (train militia)
)

; Train militia because we're in Feudal Age
(defrule
  (current-age >= feudal-age)
  (can-train militia)
=>
  (train militia)
)
```

All three might fire, but the engine ensures you only train what you can afford.

## Attack methods

There are three main ways to make the AI attack:

### Method 1: attack-now

Simple timer-based attacks. Only sends a fraction of the army.

```lisp
(defconst timer-attack 1)

(defrule
  (true)
=>
  (set-strategic-number sn-number-explore-groups 1)
  (enable-timer timer-attack 60)
  (disable-self)
)

(defrule
  (timer-triggered timer-attack)
  (military-population >= 10)
=>
  (attack-now)
  (disable-timer timer-attack)
  (enable-timer timer-attack 60)
)
```

**Pros:** Fewest lines of code. Works for naval attacks.
**Cons:** Only sends a fraction of soldiers, even with `sn-percent-attack-soldiers` at 100. Units may get stuck on walls.

### Method 2: attack-groups

Sends all soldiers, better pathfinding around obstacles.

```lisp
(defconst timer-wait 1)
(defconst timer-attack 2)

; Start in wait mode
(defrule
  (true)
=>
  (set-strategic-number sn-number-attack-groups 0)
  (enable-timer timer-wait 40)
  (disable-self)
)

; After waiting, switch to attack mode
(defrule
  (timer-triggered timer-wait)
  (military-population >= 10)
=>
  (set-strategic-number sn-number-attack-groups 200)
  (disable-timer timer-wait)
  (enable-timer timer-attack 20)
)

; After attacking, switch back to wait mode
(defrule
  (timer-triggered timer-attack)
=>
  (set-strategic-number sn-number-attack-groups 0)
  (disable-timer timer-attack)
  (enable-timer timer-wait 40)
)
```

**Pros:** Sends all available soldiers. Less stuck on walls than attack-now.
**Cons:** More code than attack-now. Only works for land units.

### Method 3: town size attack

Expands the AI's "town" boundary, triggering defense responses against anything in range.

```lisp
(defconst timer-expand 1)
(defconst gl-town-size 1)

(defrule
  (true)
=>
  (set-goal gl-town-size 24)
  (set-strategic-number sn-maximum-town-size 24)
  (enable-timer timer-expand 5)
  (disable-self)
)

(defrule
  (timer-triggered timer-expand)
  (goal gl-town-size < 144)
=>
  ; Expand town size
  (up-modify-goal gl-town-size c:+ 12)
  (up-modify-sn sn-maximum-town-size g:= gl-town-size)
  (disable-timer timer-expand)
  (enable-timer timer-expand 5)
)
```

**Pros:** Prioritizes attacking nearest enemy buildings. Good coordination.
**Cons:** Most code-intensive of the three methods.

## Complete example: Dark Age economy

Here's a minimal working AI that handles Dark Age economy:

```lisp
; ==========================================
; CONSTANTS
; ==========================================
(defconst my-target-villagers 25)
(defconst my-target-farms 6)

; ==========================================
; INITIALIZATION (runs once)
; ==========================================
(defrule
  (true)
=>
  ; Resource allocation
  (set-strategic-number sn-food-gatherer-percentage 60)
  (set-strategic-number sn-wood-gatherer-percentage 40)
  (set-strategic-number sn-gold-gatherer-percentage 0)
  (set-strategic-number sn-stone-gatherer-percentage 0)

  ; Don't scout with villagers
  (set-strategic-number sn-percent-civilian-explorers 0)
  (set-strategic-number sn-total-number-explorers 1)

  ; Allow building before full exploration
  (set-strategic-number sn-initial-exploration-required 0)

  ; Enable boar hunting
  (set-strategic-number sn-enable-boar-hunting 1)

  (disable-self)
)

; ==========================================
; HOUSING
; ==========================================
(defrule
  (housing-headroom < 5)
  (population-headroom > 0)
  (can-build house)
=>
  (build house)
)

; ==========================================
; VILLAGER PRODUCTION
; ==========================================
(defrule
  (civilian-population < my-target-villagers)
  (can-train villager)
=>
  (train villager)
)

; ==========================================
; RESOURCE BUILDINGS
; ==========================================

; Build lumber camp when trees are far
(defrule
  (resource-found wood)
  (dropsite-min-distance wood > 3)
  (can-build lumber-camp)
=>
  (build lumber-camp)
)

; Build mill for berries/hunting
(defrule
  (resource-found food)
  (dropsite-min-distance food > 3)
  (building-type-count-total mill < 1)
  (can-build mill)
=>
  (build mill)
)

; Build mining camp for gold
(defrule
  (resource-found gold)
  (dropsite-min-distance gold > 3)
  (building-type-count-total mining-camp < 1)
  (can-build mining-camp)
=>
  (build mining-camp)
)

; ==========================================
; FARMS
; ==========================================
(defrule
  (building-type-count-total farm < my-target-farms)
  (can-build farm)
=>
  (build farm)
)

; ==========================================
; AGE ADVANCEMENT
; ==========================================
(defrule
  (civilian-population >= 21)
  (can-research feudal-age)
=>
  (research feudal-age)
)

; Research loom for villager survivability
(defrule
  (can-research ri-loom)
=>
  (research ri-loom)
)
```

## Complete example: military and attacking

Extending the above with military:

```lisp
; ==========================================
; ADDITIONAL CONSTANTS
; ==========================================
(defconst my-min-military 10)
(defconst timer-attack 1)

; ==========================================
; MILITARY BUILDINGS
; ==========================================
(defrule
  (current-age >= feudal-age)
  (building-type-count-total barracks < 1)
  (can-build barracks)
=>
  (build barracks)
)

(defrule
  (current-age >= feudal-age)
  (building-type-count-total barracks >= 1)
  (building-type-count-total archery-range < 1)
  (can-build archery-range)
=>
  (build archery-range)
)

; ==========================================
; UNIT TRAINING
; ==========================================

; Train militia from barracks
(defrule
  (building-type-count-total barracks >= 1)
  (can-train militia)
=>
  (train militia)
)

; Train archers from archery range
(defrule
  (building-type-count-total archery-range >= 1)
  (can-train archer)
=>
  (train archer)
)

; Train spearmen if enemy has cavalry
(defrule
  (building-type-count-total barracks >= 1)
  (players-unit-type-count any-enemy scout-cavalry >= 3)
  (can-train spearman)
=>
  (train spearman)
)

; ==========================================
; ATTACK SYSTEM
; ==========================================

; Initialize attack timer
(defrule
  (true)
=>
  (set-strategic-number sn-percent-attack-soldiers 100)
  (set-strategic-number sn-attack-intelligence 1)
  (set-strategic-number sn-task-ungrouped-soldiers 0)
  (enable-timer timer-attack 90)
  (disable-self)
)

; Attack when timer fires and we have army
(defrule
  (timer-triggered timer-attack)
  (military-population >= my-min-military)
  (not (town-under-attack))
=>
  (attack-now)
  (disable-timer timer-attack)
  (enable-timer timer-attack 60)
)

; Reset timer if attacked
(defrule
  (timer-triggered timer-attack)
  (town-under-attack)
=>
  (disable-timer timer-attack)
  (enable-timer timer-attack 30)
)

; ==========================================
; DEFENSE
; ==========================================
(defrule
  (town-under-attack)
=>
  (set-strategic-number sn-percent-enemy-sighted-response 100)
  (set-strategic-number sn-gather-defense-units 1)
)
```

## References

- [AoE2 AI Scripting Encyclopedia](https://airef.github.io/) - Comprehensive reference for all commands, parameters, and strategic numbers
- [Steam AI Scripting Guide](https://steamcommunity.com/sharedfiles/filedetails/?id=1238296169) - Tutorial with examples
- [Age of Kings Heaven - World of AI Scripting](https://aok.heavengames.com/university/other/world-of-ai-scripting-chapter-1/) - Beginner tutorial
- [Three Ways to Get the AI to Attack](https://forums.ageofempires.com/t/three-ways-to-get-the-ai-to-attack/205476) - Attack method comparison
- [UserPatch Scripting Reference](https://userpatch.aiscripters.net/reference.html) - Extended commands for UserPatch
- [CPSB Documentation (PDF)](http://userpatch.aiscripters.net/CPSB.pdf) - Official Computer Player Strategy Builder Guide
- [GitHub: AoE2 AI Scripts](https://github.com/Eruner/Age-Of-Empires-AI-Scripts) - Working script examples
- [AoE2 AI Scripting Discord](https://discord.gg/hEJ9GJNBCg) - Community for questions
