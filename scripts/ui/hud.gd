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
@onready var build_blacksmith_btn: Button = $BottomPanel/BottomContent/CenterSection/ActionContainer/ActionGrid/BuildBlacksmithButton
@onready var build_monastery_btn: Button = $BottomPanel/BottomContent/CenterSection/ActionContainer/ActionGrid/BuildMonasteryButton
@onready var build_outpost_btn: Button = $BottomPanel/BottomContent/CenterSection/ActionContainer/ActionGrid/BuildOutpostButton
@onready var build_watch_tower_btn: Button = $BottomPanel/BottomContent/CenterSection/ActionContainer/ActionGrid/BuildWatchTowerButton

# Garrison buttons
@onready var ungarrison_btn: Button = $BottomPanel/BottomContent/CenterSection/ActionContainer/ActionGrid/UngarrisonButton
@onready var town_bell_btn: Button = $BottomPanel/BottomContent/CenterSection/ActionContainer/ActionGrid/TownBellButton

# Train buttons
@onready var train_villager_btn: Button = $BottomPanel/BottomContent/CenterSection/ActionContainer/ActionGrid/TrainVillagerButton
@onready var advance_age_btn: Button = $BottomPanel/BottomContent/CenterSection/ActionContainer/ActionGrid/AdvanceAgeButton
@onready var loom_btn: Button = $BottomPanel/BottomContent/CenterSection/ActionContainer/ActionGrid/LoomButton
@onready var train_militia_btn: Button = $BottomPanel/BottomContent/CenterSection/ActionContainer/ActionGrid/TrainMilitiaButton
@onready var train_spearman_btn: Button = $BottomPanel/BottomContent/CenterSection/ActionContainer/ActionGrid/TrainSpearmanButton
@onready var train_archer_btn: Button = $BottomPanel/BottomContent/CenterSection/ActionContainer/ActionGrid/TrainArcherButton
@onready var train_skirmisher_btn: Button = $BottomPanel/BottomContent/CenterSection/ActionContainer/ActionGrid/TrainSkirmisherButton
@onready var train_scout_cavalry_btn: Button = $BottomPanel/BottomContent/CenterSection/ActionContainer/ActionGrid/TrainScoutCavalryButton
@onready var train_cavalry_archer_btn: Button = $BottomPanel/BottomContent/CenterSection/ActionContainer/ActionGrid/TrainCavalryArcherButton
@onready var train_knight_btn: Button = $BottomPanel/BottomContent/CenterSection/ActionContainer/ActionGrid/TrainKnightButton
@onready var train_monk_btn: Button = $BottomPanel/BottomContent/CenterSection/ActionContainer/ActionGrid/TrainMonkButton

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

# Selection overlay (draws selection rect in screen space)
@onready var selection_overlay: Control = $SelectionOverlay

# Overlays
@onready var error_label: Label = $ErrorLabel
@onready var game_over_panel: PanelContainer = $GameOverPanel
@onready var game_over_label: Label = $GameOverPanel/VBoxContainer/GameOverLabel
@onready var restart_button: Button = $GameOverPanel/VBoxContainer/RestartButton

# Attack notification (created dynamically)
var attack_notification_label: Label = null

# Relic victory countdown (created dynamically)
var relic_countdown_label: Label = null

# Currently selected building (for training)
var selected_building: Building = null
var selected_building_type: String = ""  # "tc", "barracks", "market", "archery_range", "stable", "blacksmith", "monastery"

# Track selected entity for info panel updates
var selected_info_entity: Node = null

# Track selected military unit for stance buttons
var selected_military_unit: Unit = null

# Notification counter to prevent race conditions
var _notification_counter: int = 0

# Game logger reference
var _game_logger: GameLogger = null

# All action buttons for easy hide/show
var build_buttons: Array[Button] = []
var tc_buttons: Array[Button] = []
var barracks_buttons: Array[Button] = []
var archery_range_buttons: Array[Button] = []
var stable_buttons: Array[Button] = []
var market_buttons: Array[Button] = []
var blacksmith_buttons: Array[Button] = []  # Dynamically created tech research buttons
var monastery_buttons: Array[Button] = []
var monastery_tech_buttons: Array[Button] = []  # Dynamically created monastery tech buttons
var barracks_upgrade_buttons: Array[Button] = []  # Dynamically created upgrade buttons
var archery_range_upgrade_buttons: Array[Button] = []
var stable_upgrade_buttons: Array[Button] = []


