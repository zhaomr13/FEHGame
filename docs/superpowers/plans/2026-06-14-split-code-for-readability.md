# Split Code for Readability Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Split four oversized GDScript files into focused node components and clean up dead code, without changing game behavior.

**Architecture:** Add child nodes to existing scenes to own focused responsibilities. Root scripts become thin coordinators that delegate to children. A new `CharacterDatabase` autoload extracts character initialization from `GameManager`.

**Tech Stack:** Godot 4.4, GDScript

---

## File Structure

### New files to create

- `godot/scripts/autoload/CharacterDatabase.gd`
- `godot/scripts/world_map/MapDataManager.gd`
- `godot/scripts/world_map/WorldMapArmyManager.gd`
- `godot/scripts/world_map/PlanningPhaseController.gd`
- `godot/scripts/world_map/ExecutionPhaseController.gd`
- `godot/scripts/battle/BattleBackgroundManager.gd`
- `godot/scripts/battle/BattleDeploymentManager.gd`
- `godot/scripts/battle/BattleUnitFactory.gd`
- `godot/scripts/battle/BattleStatusPanel.gd`
- `godot/scripts/battle/BattleTurnManager.gd`
- `godot/scripts/battle/BattleUnitTactics.gd`
- `godot/scripts/battle/BattleUnitCombat.gd`
- `godot/scripts/battle/BattleUnitMovement.gd`
- `godot/scripts/ui/SquadMenuData.gd`
- `godot/scripts/ui/SquadMenuLists.gd`
- `godot/scripts/ui/SquadMenuActions.gd`

### Files to modify

- `godot/scripts/autoload/GameManager.gd`
- `godot/scripts/world_map/WorldMapManager.gd`
- `godot/scripts/world_map/WorldMap.tscn`
- `godot/scripts/battle/BattleManager.gd`
- `godot/scripts/battle/BattleScene.tscn`
- `godot/scripts/battle/BattleUnit.gd`
- `godot/scripts/battle/BattleUnit.tscn`
- `godot/scripts/ui/SquadMenu.gd`
- `godot/scripts/ui/SquadMenu.tscn`
- `godot/scripts/world_map/Army.gd`
- `godot/project.godot`

### Files to delete

- `godot/scripts/Character.gd` (duplicate of `godot/scripts/character/Character.gd`)

---

## Task 1: Setup and baseline

**Files:**
- Modify: `godot/project.godot`

- [ ] **Step 1: Verify git status is clean**

Run:
```bash
cd /Users/mzhao/workdir/feh && git status
```
Expected: working tree clean

- [ ] **Step 2: Register CharacterDatabase autoload**

Add to `godot/project.godot` under `[autoload]`:
```ini
CharacterDatabase="*res://scripts/autoload/CharacterDatabase.gd"
```

- [ ] **Step 3: Commit setup**

```bash
git add godot/project.godot
git commit -m "chore: register CharacterDatabase autoload"
```

---

## Task 2: Extract CharacterDatabase

**Files:**
- Create: `godot/scripts/autoload/CharacterDatabase.gd`
- Modify: `godot/scripts/autoload/GameManager.gd`

- [ ] **Step 1: Create CharacterDatabase.gd**

Move these methods from `GameManager.gd` into the new file:
- `_initialize_all_characters()`
- `_create_character(...)`
- `get_characters_by_faction(faction)`
- `get_characters_not_in_faction(faction)`

Also move the `all_characters` and `available_recruits` arrays.

Use `class_name CharacterDatabase extends Node` and keep it as an autoload. No signals needed.

- [ ] **Step 2: Update GameManager to use CharacterDatabase**

In `GameManager._ready()`, replace `_initialize_all_characters()` with:
```gdscript
CharacterDatabase._initialize_all_characters()
```

In `WorldMapManager._create_enemy_armies`, it currently calls `GameManager.get_characters_by_faction(faction)`. Change this to `CharacterDatabase.get_characters_by_faction(faction)`. Also update any other callers.

- [ ] **Step 3: Static validation**

Run:
```bash
grep -R "GameManager.get_characters_by_faction\|GameManager.get_characters_not_in_faction\|GameManager._initialize_all_characters\|GameManager._create_character" /Users/mzhao/workdir/feh/godot/scripts/
```
Expected: no matches

