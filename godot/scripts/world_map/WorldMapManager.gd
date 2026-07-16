class_name WorldMapManager
extends Node2D

signal phase_changed(new_phase: int)
signal turn_started(turn_number: int)
signal event_logged(message: String, color: Color)

enum GamePhase {
	PLANNING,
	EXECUTING,
	BATTLE
}

@export var current_node_id: String = "city_1"
@export var player_morale: int = 100
@export var turn_count: int = 1

var current_phase: GamePhase = GamePhase.PLANNING
var current_faction: String = ""

var city_menu: Control = null
var army_manage_panel: ArmyManagePanel = null
var _last_opened_city_id: String = ""
var selected_army: Army = null
var planning_ui: Control = null
var army_selection_popup: ArmySelectionPopup = null
var event_log_panel: Control = null
var event_log_list: VBoxContainer = null

var encounter_banner: BattleEncounterBanner = null
var _is_encounter_active: bool = false
var _encounter_input_skip: bool = false
const ENCOUNTER_DURATION: float = 2.0
const ENCOUNTER_CAMERA_MOVE_DURATION: float = 0.8
const ENCOUNTER_CAMERA_ZOOM: float = 1.1

@onready var ui: CanvasLayer = $WorldMapUI
@onready var background_sprite: Sprite2D = $Background
@onready var map_data: MapDataManager = $MapDataManager
@onready var army_mgr_node: Node2D = $Armies
@onready var clock: GameClock = $GameClock

var all_armies: Array[Army] = []
var player_armies: Array[Army] = []
var enemy_armies: Array[Army] = []
var battling_armies: Array[Army] = []  # armies in current battle (for midpoint retreat)
var battle_city_id: String = ""

var _executing_armies: Dictionary = {}  # armies still moving during EXECUTING phase

var _drag_start: Vector2 = Vector2.ZERO
var _is_dragging: bool = false
var _is_shift_panning: bool = false
const DRAG_THRESHOLD: float = 5.0
const MIN_ZOOM: float = 0.25
const MAX_ZOOM: float = 1.5
const WHEEL_ZOOM_FACTOR: float = 1.2
const MAP_SIZE: Vector2 = Vector2(3840, 2160)
const ARMY_OFFSET_RADIUS: float = 0.0
const ROAD_ENCOUNTER_DISTANCE: float = 24.0
const MAP_FIT_PADDING: float = 0.95
const PLANNING_UI_HEIGHT: float = 80.0

@onready var camera: Camera2D = $Camera2D

func _ready():
	setup_background()
	if not map_data:
		print("ERROR: WorldMapManager - MapDataManager missing!")
		return
	map_data.create_map_nodes()
	map_data.draw_connections()
	setup_ui()
	setup_battle_result_handler()
	_setup_encounter_banner()
	map_data.node_clicked.connect(_on_node_clicked)
	if camera:
		_fit_camera()
	if get_tree() and get_tree().root:
		get_tree().root.size_changed.connect(_fit_camera)

func _process(_delta):
	if current_phase == GamePhase.EXECUTING:
		_check_encounters()

func _check_encounters():
	if _is_encounter_active:
		return
	for i in range(all_armies.size()):
		var a1 = all_armies[i]
		if not is_instance_valid(a1):
			continue
		for j in range(i + 1, all_armies.size()):
			var a2 = all_armies[j]
			if not is_instance_valid(a2):
				continue
			if _are_allies(a1, a2):
				continue
			if _should_start_battle(a1, a2):
				_start_battle(a1, a2)
				return

func _are_allies(a1: Army, a2: Army) -> bool:
	"""Return true if two armies belong to the same faction/alliance."""
	# All player armies are allies.
	if a1.army_type != Army.ArmyType.ENEMY and a2.army_type != Army.ArmyType.ENEMY:
		return true
	# Enemy armies are allies only if they share the same faction.
	if a1.army_type == Army.ArmyType.ENEMY and a2.army_type == Army.ArmyType.ENEMY:
		return a1.faction == a2.faction
	return false

func _should_start_battle(a1: Army, a2: Army) -> bool:
	"""Start battle when hostile armies share a city or collide on the same road segment."""
	if a1.current_city_id != "" and a1.current_city_id == a2.current_city_id:
		return true
	if not _is_reverse_road_segment(a1, a2):
		return false
	return a1.position.distance_to(a2.position) <= ROAD_ENCOUNTER_DISTANCE

func _is_reverse_road_segment(a1: Army, a2: Army) -> bool:
	if a1.state != Army.ArmyState.MOVING or a2.state != Army.ArmyState.MOVING:
		return false
	if a1.from_city_id == "" or a1.to_city_id == "" or a2.from_city_id == "" or a2.to_city_id == "":
		return false
	return a1.from_city_id == a2.to_city_id and a1.to_city_id == a2.from_city_id

