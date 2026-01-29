# Gotchas

Accumulated learnings and pitfalls. Add entries here as issues are encountered during development.

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

- **Typed arrays in GDScript 4**: When using `Array[String]` as an export, don't assign with `= ["a", "b"]` - this creates an untyped array. Use `.assign(["a", "b"])` instead. Also use `.has()` instead of `in` operator for checking membership in typed arrays.

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

- **Asset sources updated**: AoE sprites now used for: villager, militia, sheep, deer, boar, wolf (units with 8-dir idle animations); town_center, house, barracks, mill, lumber_camp, mining_camp (buildings); tree, berry_bush, gold_mine, stone_mine, food_carcass (resources). Farm still uses SVG placeholder (no AoE farm sprite available).

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
