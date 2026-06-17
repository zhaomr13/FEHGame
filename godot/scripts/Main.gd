extends Node2D

@onready var world_map = $WorldMap
@onready var battle_manager = $BattleScene
@onready var main_menu = $MainMenu
@onready var faction_select = $FactionSelectLayer/FactionSelect

const WORLD_MAP_RATIO: float = 0.75

var world_map_container: SubViewportContainer
var world_map_viewport: SubViewport
var world_map_hud: CanvasLayer
var event_log_panel: PanelContainer
var event_log_list: VBoxContainer

# Faction starting positions
const FACTION_START_POSITIONS = {
	"askr": "city_11",    # central kingdom
	"embla": "city_01",   # northern empire
	"nifl": "city_45",    # eastern kingdom
	"muspell": "city_33"  # western frontier
}

var selected_faction: String = ""

func _ready():
	_setup_world_map_split()
	var viewport = get_viewport()
	if viewport and not viewport.size_changed.is_connected(_layout_world_map_split):
		viewport.size_changed.connect(_layout_world_map_split)

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
	if world_map_container:
		world_map_container.visible = false

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
			if world_map_container:
				world_map_container.visible = true
			if world_map_hud:
				world_map_hud.visible = true
			if world_map:
				world_map.visible = true
			_clear_event_log()
			battle_manager.visible = false
			main_menu.visible = false
			faction_select.visible = false
			if world_map_camera:
				world_map_camera.enabled = true
		GameConstants.GameState.BATTLE_DEPLOYMENT, \
		GameConstants.GameState.BATTLE_ACTIVE:
			if world_map_container:
				world_map_container.visible = false
			if world_map_hud:
				world_map_hud.visible = false
			if world_map:
				world_map.visible = false
			battle_manager.visible = true
			main_menu.visible = false
			faction_select.visible = false
			if world_map_camera:
				world_map_camera.enabled = false
		GameConstants.GameState.MAIN_MENU:
			if world_map_container:
				world_map_container.visible = false
			if world_map_hud:
				world_map_hud.visible = false
			if world_map:
				world_map.visible = false
			battle_manager.visible = false
			main_menu.visible = true
			faction_select.visible = false
			if world_map_camera:
				world_map_camera.enabled = false

func _setup_world_map_split():
	_layout_world_map_split()

	world_map_container = SubViewportContainer.new()
	world_map_container.name = "WorldMapContainer"
	world_map_container.position = Vector2.ZERO
	world_map_container.size = _get_world_map_container_size()
	world_map_container.stretch = true
	add_child(world_map_container)

	world_map_viewport = SubViewport.new()
	world_map_viewport.name = "WorldMapViewport"
	world_map_viewport.size = Vector2i(world_map_container.size)
	world_map_viewport.transparent_bg = true
	world_map_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	world_map_container.add_child(world_map_viewport)

	world_map.reparent(world_map_viewport)
	world_map.position = Vector2.ZERO

	world_map_hud = CanvasLayer.new()
	world_map_hud.name = "WorldMapHUD"
	add_child(world_map_hud)

	event_log_panel = PanelContainer.new()
	event_log_panel.name = "EventLogPanel"
	event_log_panel.anchor_left = WORLD_MAP_RATIO
	event_log_panel.anchor_top = 0.0
	event_log_panel.anchor_right = 1.0
	event_log_panel.anchor_bottom = 1.0
	event_log_panel.offset_left = 0
	event_log_panel.offset_top = 0
	event_log_panel.offset_right = 0
	event_log_panel.offset_bottom = 0

	var divider = ColorRect.new()
	divider.color = Color(0.15, 0.18, 0.22, 1.0)
	divider.anchor_left = 0.0
	divider.anchor_top = 0.0
	divider.anchor_right = 0.0
	divider.anchor_bottom = 1.0
	divider.offset_left = -2
	divider.offset_right = 0
	event_log_panel.add_child(divider)

	var vbox = VBoxContainer.new()
	vbox.anchor_left = 0.0
	vbox.anchor_top = 0.0
	vbox.anchor_right = 1.0
	vbox.anchor_bottom = 1.0
	vbox.offset_left = 12
	vbox.offset_top = 12
	vbox.offset_right = -12
	vbox.offset_bottom = -12
	vbox.add_theme_constant_override("separation", 8)
	event_log_panel.add_child(vbox)

	var title = Label.new()
	title.text = "Event Log"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	vbox.add_child(title)

	event_log_list = VBoxContainer.new()
	event_log_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	event_log_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	event_log_list.add_theme_constant_override("separation", 6)

	var scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(event_log_list)
	vbox.add_child(scroll)

	event_log_panel.visible = false
	world_map_hud.add_child(event_log_panel)

	if world_map.has_signal("event_logged"):
		world_map.event_logged.connect(_on_world_map_event_logged)

func _on_world_map_event_logged(message: String, color: Color):
	if not event_log_list or not event_log_panel.visible:
		return
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

func _clear_event_log():
	if not event_log_list:
		return
	for child in event_log_list.get_children():
		child.queue_free()

func _layout_world_map_split():
	if not get_viewport():
		return
	var size = get_viewport().get_visible_rect().size
	var map_size = _get_world_map_container_size(size)
	if world_map_container:
		world_map_container.size = map_size
	if world_map_viewport:
		world_map_viewport.size = Vector2i(map_size)

func _get_world_map_container_size(viewport_size: Vector2 = Vector2.ZERO) -> Vector2:
	if viewport_size == Vector2.ZERO:
		viewport_size = get_viewport().get_visible_rect().size if get_viewport() else Vector2(1280, 720)
	return Vector2(viewport_size.x * WORLD_MAP_RATIO, viewport_size.y)