func _on_node_clicked(node: MapNode):
	if _is_encounter_active:
		return
	if current_phase != GamePhase.PLANNING:
		return

	if selected_army == null:
		if not _can_open_city_menu(node):
			return
		open_city_menu(node)
		return

	# Army is selected — try to set route to clicked city
	var path = _find_route(selected_army, node.node_id)
	if not path.is_empty():
		var waypoints: Array[Vector2] = []
		var cities: Array[String] = []
		for city_id in path:
			if map_data.map_nodes.has(city_id):
				var pos = map_data.map_nodes[city_id].position
				waypoints.append(pos)
				cities.append(city_id)
		selected_army.set_route(waypoints, cities)
		_clear_selected_army()

func _find_route(army: Army, target_city: String) -> Array[String]:
	if not is_instance_valid(army):
		return []
	if target_city == "":
		return []
	var from_cities: Array[String] = []
	if army.current_city_id != "":
		from_cities.append(army.current_city_id)
	else:
		if army.from_city_id != "":
			from_cities.append(army.from_city_id)
		if army.to_city_id != "" and not from_cities.has(army.to_city_id):
			from_cities.append(army.to_city_id)

	for from_city in from_cities:
		if from_city == target_city:
			return []
		if not map_data.NODE_CONFIG.has(from_city) or not map_data.NODE_CONFIG.has(target_city):
			continue
		if map_data.NODE_CONFIG[from_city].connections.has(target_city):
			return [target_city]
	return []

func _can_open_city_menu(node: MapNode) -> bool:
	if not node:
		return false
	if not map_data.NODE_CONFIG.has(node.node_id):
		return false
	var faction: String = map_data.NODE_CONFIG[node.node_id].faction
	return faction == current_faction

func _input(event):
	if _is_encounter_active:
		return
	if event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				if camera:
					_zoom_camera(WHEEL_ZOOM_FACTOR)
			MOUSE_BUTTON_WHEEL_DOWN:
				if camera:
					_zoom_camera(1.0 / WHEEL_ZOOM_FACTOR)
			MOUSE_BUTTON_LEFT:
				if event.pressed:
					_is_shift_panning = Input.is_key_pressed(KEY_SHIFT)
					if _is_shift_panning:
						_drag_start = get_global_mouse_position()
						return
					if current_phase != GamePhase.PLANNING:
						return
					_drag_start = get_global_mouse_position()
					_is_dragging = false
				else:
					if _is_shift_panning:
						_is_shift_panning = false
						return
					if current_phase != GamePhase.PLANNING:
						return
					if not _is_dragging:
						_handle_world_click()
	elif event is InputEventMouseMotion:
		if camera and (Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE) or Input.is_key_pressed(KEY_SPACE) or _is_shift_panning or (Input.is_key_pressed(KEY_SHIFT) and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT))):
			camera.position -= event.relative / camera.zoom
		elif Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			var mouse_pos = get_viewport().get_mouse_position()
			if mouse_pos.distance_to(_drag_start) > DRAG_THRESHOLD:
				_is_dragging = true
	elif event is InputEventMagnifyGesture:
		if camera:
			_zoom_camera(event.factor)

func _unhandled_input(event: InputEvent):
	if not _is_encounter_active:
		return
	var skip = false
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		skip = true
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE or event.is_action("ui_accept"):
			skip = true
	if skip:
		_encounter_input_skip = true
		get_viewport().set_input_as_handled()

func _zoom_camera(factor: float):
	if not camera or not get_viewport():
		return
	var new_zoom = (camera.zoom * factor).clamp(Vector2(MIN_ZOOM, MIN_ZOOM), Vector2(MAX_ZOOM, MAX_ZOOM))

	# Zoom towards the mouse cursor: keep the world point under the cursor stationary.
	var viewport = get_viewport()
	var screen_center = viewport.get_visible_rect().size / 2.0
	var mouse_screen = viewport.get_mouse_position()
	var offset = (mouse_screen - screen_center) * (Vector2.ONE / camera.zoom - Vector2.ONE / new_zoom)
	camera.position += offset
	camera.zoom = new_zoom

func _handle_world_click():
	var world_pos = get_global_mouse_position()
	var clicked_army = _get_army_at_position(world_pos)
	if clicked_army:
		_on_army_clicked(clicked_army)

func _on_army_clicked(army: Army):
	if _is_encounter_active:
		return
	if army.army_type == Army.ArmyType.ENEMY:
		if selected_army and selected_army.army_type != Army.ArmyType.ENEMY:
			var path = _find_route(selected_army, army.current_city_id)
			if not path.is_empty():
				var waypoints: Array[Vector2] = []
				var cities: Array[String] = []
				for city_id in path:
					if map_data.map_nodes.has(city_id):
						var pos = map_data.map_nodes[city_id].position
						waypoints.append(pos)
						cities.append(city_id)
				selected_army.set_route(waypoints, cities)
				_clear_selected_army()
		return

	_set_selected_army(army)

func _set_destination_to(army: Army, target_city: String):
	var path = _find_route(army, target_city)
	if not path.is_empty():
		var waypoints: Array[Vector2] = []
		var cities: Array[String] = []
		for city_id in path:
			if map_data.map_nodes.has(city_id):
				var pos = map_data.map_nodes[city_id].position
				waypoints.append(pos)
				cities.append(city_id)
		army.set_route(waypoints, cities)

