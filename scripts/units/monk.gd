extends Unit
class_name Monk

## Monk - support unit with healing and conversion abilities.
## AoE2 spec: 100G cost, 30 HP, 0 attack, 0/0 armor, speed 70
## Cannot attack. Heals friendly wounded units. Converts enemy units.

enum State { IDLE, MOVING, HEALING, CONVERTING }

var current_state: State = State.IDLE

# Healing
var heal_target: Node2D = null
var heal_range: float = 128.0  # ~4 tiles
var heal_rate: float = 1.0  # HP per second
var heal_scan_timer: float = 0.0
var _heal_accumulator: float = 0.0
const HEAL_SCAN_INTERVAL: float = 0.5  # Auto-heal scan interval

# Conversion
var conversion_target: Node2D = null
var conversion_range: float = 288.0  # ~9 tiles
var conversion_timer: float = 0.0

# Rejuvenation (cooldown after conversion)
var is_rejuvenating: bool = false
var rejuvenation_timer: float = 0.0
var rejuvenation_time: float = 62.0  # AoE2 base

# Conversion resistance (applied by target, not monk)
var conversion_resistance: float = 0.0

# Relic carrying (Phase 6B)
var carrying_relic: Node = null

# Base stats for tech bonuses
var _base_conversion_range: float = 288.0
var _base_move_speed: float = 70.0
var _base_rejuvenation_time: float = 62.0

func _ready() -> void:
	super._ready()
	add_to_group("monks")
	# Monks are NOT military - they don't auto-attack or count for attack thresholds
	max_hp = 30
	current_hp = max_hp
	move_speed = 70.0
	melee_armor = 0
	pierce_armor = 0
	sight_range = 352.0  # 11 tiles - long sight range
	stance = Stance.NO_ATTACK  # Monks never auto-attack
	_load_directional_animations("res://assets/sprites/units/monk_frames", "Monkstand", 30)
	_store_base_stats()
	apply_tech_bonuses()

func _store_base_stats() -> void:
	super._store_base_stats()
	_base_conversion_range = conversion_range
	_base_move_speed = move_speed
	_base_rejuvenation_time = rejuvenation_time

func apply_tech_bonuses() -> void:
	super.apply_tech_bonuses()
	# Sanctity: +15 HP (50% of base 30)
	var hp_bonus = GameManager.get_tech_bonus("monk_hp", team)
	if hp_bonus > 0:
		var old_max = max_hp
		max_hp = _base_max_hp + hp_bonus
		if max_hp > old_max:
			current_hp += max_hp - old_max
	# Fervor: +15% speed
	var speed_bonus = GameManager.get_tech_bonus("monk_speed", team)
	if speed_bonus > 0:
		move_speed = _base_move_speed * (1.0 + speed_bonus / 100.0)
	else:
		move_speed = _base_move_speed
	# Block Printing: +96 range (+3 tiles)
	var range_bonus = GameManager.get_tech_bonus("monk_range", team)
	conversion_range = _base_conversion_range + range_bonus
	# Illumination: faster rejuvenation (50% faster = divide by 1.5)
	var illumination = GameManager.get_tech_bonus("illumination", team)
	if illumination > 0:
		rejuvenation_time = _base_rejuvenation_time / 1.5
	else:
		rejuvenation_time = _base_rejuvenation_time

func _physics_process(delta: float) -> void:
	# Process rejuvenation cooldown
	if is_rejuvenating:
		rejuvenation_timer += delta
		if rejuvenation_timer >= rejuvenation_time:
			is_rejuvenating = false
			rejuvenation_timer = 0.0

	match current_state:
		State.IDLE:
			_stop_and_stay()
			_check_auto_heal(delta)
		State.MOVING:
			_process_moving()
		State.HEALING:
			_process_healing(delta)
		State.CONVERTING:
			_process_converting(delta)

