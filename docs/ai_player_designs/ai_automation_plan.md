# AI player automation plan

**Status:** Planning (not yet implemented)
**Date:** 2026-02-05 (updated)

This document describes the plan for automating AI player development and testing. A future agent will implement this.

---

## Overview

When building new game features, the AI player needs to be updated to use those features. This plan describes a process to:

1. Update the AI with new rules and observability
2. Code review the AI changes
3. Run automated behavior tests with structured output
4. Report pass/fail with analysis

---

## Phased implementation

This plan is implemented incrementally. Each phase validates value before building the next.

### Phase A: Summary infrastructure (do first)

**Build:** `summary.json` output from test runner with milestones, anomalies, and pass/fail checks.

**What you get:**
- Structured test output instead of parsing stdout
- Milestone timings for regression detection
- Anomaly detection (idle villagers, high drop distance)
- Pass/fail verdict with specific failure reasons

**Validation gate:** Run this manually. Is the summary useful for debugging? Does it catch real issues? If yes, proceed to Phase B.

**No agents yet.** Human reads summary.json directly.

### Phase B: ai-observer agent

**Build:** Agent that runs the test, reads summary.json, and on failure digs into logs.txt to analyze.

**What you get:**
- Automated test execution + analysis
- Detailed failure reports with suggested investigation areas
- Less manual log-reading

**Validation gate:** Run ai-observer on 2-3 phases. Does it save time vs reading the summary yourself? Does its analysis help? If yes, consider Phase C.

**AI rule changes still manual.**

### Phase C: ai-updater agent (optional, higher risk)

**Build:** Agent that modifies AI rules when new game features are added.

**What you get:**
- Automated AI rule creation for new features
- Less manual AI coding

**When to add:** Only if AI rule changes become a frequent bottleneck AND the testing infrastructure (Phases A+B) gives confidence that broken rules will be caught.

**Risk:** Automated code changes to game logic. Requires strong test coverage to catch regressions.

---

### Current status

| Phase | Status | Notes |
|-------|--------|-------|
| A | Not started | Start here |
| B | Not started | After A proves useful |
| C | Not started | Only if needed |

---

## Where this fits in the phase workflow

When a phase includes features that affect AI behavior, the workflow becomes:

| Step | What | Agent |
|------|------|-------|
| 1 | Build new game feature | Human / Phase agent |
| 2 | Run spec-check (if units/buildings/techs) | spec-check agent |
| 3 | Update AI to use new feature | **ai-updater agent** |
| 4 | Code review all changes | code-reviewer agent |
| 5 | Run AI behavior test | **ai-observer agent** |
| 6 | Write unit tests | test-writer agent |
| 7 | Write checkpoint doc | Human / Phase agent |

**Important distinction:**
- **ai-observer agent** - Runs the game headless and analyzes AI behavior (game-level outcomes, stochastic, slow)
- **test-writer agent** - Writes GDScript unit tests in `tests/` (code correctness, deterministic, fast)

Both are needed. Unit tests verify code works correctly. AI behavior tests verify the AI plays the game competently.

---

## The pattern

| Step | Agent | What it does |
|------|-------|--------------|
| 1 | Human / Phase agent | Build new game feature |
| 2 | ai-updater agent | Add/modify rules for new feature + observability |
| 3 | code-reviewer agent | Review all changes (feature code + AI rules) |
| 4 | ai-observer agent | Run test, read summary, if failures read logs and analyze, report |

The ai-observer agent is **diagnostic only** - it reports findings but does not fix anything. Human decides next steps based on the report.

---

## What needs to be built

### 1. Test output: Two separate files

Currently, all logs go to stdout. Change to output two files:

```
/tmp/ai_test_<timestamp>/
  ├── summary.json      # Structured pass/fail, milestones, anomalies
  └── logs.txt          # Full verbose logs (AI_STATE, RULE_TICK, AI_ACTION)
```

**Why:** Agent reads small summary first (low context). Only reads verbose logs if there are failures.

### 2. Summary output format (`summary.json`)

```json
{
  "test_info": {
    "timestamp": "2026-02-05T14:30:00",
    "duration_game_seconds": 300,
    "time_scale": 10.0,
    "duration_real_seconds": 30
  },

  "milestones": {
    "first_house": 15.0,
    "first_barracks": 45.0,
    "first_farm": 90.0,
    "first_lumber_camp": 60.0,
    "first_mill": null,
    "first_mining_camp": 120.0,
    "reached_5_villagers": 30.0,
    "reached_10_villagers": 75.0,
    "reached_15_villagers": 150.0,
    "first_military_unit": 90.0,
    "first_attack": 180.0
  },
  "milestones_missed": ["first_mill"],

  "final_state": {
    "game_time": 300.0,
    "villagers": 18,
    "military": 6,
    "resources": {"food": 150, "wood": 200, "gold": 50, "stone": 0},
    "buildings": {
      "town_center": 1,
      "house": 4,
      "barracks": 1,
      "farm": 6,
      "lumber_camp": 1,
      "mining_camp": 1,
      "mill": 0
    }
  },

  "anomalies": [
    {"t": 60.0, "type": "idle_villagers_prolonged", "count": 3, "duration_seconds": 35},
    {"t": 120.0, "type": "high_drop_distance", "resource": "food", "distance": 420}
  ],

  "checks": {
    "villagers_at_60s": {"expected": ">=5", "actual": 6, "pass": true},
    "villagers_at_180s": {"expected": ">=12", "actual": 14, "pass": true},
    "barracks_by_90s": {"expected": true, "actual": true, "pass": true},
    "no_prolonged_idle": {"expected": true, "actual": false, "pass": false},
    "food_drop_distance_under_300": {"expected": true, "actual": false, "pass": false},
    "no_crashes": {"expected": true, "actual": true, "pass": true}
  },

  "overall_pass": false,
  "failure_reasons": ["no_prolonged_idle", "food_drop_distance_under_300"]
}
```

