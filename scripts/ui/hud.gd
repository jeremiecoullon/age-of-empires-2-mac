extends CanvasLayer

## AoE2-style HUD with bottom panel (info, actions, minimap) and top resource bar

# Top bar
@onready var wood_label: Label = $TopBar/TopBarContent/WoodLabel
@onready var food_label: Label = $TopBar/TopBarContent/FoodLabel
@onready var gold_label: Label = $TopBar/TopBarContent/GoldLabel
@onready var stone_label: Label = $TopBar/TopBarContent/StoneLabel
@onready var pop_label: Label = $TopBar/TopBarContent/PopLabel
@onready var age_label: Label = $TopBar/TopBarContent/AgeLabel

# Left section - Info panel
@onready var info_title: Label = $BottomPanel/BottomContent/LeftSection/InfoContainer/InfoTitle
@onready var hp_bar: ProgressBar = $BottomPanel/BottomContent/LeftSection/InfoContainer/HPContainer/HPBar
@onready var hp_label: Label = $BottomPanel/BottomContent/LeftSection/InfoContainer/HPContainer/HPLabel
@onready var attack_label: Label = $BottomPanel/BottomContent/LeftSection/InfoContainer/StatsContainer/AttackLabel
@onready var armor_label: Label = $BottomPanel/BottomContent/LeftSection/InfoContainer/StatsContainer/ArmorLabel
@onready var info_details: Label = $BottomPanel/BottomContent/LeftSection/InfoContainer/InfoDetails

# Center section - Actions
@onready var action_title: Label = $BottomPanel/BottomContent/CenterSection/ActionContainer/ActionTitle
@onready var action_grid: GridContainer = $BottomPanel/BottomContent/CenterSection/ActionContainer/ActionGrid

# Build buttons
@onready var build_house_btn: Button = $BottomPanel/BottomContent/CenterSection/ActionContainer/ActionGrid/BuildHouseButton
@onready var build_barracks_btn: Button = $BottomPanel/BottomContent/CenterSection/ActionContainer/ActionGrid/BuildBarracksButton
@onready var build_farm_btn: Button = $BottomPanel/BottomContent/CenterSection/ActionContainer/ActionGrid/BuildFarmButton
@onready var build_mill_btn: Button = $BottomPanel/BottomContent/CenterSection/ActionContainer/ActionGrid/BuildMillButton
@onready var build_lumber_camp_btn: Button = $BottomPanel/BottomContent/CenterSection/ActionContainer/ActionGrid/BuildLumberCampButton
@onready var build_mining_camp_btn: Button = $BottomPanel/BottomContent/CenterSection/ActionContainer/ActionGrid/BuildMiningCampButton
@onready var build_market_btn: Button = $BottomPanel/BottomContent/CenterSection/ActionContainer/ActionGrid/BuildMarketButton
@onready var build_archery_range_btn: Button = $BottomPanel/BottomContent/CenterSection/ActionContainer/ActionGrid/BuildArcheryRangeButton
@onready var build_stable_btn: Button = $BottomPanel/BottomContent/CenterSection/ActionContainer/ActionGrid/BuildStableButton

# Train buttons
@onready var train_villager_btn: Button = $BottomPanel/BottomContent/CenterSection/ActionContainer/ActionGrid/TrainVillagerButton
@onready var train_militia_btn: Button = $BottomPanel/BottomContent/CenterSection/ActionContainer/ActionGrid/TrainMilitiaButton
@onready var train_spearman_btn: Button = $BottomPanel/BottomContent/CenterSection/ActionContainer/ActionGrid/TrainSpearmanButton
@onready var train_archer_btn: Button = $BottomPanel/BottomContent/CenterSection/ActionContainer/ActionGrid/TrainArcherButton
@onready var train_skirmisher_btn: Button = $BottomPanel/BottomContent/CenterSection/ActionContainer/ActionGrid/TrainSkirmisherButton
@onready var train_scout_cavalry_btn: Button = $BottomPanel/BottomContent/CenterSection/ActionContainer/ActionGrid/TrainScoutCavalryButton
@onready var train_cavalry_archer_btn: Button = $BottomPanel/BottomContent/CenterSection/ActionContainer/ActionGrid/TrainCavalryArcherButton