func _ready() -> void:
	layer = 100  # Above fog of war

	# Connect signals
	GameManager.resources_changed.connect(_update_resources)
	GameManager.population_changed.connect(_update_population)
	GameManager.game_over.connect(_on_game_over)
	GameManager.villager_idle.connect(_on_villager_idle)
	GameManager.market_prices_changed.connect(_update_market_prices)
	GameManager.player_under_attack.connect(_on_player_under_attack)
	GameManager.age_changed.connect(_on_age_changed)
	GameManager.relic_countdown_started.connect(_on_relic_countdown_started)
	GameManager.relic_countdown_updated.connect(_on_relic_countdown_updated)
	GameManager.relic_countdown_cancelled.connect(_on_relic_countdown_cancelled)

	# Group buttons for easier management
	build_buttons = [build_house_btn, build_barracks_btn, build_farm_btn, build_mill_btn,
					 build_lumber_camp_btn, build_mining_camp_btn, build_market_btn,
					 build_archery_range_btn, build_stable_btn, build_blacksmith_btn,
					 build_monastery_btn, build_outpost_btn, build_watch_tower_btn]
	monastery_buttons = [train_monk_btn]
	tc_buttons = [train_villager_btn, advance_age_btn, loom_btn]
	barracks_buttons = [train_militia_btn, train_spearman_btn]
	archery_range_buttons = [train_archer_btn, train_skirmisher_btn]
	stable_buttons = [train_scout_cavalry_btn, train_cavalry_archer_btn, train_knight_btn]
	market_buttons = [buy_wood_btn, buy_food_btn, buy_stone_btn,
					  sell_wood_btn, sell_food_btn, sell_stone_btn, train_trade_cart_btn]

	# Initial update
	_update_resources()
	_update_population()
	_update_age_label()
	_update_market_prices()
	_setup_attack_notification()

	# Hide all action buttons initially
	_hide_all_action_buttons()
	game_over_panel.visible = false
	error_label.visible = false

	# Relic victory countdown label
	_setup_relic_countdown_label()

	# Cache game logger reference
	_game_logger = get_parent().get_node_or_null("GameLogger") as GameLogger


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

	# Age research progress (TC only)
	if selected_building is TownCenter:
		var tc = selected_building as TownCenter
		if tc.is_researching_age:
			train_progress.value = tc.get_age_research_progress() * 100
			train_progress.visible = true
			var age_name = GameManager.AGE_NAMES[tc.age_research_target] if tc.age_research_target < GameManager.AGE_NAMES.size() else "?"
			queue_label.text = age_name
			cancel_btn.visible = true
			return
		if tc.is_researching:
			train_progress.value = tc.get_research_progress() * 100
			train_progress.visible = true
			queue_label.text = "Loom"
			cancel_btn.visible = true
			return

	# Tech research progress (Monastery)
	if selected_building is Monastery:
		var mon = selected_building as Monastery
		if mon.is_researching:
			train_progress.value = mon.get_research_progress() * 100
			train_progress.visible = true
			var tech_name = GameManager.TECHNOLOGIES.get(mon.current_research_id, {}).get("name", "?")
			queue_label.text = tech_name
			cancel_btn.visible = true
			return

	# Tech research progress (Blacksmith)
	if selected_building is Blacksmith:
		var bs = selected_building as Blacksmith
		if bs.is_researching:
			train_progress.value = bs.get_research_progress() * 100
			train_progress.visible = true
			var tech_name = GameManager.TECHNOLOGIES.get(bs.current_research_id, {}).get("name", "?")
			queue_label.text = tech_name
			cancel_btn.visible = true
			return
		else:
			train_progress.visible = false
			queue_label.text = ""
			cancel_btn.visible = false
			return

	# Research progress for training buildings (Barracks, Archery Range, Stable)
	if (selected_building is Barracks or selected_building is ArcheryRange or selected_building is Stable) and selected_building.is_researching:
		train_progress.value = selected_building.get_research_progress() * 100
		train_progress.visible = true
		var tech_name = GameManager.TECHNOLOGIES.get(selected_building.current_research_id, {}).get("name", "?")
		queue_label.text = tech_name
		cancel_btn.visible = true
		return

	if not selected_building.has_method("get_queue_size"):
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
	for btn in blacksmith_buttons:
		btn.visible = false
	for btn in monastery_buttons:
		btn.visible = false
	for btn in monastery_tech_buttons:
		if is_instance_valid(btn):
			btn.queue_free()
	monastery_tech_buttons.clear()
	for btn in barracks_upgrade_buttons:
		if is_instance_valid(btn):
			btn.queue_free()
	barracks_upgrade_buttons.clear()
	for btn in archery_range_upgrade_buttons:
		if is_instance_valid(btn):
			btn.queue_free()
	archery_range_upgrade_buttons.clear()
	for btn in stable_upgrade_buttons:
		if is_instance_valid(btn):
			btn.queue_free()
	stable_upgrade_buttons.clear()
	ungarrison_btn.visible = false
	town_bell_btn.visible = false
	cancel_btn.visible = false
	train_progress.visible = false
	queue_label.text = ""
	stance_container.visible = false


func _show_build_buttons() -> void:
	_hide_all_action_buttons()
	for btn in build_buttons:
		btn.visible = true
	_update_build_button_states()
	action_title.text = "Build"


func _show_tc_buttons(tc: TownCenter) -> void:
	_hide_all_action_buttons()
	for btn in tc_buttons:
		btn.visible = true
	action_title.text = "Town Center"
	selected_building = tc
	selected_building_type = "tc"
	_update_advance_age_button()
	_update_loom_button()
	# Show garrison/bell buttons
	if tc.get_garrisoned_count() > 0:
		ungarrison_btn.visible = true
		ungarrison_btn.text = "Ungarrison All (%d)" % tc.get_garrisoned_count()
	town_bell_btn.visible = true
	town_bell_btn.text = "All Clear" if tc.bell_active else "Town Bell"


func _show_barracks_buttons(barracks: Barracks) -> void:
	_hide_all_action_buttons()
	for btn in barracks_buttons:
		btn.visible = true
	action_title.text = "Barracks"
	selected_building = barracks
	selected_building_type = "barracks"
	_update_barracks_button_states()
	_create_upgrade_buttons("barracks", ["man_at_arms", "long_swordsman", "pikeman"], barracks_upgrade_buttons)
	cancel_btn.visible = barracks.is_researching or barracks.get_queue_size() > 0
	if barracks.get_garrisoned_count() > 0:
		ungarrison_btn.visible = true
		ungarrison_btn.text = "Ungarrison All (%d)" % barracks.get_garrisoned_count()


func _show_archery_range_buttons(archery_range: ArcheryRange) -> void:
	_hide_all_action_buttons()
	for btn in archery_range_buttons:
		btn.visible = true
	action_title.text = "Archery Range"
	selected_building = archery_range
	selected_building_type = "archery_range"
	_update_archery_range_button_states()
	_create_upgrade_buttons("archery_range", ["crossbowman", "elite_skirmisher", "heavy_cavalry_archer"], archery_range_upgrade_buttons)
	cancel_btn.visible = archery_range.is_researching or archery_range.get_queue_size() > 0
	if archery_range.get_garrisoned_count() > 0:
		ungarrison_btn.visible = true
		ungarrison_btn.text = "Ungarrison All (%d)" % archery_range.get_garrisoned_count()


func _show_stable_buttons(stable: Stable) -> void:
	_hide_all_action_buttons()
	for btn in stable_buttons:
		btn.visible = true
	action_title.text = "Stable"
	selected_building = stable
	selected_building_type = "stable"
	_update_stable_button_states()
	_create_upgrade_buttons("stable", ["light_cavalry"], stable_upgrade_buttons)
	cancel_btn.visible = stable.is_researching or stable.get_queue_size() > 0
	if stable.get_garrisoned_count() > 0:
		ungarrison_btn.visible = true
		ungarrison_btn.text = "Ungarrison All (%d)" % stable.get_garrisoned_count()


