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
		"spearman": 0,
		"archer": 0,
		"skirmisher": 0,
		"scout_cavalry": 0,
		"cavalry_archer": 0,
	}

	# Map group names to result keys
	var groups = {
		"militia": "militia",
		"spearmen": "spearman",
		"archers": "archer",
		"skirmishers": "skirmisher",
		"scout_cavalry": "scout_cavalry",
		"cavalry_archers": "cavalry_archer",
	}

	for group_name in groups:
		var key = groups[group_name]
		for unit in scene_tree.get_nodes_in_group(group_name):
			if unit.team == team and not unit.is_dead:
				result[key] += 1
				result["total"] += 1

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
	}

	for group_name in groups:
		var key = groups[group_name]
		for building in scene_tree.get_nodes_in_group(group_name):
			if building.team == team and building.is_functional():
				result[key] += 1

	return result
