extends Unit
class_name Spearman

## Spearman - cheap anti-cavalry infantry.
## AoE2 spec: 35F + 25W cost, 45 HP, 3 attack, 0/0 armor, +15 bonus vs cavalry

enum State { IDLE, MOVING, ATTACKING }

@export var attack_damage: int = 3
@export var attack_range: float = 30.0
@export var attack_cooldown: float = 2.0
@export var bonus_vs_cavalry: int = 15  # Extra damage vs cavalry group

const SPEARMAN_TEXTURE: Texture2D = preload("res://assets/sprites/units/spearman.svg")

var current_state: State = State.IDLE
var attack_target: Node2D = null  # Can be Unit or Building
var attack_timer: float = 0.0

func _ready() -> void:
	super._ready()
	add_to_group("military")
	add_to_group("infantry")
	max_hp = 45
	current_hp = max_hp
	move_speed = 96.0  # Same as archer, slower than militia
	melee_armor = 0
	pierce_armor = 0
	if SPEARMAN_TEXTURE:
		_load_static_sprite(SPEARMAN_TEXTURE)

func _load_static_sprite(texture: Texture2D) -> void:
	if not sprite or not texture:
		return
	var sprite_frames = SpriteFrames.new()
	sprite_frames.remove_animation("default")
	sprite_frames.add_animation("idle")
	sprite_frames.set_animation_loop("idle", true)
	sprite_frames.add_frame("idle", texture)
	sprite.sprite_frames = sprite_frames
	sprite.play("idle")
	sprite.scale = Vector2(0.5, 0.5)  # Scale down 64px SVG

func _physics_process(delta: float) -> void:
	match current_state:
		State.IDLE:
			velocity = Vector2.ZERO
		State.MOVING:
			_process_moving(delta)
		State.ATTACKING:
			_process_attacking(delta)

func _process_moving(delta: float) -> void:
	if nav_agent.is_navigation_finished():
		current_state = State.IDLE
		velocity = Vector2.ZERO
		return

	var next_path_position = nav_agent.get_next_path_position()
	var direction = global_position.direction_to(next_path_position)
	velocity = direction * move_speed
	move_and_slide()
	_update_facing_direction()

func _process_attacking(delta: float) -> void:
	if not is_instance_valid(attack_target):
		attack_target = null
		current_state = State.IDLE
		return

	# Check if target is dead/destroyed
	if attack_target is Unit:
		if attack_target.is_dead or attack_target.current_hp <= 0:
			attack_target = null
			current_state = State.IDLE
			return
	elif attack_target is Building:
		if attack_target.is_destroyed or attack_target.current_hp <= 0:
			attack_target = null
			current_state = State.IDLE
			return

	var distance = global_position.distance_to(attack_target.global_position)

	if distance > attack_range:
		# Move closer to target using nav_agent
		nav_agent.target_position = attack_target.global_position
		var next_path_position = nav_agent.get_next_path_position()
		var direction = global_position.direction_to(next_path_position)
		velocity = direction * move_speed
		move_and_slide()
		_update_facing_direction()
		return

	# In range, stop and attack
	velocity = Vector2.ZERO
	attack_timer += delta

	if attack_timer >= attack_cooldown:
		attack_timer = 0.0
		_deal_damage()

func _deal_damage() -> void:
	if not is_instance_valid(attack_target):
		return

	var bonus = 0
	# Apply bonus damage vs cavalry
	if attack_target is Unit and attack_target.is_in_group("cavalry"):
		bonus = bonus_vs_cavalry

	attack_target.take_damage(attack_damage, "melee", bonus)

func command_attack(target: Node2D) -> void:
	attack_target = target
	current_state = State.ATTACKING
	attack_timer = 0.0

func move_to(target_position: Vector2) -> void:
	attack_target = null
	current_state = State.MOVING
	nav_agent.target_position = target_position
