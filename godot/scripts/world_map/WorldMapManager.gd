class_name WorldMapManager
extends Node2D

signal phase_changed(new_phase: int)

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

const ENCOUNTER_DISTANCE: float = 30.0

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
		if map_data.NODE_CONFIG[node.node_id].faction == current_faction:
			var army_here = _get_army_at_city(node.node_id)
			if army_here and army_here.army_type != Army.ArmyType.ENEMY:
				_on_army_clicked(army_here)
			else:
				open_city_menu(node)
		return

	var from_city = selected_army.current_city_id
	if from_city == "":
		from_city = map_data.get_nearest_city(selected_army.position)

	if from_city != node.node_id:
		if map_data.can_move_to(from_city, node.node_id):
			var path = map_data.find_path(from_city, node.node_id)
			if not path.is_empty():
				var waypoints: Array[Vector2] = []
				var cities: Array[String] = []
				for city_id in path:
					if map_data.map_nodes.has(city_id):
						var pos = map_data.map_nodes[city_id].position
						waypoints.append(pos + Vector2(20, -20))
						cities.append(city_id)
				selected_army.set_route(waypoints, cities)

func _input(event):
	if current_phase != GamePhase.PLANNING:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var clicked_army = _get_army_at_position(get_global_mouse_position())
		if clicked_army:
			_on_army_clicked(clicked_army)

func _on_army_clicked(army: Army):
	if army.army_type == Army.ArmyType.ENEMY:
		if selected_army and selected_army.army_type != Army.ArmyType.ENEMY:
			_set_destination_to(selected_army, army.current_city_id)
		return

	if selected_army and is_instance_valid(selected_army):
		selected_army.set_selected(false)
	selected_army = army
	army.set_selected(true)

func _set_destination_to(army: Army, target_city: String):
	var from_city = army.current_city_id
	if from_city == "":
		from_city = map_data.get_nearest_city(army.position)
	if from_city == target_city:
		return
	if map_data.can_move_to(from_city, target_city):
		var path = map_data.find_path(from_city, target_city)
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

	# Show planning UI when entering world map
	if planning_ui:
		planning_ui.visible = true

	_clear_armies()
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
	army.army_type = type  # Set BEFORE add_child so setup_visual uses correct color
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
		var connections = map_data.NODE_CONFIG[enemy.current_city_id].connections
		for connected_id in connections:
			for player in player_armies:
				if is_instance_valid(player) and player.current_city_id == connected_id:
					_set_destination_to(enemy, connected_id)
					break

func setup_background():
	if background_sprite and background_sprite.texture:
		var bg_size = background_sprite.texture.get_size()
		background_sprite.position = Vector2(640, 360)
		var screen_size = Vector2(1280, 720)
		var scale_factor = max(screen_size.x / bg_size.x, screen_size.y / bg_size.y)
		if scale_factor > 1:
			background_sprite.scale = Vector2(scale_factor, scale_factor)

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
	cancel_plan_btn.name = "CancelPlanButton"
	cancel_plan_btn.text = "Clear All Plans"
	cancel_plan_btn.custom_minimum_size = Vector2(150, 50)
	cancel_plan_btn.pressed.connect(_on_clear_plans_pressed)

	hbox.add_child(end_planning_btn)
	hbox.add_child(cancel_plan_btn)
	panel.add_child(hbox)
	planning_ui.add_child(panel)
	planning_ui.visible = false

	ui.add_child(planning_ui)

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
	current_phase = GamePhase.EXECUTING
	if planning_ui:
		planning_ui.visible = false
	# Plan AI moves, then execute all plans
	_plan_ai_moves()
	for army in all_armies:
		if is_instance_valid(army) and army.has_plan():
			army.execute_plan()
	if clock:
		clock.is_running = true

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
	attacker.state = Army.ArmyState.IN_BATTLE
	defender.state = Army.ArmyState.IN_BATTLE

	var battle_bg = map_data.select_battle_background(map_data.map_nodes[attacker.current_city_id])
	GameManager.start_battle_with_background(attacker.squad_data, defender.squad_data, battle_bg)

func setup_battle_result_handler():
	GameManager.battle_ended.connect(_on_battle_ended)

func _on_battle_ended(victory: bool):
	current_phase = GamePhase.PLANNING
	phase_changed.emit(current_phase)
	if clock:
		clock.is_running = false

	if victory and selected_army:
		var city_id = selected_army.current_city_id
		map_data.NODE_CONFIG[city_id].faction = current_faction
		if map_data.map_nodes.has(city_id):
			map_data.map_nodes[city_id].set_faction_color(current_faction)

	var i = all_armies.size() - 1
	while i >= 0:
		if not is_instance_valid(all_armies[i]):
			all_armies.remove_at(i)
		i -= 1

	if planning_ui:
		planning_ui.visible = true
	GameManager.change_state(GameConstants.GameState.WORLD_MAP)
	visible = true
