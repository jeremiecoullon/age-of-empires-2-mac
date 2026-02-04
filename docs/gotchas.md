# Gotchas

Accumulated learnings and pitfalls. Add entries here as issues are encountered during development.

---

## Missing Sprites

Track placeholder sprites here for replacement in Phase 9 (Polish). When creating a new entity without an available sprite, add it to this list.

| Entity | Type | Current Placeholder | Notes |
|--------|------|---------------------|-------|
| Farm | Building | `assets/sprites/buildings/farm.svg` | Simple green rectangle |
| Market | Building | `assets/sprites/buildings/market.svg` | Orange rectangle with "M" |
| Archery Range | Building | `assets/sprites/buildings/archery_range.svg` | Building with target |
| Stable | Building | `assets/sprites/buildings/stable.svg` | Brown rectangle with horseshoe |
| Archer | Unit | `assets/sprites/units/archer.svg` | Green figure with bow |
| Scout Cavalry | Unit | `assets/sprites/units/scout_cavalry.svg` | Orange mounted figure |
| Spearman | Unit | `assets/sprites/units/spearman.svg` | Blue figure with spear |
| Skirmisher | Unit | `assets/sprites/units/skirmisher.svg` | Light green figure with javelins |
| Cavalry Archer | Unit | `assets/sprites/units/cavalry_archer.svg` | Mounted figure with bow |
| Trade Cart | Unit | `assets/sprites/units/trade_cart.svg` | Cart/wagon figure |

**Important:** Never use another entity's sprite as a fallback. Always create an SVG placeholder and add it here.

---

## Missing UI Feedback

Track mechanics that work in code but have no visual feedback for the player. Address in Phase 10 (Polish & UX).

| Mechanic | Status | What's Missing |
|----------|--------|----------------|
| Armor system | Working (Phase 2B) | No armor values shown in unit info panel, no damage numbers, no indication of melee vs pierce attack type |
| Bonus damage | Working (Phase 2B) | Spearman +15 vs cavalry works but player can't see bonus being applied |

---

## Known UI Layout Issues

Track layout/visual issues for future polish.

| Issue | Added | Notes |
|-------|-------|-------|
| Minimap square on diamond navbar | Phase 2.6A | The minimap is square but the AoE2 navbar behind it is diamond-shaped. The minimap is centered over the diamond which looks off. **Possible fix:** Make maps always diamond-shaped (rotated square), so the minimap naturally fits the diamond frame. This is non-trivial and deferred to Phase 10 Polish. |

---

## Project Structure

- Collision layers: 1=Units, 2=Buildings, 4=Resources
- Team 0 = Player (Blue), Team 1 = AI (Red)
- All game state goes through GameManager singleton

---

## Learnings

### Phase 1A - Resource System Refactor

- **Always pass team parameter**: When refactoring to unified functions with team parameter (e.g., `add_resource(type, amount, team)`), must update ALL call sites. Easy to miss places like unit death, training completion.

- **Dictionary-based resources**: Works well in GDScript since dictionaries are passed by reference. But consider adding validation for unknown resource types to catch typos early.

- **Drop-off finding edge case**: If no valid drop-off exists, villager should wait in place (still in RETURNING state) rather than going IDLE and losing carried resources.

- **Building placement validation**: Both player and AI need to check resource collision, not just building collision. The AI's `_is_valid_building_position` initially missed resource checks.

- **TownCenter needs team-aware training**: When TownCenter trains villagers, it must use its own team for resource spending and population, not hardcode team 0. Otherwise AI Town Centers spend player resources.

- **Typed arrays in GDScript 4**: When using `Array[String]` as an export, don't assign with `= ["a", "b"]` - this creates an untyped array. Use `.assign(["a", "b"])` instead. Also use `.has()` instead of `in` operator for checking membership in typed arrays. **Important:** The `.filter()` method always returns an untyped `Array`, even when called on a typed array. You cannot assign it directly back: `my_typed_array = my_typed_array.filter(...)` will error at runtime. Use `.assign()` instead: `my_typed_array.assign(my_typed_array.filter(...))`.

