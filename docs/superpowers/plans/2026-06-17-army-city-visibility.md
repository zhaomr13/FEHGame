# Army City Visibility Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Hide armies while they are garrisoned inside cities and reveal them only when marching, with city-click selection for hidden armies.

**Architecture:** Add an `update_visibility()` helper to `Army.gd` that hides the army when `current_city_id` is set and state is not `MOVING`. `WorldMapManager.gd` will detect garrisoned armies on city clicks and either select a lone army or open a new `ArmySelectionPopup`. Execution phase will reveal routed armies before they move.

**Tech Stack:** Godot 4.6, GDScript

---

## File Structure

| File | Change |
|------|--------|
| `godot/scripts/world_map/Army.gd` | Add `update_visibility()` and call it from lifecycle methods |
| `godot/scripts/world_map/WorldMapManager.gd` | City-click army selection, popup wiring, execution-phase reveal |
| `godot/scripts/ui/ArmySelectionPopup.gd` | New popup script for choosing among multiple armies |
| `godot/scenes/ui/ArmySelectionPopup.tscn` | New popup scene |
| `godot/tests/test_world_map_scene.gd` | Update/add visibility assertions |

---

### Task 1: Add visibility helper to Army.gd

**Files:**
- Modify: `godot/scripts/world_map/Army.gd`

- [ ] **Step 1: Add `update_visibility()` method**

Insert after `setup_visual()`:

```gdscript
func update_visibility():
	if current_city_id != "" and state != ArmyState.MOVING:
		visible = false
	else:
		visible = true
```

- [ ] **Step 2: Call `update_visibility()` in `_ready()`**

At the end of `_ready()`:

```gdscript
func _ready():
	setup_visual()
	update_visibility()
```

- [ ] **Step 3: Commit**

```bash
git add godot/scripts/world_map/Army.gd
git commit -m "feat(Army): add update_visibility helper

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 2: Wire visibility into Army lifecycle

**Files:**
- Modify: `godot/scripts/world_map/Army.gd`

- [ ] **Step 1: Hide after plan is set**

In `set_route()`, the army is still garrisoned, so add at the end:

```gdscript
func set_route(waypoints: Array[Vector2], cities: Array[String]):
	# ... existing code ...
	state = ArmyState.PLANNED
	label.text = army_name + " →"
	_update_plan_line()
	update_visibility()
```

- [ ] **Step 2: Reveal when movement starts**

In `execute_plan()`:

```gdscript
func execute_plan():
	if planned_route.is_empty():
		return
	route = planned_route.duplicate()
	route_cities = planned_cities.duplicate()
	planned_route.clear()
	planned_cities.clear()
	plan_line.visible = false
	state = ArmyState.MOVING
	update_visibility()
```

- [ ] **Step 3: Hide when movement ends at a city**

In `_move_along_route()`, when the route empties:

```gdscript
func _move_along_route(delta):
	var target = route[0]
	var distance = position.distance_to(target)

	if distance < 2:
		position = target
		route.pop_front()
		if not route_cities.is_empty():
			current_city_id = route_cities.pop_front()
		if route.is_empty():
			state = ArmyState.IDLE
			label.text = army_name
			update_visibility()
			movement_finished.emit(self)
	else:
		var direction = (target - position).normalized()
		position += direction * MOVE_SPEED * delta
		z_index = int(position.y)
```

- [ ] **Step 4: Hide when plan is cancelled**

In `clear_plan()`:

```gdscript
func clear_plan():
	planned_route.clear()
	planned_cities.clear()
	plan_line.visible = false
	target_city_id = ""
	state = ArmyState.IDLE
	label.text = army_name
	update_visibility()
```

- [ ] **Step 5: Commit**

```bash
git add godot/scripts/world_map/Army.gd
git commit -m "feat(Army): wire visibility into lifecycle

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 3: Create ArmySelectionPopup UI

**Files:**
- Create: `godot/scripts/ui/ArmySelectionPopup.gd`
- Create: `godot/scenes/ui/ArmySelectionPopup.tscn`

- [ ] **Step 1: Write ArmySelectionPopup.gd**