func _get_army_at_position(pos: Vector2) -> Army:
	for army in all_armies:
		if is_instance_valid(army) and army.position.distance_to(pos) < 30:
			return army
	return null

func _get_army_at_city(city_id: String) -> Army:
	for army in all_armies:
		if is_instance_valid(army) and army.current_city_id == city_id:
			return army
	return null

func _get_player_armies_at_city(city_id: String) -> Array[Army]:
	var result: Array[Army] = []
	for army in player_armies:
		if is_instance_valid(army) and army.current_city_id == city_id:
			result.append(army)
	return result

func _sync_city_faction_colors():
	"""Update all city colors from the stored ownership data."""
	for city_id in map_data.map_nodes.keys():
		if map_data.NODE_CONFIG.has(city_id):
			map_data.map_nodes[city_id].set_faction_color(map_data.NODE_CONFIG[city_id].faction)

func _refresh_city_ownership(city_id: String):
	"""Set a city to the faction currently occupying it, or neutral if empty."""
	if city_id == "" or not map_data.NODE_CONFIG.has(city_id):
		return

	var occupant_faction := ""
	for army in all_armies:
		if is_instance_valid(army) and army.current_city_id == city_id:
			occupant_faction = army.faction
			break

	_set_city_owner(city_id, occupant_faction)

func _set_city_owner(city_id: String, faction: String):
	if city_id == "" or not map_data.NODE_CONFIG.has(city_id):
		return
	map_data.NODE_CONFIG[city_id]["faction"] = faction
	if map_data.map_nodes.has(city_id):
		map_data.map_nodes[city_id].set_faction_color(faction)

func _get_battle_city_id(attacker: Army, defender: Army) -> String:
	"""Return the city being fought over, if the battle happens inside a city."""
	if is_instance_valid(attacker) and attacker.current_city_id != "" and attacker.state != Army.ArmyState.MOVING:
		return attacker.current_city_id
	if is_instance_valid(defender) and defender.current_city_id != "" and defender.state != Army.ArmyState.MOVING:
		return defender.current_city_id
	return ""

func _get_winning_faction(victory: bool) -> String:
	if victory:
		return current_faction
	for army in battling_armies:
		if is_instance_valid(army) and army.army_type == Army.ArmyType.ENEMY:
			return army.faction
	return ""

func _remove_battle_losers(victory: bool):
	for army in battling_armies:
		if not is_instance_valid(army):
			continue
		var lost_side = (victory and army.army_type == Army.ArmyType.ENEMY) or (not victory and army.army_type != Army.ArmyType.ENEMY)
		if lost_side:
			_destroy_battle_army(army)

func setup_faction_start(faction: String, start_city: String):
	current_faction = faction
	current_node_id = start_city
	current_phase = GamePhase.PLANNING
	if planning_ui:
		planning_ui.visible = true
	_update_planning_ui()

	_clear_armies()
	for child in map_data.map_nodes_container.get_children():
		child.queue_free()
	map_data.map_nodes.clear()
	map_data.reset_ownership()
	map_data.create_map_nodes()

	_create_player_armies_from_squads(start_city)
	_create_enemy_armies(faction)

func _clear_armies():
	for army in all_armies:
		if is_instance_valid(army):
			army.queue_free()
	all_armies.clear()
	player_armies.clear()
	enemy_armies.clear()

func _create_player_armies_from_squads(start_city: String):
	var source_squads: Array = []

	# Use configured squads if any are non-empty; otherwise split player_army into 10 squads
	var has_configured_squads = false
	for squad_data in GameManager.squad_data:
		if not squad_data.is_empty():
			has_configured_squads = true
			break

	if has_configured_squads:
		for squad_data in GameManager.squad_data:
			source_squads.append(squad_data.duplicate())
	else:
		source_squads = _split_characters_into_squads(GameManager.player_army, GameConstants.ARMIES_PER_FACTION)

	# Place player armies only in player-controlled cities at start.
	var placement_cities = _get_faction_cities(current_faction)
	if placement_cities.is_empty():
		placement_cities = [start_city]
	elif not placement_cities.has(start_city):
		placement_cities.push_front(start_city)
	if placement_cities.is_empty():
		placement_cities = [start_city]

	var squad_index = 0
	for squad_data in source_squads:
		if squad_data.is_empty():
			squad_index += 1
			continue

		var city_id = placement_cities[squad_index % placement_cities.size()]
		var army_type = Army.ArmyType.PLAYER_MAIN if squad_index == 0 else Army.ArmyType.PLAYER_SQUAD
		var offset = _army_offset(squad_index, source_squads.size())
		var army = _create_army(squad_data, city_id, army_type, offset)
		army.army_id = "player_squad_%d" % squad_index
		army.army_name = "Squad %d" % (squad_index + 1) if squad_index > 0 else "Main Army"
		army.squad_index = squad_index
		army.faction = current_faction
		army.army_clicked.connect(_on_army_clicked)
		player_armies.append(army)
		all_armies.append(army)
		squad_index += 1

	if player_armies.is_empty():
		var chars = GameManager.player_army.duplicate()
		var army = _create_army(chars, start_city, Army.ArmyType.PLAYER_MAIN)
		army.army_id = "player_main"
		army.army_name = "Main Army"
		army.faction = current_faction
		army.army_clicked.connect(_on_army_clicked)
		player_armies.append(army)
		all_armies.append(army)

	_sync_city_faction_colors()

