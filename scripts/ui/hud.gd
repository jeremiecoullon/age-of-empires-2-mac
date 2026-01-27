extends CanvasLayer

@onready var wood_label: Label = $TopBar/WoodLabel
@onready var food_label: Label = $TopBar/FoodLabel
@onready var gold_label: Label = $TopBar/GoldLabel
@onready var stone_label: Label = $TopBar/StoneLabel
@onready var pop_label: Label = $TopBar/PopLabel
@onready var build_panel: PanelContainer = $BuildPanel
@onready var tc_panel: PanelContainer = $TCPanel
@onready var train_button: Button = $TCPanel/VBoxContainer/TrainVillagerButton
@onready var train_progress: ProgressBar = $TCPanel/VBoxContainer/TrainProgress
@onready var barracks_panel: PanelContainer = $BarracksPanel
@onready var train_militia_button: Button = $BarracksPanel/VBoxContainer/TrainMilitiaButton
@onready var barracks_train_progress: ProgressBar = $BarracksPanel/VBoxContainer/BarracksTrainProgress
@onready var error_label: Label = $ErrorLabel
@onready var info_panel: PanelContainer = $InfoPanel
@onready var info_title: Label = $InfoPanel/VBoxContainer/InfoTitle
@onready var info_details: Label = $InfoPanel/VBoxContainer/InfoDetails
@onready var game_over_panel: PanelContainer = $GameOverPanel
@onready var game_over_label: Label = $GameOverPanel/VBoxContainer/GameOverLabel
@onready var restart_button: Button = $GameOverPanel/VBoxContainer/RestartButton

var selected_tc: TownCenter = null
var selected_barracks: Barracks = null

func _ready() -> void:
	GameManager.resources_changed.connect(_update_resources)
	GameManager.population_changed.connect(_update_population)
	GameManager.game_over.connect(_on_game_over)
	_update_resources()
	_update_population()
	tc_panel.visible = false
	barracks_panel.visible = false
	error_label.visible = false
	info_panel.visible = false
	game_over_panel.visible = false

func _update_resources() -> void:
	wood_label.text = "Wood: %d" % GameManager.get_resource("wood")
	food_label.text = "Food: %d" % GameManager.get_resource("food")
	gold_label.text = "Gold: %d" % GameManager.get_resource("gold")
	stone_label.text = "Stone: %d" % GameManager.get_resource("stone")

func _update_population() -> void:
	pop_label.text = "Pop: %d/%d" % [GameManager.get_population(), GameManager.get_population_cap()]

func _process(_delta: float) -> void:
	if selected_tc and selected_tc.is_training:
		train_progress.value = selected_tc.get_train_progress() * 100
		train_progress.visible = true
	else:
		train_progress.visible = false

	if selected_barracks and selected_barracks.is_training:
		barracks_train_progress.value = selected_barracks.get_train_progress() * 100
		barracks_train_progress.visible = true
	else:
		barracks_train_progress.visible = false

func show_tc_panel(tc: TownCenter) -> void:
	# Disconnect previous TC signal if exists
	if selected_tc and selected_tc.training_completed.is_connected(_on_training_completed):
		selected_tc.training_completed.disconnect(_on_training_completed)

	selected_tc = tc
	tc_panel.visible = true
	build_panel.visible = false
	if not tc.training_completed.is_connected(_on_training_completed):
		tc.training_completed.connect(_on_training_completed)

func hide_tc_panel() -> void:
	if selected_tc:
		if selected_tc.training_completed.is_connected(_on_training_completed):
			selected_tc.training_completed.disconnect(_on_training_completed)
	selected_tc = null
	tc_panel.visible = false
	build_panel.visible = true

func show_barracks_panel(barracks: Barracks) -> void:
	# Disconnect previous barracks signal if exists
	if selected_barracks and selected_barracks.training_completed.is_connected(_on_barracks_training_completed):
		selected_barracks.training_completed.disconnect(_on_barracks_training_completed)

	selected_barracks = barracks
	barracks_panel.visible = true
	tc_panel.visible = false
	build_panel.visible = false
	if not barracks.training_completed.is_connected(_on_barracks_training_completed):
		barracks.training_completed.connect(_on_barracks_training_completed)

func hide_barracks_panel() -> void:
	if selected_barracks:
		if selected_barracks.training_completed.is_connected(_on_barracks_training_completed):
			selected_barracks.training_completed.disconnect(_on_barracks_training_completed)
	selected_barracks = null
	barracks_panel.visible = false
	build_panel.visible = true

func _on_training_completed() -> void:
	train_progress.visible = false

func _on_barracks_training_completed() -> void:
	barracks_train_progress.visible = false

func _on_train_villager_pressed() -> void:
	if selected_tc:
		if not selected_tc.train_villager():
			if not GameManager.can_afford("food", TownCenter.VILLAGER_COST):
				_show_error("Not enough food! (Need 50)")
			elif not GameManager.can_add_population():
				_show_error("Population cap reached! Build a House.")

func _on_build_house_pressed() -> void:
	if not GameManager.can_afford("wood", 25):
		_show_error("Not enough wood! (Need 25)")
		return
	get_parent().start_house_placement()