func _show_market_buttons(market: Market) -> void:
	_hide_all_action_buttons()
	for btn in market_buttons:
		btn.visible = true
	action_title.text = "Market"
	selected_building = market
	selected_building_type = "market"
	_update_market_prices()
	_update_market_button_states()


func _show_blacksmith_buttons(blacksmith: Blacksmith) -> void:
	_hide_all_action_buttons()
	action_title.text = "Blacksmith"
	selected_building = blacksmith
	selected_building_type = "blacksmith"
	_create_blacksmith_tech_buttons()
	cancel_btn.visible = blacksmith.is_researching


func _show_monastery_buttons(monastery: Monastery) -> void:
	_hide_all_action_buttons()
	for btn in monastery_buttons:
		btn.visible = true
	action_title.text = "Monastery"
	selected_building = monastery
	selected_building_type = "monastery"
	_create_monastery_tech_buttons()
	cancel_btn.visible = monastery.is_researching or monastery.get_queue_size() > 0
	if monastery.get_garrisoned_count() > 0:
		ungarrison_btn.visible = true
		ungarrison_btn.text = "Ungarrison All (%d)" % monastery.get_garrisoned_count()


func _update_market_prices() -> void:
	buy_wood_btn.text = "Buy Wood: %dg" % GameManager.get_market_buy_price("wood")
	buy_food_btn.text = "Buy Food: %dg" % GameManager.get_market_buy_price("food")
	buy_stone_btn.text = "Buy Stone: %dg" % GameManager.get_market_buy_price("stone")
	sell_wood_btn.text = "Sell Wood: %dg" % GameManager.get_market_sell_price("wood")
	sell_food_btn.text = "Sell Food: %dg" % GameManager.get_market_sell_price("food")
	sell_stone_btn.text = "Sell Stone: %dg" % GameManager.get_market_sell_price("stone")


# ============================================================================
# Age-gating helpers
# ============================================================================

func _set_button_age_locked(btn: Button, locked: bool, age_name: String, base_text: String) -> void:
	if locked:
		btn.disabled = true
		btn.text = "%s (%s)" % [base_text, age_name]
	else:
		btn.disabled = false
		btn.text = base_text


func _update_build_button_states() -> void:
	# Dark Age buildings - always enabled
	build_house_btn.disabled = false
	build_barracks_btn.disabled = false
	build_farm_btn.disabled = false
	build_mill_btn.disabled = false
	build_lumber_camp_btn.disabled = false
	build_mining_camp_btn.disabled = false

	# Dark Age buildings
	build_outpost_btn.disabled = false

	# Feudal Age buildings
	_set_button_age_locked(build_archery_range_btn, not GameManager.is_building_unlocked("archery_range"), GameManager.get_required_age_name("archery_range", true), "Archery Range")
	_set_button_age_locked(build_stable_btn, not GameManager.is_building_unlocked("stable"), GameManager.get_required_age_name("stable", true), "Stable")
	_set_button_age_locked(build_market_btn, not GameManager.is_building_unlocked("market"), GameManager.get_required_age_name("market", true), "Market")
	_set_button_age_locked(build_blacksmith_btn, not GameManager.is_building_unlocked("blacksmith"), GameManager.get_required_age_name("blacksmith", true), "Blacksmith (150W)")
	_set_button_age_locked(build_monastery_btn, not GameManager.is_building_unlocked("monastery"), GameManager.get_required_age_name("monastery", true), "Monastery (175W)")
	_set_button_age_locked(build_watch_tower_btn, not GameManager.is_building_unlocked("watch_tower"), GameManager.get_required_age_name("watch_tower", true), "Watch Tower (25W, 125S)")


func _update_barracks_button_states() -> void:
	# Militia - Dark Age, always available
	train_militia_btn.disabled = false
	train_militia_btn.text = "Train Militia"

	# Spearman - Feudal Age
	var locked = not GameManager.is_unit_unlocked("spearman")
	_set_button_age_locked(train_spearman_btn, locked, GameManager.get_required_age_name("spearman"), "Train Spearman")


func _update_archery_range_button_states() -> void:
	# Archer - Feudal Age (archery range itself is Feudal, so should always be unlocked here)
	train_archer_btn.disabled = false
	train_archer_btn.text = "Train Archer"

	# Skirmisher - Feudal Age
	train_skirmisher_btn.disabled = false
	train_skirmisher_btn.text = "Train Skirmisher"


func _update_stable_button_states() -> void:
	# Scout Cavalry - Feudal Age (stable itself is Feudal, so should always be unlocked here)
	train_scout_cavalry_btn.disabled = false
	train_scout_cavalry_btn.text = "Train Scout Cavalry"

	# Cavalry Archer - Castle Age
	var locked = not GameManager.is_unit_unlocked("cavalry_archer")
	_set_button_age_locked(train_cavalry_archer_btn, locked, GameManager.get_required_age_name("cavalry_archer"), "Train Cavalry Archer")

	# Knight - Castle Age
	var knight_locked = not GameManager.is_unit_unlocked("knight")
	_set_button_age_locked(train_knight_btn, knight_locked, GameManager.get_required_age_name("knight"), "Train Knight")


func _update_market_button_states() -> void:
	# Trade Cart - Feudal Age (market itself is Feudal, so should always be unlocked here)
	train_trade_cart_btn.disabled = false
	train_trade_cart_btn.text = "Train Trade Cart"


## Create upgrade research buttons for a training building (barracks, archery range, stable).
## tech_ids: ordered list of upgrade tech IDs to show. btn_array: passed by reference to store buttons.
func _create_upgrade_buttons(building_type: String, tech_ids: Array, btn_array: Array[Button]) -> void:
	# Clean up old buttons
	for btn in btn_array:
		if is_instance_valid(btn):
			btn.queue_free()
	btn_array.clear()

	for tech_id in tech_ids:
		if tech_id not in GameManager.TECHNOLOGIES:
			continue
		var tech = GameManager.TECHNOLOGIES[tech_id]
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(120, 25)

		if GameManager.has_tech(tech_id, 0):
			btn.text = "%s [Done]" % tech["name"]
			btn.disabled = true
		elif GameManager.get_age(0) < tech["age"]:
			btn.text = "%s (%s)" % [tech["name"], GameManager.AGE_NAMES[tech["age"]]]
			btn.disabled = true
		elif tech["requires"] != "" and not GameManager.has_tech(tech["requires"], 0):
			var prereq_name = GameManager.TECHNOLOGIES[tech["requires"]]["name"]
			btn.text = "%s (Req: %s)" % [tech["name"], prereq_name]
			btn.disabled = true
		elif selected_building and selected_building.is_researching:
			btn.text = _format_tech_cost(tech)
			btn.disabled = true
		else:
			btn.text = _format_tech_cost(tech)
			btn.disabled = false

		var captured_id = tech_id
		btn.pressed.connect(func(): _on_upgrade_tech_pressed(captured_id))
		action_grid.add_child(btn)
		btn.visible = true
		btn_array.append(btn)


