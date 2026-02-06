class_name GameLogger
extends Node

## Logs game state snapshots and human actions during play.
## Writes log files to disk when the game ends (via game_over signal).

const SNAPSHOT_INTERVAL: float = 10.0
const HUMAN_TEAM: int = 0
const AI_TEAM: int = 1

# Snapshot and action storage
var snapshots: Array = []
var human_actions: Array = []

# Timing
var _time_elapsed: float = 0.0
var _snapshot_timer: float = 0.0
var _ai_controller: Node = null
var _took_initial_snapshot: bool = false

# Metadata
var _metadata: Dictionary = {}


func _ready() -> void:
	_collect_metadata()
	GameManager.game_over.connect(_on_game_over)
	# Try to find AIController for shared game time
	_ai_controller = get_parent().get_node_or_null("AIController")


func _process(delta: float) -> void:
	if GameManager.game_ended:
		return

	# Take initial snapshot on first frame (scene tree is fully populated)
	if not _took_initial_snapshot:
		_took_initial_snapshot = true
		_take_snapshot()

	_time_elapsed += delta
	_snapshot_timer += delta

	if _snapshot_timer >= SNAPSHOT_INTERVAL:
		_snapshot_timer -= SNAPSHOT_INTERVAL
		_take_snapshot()


func log_action(action: String, details: Dictionary = {}) -> void:
	human_actions.append({
		"t": snappedf(_get_game_time(), 0.1),
		"action": action,
		"details": details,
	})


func _get_game_time() -> float:
	if _ai_controller and "game_time_elapsed" in _ai_controller:
		return _ai_controller.game_time_elapsed
	return _time_elapsed


func _take_snapshot() -> void:
	var t = snappedf(_get_game_time(), 0.1)
	snapshots.append({
		"t": t,
		"human": GameStateSnapshot.capture(get_tree(), HUMAN_TEAM),
		"ai": GameStateSnapshot.capture(get_tree(), AI_TEAM),
	})


func _collect_metadata() -> void:
	_metadata["timestamp"] = Time.get_datetime_string_from_system()

	# Git commit
	var output: Array = []
	OS.execute("git", ["rev-parse", "--short", "HEAD"], output)
	_metadata["git_commit"] = output[0].strip_edges() if output.size() > 0 else "unknown"

	# Git dirty flag
	output = []
	OS.execute("git", ["status", "--porcelain"], output)
	_metadata["git_dirty"] = output[0].strip_edges() != "" if output.size() > 0 else false


func _on_game_over(winner: int) -> void:
	# Take final snapshot
	_take_snapshot()

	# Complete metadata
	_metadata["game_duration_seconds"] = snappedf(_get_game_time(), 0.1)
	_metadata["winner"] = winner
	_metadata["winner_name"] = "human" if winner == 0 else "ai"

	_write_logs()


func _write_logs() -> void:
	var timestamp = Time.get_datetime_string_from_system().replace(":", "-").replace("T", "_")
	var project_root = ProjectSettings.globalize_path("res://")
	var dir_path = project_root.path_join("logs/game_logs/game_%s" % timestamp)

	# Ensure directory exists
	DirAccess.make_dir_recursive_absolute(dir_path)

	_write_metadata(dir_path)
	_write_snapshots(dir_path)
	_write_human_actions(dir_path)
	_write_comparison(dir_path)

	# Also log the absolute path for easy access
	var abs_path = ProjectSettings.globalize_path(dir_path)
	print("[GameLogger] Logs written to: %s" % abs_path)


func _write_metadata(dir_path: String) -> void:
	var file = FileAccess.open(dir_path + "/metadata.json", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(_metadata, "  "))


func _write_snapshots(dir_path: String) -> void:
	var file = FileAccess.open(dir_path + "/snapshots.jsonl", FileAccess.WRITE)
	if file:
		for snap in snapshots:
			file.store_line(JSON.stringify(snap))


func _write_human_actions(dir_path: String) -> void:
	var file = FileAccess.open(dir_path + "/human_actions.jsonl", FileAccess.WRITE)
	if file:
		for action in human_actions:
			file.store_line(JSON.stringify(action))


func _write_comparison(dir_path: String) -> void:
	var file = FileAccess.open(dir_path + "/comparison.md", FileAccess.WRITE)
	if not file:
		return

	file.store_line("# Game comparison: Human vs AI")
	file.store_line("")
	file.store_line("**Duration:** %.0fs | **Winner:** %s" % [
		_metadata.get("game_duration_seconds", 0),
		_metadata.get("winner_name", "unknown"),
	])
	file.store_line("")

	_write_economy_curve(file)
	_write_resource_stockpiles(file)
	_write_milestones(file)
	_write_final_state(file)
	_write_action_summary(file)


func _write_economy_curve(file: FileAccess) -> void:
	file.store_line("## Economy curve (villager count)")
	file.store_line("")
	file.store_line("| Time | Human | AI |")
	file.store_line("|------|-------|----|")

	var checkpoints = [60, 120, 180, 240, 300]
	for t in checkpoints:
		var snap = _find_nearest_snapshot(t)
		if snap:
			var h = snap["human"]["villagers"]["total"]
			var a = snap["ai"]["villagers"]["total"]
			file.store_line("| %ds | %d | %d |" % [t, h, a])
		else:
			file.store_line("| %ds | - | - |" % t)
	file.store_line("")


