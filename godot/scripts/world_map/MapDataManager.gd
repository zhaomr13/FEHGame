class_name MapDataManager
extends Node2D

signal node_clicked(node: MapNode)
signal map_data_loaded(success: bool)

var map_nodes: Dictionary = {}
var _base_node_config: Dictionary = {}

const DEFAULT_MAP_DATA_PATH = "res://data/world_map.yaml"

var NODE_CONFIG: Dictionary = {}

@onready var map_nodes_container: Node2D = get_node_or_null("../MapNodes")
@onready var connections_node: Node2D = get_node_or_null("../Connections")

func _ready():
	load_map_data(DEFAULT_MAP_DATA_PATH)

func load_map_data(path: String) -> bool:
	if not FileAccess.file_exists(path):
		push_error("Map data file not found: " + path)
		map_data_loaded.emit(false)
		return false

	var yaml_text = FileAccess.get_file_as_string(path)
	var parser = YamlParser.new()
	var parsed = parser.parse(yaml_text)
	if parsed == null or not parsed is Dictionary:
		push_error("Failed to parse map data YAML")
		map_data_loaded.emit(false)
		return false

	NODE_CONFIG = _build_node_config(parsed)
	_base_node_config = NODE_CONFIG.duplicate(true)
	validate_map_data()
	map_data_loaded.emit(true)
	return true

func _node_type_from_string(type_str: String) -> int:
	match type_str:
		"fort":
			return GameConstants.NodeType.FORT
		"village":
			return GameConstants.NodeType.VILLAGE
		"city":
			return GameConstants.NodeType.CITY
	return GameConstants.NodeType.CITY

func _get_icon_size(node: Dictionary) -> String:
	var size_str: String = node.get("icon_size", "")
	if size_str == "large" or size_str == "small":
		return size_str
	# Default based on node type
	var type_str: String = node.get("type", "city")
	if type_str == "village":
		return "small"
	return "large"

