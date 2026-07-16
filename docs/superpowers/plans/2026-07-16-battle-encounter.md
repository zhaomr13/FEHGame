# 战斗过场实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在世界地图上触发战斗时，先播放一段"镜头聚焦到交战城市 + 底部文言风战役横幅"的过场，2 秒后可跳过，然后进入战斗场景。

**Architecture:** 新增一个独立的 `BattleEncounterBanner` UI 场景负责横幅动画和文字渲染；`WorldMapManager` 通过协程控制镜头移动、横幅显示、等待和跳过输入，最后才调用原有的 `GameManager.start_battle_with_background()`。

**Tech Stack:** Godot 4.6, GDScript, Tween, Camera2D, CanvasLayer.

## Global Constraints

- 战役文字使用文言风：`{攻方主将}军 与 {守方主将}军 战于 {城市名}`。
- 过场总时长 2 秒，期间点击屏幕或按空格可跳过。
- 镜头移动 0.8 秒，使用 `Tween.TRANS_QUAD` + `Tween.EASE_OUT`。
- 横幅从底部滑入，持续 0.4 秒。
- 不新增 `GameConstants.GameState`，过场期间用 `WorldMapManager` 内部标志控制。
- 势力颜色复用 `MapNode.FACTION_COLORS`。
- 代码注释和玩家可见文本使用中文。

---

## 文件结构

### 新建文件

- `godot/scenes/ui/BattleEncounterBanner.tscn`：战役横幅 UI 场景。
- `godot/scripts/ui/BattleEncounterBanner.gd`：横幅控制脚本，提供 `show_encounter()` 和 `hide_banner()`。

### 修改文件

- `godot/scripts/world_map/WorldMapManager.gd`：
  - 在 `_ready()` 中实例化横幅场景。
  - 添加 `_is_encounter_active`、`_encounter_input_skip` 等状态。
  - 添加 `_start_battle_encounter()` 协程。
  - 修改 `_start_battle()` 先调用过场再进入战斗。
  - 在 `_unhandled_input()` 中处理跳过输入。

---

## Task 1: 创建战役横幅 UI 场景

**Files:**
- Create: `godot/scenes/ui/BattleEncounterBanner.tscn`
- Create: `godot/scripts/ui/BattleEncounterBanner.gd`

**Interfaces:**
- Produces: `BattleEncounterBanner.show_encounter(attacker_name: String, defender_name: String, city_name: String, attacker_faction: String = "", defender_faction: String = "") -> void`
- Produces: `BattleEncounterBanner.hide_banner() -> void`
- Produces: `BattleEncounterBanner.is_animating: bool`（可选，用于外部判断）

- [ ] **Step 1: 创建场景根节点**

在 Godot 编辑器中新建场景：
- 根节点类型：`CanvasLayer`
- 保存为 `res://scenes/ui/BattleEncounterBanner.tscn`
- 将 `Layer` 属性设为 `10`，确保在大部分 UI 之上。

- [ ] **Step 2: 添加底部横幅面板**

在 `CanvasLayer` 下添加 `Panel` 节点：
- `name = "BannerPanel"`
- `anchors_preset = 7`（底部全宽）
- `anchor_left = 0.0`, `anchor_top = 1.0`, `anchor_right = 1.0`, `anchor_bottom = 1.0`
- `offset_top = -100.0`
- `offset_bottom = 0.0`
- 背景样式：新建 `StyleBoxFlat`，颜色 `Color(0.05, 0.05, 0.05, 0.88)`，无圆角。

- [ ] **Step 3: 添加主标题标签**

在 `BannerPanel` 下添加 `Label` 节点：
- `name = "TitleLabel"`
- `layout_mode = 1`
- `anchors_preset = 8`（居中）
- `anchor_left = 0.0`, `anchor_top = 0.0`, `anchor_right = 1.0`, `anchor_bottom = 1.0`
- `offset_top = -12.0`
- `horizontal_alignment = 1`, `vertical_alignment = 1`
- 主题字体大小覆盖：`font_size = 28`
- 主题字体颜色：`Color.WHITE`
- 默认 `text = "敌军与我军战于某地"`

- [ ] **Step 4: 添加势力颜色块**

在 `BannerPanel` 下添加两个 `ColorRect` 节点：
- 左侧：`name = "AttackerColor"`
  - `layout_mode = 1`
  - `anchors_preset = 4`
  - `offset_left = 20.0`, `offset_top = 35.0`, `offset_right = 40.0`, `offset_bottom = 65.0`
  - `color = Color.WHITE`
