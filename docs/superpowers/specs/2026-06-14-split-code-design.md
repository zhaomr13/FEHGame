# Split Code for Readability — Design

## Summary

Split four oversized Godot GDScript files into smaller, focused components using Godot's node-composition model. The refactor includes aggressive cleanup: removing dead code, redundant debug prints, unused signals, and duplicated files.

## Scope

### Scripts to split

| File | Lines | Main responsibilities |
|------|-------|----------------------|
| `scripts/world_map/WorldMapManager.gd` | 645 | Map setup, army lifecycle, planning phase, execution phase, battle results |
| `scripts/ui/SquadMenu.gd` | 472 | UI init, list rendering, selection, character moves, save/cancel |
| `scripts/battle/BattleManager.gd` | 400 | Deployment, unit creation, status panels, turn loop, victory checks |
| `scripts/battle/BattleUnit.gd` | 310 | Time bar, tactics, targeting, melee/ranged attacks, damage |

### New files

```
godot/
├── scripts/
│   ├── autoload/
│   │   └── CharacterDatabase.gd
│   ├── world_map/
│   │   ├── MapDataManager.gd
│   │   ├── WorldMapArmyManager.gd
│   │   ├── PlanningPhaseController.gd
│   │   └── ExecutionPhaseController.gd
│   ├── battle/
│   │   ├── BattleBackgroundManager.gd
│   │   ├── BattleDeploymentManager.gd
│   │   ├── BattleUnitFactory.gd
│   │   ├── BattleStatusPanel.gd
│   │   ├── BattleTurnManager.gd
│   │   ├── BattleUnitTactics.gd
│   │   ├── BattleUnitCombat.gd
│   │   └── BattleUnitMovement.gd
│   └── ui/
│       ├── SquadMenuData.gd
│       ├── SquadMenuLists.gd
│       └── SquadMenuActions.gd
```

## Approach

Use **node/component split (Approach B)**: add child nodes to existing scenes, move focused responsibilities onto those children, and keep the original root scripts as thin coordinators.

This aligns with Godot's composition model and gives each file a single reason to change.

## World Map

### Scene changes

`WorldMap.tscn` root `WorldMapManager` gets child nodes:

- `MapDataManager`
- `WorldMapArmyManager`
- `PlanningPhaseController`
- `ExecutionPhaseController`

### Responsibilities

`WorldMapManager` (coordinator)
- Owns `current_phase`, `current_faction`, `turn_count`
- High-level flow: `setup_faction_start()`, `_start_planning_phase()`
- Battle result handler (`_on_battle_ended`)
- Delegates signals between children

`MapDataManager`
- Owns `NODE_CONFIG`, `map_nodes`, `connections`
- `create_map_nodes()`, `draw_connections()`
- `get_city_position(city_id)`, `can_move_to(from, to)`, `find_path(from, to)`
- `select_battle_background(node)`

`WorldMapArmyManager`
- Owns `player_armies`, `enemy_armies`, `selected_army`
- `_create_player_armies_from_squads()`, `_create_enemy_armies()`
- `_set_selected_army()`, `_get_army_at_position()`
- `_refresh_player_armies()`, `_clear_armies()`
- Emits `army_selected`, `enemy_targeted`

`PlanningPhaseController`
- Handles input during planning
- `_on_army_clicked()`, `_on_node_clicked()`
- Drag attack line logic
- City / squad menu opening
- Owns the dynamically built planning UI

`ExecutionPhaseController`
- Runs the execution queue
- `_start_execution_phase()`, `_execute_next_move()`
- `_wait_for_move_complete()`, `_check_encounter()`
- Enemy AI plan generation (`_process_enemy_turn`)

## Battle

### Scene changes

`BattleScene.tscn` root `BattleManager` gets child nodes:

- `BattleBackgroundManager`
- `BattleDeploymentManager`
- `BattleUnitFactory`
- `BattleStatusPanel`
- `BattleTurnManager`

`BattleUnit.tscn` root `BattleUnit` gets child nodes:

- `BattleUnitTactics`
- `BattleUnitCombat`
- `BattleUnitMovement`

### Responsibilities

`BattleManager` (coordinator)
- Listens to `GameManager.battle_started_with_background`
- Wires children together
- Emits `battle_finished`

`BattleBackgroundManager`
- Owns `BATTLE_BACKGROUNDS` and `set_background(type)`

`BattleDeploymentManager`
- `start_deployment()`, `_play_preparation_animation()`
- `_on_deployment_confirmed()`

`BattleUnitFactory`
- `create_battle_unit()`, `_create_preview_unit()`, `_create_default_enemy()`
- Returns `BattleUnit` instances and adds them to formations

`BattleStatusPanel`
- `_create_unit_status_entry()`, `update_unit_status()`, `_cleanup_status_entries()`
- Knows `player_status_panel` and `enemy_status_panel` UI nodes

`BattleTurnManager`
- `start_combat_round()`, `check_victory()`, `end_battle()`

`BattleUnit` (coordinator)
- `character_data`, `battle_position`, `is_player_unit`
- `time_bar`, `is_ready`, `update_time_bar()`, `enter_ready_state()`
- `setup()` and sprite wiring
- `process_turn()` delegates to children

`BattleUnitTactics`
- `execute_tactics()`, `execute_action()`, `find_nearest_target()`

`BattleUnitCombat`
- `perform_attack()`, `calculate_damage()`, `get_weapon_triangle_bonus()`, `take_damage()`

`BattleUnitMovement`
- `_perform_melee_attack_sequence()`

## Squad Menu

### Scene changes

`SquadMenu.tscn` keeps the same scene tree; the root script becomes a coordinator and three child nodes receive the logic:

- `SquadMenuData`
- `SquadMenuLists`
- `SquadMenuActions`

### Responsibilities

`SquadMenu` (coordinator)
- `open_menu()`, `get_active_squads()`, `get_squad_characters()`
- Emits `menu_closed`

`SquadMenuData`
- Owns `squads`, `unassigned`
- `_load_squad_data()`, `_initialize_from_player_army()`
- `_move_character_to_squad()`, `_on_remove_from_squad()`, `_remove_from_current()`
- Validation helpers (`is_squad_full`, `get_active_squads`)

`SquadMenuLists`
- `_initialize_nodes()` (node discovery)
- `_connect_signals()` for list selections
- `_refresh_lists()`, `_refresh_squad_list()`, `_refresh_unassigned_list()`
- Selection handlers (`_on_squad1_selected`, etc.)

`SquadMenuActions`
- `_on_move_to_squad1/2/3`, `_on_save`, `_on_cancel`
- `_update_character_info()`, `_set_info_text()`

## GameManager

Extract a new autoload `CharacterDatabase.gd`:

- Move `_initialize_all_characters()` and `_create_character()`
- Move `get_characters_by_faction()` and `get_characters_not_in_faction()`

`GameManager` keeps:
- State management
- Squad data
- Battle signals

## Cleanup

- Remove redundant `print("DEBUG: ...")` statements; keep error prints.
- Remove unused signals and empty stubs (`_on_city_closed`).
- Delete duplicate `scripts/Character.gd` (keep `scripts/character/Character.gd`).
- Remove unused `_update_player_army_order()` from `SquadMenu`.
- Fix mixed tab/space indentation in `GameManager.gd`.
- Delete or implement the empty `execute_move()` body in `Army.gd`.
- Use typed arrays where GDScript allows (`Array[CharacterData]`).

## Migration strategy

1. Create new files first, then update root scripts to delegate.
2. Keep old method signatures on root scripts as thin wrappers during the transition.
3. Remove wrappers only after verifying all internal references point to children.
4. Update `.tscn` files to add child nodes and attach new scripts.
5. Perform a static check for broken node paths or missing `class_name` references.

## Verification

No runtime verification requested. Validation will be static: confirm files compile, node paths resolve, and signals connect correctly.