func _write_resource_stockpiles(file: FileAccess) -> void:
	file.store_line("## Resource stockpiles")
	file.store_line("")

	var checkpoints = [120, 240]
	for t in checkpoints:
		var snap = _find_nearest_snapshot(t)
		if not snap:
			continue
		file.store_line("### t=%ds" % t)
		file.store_line("")
		file.store_line("| Resource | Human | AI |")
		file.store_line("|----------|-------|----|")
		for res in ["food", "wood", "gold", "stone"]:
			var h = snap["human"]["resources"][res]
			var a = snap["ai"]["resources"][res]
			file.store_line("| %s | %d | %d |" % [res, h, a])
		file.store_line("")


func _write_milestones(file: FileAccess) -> void:
	file.store_line("## Milestone timings")
	file.store_line("")
	file.store_line("| Milestone | Human | AI |")
	file.store_line("|-----------|-------|----|")

	var milestone_defs = [
		["First barracks", "buildings", "barracks"],
		["First farm", "buildings", "farm"],
		["First military building (AR/Stable)", "buildings", "_first_military_building"],
		["5 villagers", "villagers", "_villager_threshold_5"],
		["10 villagers", "villagers", "_villager_threshold_10"],
		["15 villagers", "villagers", "_villager_threshold_15"],
		["First military unit", "military", "total"],
	]

	for mdef in milestone_defs:
		var label = mdef[0]
		var category = mdef[1]
		var key = mdef[2]

		var h_time = _find_milestone_time(HUMAN_TEAM, category, key)
		var a_time = _find_milestone_time(AI_TEAM, category, key)

		var h_str = "%ds" % h_time if h_time >= 0 else "-"
		var a_str = "%ds" % a_time if a_time >= 0 else "-"
		file.store_line("| %s | %s | %s |" % [label, h_str, a_str])
	file.store_line("")


func _write_final_state(file: FileAccess) -> void:
	if snapshots.is_empty():
		return

	var final = snapshots[-1]
	file.store_line("## Final state")
	file.store_line("")

	# Buildings
	file.store_line("### Buildings")
	file.store_line("")
	file.store_line("| Building | Human | AI |")
	file.store_line("|----------|-------|----|")
	for btype in ["town_center", "house", "barracks", "archery_range", "stable", "farm", "mill", "lumber_camp", "mining_camp", "market"]:
		var h = final["human"]["buildings"][btype]
		var a = final["ai"]["buildings"][btype]
		if h > 0 or a > 0:
			file.store_line("| %s | %d | %d |" % [btype, h, a])
	file.store_line("")

	# Military
	file.store_line("### Military")
	file.store_line("")
	file.store_line("| Unit | Human | AI |")
	file.store_line("|------|-------|----|")
	for utype in ["militia", "spearman", "archer", "skirmisher", "scout_cavalry", "cavalry_archer"]:
		var h = final["human"]["military"][utype]
		var a = final["ai"]["military"][utype]
		if h > 0 or a > 0:
			file.store_line("| %s | %d | %d |" % [utype, h, a])
	var h_total = final["human"]["military"]["total"]
	var a_total = final["ai"]["military"]["total"]
	file.store_line("| **total** | **%d** | **%d** |" % [h_total, a_total])
	file.store_line("")


func _write_action_summary(file: FileAccess) -> void:
	file.store_line("## Human action summary")
	file.store_line("")

	var counts: Dictionary = {}
	for action_entry in human_actions:
		var action = action_entry["action"]
		counts[action] = counts.get(action, 0) + 1

	if counts.is_empty():
		file.store_line("No actions recorded.")
		file.store_line("")
		return

	file.store_line("| Action | Count |")
	file.store_line("|--------|-------|")
	# Sort keys for consistent output
	var keys = counts.keys()
	keys.sort()
	for key in keys:
		file.store_line("| %s | %d |" % [key, counts[key]])
	file.store_line("")


# --- Helpers ---

func _find_nearest_snapshot(target_time: float) -> Variant:
	## Returns the snapshot closest to target_time, or null if none exist.
	var best: Variant = null
	var best_dist: float = INF
	for snap in snapshots:
		var dist = absf(snap["t"] - target_time)
		if dist < best_dist:
			best_dist = dist
			best = snap
	return best


func _find_milestone_time(team: int, category: String, key: String) -> float:
	## Scan snapshots for the first time a metric crosses from 0 to >0.
	## Returns the time in seconds, or -1 if never reached.
	var team_key = "human" if team == HUMAN_TEAM else "ai"

	for snap in snapshots:
		var data = snap[team_key]

		# Special compound checks
		if key == "_first_military_building":
			if data["buildings"]["archery_range"] > 0 or data["buildings"]["stable"] > 0:
				return snap["t"]
			continue

		if key == "_villager_threshold_5":
			if data["villagers"]["total"] >= 5:
				return snap["t"]
			continue

		if key == "_villager_threshold_10":
			if data["villagers"]["total"] >= 10:
				return snap["t"]
			continue

		if key == "_villager_threshold_15":
			if data["villagers"]["total"] >= 15:
				return snap["t"]
			continue

		# Standard check: category.key crosses 0→>0
		if category in data and key in data[category]:
			if data[category][key] > 0:
				return snap["t"]

	return -1.0