- [ ] **Step 4: Commit**

```bash
git add godot/scripts/autoload/CharacterDatabase.gd godot/scripts/autoload/GameManager.gd godot/scripts/world_map/WorldMapManager.gd
git commit -m "refactor: extract CharacterDatabase from GameManager"
```

---

## Task 3: Split WorldMapManager — MapDataManager

**Files:**
- Create: `godot/scripts/world_map/MapDataManager.gd`
- Modify: `godot/scripts/world_map/WorldMapManager.gd`

- [ ] **Step 1: Create MapDataManager.gd**

```gdscript
class_name MapDataManager
extends Node2D

signal node_clicked(node: MapNode)

var map_nodes: Dictionary = {}
var connections: Dictionary = {}

const WORLD_BACKGROUNDS = {
    "world_map": "res://assets/world_map/backgrounds/world_map.png",
    "occupation": "res://assets/world_map/backgrounds/occupation_map.png",
}

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

func _ready():
    create_map_nodes()
    draw_connections()

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

func can_move_to(from_id: String, to_id: String) -> bool:
    if from_id == to_id:
        return false
    if NODE_CONFIG.has(from_id) and NODE_CONFIG[from_id].connections.has(to_id):
        return true
    return false

func find_path(from_id: String, to_id: String) -> Array[String]:
    if can_move_to(from_id, to_id):
        return [to_id]
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
```

- [ ] **Step 2: Remove map logic from WorldMapManager**

Delete from `WorldMapManager.gd`:
- `map_nodes` and `connections` variables
- `NODE_CONFIG` constant
- `create_map_nodes()`
- `draw_connections()`
- `select_battle_background()`
- `_can_move_to()`
- `_find_path()`

Replace references with calls to `$MapDataManager`:
- `map_nodes[city_id]` → `$MapDataManager.map_nodes[city_id]`
- `NODE_CONFIG[city_id]` → `$MapDataManager.NODE_CONFIG[city_id]`
- `_can_move_to(...)` → `$MapDataManager.can_move_to(...)`
- `_find_path(...)` → `$MapDataManager.find_path(...)`
- `select_battle_background(...)` → `$MapDataManager.select_battle_background(...)`

- [ ] **Step 3: Static validation**

Run:
```bash
grep -n "NODE_CONFIG\|create_map_nodes\|draw_connections\|func _can_move_to\|func _find_path\|func select_battle_background" /Users/mzhao/workdir/feh/godot/scripts/world_map/WorldMapManager.gd
```
Expected: only references inside delegate calls, no definitions

- [ ] **Step 4: Commit**

```bash
git add godot/scripts/world_map/MapDataManager.gd godot/scripts/world_map/WorldMapManager.gd
git commit -m "refactor: extract MapDataManager from WorldMapManager"
```

---

## Task 4: Split WorldMapManager — WorldMapArmyManager

**Files:**
- Create: `godot/scripts/world_map/WorldMapArmyManager.gd`
- Modify: `godot/scripts/world_map/WorldMapManager.gd`
- Modify: `godot/scenes/world_map/WorldMap.tscn`

- [ ] **Step 1: Create WorldMapArmyManager.gd**

Move these responsibilities from `WorldMapManager`:
- `player_armies`, `enemy_armies`, `selected_army`
- `_clear_armies()`
- `_create_player_armies_from_squads()`
- `_convert_squad_data()`
- `_create_default_player_army()`
- `_create_enemy_armies()`
- `_get_faction_squad()`
- `_get_squad_characters()`
- `_initialize_squads()`
- `_update_army_position()`
- `_refresh_player_armies()`
- `_create_squad_from_main()`
- `_set_selected_army()`
- `_get_army_at_position()`

Signals:
```gdscript
signal army_selected(army: Army)
signal enemy_targeted(attacker: Army, target: Army)
```

Use `@onready var armies_container: Node2D = $"../Armies"` and `@onready var map_data: MapDataManager = $"../MapDataManager"`.

- [ ] **Step 2: Update WorldMapManager to delegate army logic**

Replace direct army manipulation with calls to `$WorldMapArmyManager`.

- [ ] **Step 3: Add child node to WorldMap.tscn**

