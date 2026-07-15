# Map Editor Continuation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Complete the remaining map-editor spec items: bidirectional connection editing, delete confirmation dialog, and save-result popup feedback.

**Architecture:** Add two dialog nodes (`ConfirmationDialog`, `AcceptDialog`) to `MapEditor.tscn` and drive them from `MapEditor.gd`. Connection toggles update both cities’ `force_connections`. Delete defers actual removal until the user confirms. Save replaces `print` calls with modal `AcceptDialog` text.

**Tech Stack:** Godot 4.6, GDScript, `world_map.yaml`, `YamlParser`, `MapEditorYamlWriter`.

## Global Constraints

- UI text remains in Chinese.
- `MapEditor.gd` is the single controller for editor behavior.
- YAML output must remain compatible with `YamlParser` (no flow style, no anchors).
- The editor stays a standalone scene; no main-menu integration in this plan.
- Validation rules remain: overlap threshold 60 px, no isolated nodes.

---

## File Structure

| File | Responsibility |
|------|----------------|
| `godot/scenes/editor/MapEditor.tscn` | Adds `ConfirmationDialog` and `AcceptDialog` child nodes under `UI`. |
| `godot/scripts/editor/MapEditor.gd` | Owns dialog references, handles connection-toggle symmetry, delete confirmation, save feedback. |

---

### Task 1: Add dialog nodes to the editor scene

**Files:**
- Modify: `godot/scenes/editor/MapEditor.tscn`

**Interfaces:**
- Consumes: existing `UI` CanvasLayer node.
- Produces: two new nodes accessible by unique name from `MapEditor.gd`:
  - `%DeleteConfirmationDialog` of type `ConfirmationDialog`
  - `%SaveResultDialog` of type `AcceptDialog`

- [ ] **Step 1: Open `godot/scenes/editor/MapEditor.tscn` in a text editor.**

- [ ] **Step 2: Add `ConfirmationDialog` and `AcceptDialog` as children of `UI`.**

Insert after the `PropertiesPanel` node line:

```ini
[node name="DeleteConfirmationDialog" type="ConfirmationDialog" parent="UI"]
initial_position = 1
size = Vector2i(400, 120)
dialog_text = "确认删除城市？"

[node name="SaveResultDialog" type="AcceptDialog" parent="UI"]
initial_position = 1
size = Vector2i(350, 120)
```

- [ ] **Step 3: Verify the scene still opens.**

Run:
```bash
cd godot
/Applications/Godot.app/Contents/MacOS/Godot --editor scenes/editor/MapEditor.tscn
```

Expected: Godot editor opens `MapEditor.tscn` without errors.

- [ ] **Step 4: Commit.**

```bash
git add godot/scenes/editor/MapEditor.tscn
git commit -m "feat(map-editor): add confirmation and result dialog nodes"
```

---

### Task 2: Implement bidirectional connection editing

**Files:**
- Modify: `godot/scripts/editor/MapEditor.gd`

**Interfaces:**
- Consumes: `_selected_city.data`, `_city_nodes`, `_cities`.
- Produces: `_on_connection_toggled` updates both the selected city and the target city; no new public API.

- [ ] **Step 1: Add a helper to look up city data by id.**

In `godot/scripts/editor/MapEditor.gd`, add after `_city_nodes: Dictionary = {}`:

```gdscript
func _get_city_data_by_id(city_id: String) -> Dictionary:
	for city in _cities:
		if city.get("id", "") == city_id:
			return city
	return {}
```

- [ ] **Step 2: Rewrite `_on_connection_toggled` to keep connections symmetric.**

Replace the existing `_on_connection_toggled` with:

```gdscript
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
```

- [ ] **Step 3: Verify in the running editor.**

Run:
```bash
cd godot
/Applications/Godot.app/Contents/MacOS/Godot scenes/editor/MapEditor.tscn
```

Steps:
1. Select a city with existing connections.
2. In the properties panel, uncheck one connection. The line should disappear.
3. Save (`保存`).
4. Open `godot/data/world_map.yaml` and confirm the previously connected city no longer lists the selected city in its `force_connections`.

Expected: both cities’ `force_connections` arrays are updated symmetrically.

- [ ] **Step 4: Commit.**

```bash
git add godot/scripts/editor/MapEditor.gd
git commit -m "feat(map-editor): keep force_connections symmetric on toggle"
```

---

### Task 3: Add delete confirmation dialog

**Files:**
- Modify: `godot/scripts/editor/MapEditor.gd`
- Modify: `godot/scenes/editor/MapEditor.tscn` (already done in Task 1)

**Interfaces:**
- Consumes: `%DeleteConfirmationDialog` confirmed signal.
- Produces: `_on_delete_city` shows the dialog; `_perform_delete_city` does the actual removal.

- [ ] **Step 1: Add dialog references and pending-delete state.**

In `godot/scripts/editor/MapEditor.gd`, add after `_is_panning: bool = false`:

```gdscript
@onready var delete_dialog: ConfirmationDialog = $UI/DeleteConfirmationDialog
var _pending_delete_city: MapEditorCity = null
```