```gdscript
class_name ArmySelectionPopup
extends Panel

signal army_selected(army: Army)
signal cancelled

@onready var item_list: ItemList = $VBoxContainer/ItemList
@onready var cancel_button: Button = $VBoxContainer/CancelButton

var _armies: Array[Army] = []

func _ready():
	cancel_button.pressed.connect(_on_cancel)
	item_list.item_selected.connect(_on_item_selected)
	visible = false

func setup(armies: Array[Army]):
	_armies = armies
	item_list.clear()
	for army in armies:
		var leader = army.get_leader_name()
		var text = "%s (%d members)" % [army.army_name, army.squad_data.size()]
		item_list.add_item(text)

func popup_at(center_position: Vector2):
	visible = true
	position = center_position - size / 2.0

func _on_item_selected(index: int):
	if index >= 0 and index < _armies.size():
		army_selected.emit(_armies[index])
	visible = false

func _on_cancel():
	visible = false
	cancelled.emit()
```

- [ ] **Step 2: Create ArmySelectionPopup.tscn**

Create `godot/scenes/ui/ArmySelectionPopup.tscn`:

```
[gd_scene load_steps=2 format=3 uid="uid://army_selection_popup"]

[ext_resource type="Script" path="res://scripts/ui/ArmySelectionPopup.gd" id="1_script"]

[node name="ArmySelectionPopup" type="Panel"]
custom_minimum_size = Vector2(250, 200)
offset_right = 250.0
offset_bottom = 200.0
script = ExtResource("1_script")

[node name="VBoxContainer" type="VBoxContainer" parent="."]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
offset_left = 10.0
offset_top = 10.0
offset_right = -10.0
offset_bottom = -10.0
grow_horizontal = 2
grow_vertical = 2

[node name="TitleLabel" type="Label" parent="VBoxContainer"]
layout_mode = 2
text = "Select Army"
horizontal_alignment = 1

[node name="ItemList" type="ItemList" parent="VBoxContainer"]
layout_mode = 2
size_flags_vertical = 3

[node name="CancelButton" type="Button" parent="VBoxContainer"]
layout_mode = 2
text = "Cancel"
```

- [ ] **Step 3: Commit**

```bash
git add godot/scripts/ui/ArmySelectionPopup.gd godot/scenes/ui/ArmySelectionPopup.tscn
git commit -m "feat(ui): add ArmySelectionPopup for choosing garrisoned armies

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 4: Update WorldMapManager city-click handling

**Files:**
- Modify: `godot/scripts/world_map/WorldMapManager.gd`

- [ ] **Step 1: Add popup instance variable and setup**

Add near other UI vars:

```gdscript
var army_selection_popup: ArmySelectionPopup = null
```

In `setup_ui()`:

```gdscript
func setup_ui():
	setup_city_menu()
	setup_squad_menu()
	setup_planning_ui()
	setup_army_selection_popup()
```

Add new function:

```gdscript
func setup_army_selection_popup():
	army_selection_popup = preload("res://scenes/ui/ArmySelectionPopup.tscn").instantiate()
	ui.add_child(army_selection_popup)
	army_selection_popup.army_selected.connect(_on_popup_army_selected)
	army_selection_popup.cancelled.connect(_on_popup_cancelled)

func _on_popup_army_selected(army: Army):
	_on_army_clicked(army)

func _on_popup_cancelled():
	if city_menu:
		city_menu.visible = true
```

- [ ] **Step 2: Add helper to find armies in a city**

```gdscript
func _get_player_armies_at_city(city_id: String) -> Array[Army]:
	var result: Array[Army] = []
	for army in player_armies:
		if is_instance_valid(army) and army.current_city_id == city_id:
			result.append(army)
	return result
```

- [ ] **Step 3: Modify `_on_node_clicked()`**

Replace the no-army-selected branch:

```gdscript
func _on_node_clicked(node: MapNode):
	if current_phase != GamePhase.PLANNING:
		return

	if selected_army == null:
		var garrisoned = _get_player_armies_at_city(node.node_id)
		if garrisoned.size() == 1:
			_on_army_clicked(garrisoned[0])
		elif garrisoned.size() > 1:
			if city_menu:
				city_menu.visible = false
			army_selection_popup.setup(garrisoned)
			var screen_center = get_viewport().get_visible_rect().size / 2.0
			army_selection_popup.popup_at(screen_center)
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
```

- [ ] **Step 4: Commit**

```bash
git add godot/scripts/world_map/WorldMapManager.gd
git commit -m "feat(world_map): select garrisoned armies by clicking cities

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 5: Reveal moving armies at execution start

