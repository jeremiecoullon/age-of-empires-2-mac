extends CanvasLayer

@onready var wood_label: Label = $TopBar/WoodLabel
@onready var food_label: Label = $TopBar/FoodLabel
@onready var gold_label: Label = $TopBar/GoldLabel
@onready var stone_label: Label = $TopBar/StoneLabel
@onready var pop_label: Label = $TopBar/PopLabel
@onready var build_panel: PanelContainer = $BuildPanel
@onready var tc_panel: PanelContainer = $TCPanel
@onready var train_button: Button = $TCPanel/VBoxContainer/TrainVillagerButton
@onready var train_progress: ProgressBar = $TCPanel/VBoxContainer/QueueContainer/TrainProgress
@onready var tc_queue_label: Label = $TCPanel/VBoxContainer/QueueContainer/QueueLabel
@onready var tc_cancel_button: Button = $TCPanel/VBoxContainer/CancelButton
@onready var barracks_panel: PanelContainer = $BarracksPanel
@onready var train_militia_button: Button = $BarracksPanel/VBoxContainer/TrainMilitiaButton
@onready var barracks_train_progress: ProgressBar = $BarracksPanel/VBoxContainer/QueueContainer/BarracksTrainProgress
@onready var barracks_queue_label: Label = $BarracksPanel/VBoxContainer/QueueContainer/QueueLabel
@onready var barracks_cancel_button: Button = $BarracksPanel/VBoxContainer/CancelButton
@onready var market_panel: PanelContainer = $MarketPanel
@onready var buy_wood_button: Button = $MarketPanel/VBoxContainer/PriceContainer/BuyColumn/BuyWoodButton
@onready var buy_food_button: Button = $MarketPanel/VBoxContainer/PriceContainer/BuyColumn/BuyFoodButton
@onready var buy_stone_button: Button = $MarketPanel/VBoxContainer/PriceContainer/BuyColumn/BuyStoneButton
@onready var sell_wood_button: Button = $MarketPanel/VBoxContainer/PriceContainer/SellColumn/SellWoodButton
@onready var sell_food_button: Button = $MarketPanel/VBoxContainer/PriceContainer/SellColumn/SellFoodButton
@onready var sell_stone_button: Button = $MarketPanel/VBoxContainer/PriceContainer/SellColumn/SellStoneButton
@onready var market_train_progress: ProgressBar = $MarketPanel/VBoxContainer/QueueContainer/MarketTrainProgress
@onready var market_queue_label: Label = $MarketPanel/VBoxContainer/QueueContainer/QueueLabel
@onready var market_cancel_button: Button = $MarketPanel/VBoxContainer/CancelButton
@onready var archery_range_panel: PanelContainer = $ArcheryRangePanel
@onready var archery_range_train_progress: ProgressBar = $ArcheryRangePanel/VBoxContainer/QueueContainer/ArcheryRangeTrainProgress
@onready var archery_range_queue_label: Label = $ArcheryRangePanel/VBoxContainer/QueueContainer/QueueLabel
@onready var archery_range_cancel_button: Button = $ArcheryRangePanel/VBoxContainer/CancelButton
@onready var stable_panel: PanelContainer = $StablePanel
@onready var stable_train_progress: ProgressBar = $StablePanel/VBoxContainer/QueueContainer/StableTrainProgress
@onready var stable_queue_label: Label = $StablePanel/VBoxContainer/QueueContainer/QueueLabel
@onready var stable_cancel_button: Button = $StablePanel/VBoxContainer/CancelButton
@onready var error_label: Label = $ErrorLabel
@onready var info_panel: PanelContainer = $InfoPanel
@onready var info_title: Label = $InfoPanel/VBoxContainer/InfoTitle
@onready var info_details: Label = $InfoPanel/VBoxContainer/InfoDetails
@onready var game_over_panel: PanelContainer = $GameOverPanel
@onready var game_over_label: Label = $GameOverPanel/VBoxContainer/GameOverLabel
@onready var restart_button: Button = $GameOverPanel/VBoxContainer/RestartButton

