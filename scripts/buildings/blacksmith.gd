extends Building
class_name Blacksmith

## Blacksmith - researches attack and armor upgrades for all military units.
## AoE2 spec: 150W, 2100 HP, 3x3 tiles, available from Feudal Age.

func _ready() -> void:
	max_hp = 2100
	super._ready()
	add_to_group("blacksmiths")
	building_name = "Blacksmith"
	size = Vector2i(3, 3)
	wood_cost = 150
	build_time = 40.0
	sight_range = 192.0

func _process(delta: float) -> void:
	if is_destroyed or not is_constructed:
		return
	_process_research(delta)

func _destroy() -> void:
	if is_destroyed:
		return
	if is_researching:
		cancel_research()
	is_destroyed = true
	destroyed.emit()
	queue_free()

## Get tech IDs available at this Blacksmith (based on age and prerequisites)
func get_available_techs() -> Array[String]:
	var available: Array[String] = []
	for tech_id in GameManager.TECHNOLOGIES:
		var tech = GameManager.TECHNOLOGIES[tech_id]
		if tech["building"] != "blacksmith":
			continue
		if GameManager.has_tech(tech_id, team):
			continue
		if GameManager.get_age(team) < tech["age"]:
			continue
		var prereq = tech["requires"]
		if prereq != "" and not GameManager.has_tech(prereq, team):
			continue
		available.append(tech_id)
	return available

## Get all blacksmith tech IDs (regardless of availability)
func get_all_techs() -> Array[String]:
	var techs: Array[String] = []
	for tech_id in GameManager.TECHNOLOGIES:
		if GameManager.TECHNOLOGIES[tech_id]["building"] == "blacksmith":
			techs.append(tech_id)
	return techs