func _create_army(chars: Array, start_city: String, type: Army.ArmyType = Army.ArmyType.PLAYER_SQUAD, offset: Vector2 = Vector2.ZERO) -> Army:
	var army = Army.new()
	army.current_city_id = start_city
	army.squad_data = _convert_squad_data(chars)
	army.army_type = type
	army.movement_finished.connect(_on_army_movement_finished)
	army_mgr_node.add_child(army)
	if map_data.map_nodes.has(start_city):
		army.position = map_data.map_nodes[start_city].position + offset
	army.left_city.connect(_on_army_left_city)
	return army

func _convert_squad_data(data: Array) -> Array[CharacterData]:
	var result: Array[CharacterData] = []
	for char in data:
		if char is CharacterData:
			result.append(char)
	return result

func _army_offset(index: int, total: int) -> Vector2:
	var angle = 2.0 * PI * index / max(1, total)
	return Vector2(cos(angle), sin(angle)) * ARMY_OFFSET_RADIUS

func _split_characters_into_squads(characters: Array, squad_count: int) -> Array[Array]:
	var squads: Array[Array] = []
	for i in range(squad_count):
		squads.append([])
	for i in range(characters.size()):
		var squad_index = i % max(1, squad_count)
		squads[squad_index].append(characters[i])
	return squads

func _get_faction_cities(faction: String) -> Array[String]:
	var cities: Array[String] = []
	for city_id in map_data.NODE_CONFIG.keys():
		if map_data.NODE_CONFIG[city_id].faction == faction:
			cities.append(city_id)
	return cities

func _get_start_region_cities(start_city: String, count: int) -> Array[String]:
	"""Return up to `count` connected cities starting from `start_city` using BFS."""
	var result: Array[String] = []
	if not map_data.NODE_CONFIG.has(start_city):
		return result
	var visited: Dictionary = {start_city: true}
	var queue: Array[String] = [start_city]
	while not queue.is_empty() and result.size() < count:
		var current = queue.pop_front()
		result.append(current)
		for neighbor in map_data.NODE_CONFIG[current].connections:
			if not visited.has(neighbor):
				visited[neighbor] = true
				queue.append(neighbor)
	return result

func _create_enemy_armies(player_faction: String):
	var all_factions = ["askr", "embla", "nifl", "muspell"]
	for faction in all_factions:
		if faction == player_faction:
			continue
		var faction_chars = GameManager.get_characters_by_faction(faction)
		if faction_chars.is_empty():
			continue

		var squads = _split_characters_into_squads(faction_chars, GameConstants.ARMIES_PER_FACTION)
		var faction_cities = _get_faction_cities(faction)
		if faction_cities.is_empty():
			# Fallback: use the faction's predefined start city if no city on map matches
			faction_cities = ["city_01"]

		for i in range(squads.size()):
			if squads[i].is_empty():
				continue
			var city_id = faction_cities[i % faction_cities.size()]
			var offset = _army_offset(i, squads.size())
			var army = _create_army(squads[i], city_id, Army.ArmyType.ENEMY, offset)
			army.army_id = "enemy_%s_%d" % [faction, i]
			army.army_name = "Enemy %s %d" % [faction.capitalize(), i + 1]
			army.faction = faction
			army.army_clicked.connect(_on_army_clicked)
			enemy_armies.append(army)
			all_armies.append(army)

	_sync_city_faction_colors()

func _plan_ai_moves():
	for enemy in enemy_armies:
		if not is_instance_valid(enemy):
			continue
		var enemy_city = enemy.current_city_id if enemy.current_city_id != "" else map_data.get_nearest_city(enemy.position)
		if enemy_city == "" or not map_data.NODE_CONFIG.has(enemy_city):
			continue
		var connections = map_data.NODE_CONFIG[enemy_city].connections
		for connected_id in connections:
			for player in player_armies:
				if is_instance_valid(player) and player.current_city_id == connected_id:
					_set_destination_to(enemy, connected_id)
					break

func setup_background():
	# Background texture is assigned in WorldMap.tscn via the editor.
	# This function is kept as a hook for any future runtime background setup.
	pass

func _fit_camera():
	if not camera:
		return
	var viewport_size := get_viewport().get_visible_rect().size
	var usable_height := viewport_size.y - PLANNING_UI_HEIGHT
	if usable_height <= 0:
		return
	var fit_x: float = viewport_size.x / MAP_SIZE.x
	var fit_y: float = usable_height / MAP_SIZE.y
	var fit_zoom: float = min(fit_x, fit_y) * MAP_FIT_PADDING
	camera.zoom = Vector2(fit_zoom, fit_zoom)
	camera.position = MAP_SIZE / 2.0
	_update_camera_limits()