### Phase 1B - Animals & Food Sources

- **Animals don't add/remove population**: Animals extend Unit but should NOT be counted in population. Override die() completely rather than calling super.die() which would decrement population.

- **Neutral team = -1**: Wild/unowned animals use team = -1 (NEUTRAL_TEAM constant). Player = 0, AI = 1.

- **Preload scenes for runtime spawning**: When spawning scenes during gameplay (like carcasses on animal death), use `preload()` as a class constant rather than `load()` at runtime. Avoids file I/O during gameplay.

- **Throttle expensive tree searches**: Functions like `get_tree().get_nodes_in_group()` are O(n). Don't call them every frame. Use timers (e.g., check every 0.5s) for aggro detection, ownership checks, etc.

- **Store last known position before target dies**: When hunting/attacking a moving target, store their position each frame. When they die, you can find the carcass at the last known position even if the target node is already freed.

- **Animals aren't "units" in AoE2 spec**: The manual doesn't list HP/attack for sheep/deer/boar/wolf in the Unit Attributes appendix. They're resources/hazards, not combat units. Use reasonable placeholder values.

### Phase 1C - Basic Sprites

- **Sprite sheets need region_rect**: Tiny Swords assets are sprite sheets (multiple frames for animation). Use `region_enabled = true` and `region_rect = Rect2(x, y, w, h)` where (x,y) is top-left corner and (w,h) is frame size. For first frame: `Rect2(0, 0, frame_width, frame_height)`. Common frame sizes: units 192x192, sheep 128x128, trees 256x256. **Standalone files (SVGs, individual PNGs) should NOT use region_rect.**

- **Sprite scale calculation**: Target visual size in game pixels, then `scale = target / source_size`. Units typically 30-40px visual to match ~24px collision. Buildings 50-80px visual for 64-96px collision. Example: 192x192 sprite × 0.2 scale = 38px visual. Document your scale choice.

- **Vertical sprite offset for tall objects**: Use `position = Vector2(0, -y)` to visually center tall sprites (trees) when collision shape is at ground level. The sprite extends upward while collision stays at origin.

- **Standardized sprite paths for easy replacement**: Put sprites in `assets/sprites/{units,buildings,resources}/` with consistent names. To replace later: drop in new file with same name. Godot handles PNG/SVG the same way.

- **Team colors + pre-colored sprites = tinted result**: Current `_apply_team_color()` uses modulate to tint sprites. With pre-colored Blue sprites from Tiny Swords, AI units (red modulate on blue base) will look purple-ish. Proper fix: load team-specific sprites. Deferred for now.

- **SVG for placeholder sprites**: SVGs are text-based XML that Godot can import. Good for creating simple placeholder sprites (e.g., deer, boar, wolf) when asset pack doesn't have them. Will look flat compared to pixel art. Replace with matching pixel art before polish phase.

- **SelectionIndicator without texture**: SelectionIndicator nodes use `scale = Vector2(width, height)` as direct dimensions in game pixels (not multipliers) since they have no texture. Main sprites use scale as multipliers on texture dimensions.

- **Asset sources**: Tiny Swords pack: villager, militia, sheep, all buildings except farm, tree, berry_bush, gold_mine, stone_mine, food_carcass. Custom SVG placeholders: deer, boar, wolf, farm.

### Phase 1D - AoE Sprites & 8-Directional Animations

- **AoE sprites are individual frames, not sprite sheets**: Unlike Tiny Swords (sprite sheets with region_rect), AoE sprites are separate PNG files per frame (e.g., `Villagerstand001.png` through `Villagerstand075.png`). Load them into SpriteFrames at runtime.

- **8-directional sprite order**: AoE unit sprites encode 8 facing directions sequentially in this order: **SW, W, NW, N, NE, E, SE, S** (counter-clockwise starting from Southwest). For a 75-frame animation, each direction has ~9 frames (75/8 = 9, with 3 unused frames at the end).