### 3. Milestone tracking

Track timestamps when these events first occur:

| Milestone | Condition |
|-----------|-----------|
| `first_house` | First house construction complete |
| `first_barracks` | First barracks construction complete |
| `first_farm` | First farm construction complete |
| `first_lumber_camp` | First lumber camp construction complete |
| `first_mill` | First mill construction complete |
| `first_mining_camp` | First mining camp construction complete |
| `reached_5_villagers` | Civilian population >= 5 |
| `reached_10_villagers` | Civilian population >= 10 |
| `reached_15_villagers` | Civilian population >= 15 |
| `first_military_unit` | First military unit trained |
| `first_attack` | First attack command issued |

If milestone not reached by end of test, value is `null` and added to `milestones_missed`.

### 4. Anomaly detection

Detect and log these anomalies during the test run:

| Anomaly | Condition | Threshold |
|---------|-----------|-----------|
| `idle_villagers_prolonged` | N villagers idle for >30 game seconds | N >= 2, duration > 30s |
| `high_drop_distance` | Average drop distance for resource > threshold | food > 300, wood > 200 |
| `stuck_villager` | Villager position unchanged for >60 game seconds | position delta < 10px |
| `no_resource_income` | Resource stockpile unchanged for >60 game seconds | food or wood |
| `population_stalled` | Population unchanged for >90 game seconds | after t=60 |

### 5. Pass/fail checks

These are the automated checks. Derived from `docs/ai_player_designs/ai_behavior_checklist.md`.

**Note:** These thresholds are reasonable defaults based on expected AI behavior. Adjust as needed if tests fail for legitimate reasons (e.g., map layout makes certain timings impossible).

| Check | Expected | Notes |
|-------|----------|-------|
| `villagers_at_60s` | >= 5 | Early economy working |
| `villagers_at_180s` | >= 12 | Mid economy working |
| `barracks_by_90s` | true | Military buildings being built |
| `no_prolonged_idle` | true (no anomalies) | Villagers being assigned |
| `food_drop_distance_under_300` | true | Drop-off buildings being built |
| `wood_drop_distance_under_200` | true | Lumber camp being built |
| `no_crashes` | true | Game didn't error |
| `max_gatherers_per_node` | <= 2 | Clustering prevention working |

---

## Files to modify

### `scripts/testing/ai_solo_test.gd`

Current state:
- Prints `AI_TEST_START` and `AI_TEST_END` to stdout
- Duration: 300 game seconds at 10x speed

Changes needed:
- Track milestones during run (listen for building/unit creation signals)
- Track anomalies during run (check state each tick)
- At end: write `summary.json` to output directory
- Redirect or copy logs to `logs.txt`

### `scripts/ai/ai_controller.gd`

Current state:
- Prints `AI_STATE` every 10 game seconds
- Prints `RULE_TICK` when rules fire
- Has `_print_debug_state()` method

Changes needed:
- Add signals or callbacks for milestone events (building complete, unit trained, attack issued)
- Expose efficiency metrics for anomaly checking
- Possibly add `AI_MILESTONE` log entries for easier parsing

### New file: `scripts/testing/ai_test_analyzer.gd`

Purpose: Analyze game state during test, track milestones and anomalies

Responsibilities:
- Subscribe to building/unit creation signals
- Track milestone timestamps
- Check for anomaly conditions each tick
- Generate summary data at end of test

---

## Agent definitions

### ai-updater agent

**Location:** `.claude/agents/ai-updater.md` (to be created)

**Scope:**
- `scripts/ai/ai_rules.gd` - Add new rules, modify existing if needed
- `scripts/ai/ai_game_state.gd` - Add helper methods
- `scripts/ai/ai_controller.gd` - Modify if needed

**What it does:**
- Adds new rules for new features (e.g., new Castle building → new rule to build/use Castle)
- Modifies existing rules if the new feature requires it
- Adds observability for the new behavior (log entries, metrics)

**Conservative modification principle:** When modifying existing rules, prefer minimal changes. Don't refactor rules that work unless the new feature requires it. The goal is to make the AI handle the new feature, not to "improve" unrelated code.

**Input:** Description of new feature that was built

**Output:**
- New rules that use the feature
- Modified rules (if needed)
- Observability for the new behavior (log entries, metrics)

