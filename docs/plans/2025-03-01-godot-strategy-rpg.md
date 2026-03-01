# Godot Strategy RPG Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a turn-based strategy RPG with world map exploration and auto-battle combat system in Godot 4.

**Architecture:** Separate WorldMap and Battle scenes with GameManager autoload handling state transitions. Character animations use pre-exported PNG frames from ssbp_viewer converted to SpriteFrames.

**Tech Stack:** Godot 4.4, GDScript, SpriteFrames for animations, AsepriteWizard plugin for atlas import

---

## Current Progress

### ✅ Completed
- `godot/project.godot` - Updated with autoloads and input configuration
- `godot/scripts/utils/Constants.gd` - Game constants and enums
- `godot/scripts/autoload/GameManager.gd` - Game state management
- Directory structure created: scenes/{world_map,battle,character,common}, scripts/{autoload,world_map,battle,character,ui,utils}, assets/{characters,ui,world_map,battle}, resources/{characters,formations,skills}
- Existing fighter demo: `scripts/Character.gd`, `scripts/AtlasLoader.gd`, `scenes/Character.tscn`, `scenes/Main.tscn`

### ⏳ Remaining (13 Tasks)

**Phase 1 - Assets:**
1. ⏳ Export character animations (10 characters) - MANUAL STEP
2. ⏳ Copy background assets (battle + world map)
3. ⏳ Copy UI assets

**Phase 2 - Core Systems:**
4. ⏳ SaveManager autoload
5. ⏳ CharacterData resource
6. ⏳ SkillData resource
6b. ⏳ Tactic resource (Unicorn Overlord style)

**Phase 3 - Character:**
7. ⏳ Character scene for strategy RPG

**Phase 4 - World Map:**
8. ⏳ MapNode
9. ⏳ WorldMapManager (with background support)

**Phase 5 - Battle:**
10. ⏳ BattleUnit
11. ⏳ BattleManager (with background switching)

**Phase 6 - Integration:**
12. ⏳ Main scene integration

---

## PHASE 1: Asset Generation (REQUIRED FIRST)

Before any code implementation, we need to export 10 character animations and copy background assets.

### Available Asset Sources

**1. Character Animations (ssbp_viewer export)**
- Location: `ssbp_VV/sprites/` (340+ characters)
- Export tool: `ssbp_viewer` with `--wep-scale` support
- Atlas converter: `ssbp_to_godot_atlas.py`

**2. Battle Backgrounds (Ready to use)**
- Location: `ssbp_VV/FEH/Battle Backgrounds/`
- 116 different battle scenes
- Structure: `<Theme>/<images>/BG_*.png` (background) + `FG_*.png` (foreground)
- Recommended themes:
  - `001_BraveAttack` - 勇敢攻击场景
  - `001_BraveForest` - 森林场景
  - `001_BraveInside` - 室内场景
  - `002_Plain` - 平原场景
  - `002_PlainForest` - 平原森林
  - `002_PlainRiver` - 河流场景

**3. World Map Backgrounds (Ready to use)**
- Location: `ssbp_VV/FEH/Backgrounds/`
- Key files:
  - `Bg_Occupation.png` - 灰色地形，多岛屿
  - `Bg_SequentialMap.png` - 漩涡云层效果（太抽象，不推荐）
  - `Bg_Title.png` - 标题画面背景
  - `201805.png` - `201901.png` - 古典风格活动地图背景（**推荐**）

**推荐主地图：201805.png**
- 古典风格，符合三国群英传/圣兽之王史诗感
- 地形清晰：山脉、森林、平原层次分明
- 右下角有指南针方向指示
- 岛屿间路径连接自然

**城池（节点）布局方案（基于201805.png）：**

```
        [1] 北方要塞
         |
    [2]--[3]--[4]  中央平原
   /      |      \
[5]       |       [6]
  \       |       /
   [7]---[8]---[9]
      \   |   /
        [10] 首都
```

| 节点 | 位置 | 类型 | 地形 | 对应战斗背景 |
|------|------|------|------|-------------|
| 1 | 西北大陆中心 | FORT | 山脉 | brave_attack |
| 2 | 西岛 | VILLAGE | 平原 | plain_forest |
| 3 | 中央山脉入口 | CITY | 山口 | inside |
| 4 | 东岛 | CITY | 平原 | brave_attack |
| 5 | 西南岛屿 | VILLAGE | 海岸 | plain |
| 6 | 东北半岛 | FORT | 山脉 | brave_attack |
| 7 | 南西群岛 | VILLAGE | 河流 | river |
| 8 | 南方大陆中心 | CITY | 平原 | inside |
| 9 | 东南岛屿 | VILLAGE | 森林 | plain_forest |
| 10 | 最南大陆 | CITY | 首都 | inside |

**4. UI Assets (Ready to use)**
- Location: `ssbp_VV/FEH/UI/`
- 42+ PNG files + 多个子文件夹

**核心UI资产分析：**

| 文件 | 内容 | 用途 |
|------|------|------|
| `Common_Button.png` | 长条彩色按钮（蓝绿紫红青），宝石/水晶质感 | 主菜单按钮、确认取消按钮 |
| `Common_Window.png` | 金属边框面板，深色背景，9-slice友好 | 窗口、对话框、信息面板 |
| `Common.png` | 综合元素：横幅、箭头、六边形按钮、勾选标记 | 标题栏、装饰元素、小按钮 |
| `Battle/Window.png` | 透明渐变面板，标签式设计 | 战斗HUD、单位状态显示 |
| `Battle/Shadow.png` | 圆形渐变阴影 | 角色脚下阴影、选中效果 |
| `Navigation.png` | 六边形图标按钮：Battle, Home, Summon, Shop, Allies | 主导航菜单 |
| `Occupation.png` | 圆形头像框、六边形状态图标、小图标 | 地图节点图标、城市标记 |
| `Home.png` | 信封图标、功能按钮、红色丝带 | 邮件/消息系统、主页菜单 |
| `Arena.png` | 渐变色面板、数字徽章、箭头按钮 | PVP对战界面、排名显示 |
| `Item.png` | 货币（金币、宝珠）、道具、徽章、材料 | 资源系统、背包物品 |
| `Map.png` | 网格线、方向箭头、方框 | 地图网格、移动范围指示 |

**UI 9-Slice 推荐：**
- `Common_Window.png` 长条面板 → 可伸缩窗口框架
- `Common_Button.png` 按钮 → 各种尺寸按钮
- `Battle/Window.png` 透明面板 → HUD元素

### Asset Summary Table

| Asset Type | Source | Count | Status | Godot Path |
|------------|--------|-------|--------|------------|
| Character Atlases | ssbp_viewer export | 10 | ⏳ Manual | `assets/characters/` |
| Battle Backgrounds | FEH/Battle Backgrounds/ | 6 themes | ✅ Ready | `assets/battle/backgrounds/` |
| World Map BGs | FEH/Backgrounds/ | 7 files | ✅ Ready | `assets/world_map/backgrounds/` |
| UI Assets | FEH/UI/ | 42+ files | ✅ Ready | `assets/ui/` |

**Battle Background Selection Logic:**
- City/Fort nodes → `inside` or `brave_attack`
- Village nodes → `plain_forest`
- Random encounters → `plain`, `forest`, `river` (random)