func _on_upgrade_tech_pressed(tech_id: String) -> void:
	if not selected_building or not is_instance_valid(selected_building):
		return
	if selected_building.is_researching:
		_show_error("Already researching!")
		return
	if selected_building.start_research(tech_id):
		var tech_name = GameManager.TECHNOLOGIES[tech_id]["name"]
		_show_notification("Researching %s..." % tech_name)
		# Refresh the building panel to update button states
		if selected_building_type == "barracks":
			_show_barracks_buttons(selected_building as Barracks)
		elif selected_building_type == "archery_range":
			_show_archery_range_buttons(selected_building as ArcheryRange)
		elif selected_building_type == "stable":
			_show_stable_buttons(selected_building as Stable)
		if _game_logger:
			_game_logger.log_action("research", {"tech": tech_id})
	else:
		_show_error("Cannot research!")


func _refresh_current_panel() -> void:
	## Re-evaluates button states for the currently visible panel.
	## Called when age changes to immediately unlock newly available content.
	if selected_building_type == "tc":
		_update_advance_age_button()
	elif selected_building_type == "barracks":
		_update_barracks_button_states()
		_create_upgrade_buttons("barracks", ["man_at_arms", "long_swordsman", "pikeman"], barracks_upgrade_buttons)
	elif selected_building_type == "archery_range":
		_update_archery_range_button_states()
		_create_upgrade_buttons("archery_range", ["crossbowman", "elite_skirmisher", "heavy_cavalry_archer"], archery_range_upgrade_buttons)
	elif selected_building_type == "stable":
		_update_stable_button_states()
		_create_upgrade_buttons("stable", ["light_cavalry"], stable_upgrade_buttons)
	elif selected_building_type == "market":
		_update_market_button_states()
	elif selected_building_type == "blacksmith":
		_create_blacksmith_tech_buttons()  # Recreate to reflect new age
	elif selected_building_type == "monastery":
		_create_monastery_tech_buttons()

	# Also refresh build buttons if a villager is selected
	if selected_info_entity is Villager and selected_info_entity.team == 0:
		_update_build_button_states()


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
	elif entity is Knight:
		_show_military_info(entity, entity.unit_display_name if entity.unit_display_name != "" else "Knight")
	elif entity is Militia:
		_show_military_info(entity, entity.unit_display_name if entity.unit_display_name != "" else "Militia")
	elif entity is Archer:
		_show_military_info(entity, entity.unit_display_name if entity.unit_display_name != "" else "Archer")
	elif entity is Skirmisher:
		_show_military_info(entity, entity.unit_display_name if entity.unit_display_name != "" else "Skirmisher")
	elif entity is CavalryArcher:
		_show_military_info(entity, entity.unit_display_name if entity.unit_display_name != "" else "Cavalry Archer")
	elif entity is ScoutCavalry:
		_show_military_info(entity, entity.unit_display_name if entity.unit_display_name != "" else "Scout Cavalry")
	elif entity is Spearman:
		_show_military_info(entity, entity.unit_display_name if entity.unit_display_name != "" else "Spearman")
	elif entity is Monk:
		_show_monk_info(entity)
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
		var tc_details = "Trains villagers\nDrop-off: all"
		if entity.get_garrisoned_count() > 0:
			tc_details += "\nGarrisoned: %d/%d" % [entity.get_garrisoned_count(), entity.garrison_capacity]
		_show_building_info("Town Center", tc_details, entity)
		if entity.team == 0 and entity.is_functional():
			_show_tc_buttons(entity)
	elif entity is Barracks:
		var brk_details = "Trains infantry"
		if entity.get_garrisoned_count() > 0:
			brk_details += "\nGarrisoned: %d/%d" % [entity.get_garrisoned_count(), entity.garrison_capacity]
		_show_building_info("Barracks", brk_details, entity)
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
	elif entity is Blacksmith:
		_show_building_info("Blacksmith", "Researches upgrades", entity)
		if entity.team == 0 and entity.is_functional():
			_show_blacksmith_buttons(entity)
	elif entity is Monastery:
		var mon_details = "Trains monks\nResearches monastery techs"
		var relic_count = entity.get_relic_count()
		if relic_count > 0:
			var gold_rate = relic_count * Monastery.RELIC_GOLD_RATE
			mon_details += "\nRelics: %d (+%.1f gold/sec)" % [relic_count, gold_rate]
		_show_building_info("Monastery", mon_details, entity)
		if entity.team == 0 and entity.is_functional():
			_show_monastery_buttons(entity)
	elif entity is WatchTower:
		var tower_details = "Attack: %d pierce | Range: %d" % [WatchTower.TOWER_BASE_ATTACK, int(WatchTower.TOWER_ATTACK_RANGE)]
		if entity.get_garrisoned_count() > 0:
			tower_details += "\nGarrisoned: %d/%d" % [entity.get_garrisoned_count(), entity.garrison_capacity]
		_show_building_info("Watch Tower", tower_details, entity)
		if entity.team == 0 and entity.is_functional():
			_show_garrison_buttons(entity)
	elif entity is Outpost:
		_show_building_info("Outpost", "Provides line of sight\nLOS: 10 tiles", entity)
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

func show_blacksmith_panel(blacksmith: Blacksmith) -> void:
	show_info(blacksmith)

func hide_blacksmith_panel() -> void:
	if selected_building_type == "blacksmith":
		_hide_all_action_buttons()
		selected_building = null
		selected_building_type = ""

func show_monastery_panel(monastery: Monastery) -> void:
	show_info(monastery)

func hide_monastery_panel() -> void:
	if selected_building_type == "monastery":
		_hide_all_action_buttons()
		selected_building = null
		selected_building_type = ""