func setup_ui():
	setup_city_menu()
	setup_army_manage_panel()
	setup_planning_ui()
	setup_army_selection_popup()

func setup_army_selection_popup():
	army_selection_popup = preload("res://scenes/ui/ArmySelectionPopup.tscn").instantiate()
	ui.add_child(army_selection_popup)
	army_selection_popup.army_selected.connect(_on_popup_army_selected)
	army_selection_popup.cancelled.connect(_on_popup_cancelled)

func _on_popup_army_selected(army: Army):
	_on_army_clicked(army)

func _on_popup_cancelled():
	if city_menu:
		city_menu.visible = true

func setup_planning_ui():
	planning_ui = Control.new()
	planning_ui.name = "PlanningUI"

	var panel = Panel.new()
	panel.name = "Panel"
	panel.set_anchors_preset(Control.PRESET_TOP_WIDE)
	panel.custom_minimum_size = Vector2(0, 80)

	var hbox = HBoxContainer.new()
	hbox.name = "ButtonContainer"
	hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER

	var end_planning_btn = Button.new()
	end_planning_btn.name = "EndPlanningButton"
	end_planning_btn.text = "结束计划"
	end_planning_btn.custom_minimum_size = Vector2(200, 50)
	end_planning_btn.pressed.connect(_on_end_planning_pressed)

	var cancel_plan_btn = Button.new()
	cancel_plan_btn.name = "ClearPlansButton"
	cancel_plan_btn.text = "清除计划"
	cancel_plan_btn.custom_minimum_size = Vector2(150, 50)
	cancel_plan_btn.pressed.connect(_on_clear_plans_pressed)

	hbox.add_child(end_planning_btn)
	hbox.add_child(cancel_plan_btn)
	panel.add_child(hbox)
	planning_ui.add_child(panel)
	planning_ui.visible = false

	var status_label = Label.new()
	status_label.name = "ExecutionStatusLabel"
	status_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	status_label.position = Vector2(0, 90)
	status_label.custom_minimum_size = Vector2(400, 30)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.visible = false
	ui.add_child(status_label)

	ui.add_child(planning_ui)

func _log_event(message: String, color: Color = Color(0.92, 0.92, 0.92)):
	event_logged.emit(message, color)

func set_event_log_visible(visible: bool):
	pass

func clear_event_log():
	pass

func _update_camera_limits():
	if not camera:
		return
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = MAP_SIZE.x
	camera.limit_bottom = MAP_SIZE.y

func _update_planning_ui():
	if not planning_ui:
		return
	var end_btn = planning_ui.get_node_or_null("Panel/ButtonContainer/EndPlanningButton")
	var clear_btn = planning_ui.get_node_or_null("Panel/ButtonContainer/ClearPlansButton")
	var status = ui.get_node_or_null("ExecutionStatusLabel")

	var is_planning = current_phase == GamePhase.PLANNING
	if end_btn:
		end_btn.disabled = not is_planning
	if clear_btn:
		clear_btn.disabled = not is_planning
	if status:
		status.visible = not is_planning
		if current_phase == GamePhase.EXECUTING:
			status.text = "执行中..."
		elif current_phase == GamePhase.BATTLE:
			status.text = "战斗中..."

func setup_city_menu():
	city_menu = preload("res://scenes/ui/CityMenu.tscn").instantiate()
	ui.add_child(city_menu)
	city_menu.open_formation.connect(_on_open_formation)
	city_menu.army_selected.connect(_on_city_army_selected)
	city_menu.city_closed.connect(_on_city_closed)
	city_menu.visible = false

func setup_army_manage_panel():
	if army_manage_panel != null:
		return
	army_manage_panel = preload("res://scenes/ui/ArmyManagePanel.tscn").instantiate()
	ui.add_child(army_manage_panel)
	army_manage_panel.saved.connect(_on_army_manage_saved)
	army_manage_panel.cancelled.connect(_on_army_manage_cancelled)
	army_manage_panel.visible = false

func _on_end_planning_pressed():
	if current_phase != GamePhase.PLANNING:
		return
	_start_execution()

func _on_clear_plans_pressed():
	for army in player_armies:
		if is_instance_valid(army):
			army.clear_plan()
	_clear_selected_army()
	_log_event("所有计划已清除。", Color(0.8, 0.8, 0.95))

func _start_execution():
	if _is_encounter_active:
		return
	if current_phase != GamePhase.PLANNING:
		return
	current_phase = GamePhase.EXECUTING
	phase_changed.emit(current_phase)
	if planning_ui:
		planning_ui.visible = false
	_executing_armies.clear()
	_plan_ai_moves()
	for army in all_armies:
		if is_instance_valid(army) and army.has_plan():
			army.update_visibility()
			army.execute_plan()
			_executing_armies[army] = true
	if clock:
		clock.is_running = true
	if _executing_armies.is_empty():
		_end_execution()
	_update_planning_ui()