**World Map Backgrounds Selection:**
- **Main map** → `world_map.png` (201805.png) - 古典风格，10城池布局
- Alternative → `occupation_map.png` (Bg_Occupation.png)
- Title screen → `title_bg.png` (Bg_Title.png)

### Task 1: Export Character Animations

**Location:** `ssbp_VV/` directory

**Characters to Export:**

| # | Character | Weapon File | Scale | Output Name | Class |
|---|-----------|-------------|-------|-------------|-------|
| 1 | Alm | wep_sw.png | 1.0 | char_01_alm | Lord |
| 2 | Lilina | wep_mg.png | 1.0 | char_02_lilina | Mage |
| 3 | Dorcas | wep_ax.png | 1.0 | char_03_dorcas | Fighter |
| 4 | Abel | wep_lc.png | 1.0 | char_04_abel | Knight |
| 5 | Klein | wep_bw.png | 1.0 | char_05_klein | Archer |
| 6 | Sharena | wep_lc.png | 1.0 | char_06_sharena | Knight |
| 7 | Lyn | wep_sw.png | 1.0 | char_07_lyn | Swordmaster |
| 8 | Robin_M | wep_mg.png | 1.0 | char_08_robin | Mage |
| 9 | Rebecca | wep_bw.png | 1.0 | char_09_rebecca | Archer |
| 10 | Hector | wep_ax.png | 1.1 | char_10_hector | Fighter |

**Step 1: Export each character (MANUAL - requires Shift+Q)**

```bash
cd /Users/mzhao/workdir/feh/ssbp_VV

# For each character, run:
./ssbp_viewer Alm -w wep_sw.png --wep-scale 1.0
# Then press Shift+Q to export all animations
# Output: Alm_Screenshots/ with Idle/, Attack1/, Attack2/, Damage/, Ready/
```

**Repeat for all 10 characters.**

**Step 2: Convert to Godot Atlas**

```bash
cd /Users/mzhao/workdir/feh/ssbp_VV

# Convert each character
python3 ssbp_to_godot_atlas.py Alm_Screenshots char_01_alm 12
python3 ssbp_to_godot_atlas.py Lilina_Screenshots char_02_lilina 12
python3 ssbp_to_godot_atlas.py Dorcas_Screenshots char_03_dorcas 12
python3 ssbp_to_godot_atlas.py Abel_Screenshots char_04_abel 12
python3 ssbp_to_godot_atlas.py Klein_Screenshots char_05_klein 12
python3 ssbp_to_godot_atlas.py Sharena_Screenshots char_06_sharena 12
python3 ssbp_to_godot_atlas.py Lyn_Screenshots char_07_lyn 12
python3 ssbp_to_godot_atlas.py Robin_M_Screenshots char_08_robin 12
python3 ssbp_to_godot_atlas.py Rebecca_Screenshots char_09_rebecca 12
python3 ssbp_to_godot_atlas.py Hector_Screenshots char_10_hector 12
```

**Step 3: Copy to Godot project**

```bash
cd /Users/mzhao/workdir/feh/ssbp_VV

mkdir -p ../godot/assets/characters
cp char_*.png char_*.json ../godot/assets/characters/
```

**Step 4: Verify**

```bash
ls -la /Users/mzhao/workdir/feh/godot/assets/characters/
# Expected: char_01_alm.png, char_01_alm.json, etc.
```

**Step 5: Commit Characters**

```bash
cd /Users/mzhao/workdir/feh
git add godot/assets/characters/
git commit -m "assets: add 10 character animation atlases"
```

---

### Task 2: Copy Background Assets

**Files to Copy:**

**Battle Backgrounds:**
```bash
cd /Users/mzhao/workdir/feh

# Create battle backgrounds directory
mkdir -p godot/assets/battle/backgrounds

# Copy selected battle backgrounds (6 themes for variety)
cp "ssbp_VV/FEH/Battle Backgrounds/001_BraveAttack/images/BG_02.png" godot/assets/battle/backgrounds/brave_attack_bg.png
cp "ssbp_VV/FEH/Battle Backgrounds/001_BraveAttack/images/FG_01.png" godot/assets/battle/backgrounds/brave_attack_fg.png

cp "ssbp_VV/FEH/Battle Backgrounds/001_BraveForest/images/BG_02.png" godot/assets/battle/backgrounds/forest_bg.png
cp "ssbp_VV/FEH/Battle Backgrounds/001_BraveForest/images/FG_01.png" godot/assets/battle/backgrounds/forest_fg.png

cp "ssbp_VV/FEH/Battle Backgrounds/001_BraveInside/images/BG_02.png" godot/assets/battle/backgrounds/inside_bg.png
cp "ssbp_VV/FEH/Battle Backgrounds/001_BraveInside/images/FG_01.png" godot/assets/battle/backgrounds/inside_fg.png

cp "ssbp_VV/FEH/Battle Backgrounds/002_Plain/images/BG_02.png" godot/assets/battle/backgrounds/plain_bg.png
cp "ssbp_VV/FEH/Battle Backgrounds/002_Plain/images/FG_01.png" godot/assets/battle/backgrounds/plain_fg.png

cp "ssbp_VV/FEH/Battle Backgrounds/002_PlainForest/images/BG_02.png" godot/assets/battle/backgrounds/plain_forest_bg.png
cp "ssbp_VV/FEH/Battle Backgrounds/002_PlainForest/images/FG_01.png" godot/assets/battle/backgrounds/plain_forest_fg.png

cp "ssbp_VV/FEH/Battle Backgrounds/002_PlainRiver/images/BG_02.png" godot/assets/battle/backgrounds/river_bg.png
cp "ssbp_VV/FEH/Battle Backgrounds/002_PlainRiver/images/FG_01.png" godot/assets/battle/backgrounds/river_fg.png
```

**World Map Backgrounds:**
```bash
cd /Users/mzhao/workdir/feh

# Create world map backgrounds directory
mkdir -p godot/assets/world_map/backgrounds

# Copy MAIN world map (201805.png - classical style with compass)
cp "ssbp_VV/FEH/Backgrounds/201805.png" godot/assets/world_map/backgrounds/world_map.png

# Copy alternative backgrounds
cp "ssbp_VV/FEH/Backgrounds/Bg_Occupation.png" godot/assets/world_map/backgrounds/occupation_map.png
cp "ssbp_VV/FEH/Backgrounds/Bg_Title.png" godot/assets/world_map/backgrounds/title_bg.png
cp "ssbp_VV/FEH/Backgrounds/Bg_ArenaDuels.png" godot/assets/world_map/backgrounds/arena_bg.png

# Copy additional seasonal backgrounds
cp "ssbp_VV/FEH/Backgrounds/201806.png" godot/assets/world_map/backgrounds/event_01.png
cp "ssbp_VV/FEH/Backgrounds/201806.png" godot/assets/world_map/backgrounds/event_02.png
cp "ssbp_VV/FEH/Backgrounds/201807.png" godot/assets/world_map/backgrounds/event_03.png
```

**Step 1: Verify Battle Backgrounds**

```bash
ls -la godot/assets/battle/backgrounds/
# Expected: brave_attack_bg.png, brave_attack_fg.png, forest_bg.png, etc.
```