func update_selection_rect(rect: Rect2, visible: bool) -> void:
	selection_overlay.update_selection_rect(rect, visible)


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
		Villager.State.ATTACKING:
			state_text = "Attacking"

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


func _show_monk_info(monk: Monk) -> void:
	info_title.text = "Monk"
	hp_bar.max_value = monk.max_hp
	hp_bar.value = monk.current_hp
	hp_label.text = "%d/%d" % [monk.current_hp, monk.max_hp]
	attack_label.text = ""
	armor_label.text = "🛡️ 0/0"
	info_details.text = "Status: %s\nConvert range: %d" % [monk.get_status_text(), int(monk.conversion_range)]


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
	elif selected_info_entity is Monk:
		_show_monk_info(selected_info_entity as Monk)
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
	var stone_refund = int(building.stone_cost * refund_ratio)
	var gold_refund = int(building.gold_cost * refund_ratio)

	if wood_refund > 0:
		GameManager.add_resource("wood", wood_refund, 0)
	if food_refund > 0:
		GameManager.add_resource("food", food_refund, 0)
	if stone_refund > 0:
		GameManager.add_resource("stone", stone_refund, 0)
	if gold_refund > 0:
		GameManager.add_resource("gold", gold_refund, 0)

	# Release builders
	for builder in building.builders.duplicate():
		if is_instance_valid(builder):
			building.remove_builder(builder)
			builder.target_construction = null
			builder.current_state = Villager.State.IDLE

	building.queue_free()
	selected_info_entity = null
	hide_info()

	var total_refund = wood_refund + food_refund + stone_refund + gold_refund
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
	if not GameManager.is_building_unlocked("market"):
		_show_error("Requires %s!" % GameManager.get_required_age_name("market", true))
		return
	if not GameManager.can_afford("wood", 175):
		_show_error("Need 175 wood!")
		return
	get_parent().start_market_placement()

func _on_build_archery_range_pressed() -> void:
	if not GameManager.is_building_unlocked("archery_range"):
		_show_error("Requires %s!" % GameManager.get_required_age_name("archery_range", true))
		return
	if not GameManager.can_afford("wood", 175):
		_show_error("Need 175 wood!")
		return
	get_parent().start_archery_range_placement()

func _on_build_stable_pressed() -> void:
	if not GameManager.is_building_unlocked("stable"):
		_show_error("Requires %s!" % GameManager.get_required_age_name("stable", true))
		return
	if not GameManager.can_afford("wood", 175):
		_show_error("Need 175 wood!")
		return
	get_parent().start_stable_placement()


func _on_train_villager_pressed() -> void:
	if selected_building is TownCenter:
		var tc = selected_building as TownCenter
		if tc.train_villager():
			if _game_logger:
				_game_logger.log_action("train", {"unit": "villager"})
		else:
			if not GameManager.can_afford("food", TownCenter.VILLAGER_COST):
				_show_error("Need 50 food!")
			elif not GameManager.can_add_population():
				_show_error("Pop cap reached!")

func _on_train_militia_pressed() -> void:
	if selected_building is Barracks:
		var barracks = selected_building as Barracks
		if barracks.train_militia():
			if _game_logger:
				_game_logger.log_action("train", {"unit": "militia"})
		else:
			if not GameManager.can_afford("food", Barracks.MILITIA_FOOD_COST):
				_show_error("Need 60 food!")
			elif not GameManager.can_afford("wood", Barracks.MILITIA_WOOD_COST):
				_show_error("Need 20 wood!")
			elif not GameManager.can_add_population():
				_show_error("Pop cap reached!")

func _on_train_spearman_pressed() -> void:
	if not GameManager.is_unit_unlocked("spearman"):
		_show_error("Requires %s!" % GameManager.get_required_age_name("spearman"))
		return
	if selected_building is Barracks:
		var barracks = selected_building as Barracks
		if barracks.train_spearman():
			if _game_logger:
				_game_logger.log_action("train", {"unit": "spearman"})
		else:
			if not GameManager.can_afford("food", Barracks.SPEARMAN_FOOD_COST):
				_show_error("Need 35 food!")
			elif not GameManager.can_afford("wood", Barracks.SPEARMAN_WOOD_COST):
				_show_error("Need 25 wood!")
			elif not GameManager.can_add_population():
				_show_error("Pop cap reached!")

func _on_train_archer_pressed() -> void:
	if not GameManager.is_unit_unlocked("archer"):
		_show_error("Requires %s!" % GameManager.get_required_age_name("archer"))
		return
	if selected_building is ArcheryRange:
		var ar = selected_building as ArcheryRange
		if ar.train_archer():
			if _game_logger:
				_game_logger.log_action("train", {"unit": "archer"})
		else:
			if not GameManager.can_afford("wood", ArcheryRange.ARCHER_WOOD_COST):
				_show_error("Need 25 wood!")
			elif not GameManager.can_afford("gold", ArcheryRange.ARCHER_GOLD_COST):
				_show_error("Need 45 gold!")
			elif not GameManager.can_add_population():
				_show_error("Pop cap reached!")

func _on_train_skirmisher_pressed() -> void:
	if not GameManager.is_unit_unlocked("skirmisher"):
		_show_error("Requires %s!" % GameManager.get_required_age_name("skirmisher"))
		return
	if selected_building is ArcheryRange:
		var ar = selected_building as ArcheryRange
		if ar.train_skirmisher():
			if _game_logger:
				_game_logger.log_action("train", {"unit": "skirmisher"})
		else:
			if not GameManager.can_afford("food", ArcheryRange.SKIRMISHER_FOOD_COST):
				_show_error("Need 25 food!")
			elif not GameManager.can_afford("wood", ArcheryRange.SKIRMISHER_WOOD_COST):
				_show_error("Need 35 wood!")
			elif not GameManager.can_add_population():
				_show_error("Pop cap reached!")

func _on_train_scout_cavalry_pressed() -> void:
	if not GameManager.is_unit_unlocked("scout_cavalry"):
		_show_error("Requires %s!" % GameManager.get_required_age_name("scout_cavalry"))
		return
	if selected_building is Stable:
		var stable = selected_building as Stable
		if stable.train_scout_cavalry():
			if _game_logger:
				_game_logger.log_action("train", {"unit": "scout_cavalry"})
		else:
			if not GameManager.can_afford("food", Stable.SCOUT_CAVALRY_FOOD_COST):
				_show_error("Need 80 food!")
			elif not GameManager.can_add_population():
				_show_error("Pop cap reached!")

