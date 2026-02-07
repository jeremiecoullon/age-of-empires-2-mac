extends Unit
class_name TradeCart

enum State { IDLE, MOVING_TO_DESTINATION, TRADING, MOVING_TO_HOME }

# Trade Cart stats from AoE2 spec
const BASE_GOLD_PER_TILE: float = 0.46  # ~46 gold per 100 tiles one-way
const TRADE_TIME: float = 1.0  # Time to complete trade at market
const TILE_SIZE: float = 32.0  # Pixels per tile
const MARKET_ARRIVAL_DISTANCE: float = 60.0  # Distance in pixels to consider "arrived"
const MARKET_SEARCH_INTERVAL: float = 0.5  # Throttle expensive market searches

# Preload texture to avoid runtime file I/O
const TRADE_CART_TEXTURE: Texture2D = preload("res://assets/sprites/units/trade_cart.svg")

@export var home_market: Market = null  # Starting market
@export var destination_market: Market = null  # Target market

var current_state: State = State.IDLE
var trade_timer: float = 0.0
var last_trade_gold: int = 0  # Gold earned on last trade (for display)
var market_search_cooldown: float = 0.0  # Throttle market searches

func _ready() -> void:
	super._ready()
	add_to_group("trade_carts")
	max_hp = 70  # From AoE2 spec
	move_speed = 100.0  # Medium speed

	# Use single SVG for now (no 8-dir sprites available)
	_load_static_sprite(TRADE_CART_TEXTURE)

func _physics_process(delta: float) -> void:
	match current_state:
		State.IDLE:
			_stop_and_stay()
		State.MOVING_TO_DESTINATION:
			_process_moving_to_destination(delta)
		State.TRADING:
			_process_trading(delta)
		State.MOVING_TO_HOME:
			_process_moving_to_home(delta)

func _process_moving_to_destination(delta: float) -> void:
	if not _is_valid_market(destination_market):
		# Throttle expensive market searches
		market_search_cooldown -= delta
		if market_search_cooldown <= 0:
			market_search_cooldown = MARKET_SEARCH_INTERVAL
			_find_destination_market()
		if not _is_valid_market(destination_market):
			current_state = State.IDLE
			velocity = Vector2.ZERO
			return

	var distance = global_position.distance_to(destination_market.global_position)
	if distance < MARKET_ARRIVAL_DISTANCE:
		# Arrived at destination market
		current_state = State.TRADING
		velocity = Vector2.ZERO
		trade_timer = 0.0
		return

	# Navigate to destination market
	nav_agent.target_position = destination_market.global_position
	var next_path_position = nav_agent.get_next_path_position()
	var direction = global_position.direction_to(next_path_position)
	_resume_movement()
	_apply_movement(direction * move_speed)

func _process_trading(delta: float) -> void:
	trade_timer += delta
	if trade_timer >= TRADE_TIME:
		# Complete trade - generate gold based on distance
		_complete_trade()
		# Swap destination and home for return trip
		var temp = home_market
		home_market = destination_market
		destination_market = temp
		current_state = State.MOVING_TO_DESTINATION

func _process_moving_to_home(delta: float) -> void:
	# This state is now unused since we swap markets, but kept for clarity
	_process_moving_to_destination(delta)

func _complete_trade() -> void:
	if not _is_valid_market(home_market) or not _is_valid_market(destination_market):
		last_trade_gold = 0
		return

	# Calculate distance in tiles
	var distance_pixels = home_market.global_position.distance_to(destination_market.global_position)
	var distance_tiles = distance_pixels / TILE_SIZE

	# Gold earned scales with distance
	# AoE2 formula: roughly 46 gold per 100 tiles traveled
	var gold_earned = int(distance_tiles * BASE_GOLD_PER_TILE)
	gold_earned = max(gold_earned, 1)  # Minimum 1 gold

	GameManager.add_resource("gold", gold_earned, team)
	last_trade_gold = gold_earned

func _is_valid_market(market: Market) -> bool:
	return market != null and is_instance_valid(market) and not market.is_destroyed

func _find_destination_market() -> void:
	# Find the farthest friendly market (for maximum gold)
	var markets = get_tree().get_nodes_in_group("markets")
	var best_market: Market = null
	var best_distance: float = 0.0

	for market in markets:
		if market == home_market:
			continue
		if market.team != team:
			continue
		if market.is_destroyed:
			continue

		var dist = global_position.distance_to(market.global_position)
		if dist > best_distance:
			best_distance = dist
			best_market = market

	destination_market = best_market

func _find_any_market() -> Market:
	# Find nearest friendly market (for assigning home)
	var markets = get_tree().get_nodes_in_group("markets")
	var nearest: Market = null
	var nearest_dist: float = INF

	for market in markets:
		if market.team != team:
			continue
		if market.is_destroyed:
			continue

		var dist = global_position.distance_to(market.global_position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = market

	return nearest

# Commands
func command_trade(target_market: Market) -> void:
	# Set up trade route to specified market
	if not _is_valid_market(target_market):
		return

	if home_market == null:
		home_market = _find_any_market()

	destination_market = target_market
	current_state = State.MOVING_TO_DESTINATION

func command_trade_auto() -> void:
	# Start automatic trading - find best market pair
	if home_market == null:
		home_market = _find_any_market()

	if home_market == null:
		current_state = State.IDLE
		return

	_find_destination_market()

	if destination_market != null:
		current_state = State.MOVING_TO_DESTINATION
	else:
		current_state = State.IDLE

func move_to(target_position: Vector2) -> void:
	# Override to stop trading when moved manually
	destination_market = null
	current_state = State.IDLE
	super.move_to(target_position)

func get_trade_info() -> String:
	if current_state == State.IDLE:
		return "Idle"
	elif current_state == State.TRADING:
		return "Trading..."
	else:
		var dest_name = "None"
		if _is_valid_market(destination_market):
			dest_name = "Market"
		return "En route to " + dest_name + " (Last: +" + str(last_trade_gold) + "g)"
