extends Animal
class_name Sheep

## Sheep are herdable animals that can be claimed by the first player/AI to spot them.
## They can be "stolen" if an enemy unit sees them without a friendly unit nearby.

const OWNERSHIP_CHECK_INTERVAL: float = 0.5  # How often to check for ownership changes
const OWNERSHIP_RADIUS: float = 200.0  # Range for ownership detection

var ownership_timer: float = 0.0

func _ready() -> void:
	team = NEUTRAL_TEAM  # Start unowned
	food_amount = 100
	max_hp = 7
	current_hp = max_hp
	move_speed = 40.0  # Slow movement
	wander_range = 60.0  # Don't wander far
	wander_interval = 8.0
	is_aggressive = false

	super._ready()
	add_to_group("sheep")
	# 45 frames total, 8 directions = ~5-6 frames per direction
	_load_directional_animations("res://assets/sprites/units/sheep_frames", "Sheepstand", 45)

func _physics_process(delta: float) -> void:
	super._physics_process(delta)

	# Check for ownership changes
	ownership_timer += delta
	if ownership_timer >= OWNERSHIP_CHECK_INTERVAL:
		ownership_timer = 0.0
		_check_ownership()

func _check_ownership() -> void:
	var units = get_tree().get_nodes_in_group("units")

	# Find nearest unit of each team within range
	var nearest_by_team: Dictionary = {}  # team -> distance
	var units_by_team: Dictionary = {}  # team -> unit

	for unit in units:
		if unit == self:
			continue
		if unit is Animal:
			continue  # Ignore other animals
		if unit.is_dead:
			continue

		var unit_team = unit.team
		if unit_team < 0:
			continue  # Ignore neutral units

		var dist = global_position.distance_to(unit.global_position)
		if dist > OWNERSHIP_RADIUS:
			continue

		if not nearest_by_team.has(unit_team) or dist < nearest_by_team[unit_team]:
			nearest_by_team[unit_team] = dist
			units_by_team[unit_team] = unit

	if nearest_by_team.is_empty():
		return  # No units nearby, keep current owner

	# If currently neutral, claim by nearest unit
	if team == NEUTRAL_TEAM:
		var nearest_team = -1
		var nearest_dist = INF
		for t in nearest_by_team:
			if nearest_by_team[t] < nearest_dist:
				nearest_dist = nearest_by_team[t]
				nearest_team = t

		if nearest_team >= 0:
			_set_owner(nearest_team)
		return

	# Check for stealing: if enemy is closer AND no friendly nearby
	var friendly_nearby = nearest_by_team.has(team)
	var enemy_teams = nearest_by_team.keys().filter(func(t): return t != team)

	if not friendly_nearby and not enemy_teams.is_empty():
		# Find closest enemy
		var closest_enemy_team = -1
		var closest_enemy_dist = INF
		for t in enemy_teams:
			if nearest_by_team[t] < closest_enemy_dist:
				closest_enemy_dist = nearest_by_team[t]
				closest_enemy_team = t

		if closest_enemy_team >= 0:
			_set_owner(closest_enemy_team)

func _set_owner(new_team: int) -> void:
	if team == new_team:
		return

	team = new_team
	_apply_team_color()