func _on_train_cavalry_archer_pressed() -> void:
	if not GameManager.is_unit_unlocked("cavalry_archer"):
		_show_error("Requires %s!" % GameManager.get_required_age_name("cavalry_archer"))
		return
	if selected_building is Stable:
		var stable = selected_building as Stable
		if stable.train_cavalry_archer():
			if _game_logger:
				_game_logger.log_action("train", {"unit": "cavalry_archer"})
		else:
			if not GameManager.can_afford("wood", Stable.CAVALRY_ARCHER_WOOD_COST):
				_show_error("Need 40 wood!")
			elif not GameManager.can_afford("gold", Stable.CAVALRY_ARCHER_GOLD_COST):
				_show_error("Need 70 gold!")
			elif not GameManager.can_add_population():
				_show_error("Pop cap reached!")


func _on_train_knight_pressed() -> void:
	if not GameManager.is_unit_unlocked("knight"):
		_show_error("Requires %s!" % GameManager.get_required_age_name("knight"))
		return
	if selected_building is Stable:
		var stable = selected_building as Stable
		if stable.train_knight():
			if _game_logger:
				_game_logger.log_action("train", {"unit": "knight"})
		else:
			if not GameManager.can_afford("food", Stable.KNIGHT_FOOD_COST):
				_show_error("Need 60 food!")
			elif not GameManager.can_afford("gold", Stable.KNIGHT_GOLD_COST):
				_show_error("Need 75 gold!")
			elif not GameManager.can_add_population():
				_show_error("Pop cap reached!")

func _on_advance_age_pressed() -> void:
	if not selected_building is TownCenter:
		return
	var tc = selected_building as TownCenter
	if tc.is_researching_age:
		_show_error("Already researching!")
		return

	var current_age = GameManager.get_age(0)
	if current_age >= GameManager.AGE_IMPERIAL:
		_show_error("Already at max age!")
		return

	var target_age = current_age + 1
	var qualifying = GameManager.get_qualifying_building_count(target_age, 0)
	if qualifying < GameManager.AGE_REQUIRED_QUALIFYING_COUNT:
		_show_error("Need %d qualifying buildings (have %d)" % [GameManager.AGE_REQUIRED_QUALIFYING_COUNT, qualifying])
		return

	if not GameManager.can_afford_age(target_age, 0):
		var costs = GameManager.AGE_COSTS[target_age]
		var cost_parts: Array[String] = []
		for res in costs:
			cost_parts.append("%d %s" % [costs[res], res])
		_show_error("Need %s" % ", ".join(cost_parts))
		return

	if tc.start_age_research(target_age):
		var age_name = GameManager.AGE_NAMES[target_age]
		_show_notification("Researching %s..." % age_name)
		if _game_logger:
			_game_logger.log_action("age_research", {"target": age_name})


func _update_advance_age_button() -> void:
	var current_age = GameManager.get_age(0)
	if current_age >= GameManager.AGE_IMPERIAL:
		advance_age_btn.text = "Max Age"
		advance_age_btn.disabled = true
		return

	var target_age = current_age + 1
	var age_name = GameManager.AGE_NAMES[target_age]
	var costs = GameManager.AGE_COSTS[target_age]
	var cost_parts: Array[String] = []
	for res in costs:
		var short = res[0].to_upper()  # "F", "G", etc.
		cost_parts.append("%d%s" % [costs[res], short])

	advance_age_btn.text = "%s (%s)" % [age_name, ", ".join(cost_parts)]
	advance_age_btn.disabled = false


func _update_age_label() -> void:
	age_label.text = GameManager.get_age_name(0)


func _on_age_changed(team: int, new_age: int) -> void:
	if team == 0:
		_update_age_label()
		_show_notification("Advanced to %s!" % GameManager.AGE_NAMES[new_age])
		_refresh_current_panel()


func _on_buy_wood_pressed() -> void:
	if selected_building is Market:
		var market = selected_building as Market
		if market.buy_resource("wood"):
			if _game_logger:
				_game_logger.log_action("market_buy", {"resource": "wood"})
		else:
			_show_error("Need %d gold!" % GameManager.get_market_buy_price("wood"))

func _on_buy_food_pressed() -> void:
	if selected_building is Market:
		var market = selected_building as Market
		if market.buy_resource("food"):
			if _game_logger:
				_game_logger.log_action("market_buy", {"resource": "food"})
		else:
			_show_error("Need %d gold!" % GameManager.get_market_buy_price("food"))

func _on_buy_stone_pressed() -> void:
	if selected_building is Market:
		var market = selected_building as Market
		if market.buy_resource("stone"):
			if _game_logger:
				_game_logger.log_action("market_buy", {"resource": "stone"})
		else:
			_show_error("Need %d gold!" % GameManager.get_market_buy_price("stone"))

func _on_sell_wood_pressed() -> void:
	if selected_building is Market:
		var market = selected_building as Market
		if market.sell_resource("wood"):
			if _game_logger:
				_game_logger.log_action("market_sell", {"resource": "wood"})
		else:
			_show_error("Need 100 wood!")

func _on_sell_food_pressed() -> void:
	if selected_building is Market:
		var market = selected_building as Market
		if market.sell_resource("food"):
			if _game_logger:
				_game_logger.log_action("market_sell", {"resource": "food"})
		else:
			_show_error("Need 100 food!")

func _on_sell_stone_pressed() -> void:
	if selected_building is Market:
		var market = selected_building as Market
		if market.sell_resource("stone"):
			if _game_logger:
				_game_logger.log_action("market_sell", {"resource": "stone"})
		else:
			_show_error("Need 100 stone!")

func _on_train_trade_cart_pressed() -> void:
	if not GameManager.is_unit_unlocked("trade_cart"):
		_show_error("Requires %s!" % GameManager.get_required_age_name("trade_cart"))
		return
	if selected_building is Market:
		var market = selected_building as Market
		if market.train_trade_cart():
			if _game_logger:
				_game_logger.log_action("train", {"unit": "trade_cart"})
		else:
			if not GameManager.can_afford("wood", Market.TRADE_CART_WOOD_COST):
				_show_error("Need 100 wood!")
			elif not GameManager.can_afford("gold", Market.TRADE_CART_GOLD_COST):
				_show_error("Need 50 gold!")
			elif not GameManager.can_add_population():
				_show_error("Pop cap reached!")


