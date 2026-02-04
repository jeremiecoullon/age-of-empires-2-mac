# AI testing

This doc covers how to test and debug the AI player using headless runs.

## Overview

The AI outputs structured JSON logs to stdout every 10 game-seconds. These can be captured and analyzed to verify AI behavior without manual play-testing.

## Running headless tests

### Basic command

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . scenes/test_ai_solo.tscn 2>&1 | grep "AI_"
```

This runs the AI for 60 game-seconds at 10x speed (~6 real seconds).

### What it outputs

```
AI_TEST_START|{"duration":60.0,"time_scale":10.0}
AI_STATE|{"t":10.0,"villagers":{"total":5},"resources":{"food":0,"wood":0},...}
AI_STATE|{"t":20.0,"villagers":{"total":7},"resources":{"food":10,"wood":10},...}
...
AI_TEST_END|{"game_time":60.1,"status":"complete"}
```

Each `AI_STATE` line is valid JSON containing the full AI state at that moment.

## Files involved

| File | Purpose |
|------|---------|
| `scenes/test_ai_solo.tscn` | Test scene - extends main.tscn, adds test controller |
| `scripts/testing/ai_solo_test.gd` | Test controller - sets time_scale, quits after duration |
| `scripts/ai/ai_controller.gd` | AI logic + JSON logging (see `_print_debug_state()`) |

## JSON output format

The `AI_STATE` JSON contains:

```json
{
  "t": 30.1,                    // Game time in seconds
  "resources": {
    "food": 150,
    "wood": 200,
    "gold": 0,
    "stone": 0
  },
  "population": {
    "current": 8,
    "cap": 15,
    "headroom": 7
  },
  "villagers": {
    "total": 8,
    "food": 5,
    "wood": 3,
    "gold": 0,
    "stone": 0,
    "idle": 0,
    "building": 0
  },
  "military": {
    "total": 0,
    "militia": 0,
    "spearman": 0,
    "archer": 0,
    "scout": 0
  },
  "buildings": {
    "town_center": 1,
    "house": 2,
    "barracks": 0,
    "farm": 0,
    "mill": 0,
    "lumber_camp": 0,
    "mining_camp": 0,
    "market": 0
  },
  "strategic_numbers": {
    "food_pct": 60,
    "wood_pct": 40,
    "gold_pct": 0,
    "stone_pct": 0,
    "target_villagers": 20,
    "min_attack_group": 5
  },
  "state": {
    "under_attack": false,
    "timers": {},
    "goals": {"1": 1}
  },
  "can_afford": {
    "villager": true,
    "militia": false,
    "house": true,
    "barracks": false
  },
  "efficiency": {
    "avg_food_drop_dist": 150.0,   // Average distance villagers walk to drop off food
    "avg_wood_drop_dist": 80.0,
    "avg_gold_drop_dist": -1,      // -1 means no gatherers for this resource
    "avg_stone_drop_dist": -1,
    "max_on_same_food": 3,         // Max villagers on a single food source
    "max_on_same_wood": 2,
    "max_on_same_gold": 0,
    "max_on_same_stone": 0
  }
}
```

## Configuring the test

Edit `scenes/test_ai_solo.tscn` or the exported vars in `scripts/testing/ai_solo_test.gd`:

- `time_scale`: Game speed multiplier (default: 10.0)
- `test_duration`: How many game-seconds to run (default: 60.0)

The debug print interval is set in `ai_controller.gd`:
- `DEBUG_PRINT_INTERVAL`: Seconds between snapshots (default: 10.0)

## Debug toggles

Both are `@export` vars, editable in Godot Inspector or by changing defaults in code:

| Setting | File | Variable | Default |
|---------|------|----------|---------|
| AI state logging | `scripts/ai/ai_controller.gd` | `debug_print_enabled` | `true` |
| Fog of War | `scripts/fog_of_war.gd` | `debug_disable_fog` | `true` |

## What to look for

When analyzing AI output, check:

1. **Villager growth**: Should increase over time toward `target_villagers`
2. **Resource accumulation**: Should have stable income, not stuck at 0
3. **Idle villagers**: Should be 0 (AI reassigns idle villagers)
4. **Drop-off distances**: High values (>200) indicate villagers walking too far
5. **Building progression**: Houses before pop cap, barracks for military

## Example: detecting problems

From a real test run:
```
AI_STATE|{..."avg_food_drop_dist":340.0,...}
```

This shows villagers walking 340 pixels to drop off food — far too high. Indicates either:
- No nearby food sources
- AI not building drop-off buildings (mill) near food
- Villagers assigned to distant resources

## Future improvements

Not yet implemented:

1. **Automated assertions**: Script that parses JSON and fails on bad conditions
2. **Two-AI battles**: Test combat and military AI
3. **Longer runs**: 5-10 minute tests for late-game behavior
4. **Comparison runs**: Before/after code changes