# Attack notification label (created dynamically if not in scene)
var attack_notification_label: Label = null

# Stance UI (created dynamically)
var stance_container: HBoxContainer = null
var stance_buttons: Array[Button] = []
var selected_military_unit: Unit = null  # Track currently selected military unit for stance changes

var selected_tc: TownCenter = null
var selected_barracks: Barracks = null
var selected_market: Market = null
var selected_archery_range: ArcheryRange = null
var selected_stable: Stable = null

# Track selected entity for live info updates
var selected_info_entity: Node = null

func _ready() -> void:
	layer = 100  # Above fog of war (layer 10)
	GameManager.resources_changed.connect(_update_resources)
	GameManager.population_changed.connect(_update_population)
	GameManager.game_over.connect(_on_game_over)
	GameManager.villager_idle.connect(_on_villager_idle)
	GameManager.market_prices_changed.connect(_update_market_prices)
	GameManager.player_under_attack.connect(_on_player_under_attack)
	_update_resources()
	_update_population()
	_update_market_prices()
	_setup_attack_notification()
	_setup_stance_buttons()
	tc_panel.visible = false
	barracks_panel.visible = false
	market_panel.visible = false
	archery_range_panel.visible = false
	stable_panel.visible = false
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
	# Live update info panel for selected entity (unit state changes, HP, etc.)
	_update_selected_entity_info()

	# Update Town Center queue
	if selected_tc:
		var queue_size = selected_tc.get_queue_size()
		tc_queue_label.text = "[%d]" % queue_size if queue_size > 0 else ""
		tc_cancel_button.visible = queue_size > 0
		if selected_tc.is_training:
			train_progress.value = selected_tc.get_train_progress() * 100
			train_progress.visible = true
		else:
			train_progress.visible = false
	else:
		train_progress.visible = false

	# Update Barracks queue
	if selected_barracks:
		var queue_size = selected_barracks.get_queue_size()
		barracks_queue_label.text = "[%d]" % queue_size if queue_size > 0 else ""
		barracks_cancel_button.visible = queue_size > 0
		if selected_barracks.is_training:
			barracks_train_progress.value = selected_barracks.get_train_progress() * 100
			barracks_train_progress.visible = true
		else:
			barracks_train_progress.visible = false
	else:
		barracks_train_progress.visible = false

	# Update Market queue
	if selected_market:
		var queue_size = selected_market.get_queue_size()
		market_queue_label.text = "[%d]" % queue_size if queue_size > 0 else ""
		market_cancel_button.visible = queue_size > 0
		if selected_market.is_training:
			market_train_progress.value = selected_market.get_train_progress() * 100
			market_train_progress.visible = true
		else:
			market_train_progress.visible = false
	else:
		market_train_progress.visible = false

	# Update Archery Range queue
	if selected_archery_range:
		var queue_size = selected_archery_range.get_queue_size()
		archery_range_queue_label.text = "[%d]" % queue_size if queue_size > 0 else ""
		archery_range_cancel_button.visible = queue_size > 0
		if selected_archery_range.is_training:
			archery_range_train_progress.value = selected_archery_range.get_train_progress() * 100
			archery_range_train_progress.visible = true
		else:
			archery_range_train_progress.visible = false
	else:
		archery_range_train_progress.visible = false

	# Update Stable queue
	if selected_stable:
		var queue_size = selected_stable.get_queue_size()
		stable_queue_label.text = "[%d]" % queue_size if queue_size > 0 else ""
		stable_cancel_button.visible = queue_size > 0
		if selected_stable.is_training:
			stable_train_progress.value = selected_stable.get_train_progress() * 100
			stable_train_progress.visible = true
		else:
			stable_train_progress.visible = false
	else:
		stable_train_progress.visible = false

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

