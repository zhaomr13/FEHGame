class_name WorldMapManager
extends Node2D

signal turn_ended
signal phase_changed(new_phase: int)

enum GamePhase {
	PLANNING,
	EXECUTION,
	BATTLE
}

@export var current_node_id: String = "city_1"
@export var player_morale: int = 100
@export var turn_count: int = 1

var current_phase: GamePhase = GamePhase.PLANNING
var is_player_turn: bool = true
var current_faction: String = ""

var city_menu: Control = null
var squad_menu: Control = null

@onready var ui: CanvasLayer = $WorldMapUI
@onready var background_sprite: Sprite2D = $Background
@onready var map_data: MapDataManager = $MapDataManager
@onready var army_mgr: WorldMapArmyManager = $WorldMapArmyManager
@onready var planning_ctrl: PlanningPhaseController = $PlanningPhaseController
@onready var execution_ctrl: ExecutionPhaseController = $ExecutionPhaseController

func _ready():
	setup_background()
	map_data.create_map_nodes()
	map_data.draw_connections()
	setup_ui()
	setup_battle_result_handler()

	# Wire child signals
	map_data.node_clicked.connect(_on_node_clicked)
	army_mgr.army_selected.connect(_on_army_clicked)
	army_mgr.move_completed.connect(_on_army_move_completed)
	planning_ctrl.planning_ended.connect(_on_planning_ended)
	planning_ctrl.city_opened.connect(open_city_menu)
	planning_ctrl.formation_opened.connect(_on_open_formation)
	execution_ctrl.battle_started.connect(_start_battle)
	execution_ctrl.execution_ended.connect(_on_execution_ended)

func _input(event):
	if current_phase == GamePhase.PLANNING:
		planning_ctrl.handle_input(event)

func _on_node_clicked(node: MapNode):
	if current_phase != GamePhase.PLANNING:
		return
	planning_ctrl.on_node_clicked(node)

func _on_army_clicked(army: Army):
	if current_phase != GamePhase.PLANNING:
		return
	planning_ctrl.on_army_clicked(army)

func _on_planning_ended():
	start_execution_phase()

func setup_faction_start(faction: String, start_city: String):
	current_faction = faction
	current_node_id = start_city

	army_mgr.clear_armies()
	map_data.map_nodes.clear()
	map_data.create_map_nodes()

	army_mgr.create_player_armies_from_squads(start_city)
	army_mgr.create_enemy_armies(faction)
	army_mgr.initialize_squads()

	start_planning_phase()

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
	if planning_ctrl:
		planning_ctrl.setup_planning_ui()

func setup_city_menu():
	city_menu = preload("res://scenes/ui/CityMenu.tscn").instantiate()
	ui.add_child(city_menu)
	city_menu.deploy_army.connect(_on_deploy_army)
	city_menu.open_formation.connect(_on_open_formation)
	city_menu.visible = false

func setup_squad_menu():
	if squad_menu != null:
		return
	squad_menu = preload("res://scenes/ui/SquadMenu.tscn").instantiate()
	ui.add_child(squad_menu)
	squad_menu.menu_closed.connect(_on_squad_menu_closed)
	squad_menu.visible = false

func start_planning_phase():
	current_phase = GamePhase.PLANNING
	phase_changed.emit(current_phase)
	if planning_ctrl:
		planning_ctrl.start_planning_phase()

func start_execution_phase():
	current_phase = GamePhase.EXECUTION
	phase_changed.emit(current_phase)
	if execution_ctrl:
		execution_ctrl.start_execution_phase()

func _start_battle(attacker: Army, defender: Army):
	current_phase = GamePhase.BATTLE
	phase_changed.emit(current_phase)

	var battle_bg = map_data.select_battle_background(map_data.map_nodes[attacker.current_city_id])
	GameManager.start_battle_with_background(attacker.squad_data, defender.squad_data, battle_bg)

func _on_execution_ended():
	if execution_ctrl:
		execution_ctrl.process_enemy_turn()

func _on_army_move_completed(army: Army):
	army_mgr._update_army_position(army)

func open_city_menu(node: MapNode):
	if city_menu:
		city_menu.show_city(node.node_name, node.node_type, false)

func _on_open_formation():
	if squad_menu:
		squad_menu.open_menu()

func _on_squad_menu_closed(saved: bool):
	if city_menu:
		city_menu.visible = true

	if saved:
		if squad_menu:
			GameManager.update_squad_data(squad_menu.data.squads, squad_menu.data.unassigned)
		army_mgr.refresh_player_armies(current_node_id, current_faction)

func _on_deploy_army():
	city_menu.visible = false
	if army_mgr.selected_army:
		army_mgr.create_squad_from_main(army_mgr.selected_army)

func setup_battle_result_handler():
	GameManager.battle_ended.connect(_on_battle_ended)

func _on_battle_ended(victory: bool):
	current_phase = GamePhase.PLANNING
	phase_changed.emit(current_phase)

	if victory and army_mgr.selected_army:
		var city_id = army_mgr.selected_army.current_city_id
		map_data.NODE_CONFIG[city_id].faction = current_faction
		if map_data.map_nodes.has(city_id):
			map_data.map_nodes[city_id].set_faction_color(current_faction)

	GameManager.change_state(GameConstants.GameState.WORLD_MAP)
	visible = true
	start_planning_phase()