**Step 2: Verify World Map Backgrounds**

```bash
ls -la godot/assets/world_map/backgrounds/
# Expected: occupation_map.png, sequential_map.png, title_bg.png, etc.
```

**Step 3: Commit Backgrounds**

```bash
git add godot/assets/battle/backgrounds/ godot/assets/world_map/backgrounds/
git commit -m "assets: add battle and world map backgrounds from FEH"
```

---

### Task 3: Copy UI Assets

**Files to Copy:**

```bash
cd /Users/mzhao/workdir/feh

# Create UI assets directory
mkdir -p godot/assets/ui

# Copy main UI assets
cp "ssbp_VV/FEH/UI/Common_Button.png" godot/assets/ui/buttons.png
cp "ssbp_VV/FEH/UI/Common_Window.png" godot/assets/ui/window.png
cp "ssbp_VV/FEH/UI/Common.png" godot/assets/ui/common.png

# Copy navigation and menu UI
cp "ssbp_VV/FEH/UI/Navigation.png" godot/assets/ui/navigation.png
cp "ssbp_VV/FEH/UI/Home.png" godot/assets/ui/home.png
cp "ssbp_VV/FEH/UI/Occupation.png" godot/assets/ui/occupation_ui.png

# Copy battle UI
cp "ssbp_VV/FEH/UI/Battle/Window.png" godot/assets/ui/battle_window.png
cp "ssbp_VV/FEH/UI/Battle/Shadow.png" godot/assets/ui/shadow.png

# Copy item and map UI
cp "ssbp_VV/FEH/UI/Item.png" godot/assets/ui/items.png
cp "ssbp_VV/FEH/UI/Map.png" godot/assets/ui/map_ui.png

# Copy arena and score UI
cp "ssbp_VV/FEH/UI/Arena.png" godot/assets/ui/arena.png
cp "ssbp_VV/FEH/UI/ScoreBoard.png" godot/assets/ui/scoreboard.png

# Copy loading and title
cp "ssbp_VV/FEH/UI/Loading.png" godot/assets/ui/loading.png
cp "ssbp_VV/FEH/UI/Logo.png" godot/assets/ui/logo.png
```

**Aether Raids UI (Additional backgrounds):**

```bash
# Copy Aether Raids backgrounds
mkdir -p godot/assets/ui/aether_raid
cp "ssbp_VV/FEH/UI/Aether Raids/Bg_SkyCastle_00.png" godot/assets/ui/aether_raid/sky_castle_00.png
cp "ssbp_VV/FEH/UI/Aether Raids/Bg_SkyCastle_01.png" godot/assets/ui/aether_raid/sky_castle_01.png
cp "ssbp_VV/FEH/UI/Aether Raids/Result_BG.png" godot/assets/ui/aether_raid/result_bg.png
```

**Step 1: Verify UI Assets**

```bash
ls -la godot/assets/ui/
# Expected: buttons.png, window.png, navigation.png, battle_window.png, etc.
```

**Step 2: Commit UI Assets**

```bash
git add godot/assets/ui/
git commit -m "assets: add UI assets from FEH"
```

---

## PHASE 2: Core Systems

### Task 4: Create SaveManager Autoload

**Files:**
- Create: `godot/scripts/autoload/SaveManager.gd`

**Step 1: Write SaveManager.gd**

```gdscript
# godot/scripts/autoload/SaveManager.gd
extends Node

const SAVE_PATH = "user://savegame.json"

func save_game():
    var save_data = {
        "chapter": GameManager.current_chapter,
        "gold": GameManager.player_gold,
        "player_army": []
    }

    for character in GameManager.player_army:
        save_data["player_army"].append({
            "name": character.character_name,
            "class": character.character_class,
            "level": character.level,
            "exp": character.experience,
            "hp": character.current_hp,
            "max_hp": character.max_hp,
            "attack": character.attack,
            "defense": character.defense,
            "speed": character.speed,
            "soldiers": character.soldiers
        })

    var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
    file.store_string(JSON.stringify(save_data))
    file.close()
    print("Game saved to ", SAVE_PATH)

func load_game() -> bool:
    if not FileAccess.file_exists(SAVE_PATH):
        print("No save file found")
        return false

    var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
    var json_string = file.get_as_text()
    file.close()

    var json = JSON.new()
    var error = json.parse(json_string)
    if error != OK:
        print("JSON parse error: ", json.get_error_message())
        return false

    var save_data = json.data
    GameManager.current_chapter = save_data.get("chapter", 1)
    GameManager.player_gold = save_data.get("gold", 1000)

    # TODO: Restore player army from save data
    print("Game loaded from ", SAVE_PATH)
    return true

func has_save() -> bool:
    return FileAccess.file_exists(SAVE_PATH)
```

**Step 2: Commit**

```bash
git add godot/scripts/autoload/SaveManager.gd
git commit -m "feat: add SaveManager autoload"
```

---

### Task 5: Create CharacterData Resource

**Files:**
- Create: `godot/scripts/character/CharacterData.gd`

**Step 1: Write CharacterData.gd**

```gdscript
# godot/scripts/character/CharacterData.gd
class_name CharacterData
extends Resource

@export var character_name: String = "Unnamed"
@export var character_class: GameConstants.CharacterClass = GameConstants.CharacterClass.LORD
@export var level: int = 1
@export var experience: int = 0

# Stats
@export var max_hp: int = 20
@export var current_hp: int = 20
@export var attack: int = 5
@export var defense: int = 3
@export var speed: int = 5
@export var leadership: int = 5

# Combat
@export var weapon_type: String = "sword"
@export var soldiers: int = 100
@export var max_soldiers: int = 100

# Skills & Tactics (Unicorn Overlord style)
@export var skills: Array[SkillData] = []
@export var tactics: Array[Tactic] = []  # 4 tactics max, priority order

# Battle state
var is_defending: bool = false

# Visual
@export var sprite_frames_path: String = ""

# Default tactics for new characters
func setup_default_tactics():
    """Create default 4-slot tactics for new characters"""
    tactics.clear()

    # Slot 1: Attack low HP enemies
    var t1 = Tactic.new()
    t1.priority = 1
    t1.condition_type = Tactic.ConditionType.ENEMY_HP_LOW
    t1.condition_value = 0.3
    t1.target_type = Tactic.TargetType.LOWEST_HP
    t1.action_type = Tactic.ActionType.ATTACK
    t1.use_skill = true
    tactics.append(t1)

    # Slot 2: Defend when self HP low
    var t2 = Tactic.new()
    t2.priority = 2
    t2.condition_type = Tactic.ConditionType.SELF_HP_LOW
    t2.condition_value = 0.3
    t2.target_type = Tactic.TargetType.NEAREST
    t2.action_type = Tactic.ActionType.DEFEND
    tactics.append(t2)

    # Slot 3: Attack nearest
    var t3 = Tactic.new()
    t3.priority = 3
    t3.condition_type = Tactic.ConditionType.ALWAYS
    t3.target_type = Tactic.TargetType.NEAREST
    t3.action_type = Tactic.ActionType.ATTACK
    t3.use_skill = false
    tactics.append(t3)

    # Slot 4: Default attack
    var t4 = Tactic.new()
    t4.priority = 4
    t4.condition_type = Tactic.ConditionType.ALWAYS
    t4.target_type = Tactic.TargetType.NEAREST
    t4.action_type = Tactic.ActionType.ATTACK
    t4.use_skill = false
    tactics.append(t4)

func take_damage(amount: int):
    current_hp = max(0, current_hp - amount)
    if current_hp == 0:
        soldiers = max(0, soldiers - 10)

func heal(amount: int):
    current_hp = min(max_hp, current_hp + amount)

func is_defeated() -> bool:
    return current_hp <= 0 and soldiers <= 0

func gain_experience(amount: int):
    experience += amount
    if experience >= 100:
        level_up()

func level_up():
    level += 1
    experience = 0
    max_hp += 5
    current_hp = max_hp
    attack += 2
    defense += 1
    speed += 1
```