func _on_army_movement_finished(army: Army):
	if not _executing_armies.has(army):
		return
	_executing_armies.erase(army)
	_refresh_city_ownership(army.current_city_id)
	if army.current_city_id != "":
		_log_event("%s 进入 %s。" % [army.army_name, _get_city_display_name(army.current_city_id)], Color(0.8, 0.95, 0.8))
	if current_phase == GamePhase.EXECUTING and player_armies.has(army):
		_check_encounters()
		if current_phase != GamePhase.EXECUTING:
			return
		_reset_armies_after_execution()
		_end_execution()
		return
	if current_phase == GamePhase.EXECUTING and _executing_armies.is_empty():
		_end_execution()

func _on_army_left_city(army: Army, city_id: String):
	_refresh_city_ownership(city_id)
	_log_event("%s 离开 %s。" % [army.army_name, _get_city_display_name(city_id)], Color(0.95, 0.85, 0.7))

func _end_execution():
	if current_phase != GamePhase.EXECUTING:
		return
	_executing_armies.clear()
	current_phase = GamePhase.PLANNING
	phase_changed.emit(current_phase)
	if clock:
		clock.is_running = false
	if planning_ui:
		planning_ui.visible = true
	turn_count += 1
	_on_turn_started()
	_update_planning_ui()

func _on_turn_started():
	turn_started.emit(turn_count)

func open_city_menu(node: MapNode):
	if _is_encounter_active:
		return
	if city_menu:
		_last_opened_city_id = node.node_id
		var garrisoned = _get_player_armies_at_city(node.node_id)
		city_menu.show_city(node.node_name, node.node_type, false, garrisoned)

func _on_city_army_selected(army: Army):
	if not is_instance_valid(army):
		return
	_set_selected_army(army)
	if city_menu:
		city_menu.visible = false

func _on_city_closed():
	_clear_selected_army()

func _on_open_formation():
	if _is_encounter_active:
		return
	_clear_selected_army()
	var city_id = _last_opened_city_id if _last_opened_city_id != "" else current_node_id
	if not army_manage_panel or city_id == "":
		return
	var garrisoned: Array = []
	var squad_indices: Array[int] = []
	for army in _get_player_armies_at_city(city_id):
		if is_instance_valid(army):
			garrisoned.append(army.squad_data)
			squad_indices.append(army.squad_index)
	var city_name = _get_city_display_name(city_id)
	army_manage_panel.setup(garrisoned, GameManager.unassigned_units, city_name, city_id, squad_indices)
	army_manage_panel.visible = true

func _on_army_manage_saved(armies: Array, unassigned: Array, army_squad_indices: Array):
	_sync_armies_in_place(armies, unassigned, army_squad_indices)
	if city_menu and _last_opened_city_id != "":
		var node = map_data.map_nodes.get(_last_opened_city_id)
		if node:
			open_city_menu(node)
		else:
			city_menu.visible = true

func _on_army_manage_cancelled():
	_clear_selected_army()
	if city_menu:
		city_menu.visible = true

func _sync_armies_in_place(new_armies: Array, new_unassigned: Array, army_squad_indices: Array):
	"""Update/create/remove Army nodes at the garrison city based on panel result."""
	var city_id = _last_opened_city_id if _last_opened_city_id != "" else current_node_id

	# Step 1: Remove armies at this city that were disbanded in the panel
	var panel_indices: Dictionary = {}
	for sidx in army_squad_indices:
		if sidx >= 0:
			panel_indices[sidx] = true
	var ri = player_armies.size() - 1
	while ri >= 0:
		var army = player_armies[ri]
		if is_instance_valid(army) and army.squad_index >= 0 \
				and army.current_city_id == city_id \
				and not panel_indices.has(army.squad_index):
			GameManager.squad_data[army.squad_index] = []
			_remove_army(army)
		ri -= 1

	# Step 2: Rebuild lookup AFTER removals so freed slots are truly gone
	var indexed_armies: Dictionary = {}
	for army in player_armies:
		if is_instance_valid(army) and army.squad_index >= 0:
			indexed_armies[army.squad_index] = army

	# Step 3: Allocate squad_indices for brand-new armies (index == -1)
	var used_indices: Dictionary = indexed_armies.duplicate()  # keys are squad_indices in use
	for sidx in army_squad_indices:
		if sidx >= 0:
			used_indices[sidx] = true
	var free_slot_ptr: int = 0
	for i in range(new_armies.size()):
		if army_squad_indices[i] == -1:
			while free_slot_ptr < GameConstants.MAX_SQUADS and used_indices.has(free_slot_ptr):
				free_slot_ptr += 1
			if free_slot_ptr < GameConstants.MAX_SQUADS:
				army_squad_indices[i] = free_slot_ptr
				used_indices[free_slot_ptr] = true
				free_slot_ptr += 1
			else:
				push_error("_sync_armies_in_place: no free squad slots")
				army_squad_indices[i] = 0

	# Step 4: Update existing armies and create new ones
	for i in range(new_armies.size()):
		var squad = new_armies[i]
		var sidx: int = army_squad_indices[i]

		var typed_squad: Array[CharacterData] = []
		typed_squad.assign(squad)
		if sidx < GameManager.squad_data.size():
			GameManager.squad_data[sidx] = typed_squad

		if indexed_armies.has(sidx):
			indexed_armies[sidx].squad_data = typed_squad
		else:
			var army_type = Army.ArmyType.PLAYER_MAIN if sidx == 0 else Army.ArmyType.PLAYER_SQUAD
			var army = _create_army(squad, city_id, army_type)
			army.army_id = "player_squad_%d" % sidx
			army.army_name = "主队" if sidx == 0 else "第%d队" % (sidx + 1)
			army.squad_index = sidx
			army.faction = current_faction
			army.army_clicked.connect(_on_army_clicked)
			player_armies.append(army)
			all_armies.append(army)

	# Step 5: Sync unassigned units
	var typed_unassigned: Array[CharacterData] = []
	typed_unassigned.assign(new_unassigned)
	GameManager.unassigned_units = typed_unassigned

	_sync_city_faction_colors()

