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
@export var melee_armor: int = 0  # Reduces melee damage (most buildings have 0)
@export var pierce_armor: int = 0  # Reduces pierce damage (most buildings have 0)
# Resource types this building accepts for drop-off (empty = not a drop-off point)
@export var accepts_resources: Array[String] = []
@export var sight_range: float = 192.0  # How far building reveals fog (~6 tiles)

var current_hp: int
var is_constructed: bool = true
var is_destroyed: bool = false

signal destroyed
signal damaged(amount: int, attacker: Node2D)  # Emitted when building takes damage

func _ready() -> void:
	add_to_group("buildings")
	current_hp = max_hp
	# Apply team color after a frame to ensure sprite is ready
	call_deferred("_apply_team_color")
	# Connect to attack notification system
	damaged.connect(_on_damaged_for_notification)

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