**Step 2: Commit**

```bash
git add godot/scripts/character/CharacterData.gd
git commit -m "feat: add CharacterData resource class"
```

---

### Task 6: Create SkillData Resource

**Files:**
- Create: `godot/scripts/character/SkillData.gd`

**Step 1: Write SkillData.gd**

```gdscript
# godot/scripts/character/SkillData.gd
class_name SkillData
extends Resource

enum SkillType { ACTIVE, PASSIVE, LEADER }
enum TargetType { SELF, SINGLE, AOE, ALLY, ALL_ALLIES }

@export var skill_name: String = "Unknown Skill"
@export var description: String = ""
@export var skill_type: SkillType = SkillType.ACTIVE
@export var target_type: TargetType = TargetType.SINGLE
@export var power: int = 10
@export var cooldown: int = 3
@export var current_cooldown: int = 0

func calculate_damage(user: CharacterData, target: CharacterData) -> int:
    match skill_type:
        SkillType.ACTIVE:
            return max(1, user.attack * power / 10 - target.defense)
        SkillType.PASSIVE:
            return 0
        SkillType.LEADER:
            return 0
    return 0

func can_use() -> bool:
    return current_cooldown <= 0

func use():
    current_cooldown = cooldown

func update_cooldown():
    current_cooldown = max(0, current_cooldown - 1)
```

**Step 2: Commit**

```bash
git add godot/scripts/character/SkillData.gd
git commit -m "feat: add SkillData resource class"
```

---

### Task 6b: Create Tactic Resource (Unicorn Overlord Style)

**Files:**
- Create: `godot/scripts/character/Tactic.gd`

**Step 1: Write Tactic.gd**

```gdscript
# godot/scripts/character/Tactic.gd
class_name Tactic
extends Resource

# Condition types for tactics programming
enum ConditionType {
    ALWAYS,           # No condition
    ENEMY_HP_LOW,     # Enemy HP < threshold
    SELF_HP_LOW,      # Self HP < threshold
    ENEMY_COUNT_HIGH, # Many enemies remaining
    TURN_COUNT        # Turn number threshold
}

# Target selection types
enum TargetType {
    NEAREST,          # Closest enemy
    LOWEST_HP,        # Lowest HP enemy
    HIGHEST_ATK,      # Highest attack enemy
    RANGED_ONLY,      # Only ranged enemies
    MELEE_ONLY        # Only melee enemies
}

# Action types
enum ActionType {
    ATTACK,           # Normal attack
    SKILL,            # Use skill
    DEFEND,           # Defend stance
    MOVE_FORWARD,     # Move to front line
    MOVE_BACKWARD     # Move to back line
}

@export var priority: int = 1  # 1-4, lower = higher priority
@export var condition_type: ConditionType = ConditionType.ALWAYS
@export var condition_value: float = 0.5  # For HP thresholds (0.0-1.0)
@export var target_type: TargetType = TargetType.NEAREST
@export var action_type: ActionType = ActionType.ATTACK
@export var use_skill: bool = false  # If true, use Attack2/skill animation

# Condition check
func is_condition_met(self_unit: BattleUnit, all_enemies: Array, all_allies: Array) -> bool:
    match condition_type:
        ConditionType.ALWAYS:
            return true
        ConditionType.ENEMY_HP_LOW:
            for enemy in all_enemies:
                if enemy.character_data.hp > 0:
                    var hp_percent = float(enemy.character_data.hp) / enemy.character_data.max_hp
                    if hp_percent <= condition_value:
                        return true
            return false
        ConditionType.SELF_HP_LOW:
            var hp_percent = float(self_unit.character_data.hp) / self_unit.character_data.max_hp
            return hp_percent <= condition_value
        ConditionType.ENEMY_COUNT_HIGH:
            var alive_enemies = all_enemies.filter(func(e): return e.character_data.hp > 0)
            return alive_enemies.size() >= int(condition_value * 6)  # Max 6 enemies
        ConditionType.TURN_COUNT:
            # Need reference to turn manager
            return false  # Placeholder
    return false

# Find target based on target_type
func find_target(self_unit: BattleUnit, enemies: Array) -> BattleUnit:
    var valid_enemies = enemies.filter(func(e): return e.character_data.hp > 0)
    if valid_enemies.is_empty():
        return null

    match target_type:
        TargetType.NEAREST:
            # Simple: sort by battle position
            valid_enemies.sort_custom(func(a, b): return a.battle_position < b.battle_position)
            return valid_enemies[0]
        TargetType.LOWEST_HP:
            valid_enemies.sort_custom(func(a, b): return a.character_data.hp < b.character_data.hp)
            return valid_enemies[0]
        TargetType.HIGHEST_ATK:
            valid_enemies.sort_custom(func(a, b): return a.character_data.attack > b.character_data.attack)
            return valid_enemies[0]
    return valid_enemies[0]
```

**Step 2: Commit**

```bash
git add godot/scripts/character/Tactic.gd
git commit -m "feat: add Tactic resource for Unicorn Overlord style combat"
```

---

## PHASE 3: Character Scene

### Task 7: Create Character Scene for Strategy RPG

**Files:**
- Create: `godot/scenes/character/Character.tscn` (replace existing)
- Create: `godot/scripts/character/Character.gd` (replace existing)

**Step 1: Write Character.gd**