func _setup_encounter_banner():
	var banner_scene = preload("res://scenes/ui/BattleEncounterBanner.tscn")
	if banner_scene:
		encounter_banner = banner_scene.instantiate()
		add_child(encounter_banner)

func _start_battle(attacker: Army, defender: Army):
	_start_battle_encounter(attacker, defender)

func _start_battle_encounter(attacker: Army, defender: Army):
	_is_encounter_active = true
	_encounter_input_skip = false

	var city_id = _get_battle_city_id(attacker, defender)
	var city_name = _get_city_display_name(city_id)
	if city_name == city_id and attacker.from_city_id != "" and attacker.to_city_id != "":
		city_name = _get_city_display_name(attacker.to_city_id)

	var attacker_name = attacker.get_leader_name()
	var defender_name = defender.get_leader_name()

	if encounter_banner:
		encounter_banner.show_encounter(attacker_name, defender_name, city_name, attacker.faction, defender.faction)

	var camera_target = _get_encounter_camera_target(attacker, defender, city_id)
	var original_position = camera.position if camera else Vector2.ZERO
	var original_zoom = camera.zoom if camera else Vector2.ONE

	if camera:
		var tween = create_tween()
		tween.set_trans(Tween.TRANS_QUAD)
		tween.set_ease(Tween.EASE_OUT)
		tween.tween_property(camera, "position", camera_target, ENCOUNTER_CAMERA_MOVE_DURATION)
		tween.parallel().tween_property(camera, "zoom", Vector2.ONE * ENCOUNTER_CAMERA_ZOOM, ENCOUNTER_CAMERA_MOVE_DURATION)

	await _wait_for_encounter_or_skip()

	_is_encounter_active = false
	if encounter_banner:
		await encounter_banner.hide_banner()

	if camera:
		var reset_tween = create_tween()
		reset_tween.set_trans(Tween.TRANS_QUAD)
		reset_tween.set_ease(Tween.EASE_OUT)
		reset_tween.tween_property(camera, "position", original_position, 0.3)
		reset_tween.parallel().tween_property(camera, "zoom", original_zoom, 0.3)
		await reset_tween.finished

	_enter_battle(attacker, defender)

func _get_encounter_camera_target(attacker: Army, defender: Army, city_id: String) -> Vector2:
	if city_id != "" and map_data.NODE_CONFIG.has(city_id):
		return map_data.NODE_CONFIG[city_id]["pos"]
	if is_instance_valid(attacker) and is_instance_valid(defender):
		return (attacker.position + defender.position) * 0.5
	return Vector2.ZERO

func _wait_for_encounter_or_skip():
	var elapsed = 0.0
	while elapsed < ENCOUNTER_DURATION:
		if _encounter_input_skip:
			break
		await get_tree().process_frame
		elapsed += get_process_delta_time()

func _enter_battle(attacker: Army, defender: Army):
	_pause_all_armies_for_battle()
	current_phase = GamePhase.BATTLE
	phase_changed.emit(current_phase)
	_executing_armies.clear()
	attacker.state = Army.ArmyState.IN_BATTLE
	defender.state = Army.ArmyState.IN_BATTLE
	battling_armies = [attacker, defender]
	battle_city_id = _get_battle_city_id(attacker, defender)
	var battle_bg = "plain"
	if battle_city_id != "" and map_data.map_nodes.has(battle_city_id):
		battle_bg = map_data.select_battle_background(map_data.map_nodes[battle_city_id])
	_log_event(_describe_battle_start(attacker, defender), Color(1.0, 0.7, 0.55))
	GameManager.start_battle_with_background(attacker.squad_data, defender.squad_data, battle_bg)
	_update_planning_ui()

func setup_battle_result_handler():
	GameManager.battle_ended.connect(_on_battle_ended)

