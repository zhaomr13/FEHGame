# Phase Transition Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Connect the world-map phases so that EXECUTING auto-returns to PLANNING when all armies finish moving, and BATTLE always returns to PLANNING when it ends.

**Architecture:** Event-driven tracking: `Army` emits `movement_finished` when its route empties; `WorldMapManager` maintains a set of armies still executing and transitions back to `PLANNING` when the set becomes empty. Battles immediately end execution and return to planning.

**Tech Stack:** Godot 4.4, GDScript, headless SceneTree tests

---

## File Structure

| File | Responsibility |
|------|----------------|
| `godot/scripts/world_map/Army.gd` | Emits `movement_finished` signal when route completes. |
| `godot/scripts/world_map/WorldMapManager.gd` | Tracks executing armies, handles phase transitions, turn counting, clock control, UI updates. |
| `godot/tests/test_phase_flow.gd` | Headless tests for movement completion signal and phase transitions. |

---

## Task 1: Add `movement_finished` signal to `Army.gd`

**Files:**
- Modify: `godot/scripts/world_map/Army.gd:14-18`

- [ ] **Step 1: Add the signal declaration**

Add the new signal below the existing `army_clicked` signal:

```gdscript
signal army_clicked(army: Army)
signal movement_finished(army: Army)
```

- [ ] **Step 2: Emit the signal when movement completes**

In `Army._move_along_route`, change the route-empty branch from:

```gdscript
if route.is_empty():
    state = ArmyState.IDLE
    label.text = army_name
```

to:

```gdscript
if route.is_empty():
    state = ArmyState.IDLE
    label.text = army_name
    movement_finished.emit(self)
```

- [ ] **Step 3: Commit**

```bash
cd /Users/wave/workdir/Game/feh
git add godot/scripts/world_map/Army.gd
git commit -m "feat(army): emit movement_finished signal when route completes"
```

---

## Task 2: Write the failing phase-flow test

**Files:**
- Create: `godot/tests/test_phase_flow.gd`

- [ ] **Step 1: Create the test file**