func show_market_panel(market: Market) -> void:
	# Disconnect previous market signal if exists
	if selected_market and selected_market.training_completed.is_connected(_on_market_training_completed):
		selected_market.training_completed.disconnect(_on_market_training_completed)

	selected_market = market
	market_panel.visible = true
	tc_panel.visible = false
	barracks_panel.visible = false
	build_panel.visible = false
	_update_market_prices()
	if not market.training_completed.is_connected(_on_market_training_completed):
		market.training_completed.connect(_on_market_training_completed)

func hide_market_panel() -> void:
	if selected_market:
		if selected_market.training_completed.is_connected(_on_market_training_completed):
			selected_market.training_completed.disconnect(_on_market_training_completed)
	selected_market = null
	market_panel.visible = false
	build_panel.visible = true

func show_archery_range_panel(archery_range: ArcheryRange) -> void:
	# Disconnect previous archery range signal if exists
	if selected_archery_range and selected_archery_range.training_completed.is_connected(_on_archery_range_training_completed):
		selected_archery_range.training_completed.disconnect(_on_archery_range_training_completed)

	selected_archery_range = archery_range
	archery_range_panel.visible = true
	tc_panel.visible = false
	barracks_panel.visible = false
	market_panel.visible = false
	build_panel.visible = false
	if not archery_range.training_completed.is_connected(_on_archery_range_training_completed):
		archery_range.training_completed.connect(_on_archery_range_training_completed)

func hide_archery_range_panel() -> void:
	if selected_archery_range:
		if selected_archery_range.training_completed.is_connected(_on_archery_range_training_completed):
			selected_archery_range.training_completed.disconnect(_on_archery_range_training_completed)
	selected_archery_range = null
	archery_range_panel.visible = false
	build_panel.visible = true

func show_stable_panel(stable: Stable) -> void:
	# Disconnect previous stable signal if exists
	if selected_stable and selected_stable.training_completed.is_connected(_on_stable_training_completed):
		selected_stable.training_completed.disconnect(_on_stable_training_completed)

	selected_stable = stable
	stable_panel.visible = true
	tc_panel.visible = false
	barracks_panel.visible = false
	market_panel.visible = false
	archery_range_panel.visible = false
	build_panel.visible = false
	if not stable.training_completed.is_connected(_on_stable_training_completed):
		stable.training_completed.connect(_on_stable_training_completed)

func hide_stable_panel() -> void:
	if selected_stable:
		if selected_stable.training_completed.is_connected(_on_stable_training_completed):
			selected_stable.training_completed.disconnect(_on_stable_training_completed)
	selected_stable = null
	stable_panel.visible = false
	build_panel.visible = true

func _on_training_completed() -> void:
	train_progress.visible = false

func _on_barracks_training_completed() -> void:
	barracks_train_progress.visible = false

func _on_market_training_completed() -> void:
	market_train_progress.visible = false

func _on_archery_range_training_completed() -> void:
	archery_range_train_progress.visible = false

func _on_stable_training_completed() -> void:
	stable_train_progress.visible = false

func _update_market_prices() -> void:
	# Update buy button labels
	buy_wood_button.text = "Wood: %dg" % GameManager.get_market_buy_price("wood")
	buy_food_button.text = "Food: %dg" % GameManager.get_market_buy_price("food")
	buy_stone_button.text = "Stone: %dg" % GameManager.get_market_buy_price("stone")

	# Update sell button labels
	sell_wood_button.text = "Wood: %dg" % GameManager.get_market_sell_price("wood")
	sell_food_button.text = "Food: %dg" % GameManager.get_market_sell_price("food")
	sell_stone_button.text = "Stone: %dg" % GameManager.get_market_sell_price("stone")

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

