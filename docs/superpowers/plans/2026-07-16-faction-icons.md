# Faction Icons Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` (recommended) or `superpowers:executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add faction icons to the faction select screen, world-map armies, battle encounter banner, city menu, and world-map HUD, while leaving map node markers unchanged.

**Architecture:** Centralize the faction-to-texture mapping in `GameConstants.gd` so every UI component reads from one source. Each consumer creates its own `TextureRect`/`Sprite2D` and sizes it locally. `muspell` gets a fourth icon by copying `fraction3.png` to `fraction4.png`.

**Tech Stack:** Godot 4.6, GDScript, `TextureRect`, `Sprite2D`.

## Global Constraints

- All Godot commands run from the `godot/` directory.
- UI text remains in Chinese.
- Missing faction icon returns `null` and the UI omits the icon without crashing.
- Map node markers (`MapNode`) are **not** changed in this feature.
- Verification is manual by running the game: `cd godot && /Applications/Godot.app/Contents/MacOS/Godot`.

---

## File Structure

| File | Responsibility |
|------|----------------|
| `godot/assets/ui/fraction4.png` | New icon asset for `muspell` (copy of `fraction3.png`). |
| `godot/scripts/utils/Constants.gd` | Central `FACTION_ICONS` dictionary and `get_faction_icon()` helper. |
| `godot/scripts/ui/FactionSelect.gd` | Build faction cards with an icon `TextureRect` at the top. |
| `godot/scripts/world_map/Army.gd` | Replace the solid circle body with a faction icon `Sprite2D`. |
| `godot/scripts/ui/BattleEncounterBanner.gd` + `.tscn` | Show attacker/defender faction icons on the encounter banner. |
| `godot/scripts/ui/CityMenu.gd` + `.tscn` | Show the city owner's faction icon next to the city name. |
| `godot/scripts/world_map/WorldMapManager.gd` | Pass the city's current faction to `CityMenu.show_city()`. |
| `godot/scripts/Main.gd` | Show the current player faction icon in the world-map HUD. |

---

### Task 1: Create the `muspell` Icon Asset

**Files:**
- Create: `godot/assets/ui/fraction4.png`

**Interfaces:**
- Produces: `res://assets/ui/fraction4.png` must exist and be identical to `fraction3.png`.

- [ ] **Step 1: Copy the asset**

```bash
cp /Users/wave/workdir/Game/feh/godot/assets/ui/fraction3.png /Users/wave/workdir/Game/feh/godot/assets/ui/fraction4.png
```

- [ ] **Step 2: Verify the file exists**

```bash
ls -l /Users/wave/workdir/Game/feh/godot/assets/ui/fraction4.png
```

Expected: file exists and has the same size as `fraction3.png`.

- [ ] **Step 3: Stage the asset**

```bash
cd /Users/wave/workdir/Game/feh
git add godot/assets/ui/fraction4.png
```

---

### Task 2: Add Centralized Faction Icon Lookup

**Files:**
- Modify: `godot/scripts/utils/Constants.gd`

**Interfaces:**
- Produces: `GameConstants.FACTION_ICONS: Dictionary`
- Produces: `GameConstants.get_faction_icon(faction: String) -> Texture2D`

- [ ] **Step 1: Add the icon dictionary and helper after the existing constants**

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

Insert this block at the end of `Constants.gd`, after the existing `ARMIES_PER_FACTION` constant.

- [ ] **Step 2: Run the project to confirm `preload` succeeds**

```bash
cd /Users/wave/workdir/Game/feh/godot
/Applications/Godot.app/Contents/MacOS/Godot --editor
```

Expected: editor opens with no resource load errors in the Output panel.

- [ ] **Step 3: Commit**

```bash
cd /Users/wave/workdir/Game/feh
git add godot/scripts/utils/Constants.gd
git commit -m "feat: add centralized faction icon lookup

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

### Task 3: Show Icons in the Faction Select Screen

**Files:**
- Modify: `godot/scripts/ui/FactionSelect.gd`

**Interfaces:**
- Consumes: `GameConstants.get_faction_icon(faction_id)`

- [ ] **Step 1: Add icon texture to each faction card**

In `create_faction_buttons()`, after creating the inner `vbox`, add a `TextureRect` before the name label:

```gdscript
# Faction icon
var icon_texture = GameConstants.get_faction_icon(faction_id)
if icon_texture:
    var icon = TextureRect.new()
    icon.texture = icon_texture
    icon.custom_minimum_size = Vector2(64, 64)
    icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
    icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
    icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    vbox.add_child(icon)
