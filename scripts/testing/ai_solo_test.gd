extends Node
class_name AISoloTest

## Test controller for headless AI observation.
## Runs the game at accelerated speed and quits after a set duration.
## Outputs structured summary.json and logs.txt to /tmp/ai_test_<timestamp>/

@export var time_scale: float = 10.0
@export var test_duration: float = 600.0  # Game seconds (10 minutes default)

var test_started: bool = false

# Output directory
var output_dir: String = ""

# Analyzer for tracking milestones and anomalies
var analyzer: AITestAnalyzer = null

# Log buffer
var log_buffer: Array[String] = []

# Reference to AI controller (to get game state)
var ai_controller: Node = null


func _ready() -> void:
	# Parse command-line arguments (passed after -- on command line)
	_parse_cmdline_args()

	Engine.time_scale = time_scale

	# Create output directory in repo (logs/testing_logs/)
	# NOTE: This writes to the project directory, which works during development
	# Include PID to ensure unique directories for parallel runs
	var timestamp = Time.get_datetime_string_from_system().replace(":", "-").replace("T", "_")
	var pid = OS.get_process_id()
	output_dir = "res://logs/testing_logs/ai_test_%s_p%d" % [timestamp, pid]
	output_dir = ProjectSettings.globalize_path(output_dir)
	var dir_err = DirAccess.make_dir_recursive_absolute(output_dir)
	if dir_err != OK and dir_err != ERR_ALREADY_EXISTS:
		push_error("AI_TEST_ERROR: Failed to create output directory: " + str(dir_err))

	# Initialize analyzer
	analyzer = AITestAnalyzer.new()
	analyzer.initialize(get_tree())

	# Find AI controller - required for test to run
	ai_controller = _find_ai_controller()
	if ai_controller:
		ai_controller.set_meta("log_callback", _on_ai_log)
	else:
		push_error("AI_TEST_ERROR: Could not find AIController - test cannot proceed")
		get_tree().quit(1)
		return

	var start_data = {
		"time_scale": time_scale,
		"duration": test_duration,
		"output_dir": output_dir,
	}
	_log("AI_TEST_START|" + JSON.stringify(start_data))
	test_started = true


func _parse_cmdline_args() -> void:
	## Parse command-line arguments passed after -- on the command line.
	## Supported args:
	##   --duration=<seconds>  Set test duration in game seconds (default: 600)
	##   --timescale=<multiplier>  Set time scale (default: 10.0)
	var args = OS.get_cmdline_user_args()
	for arg in args:
		if arg.begins_with("--duration="):
			var value = arg.substr(11)
			if value.is_valid_float():
				test_duration = value.to_float()
				print("AI_TEST_CONFIG: duration set to " + str(test_duration) + " game seconds")
			else:
				push_warning("AI_TEST_WARNING: Invalid duration value: " + value)
		elif arg.begins_with("--timescale="):
			var value = arg.substr(12)
			if value.is_valid_float():
				time_scale = value.to_float()
				print("AI_TEST_CONFIG: time_scale set to " + str(time_scale))
			else:
				push_warning("AI_TEST_WARNING: Invalid timescale value: " + value)


func _find_ai_controller() -> Node:
	# AI controller is an autoload or child of main scene
	var main = get_tree().current_scene
	for child in main.get_children():
		if child is AIController:
			return child
	# Check autoloads
	if has_node("/root/AIController"):
		return get_node("/root/AIController")
	return null


func _process(_delta: float) -> void:
	if not test_started:
		return

	# Use AI controller's time as single source of truth
	var game_time = ai_controller.game_time_elapsed

	# Update analyzer
	if analyzer and ai_controller.game_state:
		analyzer.check_state(game_time, ai_controller.game_state)

	# End test if duration reached OR game ended (AI won/lost)
	if game_time >= test_duration or GameManager.game_ended:
		_end_test()


func _log(message: String) -> void:
	## Log to both stdout and buffer
	print(message)
	log_buffer.append(message)


func _on_ai_log(message: String) -> void:
	## Callback for AI controller logs
	log_buffer.append(message)

	# Check for attack action to record milestone
	if message.begins_with("AI_ACTION|"):
		var json_str = message.substr(10)
		var json = JSON.new()
		if json.parse(json_str) == OK:
			var data = json.get_data()
			if data is Dictionary and data.get("action") == "attack":
				if analyzer:
					analyzer.record_attack()


func _end_test() -> void:
	var game_time = ai_controller.game_time_elapsed
	var end_data = {
		"game_time": snappedf(game_time, 0.1),
		"status": "complete",
		"output_dir": output_dir,
	}
	_log("AI_TEST_END|" + JSON.stringify(end_data))

	# Generate and write summary
	if analyzer and ai_controller.game_state:
		var summary = analyzer.generate_summary(
			test_duration,
			time_scale,
			game_time,
			ai_controller.game_state
		)
		_write_summary(summary)

	# Write logs
	_write_logs()

	# Print output location for easy access
	print("\n=== Test Complete ===")
	print("Output: " + output_dir)
	print("  summary.json - Structured results")
	print("  logs.txt     - Full verbose logs")

	get_tree().quit(0)


func _write_summary(summary: Dictionary) -> void:
	var path = output_dir + "/summary.json"
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file:
		var json_str = JSON.stringify(summary, "  ")
		file.store_string(json_str)
		file.close()
	else:
		push_error("AI_TEST_ERROR: Failed to write summary.json - " + str(FileAccess.get_open_error()))


func _write_logs() -> void:
	var path = output_dir + "/logs.txt"
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file:
		for line in log_buffer:
			file.store_line(line)
		file.close()
	else:
		push_error("AI_TEST_ERROR: Failed to write logs.txt - " + str(FileAccess.get_open_error()))