func _on_train_spearman_pressed() -> void:
	if selected_barracks:
		if not selected_barracks.train_spearman():
			if not GameManager.can_afford("food", Barracks.SPEARMAN_FOOD_COST):
				_show_error("Not enough food! (Need 35)")
			elif not GameManager.can_afford("wood", Barracks.SPEARMAN_WOOD_COST):
				_show_error("Not enough wood! (Need 25)")
			elif not GameManager.can_add_population():
				_show_error("Population cap reached! Build a House.")

func _on_build_market_pressed() -> void:
	if not GameManager.can_afford("wood", 175):
		_show_error("Not enough wood! (Need 175)")
		return
	get_parent().start_market_placement()

func _on_build_archery_range_pressed() -> void:
	if not GameManager.can_afford("wood", 175):
		_show_error("Not enough wood! (Need 175)")
		return
	get_parent().start_archery_range_placement()

func _on_train_archer_pressed() -> void:
	if selected_archery_range:
		if not selected_archery_range.train_archer():
			if not GameManager.can_afford("wood", ArcheryRange.ARCHER_WOOD_COST):
				_show_error("Not enough wood! (Need 25)")
			elif not GameManager.can_afford("gold", ArcheryRange.ARCHER_GOLD_COST):
				_show_error("Not enough gold! (Need 45)")
			elif not GameManager.can_add_population():
				_show_error("Population cap reached! Build a House.")

func _on_train_skirmisher_pressed() -> void:
	if selected_archery_range:
		if not selected_archery_range.train_skirmisher():
			if not GameManager.can_afford("food", ArcheryRange.SKIRMISHER_FOOD_COST):
				_show_error("Not enough food! (Need 25)")
			elif not GameManager.can_afford("wood", ArcheryRange.SKIRMISHER_WOOD_COST):
				_show_error("Not enough wood! (Need 35)")
			elif not GameManager.can_add_population():
				_show_error("Population cap reached! Build a House.")

func _on_build_stable_pressed() -> void:
	if not GameManager.can_afford("wood", 175):
		_show_error("Not enough wood! (Need 175)")
		return
	get_parent().start_stable_placement()

func _on_train_scout_cavalry_pressed() -> void:
	if selected_stable:
		if not selected_stable.train_scout_cavalry():
			if not GameManager.can_afford("food", Stable.SCOUT_CAVALRY_FOOD_COST):
				_show_error("Not enough food! (Need 80)")
			elif not GameManager.can_add_population():
				_show_error("Population cap reached! Build a House.")

func _on_train_cavalry_archer_pressed() -> void:
	if selected_stable:
		if not selected_stable.train_cavalry_archer():
			if not GameManager.can_afford("wood", Stable.CAVALRY_ARCHER_WOOD_COST):
				_show_error("Not enough wood! (Need 40)")
			elif not GameManager.can_afford("gold", Stable.CAVALRY_ARCHER_GOLD_COST):
				_show_error("Not enough gold! (Need 70)")
			elif not GameManager.can_add_population():
				_show_error("Population cap reached! Build a House.")

# Market buy/sell handlers
func _on_buy_wood_pressed() -> void:
	if selected_market:
		if not selected_market.buy_resource("wood"):
			var price = GameManager.get_market_buy_price("wood")
			_show_error("Not enough gold! (Need %d)" % price)

func _on_buy_food_pressed() -> void:
	if selected_market:
		if not selected_market.buy_resource("food"):
			var price = GameManager.get_market_buy_price("food")
			_show_error("Not enough gold! (Need %d)" % price)

func _on_buy_stone_pressed() -> void:
	if selected_market:
		if not selected_market.buy_resource("stone"):
			var price = GameManager.get_market_buy_price("stone")
			_show_error("Not enough gold! (Need %d)" % price)

func _on_sell_wood_pressed() -> void:
	if selected_market:
		if not selected_market.sell_resource("wood"):
			_show_error("Not enough wood! (Need 100)")