Add a `WorldMapArmyManager` child under the root with script `res://scripts/world_map/WorldMapArmyManager.gd`.

- [ ] **Step 4: Static validation**

Run:
```bash
grep -n "player_armies\|enemy_armies\|_create_player_armies\|_create_enemy_armies\|_refresh_player_armies" /Users/mzhao/workdir/feh/godot/scripts/world_map/WorldMapManager.gd
```
Expected: only references inside delegate calls, no definitions

- [ ] **Step 5: Commit**

```bash
git add godot/scripts/world_map/WorldMapArmyManager.gd godot/scripts/world_map/WorldMapManager.gd godot/scenes/world_map/WorldMap.tscn
git commit -m "refactor: extract WorldMapArmyManager"
```

---

## Task 5: Split WorldMapManager — PlanningPhaseController

**Files:**
- Create: `godot/scripts/world_map/PlanningPhaseController.gd`
- Modify: `godot/scripts/world_map/WorldMapManager.gd`
- Modify: `godot/scenes/world_map/WorldMap.tscn`

- [ ] **Step 1: Create PlanningPhaseController.gd**

Move from `WorldMapManager`:
- Planning UI creation (`setup_planning_ui()`)
- `_start_planning_phase()`
- `_on_end_planning_pressed()`
- `_on_clear_plans_pressed()`
- `_on_army_clicked()`
- `_start_drag_plan()`
- `_end_drag_selection()`
- `_on_node_clicked()`
- Drag state (`is_dragging_plan`, `drag_start_army`)
- `open_city_menu()`
- `_on_open_formation()`

Expose signals:
```gdscript
signal planning_ended
signal plans_cleared
signal city_opened(node: MapNode)
signal formation_opened
```

- [ ] **Step 2: Update WorldMapManager**

Connect `PlanningPhaseController` signals to the remaining manager methods.

- [ ] **Step 3: Add child node to WorldMap.tscn**

Add `PlanningPhaseController` child node with the new script.

- [ ] **Step 4: Static validation**

Run:
```bash
grep -n "is_dragging_plan\|setup_planning_ui\|_on_node_clicked\|_start_drag_plan" /Users/mzhao/workdir/feh/godot/scripts/world_map/WorldMapManager.gd
```
Expected: no definitions

- [ ] **Step 5: Commit**

```bash
git add godot/scripts/world_map/PlanningPhaseController.gd godot/scripts/world_map/WorldMapManager.gd godot/scenes/world_map/WorldMap.tscn
git commit -m "refactor: extract PlanningPhaseController"
```

---

## Task 6: Split WorldMapManager — ExecutionPhaseController

**Files:**
- Create: `godot/scripts/world_map/ExecutionPhaseController.gd`
- Modify: `godot/scripts/world_map/WorldMapManager.gd`
- Modify: `godot/scenes/world_map/WorldMap.tscn`

- [ ] **Step 1: Create ExecutionPhaseController.gd**

Move from `WorldMapManager`:
- `_start_execution_phase()`
- `_execute_next_move()`
- `_wait_for_move_complete()`
- `_check_encounter()`
- `_start_battle()`
- `_process_enemy_turn()`
- `execution_queue`

Expose signals:
```gdscript
signal battle_started(attacker: Army, defender: Army)
signal execution_ended
```

- [ ] **Step 2: Update WorldMapManager**

Delegate execution phase start and connect `battle_started` to `_start_battle` handler.

- [ ] **Step 3: Add child node to WorldMap.tscn**

Add `ExecutionPhaseController` child node with the new script.

- [ ] **Step 4: Static validation**

Run:
```bash
grep -n "execution_queue\|_execute_next_move\|_process_enemy_turn\|_start_execution_phase" /Users/mzhao/workdir/feh/godot/scripts/world_map/WorldMapManager.gd
```
Expected: no definitions

- [ ] **Step 5: Commit**

```bash
git add godot/scripts/world_map/ExecutionPhaseController.gd godot/scripts/world_map/WorldMapManager.gd godot/scenes/world_map/WorldMap.tscn
git commit -m "refactor: extract ExecutionPhaseController"
```

---

## Task 7: Split BattleManager — Background and Deployment