- **Direction from velocity calculation**: Use `velocity.angle()` to get angle from +X axis, divide circle into 8 sectors (45° each), then map angle-sector to AoE direction order. Add PI/8 offset so sector boundaries fall between cardinal directions. **Note**: The mapping may not be pixel-perfect for all 8 directions - AoE sprite direction identification from small frames is tricky. Current implementation is "good enough" but could be refined in Phase 9 Polish. See `_get_direction_from_velocity()` in unit.gd.

- **Cache SpriteFrames to avoid repeated I/O**: When loading frames at runtime with DirAccess + load(), cache the resulting SpriteFrames in a static Dictionary. Same animation shared by many units (e.g., all villagers) only loads once. Use different cache keys for 8-dir vs single-dir animations.

- **AnimatedSprite2D still supports modulate**: Team color tinting via `sprite.modulate = PLAYER_COLOR` works identically on AnimatedSprite2D as it did on Sprite2D (both inherit from CanvasItem).

- **DirAccess may not work in exported builds**: `DirAccess.list_dir_begin()` lists raw files, but exported builds use Godot's import system (.import files). Consider pre-generating SpriteFrames as .tres resources before shipping. Works fine during development.

- **Remove default animation from SpriteFrames.new()**: `SpriteFrames.new()` creates a "default" animation automatically. Call `sprite_frames.remove_animation("default")` first to avoid unused animation clutter.

- **Call _update_facing_direction() after move_and_slide()**: Subclasses that override movement must call `_update_facing_direction()` after `move_and_slide()` to update the sprite facing. The base Unit class doesn't automatically handle this since subclasses fully override _physics_process().

- **Validate minimum frames for 8-dir animations**: Before creating an 8-directional animation, verify the sprite folder has at least 8 frames. If fewer frames exist, fall back to a single-direction animation to avoid index errors.

- **Asset sources updated**: AoE sprites now used for: villager, militia, sheep, deer, boar, wolf (units with 8-dir idle animations); town_center, house, barracks, mill, lumber_camp, mining_camp (buildings); tree, berry_bush, gold_mine, stone_mine, food_carcass (resources). Farm and Market use custom SVG placeholders (no AoE sprites available).

### Phase 1E - Market & Trading

- **Market prices are global**: All players share the same market prices. Buying increases price, selling decreases. This is the AoE2 model - it creates strategic tension (if AI sells wood heavily, prices drop for everyone).

- **Sell price spread (~70% of buy price)**: AoE2-style spread means you can't arbitrage (buy and immediately sell for profit). Implemented as `sell_price = buy_price * 0.7`.

- **Trade Cart gold formula**: Gold earned = distance_in_tiles × 0.46 (roughly 46 gold per 100 tiles one-way). Trade Carts swap home/destination after each trade, so they automatically return.

- **Trade Cart needs two markets**: For meaningful trade income, you need two markets far apart. With only one market, Trade Carts have no destination. AI doesn't train Trade Carts (would need two AI markets or allied player).

- **AI market usage is conservative**: AI only sells when surplus > 400, only buys when desperate (resource < 50) AND has gold > 150. Prevents AI from bankrupting itself through poor trades.

- **Building panels: explicit over generic**: Kept explicit panels per building type (tc_panel, barracks_panel, market_panel) rather than a generic system. This matches AoE2's approach and is easier to understand. See DD-005 in design_decisions.md.

- **Market sprite**: Custom SVG created at `assets/sprites/buildings/market.svg` since no AoE market sprite was available in asset pack.

- **Preload() pattern for runtime spawning**: Several existing files still use `load()` at runtime (barracks.gd, town_center.gd, ai_controller.gd). Phase 1E market.gd was fixed to use preload(). The pattern should be applied consistently - use `const SceneName: PackedScene = preload("path")` rather than `const PATH = "path"` + `load(PATH)`. This is a known tech debt to address.

- **Click selection priority (units > buildings)**: Selection logic is split across two functions in main.gd. `_start_selection()` runs on mouse press and handles building panel display. `_click_select()` runs on mouse release and handles unit/resource selection. Units must be checked in BOTH functions to ensure they have priority over buildings (otherwise clicking a militia near a building selects the building). The fix: `_start_selection()` checks for units first and skips building handling if one is found.

