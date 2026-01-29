# Automated UX Testing Framework

This folder documents the automated testing infrastructure for the AoE2 clone.

## Quick Start

**In Godot:**
1. Open `tests/test_scene.tscn`
2. Cmd+R (Mac) or F6 (Windows/Linux)
3. Watch console for test results

**From command line (CI):**
```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . res://tests/test_scene.tscn
```

## What It Tests

Currently implemented: **Selection Tests**

- Click on unit → unit selected
- Click empty ground → deselect
- Click different unit → selection changes
- Click near unit (within 30px) → selects
- Click far from unit → no selection
- Box drag → multiple selection
- Enemy units → should not be selectable

## Architecture

```
tests/
├── test_scene.tscn          # Run this scene to execute tests
├── test_main.gd             # Extends main.gd, runs tests on load
├── test_runner.gd           # Test execution engine
├── helpers/
│   ├── test_spawner.gd      # Spawn units/buildings at known positions
│   ├── input_simulator.gd   # Simulate mouse clicks and drags
│   ├── assertions.gd        # Check expected game state
│   └── mock_hud.gd          # Stub HUD for testing without UI
└── scenarios/
    └── test_selection.gd    # Selection test cases
```

## How It Works

1. **test_scene.tscn** - Minimal game scene (map, camera, empty containers, mock HUD)
2. **test_main.gd** - Inherits main.gd input handling, adds test execution
3. **TestRunner** - Manages test lifecycle (setup → run → teardown → report)
4. **Helpers** - Spawn entities, simulate input, check state

## Adding New Tests

### Adding a test to an existing scenario

Edit `tests/scenarios/test_selection.gd`:

```gdscript
func get_all_tests() -> Array[Callable]:
    return [
        # ... existing tests ...
        test_my_new_test,
    ]

func test_my_new_test() -> Assertions.AssertResult:
    # Setup
    var unit = runner.spawner.spawn_villager(Vector2(400, 400))
    await runner.wait_frames(2)

    # Action
    await runner.input_sim.click_on_entity(unit)
    await runner.wait_frames(2)

    # Assert
    return Assertions.assert_selected([unit])
```

### Creating a new test scenario

1. Create `tests/scenarios/test_something.gd`:

```gdscript
extends Node
class_name TestSomething

var runner: TestRunner

func _init(test_runner: TestRunner) -> void:
    runner = test_runner

func get_all_tests() -> Array[Callable]:
    return [
        test_example,
    ]

func test_example() -> Assertions.AssertResult:
    # Your test code
    return Assertions.assert_true(true, "Should pass")
```

2. Add to `test_main.gd`:

```gdscript
func _ready() -> void:
    # ... existing setup ...

    # Add your new tests
    var something_tests = TestSomething.new(test_runner)
    await test_runner.run_all_tests(something_tests.get_all_tests())
```

## Available Helpers

### TestSpawner

```gdscript
spawner.spawn_villager(position, team)  # Returns villager node
spawner.spawn_militia(position, team)   # Returns militia node
spawner.spawn_town_center(position, team)
spawner.spawn_house(position, team)
spawner.spawn_barracks(position, team)
spawner.clear_all()                     # Remove all spawned entities
```

### InputSimulator

```gdscript
await input_sim.click_at_world_pos(Vector2(x, y))
await input_sim.right_click_at_world_pos(Vector2(x, y))
await input_sim.click_on_entity(entity)
await input_sim.right_click_on_entity(entity)
await input_sim.drag_box(start_pos, end_pos)
```

### Assertions

```gdscript
Assertions.assert_selected([unit1, unit2])      # Exactly these selected
Assertions.assert_nothing_selected()            # Selection empty
Assertions.assert_selection_count(3)            # N units selected
Assertions.assert_unit_selected(unit)           # Unit is in selection
Assertions.assert_unit_not_selected(unit)       # Unit not in selection
Assertions.assert_unit_at_position(unit, pos)   # Unit near position
Assertions.assert_true(condition, message)      # Generic
Assertions.assert_equal(actual, expected)       # Equality
```

### TestRunner

```gdscript
await runner.wait_frames(2)  # Wait for input to process
```

## Important Notes

### Frame Timing

Always `await runner.wait_frames(N)` after:
- Spawning entities (2 frames)
- Simulating input (2 frames)

Input doesn't process instantly - Godot needs frames to handle it.

### Hit Detection Radii

From `main.gd`:
- Units: 30px radius
- Buildings: 60px radius
- Resources: 40px radius

Tests should account for these when clicking "near" vs "on" entities.

### Known Limitations

1. **No pathfinding tests yet** - Movement tests need more wait time
2. **Input simulation unreliable** - Godot headless mode on Mac has a ~20x coordinate scaling bug. Tests use `direct_select_*` methods instead.

### Direct Selection API

Due to input simulation issues, tests use direct method calls:

```gdscript
# Instead of: await runner.input_sim.click_on_entity(unit)
await runner.input_sim.direct_select_entity(unit)

# Instead of: await runner.input_sim.click_at_world_pos(pos)
await runner.input_sim.direct_select_at_world_pos(pos)

# Instead of: await runner.input_sim.drag_box(start, end)
await runner.input_sim.direct_box_select(start, end)
```

This tests the selection logic directly without going through input simulation.

## Future Expansion

Planned test scenarios:
- `test_commands.gd` - Right-click move/attack/gather commands
- `test_building_placement.gd` - Building placement validation
- `test_training.gd` - Unit training from buildings
- `test_resources.gd` - Gathering and resource management

## CI Integration

Tests auto-quit in headless mode with proper exit code:

```bash
# Mac
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . res://tests/test_scene.tscn

# Linux (adjust path as needed)
godot --headless --path . res://tests/test_scene.tscn
```

Exit code 0 = all tests passed, exit code 1 = some tests failed.
