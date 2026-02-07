extends StaticBody2D
class_name Building

const PLAYER_COLOR = Color(0.3, 0.5, 0.9, 1)  # Blue
const AI_COLOR = Color(0.9, 0.2, 0.2, 1)  # Red
const CONSTRUCTION_COLOR_MULT = Color(0.6, 0.6, 0.6, 0.8)  # Dim during construction

@export var building_name: String = "Building"
@export var size: Vector2i = Vector2i(2, 2)  # in tiles
@export var wood_cost: int = 0
@export var food_cost: int = 0
@export var stone_cost: int = 0
@export var gold_cost: int = 0
@export var team: int = 0  # 0 = player, 1 = AI
@export var max_hp: int = 200
@export var melee_armor: int = 0  # Reduces melee damage (most buildings have 0)
@export var pierce_armor: int = 0  # Reduces pierce damage (most buildings have 0)
# Resource types this building accepts for drop-off (empty = not a drop-off point)
@export var accepts_resources: Array[String] = []
@export var sight_range: float = 192.0  # How far building reveals fog (~6 tiles)
@export var build_time: float = 25.0  # Base construction time in seconds (1 villager)

var current_hp: int
var is_constructed: bool = true  # False while under construction
var is_destroyed: bool = false

# Construction system
var construction_progress: float = 0.0  # 0.0 to 1.0
var builders: Array[Node] = []  # Villagers currently constructing this building

# Repair system — tracks fractional resource cost accumulated during repair
var _repair_cost_accumulator: float = 0.0

signal destroyed
signal damaged(amount: int, attacker: Node2D)  # Emitted when building takes damage
signal construction_completed  # Emitted when building finishes construction

func _ready() -> void:
	add_to_group("buildings")
	if is_constructed:
		current_hp = max_hp
	else:
		# Start at 1 HP when under construction
		current_hp = 1
	# Apply team color after a frame to ensure sprite is ready
	call_deferred("_apply_team_color")
	# Connect to attack notification system
	damaged.connect(_on_damaged_for_notification)

func _apply_team_color() -> void:
	if has_node("Sprite2D"):
		var sprite = get_node("Sprite2D")
		var base_color = PLAYER_COLOR if team == 0 else AI_COLOR
		if not is_constructed:
			sprite.modulate = base_color * CONSTRUCTION_COLOR_MULT
		else:
			sprite.modulate = base_color

func get_building_name() -> String:
	return building_name

func is_drop_off_for(resource_type: String) -> bool:
	return accepts_resources.has(resource_type)

## Take damage with armor calculation.
## attack_type: "melee" or "pierce" - determines which armor applies
## bonus_damage: Extra damage that ignores armor (e.g., rams vs buildings)
## attacker: The node that dealt the damage (optional, for notification/response)
func take_damage(amount: int, attack_type: String = "melee", bonus_damage: int = 0, attacker: Node2D = null) -> void:
	var armor = melee_armor if attack_type == "melee" else pierce_armor
	var base_damage = max(1, amount - armor)  # Minimum 1 damage
	var final_damage = base_damage + bonus_damage
	current_hp -= final_damage
	damaged.emit(final_damage, attacker)
	_check_garrison_ejection()
	if current_hp <= 0:
		_destroy()

func _destroy() -> void:
	if is_destroyed:
		return
	is_destroyed = true
	ungarrison_all()
	destroyed.emit()
	queue_free()

## Called when this building takes damage - notifies GameManager for attack alerts
func _on_damaged_for_notification(amount: int, attacker: Node2D) -> void:
	GameManager.notify_building_damaged(self, amount, attacker)

# ===== CONSTRUCTION SYSTEM =====

## Start building as under construction (called during placement)
func start_construction() -> void:
	is_constructed = false
	construction_progress = 0.0
	current_hp = 1
	_apply_construction_visual()

## Add a villager as a builder
func add_builder(villager: Node) -> void:
	if not builders.has(villager):
		builders.append(villager)