**Files:**
- Create: `godot/scripts/battle/BattleBackgroundManager.gd`
- Create: `godot/scripts/battle/BattleDeploymentManager.gd`
- Modify: `godot/scripts/battle/BattleManager.gd`
- Modify: `godot/scenes/battle/BattleScene.tscn`

- [ ] **Step 1: Create BattleBackgroundManager.gd**

Move `BATTLE_BACKGROUNDS` constant and `set_background()` method.

- [ ] **Step 2: Create BattleDeploymentManager.gd**

Move:
- `start_deployment()`
- `_play_preparation_animation()`
- `_create_preview_unit()`
- `_on_deployment_confirmed()`

Expose signal:
```gdscript
signal deployment_confirmed(player_army: Array, enemy_army: Array, formation: int)
```

- [ ] **Step 3: Update BattleManager**

Delegate `set_background` and `start_deployment` to child nodes. Connect `deployment_confirmed` to start combat.

- [ ] **Step 4: Add child nodes to BattleScene.tscn**

Add `BattleBackgroundManager` and `BattleDeploymentManager` children.

- [ ] **Step 5: Static validation**

```bash
grep -n "BATTLE_BACKGROUNDS\|_play_preparation_animation\|_create_preview_unit\|start_deployment" /Users/mzhao/workdir/feh/godot/scripts/battle/BattleManager.gd
```
Expected: no definitions

- [ ] **Step 6: Commit**

```bash
git add godot/scripts/battle/BattleBackgroundManager.gd godot/scripts/battle/BattleDeploymentManager.gd godot/scripts/battle/BattleManager.gd godot/scenes/battle/BattleScene.tscn
git commit -m "refactor: extract BattleBackgroundManager and BattleDeploymentManager"
```

---

## Task 8: Split BattleManager — Unit Factory and Status Panel

**Files:**
- Create: `godot/scripts/battle/BattleUnitFactory.gd`
- Create: `godot/scripts/battle/BattleStatusPanel.gd`
- Modify: `godot/scripts/battle/BattleManager.gd`
- Modify: `godot/scenes/battle/BattleScene.tscn`

- [ ] **Step 1: Create BattleUnitFactory.gd**

Move:
- `_create_default_enemy()`
- `create_battle_unit()`
- Helper unit creation logic

Expose:
```gdscript
func create_player_units(player_army: Array, parent: Node2D) -> Array[BattleUnit]
func create_enemy_units(enemy_army: Array, parent: Node2D) -> Array[BattleUnit]
```

- [ ] **Step 2: Create BattleStatusPanel.gd**

Move:
- `_create_unit_status_entry()`
- `_get_face_texture_path()`
- `update_unit_status()`
- `_cleanup_status_entries()`
- `player_status_entries`, `enemy_status_entries`

- [ ] **Step 3: Update BattleManager**

Use `$BattleUnitFactory` and `$BattleStatusPanel`.

- [ ] **Step 4: Add child nodes to BattleScene.tscn**

- [ ] **Step 5: Static validation**

```bash
grep -n "_create_default_enemy\|create_battle_unit\|_create_unit_status_entry\|_cleanup_status_entries" /Users/mzhao/workdir/feh/godot/scripts/battle/BattleManager.gd
```
Expected: no definitions

- [ ] **Step 6: Commit**

```bash
git add godot/scripts/battle/BattleUnitFactory.gd godot/scripts/battle/BattleStatusPanel.gd godot/scripts/battle/BattleManager.gd godot/scenes/battle/BattleScene.tscn
git commit -m "refactor: extract BattleUnitFactory and BattleStatusPanel"
```

---

## Task 9: Split BattleManager — Turn Manager

**Files:**
- Create: `godot/scripts/battle/BattleTurnManager.gd`
- Modify: `godot/scripts/battle/BattleManager.gd`
- Modify: `godot/scenes/battle/BattleScene.tscn`

- [ ] **Step 1: Create BattleTurnManager.gd**

Move:
- `start_combat_round()`
- `check_victory()`
- `end_battle()`

Expose signals:
```gdscript
signal battle_finished(victory: bool)
signal turn_started(turn_number: int)
signal unit_acted(unit: BattleUnit)
```

- [ ] **Step 2: Update BattleManager**

Delegate turn loop. Connect `battle_finished` to emit its own `battle_finished`.

