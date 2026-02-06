extends Node
## Bugfix Tests - Regression tests for specific bug fixes
##
## Bug 1: Sheep hunting should not trigger "under attack" notification
## Bug 2: Population cap should be enforced at spawn time, not just queue time
## Bug 4: Units should not fly to (0,0) on spawn

class_name TestBugfixes

var runner: TestRunner


func _init(test_runner: TestRunner) -> void:
	runner = test_runner


func get_all_tests() -> Array[Callable]:
	return [
		# Bug 1: Friendly fire notification
		test_friendly_damage_does_not_trigger_attack_notification,
		test_enemy_damage_triggers_attack_notification,
		test_friendly_building_damage_does_not_notify,
		# Bug 2: Pop cap at spawn time
		test_tc_pauses_when_pop_cap_reached_at_spawn,
		test_barracks_pauses_when_pop_cap_reached_at_spawn,
		test_archery_range_pauses_when_pop_cap_reached_at_spawn,
		test_stable_pauses_when_pop_cap_reached_at_spawn,
		test_tc_resumes_spawn_when_pop_frees,
		test_pop_cap_does_not_drain_queue,
		# Bug 4: Nav agent initialization
		test_unit_stays_in_place_on_spawn,
		test_militia_stays_in_place_on_spawn,
		test_two_villagers_at_same_spot_stay_in_place,
	]


# === Bug 1: Friendly fire notification ===

func test_friendly_damage_does_not_trigger_attack_notification() -> Assertions.AssertResult:
	## Damage from same-team unit (e.g. villager hunting sheep) should NOT trigger attack notification
	var villager = runner.spawner.spawn_villager(Vector2(400, 400))
	var sheep = runner.spawner.spawn_sheep(Vector2(430, 400), 0)  # Player-owned sheep
	await runner.wait_frames(2)

	var signal_received = [false]
	GameManager.player_under_attack.connect(func(_type): signal_received[0] = true)

	# Reset cooldown so notification isn't throttled
	GameManager._last_civilian_attack_time = -GameManager.ATTACK_NOTIFY_COOLDOWN

	# Simulate villager damaging own sheep (friendly fire)
	GameManager.notify_unit_damaged(sheep, 5, villager)

	if signal_received[0]:
		return Assertions.AssertResult.new(false,
			"Friendly fire should NOT trigger attack notification")

	# Disconnect to avoid affecting other tests
	for conn in GameManager.player_under_attack.get_connections():
		GameManager.player_under_attack.disconnect(conn["callable"])

	return Assertions.AssertResult.new(true)


func test_enemy_damage_triggers_attack_notification() -> Assertions.AssertResult:
	## Damage from enemy unit SHOULD trigger attack notification
	var player_villager = runner.spawner.spawn_villager(Vector2(400, 400), 0)
	var enemy_militia = runner.spawner.spawn_militia(Vector2(430, 400), 1)
	await runner.wait_frames(2)

	var signal_received = [false]
	GameManager.player_under_attack.connect(func(_type): signal_received[0] = true)

	# Reset cooldown
	GameManager._last_civilian_attack_time = -GameManager.ATTACK_NOTIFY_COOLDOWN

	# Enemy attacks player villager
	GameManager.notify_unit_damaged(player_villager, 5, enemy_militia)

	if not signal_received[0]:
		return Assertions.AssertResult.new(false,
			"Enemy damage SHOULD trigger attack notification")

	for conn in GameManager.player_under_attack.get_connections():
		GameManager.player_under_attack.disconnect(conn["callable"])

	return Assertions.AssertResult.new(true)


func test_friendly_building_damage_does_not_notify() -> Assertions.AssertResult:
	## Same-team damage to a building should NOT trigger notification
	var house = runner.spawner.spawn_house(Vector2(400, 400), 0)
	var villager = runner.spawner.spawn_villager(Vector2(430, 400), 0)
	await runner.wait_frames(2)

	var signal_received = [false]
	GameManager.player_under_attack.connect(func(_type): signal_received[0] = true)

	GameManager._last_civilian_attack_time = -GameManager.ATTACK_NOTIFY_COOLDOWN

	GameManager.notify_building_damaged(house, 5, villager)

	if signal_received[0]:
		return Assertions.AssertResult.new(false,
			"Friendly building damage should NOT trigger notification")

	for conn in GameManager.player_under_attack.get_connections():
		GameManager.player_under_attack.disconnect(conn["callable"])

	return Assertions.AssertResult.new(true)