## Remove a villager from builders
func remove_builder(villager: Node) -> void:
	builders.erase(villager)

## Get the number of active builders
func get_builder_count() -> int:
	# Clean up invalid builders
	builders.assign(builders.filter(func(b): return is_instance_valid(b)))
	return builders.size()

## Progress construction by delta time. Returns true if construction completed.
func progress_construction(delta: float) -> bool:
	if is_constructed:
		return true

	# Each additional villager adds 50% more speed (diminishing returns)
	# 1 villager = 1x speed, 2 villagers = 1.5x, 3 villagers = 1.75x, etc.
	var builder_count = get_builder_count()
	if builder_count == 0:
		return false

	var speed_mult = 1.0
	for i in range(1, builder_count):
		speed_mult += 0.5 / i  # Diminishing returns

	var progress_rate = speed_mult / build_time
	construction_progress += progress_rate * delta

	if construction_progress >= 1.0:
		construction_progress = 1.0
		_complete_construction()
		return true

	# Update HP based on construction progress
	# HP scales linearly from 1 to max_hp
	current_hp = int(1 + (max_hp - 1) * construction_progress)
	return false

## Complete the construction
func _complete_construction() -> void:
	is_constructed = true
	current_hp = max_hp
	construction_progress = 1.0

	# Clear builders
	builders.clear()

	# Update visuals
	_apply_team_color()

	# Emit signal
	construction_completed.emit()

## Apply visual effect for under-construction buildings
func _apply_construction_visual() -> void:
	if has_node("Sprite2D"):
		var sprite = get_node("Sprite2D")
		var base_color = PLAYER_COLOR if team == 0 else AI_COLOR
		sprite.modulate = base_color * CONSTRUCTION_COLOR_MULT

## Check if this building is functional (not under construction, not destroyed)
func is_functional() -> bool:
	return is_constructed and not is_destroyed

## Get construction progress as percentage (0-100)
func get_construction_percent() -> int:
	return int(construction_progress * 100)

# ===== RESEARCH SYSTEM =====

var is_researching: bool = false
var research_timer: float = 0.0
var current_research_id: String = ""
var research_time: float = 0.0

signal research_started(tech_id: String)
signal research_completed(tech_id: String)

func start_research(tech_id: String) -> bool:
	if is_researching:
		return false
	if tech_id not in GameManager.TECHNOLOGIES:
		return false
	if not GameManager.can_research_tech(tech_id, team):
		return false

	GameManager.spend_tech_cost(tech_id, team)
	is_researching = true
	current_research_id = tech_id
	research_timer = 0.0
	research_time = GameManager.TECHNOLOGIES[tech_id]["research_time"]
	research_started.emit(tech_id)
	return true

func cancel_research() -> bool:
	if not is_researching:
		return false
	GameManager.refund_tech_cost(current_research_id, team)
	is_researching = false
	current_research_id = ""
	research_timer = 0.0
	research_time = 0.0
	return true

func _process_research(delta: float) -> bool:
	## Returns true if research completed this frame
	if not is_researching:
		return false
	research_timer += delta
	if research_timer >= research_time:
		_complete_research()
		return true
	return false

func _complete_research() -> void:
	var completed_id = current_research_id
	is_researching = false
	current_research_id = ""
	research_timer = 0.0
	research_time = 0.0
	GameManager.complete_tech_research(completed_id, team)
	research_completed.emit(completed_id)

func get_research_progress() -> float:
	if not is_researching or research_time <= 0.0:
		return 0.0
	return research_timer / research_time

# ===== REPAIR SYSTEM =====

## Whether this building can be repaired (constructed, not destroyed, and damaged)
func needs_repair() -> bool:
	return is_constructed and not is_destroyed and current_hp < max_hp

## Reset repair state when a new repair session begins
func start_repair() -> void:
	_repair_cost_accumulator = 0.0

