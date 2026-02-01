# Phase 3D Checkpoint: Micro & Tactics

**Date:** 2026-02-01
**Status:** Complete

---

## Summary

Implemented micro-management and tactical AI: ranged unit kiting against melee threats, villager flee behavior when enemies approach, Town Bell system for mass villager garrison during base attacks, split attention with separate harass squads, and reinforcement waves that send new units to join attacking armies.

---

## Context Friction

1. **Files re-read multiple times?** No - ai_controller.gd was read in sections as needed
2. **Forgot earlier decisions?** No - built directly on Phase 3C's retreat and combat systems
3. **Uncertain patterns?** No - followed established patterns from Phase 3C

---

## Implemented Features

| Feature | Files | Notes |
|---------|-------|-------|
| Kiting constants | `scripts/ai/ai_controller.gd:74-83` | KITE_DISTANCE, MELEE_THREAT_RANGE, etc. |
| Kiting variables | `scripts/ai/ai_controller.gd:173-181` | kiting_units, fleeing_villagers, town_bell_*, harass_squad, etc. |
| _is_ranged_unit() | `scripts/ai/ai_controller.gd:3051-3053` | Type check for Archer, Skirmisher, CavalryArcher |
| _get_nearest_melee_threat() | `scripts/ai/ai_controller.gd:3056-3074` | Find closest melee enemy to a position |
| _manage_ranged_kiting() | `scripts/ai/ai_controller.gd:3077-3105` | Main kiting logic - checks ranged units for melee threats |
| _order_unit_kite() | `scripts/ai/ai_controller.gd:3108-3125` | Command unit to kite away from threat |
| _manage_villager_flee() | `scripts/ai/ai_controller.gd:3128-3167` | Check for villagers in danger, order flee |
| _order_villager_flee() | `scripts/ai/ai_controller.gd:3170-3181` | Command villager to flee to TC |
| _check_town_bell() | `scripts/ai/ai_controller.gd:3184-3207` | Check if mass garrison should activate |
| _activate_town_bell() | `scripts/ai/ai_controller.gd:3210-3221` | Activate Town Bell, all villagers flee |
| _check_town_bell_deactivate() | `scripts/ai/ai_controller.gd:3224-3241` | Check if threat is gone |
| _deactivate_town_bell() | `scripts/ai/ai_controller.gd:3244-3251` | Deactivate Town Bell, villagers return to work |
| _manage_reinforcements() | `scripts/ai/ai_controller.gd:3254-3293` | Send idle military to join attacking army |
| _get_rally_point_for_attack() | `scripts/ai/ai_controller.gd:3296-3300` | Calculate rally point between base and attack |
| _send_reinforcement() | `scripts/ai/ai_controller.gd:3303-3317` | Send single unit to join attack |
| _assign_attack_force() | `scripts/ai/ai_controller.gd:3320-3327` | Track units in an attack wave |
| _clear_attack_force() | `scripts/ai/ai_controller.gd:3330-3333` | Clear attack tracking when attack ends |
| _setup_harass_squad() | `scripts/ai/ai_controller.gd:3336-3362` | Select units for harassment (prefers cavalry) |
| _send_harass_squad() | `scripts/ai/ai_controller.gd:3365-3371` | Send harass squad to target |
| _get_harass_target() | `scripts/ai/ai_controller.gd:3374-3383` | Find target for harassment (enemy economy) |
| _should_harass_retreat() | `scripts/ai/ai_controller.gd:3386-3402` | Check if harass squad should return |
| _recall_harass_squad() | `scripts/ai/ai_controller.gd:3405-3413` | Order harass squad back to base |
| can_split_attention() | `scripts/ai/ai_controller.gd:3416-3425` | Check if army is large enough to split |
| _is_unit_idle_or_patrolling() | `scripts/ai/ai_controller.gd:3428-3446` | Type-safe idle state check |
| Split attention in _make_decisions() | `scripts/ai/ai_controller.gd:572-582` | Integrated harass logic into decision loop |
| Attack force tracking in _attack_player() | `scripts/ai/ai_controller.gd:1449-1492` | Track attack force for reinforcements |
| Micro management in _process() | `scripts/ai/ai_controller.gd:247-253` | Added Phase 3D micro calls |

---

## Deviations from Spec

| Spec Said | Implementation | Reason |
|-----------|----------------|--------|
| TC garrison | Villagers flee to TC (no actual garrison) | Garrison system is Phase 7; simulated effect for 3D |

---

## Known Issues

- **Performance concern:** Multiple group searches per micro-management cycle (every 0.3s). Acceptable at current game scale but may need optimization for larger battles. Consistent with Phase 3B/3C tech debt.
- **Rally point always near AI base:** Reinforcements gather at a fixed distance from AI base rather than near the active battle. Could be improved in future.

---

## Test Coverage

### Manual Testing Performed
- [ ] AI ranged units kite away from melee attackers
- [ ] AI villagers flee when enemies approach
- [ ] Town Bell activates when 3+ enemy military near TC
- [ ] Town Bell deactivates when threat is gone
- [ ] Harass squad raids enemy economy
- [ ] Harass squad returns when base under attack
- [ ] New units join active attack as reinforcements