```gdscript
# godot/scripts/character/Character.gd
class_name Character
extends Node2D

@export var character_data: CharacterData

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var selection_indicator: Sprite2D = $SelectionIndicator

enum State { IDLE, SELECTED, MOVING, ATTACKING, DAMAGED, DEFEATED }
var current_state: State = State.IDLE
var grid_position: Vector2i

func _ready():
    if character_data:
        setup_sprite()
    set_state(State.IDLE)

func setup_sprite():
    # Load atlas using AtlasLoader
    var atlas_loader = preload("res://scripts/AtlasLoader.gd")
    var json_path = character_data.sprite_frames_path.replace(".png", ".json")
    var png_path = character_data.sprite_frames_path

    animated_sprite.sprite_frames = atlas_loader.load_atlas(json_path, png_path)
    if animated_sprite.sprite_frames:
        animated_sprite.play("Idle")

func set_state(new_state: State):
    current_state = new_state
    match new_state:
        State.IDLE:
            animated_sprite.play("Idle")
            selection_indicator.visible = false
        State.SELECTED:
            animated_sprite.play("Ready")
            selection_indicator.visible = true
        State.MOVING:
            animated_sprite.play("Ready")
        State.ATTACKING:
            animated_sprite.play("Attack1")
        State.DAMAGED:
            animated_sprite.play("Damage")
        State.DEFEATED:
            animated_sprite.play("Damage")
            animated_sprite.pause()
            modulate = Color(0.5, 0.5, 0.5, 1.0)

func play_attack_animation() -> String:
    var attack_type = "Attack1"
    if randf() > 0.5 and animated_sprite.sprite_frames.has_animation("Attack2"):
        attack_type = "Attack2"
    animated_sprite.play(attack_type)
    return attack_type

func take_damage(amount: int):
    character_data.take_damage(amount)
    set_state(State.DAMAGED)
    await animated_sprite.animation_finished
    if character_data.is_defeated():
        set_state(State.DEFEATED)
    else:
        set_state(State.IDLE)

func setup_from_atlas(json_path: String, png_path: String):
    var atlas_loader = preload("res://scripts/AtlasLoader.gd")
    animated_sprite.sprite_frames = atlas_loader.load_atlas(json_path, png_path)
    animated_sprite.play("Idle")
```

**Step 2: Create Character.tscn**

```gdscript
# godot/scenes/character/Character.tscn
[gd_scene load_steps=2 format=3 uid="uid://character_scene_base"]

[ext_resource type="Script" path="res://scripts/character/Character.gd" id="1_script"]

[node name="Character" type="Node2D"]
script = ExtResource("1_script")

[node name="AnimatedSprite2D" type="AnimatedSprite2D" parent="."]

[node name="SelectionIndicator" type="Sprite2D" parent="."]
visible = false
```

**Step 3: Commit**

```bash
git add godot/scenes/character/Character.tscn godot/scripts/character/Character.gd
git commit -m "feat: update Character scene for strategy RPG"
```

---

## PHASE 4: World Map System

### Task 8: Create MapNode

**Files:**
- Create: `godot/scripts/world_map/MapNode.gd`

**Step 1: Write MapNode.gd**

```gdscript
# godot/scripts/world_map/MapNode.gd
class_name MapNode
extends Node2D

signal node_clicked(node: MapNode)

@export var node_id: String = ""
@export var node_type: GameConstants.NodeType = GameConstants.NodeType.CITY
@export var node_name: String = "Unknown"
@export var connections: Array[String] = []
@export var is_explored: bool = false

var position_on_map: Vector2i

@onready var sprite: Sprite2D = $Sprite2D
@onready var label: Label = $Label

func _ready():
    if label:
        label.text = node_name
    update_visual()

func update_visual():
    if not is_explored:
        sprite.modulate = Color(0.3, 0.3, 0.3, 1.0)
        if label:
            label.visible = false
    else:
        sprite.modulate = Color.WHITE
        if label:
            label.visible = true

func _input_event(viewport, event, shape_idx):
    if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        node_clicked.emit(self)

func explore():
    is_explored = true
    update_visual()
```

**Step 2: Commit**

```bash
git add godot/scripts/world_map/MapNode.gd
git commit -m "feat: add MapNode for world map"
```

---

### Task 9: Create WorldMapManager

**Files:**
- Create: `godot/scripts/world_map/WorldMapManager.gd`
- Create: `godot/scenes/world_map/WorldMap.tscn`

**Step 1: Write WorldMapManager.gd**

```gdscript
# godot/scripts/world_map/WorldMapManager.gd
class_name WorldMapManager
extends Node2D

signal turn_ended

@export var current_node_id: String = "city_1"
@export var player_morale: int = 100
@export var turn_count: int = 1

var map_nodes: Dictionary = {}
var player_token: Node2D
var is_player_turn: bool = true

# World map backgrounds
const WORLD_BACKGROUNDS = {
    "world_map": "res://assets/world_map/backgrounds/world_map.png",  # Main map (201805.png)
    "occupation": "res://assets/world_map/backgrounds/occupation_map.png",
    "title": "res://assets/world_map/backgrounds/title_bg.png",
    "arena": "res://assets/world_map/backgrounds/arena_bg.png"
}

# Node configuration for 201805.png world map
# Coordinates based on 1280x720 viewport, adjust based on actual background size
const NODE_CONFIG = {
    "city_1": {"name": "北方要塞", "type": GameConstants.NodeType.FORT, "pos": Vector2(400, 150), "connections": ["city_3"]},
    "city_2": {"name": "西风村", "type": GameConstants.NodeType.VILLAGE, "pos": Vector2(200, 280), "connections": ["city_3", "city_5"]},
    "city_3": {"name": "中央城", "type": GameConstants.NodeType.CITY, "pos": Vector2(450, 280), "connections": ["city_1", "city_2", "city_4", "city_8"]},
    "city_4": {"name": "东影城", "type": GameConstants.NodeType.CITY, "pos": Vector2(700, 280), "connections": ["city_3", "city_6"]},
    "city_5": {"name": "南海村", "type": GameConstants.NodeType.VILLAGE, "pos": Vector2(150, 450), "connections": ["city_2", "city_7"]},
    "city_6": {"name": "东北要塞", "type": GameConstants.NodeType.FORT, "pos": Vector2(850, 200), "connections": ["city_4"]},
    "city_7": {"name": "河湾村", "type": GameConstants.NodeType.VILLAGE, "pos": Vector2(300, 500), "connections": ["city_5", "city_8"]},
    "city_8": {"name": "南方城", "type": GameConstants.NodeType.CITY, "pos": Vector2(500, 480), "connections": ["city_3", "city_7", "city_9", "city_10"]},
    "city_9": {"name": "东岛村", "type": GameConstants.NodeType.VILLAGE, "pos": Vector2(750, 500), "connections": ["city_8"]},
    "city_10": {"name": "帝都", "type": GameConstants.NodeType.CITY, "pos": Vector2(550, 600), "connections": ["city_8"]}
}

@onready var ui: CanvasLayer = $WorldMapUI
@onready var background_sprite: Sprite2D = $Background
@onready var map_nodes_container: Node2D = $MapNodes

func _ready():
    GameManager.change_state(GameConstants.GameState.WORLD_MAP)
    setup_background()
    create_map_nodes()
    initialize_map()

func setup_background():
    """Setup the world map background (201805.png)"""
    if background_sprite:
        background_sprite.texture = load(WORLD_BACKGROUNDS["world_map"])
        # Center the background if it's larger than viewport
        var bg_size = background_sprite.texture.get_size()
        background_sprite.position = bg_size / 2

func create_map_nodes():
    """Create map nodes from NODE_CONFIG"""
    for node_id in NODE_CONFIG.keys():
        var config = NODE_CONFIG[node_id]
        var node = preload("res://scenes/world_map/MapNode.tscn").instantiate()
        node.node_id = node_id
        node.node_name = config.name
        node.node_type = config.type
        node.position = config.pos
        node.connections = config.connections
        map_nodes_container.add_child(node)

func initialize_map():
    for child in map_nodes_container.get_children():
        if child is MapNode:
            map_nodes[child.node_id] = child
            child.node_clicked.connect(_on_node_clicked)

func _on_node_clicked(node: MapNode):
    if not is_player_turn:
        return

    var current_node = map_nodes.get(current_node_id)
    if current_node and current_node.connections.has(node.node_id):
        move_to_node(node)

func move_to_node(target_node: MapNode):
    current_node_id = target_node.node_id
    target_node.explore()

    if target_node.node_type == GameConstants.NodeType.BATTLE:
        trigger_battle(target_node)
    elif target_node.node_type == GameConstants.NodeType.CITY:
        show_city_menu(target_node)

func trigger_battle(node: MapNode):
    var enemy_units = generate_enemy_army(node)

    # Select battle background based on node type and terrain
    var battle_bg = select_battle_background(node)

    # Start battle with background info
    GameManager.battle_started_with_background.emit(GameManager.player_army, enemy_units, battle_bg)
    GameManager.start_battle(GameManager.player_army, enemy_units)

func select_battle_background(node: MapNode) -> String:
    """Select appropriate battle background based on node type"""
    match node.node_type:
        GameConstants.NodeType.CITY:
            return "inside"
        GameConstants.NodeType.FORT:
            return "brave_attack"
        GameConstants.NodeType.VILLAGE:
            return "plain_forest"
        _:
            # Random outdoor battle
            var outdoor_bgs = ["plain", "forest", "river", "plain_forest"]
            return outdoor_bgs[randi() % outdoor_bgs.size()]

func generate_enemy_army(node: MapNode) -> Array[CharacterData]:
    # Generate enemy force based on node
    var enemies: Array[CharacterData] = []
    # TODO: Generate appropriate enemies
    return enemies

func get_total_soldiers() -> int:
    var total = 0
    for char in GameManager.player_army:
        total += char.soldiers
    return total

func end_player_turn():
    is_player_turn = false
    turn_ended.emit()
    process_enemy_turn()

func process_enemy_turn():
    await get_tree().create_timer(1.0).timeout
    turn_count += 1
    is_player_turn = true

func show_city_menu(node: MapNode):
    # TODO: Show city options UI
    pass
```

