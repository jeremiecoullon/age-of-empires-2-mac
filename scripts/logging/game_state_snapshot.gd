class_name GameStateSnapshot
extends RefCounted

## Captures a team-parameterized snapshot of game state.
## Used by GameLogger to record both human and AI state over time.


static func capture(scene_tree: SceneTree, team: int) -> Dictionary:
	return {
		"resources": _capture_resources(team),
		"population": _capture_population(team),
		"villagers": _capture_villagers(scene_tree, team),
		"military": _capture_military(scene_tree, team),
		"buildings": _capture_buildings(scene_tree, team),
		"technologies": _capture_technologies(team),
	}


static func _capture_resources(team: int) -> Dictionary:
	return {
		"food": GameManager.get_resource("food", team),
		"wood": GameManager.get_resource("wood", team),
		"gold": GameManager.get_resource("gold", team),
		"stone": GameManager.get_resource("stone", team),
	}


static func _capture_population(team: int) -> Dictionary:
	var current = GameManager.get_population(team)
	var cap = GameManager.get_population_cap(team)
	return {
		"current": current,
		"cap": cap,
		"headroom": cap - current,
	}


static func _capture_villagers(scene_tree: SceneTree, team: int) -> Dictionary:
	var result = {
		"total": 0,
		"food": 0,
		"wood": 0,
		"gold": 0,
		"stone": 0,
		"idle": 0,
		"building": 0,
	}

	for villager in scene_tree.get_nodes_in_group("villagers"):
		if villager.team != team or villager.is_dead:
			continue
		result["total"] += 1

		match villager.current_state:
			villager.State.IDLE, villager.State.ATTACKING:
				result["idle"] += 1
			villager.State.GATHERING, villager.State.RETURNING, villager.State.MOVING:
				var resource_type = villager.carried_resource_type
				if resource_type != "" and resource_type in result:
					result[resource_type] += 1
				else:
					result["idle"] += 1
			villager.State.HUNTING:
				result["food"] += 1
			villager.State.BUILDING, villager.State.REPAIRING:
				result["building"] += 1

	return result


static func _capture_military(scene_tree: SceneTree, team: int) -> Dictionary:
	var result = {
		"total": 0,
		"militia": 0,
		"man_at_arms": 0,
		"long_swordsman": 0,
		"spearman": 0,
		"pikeman": 0,
		"archer": 0,
		"crossbowman": 0,
		"skirmisher": 0,
		"elite_skirmisher": 0,
		"scout_cavalry": 0,
		"light_cavalry": 0,
		"cavalry_archer": 0,
		"heavy_cavalry_archer": 0,
		"knight": 0,
	}

	# Iterate military group once and classify with elif chain.
	# Check upgraded groups before base groups to avoid double-counting
	# (e.g. crossbowmen were archers before upgrade).
	for unit in scene_tree.get_nodes_in_group("military"):
		if unit.team != team or unit.is_dead:
			continue
		result["total"] += 1
		# Upgraded groups first (most specific)
		if unit.is_in_group("elite_skirmishers"):
			result["elite_skirmisher"] += 1
		elif unit.is_in_group("skirmishers"):
			result["skirmisher"] += 1
		elif unit.is_in_group("heavy_cavalry_archers"):
			result["heavy_cavalry_archer"] += 1
		elif unit.is_in_group("cavalry_archers"):
			result["cavalry_archer"] += 1
		elif unit.is_in_group("light_cavalry"):
			result["light_cavalry"] += 1
		elif unit.is_in_group("scout_cavalry"):
			result["scout_cavalry"] += 1
		elif unit.is_in_group("knights"):
			result["knight"] += 1
		elif unit.is_in_group("crossbowmen"):
			result["crossbowman"] += 1
		elif unit.is_in_group("archers") or unit.is_in_group("archers_line"):
			result["archer"] += 1
		elif unit.is_in_group("long_swordsmen"):
			result["long_swordsman"] += 1
		elif unit.is_in_group("man_at_arms"):
			result["man_at_arms"] += 1
		elif unit.is_in_group("militia"):
			result["militia"] += 1
		elif unit.is_in_group("pikemen"):
			result["pikeman"] += 1
		elif unit.is_in_group("spearmen"):
			result["spearman"] += 1
		else:
			push_warning("GameStateSnapshot: unclassified military unit '%s' in team %d" % [unit.name, team])

	return result


static func _capture_buildings(scene_tree: SceneTree, team: int) -> Dictionary:
	var result = {
		"town_center": 0,
		"house": 0,
		"barracks": 0,
		"archery_range": 0,
		"stable": 0,
		"farm": 0,
		"mill": 0,
		"lumber_camp": 0,
		"mining_camp": 0,
		"market": 0,
		"blacksmith": 0,
	}

	# Map group names to result keys
	var groups = {
		"town_centers": "town_center",
		"houses": "house",
		"barracks": "barracks",
		"archery_ranges": "archery_range",
		"stables": "stable",
		"farms": "farm",
		"mills": "mill",
		"lumber_camps": "lumber_camp",
		"mining_camps": "mining_camp",
		"markets": "market",
		"blacksmiths": "blacksmith",
	}

	for group_name in groups:
		var key = groups[group_name]
		for building in scene_tree.get_nodes_in_group(group_name):
			if building.team == team and building.is_functional():
				result[key] += 1

	return result


static func _capture_technologies(team: int) -> Dictionary:
	var researched: Array = []
	if team == 0:
		researched = GameManager.player_researched_techs.duplicate()
	else:
		researched = GameManager.ai_researched_techs.duplicate()

	# Find current research (check blacksmiths and TCs)
	var current_research: String = ""
	# We can't easily iterate scene nodes here (static func without scene_tree for this),
	# so just report the researched set. Current research is tracked in AI_STATE logs.

	return {
		"researched": researched,
		"researched_count": researched.size(),
		"has_loom": GameManager.has_tech("loom", team),
	}