# Market buttons
@onready var buy_wood_btn: Button = $BottomPanel/BottomContent/CenterSection/ActionContainer/ActionGrid/BuyWoodButton
@onready var buy_food_btn: Button = $BottomPanel/BottomContent/CenterSection/ActionContainer/ActionGrid/BuyFoodButton
@onready var buy_stone_btn: Button = $BottomPanel/BottomContent/CenterSection/ActionContainer/ActionGrid/BuyStoneButton
@onready var sell_wood_btn: Button = $BottomPanel/BottomContent/CenterSection/ActionContainer/ActionGrid/SellWoodButton
@onready var sell_food_btn: Button = $BottomPanel/BottomContent/CenterSection/ActionContainer/ActionGrid/SellFoodButton
@onready var sell_stone_btn: Button = $BottomPanel/BottomContent/CenterSection/ActionContainer/ActionGrid/SellStoneButton
@onready var train_trade_cart_btn: Button = $BottomPanel/BottomContent/CenterSection/ActionContainer/ActionGrid/TrainTradeCartButton

# Queue and cancel
@onready var cancel_btn: Button = $BottomPanel/BottomContent/CenterSection/ActionContainer/ActionGrid/CancelButton
@onready var train_progress: ProgressBar = $BottomPanel/BottomContent/CenterSection/ActionContainer/QueueContainer/TrainProgress
@onready var queue_label: Label = $BottomPanel/BottomContent/CenterSection/ActionContainer/QueueContainer/QueueLabel

# Stance buttons
@onready var stance_container: HBoxContainer = $BottomPanel/BottomContent/CenterSection/ActionContainer/StanceContainer
@onready var stance_agg_btn: Button = $BottomPanel/BottomContent/CenterSection/ActionContainer/StanceContainer/StanceAgg
@onready var stance_def_btn: Button = $BottomPanel/BottomContent/CenterSection/ActionContainer/StanceContainer/StanceDef
@onready var stance_sg_btn: Button = $BottomPanel/BottomContent/CenterSection/ActionContainer/StanceContainer/StanceSG
@onready var stance_na_btn: Button = $BottomPanel/BottomContent/CenterSection/ActionContainer/StanceContainer/StanceNA

# Minimap
@onready var minimap: Minimap = $BottomPanel/BottomContent/RightSection/Minimap

# Overlays
@onready var error_label: Label = $ErrorLabel
@onready var game_over_panel: PanelContainer = $GameOverPanel
@onready var game_over_label: Label = $GameOverPanel/VBoxContainer/GameOverLabel
@onready var restart_button: Button = $GameOverPanel/VBoxContainer/RestartButton

# Attack notification (created dynamically)
var attack_notification_label: Label = null

# Currently selected building (for training)
var selected_building: Building = null
var selected_building_type: String = ""  # "tc", "barracks", "market", "archery_range", "stable"

# Track selected entity for info panel updates
var selected_info_entity: Node = null

# Track selected military unit for stance buttons
var selected_military_unit: Unit = null

# Notification counter to prevent race conditions
var _notification_counter: int = 0

# All action buttons for easy hide/show
var build_buttons: Array[Button] = []
var tc_buttons: Array[Button] = []
var barracks_buttons: Array[Button] = []
var archery_range_buttons: Array[Button] = []
var stable_buttons: Array[Button] = []
var market_buttons: Array[Button] = []


func _ready() -> void:
	layer = 100  # Above fog of war

	# Connect signals
	GameManager.resources_changed.connect(_update_resources)
	GameManager.population_changed.connect(_update_population)
	GameManager.game_over.connect(_on_game_over)
	GameManager.villager_idle.connect(_on_villager_idle)
	GameManager.market_prices_changed.connect(_update_market_prices)
	GameManager.player_under_attack.connect(_on_player_under_attack)

	# Group buttons for easier management
	build_buttons = [build_house_btn, build_barracks_btn, build_farm_btn, build_mill_btn,
					 build_lumber_camp_btn, build_mining_camp_btn, build_market_btn,
					 build_archery_range_btn, build_stable_btn]
	tc_buttons = [train_villager_btn]
	barracks_buttons = [train_militia_btn, train_spearman_btn]
	archery_range_buttons = [train_archer_btn, train_skirmisher_btn]
	stable_buttons = [train_scout_cavalry_btn, train_cavalry_archer_btn]
	market_buttons = [buy_wood_btn, buy_food_btn, buy_stone_btn,
					  sell_wood_btn, sell_food_btn, sell_stone_btn, train_trade_cart_btn]

	# Initial update
	_update_resources()
	_update_population()
	_update_market_prices()
	_setup_attack_notification()

	# Hide all action buttons initially
	_hide_all_action_buttons()
	game_over_panel.visible = false
	error_label.visible = false


