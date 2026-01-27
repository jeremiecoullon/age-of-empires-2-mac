extends StaticBody2D
class_name ResourceNode

@export var resource_type: String = "wood"  # "wood" or "food"
@export var total_amount: int = 100
@export var gather_rate: float = 1.0  # per second

@onready var sprite: Sprite2D = $Sprite2D

var current_amount: int
var initial_scale: Vector2

signal depleted

func _ready() -> void:
	current_amount = total_amount
	initial_scale = sprite.scale if sprite else Vector2.ONE
	add_to_group("resources")
	add_to_group(resource_type + "_resources")

func harvest(amount: int) -> int:
	var harvested = min(amount, current_amount)
	current_amount -= harvested
	_update_visual()

	if current_amount <= 0:
		depleted.emit()
		queue_free()

	return harvested

func _update_visual() -> void:
	if sprite:
		var ratio = float(current_amount) / float(total_amount)
		# Scale down to minimum 50% when depleted
		var scale_factor = 0.5 + (ratio * 0.5)
		sprite.scale = initial_scale * scale_factor
		# Also fade slightly
		sprite.modulate.a = 0.6 + (ratio * 0.4)

func get_resource_type() -> String:
	return resource_type

func has_resources() -> bool:
	return current_amount > 0
