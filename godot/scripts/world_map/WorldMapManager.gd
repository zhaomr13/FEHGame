class_name WorldMapManager
extends Node2D

signal phase_changed(new_phase: int)
signal turn_started(turn_number: int)

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
var squad_menu: Control = null
var selected_army: Army = null
var planning_ui: Control = null

@onready var ui: CanvasLayer = $WorldMapUI
@onready var background_sprite: Sprite2D = $Background
@onready var map_data: MapDataManager = $MapDataManager
@onready var army_mgr_node: Node2D = $Armies
@onready var clock: GameClock = $GameClock

var all_armies: Array[Army] = []
var player_armies: Array[Army] = []
var enemy_armies: Array[Army] = []
var battling_armies: Array[Army] = []  # armies in current battle (for midpoint retreat)

var _executing_armies: Dictionary = {}  # armies still moving during EXECUTING phase

var _drag_start: Vector2 = Vector2.ZERO
var _is_dragging: bool = false
var _is_shift_panning: bool = false
const DRAG_THRESHOLD: float = 5.0
const MIN_ZOOM: float = 0.25
const MAX_ZOOM: float = 1.5
const WHEEL_ZOOM_FACTOR: float = 1.2
const MAP_SIZE: Vector2 = Vector2(3840, 2160)
const ENCOUNTER_DISTANCE: float = 30.0

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
	map_data.node_clicked.connect(_on_node_clicked)
	if camera:
		camera.position = MAP_SIZE / 2.0
		camera.zoom = Vector2(0.5, 0.5)
		camera.limit_left = 0
		camera.limit_top = 0
		camera.limit_right = MAP_SIZE.x
		camera.limit_bottom = MAP_SIZE.y

func _process(_delta):
	if current_phase == GamePhase.EXECUTING:
		_check_encounters()

func _check_encounters():
	for i in range(all_armies.size()):
		var a1 = all_armies[i]
		if not is_instance_valid(a1):
			continue
		for j in range(i + 1, all_armies.size()):
			var a2 = all_armies[j]
			if not is_instance_valid(a2):
				continue
			if a1.army_type == a2.army_type:
				continue
			if a1.position.distance_to(a2.position) < ENCOUNTER_DISTANCE:
				_start_battle(a1, a2)
				return

func _on_node_clicked(node: MapNode):
	if current_phase != GamePhase.PLANNING:
		return

	if selected_army == null:
		# Click own city with no army: select army there or open menu
		if map_data.NODE_CONFIG[node.node_id].faction == current_faction:
			var army_here = _get_army_at_city(node.node_id)
			if army_here and army_here.army_type != Army.ArmyType.ENEMY:
				_on_army_clicked(army_here)
			else:
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
				waypoints.append(pos + Vector2(20, -20))
				cities.append(city_id)
		selected_army.set_route(waypoints, cities)

func _find_route(army: Army, target_city: String) -> Array[String]:
	if not is_instance_valid(army):
		return []
	var from_cities: Array[String] = []
	if army.current_city_id != "":
		from_cities.append(army.current_city_id)
	# Also try the nearest city (might differ if army is between cities)
	var nearest = map_data.get_nearest_city(army.position)
	if nearest != "" and not from_cities.has(nearest):
		from_cities.append(nearest)
	# Also try between-cities tracking (from/to)
	if army.from_city_id != "" and not from_cities.has(army.from_city_id):
		from_cities.append(army.from_city_id)
	if army.to_city_id != "" and not from_cities.has(army.to_city_id):
		from_cities.append(army.to_city_id)

	for from_city in from_cities:
		if from_city == target_city:
			continue
		if map_data.can_move_to(from_city, target_city):
			return map_data.find_path(from_city, target_city)
	return []

func _input(event):
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
	if army.army_type == Army.ArmyType.ENEMY:
		if selected_army and selected_army.army_type != Army.ArmyType.ENEMY:
			var path = _find_route(selected_army, army.current_city_id)
			if not path.is_empty():
				var waypoints: Array[Vector2] = []
				var cities: Array[String] = []
				for city_id in path:
					if map_data.map_nodes.has(city_id):
						var pos = map_data.map_nodes[city_id].position
						waypoints.append(pos + Vector2(20, -20))
						cities.append(city_id)
				selected_army.set_route(waypoints, cities)
		return

	if selected_army and is_instance_valid(selected_army):
		selected_army.set_selected(false)
	selected_army = army
	army.set_selected(true)

func _set_destination_to(army: Army, target_city: String):
	var path = _find_route(army, target_city)
	if not path.is_empty():
		var waypoints: Array[Vector2] = []
		var cities: Array[String] = []
		for city_id in path:
			if map_data.map_nodes.has(city_id):
				var pos = map_data.map_nodes[city_id].position
				waypoints.append(pos + Vector2(20, -20))
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
	var squad_index = 0
	for squad_data in GameManager.squad_data:
		if squad_data.is_empty():
			squad_index += 1
			continue

		var army_type = Army.ArmyType.PLAYER_MAIN if squad_index == 0 else Army.ArmyType.PLAYER_SQUAD
		var army = _create_army(squad_data, start_city, army_type)
		army.army_id = "player_squad_%d" % squad_index
		army.army_name = "Squad %d" % (squad_index + 1) if squad_index > 0 else "Main Army"
		army.army_clicked.connect(_on_army_clicked)
		player_armies.append(army)
		all_armies.append(army)
		squad_index += 1

	if player_armies.is_empty():
		var chars = GameManager.player_army.duplicate()
		var army = _create_army(chars, start_city, Army.ArmyType.PLAYER_MAIN)
		army.army_id = "player_main"
		army.army_name = "Main Army"
		army.army_clicked.connect(_on_army_clicked)
		player_armies.append(army)
		all_armies.append(army)