```

Place this block immediately after `panel.add_child(vbox)` and before the name label is added.

- [ ] **Step 2: Run the game and open faction select**

```bash
cd /Users/wave/workdir/Game/feh/godot
/Applications/Godot.app/Contents/MacOS/Godot
```

Click “开始游戏” (or equivalent start button) to open the faction select screen.

Expected: each of the three faction cards shows its icon at the top.

- [ ] **Step 3: Commit**

```bash
cd /Users/wave/workdir/Game/feh
git add godot/scripts/ui/FactionSelect.gd
git commit -m "feat: show faction icons on faction select screen

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

### Task 4: Replace Army Circle with Faction Icon

**Files:**
- Modify: `godot/scripts/world_map/Army.gd`

**Interfaces:**
- Consumes: `GameConstants.get_faction_icon(faction)`
- The `Army.faction` string is already set by `WorldMapManager`.

- [ ] **Step 1: Replace the circle panel with a Sprite2D icon**

In `setup_visual()`, remove the `CirclePanel` creation block (the `Panel` named `"CirclePanel"`). Replace it with:

```gdscript
# Faction icon
var icon_sprite = Sprite2D.new()
icon_sprite.name = "FactionIcon"
var icon_texture = GameConstants.get_faction_icon(faction)
if icon_texture:
    icon_sprite.texture = icon_texture
    var target_size = 40.0
    var tex_size = icon_texture.get_size()
    icon_sprite.scale = Vector2(target_size / tex_size.x, target_size / tex_size.y)
add_child(icon_sprite)
```

- [ ] **Step 2: Update visibility logic to hide/show the icon with the army body**

Change the `update_visibility()` method so `"FactionIcon"` is included in the hidden list:

```gdscript
for child_name in ["FactionIcon", "BorderPanel", "Label", "ClickButton"]:
```

(Remove `"CirclePanel"` since it no longer exists.)

- [ ] **Step 3: Adjust the border ring size to match the icon**

Update the `BorderPanel` size from 36×36 to 44×44 and reposition it:

```gdscript
border.custom_minimum_size = Vector2(44, 44)
border.size = Vector2(44, 44)
border.position = Vector2(-22, -22)
border_style.corner_radius_top_left = 22
border_style.corner_radius_top_right = 22
border_style.corner_radius_bottom_left = 22
border_style.corner_radius_bottom_right = 22
```

- [ ] **Step 4: Adjust the click button to cover the new icon**

Update the `ClickButton` size and position:

```gdscript
btn.custom_minimum_size = Vector2(44, 44)
btn.size = Vector2(44, 44)
btn.position = Vector2(-22, -22)
```

- [ ] **Step 5: Run the game and select a faction**

Enter the world map and click an army.

Expected: the army marker displays the faction icon instead of a solid circle; the selection indicator still appears; moving the army works.

- [ ] **Step 6: Commit**

```bash
cd /Users/wave/workdir/Game/feh
git add godot/scripts/world_map/Army.gd
git commit -m "feat: replace army circle marker with faction icon

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

### Task 5: Add Icons to the Battle Encounter Banner

**Files:**
- Modify: `godot/scenes/ui/BattleEncounterBanner.tscn`
- Modify: `godot/scripts/ui/BattleEncounterBanner.gd`

**Interfaces:**
- Consumes: `GameConstants.get_faction_icon(faction)`
- `show_encounter(..., attacker_faction: String, defender_faction: String)` signature is unchanged.

- [ ] **Step 1: Add TextureRect nodes in the scene file**

Open `godot/scenes/ui/BattleEncounterBanner.tscn` and add two `TextureRect` children under `BannerPanel`:

```
[node name="AttackerIcon" type="TextureRect" parent="BannerPanel"]
layout_mode = 1
anchors_preset = 4
anchor_left = 0.0
anchor_top = 0.5
anchor_right = 0.0
anchor_bottom = 0.5
offset_left = 20.0
offset_top = 25.0
offset_right = 68.0
offset_bottom = 73.0
grow_horizontal = 0
grow_vertical = 2
expand_mode = 1
stretch_mode = 5

