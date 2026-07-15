# Map Editor Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a standalone map editor scene that lets the user drag cities, add/delete cities, edit city names/types/connections, and save the result back to `godot/data/world_map.yaml`.

**Architecture:** A new `MapEditor` scene reuses the existing `MapNode` visual by wrapping it in `MapEditorCity` nodes. The editor has a toolbar, a properties panel, and a dedicated YAML writer. `MapDataManager` is updated to respect a `"manual"` connection strategy so editor-saved YAML loads exactly as drawn.

**Tech Stack:** Godot 4.6, GDScript, existing `YamlParser`, PNG UI assets.

## Global Constraints

- Editor is a standalone scene: `scenes/editor/MapEditor.tscn`.
- Connection editing is fully manual.
- Editable city properties: position, name, type, manual connections.
- Preserved but non-editable fields: `faction`, `icon_size`, `blocked_neighbors`.
- Output YAML must remain parseable by the existing `YamlParser`.
- UI text is Chinese.
- Validation before save: no overlapping cities (< 60 px), no isolated cities.

---

## File Structure

| File | Responsibility |
|------|----------------|
| `scripts/editor/MapEditorYamlWriter.gd` | Load `world_map.yaml` via `YamlParser`; write YAML back preserving format. |
| `scripts/editor/MapEditorCity.gd` | Wrapper around `MapNode`. Handles selection, dragging, and visual feedback. |
| `scripts/editor/MapEditorToolbar.gd` | Top toolbar buttons: 新建城市, 删除城市, 保存, 返回. |
| `scripts/editor/MapEditorPropertiesPanel.gd` | Right-side panel for name, type, and connection checkboxes. |
| `scripts/editor/MapEditor.gd` | Main controller: load/save orchestration, camera, selection, city creation/deletion. |
| `scenes/editor/MapEditorCity.tscn` | City node scene with `MapNode` child, `Area2D`, and selection ring. |
| `scenes/editor/MapEditorToolbar.tscn` | Toolbar UI scene. |
| `scenes/editor/MapEditorPropertiesPanel.tscn` | Properties panel UI scene. |
| `scenes/editor/MapEditor.tscn` | Main editor scene. |
| `scripts/world_map/MapDataManager.gd` | Add `"manual"` connection strategy support. |

---

### Task 1: Support manual connection strategy in MapDataManager

**Files:**
- Modify: `scripts/world_map/MapDataManager.gd:71-143`

**Interfaces:**
- Consumes: `metadata.connection_strategy` string from YAML.
- Produces: When `connection_strategy == "manual"`, only `force_connections` and `manual_connections` are applied; auto-connect and component bridging are skipped.

- [ ] **Step 1: Read strategy and branch in `_generate_connections`**

Open `scripts/world_map/MapDataManager.gd` and change `_generate_connections`:

```gdscript
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
```

- [ ] **Step 2: Verify by temporarily changing YAML and running the game**

Edit `godot/data/world_map.yaml`:
```yaml
metadata:
  connection_strategy: "manual"
```

Run:
```bash
cd godot
/Applications/Godot.app/Contents/MacOS/Godot
```

Select a faction and check that only `force_connections` links are drawn; no auto-distance links appear. Then revert `connection_strategy` back to `"auto_with_overrides"`.

- [ ] **Step 3: Commit**

```bash
git add scripts/world_map/MapDataManager.gd
git commit -m "feat: support manual connection strategy in MapDataManager

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 2: Create YAML writer

**Files:**
- Create: `scripts/editor/MapEditorYamlWriter.gd`

**Interfaces:**
- Produces:
  - `static func load_world_map(path: String = "res://data/world_map.yaml") -> Dictionary` returning `{"metadata": Dictionary, "cities": Array[Dictionary]}`
  - `static func write_world_map(metadata: Dictionary, cities: Array, path: String = "res://data/world_map.yaml") -> bool`

- [ ] **Step 1: Create the script file**

Create `scripts/editor/MapEditorYamlWriter.gd`:

```gdscript
class_name MapEditorYamlWriter
extends RefCounted