**Files:**
- Modify: `godot/scripts/world_map/WorldMapManager.gd`

- [ ] **Step 1: Update `_start_execution()`**

Before executing plans, reveal armies:

```gdscript
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
			army.update_visibility()
			army.execute_plan()
			_executing_armies[army] = true
	if clock:
		clock.is_running = true
	if _executing_armies.is_empty():
		_end_execution()
	_update_planning_ui()
```

- [ ] **Step 2: Commit**

```bash
git add godot/scripts/world_map/WorldMapManager.gd
git commit -m "feat(world_map): reveal armies when execution phase starts

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 6: Update world map tests

**Files:**
- Modify: `godot/tests/test_world_map_scene.gd`

- [ ] **Step 1: Add visibility assertions**

After `setup_faction_start` is called and armies are created, add:

```gdscript
# Verify armies are hidden inside cities
for army in world_map.player_armies:
    assert(not army.visible, "Player army in city should be hidden")
for army in world_map.enemy_armies:
    assert(not army.visible, "Enemy army in city should be hidden")
```

- [ ] **Step 2: Add route-and-execution visibility test**

Find a player army, set a route, start execution, and verify visibility:

```gdscript
var army = world_map.player_armies[0]
var target_city = ""
for city_id in map_data.NODE_CONFIG[army.current_city_id].connections:
    target_city = city_id
    break

if target_city != "":
    var path = world_map._find_route(army, target_city)
    var waypoints: Array[Vector2] = []
    var cities: Array[String] = []
    for city_id in path:
        var pos = map_data.map_nodes[city_id].position
        waypoints.append(pos + Vector2(20, -20))
        cities.append(city_id)
    army.set_route(waypoints, cities)
    assert(not army.visible, "Army should stay hidden while planning")

    world_map._start_execution()
    assert(army.visible, "Army should be visible when moving")
```

- [ ] **Step 3: Run the test**

```bash
cd godot
/Applications/Godot.app/Contents/MacOS/Godot --headless --script tests/test_world_map_scene.gd
```

Expected: `WorldMap scene integration test PASSED`

- [ ] **Step 4: Commit**

```bash
git add godot/tests/test_world_map_scene.gd
git commit -m "test(world_map): verify army visibility in cities and during movement

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 7: Final verification

**Files:**
- All modified files

- [ ] **Step 1: Run full test suite**

```bash
cd godot
/Applications/Godot.app/Contents/MacOS/Godot --headless --script tests/test_dynamic_squads.gd
/Applications/Godot.app/Contents/MacOS/Godot --headless --script tests/test_character_roster.gd
/Applications/Godot.app/Contents/MacOS/Godot --headless --script tests/test_world_map_scene.gd
```

Expected: All three pass.

- [ ] **Step 2: Manual smoke test**

Launch the game, start a faction, confirm:
- Armies are not visible inside cities.
- Clicking a city with one army selects it.
- Setting a route and ending planning makes the army appear and move.
- After the army arrives, it disappears.

- [ ] **Step 3: Final commit if any changes**

If manual testing required fixes, commit them before finishing.

---

## Self-Review

**Spec coverage:**
- Hide armies inside cities → Task 1 + Task 2 (`update_visibility()` in Army lifecycle)
- Reveal on march → Task 2 + Task 5 (`execute_plan()` and `_start_execution()`)
- Hide on arrival → Task 2 (`_move_along_route()`)
- City-based selection → Task 3 + Task 4 (`_on_node_clicked()` and popup)
- Enemy parity → Task 1/2 apply to all armies; no faction-specific logic

**Placeholder scan:** No TBD/TODO/fill-in-details found.

**Type consistency:** `ArmySelectionPopup.setup()` takes `Array[Army]`. `_get_player_armies_at_city()` returns `Array[Army]`. Popup signals use `Army`. All consistent.
