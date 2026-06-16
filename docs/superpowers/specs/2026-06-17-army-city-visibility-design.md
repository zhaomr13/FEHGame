# Design: Army City Visibility

## Summary

Armies currently remain visible on the world map even when stationed inside a city, making the map feel crowded. This design hides armies while they are garrisoned inside cities and reveals them only when they are marching between cities.

## Requirements

1. **Hide armies inside cities**: When an army's `current_city_id` is set and it is not moving, it should be invisible.
2. **Reveal armies on the march**: When the planning phase ends and an army begins moving, it becomes visible.
3. **Hide on arrival**: When an army reaches its destination city, it becomes invisible again.
4. **City-based selection**: Clicking a city selects the army inside it. If multiple armies are present, show a popup to choose one.
5. **Enemy parity**: Enemy armies follow the same visibility rules as player armies.

## Clarifications

- No visual indicator is shown for a city that contains hidden armies; the player discovers armies by clicking cities.
- If multiple player armies occupy the same city, a popup list lets the player pick which one to select.
- Existing route planning (click destination city while an army is selected) remains unchanged.

## Behavior Rules

### Visibility State

An army is visible when:
- It has no `current_city_id` (midpoint retreat / between cities), OR
- It is actively moving (`state == MOVING` or `state == PLANNED` during execution).

An army is hidden when:
- It has a non-empty `current_city_id` AND
- Its state is `IDLE` or `PLANNED` (planning phase only).

### City Click Handling

When the player clicks a city during planning:

1. If an army is already selected, behave as today: set a route to the clicked city.
2. If no army is selected:
   - Gather player armies whose `current_city_id` matches the clicked city.
   - If exactly one army is present, select it.
   - If multiple armies are present, open an army-selection popup.
   - If no armies are present, open the existing city menu.

### Phase Transitions

- **Planning -> Executing**: `_start_execution()` shows every army that has a plan before calling `execute_plan()`.
- **Executing -> Planning**: When all armies finish moving, they are already hidden by the arrival rule.

## Components

### `Army.gd`

Add a helper to update visibility based on state and city:

```gdscript
func update_visibility():
    if current_city_id != "" and state != ArmyState.MOVING:
        visible = false
    else:
        visible = true
```

Call `update_visibility()` in:
- `_ready()`
- `set_route()` (planning phase: army still garrisoned, remains hidden)
- `execute_plan()` (army starts moving: becomes visible)
- `_move_along_route()` when the route empties and `current_city_id` is set (army arrives: hide)
- `clear_plan()` (army cancels plan while garrisoned: hide)

### `WorldMapManager.gd`

- Add `_get_player_armies_at_city(city_id: String) -> Array[Army]`.
- Modify `_on_node_clicked()` to check for garrisoned armies before opening the city menu.
- Add `_show_army_selection_popup(armies: Array[Army], city_id: String)`.
- In `_start_execution()`, call `army.update_visibility()` for each army with a plan.

### New UI: `ArmySelectionPopup`

A small `Panel` + `VBoxContainer` + `ItemList` + `Cancel` button:
- Lists army names.
- Selecting an army sets `selected_army` and closes the popup.
- Cancel closes the popup without selecting.

## Data Flow

```
Player clicks city
  |
  v
WorldMapManager._on_node_clicked(city)
  |
  +-- army selected? --> set route
  |
  +-- gather garrisoned player armies
        |
        +-- 1 army  --> select it
        +-- many    --> show ArmySelectionPopup
        +-- none    --> open CityMenu
```

## Edge Cases

- **Battle midpoint retreat**: Armies not at a city remain visible because `current_city_id` is empty.
- **Selected hidden army**: The selection indicator is hidden along with the army, but `selected_army` still references it. Clicking a destination city still works.
- **Enemy AI planning**: Enemy armies become visible when they start moving and hide when they arrive, same as player armies.
- **Multiple factions in one city**: Only player armies are selectable by clicking. Enemy armies are hidden but do not block city selection.

## Testing

- Update `test_world_map_scene.gd` or add a new test to verify:
  - Armies are hidden after `setup_faction_start` places them in cities.
  - Clicking a city with one army selects it.
  - Ending planning makes a routed army visible.
  - After movement finishes, the army is hidden again.

## Out of Scope

- Visual badges or counters on cities to indicate garrisoned armies.
- Limiting one army per city.
- Changing how encounters/battles are triggered.