func _check_auto_heal(delta: float) -> void:
	heal_scan_timer += delta
	if heal_scan_timer < HEAL_SCAN_INTERVAL:
		return
	heal_scan_timer = 0.0

	# Don't auto-heal while rejuvenating
	if is_rejuvenating:
		return

	# Look for nearby wounded friendly units
	var target = _find_wounded_friendly()
	if target:
		command_heal(target)

func _find_wounded_friendly() -> Unit:
	var nearest: Unit = null
	var nearest_dist: float = sight_range

	for unit in get_tree().get_nodes_in_group("units"):
		if unit == self:
			continue
		if unit.team != team:
			continue
		if unit.is_dead:
			continue
		if unit.current_hp >= unit.max_hp:
			continue  # Not wounded
		# Don't heal buildings or siege (future)
		if not unit is Unit:
			continue

		var dist = global_position.distance_to(unit.global_position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = unit

	return nearest

func _process_moving() -> void:
	if nav_agent.is_navigation_finished():
		current_state = State.IDLE
		return

	var next_path_position = nav_agent.get_next_path_position()
	var direction = global_position.direction_to(next_path_position)
	_resume_movement()
	_apply_movement(direction * move_speed)

func _process_healing(delta: float) -> void:
	if not is_instance_valid(heal_target) or heal_target.is_dead:
		heal_target = null
		_heal_accumulator = 0.0
		current_state = State.IDLE
		return

	# Check if target is fully healed
	if heal_target.current_hp >= heal_target.max_hp:
		heal_target = null
		_heal_accumulator = 0.0
		current_state = State.IDLE
		return

	var distance = global_position.distance_to(heal_target.global_position)

	if distance > heal_range:
		# Move closer to target
		nav_agent.target_position = heal_target.global_position
		var next_path_position = nav_agent.get_next_path_position()
		var direction = global_position.direction_to(next_path_position)
		_resume_movement()
		_apply_movement(direction * move_speed)
		return

	# In range - heal (1 HP/sec via accumulator)
	_stop_and_stay()
	_heal_accumulator += heal_rate * delta
	if _heal_accumulator >= 1.0:
		var heal_amount = int(_heal_accumulator)
		heal_target.current_hp = min(heal_target.current_hp + heal_amount, heal_target.max_hp)
		_heal_accumulator -= heal_amount

func _process_converting(delta: float) -> void:
	if not is_instance_valid(conversion_target):
		conversion_target = null
		current_state = State.IDLE
		conversion_timer = 0.0
		return

	# Check if target is dead/destroyed
	if conversion_target is Unit and (conversion_target.is_dead or conversion_target.current_hp <= 0):
		conversion_target = null
		current_state = State.IDLE
		conversion_timer = 0.0
		return
	if conversion_target is Building and (conversion_target.is_destroyed or conversion_target.current_hp <= 0):
		conversion_target = null
		current_state = State.IDLE
		conversion_timer = 0.0
		return

	var distance = global_position.distance_to(conversion_target.global_position)

	if distance > conversion_range:
		# Move closer to target
		nav_agent.target_position = conversion_target.global_position
		var next_path_position = nav_agent.get_next_path_position()
		var direction = global_position.direction_to(next_path_position)
		_resume_movement()
		_apply_movement(direction * move_speed)
		# Don't increment conversion timer when out of range
		return

	# In range - attempt conversion
	_stop_and_stay()
	conversion_timer += delta

	# Conversion probability ramp: 0-4s = 0%, 4-10s = ~28%/sec, 10+ = guaranteed
	if conversion_timer < 4.0:
		return  # No chance yet

	if conversion_timer >= 10.0:
		# Guaranteed conversion
		_complete_conversion()
		return

	# 4-10s: probability ramp (~28% per second chance)
	# Apply target's conversion resistance
	var target_resistance = 0.0
	if conversion_target is Unit and "conversion_resistance" in conversion_target:
		target_resistance = conversion_target.conversion_resistance
	# Faith tech: adds 0.5 resistance to all units on enemy team
	if conversion_target is Unit and GameManager.has_tech("faith", conversion_target.team):
		target_resistance += 0.5

	var base_chance = 0.28 * delta  # ~28% per second
	var effective_chance = base_chance * (1.0 - target_resistance)
	if effective_chance > 0.0 and randf() < effective_chance:
		_complete_conversion()

func _complete_conversion() -> void:
	if not is_instance_valid(conversion_target):
		conversion_target = null
		current_state = State.IDLE
		conversion_timer = 0.0
		return

	var target = conversion_target

	# Change target team
	var old_team = target.team
	var new_team = team

	# Check if converting team has population space
	if target is Unit and not GameManager.can_add_population(new_team):
		# Pop-capped: unit is lost (AoE2 behavior)
		if target is Unit:
			target.die()
		conversion_target = null
		current_state = State.IDLE
		conversion_timer = 0.0
		_start_rejuvenation()
		return

	# Perform team change
	target.team = new_team

	# Re-apply team color
	if target.has_method("_apply_team_color"):
		target._apply_team_color()

	# Update population
	if target is Unit:
		GameManager.remove_population(1, old_team)
		GameManager.add_population(1, new_team)

	# Deselect from old owner if selected
	if target is Unit and target in GameManager.selected_units:
		GameManager.deselect_unit(target)

	# Re-apply tech bonuses for new team (recalculates from base stats)
	if target is Unit and target.has_method("apply_tech_bonuses"):
		target.apply_tech_bonuses()

	# Clear conversion state
	conversion_target = null
	current_state = State.IDLE
	conversion_timer = 0.0

	# Enter rejuvenation
	_start_rejuvenation()

func _start_rejuvenation() -> void:
	is_rejuvenating = true
	rejuvenation_timer = 0.0

## Check if a target can be converted
func can_convert(target: Node2D) -> bool:
	if not is_instance_valid(target):
		return false

	# Can't convert same team
	if "team" in target and target.team == team:
		return false

	# Buildings immune by default (unless has Redemption tech)
	if target is Building:
		if not GameManager.has_tech("redemption", team):
			return false
		# These building types are always immune
		if target.is_in_group("town_centers") or target.is_in_group("castles") \
			or target.is_in_group("monasteries") or target.is_in_group("farms") \
			or target.is_in_group("walls") or target.is_in_group("gates") \
			or target.is_in_group("wonders") or target.is_in_group("fish_traps"):
			return false
		return true

	# Monks immune (unless has Atonement tech)
	if target is Monk:
		if not GameManager.has_tech("atonement", team):
			return false
		return true

	# Units: villagers and non-siege military can be converted
	if target is Unit:
		return true

	return false

## Command this monk to convert an enemy
func command_convert(target: Node2D) -> void:
	if not can_convert(target):
		return
	if is_rejuvenating:
		return
	conversion_target = target
	heal_target = null
	current_state = State.CONVERTING
	conversion_timer = 0.0

## Command this monk to heal a friendly unit
func command_heal(target: Node2D) -> void:
	if not is_instance_valid(target) or not target is Unit:
		return
	if target.team != team:
		return
	if target.is_dead:
		return
	heal_target = target
	_heal_accumulator = 0.0
	conversion_target = null
	current_state = State.HEALING

func move_to(target_position: Vector2) -> void:
	heal_target = null
	conversion_target = null
	conversion_timer = 0.0
	current_state = State.MOVING
	nav_agent.target_position = target_position

func die() -> void:
	# Drop relic if carrying (Phase 6B)
	if carrying_relic and is_instance_valid(carrying_relic):
		if carrying_relic.has_method("drop"):
			carrying_relic.drop(global_position)
		carrying_relic = null
	super.die()

## Get status text for HUD display
func get_status_text() -> String:
	if is_rejuvenating:
		return "Rejuvenating"
	match current_state:
		State.IDLE:
			return "Idle"
		State.MOVING:
			return "Moving"
		State.HEALING:
			return "Healing"
		State.CONVERTING:
			return "Converting"
	return "Idle"