[node name="DefenderIcon" type="TextureRect" parent="BannerPanel"]
layout_mode = 1
anchors_preset = 4
anchor_left = 0.0
anchor_top = 0.5
anchor_right = 0.0
anchor_bottom = 0.5
offset_left = 1212.0
offset_top = 25.0
offset_right = 1260.0
offset_bottom = 73.0
grow_horizontal = 0
grow_vertical = 2
expand_mode = 1
stretch_mode = 5
```

- [ ] **Step 2: Update the script to set icon textures**

Add `@onready` references at the top of `BattleEncounterBanner.gd`:

```gdscript
@onready var attacker_icon: TextureRect = $BannerPanel/AttackerIcon
@onready var defender_icon: TextureRect = $BannerPanel/DefenderIcon
```

In `show_encounter()`, after setting the color rects, add:

```gdscript
if attacker_icon:
    attacker_icon.texture = GameConstants.get_faction_icon(attacker_faction)
if defender_icon:
    defender_icon.texture = GameConstants.get_faction_icon(defender_faction)
```

- [ ] **Step 3: Optionally shrink the color rects to sit behind the icons**

Change `AttackerColor` and `DefenderColor` offsets to 48×48 squares centered behind the icons, or remove them if the icons provide enough visual identity. For minimal change, leave them and just ensure they do not overlap the icon.

- [ ] **Step 4: Trigger an encounter and verify**

Start a new game, end planning so enemy armies move, and trigger a battle (or force one by moving a player army into an enemy city).

Expected: the encounter banner shows attacker and defender faction icons on the left and right.

- [ ] **Step 5: Commit**

```bash
cd /Users/wave/workdir/Game/feh
git add godot/scenes/ui/BattleEncounterBanner.tscn godot/scripts/ui/BattleEncounterBanner.gd
git commit -m "feat: show faction icons on battle encounter banner

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

### Task 6: Show Faction Icon in the City Menu

**Files:**
- Modify: `godot/scenes/ui/CityMenu.tscn`
- Modify: `godot/scripts/ui/CityMenu.gd`
- Modify: `godot/scripts/world_map/WorldMapManager.gd`

**Interfaces:**
- `CityMenu.show_city(city_name: String, city_type: int, is_current: bool = false, garrisoned_armies: Array[Army] = [], faction: String = "")`
- `WorldMapManager.open_city_menu(node: MapNode)` passes `node.current_faction`.

- [ ] **Step 1: Add an icon TextureRect to the title row in the scene**

Open `godot/scenes/ui/CityMenu.tscn`. The title label is currently `Panel/VBoxContainer/TitleLabel`. Add a `HBoxContainer` above it (or replace the title label with a horizontal container). For minimal disruption, add a `HBoxContainer` child to `VBoxContainer` and move `TitleLabel` into it, then add a `TextureRect` sibling:

```
[node name="TitleRow" type="HBoxContainer" parent="Panel/VBoxContainer"]
layout_mode = 2
alignment = 1
theme_override_constants/separation = 10

[node name="FactionIcon" type="TextureRect" parent="Panel/VBoxContainer/TitleRow"]
layout_mode = 2
custom_minimum_size = Vector2(32, 32)
expand_mode = 1
stretch_mode = 5

[node name="TitleLabel" type="Label" parent="Panel/VBoxContainer/TitleRow"]
layout_mode = 2
theme_override_font_sizes/font_size = 32
text = "城市"
horizontal_alignment = 1
```

Remove the original `TitleLabel` from `Panel/VBoxContainer` (it is now inside `TitleRow`).

- [ ] **Step 2: Update CityMenu.gd references and show_city signature**

Change:

```gdscript
@onready var title_label = $Panel/VBoxContainer/TitleLabel
```

to:

```gdscript
@onready var title_label = $Panel/VBoxContainer/TitleRow/TitleLabel
@onready var faction_icon = $Panel/VBoxContainer/TitleRow/FactionIcon
```