## Get the total resource cost for a full repair (50% of original build cost).
## Returns {"wood": int, "food": int, ...} — only non-zero entries.
func get_full_repair_cost() -> Dictionary:
	var cost := {}
	if wood_cost > 0:
		cost["wood"] = max(1, int(wood_cost * 0.5))
	if food_cost > 0:
		cost["food"] = max(1, int(food_cost * 0.5))
	if stone_cost > 0:
		cost["stone"] = max(1, int(stone_cost * 0.5))
	if gold_cost > 0:
		cost["gold"] = max(1, int(gold_cost * 0.5))
	return cost

## Progress repair by delta time. Returns true if repair is complete.
## Repair rate = 3x construction rate (takes ~1/3 the build time for a full repair).
## Resources are deducted continuously from the owner's stockpile.
## If the owner can't afford the next tick of repair, repair pauses (returns false).
func progress_repair(delta: float) -> bool:
	if not needs_repair():
		return true  # Already at full HP

	var builder_count = get_builder_count()
	if builder_count == 0:
		return false

	# Same diminishing-returns formula as construction
	var speed_mult = 1.0
	for i in range(1, builder_count):
		speed_mult += 0.5 / i

	# HP to restore this tick (3x construction speed)
	var hp_per_second = float(max_hp) / build_time * 3.0 * speed_mult
	var hp_this_tick = hp_per_second * delta
	var hp_missing = max_hp - current_hp

	# Clamp so we don't overshoot
	hp_this_tick = min(hp_this_tick, hp_missing)

	# Calculate resource cost for this tick's HP
	# Full repair (max_hp HP) costs 50% of build cost → per-HP cost = 0.5 * cost / max_hp
	var total_build_cost = wood_cost + food_cost + stone_cost + gold_cost
	if total_build_cost == 0:
		# Free building — just heal
		current_hp = min(current_hp + int(ceil(hp_this_tick)), max_hp)
		return current_hp >= max_hp

	var cost_per_hp = 0.5 * float(total_build_cost) / float(max_hp)
	_repair_cost_accumulator += cost_per_hp * hp_this_tick

	# Deduct whole-unit costs when accumulator >= 1
	if _repair_cost_accumulator >= 1.0:
		var cost_to_deduct = int(_repair_cost_accumulator)
		# Charge proportionally from each resource used in construction
		var cost_types: Array[Array] = []  # [resource_type, build_cost] pairs
		if wood_cost > 0: cost_types.append(["wood", wood_cost])
		if food_cost > 0: cost_types.append(["food", food_cost])
		if stone_cost > 0: cost_types.append(["stone", stone_cost])
		if gold_cost > 0: cost_types.append(["gold", gold_cost])
		# Check affordability for all resource types
		for entry in cost_types:
			var res_type: String = entry[0]
			var res_share = int(ceil(cost_to_deduct * float(entry[1]) / total_build_cost))
			if res_share > 0 and not GameManager.can_afford(res_type, res_share, team):
				_repair_cost_accumulator -= cost_per_hp * hp_this_tick
				return false
		# Spend from each resource type proportionally
		for entry in cost_types:
			var res_type: String = entry[0]
			var res_share = int(ceil(cost_to_deduct * float(entry[1]) / total_build_cost))
			if res_share > 0:
				GameManager.spend_resource(res_type, res_share, team)
		_repair_cost_accumulator -= cost_to_deduct

	current_hp = min(current_hp + int(ceil(hp_this_tick)), max_hp)
	return current_hp >= max_hp

# ===== GARRISON SYSTEM =====

@export var garrison_capacity: int = 0  # 0 = no garrison
@export var garrison_adds_arrows: bool = false  # TC/towers add arrows per garrisoned unit

var garrisoned_units: Array = []
var _garrison_heal_accumulator: float = 0.0
const GARRISON_HEAL_RATE: float = 1.0  # HP/sec per unit
const GARRISON_EJECT_HP_PERCENT: float = 0.20  # Eject at 20% HP