func _on_loom_pressed() -> void:
	if not selected_building is TownCenter:
		return
	var tc = selected_building as TownCenter
	if GameManager.has_tech("loom", 0):
		_show_error("Already researched!")
		return
	if tc.is_researching_age or tc.is_researching:
		_show_error("Already researching!")
		return
	if tc.start_loom_research():
		_show_notification("Researching Loom...")
		if _game_logger:
			_game_logger.log_action("research", {"tech": "loom"})
	else:
		if not GameManager.can_afford("gold", 50):
			_show_error("Need 50 gold!")

func _on_build_blacksmith_pressed() -> void:
	if not GameManager.is_building_unlocked("blacksmith"):
		_show_error("Requires %s!" % GameManager.get_required_age_name("blacksmith", true))
		return
	if not GameManager.can_afford("wood", 150):
		_show_error("Need 150 wood!")
		return
	get_parent().start_blacksmith_placement()

func _on_build_monastery_pressed() -> void:
	if not GameManager.is_building_unlocked("monastery"):
		_show_error("Requires %s!" % GameManager.get_required_age_name("monastery", true))
		return
	if not GameManager.can_afford("wood", 175):
		_show_error("Need 175 wood!")
		return
	get_parent().start_monastery_placement()

func _on_build_outpost_pressed() -> void:
	if not GameManager.can_afford("wood", 25) or not GameManager.can_afford("stone", 25):
		_show_error("Need 25 wood, 25 stone!")
		return
	get_parent().start_outpost_placement()

func _on_build_watch_tower_pressed() -> void:
	if not GameManager.is_building_unlocked("watch_tower"):
		_show_error("Requires %s!" % GameManager.get_required_age_name("watch_tower", true))
		return
	if not GameManager.can_afford("wood", 25) or not GameManager.can_afford("stone", 125):
		_show_error("Need 25 wood, 125 stone!")
		return
	get_parent().start_watch_tower_placement()


func _on_train_monk_pressed() -> void:
	if not GameManager.is_unit_unlocked("monk"):
		_show_error("Requires %s!" % GameManager.get_required_age_name("monk"))
		return
	if selected_building is Monastery:
		var monastery = selected_building as Monastery
		if monastery.train_monk():
			if _game_logger:
				_game_logger.log_action("train", {"unit": "monk"})
		else:
			if not GameManager.can_afford("gold", Monastery.MONK_GOLD_COST):
				_show_error("Need 100 gold!")
			elif not GameManager.can_add_population():
				_show_error("Pop cap reached!")


func _update_loom_button() -> void:
	if GameManager.has_tech("loom", 0):
		loom_btn.text = "Loom [Done]"
		loom_btn.disabled = true
	else:
		loom_btn.text = "Loom (50G)"
		loom_btn.disabled = false


## Create blacksmith tech research buttons dynamically based on available techs
func _create_blacksmith_tech_buttons() -> void:
	# Remove old buttons
	for btn in blacksmith_buttons:
		if is_instance_valid(btn):
			btn.queue_free()
	blacksmith_buttons.clear()

	if not selected_building is Blacksmith:
		return
	var blacksmith = selected_building as Blacksmith

	# Ordered tech lines for display
	var tech_lines: Array[Array] = [
		["forging", "iron_casting"],  # Attack (infantry + cavalry)
		["scale_mail_armor", "chain_mail_armor"],  # Infantry armor
		["scale_barding_armor", "chain_barding_armor"],  # Cavalry armor
		["fletching", "bodkin_arrow"],  # Archer attack + range
		["padded_archer_armor", "leather_archer_armor"],  # Archer armor
	]

	for line in tech_lines:
		for tech_id in line:
			var tech = GameManager.TECHNOLOGIES[tech_id]
			var btn = Button.new()
			btn.custom_minimum_size = Vector2(120, 25)

			if GameManager.has_tech(tech_id, 0):
				btn.text = "%s [Done]" % tech["name"]
				btn.disabled = true
			elif GameManager.get_age(0) < tech["age"]:
				btn.text = "%s (%s)" % [tech["name"], GameManager.AGE_NAMES[tech["age"]]]
				btn.disabled = true
			elif tech["requires"] != "" and not GameManager.has_tech(tech["requires"], 0):
				var prereq_name = GameManager.TECHNOLOGIES[tech["requires"]]["name"]
				btn.text = "%s (Req: %s)" % [tech["name"], prereq_name]
				btn.disabled = true
			elif blacksmith.is_researching:
				btn.text = _format_tech_cost(tech)
				btn.disabled = true
			else:
				btn.text = _format_tech_cost(tech)
				btn.disabled = false

			var captured_id = tech_id
			btn.pressed.connect(func(): _on_blacksmith_tech_pressed(captured_id))
			action_grid.add_child(btn)
			btn.visible = true
			blacksmith_buttons.append(btn)

	cancel_btn.visible = blacksmith.is_researching


func _format_tech_cost(tech: Dictionary) -> String:
	var cost_parts: Array[String] = []
	for res in tech["cost"]:
		var short = res[0].to_upper()
		cost_parts.append("%d%s" % [tech["cost"][res], short])
	return "%s (%s)" % [tech["name"], ", ".join(cost_parts)]


func _on_blacksmith_tech_pressed(tech_id: String) -> void:
	if not selected_building is Blacksmith:
		return
	var blacksmith = selected_building as Blacksmith
	if blacksmith.is_researching:
		_show_error("Already researching!")
		return
	if blacksmith.start_research(tech_id):
		var tech_name = GameManager.TECHNOLOGIES[tech_id]["name"]
		_show_notification("Researching %s..." % tech_name)
		_create_blacksmith_tech_buttons()  # Refresh button states
		if _game_logger:
			_game_logger.log_action("research", {"tech": tech_id})
	else:
		_show_error("Cannot research!")