func _on_sell_food_pressed() -> void:
	if selected_market:
		if not selected_market.sell_resource("food"):
			_show_error("Not enough food! (Need 100)")

func _on_sell_stone_pressed() -> void:
	if selected_market:
		if not selected_market.sell_resource("stone"):
			_show_error("Not enough stone! (Need 100)")

func _on_train_trade_cart_pressed() -> void:
	if selected_market:
		if not selected_market.train_trade_cart():
			if not GameManager.can_afford("wood", Market.TRADE_CART_WOOD_COST):
				_show_error("Not enough wood! (Need 100)")
			elif not GameManager.can_afford("gold", Market.TRADE_CART_GOLD_COST):
				_show_error("Not enough gold! (Need 50)")
			elif not GameManager.can_add_population():
				_show_error("Population cap reached! Build a House.")

func _show_error(message: String) -> void:
	error_label.text = message
	error_label.visible = true
	await get_tree().create_timer(2.0).timeout
	error_label.visible = false

func _on_villager_idle(_villager: Node, reason: String) -> void:
	# Show notification when villager goes idle
	_show_notification("Villager idle: " + reason)

func _show_notification(message: String) -> void:
	# Reuse error label for notifications (could be separate label in future)
	error_label.text = message
	error_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))  # Yellow for notifications
	error_label.visible = true
	await get_tree().create_timer(3.0).timeout
	error_label.visible = false
	error_label.remove_theme_color_override("font_color")  # Reset to default

func show_info(entity: Node) -> void:
	selected_info_entity = entity
	if entity is Villager:
		_show_villager_info(entity)
	elif entity is TradeCart:
		_show_trade_cart_info(entity)
	elif entity is Militia:
		_show_militia_info(entity)
	elif entity is Archer:
		_show_archer_info(entity)
	elif entity is Skirmisher:
		_show_skirmisher_info(entity)
	elif entity is CavalryArcher:
		_show_cavalry_archer_info(entity)
	elif entity is ScoutCavalry:
		_show_scout_cavalry_info(entity)
	elif entity is Spearman:
		_show_spearman_info(entity)
	elif entity is Sheep:
		_show_animal_info(entity, "Sheep", "Herdable. First to spot owns it.\nCan be stolen by enemies.")
	elif entity is Deer:
		_show_animal_info(entity, "Deer", "Huntable. Flees when attacked.")
	elif entity is Boar:
		_show_animal_info(entity, "Wild Boar", "Dangerous! Fights back.\nLure to TC with villagers.")
	elif entity is Wolf:
		_show_animal_info(entity, "Wolf", "Hostile! Attacks on sight.\nNo food yield.")
	elif entity is PelicanBicycle:
		_show_animal_info(entity, "Pelican on Bicycle", "A rare sight! Herdable.\nHow did it learn to ride?")
	elif entity is Animal:
		_show_animal_info(entity, "Animal", "")
	elif entity is Farm:
		_show_building_info("Farm", "Infinite food source\nGather rate: 0.5/sec", entity)
	elif entity is ResourceNode:
		_show_resource_info(entity)
	elif entity is TownCenter:
		_show_building_info("Town Center", "Trains villagers\nDeposit: all resources", entity)
	elif entity is Barracks:
		_show_building_info("Barracks", "Trains militia", entity)
	elif entity is House:
		_show_building_info("House", "+5 population cap", entity)
	elif entity is Mill:
		_show_building_info("Mill", "Deposit point for food", entity)
	elif entity is LumberCamp:
		_show_building_info("Lumber Camp", "Deposit point for wood", entity)
	elif entity is MiningCamp:
		_show_building_info("Mining Camp", "Deposit point for gold/stone", entity)
	elif entity is Market:
		_show_building_info("Market", "Buy/sell resources\nTrain Trade Carts", entity)
	elif entity is ArcheryRange:
		_show_building_info("Archery Range", "Trains ranged units\nArcher, Skirmisher", entity)
	elif entity is Stable:
		_show_building_info("Stable", "Trains cavalry units\nScout Cavalry, Cavalry Archer", entity)
	elif entity is Building:
		_show_building_info(entity.building_name, "", entity)
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
		Villager.State.HUNTING:
			state_text = "Hunting"

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
	show_stance_ui(militia)

