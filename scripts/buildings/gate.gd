extends Building
class_name Gate

const SCAN_INTERVAL: float = 0.3  # Seconds between unit proximity scans
const OPEN_RADIUS: float = 64.0  # 2 tiles — scan range for auto-open

var is_locked: bool = false
var is_open: bool = false
var _scan_accumulator: float = 0.0

func _ready() -> void:
	max_hp = 2750
	melee_armor = 6
	pierce_armor = 6
	super._ready()
	add_to_group("gates")
	add_to_group("walls")
	building_name = "Gate"
	size = Vector2i(1, 1)
	stone_cost = 30
	build_time = 70.0
	sight_range = 96.0  # 3 tiles

func _process(delta: float) -> void:
	if is_destroyed:
		return
	if not is_functional():
		return

	_scan_accumulator += delta
	if _scan_accumulator < SCAN_INTERVAL:
		return
	_scan_accumulator = 0.0

	_update_gate_state()

func _update_gate_state() -> void:
	if is_locked:
		if is_open:
			_close_gate()
		return

	# Check for friendly units nearby
	var friendly_nearby = false
	for unit in get_tree().get_nodes_in_group("units"):
		if unit.team != team:
			continue
		if unit.is_dead:
			continue
		if global_position.distance_to(unit.global_position) <= OPEN_RADIUS:
			friendly_nearby = true
			break

	if friendly_nearby and not is_open:
		_open_gate()
	elif not friendly_nearby and is_open:
		_close_gate()

func _open_gate() -> void:
	is_open = true
	var collision = get_node_or_null("CollisionShape2D")
	if collision:
		collision.set_deferred("disabled", true)
	# Visual feedback: make gate semi-transparent when open
	if has_node("Sprite2D"):
		get_node("Sprite2D").modulate.a = 0.5

func _close_gate() -> void:
	is_open = false
	var collision = get_node_or_null("CollisionShape2D")
	if collision:
		collision.set_deferred("disabled", false)
	# Restore full opacity
	if has_node("Sprite2D"):
		get_node("Sprite2D").modulate.a = 1.0

func toggle_lock() -> void:
	is_locked = not is_locked
	if is_locked and is_open:
		_close_gate()
