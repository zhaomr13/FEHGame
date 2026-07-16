class_name MapEditor
extends Node2D

const MAP_SIZE := Vector2(3840, 2160)
const MIN_ZOOM := 0.25
const MAX_ZOOM := 1.5
const WHEEL_ZOOM_FACTOR := 1.2
const CITY_OVERLAP_THRESHOLD := 60.0

@onready var camera: Camera2D = $Camera2D
@onready var background: Sprite2D = $Background
@onready var cities_container: Node2D = $Cities
@onready var connections_node: Node2D = $Connections
@onready var ui: CanvasLayer = $UI
@onready var toolbar: MapEditorToolbar = $UI/Toolbar
@onready var properties_panel: MapEditorPropertiesPanel = $UI/PropertiesPanel
@onready var delete_dialog: ConfirmationDialog = $UI/DeleteConfirmationDialog
@onready var save_dialog: AcceptDialog = $UI/SaveResultDialog

var _metadata: Dictionary = {}
var _cities: Array[Dictionary] = []
var _city_nodes: Dictionary = {}
var _selected_city: MapEditorCity = null
var _pending_delete_city: MapEditorCity = null
var _drag_start: Vector2 = Vector2.ZERO
var _is_panning: bool = false

func _get_city_data_by_id(city_id: String) -> Dictionary:
	for city in _cities:
		if city.get("id", "") == city_id:
			return city
	return {}

func _ready():
	_setup_background()
	_load_map()
	_connect_toolbar()
	_connect_properties_panel()
	if camera:
		camera.position = MAP_SIZE / 2.0
		camera.zoom = Vector2(0.5, 0.5)
		_update_camera_limits()
	if delete_dialog:
		delete_dialog.confirmed.connect(_on_delete_confirmed)
		delete_dialog.canceled.connect(_on_delete_canceled)

func _setup_background():
	if background and background.texture:
		background.position = MAP_SIZE / 2.0
		background.scale = MAP_SIZE / background.texture.get_size()

func _load_map():
	var loaded := MapEditorYamlWriter.load_world_map()
	_metadata = loaded.get("metadata", {})
	_cities.assign(loaded.get("cities", []))
	_preserve_auto_connections()
	_metadata["connection_strategy"] = "manual"
	_create_city_nodes()
	_redraw_connections()

func _create_city_nodes():
	for city_data in _cities:
		_create_city_node(city_data)

func _preserve_auto_connections():
	var original_strategy: String = _metadata.get("connection_strategy", "manual")
	if original_strategy == "manual":
		return

	var data_manager := MapDataManager.new()
	var path := MapEditorYamlWriter.DEFAULT_PATH
	if not data_manager.load_map_data(path):
		return

	for city_data in _cities:
		var id: String = city_data.get("id", "")
		if id == "" or not data_manager.NODE_CONFIG.has(id):
			continue
		var runtime_connections: Array = data_manager.NODE_CONFIG[id].connections.duplicate()
		city_data["force_connections"] = runtime_connections

func _create_city_node(city_data: Dictionary) -> MapEditorCity:
	var city := preload("res://scenes/editor/MapEditorCity.tscn").instantiate() as MapEditorCity
	city.city_selected.connect(_on_city_selected)
	city.city_moved.connect(_on_city_moved)
	cities_container.add_child(city)
	city.setup(city_data)
	_city_nodes[city.get_city_id()] = city
	return city

func _connect_toolbar():
	toolbar.new_city_pressed.connect(_on_new_city)
	toolbar.delete_city_pressed.connect(_on_delete_city)
	toolbar.save_pressed.connect(_on_save)
	toolbar.back_pressed.connect(_on_back)
	toolbar.set_delete_enabled(false)

func _connect_properties_panel():
	properties_panel.name_changed.connect(_on_name_changed)
	properties_panel.type_changed.connect(_on_type_changed)
	properties_panel.connection_toggled.connect(_on_connection_toggled)

func _on_city_selected(city: MapEditorCity):
	_set_selected_city(city)

func _on_city_moved(city: MapEditorCity):
	_redraw_connections()

func _set_selected_city(city: MapEditorCity):
	if _selected_city and is_instance_valid(_selected_city):
		_selected_city.set_selected(false)
	_selected_city = city
	if _selected_city:
		_selected_city.set_selected(true)
		properties_panel.set_city(_selected_city.data, _cities)
	else:
		properties_panel.clear()
	toolbar.set_delete_enabled(_selected_city != null)