const DEFAULT_PATH := "res://data/world_map.yaml"

static func load_world_map(path: String = DEFAULT_PATH) -> Dictionary:
	var result := {"metadata": {}, "cities": []}
	if not FileAccess.file_exists(path):
		push_error("MapEditorYamlWriter: file not found: " + path)
		return result

	var yaml_text := FileAccess.get_file_as_string(path)
	var parser := YamlParser.new()
	var parsed := parser.parse(yaml_text)
	if parsed == null or not parsed is Dictionary:
		push_error("MapEditorYamlWriter: failed to parse YAML")
		return result

	result["metadata"] = parsed.get("metadata", {})
	result["cities"] = parsed.get("nodes", [])
	return result

static func write_world_map(metadata: Dictionary, cities: Array, path: String = DEFAULT_PATH) -> bool:
	var lines: Array[String] = [
		"# World Map Data",
		"# Cities/forts/villages, positions, factions, and connection overrides",
		""
	]

	lines.append_array(_emit_metadata(metadata))
	lines.append("nodes:")
	for city in cities:
		lines.append_array(_emit_city(city))

	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("MapEditorYamlWriter: failed to open file for writing: " + path)
		return false
	file.store_string("\n".join(lines) + "\n")
	file.close()
	return true

static func _emit_metadata(metadata: Dictionary) -> Array[String]:
	var lines: Array[String] = ["metadata:"]
	var map_size = metadata.get("map_size", {})
	lines.append("  map_size:")
	lines.append("    x: %d" % map_size.get("x", 3840))
	lines.append("    y: %d" % map_size.get("y", 2160))
	lines.append('  connection_strategy: "%s"' % metadata.get("connection_strategy", "manual"))
	lines.append("  max_auto_distance: %d" % metadata.get("max_auto_distance", 320))
	lines.append("  target_connections: %d" % metadata.get("target_connections", 3))
	lines.append("")
	return lines

static func _emit_city(city: Dictionary) -> Array[String]:
	var lines: Array[String] = []
	lines.append('  - id: "%s"' % city.get("id", ""))
	lines.append('    name: "%s"' % _escape(city.get("name", "")))
	lines.append('    type: "%s"' % city.get("type", "city"))

	var icon_size: String = city.get("icon_size", "")
	if icon_size != "":
		lines.append('    icon_size: "%s"' % icon_size)

	var pos = city.get("pos", {})
	lines.append("    pos:")
	lines.append("      x: %d" % int(pos.get("x", 0)))
	lines.append("      y: %d" % int(pos.get("y", 0)))

	var faction: String = city.get("faction", "")
	lines.append('    faction: "%s"' % faction)

	var force_connections: Array = city.get("force_connections", [])
	if force_connections.size() > 0:
		lines.append("    force_connections:")
		for conn in force_connections:
			lines.append('      - "%s"' % conn)

	var blocked_neighbors: Array = city.get("blocked_neighbors", [])
	if blocked_neighbors.size() > 0:
		lines.append("    blocked_neighbors:")
		for blocked in blocked_neighbors:
			lines.append('      - "%s"' % blocked)

	return lines

static func _escape(value: String) -> String:
	return value.replace("\\", "\\\\").replace("\"", "\\\"")
```

- [ ] **Step 2: Test by running a quick load/write round-trip**

Create a temporary test by adding this to `scripts/editor/MapEditorYamlWriter.gd` temporarily at the bottom:

```gdscript
static func _run_test():
	var loaded := load_world_map()
	print("Loaded cities: ", loaded["cities"].size())
	var ok := write_world_map(loaded["metadata"], loaded["cities"], "user://test_world_map.yaml")
	print("Write ok: ", ok)
```

Then temporarily call `MapEditorYamlWriter._run_test()` from `Main.gd` `_ready()`. Run the game, check the output, and inspect `user://test_world_map.yaml`. Remove the test code afterward.

- [ ] **Step 3: Commit**

