class_name MapDataManager
extends Node2D

signal node_clicked(node: MapNode)

var map_nodes: Dictionary = {}

var NODE_CONFIG = {
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

@onready var map_nodes_container: Node2D = $"../MapNodes"
@onready var connections_node: Node2D = $"../Connections"

func create_map_nodes():
	for node_id in NODE_CONFIG.keys():
		var config = NODE_CONFIG[node_id]
		var node = preload("res://scenes/world_map/MapNode.tscn").instantiate()
		node.node_id = node_id
		node.node_name = config.name
		node.node_type = config.type
		node.position = config.pos
		node.connections = config.connections
		node.set_faction_color(config.faction)
		node.node_clicked.connect(_on_node_clicked)
		map_nodes_container.add_child(node)
		map_nodes[node_id] = node

func _on_node_clicked(node: MapNode):
	node_clicked.emit(node)

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

func get_city_position(city_id: String) -> Vector2:
	if NODE_CONFIG.has(city_id):
		return NODE_CONFIG[city_id].pos
	return Vector2.ZERO

func get_nearest_city(pos: Vector2) -> String:
	var nearest = ""
	var min_dist = INF
	for city_id in NODE_CONFIG.keys():
		var city_pos = NODE_CONFIG[city_id].pos
		var dist = pos.distance_to(city_pos)
		if dist < min_dist:
			min_dist = dist
			nearest = city_id
	return nearest

func can_move_to(from_id: String, to_id: String) -> bool:
	if from_id == to_id:
		return false
	if NODE_CONFIG.has(from_id) and NODE_CONFIG[from_id].connections.has(to_id):
		return true
	return false

func find_path(from_id: String, to_id: String) -> Array[String]:
	# BFS pathfinding (like sanguoqunying2)
	if from_id == to_id:
		return [to_id]

	var visited: Dictionary = {}
	var parent: Dictionary = {}
	var queue: Array[String] = [from_id]
	visited[from_id] = true

	while not queue.is_empty():
		var current = queue.pop_front()
		if current == to_id:
			# Reconstruct path
			var path: Array[String] = []
			var node = to_id
			while node != from_id:
				path.push_front(node)
				node = parent[node]
			return path

		if not NODE_CONFIG.has(current):
			continue

		for neighbor in NODE_CONFIG[current].connections:
			if not visited.has(neighbor):
				visited[neighbor] = true
				parent[neighbor] = current
				queue.append(neighbor)

	return []

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