func _update_resources() -> void:
	wood_label.text = "%d" % GameManager.get_resource("wood")
	food_label.text = "%d" % GameManager.get_resource("food")
	gold_label.text = "%d" % GameManager.get_resource("gold")
	stone_label.text = "%d" % GameManager.get_resource("stone")


func _update_population() -> void:
	pop_label.text = "%d/%d" % [GameManager.get_population(), GameManager.get_population_cap()]


func _process(_delta: float) -> void:
	# Live update info panel
	_update_selected_entity_info()

	# Update production queue progress
	_update_production_progress()


func _update_production_progress() -> void:
	if not selected_building or not is_instance_valid(selected_building):
		train_progress.visible = false
		queue_label.text = ""
		cancel_btn.visible = false
		return

	var queue_size = selected_building.get_queue_size()
	queue_label.text = "[%d]" % queue_size if queue_size > 0 else ""
	cancel_btn.visible = queue_size > 0

	if selected_building.is_training:
		train_progress.value = selected_building.get_train_progress() * 100
		train_progress.visible = true
	else:
		train_progress.visible = false


func _hide_all_action_buttons() -> void:
	for btn in build_buttons:
		btn.visible = false
	for btn in tc_buttons:
		btn.visible = false
	for btn in barracks_buttons:
		btn.visible = false
	for btn in archery_range_buttons:
		btn.visible = false
	for btn in stable_buttons:
		btn.visible = false
	for btn in market_buttons:
		btn.visible = false
	cancel_btn.visible = false
	train_progress.visible = false
	queue_label.text = ""
	stance_container.visible = false


func _show_build_buttons() -> void:
	_hide_all_action_buttons()
	for btn in build_buttons:
		btn.visible = true
	action_title.text = "Build"


func _show_tc_buttons(tc: TownCenter) -> void:
	_hide_all_action_buttons()
	for btn in tc_buttons:
		btn.visible = true
	action_title.text = "Town Center"
	selected_building = tc
	selected_building_type = "tc"


func _show_barracks_buttons(barracks: Barracks) -> void:
	_hide_all_action_buttons()
	for btn in barracks_buttons:
		btn.visible = true
	action_title.text = "Barracks"
	selected_building = barracks
	selected_building_type = "barracks"


func _show_archery_range_buttons(archery_range: ArcheryRange) -> void:
	_hide_all_action_buttons()
	for btn in archery_range_buttons:
		btn.visible = true
	action_title.text = "Archery Range"
	selected_building = archery_range
	selected_building_type = "archery_range"


func _show_stable_buttons(stable: Stable) -> void:
	_hide_all_action_buttons()
	for btn in stable_buttons:
		btn.visible = true
	action_title.text = "Stable"
	selected_building = stable
	selected_building_type = "stable"


func _show_market_buttons(market: Market) -> void:
	_hide_all_action_buttons()
	for btn in market_buttons:
		btn.visible = true
	action_title.text = "Market"
	selected_building = market
	selected_building_type = "market"
	_update_market_prices()


func _update_market_prices() -> void:
	buy_wood_btn.text = "Buy Wood: %dg" % GameManager.get_market_buy_price("wood")
	buy_food_btn.text = "Buy Food: %dg" % GameManager.get_market_buy_price("food")
	buy_stone_btn.text = "Buy Stone: %dg" % GameManager.get_market_buy_price("stone")
	sell_wood_btn.text = "Sell Wood: %dg" % GameManager.get_market_sell_price("wood")
	sell_food_btn.text = "Sell Food: %dg" % GameManager.get_market_sell_price("food")
	sell_stone_btn.text = "Sell Stone: %dg" % GameManager.get_market_sell_price("stone")


# ============================================================================
# Public interface for main.gd to show info/actions
# ============================================================================