```gdscript
extends SceneTree

func _initialize():
    # Test 1: Army emits movement_finished when route completes
    var army_script = load("res://scripts/world_map/Army.gd")
    assert(army_script != null, "Failed to load Army script")

    var army = army_script.new()
    army.army_type = army.ArmyType.PLAYER_SQUAD
    army.army_name = "Test Army"
    army.position = Vector2.ZERO
    army.current_city_id = "city_1"
    root.add_child(army)

    var finished = false
    army.movement_finished.connect(func(a):
        finished = true
        assert(a == army, "movement_finished should pass the army")
    )

    army.set_route([Vector2(10, 0)], ["city_2"])
    army.execute_plan()

    # Simulate movement until done
    var max_frames = 600
    while army.state == army.ArmyState.MOVING and max_frames > 0:
        army._process(1.0 / 60.0)
        max_frames -= 1

    assert(army.state == army.ArmyState.IDLE, "Army should be IDLE after route completes")
    assert(finished, "Army should emit movement_finished")

    # Test 2: WorldMapManager transitions EXECUTING -> PLANNING when all armies finish
    var wm_script = load("res://scripts/world_map/WorldMapManager.gd")
    assert(wm_script != null, "Failed to load WorldMapManager script")

    var wm = wm_script.new()
    wm.name = "WorldMap"
    wm.map_data = load("res://scripts/world_map/MapDataManager.gd").new()
    wm.map_data.name = "MapDataManager"
    root.add_child(wm)
    root.add_child(wm.map_data)

    # Add an Armies container node
    var armies_node = Node2D.new()
    armies_node.name = "Armies"
    wm.add_child(armies_node)
    wm.army_mgr_node = armies_node

    # Inject required child references so _ready doesn't crash
    wm.ui = CanvasLayer.new()
    wm.ui.name = "WorldMapUI"
    wm.add_child(wm.ui)

    wm.background_sprite = Sprite2D.new()
    wm.background_sprite.name = "Background"
    wm.add_child(wm.background_sprite)

    wm.camera = Camera2D.new()
    wm.camera.name = "Camera2D"
    wm.add_child(wm.camera)

    wm.clock = load("res://scripts/world_map/GameClock.gd").new()
    wm.clock.name = "GameClock"
    wm.add_child(wm.clock)

    var turn_changed = false
    var final_turn = 0
    wm.phase_changed.connect(func(phase):
        if phase == wm.GamePhase.PLANNING:
            turn_changed = true
            final_turn = wm.turn_count
    )

    wm.current_phase = wm.GamePhase.PLANNING
    wm.current_faction = "askr"

    # Create a fake army with a short route
    var fake_army = army_script.new()
    fake_army.army_type = fake_army.ArmyType.PLAYER_SQUAD
    fake_army.army_name = "Mover"
    fake_army.position = Vector2.ZERO
    fake_army.current_city_id = "city_1"
    fake_army.set_route([Vector2(10, 0)], ["city_2"])
    wm.all_armies.append(fake_army)
    armies_node.add_child(fake_army)

    wm._start_execution()

    assert(wm.current_phase == wm.GamePhase.EXECUTING, "Phase should be EXECUTING after start")

    # Run movement to completion
    max_frames = 600
    while fake_army.state == fake_army.ArmyState.MOVING and max_frames > 0:
        fake_army._process(1.0 / 60.0)
        max_frames -= 1

    assert(fake_army.state == fake_army.ArmyState.IDLE, "Fake army should be IDLE")
    assert(wm.current_phase == wm.GamePhase.PLANNING, "Phase should return to PLANNING")
    assert(turn_changed, "phase_changed should fire for PLANNING")
    assert(final_turn == 1, "Turn count should be 1, got %d" % final_turn)
    assert(wm.clock.is_running == false, "Clock should stop when returning to planning")

    # Test 3: Battle ending returns to PLANNING and increments turn
    var wm2 = wm_script.new()
    wm2.name = "WorldMap2"
    wm2.current_phase = wm2.GamePhase.BATTLE
    wm2.turn_count = 0
    wm2.battling_armies = []
    wm2.selected_army = null
    wm2.all_armies = []
    wm2._on_battle_ended(true)
    assert(wm2.current_phase == wm2.GamePhase.PLANNING, "Phase should return to PLANNING after battle")
    assert(wm2.turn_count == 1, "Turn count should increment after battle, got %d" % wm2.turn_count)

    print("Phase flow test PASSED")
    quit(0)
```

- [ ] **Step 2: Run the test to verify it fails**

Run:

```bash
cd /Users/wave/workdir/Game/feh/godot
godot --headless --script res://tests/test_phase_flow.gd
```

Expected: FAIL with errors because `_executing_armies`, `_end_execution`, and `_on_army_movement_finished` do not exist in `WorldMapManager`.

- [ ] **Step 3: Commit the failing test**

```bash
cd /Users/wave/workdir/Game/feh
git add godot/tests/test_phase_flow.gd
git commit -m "test(phase): add failing phase transition test"
```

---

## Task 3: Implement execution tracking and auto-transition in `WorldMapManager.gd`

**Files:**
- Modify: `godot/scripts/world_map/WorldMapManager.gd:30-34`, `godot/scripts/world_map/WorldMapManager.gd:224-239`, `godot/scripts/world_map/WorldMapManager.gd:382-402`, `godot/scripts/world_map/WorldMapManager.gd:417-463`

- [ ] **Step 1: Add `_executing_armies` tracking set**

Add below the `battling_armies` declaration (around line 34):

```gdscript
var battling_armies: Array[Army] = []  # armies in current battle (for midpoint retreat)
var _executing_armies: Dictionary = {}  # armies still moving during EXECUTING phase
```

