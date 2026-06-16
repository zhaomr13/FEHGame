# 大地图扩展：三国群英传式节点网

**Date:** 2026-06-15  
**Scope:** 将 `godot/` 世界地图从 10 个硬编码节点扩展到约 80 个节点，整体轮廓参考《三国群英传》的中国地图，节点使用火纹英雄风格的原创地名，保留现有势力阵营。

---

## 1. Goals

- 让大地图“更像真实战略地图”，节点多、路线复杂。
- 保留现有玩法：节点点击、军队移动、相邻节点交战、势力争夺。
- 为后续战争迷雾、事件节点、地形影响等系统留下扩展空间。

## 2. Non-Goals

- 不替换火纹英雄的角色与势力（askr/embla/nifl/muspell 继续存在）。
- 本次不实现战争迷雾、随机事件节点、地形行军惩罚。
- 不修改战斗系统、部队数据、`GameManager` 的角色池。

## 3. Map Data Format

把节点配置从 `MapDataManager.gd` 中的 `NODE_CONFIG` 字典迁移到 YAML 数据文件（`godot/data/` 目录需要在首次创建时新建）：

```
godot/data/world_map.yaml
```

### 3.1 YAML Schema

```yaml
metadata:
  map_size:
    x: 3840
    y: 2160
  connection_strategy: "auto_with_overrides"
  max_auto_distance: 320
  target_connections: 3
nodes:
  - id: "city_01"
    name: "北境要塞"
    type: "fort"
    pos:
      x: 1450
      y: 420
    faction: "embla"
    force_connections:
      - "city_02"
      - "city_05"
    blocked_neighbors:
manual_connections:
  - from: "city_03"
    to: "city_21"
```

### 3.2 Field Descriptions

| Field | Type | Description |
|-------|------|-------------|
| `metadata.map_size` | Vector2 | 地图像素尺寸，决定相机边界和背景图尺寸。 |
| `metadata.max_auto_distance` | float | 自动连接的最大距离阈值。 |
| `metadata.target_connections` | int | 每个节点目标相邻数（优先取最近的 N 个）。 |
| `nodes.id` | String | 节点唯一标识，保持 `city_NN` 格式。 |
| `nodes.name` | String | 显示名称，火纹风格原创地名。 |
| `nodes.type` | String | `city` / `fort` / `village`，对应 `GameConstants.NodeType`。 |
| `nodes.pos` | Vector2 | 节点在世界坐标中的位置。 |
| `nodes.faction` | String | 开局所属势力；空字符串表示中立。 |
| `nodes.force_connections` | Array[String] | 强制相邻节点（桥梁、隘口）。 |
| `nodes.blocked_neighbors` | Array[String] | 自动连接时排除的节点。 |
| `manual_connections` | Array[{from,to}] | 额外的远距离/跨域连接。 |

## 4. Node Layout

### 4.1 Map Dimensions

- 世界尺寸：**3840 × 2160** 像素（4K）。
- 当前屏幕 1280 × 720，因此默认需要相机缩放才能看到全貌。

### 4.2 Regional Distribution (~80 nodes)

| Region | Node Count | Character |
|--------|-----------|-----------|
| 北方 | 8–10 | 要塞、平原、寒冷地带 |
| 中原 | 18–22 | 城市密集、交通中枢 |
| 西蜀 | 10–12 | 山地、关隘 |
| 江东 | 12–15 | 水网、港口 |
| 南方/边疆 | 8–10 | 村庄、边陲 |
| 其他 | 10–15 | 要塞、村庄填充 |

### 4.3 Naming Style

使用火纹英雄风格的原创名称，示例：

- 北方：`北境要塞`、`霜风城`、`铁壁关`
- 中原：`王都艾克拉`、`中央平原`、`金穗城`
- 西蜀：`翠云峰`、`剑门关`、`白龙城`
- 江东：`蓝港城`、`镜湖镇`、`东海岸`

## 5. Background Image