**Step 2: Create WorldMap.tscn**

```gdscript
# godot/scenes/world_map/WorldMap.tscn
[gd_scene load_steps=4 format=3 uid="uid://worldmap_scene"]

[ext_resource type="Script" path="res://scripts/world_map/WorldMapManager.gd" id="1_script"]
[ext_resource type="Texture2D" path="res://assets/world_map/backgrounds/world_map.png" id="2_bg"]

[node name="WorldMap" type="Node2D"]
script = ExtResource("1_script")

[node name="Background" type="Sprite2D" parent="."]
z_index = -1
texture = ExtResource("2_bg")
centered = false

[node name="Connections" type="Node2D" parent="."]
# Draw lines between connected cities

[node name="MapNodes" type="Node2D" parent="."]
# Cities will be created programmatically by WorldMapManager

[node name="PlayerToken" type="Sprite2D" parent="."]
# Shows current player position

[node name="WorldMapUI" type="CanvasLayer" parent="."]
# UI for resources, turn info, city menus
```

**Step 3: Commit**

```bash
git add godot/scripts/world_map/ godot/scenes/world_map/
git commit -m "feat: add WorldMapManager and WorldMap scene"
```

---

## PHASE 5: Battle System

### Task 10: Create BattleUnit

**Files:**
- Create: `godot/scripts/battle/BattleUnit.gd`
- Create: `godot/scenes/battle/BattleUnit.tscn`

**Step 1: Write BattleUnit.gd**

```gdscript
# godot/scripts/battle/BattleUnit.gd
class_name BattleUnit
extends Node2D

var character_data: CharacterData
var battle_position: int = 0  # 0-2: Front line, 3-5: Back line
var is_player_unit: bool = true
var current_target: BattleUnit = null

# Time bar for active time battle
var time_bar: float = 0.0
var max_time_bar: float = 100.0
var is_ready: bool = false

@onready var character: Character = $Character

func _ready():
    # Time bar fills based on speed
    max_time_bar = 100.0

func setup(data: CharacterData, position: int, is_player: bool):
    character_data = data
    battle_position = position
    is_player_unit = is_player
    character.character_data = data

    if not is_player:
        character.scale.x = -1

func update_time_bar(delta: float):
    """Called every frame to fill time bar based on speed"""
    if is_ready or character_data.is_defeated():
        return

    # Speed determines fill rate
    var fill_rate = character_data.speed * 10.0  # Adjust multiplier for game feel
    time_bar += fill_rate * delta

    if time_bar >= max_time_bar:
        time_bar = max_time_bar
        is_ready = true
        enter_ready_state()

func enter_ready_state():
    """Character is ready to act - evaluate tactics"""
    character.set_state(Character.State.READY)

func execute_tactics(all_enemy_units: Array[BattleUnit], all_ally_units: Array[BattleUnit]):
    """Evaluate tactics in priority order and execute first matching one"""
    for tactic in character_data.tactics:
        if evaluate_condition(tactic, all_enemy_units, all_ally_units):
            execute_action(tactic, all_enemy_units, all_ally_units)
            return

    # Default: Attack nearest enemy
    var target = find_nearest_target(all_enemy_units)
    if target:
        await perform_attack(target, false)

func evaluate_condition(tactic: Tactic, enemies: Array[BattleUnit], allies: Array[BattleUnit]) -> bool:
    """Check if tactic condition is met"""
    match tactic.condition_type:
        "enemy_hp_low":
            for enemy in enemies:
                if not enemy.character_data.is_defeated():
                    var hp_percent = float(enemy.character_data.hp) / enemy.character_data.max_hp
                    if hp_percent <= tactic.condition_value:
                        return true
            return false
        "self_hp_low":
            var hp_percent = float(character_data.hp) / character_data.max_hp
            return hp_percent <= tactic.condition_value
        "always":
            return true
        _:
            return false

func find_nearest_target(enemy_units: Array[BattleUnit]) -> BattleUnit:
    """Find nearest valid target considering formation"""
    var valid_targets = enemy_units.filter(func(u): return not u.character_data.is_defeated())
    if valid_targets.is_empty():
        return null

    # Check if back line is protected
    var has_front_line = false
    for enemy in valid_targets:
        if enemy.battle_position < 3:  # Front line positions
            has_front_line = true
            break

    # If front line exists, can only target front line (unless ranged)
    var is_ranged = character_data.weapon_type in ["bow", "magic"]
    if has_front_line and not is_ranged:
        valid_targets = valid_targets.filter(func(u): return u.battle_position < 3)

    if valid_targets.is_empty():
        return null

    # Sort by battle position (proximity)
    valid_targets.sort_custom(func(a, b): return a.battle_position < b.battle_position)
    return valid_targets[0]

func execute_action(tactic: Tactic, enemies: Array[BattleUnit], allies: Array[BattleUnit]):
    """Execute the tactic action"""
    var target = find_target_by_tactic(tactic, enemies, allies)
    if not target:
        return

    match tactic.action_type:
        "attack":
            await perform_attack(target, tactic.use_skill)
        "defend":
            character_data.is_defending = true
            await get_tree().create_timer(0.5).timeout
        "move_forward":
            if battle_position >= 3:  # Currently in back
                battle_position -= 3
                # Animate movement
        "move_backward":
            if battle_position < 3:  # Currently in front
                battle_position += 3
                # Animate movement

func find_target_by_tactic(tactic: Tactic, enemies: Array[BattleUnit], allies: Array[BattleUnit]) -> BattleUnit:
    """Find target based on tactic target_type"""
    match tactic.target_type:
        "nearest":
            return find_nearest_target(enemies)
        "lowest_hp":
            var valid = enemies.filter(func(u): return not u.character_data.is_defeated())
            if valid.is_empty():
                return null
            valid.sort_custom(func(a, b): return a.character_data.hp < b.character_data.hp)
            return valid[0]
        _:
            return find_nearest_target(enemies)

func perform_attack(target: BattleUnit, use_skill: bool):
    """Perform attack with damage calculation"""
    # Calculate base damage
    var damage = calculate_damage(target, use_skill)

    # Check for pincer attack
    var adjacent_allies = count_adjacent_allies(target)
    if adjacent_allies > 0:
        damage = int(damage * (1.5 + 0.3 * adjacent_allies))  # Pincer bonus

    # Play animation
    if use_skill and character.animated_sprite.sprite_frames.has_animation("Attack2"):
        character.play_attack_animation("Attack2")
    else:
        character.play_attack_animation("Attack1")

    await character.animated_sprite.animation_finished
    await target.take_damage(damage)

    # Reset time bar
    time_bar = 0.0
    is_ready = false
    character.set_state(Character.State.IDLE)

func calculate_damage(target: BattleUnit, use_skill: bool) -> int:
    """Calculate damage with weapon triangle"""
    var base_atk = character_data.attack
    if use_skill:
        base_atk = int(base_atk * 1.5)

    var damage = base_atk - target.character_data.defense

    # Weapon triangle bonus
    var triangle_bonus = get_weapon_triangle_bonus(character_data.weapon_type, target.character_data.weapon_type)
    damage = int(damage * (1.0 + triangle_bonus))

    return max(1, damage)

func get_weapon_triangle_bonus(attacker: String, defender: String) -> float:
    """Return damage modifier for weapon triangle"""
    # Sword > Axe > Lance > Sword
    if attacker == "sword" and defender == "axe": return 0.2
    if attacker == "axe" and defender == "lance": return 0.2
    if attacker == "lance" and defender == "sword": return 0.2
    if attacker == "axe" and defender == "sword": return -0.2
    if attacker == "lance" and defender == "axe": return -0.2
    if attacker == "sword" and defender == "lance": return -0.2
    # Bow strong vs Flying
    if attacker == "bow" and defender == "flying": return 0.3
    return 0.0

func count_adjacent_allies(target: BattleUnit) -> int:
    """Count how many allies are adjacent to target for pincer bonus"""
    # Simplified: check battle_position adjacency
    # In real implementation, check formation adjacency
    return 0  # Placeholder

func take_damage(amount: int):
    """Take damage with defense bonus"""
    if character_data.is_defending:
        amount = int(amount * 0.5)
        character_data.is_defending = false

    await character.take_damage(amount)
```

