extends Node
class_name AISoloTest

## Test controller for headless AI observation.
## Runs the game at accelerated speed and quits after a set duration.

@export var time_scale: float = 10.0
@export var test_duration: float = 60.0  # Game seconds

var game_time_elapsed: float = 0.0
var test_started: bool = false


func _ready() -> void:
	Engine.time_scale = time_scale
	var start_data = {
		"time_scale": time_scale,
		"duration": test_duration,
	}
	print("AI_TEST_START|" + JSON.stringify(start_data))
	test_started = true


func _process(delta: float) -> void:
	if not test_started:
		return

	game_time_elapsed += delta

	if game_time_elapsed >= test_duration:
		_end_test()


func _end_test() -> void:
	var end_data = {
		"game_time": snappedf(game_time_elapsed, 0.1),
		"status": "complete",
	}
	print("AI_TEST_END|" + JSON.stringify(end_data))
	get_tree().quit(0)
