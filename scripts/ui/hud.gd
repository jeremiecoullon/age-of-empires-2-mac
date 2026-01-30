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
@onready var market_panel: PanelContainer = $MarketPanel
@onready var buy_wood_button: Button = $MarketPanel/VBoxContainer/PriceContainer/BuyColumn/BuyWoodButton
@onready var buy_food_button: Button = $MarketPanel/VBoxContainer/PriceContainer/BuyColumn/BuyFoodButton
@onready var buy_stone_button: Button = $MarketPanel/VBoxContainer/PriceContainer/BuyColumn/BuyStoneButton
@onready var sell_wood_button: Button = $MarketPanel/VBoxContainer/PriceContainer/SellColumn/SellWoodButton
@onready var sell_food_button: Button = $MarketPanel/VBoxContainer/PriceContainer/SellColumn/SellFoodButton
@onready var sell_stone_button: Button = $MarketPanel/VBoxContainer/PriceContainer/SellColumn/SellStoneButton
@onready var market_train_progress: ProgressBar = $MarketPanel/VBoxContainer/MarketTrainProgress
@onready var archery_range_panel: PanelContainer = $ArcheryRangePanel
@onready var archery_range_train_progress: ProgressBar = $ArcheryRangePanel/VBoxContainer/ArcheryRangeTrainProgress
@onready var stable_panel: PanelContainer = $StablePanel
@onready var stable_train_progress: ProgressBar = $StablePanel/VBoxContainer/StableTrainProgress
@onready var error_label: Label = $ErrorLabel
@onready var info_panel: PanelContainer = $InfoPanel
@onready var info_title: Label = $InfoPanel/VBoxContainer/InfoTitle
@onready var info_details: Label = $InfoPanel/VBoxContainer/InfoDetails
@onready var game_over_panel: PanelContainer = $GameOverPanel
@onready var game_over_label: Label = $GameOverPanel/VBoxContainer/GameOverLabel
@onready var restart_button: Button = $GameOverPanel/VBoxContainer/RestartButton

var selected_tc: TownCenter = null
var selected_barracks: Barracks = null
var selected_market: Market = null
var selected_archery_range: ArcheryRange = null
var selected_stable: Stable = null

func _ready() -> void:
	GameManager.resources_changed.connect(_update_resources)
	GameManager.population_changed.connect(_update_population)
	GameManager.game_over.connect(_on_game_over)
	GameManager.villager_idle.connect(_on_villager_idle)
	GameManager.market_prices_changed.connect(_update_market_prices)
	_update_resources()
	_update_population()
	_update_market_prices()
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

	if selected_market and selected_market.is_training:
		market_train_progress.value = selected_market.get_train_progress() * 100
		market_train_progress.visible = true
	else:
		market_train_progress.visible = false

	if selected_archery_range and selected_archery_range.is_training:
		archery_range_train_progress.value = selected_archery_range.get_train_progress() * 100
		archery_range_train_progress.visible = true
	else:
		archery_range_train_progress.visible = false

	if selected_stable and selected_stable.is_training:
		stable_train_progress.value = selected_stable.get_train_progress() * 100
		stable_train_progress.visible = true
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
	if entity is Villager:
		_show_villager_info(entity)
	elif entity is TradeCart:
		_show_trade_cart_info(entity)
	elif entity is Militia:
		_show_militia_info(entity)
	elif entity is Archer:
		_show_archer_info(entity)
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
	elif entity is Market:
		_show_building_info("Market", "Buy/sell resources\nTrain Trade Carts")
	elif entity is ArcheryRange:
		_show_building_info("Archery Range", "Trains ranged units\nArcher, Skirmisher")
	elif entity is Stable:
		_show_building_info("Stable", "Trains cavalry units\nScout Cavalry, Knight")
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
	selected_market = null
	selected_archery_range = null
	selected_stable = null
	GameManager.reset()
	get_tree().reload_current_scene()