# === Bug 2: Pop cap at spawn time (pauses training, doesn't drain queue) ===

func test_tc_pauses_when_pop_cap_reached_at_spawn() -> Assertions.AssertResult:
	## TC should pause training (not spawn) when pop cap full at spawn time
	var tc = runner.spawner.spawn_town_center(Vector2(400, 400))
	await runner.wait_frames(2)

	GameManager.resources["food"] = 500
	GameManager.population = 0
	GameManager.population_cap = 10

	tc.train_villager()
	var food_after_queue = GameManager.get_resource("food")

	# Fill population to cap AFTER queueing
	GameManager.population = 10

	# Fast-forward training to completion
	tc.train_timer = TownCenter.TRAIN_TIME
	tc._process(0.01)
	await runner.wait_frames(2)

	# Resources should NOT be refunded (unit stays in queue, paused)
	var food_after = GameManager.get_resource("food")
	if food_after != food_after_queue:
		return Assertions.AssertResult.new(false,
			"Food should stay the same (paused, not refunded). Expected: %d, Got: %d" % [
				food_after_queue, food_after])

	# Population should not have increased
	if GameManager.population != 10:
		return Assertions.AssertResult.new(false,
			"Population should stay at cap (10), got: %d" % GameManager.population)

	# Unit should still be in queue
	if tc.get_queue_size() != 1:
		return Assertions.AssertResult.new(false,
			"Queue should still have 1 item (paused), got: %d" % tc.get_queue_size())

	return Assertions.AssertResult.new(true)


func test_barracks_pauses_when_pop_cap_reached_at_spawn() -> Assertions.AssertResult:
	## Barracks should pause training when pop cap full at spawn time
	var barracks = runner.spawner.spawn_barracks(Vector2(400, 400))
	await runner.wait_frames(2)

	GameManager.resources["food"] = 500
	GameManager.resources["wood"] = 500
	GameManager.population = 0
	GameManager.population_cap = 10

	barracks.train_militia()
	var food_after = GameManager.get_resource("food")
	var wood_after = GameManager.get_resource("wood")

	GameManager.population = 10

	barracks.train_timer = Barracks.MILITIA_TRAIN_TIME
	barracks._process(0.01)
	await runner.wait_frames(2)

	# Resources should NOT change (paused)
	if GameManager.get_resource("food") != food_after:
		return Assertions.AssertResult.new(false,
			"Food should not change when paused")

	if GameManager.get_resource("wood") != wood_after:
		return Assertions.AssertResult.new(false,
			"Wood should not change when paused")

	# Unit still in queue
	if barracks.get_queue_size() != 1:
		return Assertions.AssertResult.new(false,
			"Queue should still have 1 item, got: %d" % barracks.get_queue_size())

	return Assertions.AssertResult.new(true)


func test_archery_range_pauses_when_pop_cap_reached_at_spawn() -> Assertions.AssertResult:
	## Archery Range should pause training when pop cap full at spawn
	var ar = runner.spawner.spawn_archery_range(Vector2(400, 400))
	await runner.wait_frames(2)

	GameManager.resources["wood"] = 500
	GameManager.resources["gold"] = 500
	GameManager.population = 0
	GameManager.population_cap = 10

	ar.train_archer()

	GameManager.population = 10

	ar.train_timer = ArcheryRange.ARCHER_TRAIN_TIME
	ar._process(0.01)
	await runner.wait_frames(2)

	if ar.get_queue_size() != 1:
		return Assertions.AssertResult.new(false,
			"Queue should still have 1 item (paused), got: %d" % ar.get_queue_size())

	return Assertions.AssertResult.new(true)


func test_stable_pauses_when_pop_cap_reached_at_spawn() -> Assertions.AssertResult:
	## Stable should pause training when pop cap full at spawn
	var stable = runner.spawner.spawn_stable(Vector2(400, 400))
	await runner.wait_frames(2)

	GameManager.resources["food"] = 500
	GameManager.population = 0
	GameManager.population_cap = 10

	stable.train_scout_cavalry()

	GameManager.population = 10

	stable.train_timer = Stable.SCOUT_CAVALRY_TRAIN_TIME
	stable._process(0.01)
	await runner.wait_frames(2)

	if stable.get_queue_size() != 1:
		return Assertions.AssertResult.new(false,
			"Queue should still have 1 item (paused), got: %d" % stable.get_queue_size())

	return Assertions.AssertResult.new(true)


