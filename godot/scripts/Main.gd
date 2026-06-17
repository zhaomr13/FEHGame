extends Node2D

@onready var world_map = $WorldMap
@onready var battle_manager = $BattleScene
@onready var main_menu = $MainMenu
@onready var faction_select = $FactionSelectLayer/FactionSelect

var world_map_hud: CanvasLayer
var event_log_collapsed: Control
var event_log_collapsed_label: Label
var event_log_expanded: Control
var event_log_list: VBoxContainer
var event_log_expanded_flag: bool = false

# Faction starting positions
const FACTION_START_POSITIONS = {
	"askr": "city_11",    # central kingdom
	"embla": "city_01",   # northern empire
	"nifl": "city_45",    # eastern kingdom
	"muspell": "city_33"  # western frontier
}

var selected_faction: String = ""

func _ready():
	_setup_event_log_panel()

	# Connect start button
	var start_button = main_menu.get_node_or_null("StartButton")
	if start_button:
		start_button.pressed.connect(_on_start_pressed)

	# Connect faction selection
	faction_select.faction_selected.connect(_on_faction_selected)

	# Connect back button on faction select
	var back_button = faction_select.get_node_or_null("VBoxContainer/BackButton")
	if back_button:
		back_button.pressed.connect(_on_faction_back_pressed)

	GameManager.state_changed.connect(_on_state_changed)

	# Hide all except main menu initially
	world_map.visible = false
	battle_manager.visible = false
	faction_select.visible = false
	main_menu.visible = true
	if world_map_hud:
		world_map_hud.visible = false

func _on_start_pressed():
	main_menu.visible = false
	faction_select.visible = true

func _on_faction_back_pressed():
	faction_select.visible = false
	main_menu.visible = true

func _on_faction_selected(faction: String):
	selected_faction = faction

	# Initialize player army based on faction
	initialize_player_army(faction)

	# Set starting position based on faction
	var start_city = FACTION_START_POSITIONS.get(faction, "city_03")
	world_map.current_node_id = start_city

	# Initialize squads (all unassigned initially)
	GameManager.initialize_squads()

	faction_select.visible = false
	GameManager.change_state(GameConstants.GameState.WORLD_MAP)

	# Reinitialize world map with new starting position
	world_map.setup_faction_start(faction, start_city)

func initialize_player_army(faction: String):
	"""Assign characters to player based on faction choice"""
	GameManager.current_faction = faction
	GameManager.player_army.clear()

	# Get all characters belonging to the chosen faction
	var faction_characters = GameManager.get_characters_by_faction(faction)

	# If faction has no characters (e.g., player chooses a neutral start), give them some neutrals
	if faction_characters.is_empty():
		faction_characters = GameManager.get_characters_by_faction("")

	# Assign all faction characters to player
	for character in faction_characters:
		character.faction = faction  # Ensure faction is set correctly
		GameManager.player_army.append(character)
		print("Assigned ", character.character_name, " to player faction ", faction)

	# Set up available recruits (characters from other factions that can be recruited later)
	GameManager.available_recruits.clear()
	var other_factions = GameManager.get_characters_not_in_faction(faction)
	for char in other_factions:
		if char.faction != "":  # Only faction characters can be recruited, not neutrals
			GameManager.available_recruits.append(char)

func _on_state_changed(new_state: GameConstants.GameState):
	var world_map_camera = world_map.get_node_or_null("Camera2D")
	match new_state:
		GameConstants.GameState.WORLD_MAP:
			world_map.visible = true
			if world_map_hud:
				world_map_hud.visible = true
			battle_manager.visible = false
			main_menu.visible = false
			faction_select.visible = false
			if world_map_camera:
				world_map_camera.enabled = true
		GameConstants.GameState.BATTLE_DEPLOYMENT, \
		GameConstants.GameState.BATTLE_ACTIVE:
			world_map.visible = false
			if world_map_hud:
				world_map_hud.visible = false
			battle_manager.visible = true
			main_menu.visible = false
			faction_select.visible = false
			if world_map_camera:
				world_map_camera.enabled = false
		GameConstants.GameState.MAIN_MENU:
			world_map.visible = false
			if world_map_hud:
				world_map_hud.visible = false
			battle_manager.visible = false
			main_menu.visible = true
			faction_select.visible = false
			if world_map_camera:
				world_map_camera.enabled = false

