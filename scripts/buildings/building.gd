extends StaticBody2D
class_name Building

const PLAYER_COLOR = Color(0.3, 0.5, 0.9, 1)  # Blue
const AI_COLOR = Color(0.9, 0.2, 0.2, 1)  # Red
const CONSTRUCTION_COLOR_MULT = Color(0.6, 0.6, 0.6, 0.8)  # Dim during construction

@export var building_name: String = "Building"
@export var size: Vector2i = Vector2i(2, 2)  # in tiles
@export var wood_cost: int = 0
@export var food_cost: int = 0
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
	if current_hp <= 0:
		_destroy()

func _destroy() -> void:
	if is_destroyed:
		return
	is_destroyed = true
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
	builders = builders.filter(func(b): return is_instance_valid(b))
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
