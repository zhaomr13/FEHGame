# 战斗过场设计

## 背景

当前世界地图上两支敌对军队触发战斗后，会直接切换到战斗场景。为了让玩家清楚"在哪里、谁和谁发生了战斗"，需要加入一段短过场：镜头聚焦到交战城市，并显示战役横幅。

## 目标

- 在切入战斗前，明确展示交战地点和交战双方。
- 保持节奏感，过场不超过 2-3 秒，支持跳过。
- 视觉风格与中文三国题材一致（文言风文字 + 势力颜色）。

## 方案

**镜头聚焦 + 底部战役横幅**

1. 世界地图状态冻结（军队停止移动、UI 禁用）。
2. 镜头快速平移到交战城市位置。
3. 屏幕底部滑入一条战役横幅，用文言风显示交战双方和城市。
4. 停留 2 秒后自动进入战斗；期间玩家可以点击屏幕或按空格跳过。
5. 跳过/超时后切换到战斗场景。

## 流程

```
遭遇触发
    ↓
冻结世界地图
    ↓
启动过场协程
    ├── 镜头 Tween 移动到交战城市（0.8s，quad ease-out）
    ├── 横幅 Tween 从底部滑入
    ├── 显示：{攻方军名} 与 {守方军名} 战于 {城市名}
    │
    └── 等待 2 秒 或 收到跳过输入
              ↓
    淡出横幅 → 进入战斗场景
```

## 新增组件

### `scripts/ui/BattleEncounterBanner.gd` + `scenes/ui/BattleEncounterBanner.tscn`

一个 `CanvasLayer` 场景，包含：
- `Panel`：底部横幅背景，半透明深色。
- `Label`：居中显示战役文字。
- 可选势力颜色块：左右两侧小色块标识双方势力。

主要方法：
- `show_encounter(attacker_name, defender_name, city_name, attacker_faction, defender_faction)`：滑入并显示横幅。
- `hide_banner()`：淡出/下滑隐藏横幅。

## 修改组件

### `scripts/world_map/WorldMapManager.gd`

- 新增 `_start_battle_encounter(attacker: Army, defender: Army)` 协程。
- 新增 `_encounter_input_skip: bool` 标志。
- 新增 `is_encounter_active: bool` 标志，用于冻结输入。
- 把原来直接调用 `GameManager.start_battle_with_background()` 的地方改为先调用 `_start_battle_encounter()`。
- 在 `_unhandled_input(event)` 中监听鼠标点击或空格键，当 `is_encounter_active` 为真时设置 `_encounter_input_skip = true`。

### `scripts/Main.gd`

- 无需新增 `GameConstants.GameState.BATTLE_ENCOUNTER` 状态，过场期间世界地图保持可见，`WorldMapManager` 内部用 `is_encounter_active` 冻结输入即可。

## 战役文字格式

采用文言风：

```gdscript
var attacker_text = "%s军" % attacker.get_leader_name()
var defender_text = "%s军" % defender.get_leader_name()
var city_name = MapDataManager.NODE_CONFIG[city_id].name
var banner_text = "%s 与 %s 战于 %s" % [attacker_text, defender_text, city_name]
```

示例：

> **刘备军** 与 **曹操军** 战于 **徐州**

如果主将名未知，显示为"未知军"。

## 视觉规格

### 镜头移动

- 持续 0.8 秒。
- 缓动：`Tween.TRANS_QUAD`，`Tween.EASE_OUT`。
- 目标位置：交战城市的全局坐标。
- 到达后轻微放大到 1.1 倍（0.2 秒），进入战斗前复位。

### 底部横幅

- 位置：屏幕底部，高度 80-100 像素。
- 背景：`Color(0.05, 0.05, 0.05, 0.88)`。
- 文字：白色，加粗，字体大小 24-28。
- 军队名称使用对应势力颜色（复用 `MapNode.FACTION_COLORS`）。
- 滑入动画：从底部下方 100 像素移动到 0，持续 0.4 秒。
- 右下角小字：`点击或按空格跳过`。

## 输入与跳过

- 过场期间 `is_encounter_active = true`。
- `_unhandled_input(event)` 监听：
  - 鼠标左键点击
  - `ui_accept`（空格/回车）
- 触发时设置 `_encounter_input_skip = true`。
- 协程中每帧检查该标志，为真则立即结束等待。

## 错误处理

- 如果交战城市在 `NODE_CONFIG` 中找不到，使用城市 ID 作为 fallback 名称。
- 如果某方军队没有角色，`get_leader_name()` 返回"未知"，显示为"未知军"。

## 不包含在本期

- 音效（战鼓、号角）。
- 双方头像/头像框。
- 过场动画序列（如军队冲锋预览）。