func show_info(entity: Node) -> void:
	selected_info_entity = entity
	_hide_all_action_buttons()
	selected_building = null
	selected_building_type = ""
	selected_military_unit = null

	if entity is Villager:
		_show_villager_info(entity)
		if entity.team == 0:
			_show_build_buttons()
	elif entity is TradeCart:
		_show_trade_cart_info(entity)
	elif entity is Militia:
		_show_military_info(entity, "Militia")
	elif entity is Archer:
		_show_military_info(entity, "Archer")
	elif entity is Skirmisher:
		_show_military_info(entity, "Skirmisher")
	elif entity is CavalryArcher:
		_show_military_info(entity, "Cavalry Archer")
	elif entity is ScoutCavalry:
		_show_military_info(entity, "Scout Cavalry")
	elif entity is Spearman:
		_show_military_info(entity, "Spearman")
	elif entity is Sheep:
		_show_animal_info(entity, "Sheep", "Herdable. First to spot owns it.")
	elif entity is Deer:
		_show_animal_info(entity, "Deer", "Huntable. Flees when attacked.")
	elif entity is Boar:
		_show_animal_info(entity, "Wild Boar", "Dangerous! Fights back.")
	elif entity is Wolf:
		_show_animal_info(entity, "Wolf", "Hostile! No food yield.")
	elif entity is PelicanBicycle:
		_show_animal_info(entity, "Pelican on Bicycle", "A rare sight!")
	elif entity is Animal:
		_show_animal_info(entity, "Animal", "")
	elif entity is Farm:
		_show_building_info("Farm", "Infinite food\nGather: 0.5/sec", entity)
	elif entity is ResourceNode:
		_show_resource_info(entity)
	elif entity is TownCenter:
		_show_building_info("Town Center", "Trains villagers\nDrop-off: all", entity)
		if entity.team == 0 and entity.is_functional():
			_show_tc_buttons(entity)
	elif entity is Barracks:
		_show_building_info("Barracks", "Trains infantry", entity)
		if entity.team == 0 and entity.is_functional():
			_show_barracks_buttons(entity)
	elif entity is House:
		_show_building_info("House", "+5 population cap", entity)
	elif entity is Mill:
		_show_building_info("Mill", "Drop-off: food", entity)
	elif entity is LumberCamp:
		_show_building_info("Lumber Camp", "Drop-off: wood", entity)
	elif entity is MiningCamp:
		_show_building_info("Mining Camp", "Drop-off: gold/stone", entity)
	elif entity is Market:
		_show_building_info("Market", "Buy/sell resources", entity)
		if entity.team == 0 and entity.is_functional():
			_show_market_buttons(entity)
	elif entity is ArcheryRange:
		_show_building_info("Archery Range", "Trains ranged units", entity)
		if entity.team == 0 and entity.is_functional():
			_show_archery_range_buttons(entity)
	elif entity is Stable:
		_show_building_info("Stable", "Trains cavalry", entity)
		if entity.team == 0 and entity.is_functional():
			_show_stable_buttons(entity)
	elif entity is Building:
		_show_building_info(entity.building_name, "", entity)
	else:
		hide_info()


func show_tc_panel(tc: TownCenter) -> void:
	show_info(tc)

func hide_tc_panel() -> void:
	if selected_building_type == "tc":
		_hide_all_action_buttons()
		selected_building = null
		selected_building_type = ""

func show_barracks_panel(barracks: Barracks) -> void:
	show_info(barracks)

func hide_barracks_panel() -> void:
	if selected_building_type == "barracks":
		_hide_all_action_buttons()
		selected_building = null
		selected_building_type = ""

func show_market_panel(market: Market) -> void:
	show_info(market)

func hide_market_panel() -> void:
	if selected_building_type == "market":
		_hide_all_action_buttons()
		selected_building = null
		selected_building_type = ""

func show_archery_range_panel(archery_range: ArcheryRange) -> void:
	show_info(archery_range)

func hide_archery_range_panel() -> void:
	if selected_building_type == "archery_range":
		_hide_all_action_buttons()
		selected_building = null
		selected_building_type = ""

func show_stable_panel(stable: Stable) -> void:
	show_info(stable)

func hide_stable_panel() -> void:
	if selected_building_type == "stable":
		_hide_all_action_buttons()
		selected_building = null
		selected_building_type = ""


func hide_info() -> void:
	selected_info_entity = null
	selected_building = null
	selected_building_type = ""
	selected_military_unit = null
	info_title.text = "Select a unit"
	hp_bar.value = 100
	hp_label.text = ""
	attack_label.text = ""
	armor_label.text = ""
	info_details.text = ""
	action_title.text = "Actions"
	_hide_all_action_buttons()


# ============================================================================
# Info panel display functions
# ============================================================================

