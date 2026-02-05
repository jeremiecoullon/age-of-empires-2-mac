# AI testing

This doc covers how to test and debug the AI player, including the automation infrastructure for structured test output and analysis.

---

## Current infrastructure

### Running headless tests

**Always use a timeout** to prevent tests from hanging forever:

```bash
# Default: 600 game-seconds at 10x speed (~60 real seconds)
# Use 120s timeout (2x expected duration for safety margin)
timeout 120 /Applications/Godot.app/Contents/MacOS/Godot --headless --path . scenes/test_ai_solo.tscn

# Custom duration (e.g., 120 game-seconds for a quick 2-minute test)
timeout 60 /Applications/Godot.app/Contents/MacOS/Godot --headless --path . scenes/test_ai_solo.tscn -- --duration=120

# Custom time scale
timeout 180 /Applications/Godot.app/Contents/MacOS/Godot --headless --path . scenes/test_ai_solo.tscn -- --timescale=5
```

**Timeout calculation:** `timeout_seconds = (duration / timescale) * 2`
- Default (600s at 10x): `(600 / 10) * 2 = 120 seconds`
- Quick test (120s at 10x): `(120 / 10) * 2 = 24 seconds` (use 60s minimum)
- Slow test (600s at 5x): `(600 / 5) * 2 = 240 seconds`

**Command-line arguments** (passed after `--`):
- `--duration=<seconds>` - Test duration in game seconds (default: 600)
- `--timescale=<multiplier>` - Game speed multiplier (default: 10.0)

**Output:** `logs/testing_logs/ai_test_<timestamp>/` containing:
- `summary.json` - Structured pass/fail, milestones, anomalies
- `logs.txt` - Full verbose logs

The `logs/` directory is gitignored.

### Log output

```
AI_TEST_START|{"duration":600.0,"time_scale":10.0,"output_dir":"/path/to/logs/testing_logs/ai_test_2026-02-05_12-00-00"}
RULE_TICK|{"t":1.4,"fired":["train_villager","build_lumber_camp"],"skipped":{"build_barracks":"need_5_villagers_have_3",...}}
AI_ACTION|{"t":1.4,"action":"build","building":"lumber_camp","pos":[1808,1776]}
AI_STATE|{"t":10.0,"villagers":{"total":5},"resources":{"food":0,"wood":0},...}
...
AI_TEST_END|{"game_time":600.0,"status":"complete","output_dir":"/path/to/logs/testing_logs/ai_test_2026-02-05_12-00-00"}
```

**Log types:**
- `AI_STATE` - Full state snapshot every 10 game-seconds
- `RULE_TICK` - Which rules fired and why others were skipped (logged when any rule fires)
- `AI_ACTION` - When actions execute (train, build, attack, market trades)
- `AI_TEST_START/END` - Test boundaries

### Files involved

| File | Purpose |
|------|---------|
| `scenes/test_ai_solo.tscn` | Test scene - extends main.tscn, adds test controller |
| `scripts/testing/ai_solo_test.gd` | Test controller - runs test, writes summary.json and logs.txt |
| `scripts/testing/ai_test_analyzer.gd` | Analyzer - tracks milestones, detects anomalies, generates summary |
| `scripts/ai/ai_controller.gd` | AI logic + JSON logging (see `_print_debug_state()`) |

### Log formats

#### RULE_TICK

Logged whenever at least one rule fires. Shows decision-making in real time:

```json
{
  "t": 7.9,
  "fired": ["gather_sheep", "build_barracks"],
  "skipped": {
    "train_villager": "insufficient_food",
    "build_house": "headroom_5",
    "build_lumber_camp": "already_queued",
    "train_militia": "no_barracks",
    "attack": "need_5_military_have_0"
  }
}
```

Skip reasons are specific and actionable, not just "conditions_false".

#### AI_ACTION

Logged when AI actually executes actions:

```json
{"t": 1.4, "action": "train", "unit": "villager"}
{"t": 7.9, "action": "build", "building": "barracks", "pos": [1616, 1808]}
{"t": 90.0, "action": "attack", "units": 5, "target": "TownCenter"}
{"t": 45.0, "action": "build_failed", "building": "house", "reason": "no_valid_position"}
```

#### AI_STATE

Full state snapshot (see `ai_controller.gd:_print_debug_state()` for complete schema):

