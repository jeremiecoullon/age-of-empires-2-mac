extends Node
## Victory Tests - Tests for win/lose conditions
##
## These tests verify:
## - Player wins when enemy TC is destroyed
## - Player loses when their TC is destroyed
## - game_over signal is emitted with correct winner
## - game_ended flag is set correctly

class_name TestVictory

var runner: TestRunner


func _init(test_runner: TestRunner) -> void:
	runner = test_runner


func get_all_tests() -> Array[Callable]:
	## Returns all test methods to run
	return [
		test_player_wins_when_ai_tc_destroyed,
		test_player_loses_when_tc_destroyed,
		test_game_over_signal_emits_player_wins,
		test_game_over_signal_emits_ai_wins,
		test_game_ended_flag_set,
		test_no_victory_if_both_tcs_exist,
	]


func test_player_wins_when_ai_tc_destroyed() -> Assertions.AssertResult:
	## Destroying enemy TC should trigger player victory
	GameManager.game_ended = false

	# Spawn both TCs
	var player_tc = runner.spawner.spawn_town_center(Vector2(400, 400), 0)
	var ai_tc = runner.spawner.spawn_town_center(Vector2(600, 400), 1)
	await runner.wait_frames(2)

	# Destroy AI TC
	ai_tc.take_damage(ai_tc.current_hp)
	# Need more frames for deferred check_victory and queue_free to process
	await runner.wait_frames(10)

	if not GameManager.game_ended:
		return Assertions.AssertResult.new(false,
			"game_ended should be true after TC destroyed")

	return Assertions.AssertResult.new(true)


func test_player_loses_when_tc_destroyed() -> Assertions.AssertResult:
	## Losing player TC should trigger AI victory
	GameManager.game_ended = false

	var player_tc = runner.spawner.spawn_town_center(Vector2(400, 400), 0)
	var ai_tc = runner.spawner.spawn_town_center(Vector2(600, 400), 1)
	await runner.wait_frames(2)

	# Destroy player TC
	player_tc.take_damage(player_tc.current_hp)
	# Need more frames for deferred check_victory and queue_free to process
	await runner.wait_frames(10)

	if not GameManager.game_ended:
		return Assertions.AssertResult.new(false,
			"game_ended should be true after player TC destroyed")

	return Assertions.AssertResult.new(true)


func test_game_over_signal_emits_player_wins() -> Assertions.AssertResult:
	## game_over signal should emit with winner=0 when player wins
	GameManager.game_ended = false

	var player_tc = runner.spawner.spawn_town_center(Vector2(400, 400), 0)
	var ai_tc = runner.spawner.spawn_town_center(Vector2(600, 400), 1)
	await runner.wait_frames(2)

	# Use array to capture by reference
	var signal_winner = [-1]
	var callback = func(winner): signal_winner[0] = winner
	GameManager.game_over.connect(callback)

	# Destroy AI TC
	ai_tc.take_damage(ai_tc.current_hp)
	# Need more frames for deferred check_victory and queue_free to process
	await runner.wait_frames(10)

	# Cleanup signal connection
	if GameManager.game_over.is_connected(callback):
		GameManager.game_over.disconnect(callback)

	if signal_winner[0] != 0:
		return Assertions.AssertResult.new(false,
			"game_over signal should emit winner=0 (player), got: %d" % signal_winner[0])

	return Assertions.AssertResult.new(true)


func test_game_over_signal_emits_ai_wins() -> Assertions.AssertResult:
	## game_over signal should emit with winner=1 when AI wins
	GameManager.game_ended = false

	var player_tc = runner.spawner.spawn_town_center(Vector2(400, 400), 0)
	var ai_tc = runner.spawner.spawn_town_center(Vector2(600, 400), 1)
	await runner.wait_frames(2)

	# Use array to capture by reference
	var signal_winner = [-1]
	var callback = func(winner): signal_winner[0] = winner
	GameManager.game_over.connect(callback)

	# Destroy player TC
	player_tc.take_damage(player_tc.current_hp)
	# Need more frames for deferred check_victory and queue_free to process
	await runner.wait_frames(10)

	# Cleanup signal connection
	if GameManager.game_over.is_connected(callback):
		GameManager.game_over.disconnect(callback)

	if signal_winner[0] != 1:
		return Assertions.AssertResult.new(false,
			"game_over signal should emit winner=1 (AI), got: %d" % signal_winner[0])

	return Assertions.AssertResult.new(true)


func test_game_ended_flag_set() -> Assertions.AssertResult:
	## game_ended flag should be set to true after victory/defeat
	GameManager.game_ended = false

	var player_tc = runner.spawner.spawn_town_center(Vector2(400, 400), 0)
	var ai_tc = runner.spawner.spawn_town_center(Vector2(600, 400), 1)
	await runner.wait_frames(2)

	if GameManager.game_ended:
		return Assertions.AssertResult.new(false,
			"game_ended should be false before any TC destroyed")

	ai_tc.take_damage(ai_tc.current_hp)
	# Need more frames for deferred check_victory and queue_free to process
	await runner.wait_frames(10)

	if not GameManager.game_ended:
		return Assertions.AssertResult.new(false,
			"game_ended should be true after TC destroyed")

	return Assertions.AssertResult.new(true)


func test_no_victory_if_both_tcs_exist() -> Assertions.AssertResult:
	## No victory should occur if both TCs are alive
	GameManager.game_ended = false

	var player_tc = runner.spawner.spawn_town_center(Vector2(400, 400), 0)
	var ai_tc = runner.spawner.spawn_town_center(Vector2(600, 400), 1)
	await runner.wait_frames(2)

	# Damage but don't destroy
	ai_tc.take_damage(100)
	await runner.wait_frames(2)

	# Manually trigger check_victory
	GameManager.check_victory()
	await runner.wait_frames(2)

	if GameManager.game_ended:
		return Assertions.AssertResult.new(false,
			"game_ended should be false if both TCs still exist")

	return Assertions.AssertResult.new(true)
