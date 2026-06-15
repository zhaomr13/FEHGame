# Three-Kingdoms-Style World Map Expansion Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` (recommended) or `superpowers:executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Expand the Godot world map from 10 hard-coded nodes to ~80 nodes on a 3840×2160 Three-Kingdoms-shaped continent, using a JSON data file, auto-generated connections, manual overrides, and a pannable/zoomable `Camera2D`.

**Architecture:** Map data moves from GDScript dictionaries into `godot/data/world_map.json`. `MapDataManager` loads the JSON, builds an in-memory `NODE_CONFIG`, auto-connects nodes by distance, applies manual overrides, and runs validation. `WorldMapManager` adds a `Camera2D` for pan/zoom and converts mouse coordinates to world space. A Python helper generates the initial ~80-node JSON so we don't hand-write 80 entries.

**Tech Stack:** Godot 4 GDScript, Python 3 (tool script), JSON, Godot `Camera2D`, `godot-asset-generator` for the background image.

---

## File Map

| File | Responsibility |
|------|----------------|
| `godot/assets/world_map/backgrounds/three_kingdoms_map.png` | 3840×2160 generated background image. |
| `godot/data/world_map.json` | Source of truth for all ~80 map nodes and connections. |
| `godot/tools/generate_world_map_json.py` | Python helper that creates the initial `world_map.json`. |
| `godot/scripts/world_map/MapDataManager.gd` | Loads JSON, builds `NODE_CONFIG`, auto-connects nodes, validates graph. |
| `godot/scripts/world_map/WorldMapManager.gd` | Adds camera input handling and world-space mouse clicks. |
| `godot/scenes/world_map/WorldMap.tscn` | Adds `Camera2D` node and updates background texture. |
| `godot/scripts/Main.gd` | Updates faction starting city ids. |
| `godot/tests/test_map_data.gd` | Headless validation test run with `godot --script`. |

---

## Task 1: Generate the Background Map Image

**Files:**
- Create: `godot/assets/world_map/backgrounds/three_kingdoms_map.png`

- [ ] **Step 1: Invoke `godot-asset-generator` skill**

Use the skill to generate a 3840×2160 top-down ancient-China-style continent map. Prompt:

```
A top-down strategy game world map, 3840x2160 pixels, stylized ancient Chinese ink-wash fantasy, muted earth tones. A single continent shaped like historical China with clear rivers, mountain ranges, plains, forests, and coastlines. No text, no UI, no units, no borders. Suitable as a 4K game background.
```

- [ ] **Step 2: Save and verify the image**

Save the result as `godot/assets/world_map/backgrounds/three_kingdoms_map.png`.

Run:
```bash
file godot/assets/world_map/backgrounds/three_kingdoms_map.png
```

Expected output contains `3840x2160`.

- [ ] **Step 3: Commit the image and import file**

```bash
git add godot/assets/world_map/backgrounds/three_kingdoms_map.png godot/assets/world_map/backgrounds/three_kingdoms_map.png.import
git commit -m "assets: add generated three-kingdoms world map background

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

## Task 2: Create the World Map JSON Generator

**Files:**
- Create: `godot/tools/generate_world_map_json.py`

- [ ] **Step 1: Write the generator script**

Create `godot/tools/generate_world_map_json.py` with this content:

```python
#!/usr/bin/env python3
"""Generate an initial world_map.json with ~80 nodes distributed across a Three-Kingdoms-shaped continent."""
import json
import random
from pathlib import Path

MAP_SIZE = (3840, 2160)
MIN_NODE_SPACING = 70
random.seed(42)

REGIONS = [
    {"name": "north",   "count": 10, "bbox": (1000, 200, 2200, 650),  "faction": "embla"},
    {"name": "central", "count": 22, "bbox": (1300, 700, 2700, 1200), "faction": "askr"},
    {"name": "west",    "count": 12, "bbox": (400, 750, 1150, 1450),  "faction": "muspell"},
    {"name": "east",    "count": 15, "bbox": (2750, 800, 3650, 1500), "faction": "nifl"},
    {"name": "south",   "count": 12, "bbox": (1300, 1450, 2850, 1900), "faction": ""},
    {"name": "border",  "count": 9,  "bbox": (300, 300, 3550, 2000),  "faction": ""},
]

