extends Building
class_name WatchTower

var tower_base_attack: int = 5
const TOWER_ATTACK_RANGE: float = 256.0  # 8 tiles
const TOWER_ATTACK_COOLDOWN: float = 2.0
const TOWER_MIN_RANGE: float = 32.0  # 1 tile - cannot attack adjacent units
var _attack_cooldown_timer: float = 0.0

func _ready() -> void:
	max_hp = 1020
	pierce_armor = 7
	building_name = "Watch Tower"
	size = Vector2i(1, 1)
	wood_cost = 25
	stone_cost = 125
	build_time = 80.0
	sight_range = 288.0  # 9 tiles
	garrison_capacity = 5
	garrison_adds_arrows = true
	super._ready()
	add_to_group("watch_towers")
	add_to_group("towers")

func _process(delta: float) -> void:
	if is_destroyed or not is_functional():
		return
	_process_tower_attack(delta)
	_process_garrison_healing(delta)

func _process_tower_attack(delta: float) -> void:
	_attack_cooldown_timer -= delta
	if _attack_cooldown_timer > 0:
		return

	var attack_range = TOWER_ATTACK_RANGE + GameManager.get_tech_bonus("archer_range", team) * 32.0
	var target = _find_attack_target(attack_range)
	if not target:
		_attack_cooldown_timer = 0.5  # Don't scan every frame when idle
		return

	var attack_damage = tower_base_attack + GameManager.get_tech_bonus("archer_attack", team) + get_garrison_arrow_bonus()
	target.take_damage(attack_damage, "pierce", 0, self)
	_attack_cooldown_timer = TOWER_ATTACK_COOLDOWN

func _find_attack_target(attack_range: float) -> Node:
	var nearest: Node = null
	var nearest_dist: float = attack_range

	for unit in get_tree().get_nodes_in_group("units"):
		if unit.team == team or unit.is_dead:
			continue
		if unit is Animal:
			continue
		var dist = global_position.distance_to(unit.global_position)
		# Minimum range check (Murder Holes removes this)
		if not GameManager.has_tech("murder_holes", team) and dist < TOWER_MIN_RANGE:
			continue
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = unit

	return nearest

func _destroy() -> void:
	if is_destroyed:
		return
	is_destroyed = true
	ungarrison_all()
	destroyed.emit()
	queue_free()