**Step 2: Create BattleUnit.tscn**

```gdscript
# godot/scenes/battle/BattleUnit.tscn
[gd_scene load_steps=3 format=3 uid="uid://battleunit_scene"]

[ext_resource type="PackedScene" path="res://scenes/character/Character.tscn" id="1_character"]
[ext_resource type="Script" path="res://scripts/battle/BattleUnit.gd" id="2_script"]

[node name="BattleUnit" type="Node2D"]
script = ExtResource("2_script")

[node name="Character" parent="." instance=ExtResource("1_character")]
```

**Step 3: Commit**

```bash
git add godot/scripts/battle/BattleUnit.gd godot/scenes/battle/BattleUnit.tscn
git commit -m "feat: add BattleUnit for auto-combat"
```

---

### Task 11: Create BattleManager

**Files:**
- Create: `godot/scripts/battle/BattleManager.gd`
- Create: `godot/scenes/battle/BattleScene.tscn`

**Step 1: Write BattleManager.gd**

```gdscript
# godot/scripts/battle/BattleManager.gd
class_name BattleManager
extends Node2D

signal battle_finished(victory: bool)
signal turn_started(turn_number: int)
signal unit_acted(unit: BattleUnit)

@export var max_turns: int = 20

var player_units: Array[BattleUnit] = []
var enemy_units: Array[BattleUnit] = []
var all_units: Array[BattleUnit] = []
var current_turn: int = 0
var is_battle_active: bool = false

@onready var deployment_ui: CanvasLayer = $DeploymentUI
@onready var battle_ui: CanvasLayer = $BattleUI
@onready var background_sprite: Sprite2D = $Background
@onready var foreground_sprite: Sprite2D = $Foreground

# Available battle backgrounds
const BATTLE_BACKGROUNDS = {
    "plain": "res://assets/battle/backgrounds/plain_bg.png",
    "plain_fg": "res://assets/battle/backgrounds/plain_fg.png",
    "forest": "res://assets/battle/backgrounds/forest_bg.png",
    "forest_fg": "res://assets/battle/backgrounds/forest_fg.png",
    "inside": "res://assets/battle/backgrounds/inside_bg.png",
    "inside_fg": "res://assets/battle/backgrounds/inside_fg.png",
    "brave_attack": "res://assets/battle/backgrounds/brave_attack_bg.png",
    "brave_attack_fg": "res://assets/battle/backgrounds/brave_attack_fg.png",
    "river": "res://assets/battle/backgrounds/river_bg.png",
    "river_fg": "res://assets/battle/backgrounds/river_fg.png",
    "plain_forest": "res://assets/battle/backgrounds/plain_forest_bg.png",
    "plain_forest_fg": "res://assets/battle/backgrounds/plain_forest_fg.png"
}

func _ready():
    GameManager.battle_started.connect(_on_battle_started)
    GameManager.battle_started_with_background.connect(_on_battle_started_with_background)
    visible = false

func set_background(bg_type: String):
    """Set battle background by type (plain, forest, inside, brave_attack, river, plain_forest)"""
    var bg_path = BATTLE_BACKGROUNDS.get(bg_type, BATTLE_BACKGROUNDS["plain"])
    var fg_path = BATTLE_BACKGROUNDS.get(bg_type + "_fg", BATTLE_BACKGROUNDS["plain_fg"])

    if background_sprite:
        background_sprite.texture = load(bg_path)
    if foreground_sprite:
        foreground_sprite.texture = load(fg_path)

func _on_battle_started(player_army: Array, enemy_army: Array):
    # Use the default background if not specified
    set_background(GameManager.current_battle_background)
    start_deployment(player_army, enemy_army)

func _on_battle_started_with_background(player_army: Array, enemy_army: Array, background_type: String):
    set_background(background_type)
    start_deployment(player_army, enemy_army)

func start_deployment(player_army: Array, enemy_army: Array):
    GameManager.change_state(GameConstants.GameState.BATTLE_DEPLOYMENT)
    # TODO: Show deployment UI
    await get_tree().create_timer(1.0).timeout
    _on_deployment_confirmed(player_army, GameConstants.Formation.STANDARD)

func _on_deployment_confirmed(selected_units: Array[CharacterData], formation: int):
    if deployment_ui:
        deployment_ui.visible = false
    start_battle_combat(selected_units, formation)

func start_battle_combat(player_selected: Array[CharacterData], formation: int):
    GameManager.change_state(GameConstants.GameState.BATTLE_ACTIVE)

    for i in range(player_selected.size()):
        var unit = create_battle_unit(player_selected[i], i, true)
        player_units.append(unit)
        all_units.append(unit)

    for i in range(3):
        var enemy_data = CharacterData.new()
        enemy_data.character_name = "Enemy " + str(i+1)
        var unit = create_battle_unit(enemy_data, i, false)
        enemy_units.append(unit)
        all_units.append(unit)

    all_units.sort_custom(func(a, b): return a.character_data.speed > b.character_data.speed)

    is_battle_active = true
    current_turn = 0
    await start_combat_round()

func create_battle_unit(data: CharacterData, position: int, is_player: bool) -> BattleUnit:
    var unit_scene = preload("res://scenes/battle/BattleUnit.tscn")
    var unit = unit_scene.instantiate()
    unit.setup(data, position, is_player)
    add_child(unit)
    return unit

func start_combat_round():
    while is_battle_active and current_turn < max_turns:
        current_turn += 1
        turn_started.emit(current_turn)

        for unit in all_units:
            if unit.character_data.is_defeated():
                continue

            var enemy_list = enemy_units if unit.is_player_unit else player_units
            await unit.process_turn(enemy_list)
            unit_acted.emit(unit)

            if check_victory():
                return

            await get_tree().create_timer(0.5).timeout

        await get_tree().create_timer(1.0).timeout

    end_battle(false)

func check_victory() -> bool:
    var player_alive = player_units.any(func(u): return not u.character_data.is_defeated())
    var enemy_alive = enemy_units.any(func(u): return not u.character_data.is_defeated())

    if not enemy_alive:
        end_battle(true)
        return true
    elif not player_alive:
        end_battle(false)
        return true
    return false

func end_battle(victory: bool):
    is_battle_active = false
    battle_finished.emit(victory)
    GameManager.end_battle(victory)
```

