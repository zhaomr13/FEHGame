class_name MapEditorCity
extends Node2D

signal city_selected(city: MapEditorCity)
signal city_moved(city: MapEditorCity)

var data: Dictionary = {}
var is_selected: bool = false

var _dragging: bool = false
var _drag_offset: Vector2 = Vector2.ZERO

@onready var map_node: MapNode = $MapNode
@onready var area: Area2D = $Area2D
@onready var selection_ring: Panel = $SelectionRing

func _ready():
	if area:
		area.input_event.connect(_on_area_input_event)

func setup(city_data: Dictionary):
	data = city_data
	if not data.has("pos"):
		data["pos"] = {}
	var pos = data["pos"]
	position = Vector2(pos.get("x", 0.0), pos.get("y", 0.0))
	_update_map_node()
	# Disable MapNode's built-in click handling so the editor wrapper controls selection/drag.
	if map_node and map_node.area:
		if map_node.area.input_event.is_connected(map_node._on_area_input_event):
			map_node.area.input_event.disconnect(map_node._on_area_input_event)
		map_node.area.input_pickable = false

func _update_map_node():
	if map_node == null:
		return
	map_node.node_id = data.get("id", "")
	map_node.node_name = data.get("name", "Unknown")
	match data.get("type", "city"):
		"fort":
			map_node.node_type = GameConstants.NodeType.FORT
		"village":
			map_node.node_type = GameConstants.NodeType.VILLAGE
		_:
			map_node.node_type = GameConstants.NodeType.CITY
	map_node.icon_size = data.get("icon_size", "large")
	map_node.set_faction_color(data.get("faction", ""))
	map_node.update_visual()

func set_selected(selected: bool):
	if is_selected == selected:
		return
	is_selected = selected
	if selection_ring:
		selection_ring.visible = selected

func get_city_id() -> String:
	return data.get("id", "")

func refresh_visual():
	_update_map_node()

func _input(event: InputEvent):
	if not _dragging:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		print("DEBUG drag released globally: ", get_city_id())
		_dragging = false
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion:
		print("DEBUG dragging motion global, mouse=", get_global_mouse_position(), " new pos=", get_global_mouse_position() + _drag_offset)
		position = get_global_mouse_position() + _drag_offset
		data["pos"]["x"] = position.x
		data["pos"]["y"] = position.y
		city_moved.emit(self)
		get_viewport().set_input_as_handled()

func _on_area_input_event(viewport: Node, event: InputEvent, shape_idx: int):
	print("DEBUG MapEditorCity area input event: ", event.get_class())
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			print("DEBUG mouse pressed on city: ", get_city_id())
			city_selected.emit(self)
			_dragging = true
			_drag_offset = position - get_global_mouse_position()
			print("DEBUG dragging started, offset=", _drag_offset)
			get_viewport().set_input_as_handled()
