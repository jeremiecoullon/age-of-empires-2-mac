# Automated UX Testing Framework

This folder documents the automated testing infrastructure for the AoE2 clone.

## Quick Start

1. Open Godot
2. Open `tests/test_scene.tscn`
3. Run the scene (F6 or Scene > Run This Scene)
4. Watch console for test results

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

1. **Box selection uses screen coords** - Camera position affects results
2. **No pathfinding tests yet** - Movement tests need more wait time
3. **Enemy selection test** - `test_only_player_units_selectable` expects enemy units to NOT be selectable, but the game code doesn't filter by team. This test will fail until team filtering is added to `_get_unit_at_position()` in main.gd

### Code Review Fixes Applied

The following issues from code review have been addressed:
- `main.gd` now uses `_screen_to_world()` helper instead of `get_global_mouse_position()` - enables input simulation to work correctly
- `assertions.gd` now validates `is_instance_valid()` before accessing node properties
- `input_simulator.gd` now warns if setup() called before node is in scene tree

## Future Expansion

Planned test scenarios:
- `test_commands.gd` - Right-click move/attack/gather commands
- `test_building_placement.gd` - Building placement validation
- `test_training.gd` - Unit training from buildings
- `test_resources.gd` - Gathering and resource management

## CI Integration

To run tests headless (for CI):

```bash
godot --headless --path . -s tests/test_scene.tscn
```

Uncomment the quit logic in `test_main.gd`:
```gdscript
func _on_tests_completed(passed: int, failed: int, _results: Array) -> void:
    # ...
    await get_tree().create_timer(1.0).timeout
    get_tree().quit(0 if failed == 0 else 1)
```