## Check if a unit can garrison in this building
func can_garrison(unit: Node) -> bool:
	if garrison_capacity <= 0:
		return false
	if not is_functional():
		return false
	if unit.team != team:
		return false
	if garrisoned_units.size() >= garrison_capacity:
		return false
	if unit.is_dead:
		return false
	if unit.is_garrisoned():
		return false
	# Only foot units can garrison (no cavalry, no trade carts)
	if unit.is_in_group("cavalry"):
		return false
	return true

## Garrison a unit inside this building. Returns true if successful.
func garrison_unit(unit: Node) -> bool:
	if not can_garrison(unit):
		return false
	garrisoned_units.append(unit)
	unit.garrisoned_in = self
	# Stop and deselect the unit before disabling processing
	unit._stop_and_stay()
	if unit.is_selected:
		GameManager.deselect_unit(unit)
	# Hide and disable the unit
	unit.visible = false
	unit.process_mode = Node.PROCESS_MODE_DISABLED
	# Disable collision
	var collision = unit.get_node_or_null("CollisionShape2D")
	if collision:
		collision.set_deferred("disabled", true)
	return true

## Ungarrison a specific unit from this building
func ungarrison_unit(unit: Node) -> void:
	if unit not in garrisoned_units:
		return
	garrisoned_units.erase(unit)
	unit.garrisoned_in = null
	# Re-enable the unit
	unit.visible = true
	unit.process_mode = Node.PROCESS_MODE_INHERIT
	# Re-enable collision
	var collision = unit.get_node_or_null("CollisionShape2D")
	if collision:
		collision.set_deferred("disabled", false)
	# Position outside building
	var offset = _get_eject_offset(garrisoned_units.size())
	unit.global_position = global_position + offset

## Ungarrison all units
func ungarrison_all() -> void:
	var units_to_eject = garrisoned_units.duplicate()
	for i in range(units_to_eject.size()):
		var unit = units_to_eject[i]
		if is_instance_valid(unit):
			garrisoned_units.erase(unit)
			unit.garrisoned_in = null
			unit.visible = true
			unit.process_mode = Node.PROCESS_MODE_INHERIT
			var collision = unit.get_node_or_null("CollisionShape2D")
			if collision:
				collision.set_deferred("disabled", false)
			var offset = _get_eject_offset(i)
			unit.global_position = global_position + offset
	garrisoned_units.clear()

func get_garrisoned_count() -> int:
	# Clean up invalid refs
	garrisoned_units.assign(garrisoned_units.filter(func(u): return is_instance_valid(u) and not u.is_dead))
	return garrisoned_units.size()

## Get bonus arrows from garrisoned units (ranged units + villagers)
func get_garrison_arrow_bonus() -> int:
	if not garrison_adds_arrows:
		return 0
	var bonus = 0
	for unit in garrisoned_units:
		if is_instance_valid(unit):
			if unit.is_in_group("archers") or unit.is_in_group("villagers"):
				bonus += 1
	return bonus

## Heal garrisoned units. Call from _process(delta).
func _process_garrison_healing(delta: float) -> void:
	if garrisoned_units.is_empty():
		return
	_garrison_heal_accumulator += GARRISON_HEAL_RATE * delta
	if _garrison_heal_accumulator >= 1.0:
		var heal_amount = int(_garrison_heal_accumulator)
		_garrison_heal_accumulator -= heal_amount
		for unit in garrisoned_units:
			if is_instance_valid(unit) and unit.current_hp < unit.max_hp:
				unit.current_hp = min(unit.current_hp + heal_amount, unit.max_hp)

## Check if building HP is low enough to eject garrisoned units.
## Called from take_damage().
func _check_garrison_ejection() -> void:
	if garrisoned_units.is_empty():
		return
	if current_hp <= int(max_hp * GARRISON_EJECT_HP_PERCENT):
		ungarrison_all()

## Get eject position offset (ring around building)
func _get_eject_offset(index: int) -> Vector2:
	var angle = (index * TAU / max(8, garrisoned_units.size() + 1))
	var radius = max(size.x, size.y) * 16.0 + 20.0  # Just outside building
	return Vector2(cos(angle) * radius, sin(angle) * radius)