- [ ] **Step 3: Add child node to BattleScene.tscn**

- [ ] **Step 4: Static validation**

```bash
grep -n "start_combat_round\|check_victory\|func end_battle" /Users/mzhao/workdir/feh/godot/scripts/battle/BattleManager.gd
```
Expected: no definitions

- [ ] **Step 5: Commit**

```bash
git add godot/scripts/battle/BattleTurnManager.gd godot/scripts/battle/BattleManager.gd godot/scenes/battle/BattleScene.tscn
git commit -m "refactor: extract BattleTurnManager"
```

---

## Task 10: Split BattleUnit — Tactics, Combat, Movement

**Files:**
- Create: `godot/scripts/battle/BattleUnitTactics.gd`
- Create: `godot/scripts/battle/BattleUnitCombat.gd`
- Create: `godot/scripts/battle/BattleUnitMovement.gd`
- Modify: `godot/scripts/battle/BattleUnit.gd`
- Modify: `godot/scenes/battle/BattleUnit.tscn`

- [ ] **Step 1: Create BattleUnitTactics.gd**

Move:
- `execute_tactics()`
- `execute_action()`
- `find_nearest_target()`

- [ ] **Step 2: Create BattleUnitCombat.gd**

Move:
- `perform_attack()`
- `calculate_damage()`
- `get_weapon_triangle_bonus()`
- `count_adjacent_allies()`
- `take_damage()`

- [ ] **Step 3: Create BattleUnitMovement.gd**

Move:
- `_perform_melee_attack_sequence()`

- [ ] **Step 4: Update BattleUnit.gd**

Keep:
- `character_data`, `battle_position`, `is_player_unit`
- `time_bar`, `max_time_bar`, `is_ready`
- `setup()`, `update_time_bar()`, `enter_ready_state()`

`process_turn()` becomes:
```gdscript
func process_turn(all_enemy_units: Array, all_ally_units: Array):
    if character_data.is_defeated():
        return
    await _wait_until_ready()
    if character_data.is_defeated():
        return
    await $BattleUnitTactics.execute_tactics(all_enemy_units, all_ally_units)
```

- [ ] **Step 5: Add child nodes to BattleUnit.tscn**

Add `BattleUnitTactics`, `BattleUnitCombat`, `BattleUnitMovement` children.

- [ ] **Step 6: Static validation**

```bash
grep -n "func execute_tactics\|func execute_action\|func perform_attack\|func calculate_damage\|func _perform_melee_attack_sequence" /Users/mzhao/workdir/feh/godot/scripts/battle/BattleUnit.gd
```
Expected: no definitions

- [ ] **Step 7: Commit**

```bash
git add godot/scripts/battle/BattleUnitTactics.gd godot/scripts/battle/BattleUnitCombat.gd godot/scripts/battle/BattleUnitMovement.gd godot/scripts/battle/BattleUnit.gd godot/scenes/battle/BattleUnit.tscn
git commit -m "refactor: split BattleUnit into tactics, combat, movement"
```

---

## Task 11: Split SquadMenu

**Files:**
- Create: `godot/scripts/ui/SquadMenuData.gd`
- Create: `godot/scripts/ui/SquadMenuLists.gd`
- Create: `godot/scripts/ui/SquadMenuActions.gd`
- Modify: `godot/scripts/ui/SquadMenu.gd`
- Modify: `godot/scenes/ui/SquadMenu.tscn`

- [ ] **Step 1: Create SquadMenuData.gd**

Move:
- `squads`, `unassigned`
- `_load_squad_data()`
- `_initialize_from_player_army()`
- `_move_character_to_squad()`
- `_on_remove_from_squad()`
- `_remove_from_current()`
- `get_active_squads()`
- `get_squad_characters()`
- Validation helpers

- [ ] **Step 2: Create SquadMenuLists.gd**

Move:
- Node discovery (`_initialize_nodes()`)
- Signal connections for list selections (`_connect_signals()`)
- `_refresh_lists()`, `_refresh_squad_list()`, `_refresh_unassigned_list()`
- Selection handlers (`_on_squad1_selected`, etc.)
- `_clear_other_selections()`

- [ ] **Step 3: Create SquadMenuActions.gd**

