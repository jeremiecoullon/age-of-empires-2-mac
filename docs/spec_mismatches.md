# Spec Mismatches

Discrepancies between current implementation and AoE2 manual specs.

**Last reviewed:** 2026-01-27 (roadmap updated to reflect these)

---

## Militia (`scripts/units/militia.gd`)

| Attribute | AoE2 Spec | Implementation | Status |
|-----------|-----------|----------------|--------|
| HP | 40 | 50 | Fix needed |
| Attack | 4 | 5 | Fix needed |
| Cost | 60 food, 20 gold | 60 food, 20 wood | Fix needed (gold not wood) |
| Armor (melee/pierce) | 0/0 | Not implemented | Missing system |
| Range | 0 (melee) | 30 pixels | Fix needed (should be melee) |
| Attack Cooldown | ~2 sec | 1.0 sec | Fix needed |
| Attack bonus vs buildings | Yes | No | Missing feature |

**Notes:**
- The 30px attack range makes militia semi-ranged; AoE2 militia is true melee
- Armor system doesn't exist yet (expected - MVP)
- Building attack bonus not implemented (expected - MVP)

---

## Villager (`scripts/units/villager.gd`)

| Attribute | AoE2 Spec | Implementation | Status |
|-----------|-----------|----------------|--------|
| HP | 25 | ? | Check needed |
| Attack | 3 | ? | Check needed |
| Cost | 50 food | 50 food | ✓ Correct |

*Full check pending - run `/spec-check villager`*

---

## Buildings

### House (`scripts/buildings/house.gd`)

| Attribute | AoE2 Spec | Implementation | Status |
|-----------|-----------|----------------|--------|
| Cost | 30 wood | 25 wood | Fix needed |
| HP | 900 | 200 | Fix needed |
| Pop support | 5 | 5 | ✓ Correct |

### Barracks (`scripts/buildings/barracks.gd`)

| Attribute | AoE2 Spec | Implementation | Status |
|-----------|-----------|----------------|--------|
| Cost | 175 wood | 100 wood | Fix needed |
| HP | 1200 | 200 | Fix needed |
| Age | Dark | Dark | ✓ Correct |

### Farm (`scripts/buildings/farm.gd`)

| Attribute | AoE2 Spec | Implementation | Status |
|-----------|-----------|----------------|--------|
| Cost | 60 wood | 50 wood | Fix needed |
| HP | 480 | ? | Check needed |
| Food yield | 175 (base) | Infinite | Intentional (MVP) |

### Town Center (`scripts/buildings/town_center.gd`)

| Attribute | AoE2 Spec | Implementation | Status |
|-----------|-----------|----------------|--------|
| HP | 2400 | 500 | Fix needed |
| Attack | 5 | 0 | Missing feature |
| Range | 6 | 0 | Missing feature |
| Garrison | 15 | Not impl | Missing feature |
| Pop support | 5 | 5 | ✓ Correct |

**Notes:**
- TC should fire arrows when garrisoned or under attack (Castle Age+ in AoE2)
- Starting TC in Dark Age cannot attack

---

## Roadmap Gaps Found

The following were missing from the roadmap and have been added:

1. **Food sources** - Sheep (herdable), Deer, Wild Boar (huntables), Wolves (hazard)
2. **Garrison healing** - Units heal automatically when garrisoned
3. **Allied mechanics** - Allies can garrison in each other's buildings, open/close gates
4. **Age-gated units** - Clarified which units unlock at which age

---

## Legend

- **Fix needed** - Value differs from spec, should be corrected
- **Missing system** - Requires new code/architecture (e.g., armor system)
- **Missing feature** - Feature not yet implemented
- **Check needed** - Not yet verified against implementation
- **Intentional** - Deliberate deviation, documented in gotchas.md
- **✓ Correct** - Matches spec