func _show_archer_info(archer: Archer) -> void:
	info_title.text = "Archer"
	var state_text = ""
	match archer.current_state:
		Archer.State.IDLE:
			state_text = "Idle"
		Archer.State.MOVING:
			state_text = "Moving"
		Archer.State.ATTACKING:
			state_text = "Attacking"

	var details = "Status: %s\nHP: %d/%d\nAttack: %d\nRange: %d" % [state_text, archer.current_hp, archer.max_hp, archer.attack_damage, int(archer.attack_range / 32)]
	info_details.text = details
	info_panel.visible = true
	show_stance_ui(archer)

func _show_skirmisher_info(skirmisher: Skirmisher) -> void:
	info_title.text = "Skirmisher"
	var state_text = ""
	match skirmisher.current_state:
		Skirmisher.State.IDLE:
			state_text = "Idle"
		Skirmisher.State.MOVING:
			state_text = "Moving"
		Skirmisher.State.ATTACKING:
			state_text = "Attacking"

	var details = "Status: %s\nHP: %d/%d\nAttack: %d (+%d vs archers)\nArmor: %d/%d\nRange: %d" % [state_text, skirmisher.current_hp, skirmisher.max_hp, skirmisher.attack_damage, skirmisher.bonus_vs_archers, skirmisher.melee_armor, skirmisher.pierce_armor, int(skirmisher.attack_range / 32)]
	info_details.text = details
	info_panel.visible = true
	show_stance_ui(skirmisher)

func _show_cavalry_archer_info(cav_archer: CavalryArcher) -> void:
	info_title.text = "Cavalry Archer"
	var state_text = ""
	match cav_archer.current_state:
		CavalryArcher.State.IDLE:
			state_text = "Idle"
		CavalryArcher.State.MOVING:
			state_text = "Moving"
		CavalryArcher.State.ATTACKING:
			state_text = "Attacking"

	var details = "Status: %s\nHP: %d/%d\nAttack: %d\nRange: %d" % [state_text, cav_archer.current_hp, cav_archer.max_hp, cav_archer.attack_damage, int(cav_archer.attack_range / 32)]
	info_details.text = details
	info_panel.visible = true
	show_stance_ui(cav_archer)

func _show_scout_cavalry_info(cavalry: ScoutCavalry) -> void:
	info_title.text = "Scout Cavalry"
	var state_text = ""
	match cavalry.current_state:
		ScoutCavalry.State.IDLE:
			state_text = "Idle"
		ScoutCavalry.State.MOVING:
			state_text = "Moving"
		ScoutCavalry.State.ATTACKING:
			state_text = "Attacking"

	var details = "Status: %s\nHP: %d/%d\nAttack: %d\nArmor: %d/%d" % [state_text, cavalry.current_hp, cavalry.max_hp, cavalry.attack_damage, cavalry.melee_armor, cavalry.pierce_armor]
	info_details.text = details
	info_panel.visible = true
	show_stance_ui(cavalry)

func _show_spearman_info(spearman: Spearman) -> void:
	info_title.text = "Spearman"
	var state_text = ""
	match spearman.current_state:
		Spearman.State.IDLE:
			state_text = "Idle"
		Spearman.State.MOVING:
			state_text = "Moving"
		Spearman.State.ATTACKING:
			state_text = "Attacking"

	var details = "Status: %s\nHP: %d/%d\nAttack: %d (+%d vs cav)" % [state_text, spearman.current_hp, spearman.max_hp, spearman.attack_damage, spearman.bonus_vs_cavalry]
	info_details.text = details
	info_panel.visible = true
	show_stance_ui(spearman)