Move:
- `_on_move_to_squad1/2/3`
- `_on_save()`
- `_on_cancel()`
- `_update_character_info()`
- `_set_info_text()`

- [ ] **Step 4: Update SquadMenu.gd**

Keep:
- `open_menu()`
- `get_active_squads()`
- `get_squad_characters()`
- `menu_closed` signal

Remove:
- `_update_player_army_order()` (unused)
- `_deferred_open()` retry logic if no longer needed

- [ ] **Step 5: Add child nodes to SquadMenu.tscn**

- [ ] **Step 6: Static validation**

```bash
grep -n "func _load_squad_data\|func _refresh_lists\|func _on_move_to_squad\|func _update_character_info" /Users/mzhao/workdir/feh/godot/scripts/ui/SquadMenu.gd
```
Expected: only root-level wrappers or no definitions

- [ ] **Step 7: Commit**

```bash
git add godot/scripts/ui/SquadMenuData.gd godot/scripts/ui/SquadMenuLists.gd godot/scripts/ui/SquadMenuActions.gd godot/scripts/ui/SquadMenu.gd godot/scenes/ui/SquadMenu.tscn
git commit -m "refactor: split SquadMenu into data, lists, actions"
```

---

## Task 12: Cross-Cut Cleanup

**Files:**
- Modify: `godot/scripts/world_map/WorldMapManager.gd`
- Modify: `godot/scripts/world_map/Army.gd`
- Modify: `godot/scripts/autoload/GameManager.gd`
- Modify: `godot/scripts/ui/SquadMenu.gd`
- Delete: `godot/scripts/Character.gd`

- [ ] **Step 1: Remove debug prints**

Run:
```bash
grep -R 'print("DEBUG' /Users/mzhao/workdir/feh/godot/scripts/ | wc -l
```

Then remove all `print("DEBUG: ...")` lines across the modified files. Keep error prints.

- [ ] **Step 2: Remove empty stubs and unused code**

- Delete `WorldMapManager._on_city_closed()` (empty)
- Delete `SquadMenu._update_player_army_order()` (unused)
- Delete `scripts/Character.gd` (duplicate)
- Remove unused retry logic from `SquadMenu` if `_initialized` is reliable after split

- [ ] **Step 3: Fix indentation in GameManager.gd**

Convert spaces to tabs in `GameManager.gd` to match the rest of the project.

- [ ] **Step 4: Clean up Army.gd execute_move**

Either implement `execute_move()` or remove it if `WorldMapManager` no longer calls it.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "chore: remove debug prints, dead code, and duplicate Character.gd"
```

---

## Task 13: Final Static Validation

**Files:**
- All modified `.gd` and `.tscn` files

- [ ] **Step 1: Check for broken class_name references**

Run:
```bash
grep -R "WorldMapManager\.\|BattleManager\.\|BattleUnit\.\|SquadMenu\." /Users/mzhao/workdir/feh/godot/scripts/ | grep -v "class_name"
```
Expected: only legitimate references; no calls to methods that were moved to children

- [ ] **Step 2: Check for moved methods still on root classes**

Run:
```bash
grep -n "func _create_player_armies\|func _execute_next_move\|func start_combat_round\|func perform_attack\|func _refresh_lists" /Users/mzhao/workdir/feh/godot/scripts/world_map/WorldMapManager.gd /Users/mzhao/workdir/feh/godot/scripts/battle/BattleManager.gd /Users/mzhao/workdir/feh/godot/scripts/battle/BattleUnit.gd /Users/mzhao/workdir/feh/godot/scripts/ui/SquadMenu.gd
```
Expected: no matches

- [ ] **Step 3: Verify node paths in scenes**

Open each modified `.tscn` and confirm child nodes have the expected names and script paths.

- [ ] **Step 4: Final commit**

```bash
git add -A
git commit -m "refactor: complete code split for readability"
```

---

## Spec Coverage Check

| Spec section | Tasks |
|-------------|-------|
| CharacterDatabase extraction | Task 2 |
| WorldMapManager split | Tasks 3–6 |
| BattleManager split | Tasks 7–9 |
| BattleUnit split | Task 10 |
| SquadMenu split | Task 11 |
| Cleanup | Task 12 |
| Static validation | Task 13 |

No placeholders. Every step names exact files and concrete actions.