NAME_POOLS = {
    "north": ["北境要塞", "霜风城", "铁壁关", "雪原镇", "冰河谷", "寒霜堡", "北风营", "冻土村", "极北城", "霜牙关"],
    "central": ["王都艾克拉", "中央平原", "金穗城", "银月城", "黎明关", "沃土镇", "青石城", "荣耀要塞", "疾风城", "翡翠镇", "琥珀城", "炽烈关", "平原村", "白鹿城", "黑铁堡", "晨曦港", "丰收镇", "钢铁关", "紫晶城", "云雀镇", "断剑城", "烈阳村"],
    "west": ["翠云峰", "剑门关", "白龙城", "雾隐镇", "千仞关", "落霞城", "苍松寨", "金沙渡", "玉龙堡", "幽谷村", "紫霞关", "铁索桥"],
    "east": ["蓝港城", "镜湖镇", "东海岸", "碧波港", "云梦泽", "临江城", "潮汐镇", "龙吟关", "翠竹港", "白鹭城", "渔火村", "沧海城", "烟波渡", "钱塘镇", "银沙湾"],
    "south": ["赤焰城", "南疆村", "榕树镇", "热浪关", "雨林寨", "金滩城", "椰子港", "火山口", "藤桥渡", "翡翠谷", "红土城", "棕榈镇"],
    "border": ["边境哨站", "游牧营地", "荒原镇", "风沙关", "驿站", "古道村", "关外寨", "峭壁堡", "迷雾渡"],
}


def place_nodes():
    nodes = []
    city_index = 1
    for region in REGIONS:
        bbox = region["bbox"]
        pool = NAME_POOLS[region["name"]]
        for i in range(region["count"]):
            pos = _find_valid_position(bbox, nodes)
            name = pool[i] if i < len(pool) else f"{region['name']}{i + 1}"
            node_type = random.choices(["city", "fort", "village"], weights=[0.6, 0.2, 0.2])[0]
            faction = region["faction"] if i == 0 else ""
            nodes.append({
                "id": f"city_{city_index:02d}",
                "name": name,
                "type": node_type,
                "pos": {"x": pos[0], "y": pos[1]},
                "faction": faction,
                "force_connections": [],
                "blocked_neighbors": []
            })
            city_index += 1
    return nodes


def _find_valid_position(bbox, existing):
    for _ in range(200):
        x = random.randint(bbox[0], bbox[2])
        y = random.randint(bbox[1], bbox[3])
        if all(((x - n["pos"]["x"]) ** 2 + (y - n["pos"]["y"]) ** 2) ** 0.5 >= MIN_NODE_SPACING for n in existing):
            return (x, y)
    # Fallback: return a random spot if spacing can't be satisfied
    return (random.randint(bbox[0], bbox[2]), random.randint(bbox[1], bbox[3]))


def build_manual_connections(nodes):
    """Add a few guaranteed cross-region links to guarantee connectivity."""
    by_id = {n["id"]: n for n in nodes}
    links = [
        ("city_10", "city_11"),  # north -> central
        ("city_22", "city_33"),  # central -> west
        ("city_32", "city_45"),  # central -> east
        ("city_28", "city_60"),  # central -> south
        ("city_44", "city_72"),  # west -> border
        ("city_59", "city_80"),  # east -> border
    ]
    valid = []
    for a, b in links:
        if a in by_id and b in by_id:
            valid.append({"from": a, "to": b})
    return valid


def main():
    nodes = place_nodes()
    data = {
        "metadata": {
            "map_size": {"x": MAP_SIZE[0], "y": MAP_SIZE[1]},
            "connection_strategy": "auto_with_overrides",
            "max_auto_distance": 320,
            "target_connections": 3
        },
        "nodes": nodes,
        "manual_connections": build_manual_connections(nodes)
    }
    out_path = Path("godot/data/world_map.json")
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"Wrote {len(nodes)} nodes to {out_path}")


if __name__ == "__main__":
    main()
```

- [ ] **Step 2: Make the script executable**

```bash
chmod +x godot/tools/generate_world_map_json.py
```

- [ ] **Step 3: Commit the tool**

```bash
git add godot/tools/generate_world_map_json.py
git commit -m "tools: add world map JSON generator

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

## Task 3: Generate and Inspect world_map.json

**Files:**
- Create: `godot/data/world_map.json`

- [ ] **Step 1: Run the generator**

```bash
python3 godot/tools/generate_world_map_json.py
```

Expected output:
```
Wrote 80 nodes to godot/data/world_map.json
```

- [ ] **Step 2: Validate JSON structure**

```bash
python3 - <<'PY'
import json
with open("godot/data/world_map.json", encoding="utf-8") as f:
    data = json.load(f)
print("nodes:", len(data["nodes"]))
print("manual_connections:", len(data["manual_connections"]))
print("metadata:", data["metadata"])
PY
```