```bash
git add scripts/editor/MapEditorYamlWriter.gd
git commit -m "feat: add MapEditorYamlWriter for loading and saving world map YAML

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 3: Create draggable city node

**Files:**
- Create: `scripts/editor/MapEditorCity.gd`
- Create: `scenes/editor/MapEditorCity.tscn`

**Interfaces:**
- Produces:
  - `signal city_selected(city: MapEditorCity)`
  - `signal city_moved(city: MapEditorCity)`
  - `func setup(city_data: Dictionary) -> void`
  - `func set_selected(selected: bool) -> void`
  - `func get_city_id() -> String`
  - `var data: Dictionary`

- [ ] **Step 1: Create the script**

Create `scripts/editor/MapEditorCity.gd`:

```gdscript
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
	var pos = data.get("pos", {})
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
	is_selected = selected
	if selection_ring:
		selection_ring.visible = selected

func get_city_id() -> String:
	return data.get("id", "")

func refresh_visual():
	_update_map_node()

func _on_area_input_event(viewport, event: InputEvent, shape_idx):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			city_selected.emit(self)
			_dragging = true
			_drag_offset = position - get_global_mouse_position()
		else:
			_dragging = false
	elif event is InputEventMouseMotion and _dragging:
		position = get_global_mouse_position() + _drag_offset
		data["pos"]["x"] = position.x
		data["pos"]["y"] = position.y
		city_moved.emit(self)
```

- [ ] **Step 2: Create the scene**

Create `scenes/editor/MapEditorCity.tscn`:

```ini
[gd_scene load_steps=5 format=3 uid="uid://mapeditorcity_scene"]

[ext_resource type="Script" path="res://scripts/editor/MapEditorCity.gd" id="1_script"]
[ext_resource type="PackedScene" path="res://scenes/world_map/MapNode.tscn" id="2_mapnode"]

[sub_resource type="CircleShape2D" id="CircleShape2D_1"]
radius = 30.0

[sub_resource type="StyleBoxFlat" id="StyleBoxFlat_1"]
bg_color = Color(1, 0.9, 0, 0.3)
corner_radius_top_left = 35
corner_radius_top_right = 35
corner_radius_bottom_left = 35
corner_radius_bottom_right = 35

[node name="MapEditorCity" type="Node2D"]
script = ExtResource("1_script")

[node name="MapNode" parent="." instance=ExtResource("2_mapnode")]

[node name="Area2D" type="Area2D" parent="."]

[node name="CollisionShape2D" type="CollisionShape2D" parent="Area2D"]
shape = SubResource("CircleShape2D_1")

[node name="SelectionRing" type="Panel" parent="."]
z_index = 50
 custom_minimum_size = Vector2(70, 70)
size = Vector2(70, 70)
position = Vector2(-35, -35)
visible = false
theme_override_styles/panel = SubResource("StyleBoxFlat_1")
```

Note: the `SelectionRing` Panel uses a transparent yellow rounded style. Godot scene syntax for theme override style may need adjustment; use the editor if the hand-written tscn has issues.

- [ ] **Step 3: Verify by instantiating in a temporary scene**

Create a temporary test scene, instance `MapEditorCity`, call `setup()` with sample data, run it, and confirm you can drag the city and see the icon/label. Delete the temporary scene afterward.

- [ ] **Step 4: Commit**

```bash
git add scripts/editor/MapEditorCity.gd scenes/editor/MapEditorCity.tscn
git commit -m "feat: add draggable MapEditorCity node

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 4: Create toolbar UI

**Files:**
- Create: `scripts/editor/MapEditorToolbar.gd`
- Create: `scenes/editor/MapEditorToolbar.tscn`

**Interfaces:**
- Produces:
  - `signal new_city_pressed()`
  - `signal delete_city_pressed()`
  - `signal save_pressed()`
  - `signal back_pressed()`
  - `func set_delete_enabled(enabled: bool) -> void`

- [ ] **Step 1: Create the script**

Create `scripts/editor/MapEditorToolbar.gd`:

```gdscript
class_name MapEditorToolbar
extends HBoxContainer

signal new_city_pressed
signal delete_city_pressed
signal save_pressed
signal back_pressed

@onready var new_btn: Button = $NewBtn
@onready var delete_btn: Button = $DeleteBtn
@onready var save_btn: Button = $SaveBtn
@onready var back_btn: Button = $BackBtn

func _ready():
	new_btn.pressed.connect(func(): new_city_pressed.emit())
	delete_btn.pressed.connect(func(): delete_city_pressed.emit())
	save_btn.pressed.connect(func(): save_pressed.emit())
	back_btn.pressed.connect(func(): back_pressed.emit())

func set_delete_enabled(enabled: bool):
	delete_btn.disabled = not enabled
```

- [ ] **Step 2: Create the scene**

Create `scenes/editor/MapEditorToolbar.tscn`:

```ini
[gd_scene load_steps=2 format=3 uid="uid://mapeditortoolbar_scene"]

[ext_resource type="Script" path="res://scripts/editor/MapEditorToolbar.gd" id="1_script"]

[node name="MapEditorToolbar" type="HBoxContainer"]
anchors_preset = 10
anchor_right = 1.0
offset_bottom = 50.0
grow_horizontal = 2
alignment = 1
script = ExtResource("1_script")

[node name="NewBtn" type="Button" parent="."]
custom_minimum_size = Vector2(120, 40)
text = "新建城市"

[node name="DeleteBtn" type="Button" parent="."]
custom_minimum_size = Vector2(120, 40)
text = "删除城市"

[node name="SaveBtn" type="Button" parent="."]
custom_minimum_size = Vector2(120, 40)
text = "保存"

[node name="BackBtn" type="Button" parent="."]
custom_minimum_size = Vector2(120, 40)
text = "返回"
```

- [ ] **Step 3: Verify by adding to a temporary scene**

Add the toolbar to a temporary scene, run it, and confirm the four buttons are visible and signals fire. Delete the temporary scene afterward.

- [ ] **Step 4: Commit**

```bash
git add scripts/editor/MapEditorToolbar.gd scenes/editor/MapEditorToolbar.tscn
git commit -m "feat: add map editor toolbar UI

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 5: Create properties panel

**Files:**
- Create: `scripts/editor/MapEditorPropertiesPanel.gd`
- Create: `scenes/editor/MapEditorPropertiesPanel.tscn`

**Interfaces:**
- Produces:
  - `signal name_changed(new_name: String)`
  - `signal type_changed(new_type: String)`
  - `signal connection_toggled(city_id: String, connected: bool)`
  - `func set_city(city_data: Dictionary, all_cities: Array) -> void`
  - `func clear() -> void`

- [ ] **Step 1: Create the script**

Create `scripts/editor/MapEditorPropertiesPanel.gd`:

```gdscript
class_name MapEditorPropertiesPanel
extends Panel

signal name_changed(new_name: String)
signal type_changed(new_type: String)
signal connection_toggled(city_id: String, connected: bool)

@onready var title_label: Label = $VBox/TitleLabel
@onready var name_edit: LineEdit = $VBox/NameEdit
@onready var type_option: OptionButton = $VBox/TypeOption
@onready var connections_list: VBoxContainer = $VBox/Scroll/ConnectionsList

var _current_city_id: String = ""

func _ready():
	name_edit.text_submitted.connect(func(text: String): name_changed.emit(text))
	name_edit.focus_exited.connect(func(): name_changed.emit(name_edit.text))
	type_option.item_selected.connect(func(index: int): type_changed.emit(type_option.get_item_text(index)))

func set_city(city_data: Dictionary, all_cities: Array):
	_current_city_id = city_data.get("id", "")
	title_label.text = "属性: %s" % city_data.get("name", "")
	name_edit.text = city_data.get("name", "")

	var type = city_data.get("type", "city")
	for i in range(type_option.item_count):
		if type_option.get_item_text(i) == type:
			type_option.select(i)
			break

	for child in connections_list.get_children():
		child.queue_free()

	var connections: Array = city_data.get("force_connections", [])
	for other in all_cities:
		var other_id = other.get("id", "")
		if other_id == _current_city_id:
			continue
		var cb := CheckBox.new()
		cb.text = other.get("name", other_id)
		cb.button_pressed = connections.has(other_id)
		cb.toggled.connect(func(pressed: bool): connection_toggled.emit(other_id, pressed))
		connections_list.add_child(cb)

