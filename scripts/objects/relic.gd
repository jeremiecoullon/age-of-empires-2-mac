extends StaticBody2D
class_name Relic

## Relic object — can be picked up by monks, garrisoned in monasteries for gold.
## Relics are indestructible and cannot be interacted with by villagers.

var is_carried: bool = false
var carrier: Node = null
var is_garrisoned: bool = false
var garrison_building: Node = null

func _ready() -> void:
	add_to_group("relics")

func pickup(monk: Node) -> void:
	is_carried = true
	carrier = monk
	is_garrisoned = false
	garrison_building = null
	visible = false

func drop(drop_position: Vector2) -> void:
	is_carried = false
	carrier = null
	is_garrisoned = false
	garrison_building = null
	global_position = drop_position
	visible = true

func garrison(monastery: Node) -> void:
	is_carried = false
	carrier = null
	is_garrisoned = true
	garrison_building = monastery
	visible = false

func ungarrison(drop_position: Vector2) -> void:
	is_garrisoned = false
	garrison_building = null
	global_position = drop_position
	visible = true