func _show_trade_cart_info(cart: TradeCart) -> void:
	info_title.text = "Trade Cart"
	var details = "HP: %d/%d\n%s" % [cart.current_hp, cart.max_hp, cart.get_trade_info()]
	info_details.text = details
	info_panel.visible = true

func _show_resource_info(resource: ResourceNode) -> void:
	var type_name: String
	if resource is FoodCarcass:
		type_name = "Carcass"
	else:
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
	info_details.text = "Resource: %s\nRemaining: %d" % [resource.resource_type.capitalize(), int(resource.current_amount)]
	info_panel.visible = true

func _show_animal_info(animal: Animal, title: String, description: String) -> void:
	info_title.text = title
	var owner_text = "Wild"
	if animal.team == 0:
		owner_text = "Player"
	elif animal.team == 1:
		owner_text = "AI"
	var details = "HP: %d/%d\nFood: %d\nOwner: %s" % [animal.current_hp, animal.max_hp, animal.food_amount, owner_text]
	if description != "":
		details += "\n" + description
	info_details.text = details
	info_panel.visible = true

func _show_building_info(title: String, details: String, building: Building = null) -> void:
	var display_title = title
	if building and building.team != 0:
		display_title = title + " (Enemy)"
	info_title.text = display_title
	info_details.text = details
	info_panel.visible = true

func hide_info() -> void:
	selected_info_entity = null
	info_panel.visible = false
	hide_stance_ui()

## Update info panel for selected entity (called every frame for live updates)
func _update_selected_entity_info() -> void:
	if not is_instance_valid(selected_info_entity):
		return
	if not info_panel.visible:
		return

	# Update unit info in real-time (state, HP, carrying, etc.)
	if selected_info_entity is Villager:
		_show_villager_info(selected_info_entity)
	elif selected_info_entity is Militia:
		_show_militia_info(selected_info_entity)
	elif selected_info_entity is Archer:
		_show_archer_info(selected_info_entity)
	elif selected_info_entity is Skirmisher:
		_show_skirmisher_info(selected_info_entity)
	elif selected_info_entity is CavalryArcher:
		_show_cavalry_archer_info(selected_info_entity)
	elif selected_info_entity is ScoutCavalry:
		_show_scout_cavalry_info(selected_info_entity)
	elif selected_info_entity is Spearman:
		_show_spearman_info(selected_info_entity)
	elif selected_info_entity is TradeCart:
		_show_trade_cart_info(selected_info_entity)
	elif selected_info_entity is Animal:
		# Animals also need live updates for HP
		if selected_info_entity is Sheep:
			_show_animal_info(selected_info_entity, "Sheep", "Herdable. First to spot owns it.\nCan be stolen by enemies.")
		elif selected_info_entity is Deer:
			_show_animal_info(selected_info_entity, "Deer", "Huntable. Flees when attacked.")
		elif selected_info_entity is Boar:
			_show_animal_info(selected_info_entity, "Wild Boar", "Dangerous! Fights back.\nLure to TC with villagers.")
		elif selected_info_entity is Wolf:
			_show_animal_info(selected_info_entity, "Wolf", "Hostile! Attacks on sight.\nNo food yield.")
		elif selected_info_entity is PelicanBicycle:
			_show_animal_info(selected_info_entity, "Pelican on Bicycle", "A rare sight! Herdable.\nHow did it learn to ride?")
	# Note: Resources and buildings don't need live updates as frequently

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
	selected_market = null
	selected_archery_range = null
	selected_stable = null
	GameManager.reset()
	get_tree().reload_current_scene()

