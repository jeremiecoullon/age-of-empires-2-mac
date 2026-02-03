# AI debugging session - February 2026

## Problem statement

The AI opponent was "way too bad" - user could easily defeat it with 15-20 villagers and basic military. The AI had barely built anything (about 5 buildings, an archery range, mill). Villagers were bunching up, getting stuck, and the economy was failing.

## Root causes identified

### 1. Inefficient food gathering
- **All villagers were hunting** across the map instead of using sheep near TC
- No limit on hunters - saw 4-6 villagers chasing animals far from base
- Berries were being ignored
- Farms weren't being used (build order had farms way too late at step 37)

### 2. No builders available
- All villagers assigned to tasks, none idle for building
- Buildings queued but never constructed
- Log showed "No builder for lumber_camp" for 60+ seconds

### 3. Camp/mill placement broken
- `_find_resource_cluster_position()` returned the FIRST resource found, not nearest to base
- Lumber camps could be placed anywhere on the map
- Mill was placed near TC instead of near berries

### 4. Pathfinding/collision issues
- Villagers bunching up and blocking each other
- NavigationAgent2D avoidance settings too tight (radius=12, neighbor_distance=50)
- Farms placed too close together

### 5. Wood economy collapsed
- All villagers on food, none on wood
- Wood stuck at 0, couldn't build anything
- No minimum wood gatherer guarantee

## Fixes implemented

### A. Food gathering priority (ai_controller.gd)
```gdscript
# Added constants
const MAX_HUNTERS: int = 2
const MAX_HUNT_DISTANCE: float = 400.0
const SHEEP_PRIORITY_DISTANCE: float = 300.0

# New priority order in _assign_villager_to_resource():
# 1. Sheep near TC (safe, efficient)
# 2. Berries (with mill)
# 3. Farms (if we have them)
# 4. Hunt animals (LIMITED to MAX_HUNTERS)
```

### B. Builder availability (ai_controller.gd)
- `_find_idle_builder()` now interrupts hunters if no idle villagers
- Added `stop_current_action()` method to villager.gd
- Can also interrupt wood gatherers as last resort

### C. Resource allocation (ai_controller.gd)
```gdscript
# Added minimum wood gatherers
const MIN_WOOD_GATHERERS: int = 3

func _get_needed_resource(allocation: Dictionary) -> String:
    if allocation["wood"] < MIN_WOOD_GATHERERS:
        return "wood"
    # ... rest of function
```

### D. Farm assignment (ai_controller.gd)
- `_find_ai_farm()` now skips farms that already have a gatherer
- Prevents all villagers crowding on one farm

### E. Camp/mill placement (ai_controller.gd)
```gdscript
func _find_resource_cluster_position(resource_type: String) -> Vector2:
    # Now finds NEAREST resource to AI_BASE_POSITION
    # Within MAX_CAMP_DISTANCE (600) limit
    # Returns Vector2.ZERO if nothing found nearby

func _build_mill() -> void:
    # Now checks for berries first
    # Builds near berries if they exist
    # Otherwise builds near TC for farms
```

### F. Unit avoidance (all .tscn files)
Updated NavigationAgent2D settings in all unit scenes:
- `radius`: 12 → 20
- `neighbor_distance`: 50 → 100
- Added `avoidance_priority = 0.5`

Files changed:
- villager.tscn
- militia.tscn
- archer.tscn
- spearman.tscn
- scout_cavalry.tscn
- skirmisher.tscn
- cavalry_archer.tscn

### G. Building spacing (ai_controller.gd)
```gdscript
const FARM_RING_INNER_RADIUS: float = 100.0  # was 70
const FARM_RING_OUTER_RADIUS: float = 180.0  # was 140
const FARM_RING_SPACING: float = 90.0  # was 70
```

### H. Build order (build_order.gd)
- Lumber camp moved earlier (villager 7, was 8)
- Mill at 11 pop
- Farms spread throughout build order starting at 12 pop (was step 37!)

### I. Debug logging (ai_controller.gd)
Added comprehensive logging:
- State dump every 10 seconds (villagers, resources, buildings, allocation)
- Event logging with timestamps
- Build order status (why current step is blocked)
- Camp placement distance from base
- Warnings when no resources found

Toggle with: `const AI_DEBUG: bool = true`

## Files modified

1. `scripts/ai/ai_controller.gd` - Major changes to economy logic
2. `scripts/ai/build_order.gd` - Revised Dark Age build order
3. `scripts/units/villager.gd` - Added `stop_current_action()`
4. `scenes/units/*.tscn` - All 7 unit scenes (avoidance settings)
5. `scripts/fog_of_war.gd` - Added `FOG_DISABLED` toggle for debugging

## Documentation created

- `docs/ai_strategy_research.md` - Competitive AoE2 build orders and strategy research

## Testing notes

Run the game and observe the AI debug output in terminal. Key things to verify:
1. Lumber camp/mining camp built within ~300 distance of base
2. Mill built near berries (if they exist)
3. Max 2 hunters at any time
4. Wood gatherers >= 3 after initial food setup
5. Villagers not bunching up excessively

## Remaining concerns

1. **Boar luring not implemented** - Real AoE2 uses boar luring for fast food. Our AI just hunts sheep.
2. **Only one of each camp** - AI tracks single `ai_lumber_camp`, `ai_mining_camp`. Could benefit from multiple as it expands.
3. **Pathfinding still imperfect** - Avoidance helps but Godot's navigation has limits with many units.
4. **No villager garrison** - Can't hide villagers in TC during raids.

## Debug commands

To enable/disable fog of war for observation:
```gdscript
# In scripts/fog_of_war.gd
const FOG_DISABLED: bool = true  # Set to false for normal gameplay
```

To enable/disable AI debug logging:
```gdscript
# In scripts/ai/ai_controller.gd
const AI_DEBUG: bool = true
```