Expected:
```
nodes: 80
manual_connections: 6
metadata: {'map_size': {'x': 3840, 'y': 2160}, 'connection_strategy': 'auto_with_overrides', 'max_auto_distance': 320, 'target_connections': 3}
```

- [ ] **Step 3: Commit the generated JSON**

```bash
git add godot/data/world_map.json
git commit -m "data: add generated 80-node world map JSON

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

## Task 4: Load JSON and Generate Connections in MapDataManager

**Files:**
- Modify: `godot/scripts/world_map/MapDataManager.gd`

- [ ] **Step 1: Replace inline `NODE_CONFIG` with JSON loading**

Replace the existing inline dictionary:

```gdscript
const DEFAULT_MAP_DATA_PATH = "res://data/world_map.json"

var NODE_CONFIG: Dictionary = {}

func _ready():
    load_map_data(DEFAULT_MAP_DATA_PATH)

func load_map_data(path: String) -> bool:
    if not FileAccess.file_exists(path):
        push_error("Map data file not found: " + path)
        return false

    var json_text = FileAccess.get_file_as_string(path)
    var parsed = JSON.parse_string(json_text)
    if parsed == null or not parsed is Dictionary:
        push_error("Failed to parse map data JSON")
        return false

    NODE_CONFIG = _build_node_config(parsed)
    _validate_map_data()
    return true
```

- [ ] **Step 2: Add helper to convert type strings to enum values**

```gdscript
func _node_type_from_string(type_str: String) -> int:
    match type_str:
        "fort":
            return GameConstants.NodeType.FORT
        "village":
            return GameConstants.NodeType.VILLAGE
        "city":
            return GameConstants.NodeType.CITY
    return GameConstants.NodeType.CITY
```

- [ ] **Step 3: Add `_build_node_config` and `_generate_connections`**

```gdscript
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
            "faction": node.get("faction", "")
        }

    _generate_connections(result, data)
    return result


func _generate_connections(config: Dictionary, data: Dictionary):
    var metadata = data.get("metadata", {})
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
                if not config[id].connections.has(forced):
                    config[id].connections.append(forced)
                if not config[forced].connections.has(id):
                    config[forced].connections.append(id)

    # 2. Auto-connect by distance
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

    # 3. Apply manual connections
    for link in data.get("manual_connections", []):
        var from_id = link.get("from", "")
        var to_id = link.get("to", "")
        if config.has(from_id) and config.has(to_id):
            if not config[from_id].connections.has(to_id):
                config[from_id].connections.append(to_id)
            if not config[to_id].connections.has(from_id):
                config[to_id].connections.append(from_id)
```

- [ ] **Step 4: Add `_validate_map_data` and expose `validate_map_data`**

```gdscript
func validate_map_data() -> bool:
    return _validate_map_data()

func _validate_map_data() -> bool:
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
        var queue: Array[String] = [start]
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
    var ids: Array[String] = NODE_CONFIG.keys()
    for i in range(ids.size()):
        for j in range(i + 1, ids.size()):
            var dist = NODE_CONFIG[ids[i]].pos.distance_to(NODE_CONFIG[ids[j]].pos)
            if dist < 60.0:
                push_warning("Map nodes %s and %s are too close (%.1f px)" % [ids[i], ids[j], dist])
                ok = false

    return ok
```

- [ ] **Step 5: Remove the old inline `NODE_CONFIG` block**

Delete lines 8–19 of the original file (the hard-coded dictionary) so `NODE_CONFIG` is only set by `load_map_data`.

- [ ] **Step 6: Run the game and check the output panel**

Run:
```bash
godot --path godot
```

Expected: no errors about missing JSON; warnings only if validation finds issues (should be none after Task 3).

- [ ] **Step 7: Commit**

```bash
git add godot/scripts/world_map/MapDataManager.gd
git commit -m "feat: load world map from JSON with auto-connections and validation

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

## Task 5: Add Camera Pan/Zoom to WorldMapManager

**Files:**
- Modify: `godot/scripts/world_map/WorldMapManager.gd`

- [ ] **Step 1: Add camera reference and drag state**

At the top of the class, add:

```gdscript
@onready var camera: Camera2D = $Camera2D

var _drag_start: Vector2 = Vector2.ZERO
var _is_dragging: bool = false
const DRAG_THRESHOLD: float = 5.0
const MIN_ZOOM: float = 0.25
const MAX_ZOOM: float = 1.5
const MAP_SIZE: Vector2 = Vector2(3840, 2160)
```

- [ ] **Step 2: Configure the camera in `_ready`**

At the end of `_ready`, call a new helper:

```gdscript
_setup_camera()
```

Add the helper:

```gdscript
func _setup_camera():
    if not camera:
        return
    camera.position = MAP_SIZE / 2.0
    camera.zoom = Vector2(0.5, 0.5)
    camera.limit_left = 0
    camera.limit_top = 0
    camera.limit_right = int(MAP_SIZE.x)
    camera.limit_bottom = int(MAP_SIZE.y)
    camera.drag_horizontal_enabled = false
    camera.drag_vertical_enabled = false
```

- [ ] **Step 3: Update `_input` for zoom, middle-mouse pan, and left-click selection**

Replace the existing `_input` function with:

```gdscript
func _input(event):
    if event is InputEventMouseButton:
        match event.button_index:
            MOUSE_BUTTON_WHEEL_UP:
                if camera:
                    camera.zoom = (camera.zoom * 1.1).clamp(Vector2(MIN_ZOOM, MIN_ZOOM), Vector2(MAX_ZOOM, MAX_ZOOM))
            MOUSE_BUTTON_WHEEL_DOWN:
                if camera:
                    camera.zoom = (camera.zoom / 1.1).clamp(Vector2(MIN_ZOOM, MIN_ZOOM), Vector2(MAX_ZOOM, MAX_ZOOM))
            MOUSE_BUTTON_LEFT:
                if current_phase != GamePhase.PLANNING:
                    return
                if event.pressed:
                    _drag_start = get_viewport().get_mouse_position()
                    _is_dragging = false
                else:
                    if not _is_dragging:
                        _handle_world_click()
    elif event is InputEventMouseMotion:
        if Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE) and camera:
            camera.position -= event.relative / camera.zoom
        elif Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
            var mouse_pos = get_viewport().get_mouse_position()
            if mouse_pos.distance_to(_drag_start) > DRAG_THRESHOLD:
                _is_dragging = true
```

> Note: Middle mouse drag pans so left-click node/army selection stays intact. If you prefer left-drag pan, we can switch MapNode to release-based clicks and suppress clicks after dragging.

- [ ] **Step 4: Move click handling into `_handle_world_click`**

```gdscript
func _handle_world_click():
    var world_pos = get_global_mouse_position()
    var clicked_army = _get_army_at_position(world_pos)
    if clicked_army:
        _on_army_clicked(clicked_army)
```

- [ ] **Step 5: Update `setup_background` to display the 4K background at native size**

Replace the existing `setup_background` function with:

```gdscript
func setup_background():
    if not background_sprite:
        return
    if background_sprite.texture:
        var bg_size = background_sprite.texture.get_size()
        background_sprite.position = bg_size / 2.0
        background_sprite.scale = Vector2(1.0, 1.0)
    else:
        background_sprite.position = MAP_SIZE / 2.0
```

- [ ] **Step 6: Run the game and verify camera behavior**

Run:
```bash
godot --path godot
```

Checks:
- Mouse wheel zooms in/out.
- Left-drag pans the map.
- Clicking an army selects it.
- Clicking a node sets a route.

- [ ] **Step 7: Commit**

```bash
git add godot/scripts/world_map/WorldMapManager.gd
git commit -m "feat: add Camera2D pan/zoom and world-space mouse clicks

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

## Task 6: Add Camera2D Node and Update Background Texture

**Files:**
- Modify: `godot/scenes/world_map/WorldMap.tscn`

- [ ] **Step 1: Update the background texture reference**

Find the `[ext_resource]` line near the top that loads the old background:

```ini
[ext_resource type="Texture2D" path="res://assets/world_map/backgrounds/world_map.png" id="4_bg"]
```

Change it to:

```ini
[ext_resource type="Texture2D" path="res://assets/world_map/backgrounds/three_kingdoms_map.png" id="4_bg"]
```

Leave `texture = ExtResource("4_bg")` unchanged.

- [ ] **Step 2: Add a Camera2D node**

Add this node block near the top-level nodes:

```ini
[node name="Camera2D" type="Camera2D" parent="."]
anchor_mode = 0
```

The final scene should contain: `WorldMap`, `Background`, `Connections`, `MapNodes`, `Armies`, `WorldMapUI`, `MapDataManager`, `GameClock`, `Camera2D`.

- [ ] **Step 3: Save and test in editor**

Open `godot/scenes/world_map/WorldMap.tscn` in the Godot editor, confirm no errors, and run the scene (F6).

- [ ] **Step 4: Commit**

```bash
git add godot/scenes/world_map/WorldMap.tscn godot/scenes/world_map/WorldMap.tscn-folding-* 2>/dev/null || true
git commit -m "feat: add Camera2D to world map scene and set new background texture

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

## Task 7: Update Faction Starting Positions

**Files:**
- Modify: `godot/scripts/Main.gd`