func _on_battle_ended(victory: bool):
	current_phase = GamePhase.PLANNING
	phase_changed.emit(current_phase)
	_executing_armies.clear()
	if clock:
		clock.is_running = false
	var winning_faction = _get_winning_faction(victory)
	if battle_city_id != "" and winning_faction != "":
		_set_city_owner(battle_city_id, winning_faction)
		_log_event("%s 现在由 %s 控制。" % [_get_city_display_name(battle_city_id), winning_faction], Color(0.8, 0.9, 1.0))
	_remove_battle_losers(victory)

	var i = all_armies.size() - 1
	while i >= 0:
		if not is_instance_valid(all_armies[i]):
			all_armies.remove_at(i)
		i -= 1
	# Midpoint retreat: armies not at a city step back toward origin
	battling_armies = battling_armies.filter(func(a): return is_instance_valid(a) and all_armies.has(a))
	for army in battling_armies:
		if is_instance_valid(army) and army.from_city_id != "" and army.to_city_id != "":
			var nearest = map_data.get_nearest_city(army.position)
			var nearest_pos = map_data.NODE_CONFIG[nearest]["pos"] if nearest != "" and map_data.NODE_CONFIG.has(nearest) else Vector2.ZERO
			if army.position.distance_to(nearest_pos) > 15:
				# Not at a city — retreat toward origin
				var origin_pos = map_data.NODE_CONFIG[army.from_city_id]["pos"] if map_data.NODE_CONFIG.has(army.from_city_id) else null
				if origin_pos != null:
					var dir = (origin_pos - army.position).normalized()
					army.position += dir * 40
					army.current_city_id = ""
	for army in battling_armies:
		if is_instance_valid(army):
			army.state = Army.ArmyState.IDLE
	battling_armies.clear()
	battle_city_id = ""
	_reset_armies_after_battle()

	# Sync city colors after battle outcome and midpoint retreat.
	_sync_city_faction_colors()

	# Battle path: increment turn when returning to planning (mirror of _end_execution)
	turn_count += 1
	_on_turn_started()
	_update_planning_ui()
	_log_event(_describe_battle_end(victory), Color(0.85, 0.9, 1.0))

	if planning_ui:
		planning_ui.visible = true
	GameManager.change_state(GameConstants.GameState.WORLD_MAP)
	visible = true

func _pause_all_armies_for_battle():
	for army in all_armies:
		if is_instance_valid(army):
			army.pause_for_battle()

func _reset_armies_after_battle():
	_clear_selected_army()
	for army in all_armies:
		if is_instance_valid(army):
			army.reset_for_planning()

func _reset_armies_after_execution():
	_clear_selected_army()
	for army in all_armies:
		if is_instance_valid(army):
			army.reset_for_planning()

func _remove_army(army: Army):
	"""Remove an army from tracking arrays and queue it for deletion."""
	if not is_instance_valid(army):
		return
	all_armies.erase(army)
	player_armies.erase(army)
	enemy_armies.erase(army)
	if selected_army == army:
		selected_army = null
	army.queue_free()

func _destroy_battle_army(army: Army):
	"""Explicitly clean up an army defeated in battle."""
	if not is_instance_valid(army):
		return
	_log_event("%s 在战斗中被消灭。" % army.army_name, Color(1.0, 0.75, 0.75))
	army.pause_for_battle()
	army.planned_route.clear()
	army.planned_cities.clear()
	army.route.clear()
	army.route_cities.clear()
	army.plan_line.visible = false
	army.target_city_id = ""
	army.from_city_id = ""
	army.to_city_id = ""
	army.state = Army.ArmyState.IDLE
	army.update_visibility()
	if army.army_type != Army.ArmyType.ENEMY and army.squad_index >= 0 and army.squad_index < GameManager.squad_data.size():
		GameManager.destroy_squad_after_defeat(army.squad_index)
	_remove_army(army)

func _set_selected_army(army: Army):
	if selected_army and is_instance_valid(selected_army) and selected_army != army:
		selected_army.set_selected(false)
	selected_army = army
	if selected_army and is_instance_valid(selected_army):
		selected_army.set_selected(true)

func _clear_selected_army():
	if selected_army and is_instance_valid(selected_army):
		selected_army.set_selected(false)
	selected_army = null

func _get_city_display_name(city_id: String) -> String:
	if map_data.NODE_CONFIG.has(city_id):
		return map_data.NODE_CONFIG[city_id].name
	return city_id

func _describe_battle_start(attacker: Army, defender: Army) -> String:
	if battle_city_id != "":
		return "%s 战斗开始：%s vs %s。" % [_get_city_display_name(battle_city_id), attacker.army_name, defender.army_name]
	if attacker.from_city_id != "" and attacker.to_city_id != "":
		return "道路遭遇战：%s vs %s。" % [attacker.army_name, defender.army_name]
	return "战斗开始：%s vs %s。" % [attacker.army_name, defender.army_name]

func _describe_battle_end(victory: bool) -> String:
	var result = "胜利" if victory else "失败"
	if battle_city_id != "":
		return "%s 战斗%s。" % [_get_city_display_name(battle_city_id), result]
	return "战斗%s。" % result