func _setup_event_log_panel():
	world_map_hud = CanvasLayer.new()
	world_map_hud.name = "WorldMapHUD"
	add_child(world_map_hud)

	# --- collapsed: small bar at top-right showing latest message ---
	event_log_collapsed = Control.new()
	event_log_collapsed.name = "EventLogCollapsed"
	event_log_collapsed.anchor_left = 0.7
	event_log_collapsed.anchor_top = 0.0
	event_log_collapsed.anchor_right = 1.0
	event_log_collapsed.offset_top = 4
	event_log_collapsed.offset_bottom = 32
	event_log_collapsed.mouse_filter = Control.MOUSE_FILTER_STOP

	var collapsed_bg = ColorRect.new()
	collapsed_bg.name = "Bg"
	collapsed_bg.color = Color(0.05, 0.07, 0.09, 0.85)
	collapsed_bg.anchor_right = 1.0
	collapsed_bg.anchor_bottom = 1.0
	event_log_collapsed.add_child(collapsed_bg)

	event_log_collapsed_label = Label.new()
	event_log_collapsed_label.name = "Label"
	event_log_collapsed_label.anchor_left = 0.0
	event_log_collapsed_label.anchor_top = 0.0
	event_log_collapsed_label.anchor_right = 0.88
	event_log_collapsed_label.anchor_bottom = 1.0
	event_log_collapsed_label.offset_left = 8
	event_log_collapsed_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	event_log_collapsed_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	event_log_collapsed_label.clip_text = true
	event_log_collapsed_label.text = ""
	event_log_collapsed_label.add_theme_font_size_override("font_size", 13)
	event_log_collapsed.add_child(event_log_collapsed_label)

	var toggle_btn = Button.new()
	toggle_btn.name = "ToggleBtn"
	toggle_btn.text = "Log"
	toggle_btn.anchor_left = 0.88
	toggle_btn.anchor_right = 1.0
	toggle_btn.anchor_top = 0.0
	toggle_btn.anchor_bottom = 1.0
	toggle_btn.custom_minimum_size = Vector2(48, 0)
	toggle_btn.pressed.connect(_toggle_event_log)
	event_log_collapsed.add_child(toggle_btn)

	world_map_hud.add_child(event_log_collapsed)

	# --- expanded: dropdown panel below the collapsed bar ---
	event_log_expanded = Control.new()
	event_log_expanded.name = "EventLogExpanded"
	event_log_expanded.anchor_left = 0.5
	event_log_expanded.anchor_top = 0.0
	event_log_expanded.anchor_right = 1.0
	event_log_expanded.anchor_bottom = 1.0
	event_log_expanded.offset_top = 36
	event_log_expanded.mouse_filter = Control.MOUSE_FILTER_STOP
	event_log_expanded.visible = false

	var expanded_bg = ColorRect.new()
	expanded_bg.name = "Bg"
	expanded_bg.color = Color(0.08, 0.1, 0.12, 0.95)
	expanded_bg.anchor_right = 1.0
	expanded_bg.anchor_bottom = 1.0
	event_log_expanded.add_child(expanded_bg)

	var margin = MarginContainer.new()
	margin.name = "Margin"
	margin.anchor_right = 1.0
	margin.anchor_bottom = 1.0
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	event_log_expanded.add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.name = "VBox"
	vbox.add_theme_constant_override("separation", 6)
	margin.add_child(vbox)

	var collapse_btn = Button.new()
	collapse_btn.name = "CollapseBtn"
	collapse_btn.text = "▲ Collapse"
	collapse_btn.custom_minimum_size = Vector2(0, 28)
	collapse_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	collapse_btn.pressed.connect(_toggle_event_log)
	vbox.add_child(collapse_btn)

	event_log_list = VBoxContainer.new()
	event_log_list.name = "EventLogList"
	event_log_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	event_log_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	event_log_list.add_theme_constant_override("separation", 4)

	var scroll = ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(event_log_list)
	vbox.add_child(scroll)

	world_map_hud.add_child(event_log_expanded)

	if world_map.has_signal("event_logged"):
		world_map.event_logged.connect(_on_world_map_event_logged)

func _toggle_event_log():
	event_log_expanded_flag = not event_log_expanded_flag
	event_log_expanded.visible = event_log_expanded_flag

func _on_world_map_event_logged(message: String, color: Color):
	# Update collapsed label
	if event_log_collapsed_label:
		event_log_collapsed_label.text = message
		event_log_collapsed_label.modulate = color

	# Update expanded list
	if event_log_list:
		var entry = Label.new()
		entry.text = message
		entry.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		entry.modulate = color
		entry.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		event_log_list.add_child(entry)
		_trim_event_log()
		await get_tree().process_frame
		var scroll = event_log_list.get_parent()
		if scroll is ScrollContainer:
			(scroll as ScrollContainer).scroll_vertical = (scroll as ScrollContainer).get_v_scroll_bar().max_value

func _trim_event_log(max_entries: int = 60):
	if not event_log_list:
		return
	while event_log_list.get_child_count() > max_entries:
		var child = event_log_list.get_child(0)
		event_log_list.remove_child(child)
		child.queue_free()