- [ ] **Step 1: Update `FACTION_START_POSITIONS`**

Replace the dictionary in `Main.gd` with:

```gdscript
const FACTION_START_POSITIONS = {
    "askr": "city_11",    # central kingdom
    "embla": "city_01",   # northern empire
    "nifl": "city_45",    # eastern kingdom
    "muspell": "city_33"  # western frontier
}
```

- [ ] **Step 2: Run the game and verify each faction starts in a different region**

Start the game, choose each faction, and confirm the player army appears in the expected region.

- [ ] **Step 3: Commit**

```bash
git add godot/scripts/Main.gd
git commit -m "feat: update faction starting cities for expanded map

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

## Task 8: Add Headless Map Validation Test

**Files:**
- Create: `godot/tests/test_map_data.gd`

- [ ] **Step 1: Create the test script**

```gdscript
extends SceneTree

func _initialize():
    var mgr_script = load("res://scripts/world_map/MapDataManager.gd")
    var mgr = mgr_script.new()
    root.add_child(mgr)

    # wait one frame so _ready() runs
    await create_timer(0.01).timeout

    var config = mgr.NODE_CONFIG
    assert(config != null and not config.is_empty(), "NODE_CONFIG should not be empty")
    assert(config.size() >= 75 and config.size() <= 85, "Node count should be ~80, got %d" % config.size())

    var valid = mgr.validate_map_data()
    assert(valid, "Map data validation failed; check output for warnings")

    print("Map data test PASSED: %d nodes, fully connected, no overlaps" % config.size())
    quit(0)
```

- [ ] **Step 2: Run the test**

```bash
godot --headless --path godot --script res://tests/test_map_data.gd
```

Expected output:
```
Map data test PASSED: 80 nodes, fully connected, no overlaps
```

- [ ] **Step 3: Commit the test**

```bash
git add godot/tests/test_map_data.gd
git commit -m "test: add headless map data validation test

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

## Task 9: Manual In-Game Verification

**Files:** none

- [ ] **Step 1: Launch the game**

```bash
godot --path godot
```

- [ ] **Step 2: Verify these behaviors**

- [ ] The background image loads and fills the 4K map area.
- [ ] ~80 nodes are visible when zoomed out.
- [ ] Connections (lines) are drawn between nearby nodes.
- [ ] Mouse wheel zooms in and out smoothly.
- [ ] Middle-mouse drag pans the camera.
- [ ] Camera stops at map edges.
- [ ] Clicking a player-owned city selects the army there.
- [ ] Clicking an adjacent node sets a route; the army moves along it during execution.
- [ ] Enemy armies move and battles trigger when armies meet.
- [ ] After battle, the game returns to the world map.

- [ ] **Step 3: Fix any issues found and commit fixes**

Use small, focused commits for each fix.

---

## Task 10: Finalize and Merge

- [ ] **Step 1: Review the branch diff**

```bash
git diff main --stat
```

Expected changed files:
```
godot/assets/world_map/backgrounds/three_kingdoms_map.png
 .../three_kingdoms_map.png.import
godot/data/world_map.json
godot/scenes/world_map/WorldMap.tscn
godot/scripts/Main.gd
godot/scripts/world_map/MapDataManager.gd
godot/scripts/world_map/WorldMapManager.gd
godot/tests/test_map_data.gd
godot/tools/generate_world_map_json.py
```

- [ ] **Step 2: Run the headless test one final time**

```bash
godot --headless --path godot --script res://tests/test_map_data.gd
```

Expected: `Map data test PASSED: 80 nodes, fully connected, no overlaps`

- [ ] **Step 3: Push the branch**

Only push if the user has previously authorized pushes; otherwise stop here and ask.

```bash
git push -u origin feature/three-kingdoms-map
```

---

## Self-Review Checklist

| Spec Section | Implementing Task |
|--------------|-------------------|
| JSON data format (§3) | Task 2, Task 3, Task 4 |
| ~80 nodes / regional layout (§4) | Task 2, Task 3 |
| 3840×2160 background image (§5) | Task 1 |
| Camera pan/zoom (§6) | Task 5, Task 6 |
| Auto-connections + overrides (§7) | Task 4 |
| Faction starting positions (§8) | Task 7 |
| Validation plan (§10) | Task 4, Task 8, Task 10 |

**Placeholder scan:** No TBD/TODO placeholders. All file paths, commands, and expected outputs are explicit.

**Type consistency:** `NODE_CONFIG` keeps the same shape (`name`, `type`, `pos`, `connections`, `faction`) so `WorldMapManager`, `Army`, and UI consumers continue to work.
