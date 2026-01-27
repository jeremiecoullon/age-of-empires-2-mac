extends CharacterBody2D
class_name Unit

const PLAYER_COLOR = Color(0.3, 0.5, 0.9, 1)  # Blue
const AI_COLOR = Color(0.9, 0.2, 0.2, 1)  # Red

@export var move_speed: float = 100.0
@export var max_hp: int = 100
@export var team: int = 0  # 0 = player, 1 = AI

@onready var nav_agent: NavigationAgent2D = $NavigationAgent2D
@onready var sprite: Sprite2D = $Sprite2D
@onready var selection_indicator: Sprite2D = $SelectionIndicator

var is_selected: bool = false
var current_hp: int
var is_dead: bool = false

signal died

func _ready() -> void:
	add_to_group("units")
	current_hp = max_hp
	nav_agent.path_desired_distance = 4.0
	nav_agent.target_desired_distance = 4.0
	selection_indicator.visible = false
	_apply_team_color()

func _apply_team_color() -> void:
	if sprite:
		if team == 0:
			sprite.modulate = PLAYER_COLOR
		else:
			sprite.modulate = AI_COLOR

func _physics_process(delta: float) -> void:
	if nav_agent.is_navigation_finished():
		return

	var current_position = global_position
	var next_path_position = nav_agent.get_next_path_position()
	var direction = current_position.direction_to(next_path_position)

	velocity = direction * move_speed
	move_and_slide()

func move_to(target_position: Vector2) -> void:
	nav_agent.target_position = target_position

func set_selected(selected: bool) -> void:
	is_selected = selected
	selection_indicator.visible = selected

func stop_movement() -> void:
	nav_agent.target_position = global_position

func take_damage(amount: int) -> void:
	current_hp -= amount
	if current_hp <= 0:
		die()

func die() -> void:
	if is_dead:
		return  # Prevent double-death
	is_dead = true
	died.emit()
	if is_selected:
		GameManager.deselect_unit(self)
	if team == 0:
		GameManager.remove_population(1)
	else:
		GameManager.ai_remove_population(1)
	queue_free()