```json
{
  "t": 30.1,
  "resources": {"food": 150, "wood": 200, "gold": 0, "stone": 0},
  "population": {"current": 8, "cap": 15, "headroom": 7},
  "villagers": {"total": 8, "food": 5, "wood": 3, "idle": 0, "building": 0},
  "military": {"total": 0, "militia": 0, "spearman": 0, "archer": 0, "scout": 0},
  "buildings": {"town_center": 1, "house": 2, "barracks": 0, "farm": 0, ...},
  "efficiency": {
    "avg_food_drop_dist": 150.0,
    "avg_wood_drop_dist": 80.0,
    "max_on_same_food": 3,
    "max_on_same_wood": 2
  },
  "rule_blockers": {"build_barracks": "already_queued", "attack": "need_5_military_have_0"}
}
```

### Configuration

Edit `scenes/test_ai_solo.tscn` or the exported vars in `scripts/testing/ai_solo_test.gd`:

- `time_scale`: Game speed multiplier (default: 10.0)
- `test_duration`: How many game-seconds to run (default: 600.0 = 10 minutes)

Debug toggles (editable in Godot Inspector):

| Setting | File | Variable | Default |
|---------|------|----------|---------|
| AI state logging | `scripts/ai/ai_controller.gd` | `debug_print_enabled` | `true` |
| Fog of War | `scripts/fog_of_war.gd` | `debug_disable_fog` | `true` |

### What to look for

When analyzing AI output, check:

1. **Villager growth**: Should increase over time toward `target_villagers`
2. **Resource accumulation**: Should have stable income, not stuck at 0
3. **Idle villagers**: Should be 0 (AI reassigns idle villagers)
4. **Drop-off distances**: High values (>200) indicate villagers walking too far
5. **Building progression**: Houses before pop cap, barracks for military

---

## Output format

### Test output structure

Tests output to a timestamped directory in the repo:

```
logs/testing_logs/ai_test_<timestamp>/
  ├── summary.json      # Structured pass/fail, milestones, anomalies
  └── logs.txt          # Full verbose logs (AI_STATE, RULE_TICK, AI_ACTION)
```

The `logs/` directory is gitignored.

**Why:** Agent reads small summary first (low context). Only reads verbose logs if there are failures.

### Summary format (summary.json)

```json
{
  "test_info": {
    "timestamp": "2026-02-05T14:30:00",
    "duration_game_seconds": 600,
    "time_scale": 10.0,
    "duration_real_seconds": 60
  },

  "milestones": {
    "first_house": 1.5,
    "first_barracks": 58.0,
    "first_farm": 130.0,
    "first_lumber_camp": 46.0,
    "first_mill": null,
    "first_mining_camp": 150.0,
    "reached_5_villagers": 7.5,
    "reached_10_villagers": 96.0,
    "reached_15_villagers": 250.0,
    "first_military_unit": 390.0,
    "first_attack": 478.0
  },
  "milestones_missed": ["first_mill"],

  "final_state": {
    "game_time": 600.0,
    "villagers": 20,
    "military": 7,
    "resources": {"food": 50, "wood": 200, "gold": 400, "stone": 0},
    "buildings": {
      "town_center": 1,
      "house": 6,
      "barracks": 1,
      "farm": 5,
      "lumber_camp": 1,
      "mining_camp": 1,
      "mill": 0
    }
  },

  "anomalies": [
    {"t": 75.0, "type": "stuck_villager", "villager_id": 12345, "position": [1706, 1743]},
    {"t": 120.0, "type": "high_drop_distance", "resource": "food", "distance": 420}
  ],

  "checks": {
    "villagers_at_60s": {"expected": ">=5", "actual": 5, "pass": true},
    "villagers_at_180s": {"expected": ">=12", "actual": 20, "pass": true},
    "barracks_by_90s": {"expected": true, "actual": true, "pass": true},
    "military_by_450s": {"expected": true, "actual": true, "pass": true},
    "no_prolonged_idle": {"expected": true, "actual": true, "pass": true},
    "no_crashes": {"expected": true, "actual": true, "pass": true},
    "gatherer_clustering": {"food_max": 4, "wood_max": 2, "gold_max": 2, "stone_max": 0, "informational": true}
  },

  "overall_pass": true,
  "failure_reasons": []
}
```

### Milestones

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

### Anomaly detection

Detect and log these anomalies during the test run:

| Anomaly | Condition | Threshold |
|---------|-----------|-----------|
| `idle_villagers_prolonged` | N villagers idle for >30 game seconds | N >= 2, duration > 30s |
| `high_drop_distance` | Average drop distance for resource > threshold | food > 700, wood > 900 |
| `stuck_villager` | Villager position unchanged for >60 game seconds | position delta < 10px |
| `no_resource_income` | Resource stockpile unchanged for >60 game seconds | food or wood |
| `population_stalled` | Population unchanged for >90 game seconds | after t=60 |

**Note:** Drop distance thresholds are lenient because the current AI has known efficiency issues. These anomalies are logged for debugging but don't cause test failure.

### Pass/fail checks

Automated checks derived from `ai_behavior_checklist.md`:

| Check | Expected | Notes |
|-------|----------|-------|
| `villagers_at_60s` | >= 5 | Early economy working |
| `villagers_at_180s` | >= 12 | Mid economy working |
| `barracks_by_90s` | true | Military buildings being built |
| `military_by_450s` | true | Military production working (for 10-min tests) |
| `no_prolonged_idle` | true (no anomalies) | Villagers being assigned |
| `no_crashes` | true | Game didn't error |

**Informational only (not pass/fail):**
| Check | Notes |
|-------|-------|
| `gatherer_clustering` | food_max, wood_max, etc. - useful for debugging |

**Note:** Drop distance and clustering checks were moved to informational-only because the current AI has known efficiency issues. These are tracked as anomalies for debugging but don't fail the test.

### Files (Phase A complete)

#### `scripts/testing/ai_test_analyzer.gd`

Purpose: Analyze game state during test, track milestones and anomalies.

What it does:
- Polls building/unit counts each tick to detect milestones (simpler than signals)
- Checks for anomaly conditions with throttling (every 0.5s)
- Generates summary dictionary at end of test

#### `scripts/testing/ai_solo_test.gd`

Purpose: Test controller that runs the test and writes output.

What it does:
- Sets time_scale, runs for test_duration
- Instantiates analyzer and calls `check_state()` each tick
- Captures logs via callback on ai_controller
- Writes `summary.json` and `logs.txt` to output directory

#### `scripts/ai/ai_controller.gd`

Changes made:
- Added `_log()` method that prints to stdout AND calls log callback if set
- Test controller sets callback via `set_meta("log_callback", callback)`

#### `scripts/ai/ai_game_state.gd`

Changes made:
- Fixed `get_game_time()` to use `controller.game_time_elapsed` (game time) instead of `Time.get_ticks_msec()` (wall clock)

---

## ai-observer agent

**Location:** `.claude/agents/ai-observer.md`

**Scope:** Read-only analysis (does not modify code)

**Process:**
1. Run the headless test
2. Read `summary.json` first
3. If `overall_pass` is true: report success with milestone timings
4. If `overall_pass` is false: read `logs.txt`, analyze logs around failure times, report with suggested investigation areas

**Output:** Markdown report with pass/fail status, milestone timings, anomalies, and analysis.

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

## What we're NOT doing (keeping simple)

- Log levels (keeping current verbose logging)
- Automated fix loops (agent reports, human decides)
- Complex multi-stage testing
- Map seed control (deal with variance as it comes)
- Deterministic replay/reproduction
- AI vs AI battles (future work)

---

## Gotchas

**Timer bug pattern:** Any time-based logic that uses wall clock (`Time.get_ticks_msec()`) instead of game time (`controller.game_time_elapsed`) will behave differently at accelerated speeds. This caused AI attack timers to not trigger at 10x speed.

**AI variance:** AI behavior has randomness (resource placement, decision timing). Don't fail on single anomalies — look for patterns across the test run. Focus on clear failures (milestones missed, checks failed).

**Known efficiency issues:** The current AI has known issues that are tracked as anomalies but don't fail tests:
- Drop distances can exceed 800px (villagers walk far)
- Gatherer clustering can reach 4-5 on same resource

**Short test checks:** The `villagers_at_180s` check will fail for tests with `--duration < 180`. This is expected, not a bug.

**Military timing:** Military production typically starts around 370-420s. Tests shorter than 450s may not see military.

---

## Related docs

- `ai_behavior_checklist.md` - Behavior expectations (source for automated checks)
- `godot_rule_implementation.md` - AI rule system design