- 右侧：`name = "DefenderColor"`
  - 同样尺寸，放在右侧：`offset_left = 1240.0`, `offset_top = 35.0`, `offset_right = 1260.0`, `offset_bottom = 65.0`
  - `color = Color.WHITE`

- [ ] **Step 5: 添加跳过提示**

在 `BannerPanel` 下添加 `Label` 节点：
- `name = "SkipHintLabel"`
- `layout_mode = 1`
- `anchors_preset = 3`（右下角）
- `anchor_left = 1.0`, `anchor_top = 1.0`, `anchor_right = 1.0`, `anchor_bottom = 1.0`
- `offset_left = -160.0`, `offset_top = -28.0`, `offset_right = -12.0`, `offset_bottom = -8.0`
- `horizontal_alignment = 2`
- 主题字体大小覆盖：`font_size = 13`
- 主题字体颜色：`Color(0.7, 0.7, 0.7, 0.8)`
- `text = "点击或按空格跳过"`

- [ ] **Step 6: 编写横幅控制脚本**

创建 `godot/scripts/ui/BattleEncounterBanner.gd`：

```gdscript
class_name BattleEncounterBanner
extends CanvasLayer

@onready var banner_panel: Panel = $BannerPanel
@onready var title_label: Label = $BannerPanel/TitleLabel
@onready var attacker_color: ColorRect = $BannerPanel/AttackerColor
@onready var defender_color: ColorRect = $BannerPanel/DefenderColor
@onready var skip_hint_label: Label = $BannerPanel/SkipHintLabel

const FactionColors = {
	"askr": Color(0.2, 0.6, 1.0),
	"embla": Color(0.8, 0.2, 0.2),
	"nifl": Color(0.2, 0.8, 0.8),
	"muspell": Color(0.9, 0.5, 0.1)
}

const DEFAULT_COLOR = Color(0.6, 0.6, 0.6)

func _ready():
	visible = false
	banner_panel.position.y = 100.0
	modulate = Color.TRANSPARENT

func show_encounter(attacker_name: String, defender_name: String, city_name: String, attacker_faction: String = "", defender_faction: String = ""):
	visible = true
	modulate = Color.WHITE
	title_label.text = "%s军 与 %s军 战于 %s" % [attacker_name, defender_name, city_name]
	attacker_color.color = FactionColors.get(attacker_faction, DEFAULT_COLOR)
	defender_color.color = FactionColors.get(defender_faction, DEFAULT_COLOR)

	var tween = create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(banner_panel, "position:y", 0.0, 0.4).from(100.0)

func hide_banner():
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_IN)
	tween.tween_property(self, "modulate", Color.TRANSPARENT, 0.3)
	tween.parallel().tween_property(banner_panel, "position:y", 100.0, 0.3)
	await tween.finished
	visible = false
```

- [ ] **Step 7: 将脚本附加到场景根节点**

在 `BattleEncounterBanner.tscn` 中，为根节点 `CanvasLayer` 附加 `res://scripts/ui/BattleEncounterBanner.gd` 脚本。

- [ ] **Step 8: 提交**

```bash
cd /Users/wave/workdir/Game/feh
git add godot/scenes/ui/BattleEncounterBanner.tscn godot/scripts/ui/BattleEncounterBanner.gd
git commit -m "feat(ui): add battle encounter banner scene and script"
```

---

## Task 2: 在 WorldMapManager 中集成过场逻辑

**Files:**
- Modify: `godot/scripts/world_map/WorldMapManager.gd`

**Interfaces:**
- Consumes: `BattleEncounterBanner.show_encounter(...)` 和 `hide_banner()`
- Produces: `WorldMapManager._is_encounter_active: bool`
- Produces: `WorldMapManager._start_battle_encounter(attacker: Army, defender: Army)`

- [ ] **Step 1: 添加横幅实例和状态变量**

在 `WorldMapManager.gd` 顶部（`event_log_list` 变量附近）添加：

```gdscript
var encounter_banner: BattleEncounterBanner = null
var _is_encounter_active: bool = false
var _encounter_input_skip: bool = false
const ENCOUNTER_DURATION: float = 2.0
const ENCOUNTER_CAMERA_MOVE_DURATION: float = 0.8
const ENCOUNTER_CAMERA_ZOOM: float = 1.1
```