func _on_new_city():
	var new_id := _generate_new_city_id()
	var center := camera.position
	var new_city := {
		"id": new_id,
		"name": "新城",
		"type": "city",
		"icon_size": "large",
		"pos": {"x": int(center.x), "y": int(center.y)},
		"faction": "",
		"force_connections": []
	}
	_cities.append(new_city)
	var node := _create_city_node(new_city)
	_set_selected_city(node)

func _generate_new_city_id() -> String:
	var index := _cities.size() + 1
	while true:
		var id := "city_%02d" % index
		if not _city_nodes.has(id):
			return id
		index += 1
	return ""

func _on_delete_city():
	if _selected_city == null or delete_dialog == null:
		return
	_pending_delete_city = _selected_city
	var city_name: String = _selected_city.data.get("name", _selected_city.get_city_id())
	var conns: Array = _selected_city.data.get("force_connections", [])
	if conns.is_empty():
		delete_dialog.dialog_text = '确认删除城市 "%s"？' % city_name
	else:
		delete_dialog.dialog_text = '删除城市 "%s" 将同时移除它的所有连接。继续？' % city_name
	delete_dialog.popup_centered()

func _on_delete_confirmed():
	if _pending_delete_city == null:
		return
	if _pending_delete_city != _selected_city:
		_pending_delete_city = null
		return
	_perform_delete_city(_pending_delete_city)
	_pending_delete_city = null

func _on_delete_canceled():
	_pending_delete_city = null

func _perform_delete_city(city: MapEditorCity):
	var id := city.get_city_id()
	_city_nodes.erase(id)
	_cities.erase(city.data)
	city.queue_free()
	_remove_connections_to(id)
	_set_selected_city(null)
	_redraw_connections()

func _remove_connections_to(target_id: String):
	for city in _cities:
		var conns: Array = city.get("force_connections", []) as Array
		while conns.has(target_id):
			conns.erase(target_id)

func _on_name_changed(new_name: String):
	if _selected_city == null:
		return
	_selected_city.data["name"] = new_name
	_selected_city.refresh_visual()
	properties_panel.set_title(new_name)

func _on_type_changed(new_type: String):
	if _selected_city == null:
		return
	_selected_city.data["type"] = new_type
	_selected_city.refresh_visual()

func _on_connection_toggled(other_id: String, connected: bool):
	if _selected_city == null:
		return
	var selected_id := _selected_city.get_city_id()
	if selected_id == "":
		return

	# Ensure arrays exist
	if not _selected_city.data.has("force_connections"):
		_selected_city.data["force_connections"] = []
	var other_city := _get_city_data_by_id(other_id)
	if other_city.is_empty():
		return
	if not other_city.has("force_connections"):
		other_city["force_connections"] = []

	var selected_conns: Array = _selected_city.data["force_connections"] as Array
	var other_conns: Array = other_city["force_connections"] as Array

	if connected:
		if not selected_conns.has(other_id):
			selected_conns.append(other_id)
		if not other_conns.has(selected_id):
			other_conns.append(selected_id)
	else:
		selected_conns.erase(other_id)
		other_conns.erase(selected_id)

	_redraw_connections()

func _redraw_connections():
	for child in connections_node.get_children():
		child.queue_free()

	var drawn := {}
	for city_data in _cities:
		var from_id := city_data.get("id", "") as String
		if not _city_nodes.has(from_id):
			continue
		var from_pos := (_city_nodes[from_id] as MapEditorCity).position
		for to_id_raw in city_data.get("force_connections", []) as Array:
			var to_id := to_id_raw as String
			if not _city_nodes.has(to_id):
				continue
			var key := from_id + "<->" + to_id if from_id < to_id else to_id + "<->" + from_id
			if drawn.has(key):
				continue
			drawn[key] = true
			var to_pos := (_city_nodes[to_id] as MapEditorCity).position
			var line := Line2D.new()
			line.add_point(from_pos)
			line.add_point(to_pos)
			line.default_color = Color(0.8, 0.7, 0.4, 0.6)
			line.width = 2.0
			line.antialiased = true
			connections_node.add_child(line)

func _on_save():
	var error := _validate_map()
	if error != "":
		_show_save_result("保存失败: " + error)
		return
	var ok: bool = MapEditorYamlWriter.write_world_map(_metadata, _cities)
	if ok:
		_show_save_result("地图已保存")
	else:
		_show_save_result("保存失败，请检查文件权限。")

func _show_save_result(message: String):
	print(message)
	if save_dialog:
		save_dialog.dialog_text = message
		save_dialog.popup_centered()