func _build_node_config(data: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	var nodes = data.get("nodes", [])

	# First pass: create entries with empty connections
	for node in nodes:
		var id = node.get("id", "")
		if id == "" or result.has(id):
			continue
		var pos = node.get("pos", {})
		result[id] = {
			"name": node.get("name", "Unknown"),
			"type": _node_type_from_string(node.get("type", "city")),
			"pos": Vector2(pos.get("x", 0.0), pos.get("y", 0.0)),
			"connections": [],
			"faction": node.get("faction", "") if node.get("faction") != null else "",
			"icon_size": _get_icon_size(node)
		}

	_generate_connections(result, data)
	return result

func _generate_connections(config: Dictionary, data: Dictionary):
	var metadata = data.get("metadata", {})
	var strategy = metadata.get("connection_strategy", "auto_with_overrides")
	var max_dist = metadata.get("max_auto_distance", 320.0)
	var target = metadata.get("target_connections", 3)
	var nodes = data.get("nodes", [])

	# 1. Apply forced connections
	for node in nodes:
		var id = node.get("id", "")
		if not config.has(id):
			continue
		for forced in node.get("force_connections", []):
			if config.has(forced):
				_add_bidirectional_connection(config, id, forced)

	# 2. Auto-connect by distance (skipped for manual strategy)
	if strategy != "manual":
		for node in nodes:
			var id = node.get("id", "")
			if not config.has(id):
				continue

			var blocked: Array = node.get("blocked_neighbors", [])
			var candidates: Array[Dictionary] = []

			for other in nodes:
				var other_id = other.get("id", "")
				if other_id == id or blocked.has(other_id):
					continue
				if not config.has(other_id):
					continue
				var dist = config[id].pos.distance_to(config[other_id].pos)
				if dist <= max_dist:
					candidates.append({"id": other_id, "dist": dist})

			candidates.sort_custom(func(a, b): return a.dist < b.dist)

			var added = 0
			for candidate in candidates:
				if config[id].connections.has(candidate.id):
					continue
				config[id].connections.append(candidate.id)
				if not config[candidate.id].connections.has(id):
					config[candidate.id].connections.append(id)
				added += 1
				if added >= target:
					break

			# Fallback: if still isolated, connect to nearest node regardless of max_dist
			if config[id].connections.is_empty():
				var nearest_id = ""
				var nearest_dist = INF
				for other in nodes:
					var other_id = other.get("id", "")
					if other_id == id or blocked.has(other_id):
						continue
					if not config.has(other_id):
						continue
					var dist = config[id].pos.distance_to(config[other_id].pos)
					if dist < nearest_dist:
						nearest_dist = dist
						nearest_id = other_id
				if nearest_id != "":
					_add_bidirectional_connection(config, id, nearest_id)

	# 3. Apply manual connections
	for link in data.get("manual_connections", []):
		var from_id = link.get("from", "")
		var to_id = link.get("to", "")
		if config.has(from_id) and config.has(to_id):
			_add_bidirectional_connection(config, from_id, to_id)

	# 4. Final fallback: ensure graph is fully connected by linking components
	if strategy != "manual":
		_connect_components(config, nodes)

func _add_bidirectional_connection(config: Dictionary, a: String, b: String) -> void:
	if not config[a].connections.has(b):
		config[a].connections.append(b)
	if not config[b].connections.has(a):
		config[b].connections.append(a)

func _connect_components(config: Dictionary, nodes: Array):
	"""Find disconnected components and bridge them with nearest-node links."""
	if config.is_empty():
		return

	var all_ids: Array = []
	for node in nodes:
		var id = node.get("id", "")
		if id != "" and config.has(id):
			all_ids.append(id)

	while true:
		# Find connected components
		var unvisited = {}
		for id in all_ids:
			unvisited[id] = true

		var components: Array[Array] = []
		while not unvisited.is_empty():
			var start = unvisited.keys()[0]
			var visited = {}
			var queue: Array = [start]
			visited[start] = true
			unvisited.erase(start)

			while not queue.is_empty():
				var current = queue.pop_front()
				for neighbor in config[current].connections:
					if unvisited.has(neighbor):
						visited[neighbor] = true
						unvisited.erase(neighbor)
						queue.append(neighbor)

			var comp_ids: Array = []
			for k in visited.keys():
				comp_ids.append(k)
			components.append(comp_ids)

		if components.size() <= 1:
			break

		# Find the closest pair of nodes between the first two components
		var comp_a = components[0]
		var comp_b = components[1]
		var best_a = ""
		var best_b = ""
		var best_dist = INF

		for a in comp_a:
			for b in comp_b:
				var dist = config[a].pos.distance_to(config[b].pos)
				if dist < best_dist:
					best_dist = dist
					best_a = a
					best_b = b

		if best_a != "" and best_b != "":
			_add_bidirectional_connection(config, best_a, best_b)

func create_map_nodes():
	if not map_nodes_container or not connections_node:
		return
	for node_id in NODE_CONFIG.keys():
		var config = NODE_CONFIG[node_id]
		var node = preload("res://scenes/world_map/MapNode.tscn").instantiate()
		node.node_id = node_id
		node.node_name = config.name
		node.node_type = config.type
		node.position = config.pos
		node.connections = config.connections
		node.icon_size = config.icon_size
		node.set_faction_color(config.faction)
		node.is_explored = true
		node.node_clicked.connect(_on_node_clicked)
		map_nodes_container.add_child(node)
		map_nodes[node_id] = node

func reset_ownership():
	"""Restore city ownership to the initial YAML values."""
	if _base_node_config.is_empty():
		return
	for city_id in NODE_CONFIG.keys():
		if _base_node_config.has(city_id):
			NODE_CONFIG[city_id]["faction"] = _base_node_config[city_id].faction
			if map_nodes.has(city_id):
				map_nodes[city_id].set_faction_color(NODE_CONFIG[city_id].faction)

func _on_node_clicked(node: MapNode):
	node_clicked.emit(node)

func draw_connections():
	if not map_nodes_container or not connections_node:
		return
	var line_color = Color(0.8, 0.7, 0.4, 0.6)
	var line_width = 2.0

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
			var node: String = to_id
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

func validate_map_data() -> bool:
	var ok = true

	# No isolated nodes
	for id in NODE_CONFIG.keys():
		if NODE_CONFIG[id].connections.is_empty():
			push_warning("Map node %s has no connections" % id)
			ok = false

	# Graph connectivity
	if not NODE_CONFIG.is_empty():
		var start = NODE_CONFIG.keys()[0]
		var visited: Dictionary = {}
		var queue: Array = [start]
		visited[start] = true

		while not queue.is_empty():
			var current = queue.pop_front()
			for neighbor in NODE_CONFIG[current].connections:
				if not visited.has(neighbor):
					visited[neighbor] = true
					queue.append(neighbor)

		if visited.size() != NODE_CONFIG.size():
			push_warning("Map graph is not fully connected (%d/%d reachable from %s)" % [visited.size(), NODE_CONFIG.size(), start])
			ok = false

	# Overlap check
	var ids: Array = NODE_CONFIG.keys()
	for i in range(ids.size()):
		for j in range(i + 1, ids.size()):
			var dist = NODE_CONFIG[ids[i]].pos.distance_to(NODE_CONFIG[ids[j]].pos)
			if dist < 60.0:
				push_warning("Map nodes %s and %s are too close (%.1f px)" % [ids[i], ids[j], dist])
				ok = false

	return ok