- [ ] **Step 2: 在 _ready() 中实例化横幅**

在 `_ready()` 末尾添加：

```gdscript
func _ready():
	setup_background()
	if not map_data:
		print("错误：WorldMapManager - 缺少 MapDataManager！")
		return
	map_data.create_map_nodes()
	map_data.draw_connections()
	setup_ui()
	setup_battle_result_handler()
	map_data.node_clicked.connect(_on_node_clicked)
	_setup_encounter_banner()
	if camera:
		_fit_camera()
	if get_tree() and get_tree().root:
		get_tree().root.size_changed.connect(_fit_camera)
```

新增 `_setup_encounter_banner()`：

```gdscript
func _setup_encounter_banner():
	var banner_scene = preload("res://scenes/ui/BattleEncounterBanner.tscn")
	if banner_scene:
		encounter_banner = banner_scene.instantiate()
		add_child(encounter_banner)
```

- [ ] **Step 3: 处理跳过输入**

在 `_unhandled_input(event)` 中（如果已有该函数则修改，否则新建）：

```gdscript
func _unhandled_input(event: InputEvent):
	if not _is_encounter_active:
		return
	var skip = false
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		skip = true
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE or event.is_action("ui_accept"):
			skip = true
	if skip:
		_encounter_input_skip = true
		get_viewport().set_input_as_handled()
```

如果 `WorldMapManager` 当前没有 `_unhandled_input()`，直接添加这个函数即可。

- [ ] **Step 4: 修改 _start_battle 为过场入口**

将 `_start_battle(attacker, defender)` 改名为 `_enter_battle(attacker, defender)`，保留原有战斗启动逻辑：

```gdscript
func _enter_battle(attacker: Army, defender: Army):
	_pause_all_armies_for_battle()
	current_phase = GamePhase.BATTLE
	phase_changed.emit(current_phase)
	_executing_armies.clear()
	attacker.state = Army.ArmyState.IN_BATTLE
	defender.state = Army.ArmyState.IN_BATTLE
	battling_armies = [attacker, defender]
	battle_city_id = _get_battle_city_id(attacker, defender)
	var battle_bg = "plain"
	if battle_city_id != "" and map_data.map_nodes.has(battle_city_id):
		battle_bg = map_data.select_battle_background(map_data.map_nodes[battle_city_id])
	_log_event(_describe_battle_start(attacker, defender), Color(1.0, 0.7, 0.55))
	GameManager.start_battle_with_background(attacker.squad_data, defender.squad_data, battle_bg)
	_update_planning_ui()
```

- [ ] **Step 5: 新增 _start_battle_encounter 协程**

新增过场控制协程：

```gdscript
func _start_battle(attacker: Army, defender: Army):
	_start_battle_encounter(attacker, defender)

func _start_battle_encounter(attacker: Army, defender: Army):
	_is_encounter_active = true
	_encounter_input_skip = false

	var city_id = _get_battle_city_id(attacker, defender)
	var city_name = _get_city_display_name(city_id)
	if city_name == city_id and attacker.from_city_id != "" and attacker.to_city_id != "":
		city_name = _get_city_display_name(attacker.to_city_id)

	var attacker_name = attacker.get_leader_name()
	var defender_name = defender.get_leader_name()

	if encounter_banner:
		encounter_banner.show_encounter(attacker_name, defender_name, city_name, attacker.faction, defender.faction)

	var camera_target = _get_encounter_camera_target(attacker, defender, city_id)
	var original_position = camera.position if camera else Vector2.ZERO
	var original_zoom = camera.zoom if camera else Vector2.ONE

	if camera:
		var tween = create_tween()
		tween.set_trans(Tween.TRANS_QUAD)
		tween.set_ease(Tween.EASE_OUT)
		tween.tween_property(camera, "position", camera_target, ENCOUNTER_CAMERA_MOVE_DURATION)
		tween.parallel().tween_property(camera, "zoom", Vector2.ONE * ENCOUNTER_CAMERA_ZOOM, ENCOUNTER_CAMERA_MOVE_DURATION)

	await _wait_for_encounter_or_skip()

	_is_encounter_active = false
	if encounter_banner:
		await encounter_banner.hide_banner()

	if camera:
		var reset_tween = create_tween()
		reset_tween.set_trans(Tween.TRANS_QUAD)
		reset_tween.set_ease(Tween.EASE_OUT)
		reset_tween.tween_property(camera, "position", original_position, 0.3)
		reset_tween.parallel().tween_property(camera, "zoom", original_zoom, 0.3)
		await reset_tween.finished

	_enter_battle(attacker, defender)

func _get_encounter_camera_target(attacker: Army, defender: Army, city_id: String) -> Vector2:
	if city_id != "" and map_data.NODE_CONFIG.has(city_id):
		return map_data.NODE_CONFIG[city_id]["pos"]
	if is_instance_valid(attacker) and is_instance_valid(defender):
		return (attacker.position + defender.position) * 0.5
	return Vector2.ZERO

func _wait_for_encounter_or_skip():
	var elapsed = 0.0
	while elapsed < ENCOUNTER_DURATION:
		if _encounter_input_skip:
			break
		await get_tree().process_frame
		elapsed += get_process_delta_time()
```