## Setup attack notification label (created dynamically)
func _setup_attack_notification() -> void:
	attack_notification_label = Label.new()
	attack_notification_label.name = "AttackNotification"
	attack_notification_label.text = ""
	attack_notification_label.visible = false
	attack_notification_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	attack_notification_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	attack_notification_label.add_theme_font_size_override("font_size", 24)
	attack_notification_label.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
	# Position at top center of screen
	attack_notification_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	attack_notification_label.position = Vector2(-150, 50)
	attack_notification_label.custom_minimum_size = Vector2(300, 40)
	add_child(attack_notification_label)

## Called when player units/buildings are under attack
func _on_player_under_attack(attack_type: String) -> void:
	var message: String
	match attack_type:
		"military":
			message = "⚔ YOUR UNITS ARE UNDER ATTACK! ⚔"
		"villager":
			message = "🔔 YOUR VILLAGERS ARE UNDER ATTACK! 🔔"
		"building":
			message = "🏰 YOUR BUILDINGS ARE UNDER ATTACK! 🏰"
		_:
			message = "⚠ YOU ARE UNDER ATTACK! ⚠"

	attack_notification_label.text = message
	attack_notification_label.visible = true

	# Auto-hide after 3 seconds
	var tween = create_tween()
	tween.tween_interval(2.5)
	tween.tween_callback(func(): attack_notification_label.modulate.a = 1.0)
	tween.tween_property(attack_notification_label, "modulate:a", 0.0, 0.5)
	tween.tween_callback(func():
		attack_notification_label.visible = false
		attack_notification_label.modulate.a = 1.0
	)

## Setup stance buttons (added to info panel dynamically)
func _setup_stance_buttons() -> void:
	stance_container = HBoxContainer.new()
	stance_container.name = "StanceContainer"
	stance_container.visible = false
	stance_container.custom_minimum_size = Vector2(0, 30)

	var stance_names = ["AGG", "DEF", "SG", "NA"]
	var stance_tooltips = ["Aggressive: Chase and attack enemies", "Defensive: Attack nearby, limited chase", "Stand Ground: Attack in range only", "No Attack: Never auto-attack"]

	for i in range(4):
		var btn = Button.new()
		btn.text = stance_names[i]
		btn.tooltip_text = stance_tooltips[i]
		btn.custom_minimum_size = Vector2(40, 25)
		btn.pressed.connect(_on_stance_button_pressed.bind(i))
		stance_container.add_child(btn)
		stance_buttons.append(btn)

	# Add to info panel's VBoxContainer
	var vbox = info_panel.get_node("VBoxContainer")
	vbox.add_child(stance_container)

## Called when a stance button is pressed
func _on_stance_button_pressed(stance_index: int) -> void:
	if not is_instance_valid(selected_military_unit):
		return

	selected_military_unit.set_stance(stance_index)
	_update_stance_button_highlight()

## Update stance button highlighting to show current stance
func _update_stance_button_highlight() -> void:
	if not is_instance_valid(selected_military_unit):
		return

	for i in range(stance_buttons.size()):
		if i == selected_military_unit.stance:
			stance_buttons[i].add_theme_color_override("font_color", Color(0.2, 0.8, 0.2))
		else:
			stance_buttons[i].remove_theme_color_override("font_color")

## Show stance UI for a military unit
func show_stance_ui(unit: Unit) -> void:
	selected_military_unit = unit
	stance_container.visible = true
	_update_stance_button_highlight()

## Hide stance UI
func hide_stance_ui() -> void:
	selected_military_unit = null
	stance_container.visible = false

# Cancel button handlers
func _on_tc_cancel_pressed() -> void:
	if selected_tc:
		selected_tc.cancel_training()

func _on_barracks_cancel_pressed() -> void:
	if selected_barracks:
		selected_barracks.cancel_training()

func _on_market_cancel_pressed() -> void:
	if selected_market:
		selected_market.cancel_training()

func _on_archery_range_cancel_pressed() -> void:
	if selected_archery_range:
		selected_archery_range.cancel_training()

func _on_stable_cancel_pressed() -> void:
	if selected_stable:
		selected_stable.cancel_training()