func _show_villager_info(villager: Villager) -> void:
	info_title.text = "Villager"
	hp_bar.max_value = villager.max_hp
	hp_bar.value = villager.current_hp
	hp_label.text = "%d/%d" % [villager.current_hp, villager.max_hp]
	attack_label.text = "⚔️ 3"
	armor_label.text = "🛡️ 0/0"

	var state_text = ""
	match villager.current_state:
		Villager.State.IDLE:
			state_text = "Idle"
		Villager.State.MOVING:
			state_text = "Moving"
		Villager.State.GATHERING:
			state_text = "Gathering " + villager.carried_resource_type
		Villager.State.RETURNING:
			state_text = "Returning"
		Villager.State.HUNTING:
			state_text = "Hunting"
		Villager.State.BUILDING:
			state_text = "Building"

	var details = "Status: %s" % state_text
	if villager.carried_amount > 0:
		details += "\nCarrying: %d %s" % [villager.carried_amount, villager.carried_resource_type]
	info_details.text = details


func _show_military_info(unit: Unit, unit_name: String) -> void:
	info_title.text = unit_name
	hp_bar.max_value = unit.max_hp
	hp_bar.value = unit.current_hp
	hp_label.text = "%d/%d" % [unit.current_hp, unit.max_hp]

	var attack = unit.attack_damage if "attack_damage" in unit else 0
	var melee_armor = unit.melee_armor if "melee_armor" in unit else 0
	var pierce_armor = unit.pierce_armor if "pierce_armor" in unit else 0

	attack_label.text = "⚔️ %d" % attack
	armor_label.text = "🛡️ %d/%d" % [melee_armor, pierce_armor]

	var state_text = "Idle"
	if "current_state" in unit:
		match unit.current_state:
			0: state_text = "Idle"  # State.IDLE
			1: state_text = "Moving"  # State.MOVING
			2: state_text = "Attacking"  # State.ATTACKING

	info_details.text = "Status: %s" % state_text

	# Show stance buttons for player military units
	if unit.team == 0 and unit.is_in_group("military"):
		selected_military_unit = unit
		stance_container.visible = true
		_update_stance_highlight()


func _show_trade_cart_info(cart: TradeCart) -> void:
	info_title.text = "Trade Cart"
	hp_bar.max_value = cart.max_hp
	hp_bar.value = cart.current_hp
	hp_label.text = "%d/%d" % [cart.current_hp, cart.max_hp]
	attack_label.text = ""
	armor_label.text = ""
	info_details.text = cart.get_trade_info()


func _show_animal_info(animal: Animal, title: String, description: String) -> void:
	info_title.text = title
	hp_bar.max_value = animal.max_hp
	hp_bar.value = animal.current_hp
	hp_label.text = "%d/%d" % [animal.current_hp, animal.max_hp]
	attack_label.text = ""
	armor_label.text = ""

	var owner_text = "Wild"
	if animal.team == 0:
		owner_text = "Player"
	elif animal.team == 1:
		owner_text = "AI"

	info_details.text = "Food: %d | Owner: %s\n%s" % [animal.food_amount, owner_text, description]


func _show_building_info(title: String, details: String, building: Building) -> void:
	var display_title = title
	if building.team != 0:
		display_title = title + " (Enemy)"
	elif not building.is_constructed:
		display_title = title + " (Building)"

	info_title.text = display_title
	hp_bar.max_value = building.max_hp
	hp_bar.value = building.current_hp
	hp_label.text = "%d/%d" % [building.current_hp, building.max_hp]
	attack_label.text = ""
	armor_label.text = ""

	if not building.is_constructed:
		info_details.text = "Progress: %d%%\nBuilders: %d\n[DEL to cancel]" % [
			building.get_construction_percent(),
			building.get_builder_count()
		]
	else:
		info_details.text = details


func _show_resource_info(resource: ResourceNode) -> void:
	var type_name: String
	if resource is FoodCarcass:
		type_name = "Carcass"
	else:
		match resource.resource_type:
			"wood": type_name = "Tree"
			"food": type_name = "Berry Bush"
			"gold": type_name = "Gold Mine"
			"stone": type_name = "Stone Mine"
			_: type_name = "Resource"

	info_title.text = type_name
	hp_bar.value = 0
	hp_label.text = ""
	attack_label.text = ""
	armor_label.text = ""
	info_details.text = "%s: %d remaining" % [resource.resource_type.capitalize(), int(resource.current_amount)]