func _on_build_barracks_pressed() -> void:
	if not GameManager.can_afford("wood", 100):
		_show_error("Not enough wood! (Need 100)")
		return
	get_parent().start_barracks_placement()

func _on_build_farm_pressed() -> void:
	if not GameManager.can_afford("wood", 50):
		_show_error("Not enough wood! (Need 50)")
		return
	get_parent().start_farm_placement()

func _on_build_mill_pressed() -> void:
	if not GameManager.can_afford("wood", 100):
		_show_error("Not enough wood! (Need 100)")
		return
	get_parent().start_mill_placement()

func _on_build_lumber_camp_pressed() -> void:
	if not GameManager.can_afford("wood", 100):
		_show_error("Not enough wood! (Need 100)")
		return
	get_parent().start_lumber_camp_placement()

func _on_build_mining_camp_pressed() -> void:
	if not GameManager.can_afford("wood", 100):
		_show_error("Not enough wood! (Need 100)")
		return
	get_parent().start_mining_camp_placement()

func _on_train_militia_pressed() -> void:
	if selected_barracks:
		if not selected_barracks.train_militia():
			if not GameManager.can_afford("food", Barracks.MILITIA_FOOD_COST):
				_show_error("Not enough food! (Need 60)")
			elif not GameManager.can_afford("wood", Barracks.MILITIA_WOOD_COST):
				_show_error("Not enough wood! (Need 20)")
			elif not GameManager.can_add_population():
				_show_error("Population cap reached! Build a House.")

func _show_error(message: String) -> void:
	error_label.text = message
	error_label.visible = true
	await get_tree().create_timer(2.0).timeout
	error_label.visible = false

func show_info(entity: Node) -> void:
	if entity is Villager:
		_show_villager_info(entity)
	elif entity is Militia:
		_show_militia_info(entity)
	elif entity is Farm:
		_show_building_info("Farm", "Infinite food source\nGather rate: 0.5/sec")
	elif entity is ResourceNode:
		_show_resource_info(entity)
	elif entity is TownCenter:
		_show_building_info("Town Center", "Trains villagers\nDeposit: all resources")
	elif entity is Barracks:
		_show_building_info("Barracks", "Trains militia")
	elif entity is House:
		_show_building_info("House", "+5 population cap")
	elif entity is Mill:
		_show_building_info("Mill", "Deposit point for food")
	elif entity is LumberCamp:
		_show_building_info("Lumber Camp", "Deposit point for wood")
	elif entity is MiningCamp:
		_show_building_info("Mining Camp", "Deposit point for gold/stone")
	elif entity is Building:
		_show_building_info(entity.building_name, "")
	else:
		hide_info()

func _show_villager_info(villager: Villager) -> void:
	info_title.text = "Villager"
	var state_text = ""
	match villager.current_state:
		Villager.State.IDLE:
			state_text = "Idle"
		Villager.State.MOVING:
			state_text = "Moving"
		Villager.State.GATHERING:
			state_text = "Gathering " + villager.carried_resource_type
		Villager.State.RETURNING:
			state_text = "Returning to drop-off"

	var details = "Status: %s" % state_text
	if villager.carried_amount > 0:
		details += "\nCarrying: %d %s" % [villager.carried_amount, villager.carried_resource_type]
	info_details.text = details
	info_panel.visible = true

func _show_militia_info(militia: Militia) -> void:
	info_title.text = "Militia"
	var state_text = ""
	match militia.current_state:
		Militia.State.IDLE:
			state_text = "Idle"
		Militia.State.MOVING:
			state_text = "Moving"
		Militia.State.ATTACKING:
			state_text = "Attacking"

	var details = "Status: %s\nHP: %d/%d\nAttack: %d" % [state_text, militia.current_hp, militia.max_hp, militia.attack_damage]
	info_details.text = details
	info_panel.visible = true

func _show_resource_info(resource: ResourceNode) -> void:
	var type_name: String
	match resource.resource_type:
		"wood":
			type_name = "Tree"
		"food":
			type_name = "Berry Bush"
		"gold":
			type_name = "Gold Mine"
		"stone":
			type_name = "Stone Mine"
		_:
			type_name = "Resource"
	info_title.text = type_name
	info_details.text = "Resource: %s\nRemaining: %d" % [resource.resource_type.capitalize(), resource.current_amount]
	info_panel.visible = true

func _show_building_info(title: String, details: String) -> void:
	info_title.text = title
	info_details.text = details
	info_panel.visible = true

func hide_info() -> void:
	info_panel.visible = false

func _on_game_over(winner: int) -> void:
	game_over_panel.visible = true
	if winner == 0:
		game_over_label.text = "VICTORY!"
		game_over_label.add_theme_color_override("font_color", Color(0.2, 0.8, 0.2))
	else:
		game_over_label.text = "DEFEAT"
		game_over_label.add_theme_color_override("font_color", Color(0.8, 0.2, 0.2))

func _on_restart_pressed() -> void:
	selected_tc = null
	selected_barracks = null
	GameManager.reset()
	get_tree().reload_current_scene()