- [ ] **Step 6: 调整 _check_encounters 的调用**

`_check_encounters()` 中仍然调用 `_start_battle(a1, a2)`，不需要改，因为 `_start_battle` 现在会启动过场协程。

- [ ] **Step 7: 防止过场期间其他输入**

在 `_on_node_clicked()`、`_on_army_clicked()` 等输入处理函数开头加入：

```gdscript
func _on_node_clicked(node: MapNode):
	if _is_encounter_active:
		return
	# ... existing logic
```

同样处理 `_on_army_clicked(army)`、`_start_execution()`、`open_city_menu()`、`_on_open_formation()` 等函数。

- [ ] **Step 8: 提交**

```bash
cd /Users/wave/workdir/Game/feh
git add godot/scripts/world_map/WorldMapManager.gd
git commit -m "feat(world-map): add battle encounter cutscene before combat"
```

---

## Task 3: 手动验证

**Files:**
- Modify: `godot/project.godot`（如需要，通常不需要）
- Test: 通过运行游戏验证

- [ ] **Step 1: 运行游戏**

```bash
cd /Users/wave/workdir/Game/feh/godot
/Applications/Godot.app/Contents/MacOS/Godot
```

- [ ] **Step 2: 触发一场战斗**

1. 选择势力进入世界地图。
2. 在计划阶段，选择一支己方军队，点击相邻的敌方城市设置路线。
3. 点击"结束计划"。
4. 当己方军队与敌方军队相遇时，观察：
   - 镜头是否移动到交战城市。
   - 底部是否出现战役横幅，文字格式为"{主将}军 与 {主将}军 战于 {城市名}"。
   - 横幅是否停留约 2 秒后自动进入战斗。
   - 点击屏幕或按空格是否能跳过等待直接进入战斗。

- [ ] **Step 3: 验证道路遭遇战**

如果敌方军队也在移动，并且与己方军队在道路上相向而行：
- 镜头应移动到两军中间点。
- 横幅城市名应显示为它们正在前往的城市名（攻方 `to_city_id`）。

- [ ] **Step 4: 提交验证结果（如有修复）**

如果发现 bug 并修复，按常规提交。

---

## Self-Review

**Spec coverage:**
- 镜头聚焦：Task 2 Step 5 的 `_get_encounter_camera_target()` 和 Tween 移动。
- 底部战役横幅：Task 1 完整覆盖。
- 文言风文字：Task 1 Step 6 的 `title_label.text` 格式。
- 2 秒停留 + 跳过：Task 2 Step 5 的 `_wait_for_encounter_or_skip()`。
- 势力颜色：Task 1 Step 6 的 `FactionColors`。

**Placeholder scan:**
- 无 TBD/TODO。
- 所有函数签名、节点路径、颜色值均已明确。

**Type consistency:**
- `_start_battle(attacker, defender)` 保持原有签名，内部改为协程入口。
- `_enter_battle(attacker, defender)` 是原 `_start_battle` 的逻辑迁移，签名一致。
- `BattleEncounterBanner.show_encounter` 参数类型明确。

**无测试框架说明：**
当前项目没有测试框架，验证部分使用手动运行游戏的方式。

---

## Execution Handoff

Plan complete and saved to `docs/superpowers/plans/2026-07-16-battle-encounter.md`. Two execution options:

**1. Subagent-Driven (recommended)** - I dispatch a fresh subagent per task, review between tasks, fast iteration.

**2. Inline Execution** - Execute tasks in this session using executing-plans, batch execution with checkpoints.

Which approach?