func _update_selected_entity_info() -> void:
	if not is_instance_valid(selected_info_entity):
		return

	# Live update for units and buildings
	if selected_info_entity is Villager:
		# Villager has special state text - delegate to full info display
		_show_villager_info(selected_info_entity as Villager)
	elif selected_info_entity is TradeCart:
		# Trade cart needs HP and trade info
		var cart = selected_info_entity as TradeCart
		hp_bar.max_value = cart.max_hp
		hp_bar.value = cart.current_hp
		hp_label.text = "%d/%d" % [cart.current_hp, cart.max_hp]
		info_details.text = cart.get_trade_info()
	elif selected_info_entity is Unit:
		# Generic military unit - just update HP
		var unit = selected_info_entity as Unit
		hp_bar.max_value = unit.max_hp
		hp_bar.value = unit.current_hp
		hp_label.text = "%d/%d" % [unit.current_hp, unit.max_hp]
	elif selected_info_entity is Building:
		var building = selected_info_entity as Building
		hp_bar.max_value = building.max_hp
		hp_bar.value = building.current_hp
		hp_label.text = "%d/%d" % [building.current_hp, building.max_hp]

		if not building.is_constructed:
			info_details.text = "Progress: %d%%\nBuilders: %d\n[DEL to cancel]" % [
				building.get_construction_percent(),
				building.get_builder_count()
			]
	elif selected_info_entity is Animal:
		var animal = selected_info_entity as Animal
		hp_bar.max_value = animal.max_hp
		hp_bar.value = animal.current_hp
		hp_label.text = "%d/%d" % [animal.current_hp, animal.max_hp]


# ============================================================================
# Stance buttons
# ============================================================================

func _update_stance_highlight() -> void:
	if not is_instance_valid(selected_military_unit):
		return

	var buttons = [stance_agg_btn, stance_def_btn, stance_sg_btn, stance_na_btn]
	for i in range(buttons.size()):
		if i == selected_military_unit.stance:
			buttons[i].add_theme_color_override("font_color", Color(0.2, 0.8, 0.2))
		else:
			buttons[i].remove_theme_color_override("font_color")


func _on_stance_agg_pressed() -> void:
	if is_instance_valid(selected_military_unit):
		selected_military_unit.set_stance(0)
		_update_stance_highlight()

func _on_stance_def_pressed() -> void:
	if is_instance_valid(selected_military_unit):
		selected_military_unit.set_stance(1)
		_update_stance_highlight()

func _on_stance_sg_pressed() -> void:
	if is_instance_valid(selected_military_unit):
		selected_military_unit.set_stance(2)
		_update_stance_highlight()

func _on_stance_na_pressed() -> void:
	if is_instance_valid(selected_military_unit):
		selected_military_unit.set_stance(3)
		_update_stance_highlight()


# ============================================================================
# Building construction deletion
# ============================================================================

func delete_selected_building() -> bool:
	if not is_instance_valid(selected_info_entity):
		return false

	if not selected_info_entity is Building:
		return false

	var building = selected_info_entity as Building

	if building.team != 0:
		_show_error("Cannot delete enemy buildings!")
		return false

	if building.is_constructed:
		_show_error("Cannot delete completed buildings!")
		return false

	# Calculate refund
	var refund_ratio = 1.0 - building.construction_progress
	var wood_refund = int(building.wood_cost * refund_ratio)
	var food_refund = int(building.food_cost * refund_ratio)

	if wood_refund > 0:
		GameManager.add_resource("wood", wood_refund, 0)
	if food_refund > 0:
		GameManager.add_resource("food", food_refund, 0)

	# Release builders
	for builder in building.builders.duplicate():
		if is_instance_valid(builder):
			building.remove_builder(builder)
			builder.target_construction = null
			builder.current_state = Villager.State.IDLE

	building.queue_free()
	selected_info_entity = null
	hide_info()

	var total_refund = wood_refund + food_refund
	if total_refund > 0:
		_show_notification("Cancelled (refunded %d)" % total_refund)
	else:
		_show_notification("Construction cancelled")
	return true


# ============================================================================
# Action button handlers
# ============================================================================

func _on_build_house_pressed() -> void:
	if not GameManager.can_afford("wood", 25):
		_show_error("Need 25 wood!")
		return
	get_parent().start_house_placement()

func _on_build_barracks_pressed() -> void:
	if not GameManager.can_afford("wood", 100):
		_show_error("Need 100 wood!")
		return
	get_parent().start_barracks_placement()

func _on_build_farm_pressed() -> void:
	if not GameManager.can_afford("wood", 50):
		_show_error("Need 50 wood!")
		return
	get_parent().start_farm_placement()

func _on_build_mill_pressed() -> void:
	if not GameManager.can_afford("wood", 100):
		_show_error("Need 100 wood!")
		return
	get_parent().start_mill_placement()

func _on_build_lumber_camp_pressed() -> void:
	if not GameManager.can_afford("wood", 100):
		_show_error("Need 100 wood!")
		return
	get_parent().start_lumber_camp_placement()