### Phase 2A - Ranged Combat Foundation

- **Preload textures for static sprites:** When using static sprites (SVG placeholders, single images), use `const TEXTURE = preload("path")` at class level instead of `load()` at runtime. Avoids file I/O during gameplay.

- **Group-based attack dispatch:** Use `unit.is_in_group("military")` instead of explicit type checks (`is Militia or is Archer`) for attack command handling in main.gd. More extensible as new military units are added.

- **Static sprite loader pattern:** For units without 8-dir animations, use `_load_static_sprite(texture)` helper that creates a single-frame SpriteFrames from the preloaded texture.

### Phase 2B - Stable, Cavalry & Infantry

- **preload() vs load() for new assets:** New asset files (SVGs, scenes) that haven't been imported by Godot yet will cause `preload()` to fail at parse time. This breaks the entire class resolution chain - if `stable.gd` preloads `scout_cavalry.tscn` which references `scout_cavalry.gd` which preloads an unimported SVG, the whole chain fails and `Stable` class can't be registered. **Fix:** Use `load()` at runtime for newly created assets until they're imported. Run `godot --headless --import --path .` to force Godot to import all assets before running tests.

- **Armor system signature:** `take_damage(amount, attack_type, bonus_damage)` where `attack_type` is "melee" or "pierce". Armor reduces base damage (min 1), then bonus damage is added. This matches AoE2's damage formula.

- **Bonus damage via groups:** Spearman's anti-cavalry bonus checks `target.is_in_group("cavalry")`. When adding new unit types, add them to appropriate groups (cavalry, infantry, archer, siege) for bonus damage targeting.

### Pre-Phase Tests (MVP)

- **queue_free doesn't remove from groups immediately**: When a node is queue_free'd, it stays in its groups until actually freed at end of frame. If you check groups in a deferred call (like check_victory), the destroyed node is still there. Fix: check for `is_destroyed` flag before counting nodes. Example: `check_victory()` had to skip TCs where `tc.is_destroyed == true`.

- **GDScript lambdas capture primitives by value**: When connecting signals with lambdas like `signal.connect(func(): my_bool = true)`, primitive types (bool, int, float) are captured by value, not reference. The outer variable won't be updated. Fix: use arrays to capture by reference: `var result = [false]; signal.connect(func(): result[0] = true)`.

### Resource Gathering Interface

- **Farm duck-types ResourceNode interface**: Farm extends Building (for placement, HP, team ownership) but implements the same gathering interface as ResourceNode: `harvest(amount) -> int`, `get_resource_type() -> String`, `has_resources() -> bool`, plus `gather_rate` property. Villager's `target_resource` and `command_gather()` use `Node` type (not `ResourceNode`) to accept both via duck typing. When adding new gatherable building types (e.g., Fish Trap), ensure they implement these methods and add themselves to the "resources" group.

### Phase 2E - Fog of War & Stances

- **Fog of war needs throttling**: Updating visibility every frame is expensive. Use a timer (0.2s interval) to throttle updates. Even so, iterating all units/buildings and all tiles (60x60 = 3600) can be costly in late game.

- **Neutral entities need special fog handling**: Team -1 (wild animals) should be visible in EXPLORED or VISIBLE tiles, not hidden like enemy units. Check for `NEUTRAL_TEAM` separately from enemy team.

- **AI defense should check all building positions**: When detecting threats, don't just check distance from spawn position (AI_BASE_POSITION). Buildings may spread out, and outlying structures need defense too. Iterate all AI buildings.

- **Stance system integrates with existing state machines**: Military units already have state machines (IDLE, MOVING, ATTACKING). The stance system affects the auto-aggro check in IDLE state and the chase distance in ATTACKING state. No need for a separate stance state.

- **Attack notification throttling**: Use separate cooldowns for military vs civilian attacks. 5 seconds is a good interval to prevent spam while still alerting the player. The signal emits the attack type ("military", "villager", "building") so UI can differentiate.

- **preload() for town center villager scene**: TownCenter was using `load()` for the villager scene at runtime. Changed to `preload()` for consistency with project conventions. This applies to all scene spawning in production code.