func clear():
	_current_city_id = ""
	title_label.text = "属性"
	name_edit.text = ""
	for child in connections_list.get_children():
		child.queue_free()
```

- [ ] **Step 2: Create the scene**

Create `scenes/editor/MapEditorPropertiesPanel.tscn`:

```ini
[gd_scene load_steps=2 format=3 uid="uid://mapeditorprops_scene"]

[ext_resource type="Script" path="res://scripts/editor/MapEditorPropertiesPanel.gd" id="1_script"]

[node name="MapEditorPropertiesPanel" type="Panel"]
anchors_preset = 11
anchor_left = 1.0
anchor_right = 1.0
anchor_bottom = 1.0
offset_left = -250.0
grow_horizontal = 0
grow_vertical = 2
script = ExtResource("1_script")

[node name="VBox" type="VBoxContainer" parent="."]
anchor_right = 1.0
anchor_bottom = 1.0
offset_left = 10.0
offset_top = 10.0
offset_right = -10.0
offset_bottom = -10.0

[node name="TitleLabel" type="Label" parent="VBox"]
text = "属性"
horizontal_alignment = 1

[node name="NameLabel" type="Label" parent="VBox"]
text = "名称"

[node name="NameEdit" type="LineEdit" parent="VBox"]

[node name="TypeLabel" type="Label" parent="VBox"]
text = "类型"

[node name="TypeOption" type="OptionButton" parent="VBox"]
item_count = 3
popup/item_0/text = "city"
popup/item_1/text = "fort"
popup/item_2/text = "village"

[node name="ConnectionsLabel" type="Label" parent="VBox"]
text = "连接"

[node name="Scroll" type="ScrollContainer" parent="VBox"]
size_flags_vertical = 3

[node name="ConnectionsList" type="VBoxContainer" parent="Scroll"]
```

- [ ] **Step 3: Verify by adding to a temporary scene**

Add the panel to a temporary scene, call `set_city()` with sample data, run it, and confirm name/type/connection checkboxes appear and signals fire. Delete the temporary scene afterward.

- [ ] **Step 4: Commit**

```bash
git add scripts/editor/MapEditorPropertiesPanel.gd scenes/editor/MapEditorPropertiesPanel.tscn
git commit -m "feat: add map editor properties panel

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 6: Create main editor scene and controller

**Files:**
- Create: `scripts/editor/MapEditor.gd`
- Create: `scenes/editor/MapEditor.tscn`

**Interfaces:**
- Produces: runnable `MapEditor.tscn` that loads `world_map.yaml`, allows editing, and saves back.

- [ ] **Step 1: Create the script**

Create `scripts/editor/MapEditor.gd`:

```gdscript
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

var _metadata: Dictionary = {}
var _cities: Array[Dictionary] = []
var _city_nodes: Dictionary = {}
var _selected_city: MapEditorCity = null
var _drag_start: Vector2 = Vector2.ZERO
var _is_panning: bool = false

func _ready():
	_setup_background()
	_load_map()
	_connect_toolbar()
	_connect_properties_panel()
	if camera:
		camera.position = MAP_SIZE / 2.0
		camera.zoom = Vector2(0.5, 0.5)
		_update_camera_limits()

func _setup_background():
	if background and background.texture:
		background.position = MAP_SIZE / 2.0
		background.scale = MAP_SIZE / background.texture.get_size()

func _load_map():
	var loaded := MapEditorYamlWriter.load_world_map()
	_metadata = loaded.get("metadata", {})
	_cities = loaded.get("cities", [])
	_metadata["connection_strategy"] = "manual"
	_create_city_nodes()
	_redraw_connections()

func _create_city_nodes():
	for city_data in _cities:
		_create_city_node(city_data)

func _create_city_node(city_data: Dictionary) -> MapEditorCity:
	var city := preload("res://scenes/editor/MapEditorCity.tscn").instantiate() as MapEditorCity
	city.setup(city_data)
	city.city_selected.connect(_on_city_selected)
	city.city_moved.connect(_on_city_moved)
	cities_container.add_child(city)
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

func _on_delete_city():
	if _selected_city == null:
		return
	var id := _selected_city.get_city_id()
	_city_nodes.erase(id)
	_cities.erase(_selected_city.data)
	_selected_city.queue_free()
	_remove_connections_to(id)
	_set_selected_city(null)
	_redraw_connections()

func _remove_connections_to(target_id: String):
	for city in _cities:
		var conns: Array = city.get("force_connections", [])
		while conns.has(target_id):
			conns.erase(target_id)

func _on_name_changed(new_name: String):
	if _selected_city == null:
		return
	_selected_city.data["name"] = new_name
	_selected_city.refresh_visual()
	properties_panel.title_label.text = "属性: %s" % new_name

func _on_type_changed(new_type: String):
	if _selected_city == null:
		return
	_selected_city.data["type"] = new_type
	_selected_city.refresh_visual()

func _on_connection_toggled(other_id: String, connected: bool):
	if _selected_city == null:
		return
	var conns: Array = _selected_city.data.get("force_connections", [])
	if connected:
		if not conns.has(other_id):
			conns.append(other_id)
	else:
		conns.erase(other_id)
	_redraw_connections()

func _redraw_connections():
	for child in connections_node.get_children():
		child.queue_free()

	var drawn := {}
	for city_data in _cities:
		var from_id := city_data.get("id", "")
		if not _city_nodes.has(from_id):
			continue
		var from_pos := _city_nodes[from_id].position
		for to_id in city_data.get("force_connections", []):
			if not _city_nodes.has(to_id):
				continue
			var key := from_id + "<->" + to_id if from_id < to_id else to_id + "<->" + from_id
			if drawn.has(key):
				continue
			drawn[key] = true
			var to_pos := _city_nodes[to_id].position
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
		print("保存失败: " + error)
		return
	var ok := MapEditorYamlWriter.write_world_map(_metadata, _cities)
	if ok:
		print("地图已保存")
	else:
		print("保存失败")

func _validate_map() -> String:
	for i in range(_cities.size()):
		var c1 = _cities[i]
		var pos1 := Vector2(c1["pos"]["x"], c1["pos"]["y"])
		for j in range(i + 1, _cities.size()):
			var c2 = _cities[j]
			var pos2 := Vector2(c2["pos"]["x"], c2["pos"]["y"])
			if pos1.distance_to(pos2) < CITY_OVERLAP_THRESHOLD:
				return "%s 与 %s 重叠" % [c1.get("name", c1["id"]), c2.get("name", c2["id"])]
	for city in _cities:
		var conns: Array = city.get("force_connections", [])
		if conns.is_empty():
			return "%s 没有连接" % city.get("name", city["id"])
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
```

- [ ] **Step 2: Create the scene**

Create `scenes/editor/MapEditor.tscn`:

```ini
[gd_scene load_steps=7 format=3 uid="uid://mapeditor_scene"]

[ext_resource type="Script" path="res://scripts/editor/MapEditor.gd" id="1_script"]
[ext_resource type="Texture2D" uid="uid://bk4cmjqkk8ik6" path="res://assets/world_map/backgrounds/world_map.png" id="2_bg"]
[ext_resource type="PackedScene" path="res://scenes/editor/MapEditorToolbar.tscn" id="3_toolbar"]
[ext_resource type="PackedScene" path="res://scenes/editor/MapEditorPropertiesPanel.tscn" id="4_props"]

[node name="MapEditor" type="Node2D"]
script = ExtResource("1_script")

[node name="Camera2D" type="Camera2D" parent="."]

[node name="Background" type="Sprite2D" parent="."]
z_index = -1
position = Vector2(1920, 1080)
scale = Vector2(1.54217, 1.4734)
texture = ExtResource("2_bg")

[node name="Connections" type="Node2D" parent="."]
z_index = -1

[node name="Cities" type="Node2D" parent="."]

[node name="UI" type="CanvasLayer" parent="."]

[node name="Toolbar" parent="UI" instance=ExtResource("3_toolbar")]

[node name="PropertiesPanel" parent="UI" instance=ExtResource("4_props")]
```