func _on_build_mining_camp_pressed() -> void:
	if not GameManager.can_afford("wood", 100):
		_show_error("Need 100 wood!")
		return
	get_parent().start_mining_camp_placement()

func _on_build_market_pressed() -> void:
	if not GameManager.can_afford("wood", 175):
		_show_error("Need 175 wood!")
		return
	get_parent().start_market_placement()

func _on_build_archery_range_pressed() -> void:
	if not GameManager.can_afford("wood", 175):
		_show_error("Need 175 wood!")
		return
	get_parent().start_archery_range_placement()

func _on_build_stable_pressed() -> void:
	if not GameManager.can_afford("wood", 175):
		_show_error("Need 175 wood!")
		return
	get_parent().start_stable_placement()


func _on_train_villager_pressed() -> void:
	if selected_building is TownCenter:
		var tc = selected_building as TownCenter
		if not tc.train_villager():
			if not GameManager.can_afford("food", TownCenter.VILLAGER_COST):
				_show_error("Need 50 food!")
			elif not GameManager.can_add_population():
				_show_error("Pop cap reached!")

func _on_train_militia_pressed() -> void:
	if selected_building is Barracks:
		var barracks = selected_building as Barracks
		if not barracks.train_militia():
			if not GameManager.can_afford("food", Barracks.MILITIA_FOOD_COST):
				_show_error("Need 60 food!")
			elif not GameManager.can_afford("wood", Barracks.MILITIA_WOOD_COST):
				_show_error("Need 20 wood!")
			elif not GameManager.can_add_population():
				_show_error("Pop cap reached!")

func _on_train_spearman_pressed() -> void:
	if selected_building is Barracks:
		var barracks = selected_building as Barracks
		if not barracks.train_spearman():
			if not GameManager.can_afford("food", Barracks.SPEARMAN_FOOD_COST):
				_show_error("Need 35 food!")
			elif not GameManager.can_afford("wood", Barracks.SPEARMAN_WOOD_COST):
				_show_error("Need 25 wood!")
			elif not GameManager.can_add_population():
				_show_error("Pop cap reached!")

func _on_train_archer_pressed() -> void:
	if selected_building is ArcheryRange:
		var ar = selected_building as ArcheryRange
		if not ar.train_archer():
			if not GameManager.can_afford("wood", ArcheryRange.ARCHER_WOOD_COST):
				_show_error("Need 25 wood!")
			elif not GameManager.can_afford("gold", ArcheryRange.ARCHER_GOLD_COST):
				_show_error("Need 45 gold!")
			elif not GameManager.can_add_population():
				_show_error("Pop cap reached!")

func _on_train_skirmisher_pressed() -> void:
	if selected_building is ArcheryRange:
		var ar = selected_building as ArcheryRange
		if not ar.train_skirmisher():
			if not GameManager.can_afford("food", ArcheryRange.SKIRMISHER_FOOD_COST):
				_show_error("Need 25 food!")
			elif not GameManager.can_afford("wood", ArcheryRange.SKIRMISHER_WOOD_COST):
				_show_error("Need 35 wood!")
			elif not GameManager.can_add_population():
				_show_error("Pop cap reached!")

func _on_train_scout_cavalry_pressed() -> void:
	if selected_building is Stable:
		var stable = selected_building as Stable
		if not stable.train_scout_cavalry():
			if not GameManager.can_afford("food", Stable.SCOUT_CAVALRY_FOOD_COST):
				_show_error("Need 80 food!")
			elif not GameManager.can_add_population():
				_show_error("Pop cap reached!")

func _on_train_cavalry_archer_pressed() -> void:
	if selected_building is Stable:
		var stable = selected_building as Stable
		if not stable.train_cavalry_archer():
			if not GameManager.can_afford("wood", Stable.CAVALRY_ARCHER_WOOD_COST):
				_show_error("Need 40 wood!")
			elif not GameManager.can_afford("gold", Stable.CAVALRY_ARCHER_GOLD_COST):
				_show_error("Need 70 gold!")
			elif not GameManager.can_add_population():
				_show_error("Pop cap reached!")


func _on_buy_wood_pressed() -> void:
	if selected_building is Market:
		var market = selected_building as Market
		if not market.buy_resource("wood"):
			_show_error("Need %d gold!" % GameManager.get_market_buy_price("wood"))

func _on_buy_food_pressed() -> void:
	if selected_building is Market:
		var market = selected_building as Market
		if not market.buy_resource("food"):
			_show_error("Need %d gold!" % GameManager.get_market_buy_price("food"))

