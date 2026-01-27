extends StaticBody2D
class_name Building

const PLAYER_COLOR = Color(0.3, 0.5, 0.9, 1)  # Blue
const AI_COLOR = Color(0.9, 0.2, 0.2, 1)  # Red

@export var building_name: String = "Building"
@export var size: Vector2i = Vector2i(2, 2)  # in tiles
@export var wood_cost: int = 0
@export var food_cost: int = 0
@export var team: int = 0  # 0 = player, 1 = AI
@export var max_hp: int = 200
# Resource types this building accepts for drop-off (empty = not a drop-off point)
@export var accepts_resources: Array[String] = []

var current_hp: int
var is_constructed: bool = true
var is_destroyed: bool = false

signal destroyed

func _ready() -> void:
	add_to_group("buildings")
	current_hp = max_hp
	# Apply team color after a frame to ensure sprite is ready
	call_deferred("_apply_team_color")

func _apply_team_color() -> void:
	if has_node("Sprite2D"):
		var sprite = get_node("Sprite2D")
		if team == 0:
			sprite.modulate = PLAYER_COLOR
		else:
			sprite.modulate = AI_COLOR

func get_building_name() -> String:
	return building_name

func is_drop_off_for(resource_type: String) -> bool:
	return accepts_resources.has(resource_type)

func take_damage(amount: int) -> void:
	current_hp -= amount
	if current_hp <= 0:
		_destroy()

func _destroy() -> void:
	if is_destroyed:
		return
	is_destroyed = true
	destroyed.emit()
	queue_free()