- [ ] **Step 2: Connect `movement_finished` when armies are created**

In `_create_army`, before returning the army, connect the signal:

```gdscript
func _create_army(chars: Array, start_city: String, type: Army.ArmyType = Army.ArmyType.PLAYER_SQUAD) -> Army:
    var army = Army.new()
    army.current_city_id = start_city
    army.squad_data = _convert_squad_data(chars)
    army.army_type = type
    army.movement_finished.connect(_on_army_movement_finished)
    army_mgr_node.add_child(army)
    if map_data.map_nodes.has(start_city):
        army.position = map_data.map_nodes[start_city].position + Vector2(20, -20)
    return army
```

- [ ] **Step 3: Implement `_start_execution` with tracking**

Replace the existing `_start_execution` function with:

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
            army.execute_plan()
            _executing_armies[army] = true
    if clock:
        clock.is_running = true
    if _executing_armies.is_empty():
        _end_execution()
```

- [ ] **Step 4: Implement `_on_army_movement_finished` and `_end_execution`**

Add these new functions after `_start_execution`:

```gdscript
func _on_army_movement_finished(army: Army):
    if not _executing_armies.has(army):
        return
    _executing_armies.erase(army)
    if current_phase == GamePhase.EXECUTING and _executing_armies.is_empty():
        _end_execution()

func _end_execution():
    if current_phase != GamePhase.EXECUTING:
        return
    current_phase = GamePhase.PLANNING
    phase_changed.emit(current_phase)
    if clock:
        clock.is_running = false
    if planning_ui:
        planning_ui.visible = true
    turn_count += 1
    _on_turn_started()

func _on_turn_started():
    turn_started.emit(turn_count)
```

- [ ] **Step 5: Add `turn_started` signal declaration**

Add near the top with the other signals:

```gdscript
signal phase_changed(new_phase: int)
signal turn_started(turn_number: int)
```

- [ ] **Step 6: Run the test**

```bash
cd /Users/wave/workdir/Game/feh/godot
godot --headless --script res://tests/test_phase_flow.gd
```

Expected: PASS with message "Phase flow test PASSED".

- [ ] **Step 7: Commit**

```bash
cd /Users/wave/workdir/Game/feh
git add godot/scripts/world_map/WorldMapManager.gd
git commit -m "feat(world_map): track executing armies and auto-return to planning"
```

---

## Task 4: Update battle transitions to remove armies from execution set

**Files:**
- Modify: `godot/scripts/world_map/WorldMapManager.gd:417-425`, `godot/scripts/world_map/WorldMapManager.gd:429-463`

- [ ] **Step 1: Update `_start_battle` to clear executing armies**

Replace `_start_battle` with:

```gdscript
func _start_battle(attacker: Army, defender: Army):
    current_phase = GamePhase.BATTLE
    phase_changed.emit(current_phase)
    _executing_armies.erase(attacker)
    _executing_armies.erase(defender)
    attacker.state = Army.ArmyState.IN_BATTLE
    defender.state = Army.ArmyState.IN_BATTLE
    battling_armies = [attacker, defender]
    var battle_bg = map_data.select_battle_background(map_data.map_nodes[attacker.current_city_id])
    GameManager.start_battle_with_background(attacker.squad_data, defender.squad_data, battle_bg)
```

- [ ] **Step 2: Update `_on_battle_ended` to increment turn and emit signal**

At the end of `_on_battle_ended`, after `battling_armies.clear()` and before `if planning_ui:`, add:

```gdscript
    battling_armies.clear()

    turn_count += 1
    _on_turn_started()
```

The final part of `_on_battle_ended` should look like:

```gdscript
    battling_armies.clear()

    turn_count += 1
    _on_turn_started()

    if planning_ui:
        planning_ui.visible = true
    GameManager.change_state(GameConstants.GameState.WORLD_MAP)
    visible = true