Change the `show_city` signature:

```gdscript
func show_city(city_name: String, city_type: int, is_current: bool = false, garrisoned_armies: Array[Army] = [], faction: String = ""):
```

At the top of `show_city()`, set the icon:

```gdscript
if faction_icon:
    faction_icon.texture = GameConstants.get_faction_icon(faction)
```

- [ ] **Step 3: Pass the faction from WorldMapManager**

In `WorldMapManager.open_city_menu()`:

```gdscript
city_menu.show_city(node.node_name, node.node_type, false, garrisoned, node.current_faction)
```

- [ ] **Step 4: Open a city and verify**

Run the game, enter the world map, and click a player-owned city.

Expected: the city menu title shows the faction icon to the left of the city name.

- [ ] **Step 5: Commit**

```bash
cd /Users/wave/workdir/Game/feh
git add godot/scenes/ui/CityMenu.tscn godot/scripts/ui/CityMenu.gd godot/scripts/world_map/WorldMapManager.gd
git commit -m "feat: show faction icon in city menu

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

### Task 7: Show Current Faction Icon in the World-Map HUD

**Files:**
- Modify: `godot/scripts/Main.gd`

**Interfaces:**
- Consumes: `GameConstants.get_faction_icon(faction)`
- The HUD is built dynamically in `_setup_event_log_panel()`.

- [ ] **Step 1: Add a faction icon TextureRect to the HUD**

In `_setup_event_log_panel()`, after creating `world_map_hud`, add:

```gdscript
var faction_icon = TextureRect.new()
faction_icon.name = "FactionIcon"
faction_icon.custom_minimum_size = Vector2(40, 40)
faction_icon.size = Vector2(40, 40)
faction_icon.position = Vector2(12, 4)
faction_icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
faction_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
faction_icon.texture = GameConstants.get_faction_icon(selected_faction)
world_map_hud.add_child(faction_icon)
```

- [ ] **Step 2: Update the icon when faction is selected**

In `_on_faction_selected()`, after setting `selected_faction = faction`, add:

```gdscript
if world_map_hud:
    var icon = world_map_hud.get_node_or_null("FactionIcon")
    if icon:
        icon.texture = GameConstants.get_faction_icon(faction)
```

- [ ] **Step 3: Run the game and verify**

Start a new game, select a faction, and enter the world map.

Expected: the top-left HUD shows the selected faction icon.

- [ ] **Step 4: Commit**

```bash
cd /Users/wave/workdir/Game/feh
git add godot/scripts/Main.gd
git commit -m "feat: show current faction icon in world-map HUD

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

### Task 8: Final Integration Verification

**Files:**
- All files above

- [ ] **Step 1: Run the full flow**

```bash
cd /Users/wave/workdir/Game/feh/godot
/Applications/Godot.app/Contents/MacOS/Godot
```

Verify each screen:

1. Faction select shows three icons.
2. World-map HUD shows the chosen faction icon.
3. Army markers show faction icons.
4. City menu shows the faction icon.
5. Battle encounter banner shows attacker/defender icons.
6. Map node markers remain unchanged.

- [ ] **Step 2: Check for runtime errors**

Watch the Output panel for missing resource or script errors. Fix any that appear.

- [ ] **Step 3: Final commit if any fixes were needed**

```bash
cd /Users/wave/workdir/Game/feh
git add -A
git commit -m "fix: address faction icon integration issues

Co-Authored-By: Claude <noreply@anthropic.com>"
```

If no fixes were needed, this task is complete once verification passes.

---

## Self-Review Checklist

- [x] **Spec coverage:** Every placement from the spec (faction select, army, battle banner, city menu, HUD) has a dedicated task.
- [x] **Map nodes unchanged:** Explicitly excluded in Task 8 verification.
- [x] **No placeholders:** Each step contains exact file paths, code, and verification commands.
- [x] **Type consistency:** `get_faction_icon(faction: String) -> Texture2D` is used consistently; `CityMenu.show_city` signature extension is backward-compatible.
- [x] **Asset handling:** `fraction4.png` creation is covered; missing icon returns `null` and UI omits it.