**Instructions for agent:**
1. Read the feature that was implemented
2. Understand what AI behavior should change
3. Add rules following existing patterns in `ai_rules.gd`
4. Modify existing rules only if the new feature requires it
5. Add any needed helper methods in `ai_game_state.gd`
6. Add observability (new fields in AI_STATE, new log entries)
7. Follow patterns from Phase 3.1A and 3.1B checkpoints

### ai-observer agent

**Location:** `.claude/agents/ai-observer.md` (to be created)

**Scope:** Read-only analysis (does not modify code)

**Input:** Request to test AI behavior

**Process:**
1. Run the headless test:
   ```bash
   godot --headless --path . scenes/test_ai_solo.tscn
   ```
2. Read `summary.json` first
3. If `overall_pass` is true:
   - Report success with milestone timings
4. If `overall_pass` is false:
   - Read `logs.txt`
   - Analyze logs around failure times
   - Identify likely causes
   - Report failures with analysis and suggested investigation areas

**Output:** Markdown report like:

```markdown
## AI Behavior Test Results

**Status:** FAIL (2 of 8 checks failed)
**Duration:** 300 game seconds (30 real seconds)

### Passed
- ✓ villagers_at_60s: expected ≥5, got 7
- ✓ villagers_at_180s: expected ≥12, got 14
- ✓ barracks_by_90s: built at t=52
- ✓ no_crashes
- ✓ max_gatherers_per_node ≤2

### Failed
- ✗ no_prolonged_idle: 3 villagers idle for 45s at t=60-105
- ✗ food_drop_distance_under_300: avg 420px at t=120

### Milestones
| Milestone | Time | Status |
|-----------|------|--------|
| first_house | 15s | ✓ |
| first_barracks | 52s | ✓ |
| reached_10_villagers | 75s | ✓ |
| first_mill | - | ✗ missed |

### Anomalies
- t=60-105: 3 idle villagers (GatherSheepRule may have failed after sheep depletion)
- t=120: food drop distance 420px (no mill built, berries far from TC)

### Analysis (from logs)

Looking at RULE_TICK around t=60:
- `build_mill` showing "not_needed" - the `needs_mill()` check may be wrong
- Sheep count dropped to 0 at t=55, but no farm transition

### Suggested investigation
1. Check `needs_mill()` in `ai_game_state.gd` - threshold may be too high
2. Check `BuildFarmRule` conditions - may not fire when sheep deplete
3. Verify `GatherSheepRule` vs `HuntRule` handoff
```

---

## Checkpoint doc integration

When AI behavior tests are run as part of a phase, add a section to the checkpoint doc:

```markdown
## AI Behavior Tests

- **Test run:** 2026-02-05, 300 game seconds at 10x speed
- **Status:** PASS (8/8 checks)
- **Milestones:** first_barracks at 52s, first_farm at 90s, first_attack at 180s
- **Anomalies:** None
- **Notes:** (any observations worth recording)
```

If the test fails and is fixed, document what was wrong and how it was fixed.

---

## Implementation order

Follows the phased approach (see "Phased implementation" section above).

### Phase A: Summary infrastructure

1. **Create analyzer**
   - Create `scripts/testing/ai_test_analyzer.gd`
   - Add milestone tracking
   - Add anomaly detection
   - Add pass/fail checks

2. **Update test runner**
   - Modify `ai_solo_test.gd` to use analyzer
   - Output to directory with summary.json + logs.txt

3. **Update docs**
   - Update `docs/ai_player_designs/ai_testing.md` with new output format

4. **Validate**
   - Run 2-3 test cycles, manually inspect summary.json
   - Confirm it catches real issues and is useful for debugging

### Phase B: ai-observer agent

5. **Create ai-observer agent**
   - Write `.claude/agents/ai-observer.md`
   - Test it manually on passing and failing runs

6. **Update docs**
   - Update `docs/ai_player_designs/ai_behavior_checklist.md` to mark which checks are automated
   - Update checkpoint doc template with AI behavior test section

7. **Validate**
   - Use ai-observer on 2-3 phases
   - Confirm it saves time vs manual summary reading

### Phase C: ai-updater agent (if needed)

8. **Create ai-updater agent**
   - Write `.claude/agents/ai-updater.md`
   - Test it on a small feature addition

9. **Validate**
   - Confirm ai-observer catches any regressions introduced by ai-updater
   - Only proceed if test coverage gives confidence

---

## What we're NOT doing (keeping simple)

- Log levels (keeping current verbose logging)
- Automated fix loops (agent reports, human decides)
- Complex multi-stage testing
- Map seed control (deal with variance as it comes)
- Deterministic replay/reproduction
- AI vs AI battles (future work)

---

## Related docs

- `docs/ai_player_designs/ai_testing.md` - Current test infrastructure
- `docs/ai_player_designs/ai_behavior_checklist.md` - Behavior expectations
- `docs/phase_checkpoints/phase-3.1a.md` - Rule engine patterns
- `docs/phase_checkpoints/phase-3.1b.md` - Economy rules patterns
- `.claude/agents/code-reviewer.md` - Existing code review agent (for reference)
