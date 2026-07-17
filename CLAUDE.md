# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Godot 4.6 turn-based strategy RPG inspired by Fire Emblem Heroes and Romance of the Three Kingdoms. The UI is in Chinese. The Godot project lives under `godot/`; the repo root also contains Python tools and design docs.

Key design choices:

- **Static game data in YAML**: character roster (`godot/data/characters.yaml`) and world map (`godot/data/world_map.yaml`) are authored directly; runtime generators have been removed.
- **Army-Squad unification**: the concept of "squad" and "army" was merged. `GameManager.squad_data` is now the live army configuration; `Army` nodes on the world map are updated in place rather than destroyed and rebuilt when the player edits formations in a city.
- **Auto-battle**: combat is fully automated based on per-character tactics (condition/target/action priorities similar to *Unicorn Overlord*).

## Common Commands

All Godot commands are run from the `godot/` directory. On macOS the project uses the Godot editor binary at `/Applications/Godot.app/Contents/MacOS/Godot`.

Open the project in the Godot editor:

```bash
cd godot
/Applications/Godot.app/Contents/MacOS/Godot --editor
```

Run the game directly:

```bash
cd godot
/Applications/Godot.app/Contents/MacOS/Godot
```

### Tests

Headless test scripts live in `godot/tests/` (each extends `SceneTree` and prints a `PASSED` marker on success). Run the whole suite from the repo root:

```bash
tools/run_tests.sh            # GODOT_BIN and TEST_TIMEOUT env vars override defaults
```

The runner treats timeouts, script errors, and missing `PASSED` markers as failures. Note: a failing `assert()` in a test aborts the script before `quit()`, so the process hangs — never run a test without a timeout. There is no linter or CI configured yet.

### Data generation tools

If you need to regenerate the static databases:

```bash
# Regenerate characters.yaml (115 characters: 15 story + 100 deterministic generated)
python3 tools/generate_characters_yaml.py

# Convert world_map.json to world_map.yaml (legacy migration helper)
python3 tools/convert_world_map_to_yaml.py
```

Both scripts write into `godot/data/`.

## High-Level Architecture

### Scene and autoload layout

- `godot/project.godot` — main scene is `scenes/Main.tscn`; autoloads are `GameManager` and `SaveManager`.
- `scripts/Main.gd` — owns the top-level `WorldMap`, `BattleScene`, `MainMenu`, and `FactionSelect` nodes. It switches visibility based on `GameManager.state_changed` and handles faction selection / starting positions.
- `scripts/autoload/GameManager.gd` — global game state (current faction, `player_army`, `squad_data`/`unassigned_units`, all characters, available recruits, battle signals).
- `scripts/autoload/SaveManager.gd` — saves/loads `user://savegame.json` and `user://squads.json` (v2 dynamic-squad format).

### Game state

`scripts/utils/Constants.gd` defines `GameConstants.GameState` (MAIN_MENU, WORLD_MAP, BATTLE_DEPLOYMENT, BATTLE_ACTIVE, BATTLE_RESULT, GAME_OVER), `NodeType`, `CharacterClass`, `Formation`, and squad limits (`MAX_SQUADS = 20`, `MAX_SQUAD_SIZE = 6`, `ARMIES_PER_FACTION = 10`).

### World map

- `scripts/world_map/MapDataManager.gd` loads `res://data/world_map.yaml` via `YamlParser`, builds a node graph, auto-generates connections, validates connectivity/overlap, and creates `MapNode` instances.
- `scripts/world_map/WorldMapManager.gd` drives the world-map loop:
  - **Planning phase**: player selects armies, sets routes by clicking connected cities, and edits garrisons through `ArmyManagePanel`.
  - **Execution phase**: AI plans moves, all armies move along their routes, and hostile armies that share a city or collide on the same road segment trigger battle.
  - **Battle phase**: pauses movement, emits battle signal, then returns to planning after `GameManager.battle_ended`.
