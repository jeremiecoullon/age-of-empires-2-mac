extends Animal
class_name PelicanBicycle

## A rare Easter egg: a pelican riding a bicycle.
## Behaves like a sheep - herdable, can be claimed/stolen, provides food.

const OWNERSHIP_CHECK_INTERVAL: float = 0.5
const OWNERSHIP_RADIUS: float = 200.0

var ownership_timer: float = 0.0

func _ready() -> void:
	team = NEUTRAL_TEAM  # Start unowned
	food_amount = 85  # Slightly less than sheep (100)
	max_hp = 8
	current_hp = max_hp
	move_speed = 50.0  # Slightly faster than sheep (bicycle!)
	wander_range = 80.0  # Wanders a bit more
	wander_interval = 6.0
	is_aggressive = false

	super._ready()
	add_to_group("pelican_bicycles")
	_load_static_sprite("res://assets/sprites/units/pelican_bicycle.svg")

func _load_static_sprite(path: String) -> void:
	# Load a static SVG as a single-frame "idle" animation
	if not sprite:
		return

	var texture = load(path)
	if not texture:
		push_warning("Could not load sprite: " + path)
		return

	var sprite_frames = SpriteFrames.new()
	sprite_frames.remove_animation("default")
	sprite_frames.add_animation("idle")
	sprite_frames.set_animation_loop("idle", true)
	sprite_frames.set_animation_speed("idle", 1.0)
	sprite_frames.add_frame("idle", texture)

	sprite.sprite_frames = sprite_frames
	sprite.play("idle")

func _physics_process(delta: float) -> void:
	super._physics_process(delta)

	# Check for ownership changes (same as sheep)
	ownership_timer += delta
	if ownership_timer >= OWNERSHIP_CHECK_INTERVAL:
		ownership_timer = 0.0
		_check_ownership()

func _check_ownership() -> void:
	var units = get_tree().get_nodes_in_group("units")

	var nearest_by_team: Dictionary = {}
	var units_by_team: Dictionary = {}

	for unit in units:
		if unit == self:
			continue
		if unit is Animal:
			continue
		if unit.is_dead:
			continue

		var unit_team = unit.team
		if unit_team < 0:
			continue

		var dist = global_position.distance_to(unit.global_position)
		if dist > OWNERSHIP_RADIUS:
			continue

		if not nearest_by_team.has(unit_team) or dist < nearest_by_team[unit_team]:
			nearest_by_team[unit_team] = dist
			units_by_team[unit_team] = unit

	if nearest_by_team.is_empty():
		return

	# If neutral, claim by nearest unit
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

	# Check for stealing
	var friendly_nearby = nearest_by_team.has(team)
	var enemy_teams = nearest_by_team.keys().filter(func(t): return t != team)

	if not friendly_nearby and not enemy_teams.is_empty():
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