### Phase 2.5A - UX Polish

- **NavigationAgent2D avoidance requires scene AND script changes**: Enabling avoidance on units requires: (1) Scene properties: `avoidance_enabled = true`, `radius = 12.0`, `neighbor_distance = 50.0`, `max_neighbors = 10`, `max_speed = 100.0`; (2) Script: use `_apply_movement(velocity)` helper instead of directly setting velocity, and connect `velocity_computed` signal to handle safe velocity callback.

- **Production queue pattern (AoE2-style)**: Resources deducted immediately when queueing (not when training starts). Cancel removes last queued item (not currently training unit) and refunds resources. This prevents queue-and-cancel exploits and matches AoE2 behavior.

- **Consolidate static sprite loading in base class**: The `_load_static_sprite(texture, scale)` method in Unit base class handles single-image sprites (SVG placeholders). Subclasses don't need to duplicate this code.

- **Live UI updates via _process()**: Updating UI elements every frame in `_process()` works but could be throttled for performance if the updates become expensive. For now it's acceptable, but consider throttling if profiling shows issues.

### Phase 2.5B - Villager-Based Building Construction

- **is_functional() pattern**: Use `is_functional()` instead of just `is_constructed` when checking if a building is usable. A building may be constructed but destroyed (from combat), or under construction but not yet usable. The pattern: `return is_constructed and not is_destroyed`.

- **Builder cleanup on villager death**: Villagers must remove themselves from their target building's builder list in `die()` before calling `super.die()`. Otherwise the building's builder count becomes wrong and may prevent the building from completing if it's waiting for builders.

- **AoE2 partial refund on cancel**: When a player cancels an under-construction building, AoE2 refunds the unbuilt portion: `refund = cost * (1.0 - construction_progress)`. A building at 25% returns 75% of resources. A completed building returns nothing.

- **Multi-builder diminishing returns**: Additional villagers building the same structure follow a harmonic series, not linear scaling. Builder 1 = 1.0x, Builder 2 = +0.5x (1.5x total), Builder 3 = +0.25x (1.75x total), etc. This discourages stacking many villagers on one building.

- **HP scales with construction progress**: Buildings start at 1 HP and scale linearly to max_hp as construction progresses. Formula: `current_hp = 1 + int(progress * (max_hp - 1))`. This makes unfinished buildings vulnerable to raids.

- **Build panel visibility**: The build panel should only show when a villager is selected, not always visible. Check selection in HUD update and hide panel when no villagers are selected.

- **AI builder assignment**: AI should cap builders per building (2 is a good limit) to avoid over-committing villagers to construction. Use `_manage_construction()` in the AI decision loop to assign idle villagers.

### Phase 2.6A - UI Overhaul & Minimap

- **Minimap fog of war integration**: When drawing entities on the minimap, must check fog of war visibility state before rendering enemy entities. Enemy units should only appear when VISIBLE, enemy buildings when EXPLORED or VISIBLE. Failure to do this leaks information to the player.

- **Notification race conditions**: When using `await` with `create_timer()` to auto-hide UI elements, multiple rapid calls can interfere. Use a counter pattern: increment counter on show, store it, check after await that current counter matches stored value before hiding.

- **Minimap grid vs display size**: The minimap uses a 60x60 grid (matching fog of war) but displays at a larger size (150x120). `draw_texture_rect()` handles the scaling. Don't manually calculate scale for each pixel.

### Phase 2.6B - Cursor System

- **Throttle cursor hover detection**: Like fog of war, cursor hover detection should be throttled (0.1s interval) to avoid expensive group searches every frame. The slight delay is imperceptible to users.

- **Reuse position lookup methods**: Don't duplicate `_get_X_at_position()` methods. main.gd already has these - call them via the main_scene reference instead of duplicating the logic.

- **Cursor hotspot positions vary by type**: Arrow cursors use top-left (0,0) hotspot. Centered cursors like forbidden use center (16,16). Tool cursors like axe/hammer use the "impact point" position near the top of the cursor image.