- [ ] **Step 2: Connect the dialog in `_ready`.**

At the end of `_ready`, add:

```gdscript
	if delete_dialog:
		delete_dialog.confirmed.connect(_on_delete_confirmed)
		delete_dialog.canceled.connect(_on_delete_canceled)
```

- [ ] **Step 3: Change `_on_delete_city` to show the dialog.**

Replace `_on_delete_city` with:

```gdscript
func _on_delete_city():
	if _selected_city == null or delete_dialog == null:
		return
	_pending_delete_city = _selected_city
	var city_name := _selected_city.data.get("name", _selected_city.get_city_id())
	var conns: Array = _selected_city.data.get("force_connections", []) as Array
	if conns.is_empty():
		delete_dialog.dialog_text = '确认删除城市 "%s"？' % city_name
	else:
		delete_dialog.dialog_text = '删除城市 "%s" 将同时移除它的所有连接。继续？' % city_name
	delete_dialog.popup_centered()
```

- [ ] **Step 4: Add confirmed / canceled handlers.**

Add after `_on_delete_city`:

```gdscript
func _on_delete_confirmed():
	if _pending_delete_city == null:
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
```

- [ ] **Step 5: Remove the old immediate-delete logic from `_on_delete_city`.**

The old `_on_delete_city` body is replaced by the dialog-popup code above; no old deletion code remains in that function.

- [ ] **Step 6: Verify in the running editor.**

Run:
```bash
cd godot
/Applications/Godot.app/Contents/MacOS/Godot scenes/editor/MapEditor.tscn
```

Steps:
1. Select a city with connections, click `删除城市`. A confirmation dialog appears with the connection warning.
2. Click `取消`. The city remains selected and visible.
3. Click `删除城市` again, then `确认`. The city is removed and its connections disappear.
4. Select a city with no connections and click `删除城市`. The dialog shows the simpler message.

Expected: deletion only happens after confirmation; cancel leaves everything unchanged.

- [ ] **Step 7: Commit.**

```bash
git add godot/scripts/editor/MapEditor.gd
git commit -m "feat(map-editor): add delete confirmation dialog"
```

---

### Task 4: Add save-result popup feedback

**Files:**
- Modify: `godot/scripts/editor/MapEditor.gd`

**Interfaces:**
- Consumes: `%SaveResultDialog` and `_validate_map` / `MapEditorYamlWriter.write_world_map` results.
- Produces: `_on_save` shows a popup for validation errors, success, or write failure.

- [ ] **Step 1: Add the save-result dialog reference.**

In `godot/scripts/editor/MapEditor.gd`, add after the `delete_dialog` reference:

```gdscript
@onready var save_dialog: AcceptDialog = $UI/SaveResultDialog
```

- [ ] **Step 2: Rewrite `_on_save` to use the dialog.**

Replace `_on_save` with:

```gdscript
func _on_save():
	var error := _validate_map()
	if error != "":
		_show_save_result("保存失败: " + error)
		return
	var ok := MapEditorYamlWriter.write_world_map(_metadata, _cities)
	if ok:
		_show_save_result("地图已保存")
	else:
		_show_save_result("保存失败，请检查文件权限。")

func _show_save_result(message: String):
	print(message)
	if save_dialog:
		save_dialog.dialog_text = message
		save_dialog.popup_centered()
```

- [ ] **Step 3: Remove or demote the old `print` feedback.**

The `print` calls inside `_on_save` are replaced by `_show_save_result`; `_show_save_result` keeps `print` for debug logs but the dialog is the user-facing feedback.

- [ ] **Step 4: Verify in the running editor.**

Run:
```bash
cd godot
/Applications/Godot.app/Contents/MacOS/Godot scenes/editor/MapEditor.tscn
```

Steps:
1. Drag one city directly on top of another and click `保存`. A popup shows the overlap error in Chinese.
2. Undo the overlap, disconnect one city from everything so it has no `force_connections`, and click `保存`. A popup shows the isolated-node error.
3. Restore connections and click `保存`. A popup shows `地图已保存`.

Expected: every save action produces a visible Chinese message popup.

- [ ] **Step 5: Commit.**

```bash
git add godot/scripts/editor/MapEditor.gd
git commit -m "feat(map-editor): show popup feedback on save"
```

---

## Self-Review

- **Spec coverage:**
  - Bidirectional connections → Task 2.
  - Delete confirmation → Task 3.
  - Save feedback popups → Task 4.
- **Placeholder scan:** No TBD/TODO; each step has concrete code or commands.
- **Type consistency:** Node references use `@onready var ... = $UI/...` matching existing patterns; `_get_city_data_by_id` returns `Dictionary`; connection arrays are cast to `Array`.

## Execution Handoff

Plan complete and saved to `docs/superpowers/plans/2026-07-16-map-editor-continuation-plan.md`.

Two execution options:

1. **Subagent-Driven (recommended)** — I dispatch a fresh subagent per task, review between tasks, fast iteration.
2. **Inline Execution** — Execute tasks in this session using executing-plans, batch execution with checkpoints.

Which approach?
