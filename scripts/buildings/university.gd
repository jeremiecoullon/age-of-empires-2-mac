extends Building
class_name University

## University - researches building upgrades and defensive technologies.
## AoE2 spec: 200W, 2100 HP, 3x3 tiles, available from Castle Age.

func _ready() -> void:
	max_hp = 2100
	building_name = "University"
	size = Vector2i(3, 3)
	wood_cost = 200
	build_time = 60.0
	sight_range = 192.0
	super._ready()
	add_to_group("universities")

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

## Get tech IDs available at this University (based on age and prerequisites)
func get_available_techs() -> Array[String]:
	var available: Array[String] = []
	for tech_id in GameManager.TECHNOLOGIES:
		var tech = GameManager.TECHNOLOGIES[tech_id]
		if tech["building"] != "university":
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
