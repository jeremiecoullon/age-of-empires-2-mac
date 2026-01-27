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