func _on_buy_stone_pressed() -> void:
	if selected_building is Market:
		var market = selected_building as Market
		if not market.buy_resource("stone"):
			_show_error("Need %d gold!" % GameManager.get_market_buy_price("stone"))

func _on_sell_wood_pressed() -> void:
	if selected_building is Market:
		var market = selected_building as Market
		if not market.sell_resource("wood"):
			_show_error("Need 100 wood!")

func _on_sell_food_pressed() -> void:
	if selected_building is Market:
		var market = selected_building as Market
		if not market.sell_resource("food"):
			_show_error("Need 100 food!")

func _on_sell_stone_pressed() -> void:
	if selected_building is Market:
		var market = selected_building as Market
		if not market.sell_resource("stone"):
			_show_error("Need 100 stone!")

func _on_train_trade_cart_pressed() -> void:
	if selected_building is Market:
		var market = selected_building as Market
		if not market.train_trade_cart():
			if not GameManager.can_afford("wood", Market.TRADE_CART_WOOD_COST):
				_show_error("Need 100 wood!")
			elif not GameManager.can_afford("gold", Market.TRADE_CART_GOLD_COST):
				_show_error("Need 50 gold!")
			elif not GameManager.can_add_population():
				_show_error("Pop cap reached!")


func _on_cancel_pressed() -> void:
	if selected_building and is_instance_valid(selected_building):
		selected_building.cancel_training()


# ============================================================================
# Minimap
# ============================================================================

func _on_minimap_clicked(world_position: Vector2) -> void:
	var camera = get_viewport().get_camera_2d()
	if is_instance_valid(camera) and camera.has_method("jump_to"):
		camera.jump_to(world_position)


# ============================================================================
# Notifications and overlays
# ============================================================================

func _show_error(message: String) -> void:
	_notification_counter += 1
	var my_counter = _notification_counter
	error_label.text = message
	error_label.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
	error_label.visible = true
	await get_tree().create_timer(2.0).timeout
	if my_counter == _notification_counter:
		error_label.visible = false

func _show_notification(message: String) -> void:
	_notification_counter += 1
	var my_counter = _notification_counter
	error_label.text = message
	error_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
	error_label.visible = true
	await get_tree().create_timer(3.0).timeout
	if my_counter == _notification_counter:
		error_label.visible = false

func _on_villager_idle(_villager: Node, reason: String) -> void:
	_show_notification("Villager idle: " + reason)


func _setup_attack_notification() -> void:
	attack_notification_label = Label.new()
	attack_notification_label.name = "AttackNotification"
	attack_notification_label.text = ""
	attack_notification_label.visible = false
	attack_notification_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	attack_notification_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	attack_notification_label.add_theme_font_size_override("font_size", 24)
	attack_notification_label.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
	attack_notification_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	attack_notification_label.position = Vector2(-150, 50)
	attack_notification_label.custom_minimum_size = Vector2(300, 40)
	add_child(attack_notification_label)


func _on_player_under_attack(attack_type: String) -> void:
	var message: String
	match attack_type:
		"military":
			message = "YOUR UNITS ARE UNDER ATTACK!"
		"villager":
			message = "YOUR VILLAGERS ARE UNDER ATTACK!"
		"building":
			message = "YOUR BUILDINGS ARE UNDER ATTACK!"
		_:
			message = "YOU ARE UNDER ATTACK!"

	attack_notification_label.text = message
	attack_notification_label.visible = true

	var tween = create_tween()
	tween.tween_interval(2.5)
	tween.tween_callback(func(): attack_notification_label.modulate.a = 1.0)
	tween.tween_property(attack_notification_label, "modulate:a", 0.0, 0.5)
	tween.tween_callback(func():
		attack_notification_label.visible = false
		attack_notification_label.modulate.a = 1.0
	)


func _on_game_over(winner: int) -> void:
	game_over_panel.visible = true
	if winner == 0:
		game_over_label.text = "VICTORY!"
		game_over_label.add_theme_color_override("font_color", Color(0.2, 0.8, 0.2))
	else:
		game_over_label.text = "DEFEAT"
		game_over_label.add_theme_color_override("font_color", Color(0.8, 0.2, 0.2))


func _on_restart_pressed() -> void:
	selected_building = null
	selected_building_type = ""
	selected_info_entity = null
	selected_military_unit = null
	GameManager.reset()
	get_tree().reload_current_scene()