func _create_army(chars: Array, start_city: String, type: Army.ArmyType = Army.ArmyType.PLAYER_SQUAD) -> Army:
	var army = Army.new()
	army.current_city_id = start_city
	army.squad_data = _convert_squad_data(chars)
	army.army_type = type
	army.movement_finished.connect(_on_army_movement_finished)
	army_mgr_node.add_child(army)
	if map_data.map_nodes.has(start_city):
		army.position = map_data.map_nodes[start_city].position + Vector2(20, -20)
	return army

func _convert_squad_data(data: Array) -> Array[CharacterData]:
	var result: Array[CharacterData] = []
	for char in data:
		if char is CharacterData:
			result.append(char)
	return result

func _create_enemy_armies(player_faction: String):
	var all_factions = ["askr", "embla", "nifl", "muspell"]
	for faction in all_factions:
		if faction == player_faction:
			continue
		var faction_chars = GameManager.get_characters_by_faction(faction)
		if faction_chars.is_empty():
			continue
		for city_id in map_data.NODE_CONFIG.keys():
			if map_data.NODE_CONFIG[city_id].faction == faction:
				var army = _create_army(faction_chars, city_id, Army.ArmyType.ENEMY)
				army.army_id = "enemy_%s" % faction
				army.army_name = "Enemy: " + faction.capitalize()
				army.army_clicked.connect(_on_army_clicked)
				enemy_armies.append(army)
				all_armies.append(army)
				break

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
	if not background_sprite:
		return
	if background_sprite.texture:
		var bg_size = background_sprite.texture.get_size()
		background_sprite.position = bg_size / 2.0
		background_sprite.scale = Vector2(1.0, 1.0)
	else:
		background_sprite.position = MAP_SIZE / 2.0

func setup_ui():
	setup_city_menu()
	setup_squad_menu()
	setup_planning_ui()

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
	end_planning_btn.text = "End Planning Phase"
	end_planning_btn.custom_minimum_size = Vector2(200, 50)
	end_planning_btn.pressed.connect(_on_end_planning_pressed)

	var cancel_plan_btn = Button.new()
	cancel_plan_btn.name = "ClearPlansButton"
	cancel_plan_btn.text = "Clear All Plans"
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
			status.text = "Executing plans..."
		elif current_phase == GamePhase.BATTLE:
			status.text = "Battle in progress..."

func setup_city_menu():
	city_menu = preload("res://scenes/ui/CityMenu.tscn").instantiate()
	ui.add_child(city_menu)
	city_menu.open_formation.connect(_on_open_formation)
	city_menu.visible = false

func setup_squad_menu():
	if squad_menu != null:
		return
	squad_menu = preload("res://scenes/ui/SquadMenu.tscn").instantiate()
	ui.add_child(squad_menu)
	squad_menu.menu_closed.connect(_on_squad_menu_closed)
	squad_menu.visible = false

func _on_end_planning_pressed():
	if current_phase != GamePhase.PLANNING:
		return
	_start_execution()

func _on_clear_plans_pressed():
	for army in player_armies:
		if is_instance_valid(army):
			army.clear_plan()

func _start_execution():
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
	if current_phase == GamePhase.EXECUTING and _executing_armies.is_empty():
		_end_execution()

func _end_execution():
	if current_phase != GamePhase.EXECUTING:
		return
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
	if city_menu:
		city_menu.show_city(node.node_name, node.node_type, false)

func _on_open_formation():
	if squad_menu:
		squad_menu.open_menu()

func _on_squad_menu_closed(saved: bool):
	if city_menu:
		city_menu.visible = true
	if saved and squad_menu:
		GameManager.update_squad_data(squad_menu.data.squads, squad_menu.data.unassigned)

func _start_battle(attacker: Army, defender: Army):
	current_phase = GamePhase.BATTLE
	phase_changed.emit(current_phase)
	_executing_armies.erase(attacker)
	_executing_armies.erase(defender)
	attacker.state = Army.ArmyState.IN_BATTLE
	defender.state = Army.ArmyState.IN_BATTLE
	battling_armies = [attacker, defender]
	var battle_bg = "plain"
	if attacker.current_city_id != "" and map_data.map_nodes.has(attacker.current_city_id):
		battle_bg = map_data.select_battle_background(map_data.map_nodes[attacker.current_city_id])
	GameManager.start_battle_with_background(attacker.squad_data, defender.squad_data, battle_bg)
	_update_planning_ui()

func setup_battle_result_handler():
	GameManager.battle_ended.connect(_on_battle_ended)

func _on_battle_ended(victory: bool):
	current_phase = GamePhase.PLANNING
	phase_changed.emit(current_phase)
	if clock:
		clock.is_running = false
	if victory and selected_army:
		var city_id = selected_army.current_city_id
		if city_id != "" and map_data.NODE_CONFIG.has(city_id):
			map_data.NODE_CONFIG[city_id]["faction"] = current_faction
			if map_data.map_nodes.has(city_id):
				map_data.map_nodes[city_id].set_faction_color(current_faction)
	var i = all_armies.size() - 1
	while i >= 0:
		if not is_instance_valid(all_armies[i]):
			all_armies.remove_at(i)
		i -= 1
	# Midpoint retreat: armies not at a city step back toward origin
	battling_armies = battling_armies.filter(func(a): return is_instance_valid(a))
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

	# Battle path: increment turn when returning to planning (mirror of _end_execution)
	turn_count += 1
	_on_turn_started()
	_update_planning_ui()

	if planning_ui:
		planning_ui.visible = true
	GameManager.change_state(GameConstants.GameState.WORLD_MAP)
	visible = true