- **Resource group naming**: Resources are NOT in groups like "trees" or "gold_mines". They're in groups named `{resource_type}_resources` (e.g., "wood_resources", "gold_resources", "food_resources"). Use `get_resource_type()` method to get the type string, not group checks like `is_in_group("trees")`.

- **macOS cursor API bug (Godot 4.5.1)**: `Input.set_custom_mouse_cursor()` and `DisplayServer.cursor_set_custom_image()` only work on the first call on macOS with Metal renderer. Subsequent calls are ignored and the cursor stays stuck on the initial texture. **Workaround**: Use a sprite-based cursor: (1) hide system cursor with `Input.mouse_mode = Input.MOUSE_MODE_HIDDEN`, (2) create a CanvasLayer + Sprite2D that follows mouse position, (3) change sprite texture instead of calling cursor API. Remember to restore system cursor in `_exit_tree()`.

- **Cursor hidden when switching to Godot editor (macOS)**: When running the game from the Godot editor and switching to the editor window, the system cursor may remain hidden. This happens despite polling `window.has_focus()` and calling `Input.mouse_mode = Input.MOUSE_MODE_VISIBLE` on focus loss. **No known fix** - appears to be a macOS/Godot limitation when running from the editor. The cursor restores correctly when the game closes. Likely works fine in standalone builds.

### Phase 3 (Original - Replaced)

The original Phase 3 (procedural AI) was scrapped due to architectural issues. The learnings from that failed implementation are documented in `docs/ai_player_designs/phase3_failure_summary.md`.

**Key takeaway**: Procedural AI with tightly coupled systems led to "whack-a-mole" debugging where fixing one behavior broke others. Phase 3.1 replaces this with a rule-based system where rules are independent.

### Phase 3.1A - Rule-Based AI Core

- **AIGameState wraps all queries**: Rules should never access game objects directly. Go through AIGameState which provides a clean interface and allows caching/de-duplication.

- **Action de-duplication pattern**: Rules queue intentions (e.g., `gs.train("villager")`), then `execute_actions()` runs once at end of tick. This prevents multiple rules from issuing conflicting commands.

- **Limit AI training queue size**: Without queue limits, rules can over-commit resources by queueing many units. Check `building.get_queue_size()` in `can_train()` and limit to 3 per building.

- **Use preload() for AI building scenes**: AI creates buildings at runtime. Use preloaded PackedScene constants, not `load()` at runtime, to avoid file I/O during gameplay.

- **is_under_attack() must check all buildings**: Don't just check distance from Town Center. AI buildings spread out - check if enemy military is near ANY AI building. Per gotchas.md Phase 2E: "Buildings may spread out."

- **Attack fallback when TC destroyed**: If player TC is destroyed during the game, AI attack logic should find an alternative target (any player building) rather than silently doing nothing.

- **Use group checks over type checks**: `resource.is_in_group("farms")` is more robust than `resource is Farm`. The latter requires the Farm class to be loaded and can fail if load order changes.

- **Spawning AI starting base**: The AIController spawns the AI's starting Town Center, House, and Villagers on `_ready()`. This keeps the main scene clean and allows AI initialization logic to be self-contained.

### Phase 3.1B - Full Economy Rules

- **_queued flags must reset**: Building rules that use `_queued` flags to prevent duplicate construction attempts (e.g., `_lumber_camp_queued`) must reset the flag when the building is completed. Otherwise, if the building is destroyed, the AI will never rebuild it. Pattern: check if `get_building_count() > 0` at start of conditions() and reset flag.

- **Villager assignment de-duplication**: Multiple rules (GatherSheepRule, HuntRule) can fire in the same tick and try to assign the same idle villager. Track assigned villagers in a dictionary (`_assigned_villagers_this_tick`) and skip if already assigned. Clear the dictionary in `_clear_pending()`.

- **Build vs gather race condition**: Build rules and gather rules can capture the same idle villager in one tick. The action execution order (builds first, then villager assignments) means a villager assigned to construction can be immediately reassigned by a gather rule like GatherSheepRule. The `command_hunt()` call cancels the build by clearing `target_construction`. **Fix:** In `_do_villager_assignment()`, check `if villager.current_state == villager.State.BUILDING: return` before reassigning. This prevents gather rules from stealing builders mid-tick.

