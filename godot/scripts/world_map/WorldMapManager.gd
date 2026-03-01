class_name WorldMapManager
extends Node2D

signal turn_ended
signal battle_phase_started

@export var current_node_id: String = "city_1"
@export var player_morale: int = 100
@export var turn_count: int = 1

var map_nodes: Dictionary = {}
var player_token: Node2D
var is_player_turn: bool = true
var city_menu: Control = null
var current_faction: String = ""

# Enemy squads on map (faction -> city_id)
var enemy_squads: Dictionary = {}

# World map backgrounds
const WORLD_BACKGROUNDS = {
	"world_map": "res://assets/world_map/backgrounds/world_map.png",
	"occupation": "res://assets/world_map/backgrounds/occupation_map.png",
	"title": "res://assets/world_map/backgrounds/title_bg.png",
	"arena": "res://assets/world_map/backgrounds/arena_bg.png"
}

# Node configuration
const NODE_CONFIG = {
	"city_1": {"name": "北方要塞", "type": GameConstants.NodeType.FORT, "pos": Vector2(400, 150), "connections": ["city_3"], "faction": "embla"},
	"city_2": {"name": "西风村", "type": GameConstants.NodeType.VILLAGE, "pos": Vector2(200, 280), "connections": ["city_3", "city_5"], "faction": ""},
	"city_3": {"name": "中央城", "type": GameConstants.NodeType.CITY, "pos": Vector2(450, 280), "connections": ["city_1", "city_2", "city_4", "city_8"], "faction": "askr"},
	"city_4": {"name": "东影城", "type": GameConstants.NodeType.CITY, "pos": Vector2(700, 280), "connections": ["city_3", "city_6"], "faction": ""},
	"city_5": {"name": "南海村", "type": GameConstants.NodeType.VILLAGE, "pos": Vector2(150, 450), "connections": ["city_2", "city_7"], "faction": ""},
	"city_6": {"name": "东北要塞", "type": GameConstants.NodeType.FORT, "pos": Vector2(850, 200), "connections": ["city_4"], "faction": ""},
	"city_7": {"name": "河湾村", "type": GameConstants.NodeType.VILLAGE, "pos": Vector2(300, 500), "connections": ["city_5", "city_8"], "faction": ""},
	"city_8": {"name": "南方城", "type": GameConstants.NodeType.CITY, "pos": Vector2(500, 480), "connections": ["city_3", "city_7", "city_9", "city_10"], "faction": "nifl"},
	"city_9": {"name": "东岛村", "type": GameConstants.NodeType.VILLAGE, "pos": Vector2(750, 500), "connections": ["city_8"], "faction": ""},
	"city_10": {"name": "帝都", "type": GameConstants.NodeType.CITY, "pos": Vector2(550, 600), "connections": ["city_8"], "faction": ""}
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
	setup_battle_result_handler()

func setup_faction_start(faction: String, start_city: String):
	"""Setup the map based on selected faction"""
	current_faction = faction
	current_node_id = start_city

	# Clear and recreate nodes to show faction colors
	for child in map_nodes_container.get_children():
		child.queue_free()
	map_nodes.clear()

	create_map_nodes()
	initialize_map()

	# Setup enemy squads
	setup_enemy_squads(faction)

func setup_enemy_squads(player_faction: String):
	"""Place enemy squads on the map"""
	enemy_squads.clear()

	# Add enemy squads to non-player faction cities
	for city_id in NODE_CONFIG.keys():
		var city_data = NODE_CONFIG[city_id]
		if city_data.faction != "" and city_data.faction != player_faction:
			enemy_squads[city_data.faction] = city_id

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

		# Set faction color
		node.set_faction_color(config.faction)

		map_nodes_container.add_child(node)

func draw_connections():
	var line_color = Color(0.8, 0.7, 0.4, 0.6)
	var line_width = 3.0

	for node_id in NODE_CONFIG.keys():
		var config = NODE_CONFIG[node_id]
		var start_pos = config.pos

		for connected_id in config.connections:
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
		start_node.set_as_current()

func setup_city_menu():
	city_menu = preload("res://scenes/ui/CityMenu.tscn").instantiate()
	ui.add_child(city_menu)
	city_menu.city_closed.connect(_on_city_closed)
	city_menu.deploy_army.connect(_on_deploy_army)
	city_menu.visible = false

func setup_battle_result_handler():
	GameManager.battle_ended.connect(_on_battle_ended)

func _on_node_clicked(node: MapNode):
	if not is_player_turn:
		return

	var current_node = map_nodes.get(current_node_id)

	# If clicking current city, open menu
	if node.node_id == current_node_id:
		open_city_menu(node)
		return

	# Check if connected and can move there
	if current_node and current_node.connections.has(node.node_id):
		# Check if enemy occupied
		if is_enemy_occupied(node.node_id):
			# Show attack confirmation
			show_attack_confirmation(node)
		else:
			move_to_node(node)

func is_enemy_occupied(city_id: String) -> bool:
	"""Check if a city is occupied by enemy"""
	for faction in enemy_squads.keys():
		if enemy_squads[faction] == city_id:
			return true
	return false

func get_enemy_faction_at_city(city_id: String) -> String:
	"""Get which enemy faction occupies a city"""
	for faction in enemy_squads.keys():
		if enemy_squads[faction] == city_id:
			return faction
	return ""

func open_city_menu(node: MapNode):
	if city_menu:
		city_menu.show_city(node.node_name, node.node_type, node.node_id == current_node_id)

func show_attack_confirmation(node: MapNode):
	"""Show dialog to confirm attack on enemy city"""
	var enemy_faction = get_enemy_faction_at_city(node.node_id)
	var confirm_dialog = ConfirmationDialog.new()
	confirm_dialog.title = "Attack City?"
	confirm_dialog.dialog_text = "Attack %s held by %s?" % [node.node_name, enemy_faction.to_upper()]
	confirm_dialog.confirmed.connect(func(): start_attack_on_city(node))
	add_child(confirm_dialog)
	confirm_dialog.popup_centered()

func start_attack_on_city(target_node: MapNode):
	"""Initiate attack on enemy-occupied city"""
	current_node_id = target_node.node_id
	target_node.explore()
	target_node.set_as_current()

	# Generate enemy army for this city
	var enemy_faction = get_enemy_faction_at_city(target_node.node_id)
	var enemy_units = generate_enemy_army_for_faction(enemy_faction)

	# Start battle
	var battle_bg = select_battle_background(target_node)
	GameManager.start_battle_with_background(GameManager.player_army, enemy_units, battle_bg)

func move_to_node(target_node: MapNode):
	current_node_id = target_node.node_id
	target_node.explore()
	target_node.set_as_current()

	# Clear previous current marker
	for node in map_nodes.values():
		node.clear_current_marker()

	open_city_menu(target_node)

func _on_city_closed():
	# City menu closed
	pass

func _on_deploy_army():
	"""Player clicked deploy - start battle phase"""
	city_menu.visible = false
	battle_phase_started.emit()
	process_battle_phase()

func process_battle_phase():
	"""Process all battles for this turn"""
	# Check for enemy encounters at connected cities
	var current_node = map_nodes.get(current_node_id)
	if not current_node:
		return

	# Find adjacent enemy cities
	var adjacent_enemies = []
	for connected_id in current_node.connections:
		if is_enemy_occupied(connected_id):
			adjacent_enemies.append(connected_id)

	if adjacent_enemies.size() > 0:
		# Attack first adjacent enemy
		var target_id = adjacent_enemies[0]
		var target_node = map_nodes[target_id]
		start_attack_on_city(target_node)
	else:
		# No enemies adjacent, end turn
		end_player_turn()

func _on_battle_ended(victory: bool):
	"""Handle battle result"""
	if victory:
		# Conquer the city
		var enemy_faction = get_enemy_faction_at_city(current_node_id)
		if enemy_faction != "":
			enemy_squads.erase(enemy_faction)

		# Change faction ownership
		NODE_CONFIG[current_node_id].faction = current_faction
		if map_nodes.has(current_node_id):
			map_nodes[current_node_id].set_faction_color(current_faction)

	# Return to world map
	GameManager.change_state(GameConstants.GameState.WORLD_MAP)
	visible = true

	# Check if more battles needed
	process_battle_phase()

func generate_enemy_army(node: MapNode) -> Array[CharacterData]:
	return generate_enemy_army_for_faction("")

func generate_enemy_army_for_faction(faction: String) -> Array[CharacterData]:
	var enemies: Array[CharacterData] = []

	# Generate 3 enemies
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

func show_city_menu(node: MapNode):
	open_city_menu(node)

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

	# Move enemy squads
	for faction in enemy_squads.keys():
		var current_city = enemy_squads[faction]
		var config = NODE_CONFIG[current_city]

		# Simple AI: move to connected neutral or player city
		for connected_id in config.connections:
			var connected_config = NODE_CONFIG[connected_id]
			if connected_config.faction != faction:
				# Move enemy squad
				enemy_squads[faction] = connected_id
				if map_nodes.has(connected_id):
					map_nodes[connected_id].set_faction_color(faction)
				break

	turn_count += 1
	is_player_turn = true
