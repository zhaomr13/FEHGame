class_name WorldMapManager
extends Node2D

signal turn_ended

@export var current_node_id: String = "city_1"
@export var player_morale: int = 100
@export var turn_count: int = 1

var map_nodes: Dictionary = {}
var player_token: Node2D
var is_player_turn: bool = true
var city_menu: Control = null

# World map backgrounds
const WORLD_BACKGROUNDS = {
	"world_map": "res://assets/world_map/backgrounds/world_map.png",
	"occupation": "res://assets/world_map/backgrounds/occupation_map.png",
	"title": "res://assets/world_map/backgrounds/title_bg.png",
	"arena": "res://assets/world_map/backgrounds/arena_bg.png"
}

# Node configuration
const NODE_CONFIG = {
	"city_1": {"name": "北方要塞", "type": GameConstants.NodeType.FORT, "pos": Vector2(400, 150), "connections": ["city_3"]},
	"city_2": {"name": "西风村", "type": GameConstants.NodeType.VILLAGE, "pos": Vector2(200, 280), "connections": ["city_3", "city_5"]},
	"city_3": {"name": "中央城", "type": GameConstants.NodeType.CITY, "pos": Vector2(450, 280), "connections": ["city_1", "city_2", "city_4", "city_8"]},
	"city_4": {"name": "东影城", "type": GameConstants.NodeType.CITY, "pos": Vector2(700, 280), "connections": ["city_3", "city_6"]},
	"city_5": {"name": "南海村", "type": GameConstants.NodeType.VILLAGE, "pos": Vector2(150, 450), "connections": ["city_2", "city_7"]},
	"city_6": {"name": "东北要塞", "type": GameConstants.NodeType.FORT, "pos": Vector2(850, 200), "connections": ["city_4"]},
	"city_7": {"name": "河湾村", "type": GameConstants.NodeType.VILLAGE, "pos": Vector2(300, 500), "connections": ["city_5", "city_8"]},
	"city_8": {"name": "南方城", "type": GameConstants.NodeType.CITY, "pos": Vector2(500, 480), "connections": ["city_3", "city_7", "city_9", "city_10"]},
	"city_9": {"name": "东岛村", "type": GameConstants.NodeType.VILLAGE, "pos": Vector2(750, 500), "connections": ["city_8"]},
	"city_10": {"name": "帝都", "type": GameConstants.NodeType.CITY, "pos": Vector2(550, 600), "connections": ["city_8"]}
}

@onready var ui: CanvasLayer = $WorldMapUI
@onready var background_sprite: Sprite2D = $Background
@onready var map_nodes_container: Node2D = $MapNodes
@onready var connections_node: Node2D = $Connections

func _ready():
	GameManager.change_state(GameConstants.GameState.WORLD_MAP)
	setup_background()
	create_map_nodes()
	draw_connections()
	initialize_map()
	setup_city_menu()

func setup_background():
	if background_sprite and background_sprite.texture:
		var bg_size = background_sprite.texture.get_size()
		background_sprite.position = Vector2(640, 360)
		var screen_size = Vector2(1280, 720)
		var scale_factor = max(screen_size.x / bg_size.x, screen_size.y / bg_size.y)
		if scale_factor > 1:
			background_sprite.scale = Vector2(scale_factor, scale_factor)

func create_map_nodes():
	for node_id in NODE_CONFIG.keys():
		var config = NODE_CONFIG[node_id]
		var node = preload("res://scenes/world_map/MapNode.tscn").instantiate()
		node.node_id = node_id
		node.node_name = config.name
		node.node_type = config.type
		node.position = config.pos
		node.connections = config.connections
		map_nodes_container.add_child(node)

func draw_connections():
	"""Draw lines between connected cities"""
	var line_color = Color(0.8, 0.7, 0.4, 0.6)
	var line_width = 3.0

	for node_id in NODE_CONFIG.keys():
		var config = NODE_CONFIG[node_id]
		var start_pos = config.pos

		for connected_id in config.connections:
			# Only draw each connection once (avoid duplicates)
			if node_id < connected_id:
				var connected_config = NODE_CONFIG[connected_id]
				var end_pos = connected_config.pos

				var line = Line2D.new()
				line.add_point(start_pos)
				line.add_point(end_pos)
				line.default_color = line_color
				line.width = line_width
				line.antialiased = true
				connections_node.add_child(line)

func initialize_map():
	for child in map_nodes_container.get_children():
		if child is MapNode:
			map_nodes[child.node_id] = child
			child.node_clicked.connect(_on_node_clicked)

	# Explore starting city
	var start_node = map_nodes.get(current_node_id)
	if start_node:
		start_node.explore()

func setup_city_menu():
	"""Setup the city menu UI"""
	city_menu = preload("res://scenes/ui/CityMenu.tscn").instantiate()
	ui.add_child(city_menu)
	city_menu.city_closed.connect(_on_city_closed)
	city_menu.visible = false

func _on_node_clicked(node: MapNode):
	if not is_player_turn:
		return

	var current_node = map_nodes.get(current_node_id)

	# If clicking current city, open menu
	if node.node_id == current_node_id:
		if node.node_type == GameConstants.NodeType.CITY or \
		   node.node_type == GameConstants.NodeType.FORT or \
		   node.node_type == GameConstants.NodeType.VILLAGE:
			show_city_menu(node)
		return

	# Otherwise try to move to connected city
	if current_node and current_node.connections.has(node.node_id):
		move_to_node(node)

func move_to_node(target_node: MapNode):
	current_node_id = target_node.node_id
	target_node.explore()

	if target_node.node_type == GameConstants.NodeType.BATTLE:
		trigger_battle(target_node)
	else:
		show_city_menu(target_node)

func trigger_battle(node: MapNode):
	var enemy_units = generate_enemy_army(node)
	var battle_bg = select_battle_background(node)
	GameManager.battle_started_with_background.emit(GameManager.player_army, enemy_units, battle_bg)
	GameManager.start_battle(GameManager.player_army, enemy_units)

func select_battle_background(node: MapNode) -> String:
	match node.node_type:
		GameConstants.NodeType.CITY:
			return "inside"
		GameConstants.NodeType.FORT:
			return "brave_attack"
		GameConstants.NodeType.VILLAGE:
			return "plain_forest"
		_:
			var outdoor_bgs = ["plain", "forest", "river", "plain_forest"]
			return outdoor_bgs[randi() % outdoor_bgs.size()]

func generate_enemy_army(node: MapNode) -> Array[CharacterData]:
	var enemies: Array[CharacterData] = []
	# Generate 3 random enemies
	for i in range(3):
		var enemy = CharacterData.new()
		enemy.character_name = "Enemy " + str(i + 1)
		enemy.max_hp = 20 + randi() % 10
		enemy.current_hp = enemy.max_hp
		enemy.attack = 5 + randi() % 5
		enemy.defense = 3 + randi() % 3
		enemy.speed = 4 + randi() % 4
		enemy.setup_default_tactics()
		enemies.append(enemy)
	return enemies

func show_city_menu(node: MapNode):
	if city_menu:
		city_menu.show_city(node.node_name, node.node_type)

func _on_city_closed():
	# City menu closed, can continue playing
	pass

func get_total_soldiers() -> int:
	var total = 0
	for char in GameManager.player_army:
		total += char.soldiers
	return total

func end_player_turn():
	is_player_turn = false
	turn_ended.emit()
	process_enemy_turn()

func process_enemy_turn():
	await get_tree().create_timer(1.0).timeout
	turn_count += 1
	is_player_turn = true
