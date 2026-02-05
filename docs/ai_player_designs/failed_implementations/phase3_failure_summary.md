# Phase 3 failure summary

**Date:** 2026-02-03
**Status:** Replaced by Phase 3.1

---

## What was attempted

Phase 3 "Strong AI" aimed to make the AI competitive through 5 sub-phases:
- 3A: Macro & Build Orders
- 3B: Scouting & Information
- 3C: Combat Intelligence
- 3D: Micro & Tactics
- 3E: Economic Intelligence

The implementation used procedural/imperative code with:
- State machines for unit behavior
- Timer-based decision loops
- Explicit tracking variables for enemy army, threat levels, economy modes
- Complex interdependent functions (~3900 lines in ai_controller.gd)

---

## Observed failures

### 1. Villagers hunting forever
Villagers assigned to hunt would pursue animals indefinitely, never returning to gather other resources or respond to other needs. The state machine lacked proper exit conditions.

### 2. Farms ignoring berries
The AI would build farms while berry bushes remained ungathered. Priority logic was incorrect - conditions were too broad or thresholds were wrong.

### 3. Whack-a-mole debugging
This was the core architectural problem. Fixing one issue would break another:
- Fix hunting → breaks farm logic
- Fix farms → breaks military production
- Fix military → breaks villager allocation
- And so on...

The tight coupling between systems meant changes cascaded unpredictably.

---

## Root cause

The procedural architecture was the fundamental problem, not the specific bugs.

**Procedural AI characteristics:**
- Functions call other functions
- State is shared and modified throughout
- Execution order matters
- Changes have cascading effects
- Hard to reason about behavior

**Contrast with AoE2's rule-based system:**
- Rules are independent - they don't call each other
- Each rule has clear conditions and actions
- All matching rules fire each tick
- Adding/removing rules doesn't break others
- Easy to reason about: "if X then Y"

---

## Lessons learned

1. **Architecture matters more than features.** No amount of feature additions (scouting, micro, economic intelligence) could fix the underlying structural problem.

2. **Debugging symptoms doesn't fix root causes.** We spent time fixing individual behaviors when the real issue was the decision-making architecture.

3. **The original AoE2 AI design exists for good reasons.** The rule-based system isn't just a scripting convenience - it's an architectural choice that makes AI behavior predictable and maintainable.

---

## Path forward

Phase 3.1 will re-implement the AI using a rule-based system inspired by AoE2:
- Independent rules that don't call each other
- All matching rules fire each tick
- Clear conditions and actions per rule
- Easy to add/modify behaviors without cascading effects

See `docs/ai_player_designs/aoe2_ai_rule_system.md` for the reference design.
