extends Camera2D

@export var pan_speed: float = 400.0
@export var edge_margin: int = 20  # pixels from screen edge to trigger scroll

var map_size: Vector2 = Vector2(1920, 1920)
var viewport_size: Vector2

func _ready() -> void:
	viewport_size = get_viewport_rect().size
	# Start camera centered on town center area
	position = Vector2(480, 480)

func _process(delta: float) -> void:
	var direction = Vector2.ZERO

	# Keyboard panning (WASD and arrow keys)
	if Input.is_action_pressed("ui_left") or Input.is_key_pressed(KEY_A):
		direction.x -= 1
	if Input.is_action_pressed("ui_right") or Input.is_key_pressed(KEY_D):
		direction.x += 1
	if Input.is_action_pressed("ui_up") or Input.is_key_pressed(KEY_W):
		direction.y -= 1
	if Input.is_action_pressed("ui_down") or Input.is_key_pressed(KEY_S):
		direction.y += 1

	# Edge scrolling
	var mouse_pos = get_viewport().get_mouse_position()
	if mouse_pos.x < edge_margin:
		direction.x -= 1
	elif mouse_pos.x > viewport_size.x - edge_margin:
		direction.x += 1
	if mouse_pos.y < edge_margin:
		direction.y -= 1
	elif mouse_pos.y > viewport_size.y - edge_margin:
		direction.y += 1

	# Apply movement
	if direction != Vector2.ZERO:
		position += direction.normalized() * pan_speed * delta
		_clamp_position()

func _clamp_position() -> void:
	var half_viewport = viewport_size / 2
	position.x = clamp(position.x, half_viewport.x, map_size.x - half_viewport.x)
	position.y = clamp(position.y, half_viewport.y, map_size.y - half_viewport.y)


## Jump camera to a specific world position (used by minimap click)
func jump_to(world_pos: Vector2) -> void:
	position = world_pos
	_clamp_position()