- **Mills should be near natural food, not farms**: When using `build_near_resource("mill", "food")`, the `_find_nearest_resource_position()` will find farms if they exist. Add `exclude_farms` parameter to find berries instead - mills are meant for natural food sources.

- **Natural food count excludes farms**: When checking if the AI needs to build farms, count "natural" food sources (berries, sheep, deer, boar) separately from farms. Use `is_in_group("farms")` to filter them out.

- **Economy phase transitions**: Use GOAL constants to track economy phases (early, mid, late game). Transition based on villager count and building presence. Consider whether transitions should be reversible if conditions change (e.g., barracks destroyed).

- **Conservative market trading**: AI market rules should use high thresholds to prevent poor trades. Sell when surplus > 400, buy when desperate (< 50) and have gold > 150. This matches the gotchas from Phase 1E about AI market usage.

- **Prevent villager clustering on resources**: When assigning villagers to gather, don't just pick the nearest resource - check how many villagers are already targeting it. Use `_get_current_gatherer_counts()` to get a `{target_instance_id: count}` dictionary, then skip resources at capacity. The `sn_max_gatherers_per_resource` strategic number controls the limit (default 2). Apply this pattern to all resource assignment functions: `assign_villager_to_resource()`, `get_nearest_sheep()`, `get_nearest_huntable()`. Use graceful degradation: if all resources are full, still assign to the nearest one rather than leaving the villager idle.

- **Count RETURNING villagers in gatherer limits**: Villagers in RETURNING state (walking back to drop off resources) will return to the same resource after depositing. If you only count GATHERING/HUNTING states, you'll under-count and over-assign. The `_get_current_gatherer_counts()` function must check for `villager.State.RETURNING` and use `target_resource` or `target_animal` (whichever is valid) to track their target.

- **Distance vs capacity tradeoff for resource assignment**: An empty resource 1000px away is often worse than a "full" resource 50px away (sharing is more efficient than walking). Use distance thresholds: if the nearest available resource is >400px but a "full" resource is <200px, prefer the closer one. This prevents absurd long-distance assignments when local resources are slightly over capacity.

- **Farms are renewable - exempt from gatherer limits**: Farms regrow and provide infinite food, unlike depletable resources (sheep, berries). The max_gatherers limit makes sense for sheep (limited food) but farms can support many villagers. Check `resource.is_in_group("farms")` and skip the capacity check for farms.

- **Track pending assignments within same tick**: When multiple rules fire in one tick, `_get_current_gatherer_counts()` only sees villagers already in GATHERING/HUNTING states. Villagers assigned earlier in the same tick (queued but not executed) aren't counted, causing multiple villagers to be assigned to the same target. Fix: maintain `_assigned_targets_this_tick` dictionary tracking `{target_instance_id: count}` and merge it into gatherer counts.

- **Hard cap graceful degradation**: When all resources of a type are at capacity, graceful degradation assigns villagers to the nearest anyway (better than leaving idle). But without a cap, this causes excessive piling. Add a hard cap (e.g., 2x max_gatherers) - if a target exceeds this, return null instead of assigning more.

- **Drop-off buildings need resources FAR from existing drop-offs**: When placing mills, lumber camps, or mining camps, `_find_nearest_resource_position()` must skip resources that are already close to an existing drop-off (< 200px). Otherwise the AI builds a lumber camp near trees that are already next to the TC - useless. The `for_dropoff_building` parameter enables this filtering. If no qualifying resources exist (all resources already have nearby drop-offs), return `Vector2.ZERO` to fail placement. The rule will retry on future ticks.

- **Max hunt/herd distance**: Don't send villagers to hunt deer/boar or herd sheep beyond a maximum distance (e.g., 500px). Walking across the map to hunt distant animals is inefficient - better to farm or gather nearby resources. If `get_nearest_huntable()` or `get_nearest_sheep()` only finds targets beyond this distance, return null so the villager gets assigned to something else.