**Step 2: Create BattleScene.tscn**

```gdscript
# godot/scenes/battle/BattleScene.tscn
[gd_scene load_steps=4 format=3 uid="uid://battlescene_base"]

[ext_resource type="Script" path="res://scripts/battle/BattleManager.gd" id="1_script"]
[ext_resource type="Texture2D" path="res://assets/battle/backgrounds/plain_bg.png" id="2_bg"]
[ext_resource type="Texture2D" path="res://assets/battle/backgrounds/plain_fg.png" id="3_fg"]

[node name="BattleScene" type="Node2D"]
script = ExtResource("1_script")

[node name="Background" type="Sprite2D" parent="."]
z_index = -2
texture = ExtResource("2_bg")
centered = false

[node name="Foreground" type="Sprite2D" parent="."]
z_index = 10
texture = ExtResource("3_fg")
centered = false

[node name="PlayerFormation" type="Node2D" parent="."]
position = Vector2(300, 360)

[node name="EnemyFormation" type="Node2D" parent="."]
position = Vector2(980, 360)

[node name="DeploymentUI" type="CanvasLayer" parent="."]

[node name="BattleUI" type="CanvasLayer" parent="."]
```

**Step 3: Commit**

```bash
git add godot/scripts/battle/BattleManager.gd godot/scenes/battle/BattleScene.tscn
git commit -m "feat: add BattleManager with auto-combat system"
```

---

## PHASE 6: Main Scene Integration

### Task 12: Update Main Scene

**Files:**
- Modify: `godot/scenes/Main.tscn`
- Create: `godot/scripts/Main.gd`

**Step 1: Write Main.gd**

```gdscript
# godot/scripts/Main.gd
extends Node2D

@onready var world_map = $WorldMap
@onready var battle_manager = $BattleScene
@onready var main_menu = $MainMenu

func _ready():
    main_menu.get_node("StartButton").pressed.connect(_start_game)
    GameManager.state_changed.connect(_on_state_changed)

    world_map.visible = false
    battle_manager.visible = false
    main_menu.visible = true

func _start_game():
    main_menu.visible = false
    GameManager.change_state(GameConstants.GameState.WORLD_MAP)
    world_map.visible = true

func _on_state_changed(new_state: GameConstants.GameState):
    match new_state:
        GameConstants.GameState.WORLD_MAP:
            world_map.visible = true
            battle_manager.visible = false
        GameConstants.GameState.BATTLE_DEPLOYMENT, \
        GameConstants.GameState.BATTLE_ACTIVE:
            world_map.visible = false
            battle_manager.visible = true
```

**Step 2: Update Main.tscn**

```gdscript
# godot/scenes/Main.tscn
[gd_scene load_steps=4 format=3 uid="uid://djctfbygkh2x2"]

[ext_resource type="PackedScene" path="res://scenes/world_map/WorldMap.tscn" id="1_worldmap"]
[ext_resource type="PackedScene" path="res://scenes/battle/BattleScene.tscn" id="2_battle"]
[ext_resource type="Script" path="res://scripts/Main.gd" id="3_main"]

[node name="Main" type="Node2D"]
script = ExtResource("3_main")

[node name="WorldMap" parent="." instance=ExtResource("1_worldmap")]
visible = false

[node name="BattleScene" parent="." instance=ExtResource("2_battle")]
visible = false

[node name="MainMenu" type="CanvasLayer" parent="."]

[node name="StartButton" type="Button" parent="MainMenu"]
offset_left = 540.0
offset_top = 300.0
offset_right = 740.0
offset_bottom = 350.0
text = "Start Game"

[node name="Title" type="Label" parent="MainMenu"]
offset_left = 440.0
offset_top = 150.0
offset_right = 840.0
offset_bottom = 250.0
theme_override_font_sizes/font_size = 48
text = "Strategy RPG"
horizontal_alignment = 1
```

**Step 3: Commit**

```bash
git add godot/scenes/Main.tscn godot/scripts/Main.gd
git commit -m "feat: update Main scene with state switching"
```

---

## VERIFICATION CHECKLIST

### Asset Verification
- [ ] 10 character atlases in `godot/assets/characters/`
- [ ] Each atlas has .png and .json files
- [ ] Atlases load correctly in Godot

### Code Verification
- [ ] Project opens without errors
- [ ] GameManager autoload works
- [ ] SaveManager can save/load
- [ ] Character scene displays animations
- [ ] WorldMap nodes are clickable
- [ ] Battle starts from WorldMap
- [ ] Auto-combat runs correctly
- [ ] Battle ends and returns to WorldMap

### Run Game

```bash
cd /Users/mzhao/workdir/feh/godot
godot --editor
```

---

## EXECUTION OPTIONS

**Plan complete and saved to `docs/plans/2025-03-01-godot-strategy-rpg.md`.**

**Two execution options:**

**1. Subagent-Driven (this session)** - I dispatch fresh subagent per task, review between tasks, fast iteration

**2. Parallel Session (separate)** - Open new session with executing-plans skill

**Which approach would you prefer?**

**Note:** PHASE 1 (Asset Generation) requires manual interaction with ssbp_viewer and must be completed before PHASE 2-6 can be fully tested.
