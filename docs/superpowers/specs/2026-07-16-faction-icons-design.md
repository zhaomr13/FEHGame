# Faction Icons Design

## Summary

Use the three new UI assets `res://assets/ui/fraction1.png`, `fraction2.png`, `fraction3.png` as faction icons across the game UI, and add a fourth copy `fraction4.png` for the non-playable `muspell` faction. Map node markers are intentionally left unchanged for this iteration.

## Faction-to-Icon Mapping

| Faction | Icon File |
|---------|-----------|
| `askr`   | `res://assets/ui/fraction1.png` |
| `embla`  | `res://assets/ui/fraction2.png` |
| `nifl`   | `res://assets/ui/fraction3.png` |
| `muspell`| `res://assets/ui/fraction4.png` (copy of `fraction3.png`) |

## Data Model

Add a centralized icon lookup to `scripts/utils/Constants.gd`:

```gdscript
const FACTION_ICONS = {
    "askr": preload("res://assets/ui/fraction1.png"),
    "embla": preload("res://assets/ui/fraction2.png"),
    "nifl": preload("res://assets/ui/fraction3.png"),
    "muspell": preload("res://assets/ui/fraction4.png")
}

static func get_faction_icon(faction: String) -> Texture2D:
    return FACTION_ICONS.get(faction, null)
```

A missing or empty faction returns `null`; callers must handle that gracefully.

## UI Placement

### 1. Faction Select (`scenes/ui/FactionSelect.tscn` + `scripts/ui/FactionSelect.gd`)

- Add a `TextureRect` to each faction card, centered at the top.
- Target size: 64×64.
- Keep the original faction color on the card border/background as a secondary visual cue.
- Icon is not modulated; displayed in its original colors.

### 2. World-Map Armies (`scripts/world_map/Army.gd`)

- Replace the `CirclePanel` (32×32 solid circle) with a `Sprite2D` showing the faction icon.
- Target icon size: 40×40.
- Keep the semi-transparent black border ring and the yellow selection indicator.
- Update the transparent `ClickButton` to match the new 40×40 icon size.
- Reuse `update_visibility()` so the icon hides when the army is garrisoned in a city.

### 3. Battle Encounter Banner (`scenes/ui/BattleEncounterBanner.tscn` + `scripts/ui/BattleEncounterBanner.gd`)

- Add faction icons next to the encounter title.
- Attacker icon on the left, defender icon on the right.
- Target size: 48×48.
- Keep the existing `AttackerColor` / `DefenderColor` color rects, possibly resized as icon backplates.

### 4. City Menu (`scenes/ui/CityMenu.tscn` + `scripts/ui/CityMenu.gd`)

- Add a 32×32 faction icon to the left of the city name title.
- Extend `show_city(...)` to accept the city's current faction string.
- `WorldMapManager.open_city_menu()` passes `node.current_faction` when opening the menu.

### 5. World-Map HUD (`scripts/Main.gd`)

- Display the current player faction icon (40×40) near the top-left event log panel.
- Update the icon in `setup_faction_start()` and `_on_state_changed()` when entering the world map.

## Out of Scope

- Map node markers (`MapNode`) remain unchanged for this iteration.
- No changes to faction colors; they remain as defined in `FactionSelect.gd` and `MapNode.gd`.
- No new animations; icons appear/disappear with existing UI visibility logic.

## Asset Changes

- Copy `godot/assets/ui/fraction3.png` to `godot/assets/ui/fraction4.png` for `muspell`.

## Edge Cases

- If a faction has no icon entry, `get_faction_icon()` returns `null` and the UI simply omits the icon.
- Neutral/empty faction (`""`) returns `null` and shows no icon.
- Missing texture files will fail at `preload` time during development; the centralized dictionary makes this easy to spot.

## Testing / Verification

1. Start the game and open the faction select screen; each faction card shows its icon.
2. Enter the world map; the HUD shows the chosen faction icon.
3. Open a player-owned city; the city menu title shows the faction icon.
4. Trigger a battle encounter; the banner shows attacker/defender icons.
5. Select an army on the map; the army marker displays the faction icon instead of a solid circle.
6. Move an army into a city; the army icon hides along with the rest of the army body.