func _validate_map() -> String:
	# Check duplicate city IDs
	var seen_ids := {}
	for city in _cities:
		var id: String = city.get("id", "")
		if id == "":
			continue
		if seen_ids.has(id):
			return "存在重复的城市 ID: %s" % id
		seen_ids[id] = true

	# Validate positions and overlap
	for i in range(_cities.size()):
		var c1 = _cities[i]
		if not (c1.get("pos") is Dictionary):
			return "%s 缺少有效位置" % c1.get("name", c1.get("id", "unknown"))
		var pos1_dict: Dictionary = c1["pos"]
		if not pos1_dict.has("x") or not pos1_dict.has("y"):
			return "%s 位置缺少 x 或 y" % c1.get("name", c1.get("id", "unknown"))
		var pos1 := Vector2(pos1_dict["x"], pos1_dict["y"])
		for j in range(i + 1, _cities.size()):
			var c2 = _cities[j]
			if not (c2.get("pos") is Dictionary):
				continue
			var pos2_dict: Dictionary = c2["pos"]
			if not pos2_dict.has("x") or not pos2_dict.has("y"):
				continue
			var pos2 := Vector2(pos2_dict["x"], pos2_dict["y"])
			if pos1.distance_to(pos2) < CITY_OVERLAP_THRESHOLD:
				return "%s 与 %s 重叠" % [c1.get("name", c1.get("id", "")), c2.get("name", c2.get("id", ""))]

	# Build id set and validate connections reference existing cities
	var city_ids := {}
	for city in _cities:
		var id: String = city.get("id", "")
		if id != "":
			city_ids[id] = true

	for city in _cities:
		var id: String = city.get("id", "")
		var conns: Array = city.get("force_connections", []) as Array
		if conns.is_empty():
			return "%s 没有连接" % city.get("name", id)
		for conn in conns:
			if not city_ids.has(conn):
				return "%s 的连接 %s 不存在" % [city.get("name", id), conn]

	# Validate full graph connectivity (treat connections as undirected)
	if _cities.size() > 0:
		var adjacency := {}
		for city in _cities:
			var id: String = city.get("id", "")
			if id == "":
				continue
			if not adjacency.has(id):
				adjacency[id] = []
			for neighbor in city.get("force_connections", []) as Array:
				var neighbor_id := neighbor as String
				if neighbor_id == "" or not city_ids.has(neighbor_id):
					continue
				if not (adjacency[id] as Array).has(neighbor_id):
					(adjacency[id] as Array).append(neighbor_id)
				if not adjacency.has(neighbor_id):
					adjacency[neighbor_id] = []
				if not (adjacency[neighbor_id] as Array).has(id):
					(adjacency[neighbor_id] as Array).append(id)

		var start_id := ""
		for city in _cities:
			var id: String = city.get("id", "")
			if id != "":
				start_id = id
				break
		if start_id == "":
			return "没有有效的起始城市"
		var visited := {}
		var queue: Array = [start_id]
		visited[start_id] = true
		while not queue.is_empty():
			var current_id: String = queue.pop_front()
			for neighbor in adjacency.get(current_id, []):
				if not visited.has(neighbor):
					visited[neighbor] = true
					queue.append(neighbor)
		if visited.size() != city_ids.size():
			return "地图未完全连通 (%d/%d 城市可达)" % [visited.size(), city_ids.size()]

	return ""

func _on_back():
	get_tree().change_scene_to_file("res://scenes/Main.tscn")

func _input(event):
	if event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				_zoom_camera(WHEEL_ZOOM_FACTOR)
			MOUSE_BUTTON_WHEEL_DOWN:
				_zoom_camera(1.0 / WHEEL_ZOOM_FACTOR)
			MOUSE_BUTTON_LEFT:
				if event.pressed:
					_is_panning = Input.is_key_pressed(KEY_SHIFT)
					if _is_panning:
						_drag_start = get_global_mouse_position()
				else:
					_is_panning = false
	elif event is InputEventMouseMotion and _is_panning:
		camera.position -= event.relative / camera.zoom

func _zoom_camera(factor: float):
	if camera == null:
		return
	var new_zoom := (camera.zoom * factor).clamp(Vector2(MIN_ZOOM, MIN_ZOOM), Vector2(MAX_ZOOM, MAX_ZOOM))
	var viewport := get_viewport()
	var screen_center := viewport.get_visible_rect().size / 2.0
	var mouse_screen := viewport.get_mouse_position()
	var offset := (mouse_screen - screen_center) * (Vector2.ONE / camera.zoom - Vector2.ONE / new_zoom)
	camera.position += offset
	camera.zoom = new_zoom

func _update_camera_limits():
	if camera == null:
		return
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = int(MAP_SIZE.x)
	camera.limit_bottom = int(MAP_SIZE.y)