### Automated Tests

24 new tests added to `tests/scenarios/test_ai.gd`:

**Ranged unit kiting:**
- `test_is_ranged_unit_returns_true_for_archer` - Archer identified as ranged
- `test_is_ranged_unit_returns_true_for_skirmisher` - Skirmisher identified as ranged
- `test_is_ranged_unit_returns_true_for_cavalry_archer` - CavalryArcher identified as ranged
- `test_is_ranged_unit_returns_false_for_militia` - Militia is non-ranged
- `test_is_ranged_unit_returns_false_for_spearman` - Spearman is non-ranged
- `test_is_ranged_unit_returns_false_for_scout_cavalry` - ScoutCavalry is non-ranged
- `test_kiting_units_starts_empty` - kiting_units array initialization
- `test_get_nearest_melee_threat_returns_null_when_no_enemies` - Null when no threats

**Villager flee:**
- `test_fleeing_villagers_starts_empty` - fleeing_villagers array initialization

**Town Bell:**
- `test_town_bell_active_starts_false` - Town Bell inactive at start
- `test_town_bell_cooldown_timer_starts_at_zero` - Cooldown starts at 0
- `test_town_bell_threat_threshold_constant` - TOWN_BELL_THREAT_THRESHOLD = 3
- `test_town_bell_cooldown_constant` - TOWN_BELL_COOLDOWN = 30.0

**Split attention:**
- `test_harass_squad_starts_empty` - harass_squad array initialization
- `test_can_split_attention_returns_false_with_no_military` - Cannot split without army
- `test_harass_force_size_constant` - HARASS_FORCE_SIZE = 3

**Reinforcements:**
- `test_main_army_starts_empty` - main_army array initialization
- `test_active_attack_position_starts_at_zero` - attack position initialization
- `test_reinforcement_rally_point_starts_at_zero` - rally point initialization
- `test_get_rally_point_returns_position_between_base_and_attack` - Rally point positioning

**Helper functions:**
- `test_is_unit_idle_or_patrolling_returns_false_for_invalid_unit` - Invalid unit handling
- `test_kite_distance_constant` - KITE_DISTANCE = 60.0
- `test_melee_threat_range_constant` - MELEE_THREAT_RANGE = 80.0
- `test_villager_flee_radius_constant` - VILLAGER_FLEE_RADIUS = 150.0

---

## AI Behavior Updates

**New capabilities:**
- AI ranged units (archers, skirmishers, cavalry archers) kite away from melee threats
- AI villagers flee to TC when enemies approach
- AI activates "Town Bell" (mass villager garrison) when 3+ enemy military near TC
- AI can maintain separate harass squad to raid enemy economy while main force defends
- AI sends newly trained military units to reinforce active attacks

**Decision logic changes:**
- Micro-management runs every 0.3s (separate from 1.0s decision loop)
- Kiting units excluded from harass squad and retreat logic
- Harass squad excluded from kiting logic (follows own engagement rules)
- Attack force tracked for reinforcement purposes
- Town Bell has 30-second cooldown to prevent rapid toggling

---

## Code Review Issues Addressed

| Issue ID | Severity | Fix |
|----------|----------|-----|
| ISSUE-001 | High | Added harass_squad exclusion to kiting logic |
| ISSUE-003 | Medium | Removed unused KITE_RANGE_BUFFER constant |
| ISSUE-005 | Medium | Fixed harass target to prioritize economy over army position |

**Not addressed (acceptable tech debt):**
- ISSUE-002: Performance optimization for group searches - consistent with previous phases
- ISSUE-004, ISSUE-008, ISSUE-009: Low severity extensibility improvements

---

## Lessons Learned

- **Harass units need separate rules:** Units assigned to harassment should be excluded from individual micro behaviors (like kiting) to prevent conflicting orders. The harass system has its own engagement/retreat rules.
- **Cache group lookups when iterating multiple units:** When checking conditions for many units (e.g., threat detection for each ranged unit), cache the group lookup once rather than per-unit to reduce O(n^2) behavior.
- **Town Bell needs cooldown:** Without cooldown, rapid threat detection/resolution can cause Town Bell to toggle rapidly, disrupting villager work.
- **Rally point positioning matters:** Reinforcements should gather near the battle, not near the base, for faster response.

---

## Context for Next Phase

Critical information for Phase 3E (Economic Intelligence):

- **Kiting and flee systems active:** Ranged units and villagers have self-preservation behaviors that may affect villager allocation measurements
- **Town Bell affects villager counts:** When Town Bell is active, villagers are fleeing rather than gathering, which could skew resource balance calculations
- **harass_squad tracking:** Units in harass_squad are not available for other tasks - Phase 3E should account for this
- **Key arrays to consider:**
  - `kiting_units` - ranged units temporarily backing away
  - `fleeing_villagers` - villagers heading to TC
  - `harass_squad` - units assigned to harassment
  - `main_army` - units in current attack wave

---

## Git Reference

- **Branch:** claude/continue-development-Grc6l
- **Primary changes:** Micro-management system, kiting, flee behavior, Town Bell, harass squad, reinforcements