```

- [ ] **Step 3: Run the test**

```bash
cd /Users/wave/workdir/Game/feh/godot
godot --headless --script res://tests/test_phase_flow.gd
```

Expected: PASS.

- [ ] **Step 4: Commit**

```bash
cd /Users/wave/workdir/Game/feh
git add godot/scripts/world_map/WorldMapManager.gd
git commit -m "feat(world_map): battle ends execution and returns to planning with turn increment"
```

---

## Task 5: Add execution-phase UI feedback

**Files:**
- Modify: `godot/scripts/world_map/WorldMapManager.gd:332-366`

- [ ] **Step 1: Add an execution status label**

In `setup_planning_ui`, add a status label below the button container:

```gdscript
func setup_planning_ui():
    planning_ui = Control.new()
    planning_ui.name = "PlanningUI"

    var panel = Panel.new()
    panel.name = "Panel"
    panel.set_anchors_preset(Control.PRESET_TOP_WIDE)
    panel.custom_minimum_size = Vector2(0, 80)

    var hbox = HBoxContainer.new()
    hbox.name = "ButtonContainer"
    hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
    hbox.alignment = BoxContainer.ALIGNMENT_CENTER

    var end_planning_btn = Button.new()
    end_planning_btn.name = "EndPlanningButton"
    end_planning_btn.text = "End Planning Phase"
    end_planning_btn.custom_minimum_size = Vector2(200, 50)
    end_planning_btn.pressed.connect(_on_end_planning_pressed)

    var cancel_plan_btn = Button.new()
    cancel_plan_btn.name = "ClearPlansButton"
    cancel_plan_btn.text = "Clear All Plans"
    cancel_plan_btn.custom_minimum_size = Vector2(150, 50)
    cancel_plan_btn.pressed.connect(_on_clear_plans_pressed)

    hbox.add_child(end_planning_btn)
    hbox.add_child(cancel_plan_btn)
    panel.add_child(hbox)
    planning_ui.add_child(panel)
    planning_ui.visible = false

    var status_label = Label.new()
    status_label.name = "ExecutionStatusLabel"
    status_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
    status_label.position = Vector2(0, 90)
    status_label.custom_minimum_size = Vector2(400, 30)
    status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    status_label.visible = false
    ui.add_child(status_label)

    ui.add_child(planning_ui)
```

- [ ] **Step 2: Add `_update_planning_ui()` helper**

Add a helper function:

```gdscript
func _update_planning_ui():
    if not planning_ui:
        return
    var end_btn = planning_ui.get_node_or_null("Panel/ButtonContainer/EndPlanningButton")
    var clear_btn = planning_ui.get_node_or_null("Panel/ButtonContainer/ClearPlansButton")
    var status = ui.get_node_or_null("ExecutionStatusLabel")

    var is_planning = current_phase == GamePhase.PLANNING
    if end_btn:
        end_btn.disabled = not is_planning
    if clear_btn:
        clear_btn.disabled = not is_planning
    if status:
        status.visible = not is_planning
        if current_phase == GamePhase.EXECUTING:
            status.text = "Executing plans..."
        elif current_phase == GamePhase.BATTLE:
            status.text = "Battle in progress..."
