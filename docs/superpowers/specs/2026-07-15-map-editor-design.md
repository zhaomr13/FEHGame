# 地图编辑器设计

**Date:** 2026-07-15  
**Scope:** 为 Godot 项目添加一个独立场景的世界地图编辑器，支持拖拽调整城市位置、增删城市、手动编辑连接关系，并保存回 `godot/data/world_map.yaml`。

---

## 1. Goals

- 通过可视化方式编辑 `world_map.yaml` 中的节点数据。
- 支持城市节点的增删改（位置、名称、类型、连接）。
- 连接关系改为完全手动编辑，不再依赖自动距离生成。
- 保存时保持现有 YAML 格式，与 `YamlParser` 兼容。
- 编辑器作为独立场景存在，不影响主游戏流程。

## 2. Non-Goals

- 不编辑势力（faction）、icon_size 等字段；这些保留在 YAML 中并按原样写回。
- 不替换现有的 `WorldMap` 游戏场景；编辑器单独维护一套渲染。
- 不实现地形/战争迷雾/事件节点等高级功能。

## 3. Architecture

### 3.1 新增文件

| 文件 | 用途 |
|------|------|
| `scenes/editor/MapEditor.tscn` | 编辑器主场景 |
| `scripts/editor/MapEditor.gd` | 根控制器：加载/保存协调、相机、选择管理 |
| `scripts/editor/MapEditorCity.gd` | 城市节点包装：挂载 `MapNode` 子节点，处理拖拽和选中状态 |
| `scripts/editor/MapEditorToolbar.gd` | 顶部工具栏：新建、删除、保存、返回 |
| `scripts/editor/MapEditorPropertiesPanel.gd` | 右侧属性面板：名称、类型、连接列表 |
| `scripts/editor/MapEditorYamlWriter.gd` | YAML 读写：解析现有 YAML 并写出 |

### 3.2 场景结构

```
MapEditor (Node2D)
├── Camera2D
├── Background (Sprite2D)          # world_map.png
├── Connections (Node2D)           # 所有 Line2D 连接线的父节点
├── Cities (Node2D)                # MapEditorCity 实例的父节点
└── UI (CanvasLayer)
    ├── Toolbar (HBoxContainer)
    │   ├── 新建城市
    │   ├── 删除城市
    │   ├── 保存
    │   └── 返回
    └── PropertiesPanel (Panel)
        ├── 名称 (LineEdit)
        ├── 类型 (OptionButton)
        └── 连接 (ScrollContainer + VBoxContainer of CheckBox)
```

### 3.3 `MapEditorCity`

- 内部实例化 `scenes/world_map/MapNode.tscn` 作为子节点，复用图标、标签、势力颜色等视觉表现。
- 禁用 `MapNode` 自带的 `Area2D` 点击事件，改由 `MapEditorCity` 统一处理拖拽和选择，避免事件冲突。
- 通过 `_input` 或 `Area2D` 实现左键拖拽移动。
- 被选中时显示额外的选中环（黄色）。
- 维护一个 `data: Dictionary` 引用，直接对应内部城市数据条目。

## 4. Interactions

| 操作 | 行为 |
|------|------|
| 左键点击城市 | 选中该城市，右侧面板更新 |
| 左键拖拽城市 | 移动城市位置，连接线和标签实时跟随 |
| 中键拖拽 / Space+左键 / Shift+左键 | 平移相机 |
| 滚轮 | 缩放相机 |
| 新建城市 | 在屏幕中心附近创建新城市，自动分配下一个 `city_NN` id，默认 type 为 `city` |
| 删除城市 | 删除选中城市，清理其连接，删除前确认 |
| 保存 | 写出 YAML，成功后显示确认弹窗 |
| 返回 | 返回主场景 `scenes/Main.tscn`；若以编辑器为主场景则退出游戏 |

### 4.1 连接编辑

- 右侧面板列出所有其他城市，每项一个 CheckBox。
- 勾选 A→B 会双向添加连接（同时更新 B 的列表和内部数据）。
- 取消勾选则双向移除连接。

## 5. Data Flow

### 5.1 Load

1. `MapEditor._ready()` 调用 `MapEditorYamlWriter.load_world_map(path)`。
2. 使用现有 `YamlParser` 解析 YAML 为 Dictionary。
3. 读取 `nodes` 数组，生成内部 `Array[Dictionary] cities`。
4. 为每个节点创建 `MapEditorCity`，并绘制 `Connections` 中的 `Line2D`。

### 5.2 Edit

- `MapEditorCity` 直接修改其 `data["pos"]` 的 `x` / `y`。
- 属性面板修改 `name` 和 `type`。
- 连接列表修改 `force_connections`（连接关系统一用 `force_connections` 输出）。

### 5.3 Save

- `MapEditorYamlWriter.write_world_map(cities, metadata, path)` 手动生成 YAML 字符串。
- 保持与现有 `world_map.yaml` 相同的格式和缩进，确保 `YamlParser` 能解析。
- 保留未编辑字段：`faction`、`icon_size`、`blocked_neighbors`（若存在）。
- 空数组省略，避免 `YamlParser` 兼容问题。

### 5.4 Output YAML 示例

```yaml
metadata:
  map_size:
    x: 3840
    y: 2160
  connection_strategy: "manual"
  max_auto_distance: 320
  target_connections: 3
nodes:
  - id: "city_01"
    name: "北境要塞"
    type: "city"
    icon_size: "large"
    pos:
      x: 2719
      y: 157
    faction: "embla"
    force_connections:
      - "city_02"
      - "city_05"
```

### 5.5 MapDataManager 配合修改

`MapDataManager._generate_connections()` 目前无论 `connection_strategy` 为何都会执行自动连接。为支持手动连接，需要增加判断：

- 当 `metadata.connection_strategy == "manual"` 时，跳过自动连接阶段，只应用 `force_connections` 和 `manual_connections`。
- 当为 `"auto_with_overrides"` 时，保持现有行为（自动连接 + force/manual 覆盖）。

这样编辑器保存的 `"manual"` YAML 在游戏中加载时不会额外生成自动连接。

## 6. Validation

- **唯一 id**：新建城市时检查 `city_NN` 是否已存在，自动递增避免冲突。
- **重叠检查**：保存时若两个城市距离 < 60 px，弹窗阻止保存。
- **孤立节点检查**：保存时若存在没有任何连接的城市，弹窗阻止保存。
- **删除确认**：删除有连接的城市前要求确认。

## 7. Integration

- `MapEditor.tscn` 可作为独立场景运行，也可从主菜单通过按钮进入。
- 第一阶段先实现独立场景；后续可选在主菜单增加“地图编辑器”按钮。
- 编辑器不依赖 `GameManager` 或游戏状态，只读写 YAML 文件。

## 8. Testing

- 启动编辑器后确认所有城市位置与 YAML 一致。
- 拖拽城市后保存，重新打开确认位置已更新。
- 添加/删除城市后保存，确认 YAML 结构正确且 `YamlParser` 能解析。
- 编辑连接后保存，确认双向连接一致。
- 触发重叠/孤立验证，确认保存被阻止并显示中文提示。