func _create_monastery_tech_buttons() -> void:
	for btn in monastery_tech_buttons:
		if is_instance_valid(btn):
			btn.queue_free()
	monastery_tech_buttons.clear()

	if not selected_building is Monastery:
		return
	var monastery = selected_building as Monastery

	var tech_ids = ["sanctity", "fervor", "redemption", "atonement",
					"illumination", "faith", "block_printing"]

	for tech_id in tech_ids:
		if tech_id not in GameManager.TECHNOLOGIES:
			continue
		var tech = GameManager.TECHNOLOGIES[tech_id]
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(120, 25)

		if GameManager.has_tech(tech_id, 0):
			btn.text = "%s [Done]" % tech["name"]
			btn.disabled = true
		elif GameManager.get_age(0) < tech["age"]:
			btn.text = "%s (%s)" % [tech["name"], GameManager.AGE_NAMES[tech["age"]]]
			btn.disabled = true
		elif monastery.is_researching:
			btn.text = _format_tech_cost(tech)
			btn.disabled = true
		else:
			btn.text = _format_tech_cost(tech)
			btn.disabled = false

		var captured_id = tech_id
		btn.pressed.connect(func(): _on_monastery_tech_pressed(captured_id))
		action_grid.add_child(btn)
		btn.visible = true
		monastery_tech_buttons.append(btn)

	cancel_btn.visible = monastery.is_researching or monastery.get_queue_size() > 0


func _on_monastery_tech_pressed(tech_id: String) -> void:
	if not selected_building is Monastery:
		return
	var monastery = selected_building as Monastery
	if monastery.is_researching:
		_show_error("Already researching!")
		return
	if monastery.start_research(tech_id):
		var tech_name = GameManager.TECHNOLOGIES[tech_id]["name"]
		_show_notification("Researching %s..." % tech_name)
		_create_monastery_tech_buttons()
		if _game_logger:
			_game_logger.log_action("research", {"tech": tech_id})
	else:
		_show_error("Cannot research!")


func _on_cancel_pressed() -> void:
	if selected_building and is_instance_valid(selected_building):
		# Cancel age research first if active (TC only)
		if selected_building is TownCenter:
			var tc = selected_building as TownCenter
			if tc.is_researching_age:
				tc.cancel_age_research()
				_show_notification("Age research cancelled")
				return
			if tc.is_researching:
				tc.cancel_research()
				_show_notification("Loom research cancelled")
				_update_loom_button()
				return
		# Cancel blacksmith research
		if selected_building is Blacksmith:
			if selected_building.is_researching:
				selected_building.cancel_research()
				_show_notification("Research cancelled")
				_create_blacksmith_tech_buttons()
				return
		# Cancel monastery research
		if selected_building is Monastery and selected_building.is_researching:
			selected_building.cancel_research()
			_show_notification("Research cancelled")
			_show_monastery_buttons(selected_building as Monastery)
			return
		# Cancel research on training buildings (barracks, archery range, stable)
		if (selected_building is Barracks or selected_building is ArcheryRange or selected_building is Stable) and selected_building.is_researching:
			selected_building.cancel_research()
			_show_notification("Research cancelled")
			# Refresh the panel to update upgrade button states
			if selected_building is Barracks:
				_show_barracks_buttons(selected_building as Barracks)
			elif selected_building is ArcheryRange:
				_show_archery_range_buttons(selected_building as ArcheryRange)
			elif selected_building is Stable:
				_show_stable_buttons(selected_building as Stable)
			return
		selected_building.cancel_training()


# ============================================================================
# Garrison panel
# ============================================================================

func show_garrison_building_panel(building: Building) -> void:
	selected_building = building
	selected_building_type = "garrison_building"
	_show_garrison_buttons(building)

func hide_garrison_panel() -> void:
	if selected_building_type == "garrison_building":
		_hide_all_action_buttons()
		selected_building = null
		selected_building_type = ""

func _show_garrison_buttons(building: Building) -> void:
	_hide_all_action_buttons()
	action_title.text = building.building_name
	selected_building = building
	selected_building_type = "garrison_building"
	if building.get_garrisoned_count() > 0:
		ungarrison_btn.visible = true
		ungarrison_btn.text = "Ungarrison All (%d)" % building.get_garrisoned_count()

func _on_ungarrison_pressed() -> void:
	if selected_building and is_instance_valid(selected_building):
		selected_building.ungarrison_all()
		# Refresh the current panel
		show_info(selected_building)

func _on_town_bell_pressed() -> void:
	if not selected_building is TownCenter:
		return
	var tc = selected_building as TownCenter
	if tc.bell_active:
		tc.ring_all_clear()
		town_bell_btn.text = "Town Bell"
		_show_notification("All clear!")
	else:
		tc.ring_town_bell()
		town_bell_btn.text = "All Clear"
		_show_notification("Town bell rung!")


# ============================================================================
# Minimap
# ============================================================================

func _on_minimap_clicked(world_position: Vector2) -> void:
	# Left click: jump camera to location
	var camera = get_viewport().get_camera_2d()
	if is_instance_valid(camera) and camera.has_method("jump_to"):
		camera.jump_to(world_position)


func _on_minimap_right_clicked(world_position: Vector2) -> void:
	# Right click: move selected units to location
	for unit in GameManager.selected_units:
		if is_instance_valid(unit) and unit.has_method("move_to"):
			unit.move_to(world_position)


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


func _setup_relic_countdown_label() -> void:
	relic_countdown_label = Label.new()
	relic_countdown_label.name = "RelicCountdown"
	relic_countdown_label.text = ""
	relic_countdown_label.visible = false
	relic_countdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	relic_countdown_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	relic_countdown_label.add_theme_font_size_override("font_size", 18)
	relic_countdown_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	relic_countdown_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	relic_countdown_label.position = Vector2(-200, 30)
	relic_countdown_label.custom_minimum_size = Vector2(400, 30)
	add_child(relic_countdown_label)


func _on_relic_countdown_started(team: int) -> void:
	relic_countdown_label.visible = true
	var team_name = "Player" if team == 0 else "AI"
	relic_countdown_label.text = "%s controls all relics!" % team_name


func _on_relic_countdown_updated(team: int, time_remaining: float) -> void:
	relic_countdown_label.visible = true
	var team_name = "Player" if team == 0 else "AI"
	relic_countdown_label.text = "%s controls all relics! %ds remaining" % [team_name, int(time_remaining)]


func _on_relic_countdown_cancelled() -> void:
	relic_countdown_label.visible = false


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