- 路径：`godot/assets/world_map/backgrounds/three_kingdoms_map.png`
- 尺寸：3840 × 2160。
- 风格：俯视古风大陆地图，包含河流、山脉、海洋、陆地轮廓。
- 生成方式：使用 `godot-asset-generator` 生成。
- 节点位置根据背景图地形摆放（山脉放关隘、河流交汇处放港口/桥梁）。

## 6. Camera

在 `WorldMap` 场景下添加 `Camera2D`：

- 默认缩放：**0.5**（一次看到约 1/4 地图）。
- 缩放范围：**0.25 – 1.5**。
- 鼠标拖拽平移，限制在 `metadata.map_size` 边界内。
- 鼠标点击军队/节点时，必须使用相机变换把屏幕坐标转成世界坐标。

## 7. Connection Generation

### 7.1 Auto-Connection Rules

1. 对每个节点，计算到其他节点的距离。
2. 优先选择最近的 `target_connections` 个节点，但只保留距离 ≤ `max_auto_distance` 的。
3. 连接是无向的；记录时保证 `id_a < id_b` 避免重复绘制。
4. 应用每个节点的 `blocked_neighbors` 排除项。

### 7.2 Manual Overrides

- `force_connections`：即使超出 `max_auto_distance`，也强制连接。
- `manual_connections`：额外添加任意两点连接（如渡口、山道）。
- 最终连接列表 = 自动连接 ∪ 强制连接 ∪ 手动连接，去重。

### 7.3 Visualization

- 继续使用 `Line2D`。
- 线宽从 3.0 降到 **2.0**，避免密集地图杂乱。
- 颜色保持 `Color(0.8, 0.7, 0.4, 0.6)`，后续可按地形微调。

## 8. Faction Starting Positions

参考三国势力方位，但保留火纹阵营：

| Faction | Starting Region | Role |
|---------|----------------|------|
| `askr` | 中西部 | askr 王国 |
| `embla` | 北部 | embla 帝国 |
| `nifl` | 东南部 | nifl 王国 |
| `muspell` | 西南部/南方边疆 | muspell |

其余节点开局为中立（`faction: ""`），由玩家和 AI 争夺。

`Main.gd` 中的 `FACTION_START_POSITIONS` 需要更新为新的城市 id（具体 id 在节点布局完成后最终确定）。

## 9. Integration

### 9.1 Files to Modify

| File | Change |
|------|--------|
| `godot/scripts/world_map/MapDataManager.gd` | 从 YAML 加载节点；新增自动连接函数；保留现有查询接口。 |
| `godot/scripts/world_map/WorldMapManager.gd` | 添加 `Camera2D` 引用；鼠标点击坐标转换；更新势力起始逻辑。 |
| `godot/scripts/Main.gd` | 更新 `FACTION_START_POSITIONS` 到新的城市 id。 |
| `godot/scenes/world_map/WorldMap.tscn` | 添加 `Camera2D` 节点；替换背景图为 `three_kingdoms_map.png`。 |

### 9.2 Unchanged Systems

- `Army.gd` 的路线跟随、相遇检测、战斗状态。
- `GameManager` 的角色池、小队系统。
- 战斗场景与战场逻辑。

## 10. Validation Plan

### 10.1 Automated Checks

在 `MapDataManager` 加载 YAML 后运行自检：

1. YAML 解析成功。
2. 没有孤立节点（每个节点至少 1 条连接）。
3. 势力起始城市之间图连通。
4. 没有节点间距 < 60 像素（避免重叠）。
5. `force_connections` 和 `manual_connections` 引用的 id 都存在。

### 10.2 Manual In-Game Checks

1. 启动游戏，选择势力后进入大地图。
2. 能缩放/平移相机。
3. 节点、连接、军队可见。
4. 点击节点设置路线，军队沿路线移动。
5. 两军相遇进入战斗，战斗结束后返回大地图。

## 11. Deferred Items

以下功能不在本次实现，但设计时已预留接口：

- 战争迷雾 / 探索系统。
- 随机事件节点。
- 地形对行军速度的影响。
- 势力颜色动态变化（目前只在战斗胜利后更新占领城市）。
- 可视化地图编辑器 / 节点拖动工具。

## 12. Open Questions

None — design approved via conversation.