- `scripts/world_map/Army.gd` — runtime army node. Tracks `squad_data`, `squad_index` (index into `GameManager.squad_data`), current/target city, route following, and visual state. Armies in cities hide their body but keep the plan line visible.
- `scripts/world_map/GameClock.gd` — drives the execution-phase timer.

### Army management UI

- `scripts/ui/ArmyManagePanel.gd` / `scenes/ui/ArmyManagePanel.tscn` — replaces the older SquadMenu. Opened from a city menu. Allows creating, splitting, moving, and disbanding armies at the current city. On save, `WorldMapManager._sync_armies_in_place` updates existing `Army` nodes and creates/removes them without resetting the whole map.
- `scripts/ui/CityMenu.gd` — city actions including the "编队" (formation) button.

### Battle system

Battle is split across several component scripts under `scripts/battle/`:

- `BattleManager.gd` — top-level coordinator. Listens to `GameManager.battle_started_with_background`, creates units via `BattleUnitFactory`, and starts `BattleTurnManager`.
- `BattleTurnManager.gd` — runs combat rounds, iterates units by speed, awaits each unit's turn, and checks victory.
- `BattleUnit.gd` — per-unit node with `Character` sub-node. Holds `character_data`, position, and readiness state.
- `BattleUnitTactics.gd` — evaluates the character's tactic list in priority order and executes the first matching condition.
- `BattleUnitCombat.gd` — damage calculation, weapon triangle, attack animations, and death handling.
- `BattleUnitMovement.gd` / `BattleUnitFactory.gd` / `BattleDeploymentManager.gd` / `BattleStatusPanel.gd` / `BattleBackgroundManager.gd` — movement helpers, unit instantiation, deployment UI, status UI, and background selection.

Combat is automatic; the player does not control individual actions.

### Characters and data

- `scripts/character/CharacterData.gd` — `Resource` class with stats, soldiers, weapon type, skills, and tactics.
- `scripts/character/CharacterDatabase.gd` — loads `res://data/characters.yaml` into `CharacterData` instances at runtime.
- `scripts/character/Tactic.gd` / `SkillData.gd` — tactic condition/target/action enums and skill data.
- `scripts/character/Character.gd` — visual wrapper that sets up an `AnimatedSprite2D` from a loaded atlas.
- `scripts/AtlasLoader.gd` — loads per-animation atlases (`Idle.png` + `Idle.json`, etc.) from `res://assets/characters/<folder>/` and caches `SpriteFrames`.

### YAML parser

`scripts/utils/YamlParser.gd` is a lightweight custom parser supporting a restricted subset: comments, block lists/dicts, indentation, and scalars. It does **not** support anchors, multi-line strings, or flow style. Both `characters.yaml` and `world_map.yaml` must stay within this subset.

## Important File Paths

| Path | Purpose |
|------|---------|
| `godot/project.godot` | Godot project config, autoloads, input map |
| `godot/data/characters.yaml` | 115-character roster |
| `godot/data/world_map.yaml` | ~80 node map with positions, factions, and connection overrides |
| `godot/assets/characters/` | Per-animation sprite atlases (`Idle.json/png`, `Attack1.json/png`, ...) |
| `godot/assets/battle/backgrounds/` | Battle background pairs (`*_bg.png`, `*_fg.png`) |
| `docs/superpowers/specs/` | Recent design specs (e.g., army-squad unification, three-kingdoms map) |
| `tools/generate_characters_yaml.py` | Regenerate `characters.yaml` |
| `tools/convert_world_map_to_yaml.py` | Convert legacy `world_map.json` to YAML |

## Notes for Editing

- The UI text is Chinese; new labels, buttons, and log messages should generally remain in Chinese to match the existing game.
- `GameManager.squad_data` is an `Array` of `Array[CharacterData]` and is the source of truth for the player's army configuration. `Army.squad_index` maps an army node back to its slot.
- World-map node IDs follow the `city_NN` format. Faction starting positions are configured in `Main.gd` (`FACTION_START_POSITIONS`).
- When changing battle or world-map behavior, both `BattleManager`/`BattleTurnManager` and `WorldMapManager`/`Army` may need coordination because battle start/end signals cross the two top-level scenes.