- [ ] **Step 3: Set the editor as runnable**

Temporarily set `MapEditor.tscn` as the main scene to test:

Option A — change `godot/project.godot`:
```ini
run/main_scene="res://scenes/editor/MapEditor.tscn"
```

Option B — run directly:
```bash
cd godot
/Applications/Godot.app/Contents/MacOS/Godot scenes/editor/MapEditor.tscn
```

Use Option B for testing; do not commit project.godot changes.

- [ ] **Step 4: Verify core loop**

Run the editor and confirm:
1. Cities appear at correct positions with icons and labels.
2. Clicking a city selects it and shows the properties panel.
3. Dragging a city moves it and updates connection lines.
4. Changing name/type updates the city visual.
5. Toggling connections updates the drawn lines.
6. Save writes to `godot/data/world_map.yaml` and the file is still parseable.
7. Back button returns to the main scene.

- [ ] **Step 5: Commit**

```bash
git add scripts/editor/MapEditor.gd scenes/editor/MapEditor.tscn
git commit -m "feat: add main map editor scene and controller

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 7: Add main menu entry (optional)

**Files:**
- Modify: `scenes/Main.tscn`
- Modify: `scripts/Main.gd`

**Interfaces:**
- Produces: a "地图编辑器" button on the main menu that opens `MapEditor.tscn`.

- [ ] **Step 1: Add button to main menu scene**

In `scenes/Main.tscn`, add a second Button under `MainMenu`:

```ini
[node name="MapEditorButton" type="Button" parent="MainMenu"]
anchors_preset = 8
anchor_left = 0.5
anchor_top = 0.5
anchor_right = 0.5
anchor_bottom = 0.5
offset_left = -100.0
offset_top = 90.0
offset_right = 100.0
offset_bottom = 140.0
grow_horizontal = 2
grow_vertical = 2
text = "地图编辑器"
```

- [ ] **Step 2: Wire button in Main.gd**

Add to `scripts/Main.gd` `_ready()`:

```gdscript
var map_editor_button = main_menu.get_node_or_null("MapEditorButton")
if map_editor_button:
    map_editor_button.pressed.connect(_on_map_editor_pressed)
```

Add function:

```gdscript
func _on_map_editor_pressed():
    get_tree().change_scene_to_file("res://scenes/editor/MapEditor.tscn")
```

- [ ] **Step 3: Verify**

Run the game from the main scene, click "地图编辑器", confirm the editor loads.

- [ ] **Step 4: Commit**

```bash
git add scenes/Main.tscn scripts/Main.gd
git commit -m "feat: add map editor entry to main menu

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Self-Review

**Spec coverage:**
- Separate scene file: Task 6.
- Full CRUD: Tasks 3 (create/delete in controller), 6.
- Manual connections: Task 1 (MapDataManager), Task 5 (UI), Task 6 (controller logic).
- Editable properties (position, name, type): Tasks 3, 5, 6.
- Save to YAML: Tasks 2, 6.
- Validation: Task 6.

**Placeholder scan:** No TBD/TODO/fill-in-details remain.

**Type consistency:**
- `MapEditorCity.data` is `Dictionary` everywhere.
- `force_connections` is `Array` of strings in YAML writer, properties panel, and controller.
- `connection_strategy` values are `"manual"` and `"auto_with_overrides"`.

**Gaps:** None identified.

---

## Execution Handoff

Plan complete and saved to `docs/superpowers/plans/2026-07-15-map-editor.md`.

Two execution options:

**1. Subagent-Driven (recommended)** — I dispatch a fresh subagent per task, review between tasks, fast iteration.

**2. Inline Execution** — Execute tasks in this session using `superpowers:executing-plans`, batch execution with checkpoints.

Which approach would you prefer?