func test_tc_resumes_spawn_when_pop_frees() -> Assertions.AssertResult:
	## When pop cap frees up, paused training should resume and spawn the unit
	var tc = runner.spawner.spawn_town_center(Vector2(400, 400))
	await runner.wait_frames(2)

	GameManager.resources["food"] = 500
	GameManager.population = 9
	GameManager.population_cap = 10

	tc.train_villager()

	# Fill pop cap
	GameManager.population = 10

	# Training completes but can't spawn (paused)
	tc.train_timer = TownCenter.TRAIN_TIME
	tc._process(0.01)
	await runner.wait_frames(2)

	if tc.get_queue_size() != 1:
		return Assertions.AssertResult.new(false,
			"Should still have 1 queued after pause, got: %d" % tc.get_queue_size())

	# Free up population (simulate unit dying)
	GameManager.population = 9

	# Next frame should spawn
	tc._process(0.01)
	await runner.wait_frames(2)

	if tc.get_queue_size() != 0:
		return Assertions.AssertResult.new(false,
			"Queue should be empty after pop freed, got: %d" % tc.get_queue_size())

	if GameManager.population != 10:
		return Assertions.AssertResult.new(false,
			"Population should be 10 after spawn, got: %d" % GameManager.population)

	return Assertions.AssertResult.new(true)


func test_pop_cap_does_not_drain_queue() -> Assertions.AssertResult:
	## Multiple queued units should NOT all drain when pop-capped
	var tc = runner.spawner.spawn_town_center(Vector2(400, 400))
	await runner.wait_frames(2)

	GameManager.resources["food"] = 500
	GameManager.population = 0
	GameManager.population_cap = 10

	# Queue 3 villagers
	tc.train_villager()
	tc.train_villager()
	tc.train_villager()

	# Fill pop cap
	GameManager.population = 10

	# Complete training
	tc.train_timer = TownCenter.TRAIN_TIME
	tc._process(0.01)
	await runner.wait_frames(2)

	# All 3 should still be in queue (paused, not drained)
	if tc.get_queue_size() != 3:
		return Assertions.AssertResult.new(false,
			"All 3 units should remain in queue when pop-capped, got: %d" % tc.get_queue_size())

	return Assertions.AssertResult.new(true)


# === Bug 4: Nav agent initialization ===

func test_unit_stays_in_place_on_spawn() -> Assertions.AssertResult:
	## A newly spawned unit should not move from its spawn position
	var spawn_pos = Vector2(400, 400)
	var villager = runner.spawner.spawn_villager(spawn_pos)
	await runner.wait_frames(5)  # Give enough frames for any errant movement

	var distance_moved = villager.global_position.distance_to(spawn_pos)

	if distance_moved > 10.0:
		return Assertions.AssertResult.new(false,
			"Villager should stay near spawn position. Moved: %.1f pixels" % distance_moved)

	return Assertions.AssertResult.new(true)


func test_militia_stays_in_place_on_spawn() -> Assertions.AssertResult:
	## A newly spawned militia should not move from its spawn position
	var spawn_pos = Vector2(500, 500)
	var militia = runner.spawner.spawn_militia(spawn_pos)
	await runner.wait_frames(5)

	var distance_moved = militia.global_position.distance_to(spawn_pos)

	if distance_moved > 10.0:
		return Assertions.AssertResult.new(false,
			"Militia should stay near spawn position. Moved: %.1f pixels" % distance_moved)

	return Assertions.AssertResult.new(true)


func test_two_villagers_at_same_spot_stay_in_place() -> Assertions.AssertResult:
	## Two villagers spawned at the same position should not push each other away (avoidance bug)
	var spawn_pos = Vector2(400, 400)
	var v1 = runner.spawner.spawn_villager(spawn_pos)
	await runner.wait_frames(3)
	var v2 = runner.spawner.spawn_villager(spawn_pos)
	await runner.wait_frames(5)

	var dist_v1 = v1.global_position.distance_to(spawn_pos)
	var dist_v2 = v2.global_position.distance_to(spawn_pos)

	if dist_v1 > 10.0:
		return Assertions.AssertResult.new(false,
			"First villager should stay near spawn. Moved: %.1f pixels" % dist_v1)

	if dist_v2 > 10.0:
		return Assertions.AssertResult.new(false,
			"Second villager should stay near spawn. Moved: %.1f pixels" % dist_v2)

	return Assertions.AssertResult.new(true)
