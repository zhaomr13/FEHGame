# Phase Transition Design

**Date:** 2026-06-15
**Scope:** Define the planning/execution/battle phase flow for the Godot 4 strategy RPG world map.

---

## 1. Goals

- Provide a clear turn-based phase system: Planning → Execution → Battle → Planning.
- Ensure the world map transitions cleanly between phases without UI glitches or state corruption.
- Document the signal chain and state machine for army movement, execution tracking, and battle resolution.

## 2. Non-Goals

- Not changing the combat mechanics themselves (damage, formations, etc.).
- Not adding new map nodes or factions.
- Not implementing multiplayer or AI difficulty levels.

## 3. Phase Flow

```
[Planning Phase]
   Player clicks nodes to set routes
   AI plans moves
   Execute button visible
        |
        v
[Execution Phase]
   All armies move simultaneously
   Plan lines hidden
   Midpoint encounters trigger battles
        |
        v
[Battle Phase]
   Combat plays out
   Winner determined
        |
        v
[Return to Planning Phase]
   Turn increments
   Army states reset
   Planning UI shown
```

## 4. Army Movement Signal

`Army.gd` emits `movement_finished` when its route completes. This signal is consumed by `WorldMapManager.gd` to track which armies are still executing.

## 5. Execution Tracking

`WorldMapManager.gd` maintains a set of executing armies. When the last army finishes moving (or a battle ends execution), the manager automatically returns to the planning phase.

## 6. Battle Integration

Battles triggered during execution end the execution phase. After battle resolution:
- Army states are reset (position, route, etc.).
- The turn counter increments.
- The game returns to planning phase.

## 7. UI Feedback

- Planning buttons (Execute, etc.) are disabled outside the planning phase.
- An execution/battle status label shows the current phase.
- The status label lives outside `planning_ui` so it remains visible when planning UI is hidden.

## Implementation Status

Implemented in commits:
- `feat(army): emit movement_finished signal when route completes`
- `feat(world_map): track executing armies and auto-return to planning`
- `feat(world_map): battle ends execution and returns to planning with turn increment`
- `fix(world_map): reset army state after battle and document turn increment`
- `feat(ui): show execution/battle status and disable planning buttons outside planning`
- `fix(ui): move execution status label outside planning_ui so it displays correctly`