```

- [ ] **Step 3: Call `_update_planning_ui` on phase changes**

Call `_update_planning_ui()` at the end of:
- `setup_faction_start`
- `_start_execution`
- `_end_execution`
- `_start_battle`
- `_on_battle_ended`

For example, in `_start_execution` after `if _executing_armies.is_empty(): _end_execution()`, add:

```gdscript
_update_planning_ui()
```

In `_end_execution` after `_on_turn_started()`, add:

```gdscript
_update_planning_ui()
```

In `_start_battle` after selecting battle background, add:

```gdscript
_update_planning_ui()
```

In `_on_battle_ended` after `turn_count += 1`, add:

```gdscript
_update_planning_ui()
```

In `setup_faction_start`, after `if planning_ui: planning_ui.visible = true`, add:

```gdscript
_update_planning_ui()
```

- [ ] **Step 4: Run the test**

```bash
cd /Users/wave/workdir/Game/feh/godot
godot --headless --script res://tests/test_phase_flow.gd
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
cd /Users/wave/workdir/Game/feh
git add godot/scripts/world_map/WorldMapManager.gd
git commit -m "feat(ui): show execution/battle status and disable planning buttons outside planning"
```

---

## Task 6: Run the full test suite

- [ ] **Step 1: Run the new phase-flow test**

```bash
cd /Users/wave/workdir/Game/feh/godot
godot --headless --script res://tests/test_phase_flow.gd
```

Expected output:

```
Phase flow test PASSED
```

- [ ] **Step 2: Run existing tests to ensure no regressions**

```bash
cd /Users/wave/workdir/Game/feh/godot
godot --headless --script res://tests/test_map_data.gd
godot --headless --script res://tests/test_world_map_scene.gd
```

Expected outputs:

```
Map data test PASSED: 80 nodes, fully connected, no overlaps
WorldMap scene integration test PASSED
```

- [ ] **Step 3: Commit the passing test suite state**

```bash
cd /Users/wave/workdir/Game/feh
git add godot/tests/test_phase_flow.gd
git commit -m "test(phase): phase transition tests pass"
```

---

## Task 7: Update documentation

**Files:**
- Modify: `docs/superpowers/specs/2026-06-15-phase-transition-design.md`

- [ ] **Step 1: Mark the spec as implemented**

Append to the bottom of the spec file:

```markdown
## Implementation Status

Implemented in commits:
- `feat(army): emit movement_finished signal when route completes`
- `test(phase): add failing phase transition test`
- `feat(world_map): track executing armies and auto-return to planning`
- `feat(world_map): battle ends execution and returns to planning with turn increment`
- `feat(ui): show execution/battle status and disable planning buttons outside planning`
- `test(phase): phase transition tests pass`
```

- [ ] **Step 2: Commit**

```bash
cd /Users/wave/workdir/Game/feh
git add docs/superpowers/specs/2026-06-15-phase-transition-design.md
git commit -m "docs: mark phase transition spec as implemented"
```

---

## Self-Review

### Spec Coverage

| Spec Section | Implementing Task |
|--------------|-------------------|
| Army `movement_finished` signal | Task 1 |
| `_executing_armies` tracking set | Task 3 |
| `_start_execution` populates set | Task 3 |
| `_on_army_movement_finished` → `_end_execution` | Task 3 |
| `_end_execution` stops clock, shows UI, increments turn | Task 3 |
| `_start_battle` removes armies from set | Task 4 |
| `_on_battle_ended` increments turn | Task 4 |
| `turn_started` signal | Task 3 |
| UI status label and button disabling | Task 5 |
| Edge cases (no plans, battle during execution) | Tasks 3, 4, tests |
| Tests | Task 2, Task 6 |

### Placeholder Scan

No placeholders remain. Every step contains:
- Exact file paths
- Complete code snippets
- Exact commands and expected output
- Commit commands

### Type Consistency

- `movement_finished(army: Army)` signal matches the connected `_on_army_movement_finished(army: Army)`.
- `_executing_armies` is consistently used as `{ Army: true }`.
- `turn_count` is incremented exactly once per return to `PLANNING`.
- `GamePhase` enum values are referenced consistently via `wm.GamePhase` in tests.

---

## Execution Handoff

**Plan complete and saved to `docs/superpowers/plans/2026-06-15-phase-transition.md`.**

Two execution options:

1. **Subagent-Driven (recommended)** — I dispatch a fresh subagent per task, review between tasks, fast iteration.
2. **Inline Execution** — Execute tasks in this session using `executing-plans`, batch execution with checkpoints.

Which approach would you like?
