# 地图编辑器后续补全设计

**Date:** 2026-07-16  
**Scope:** 补全 `2026-07-15-map-editor-design.md` 中已实现场景的剩余细节：连接双向同步、删除确认、保存反馈弹窗。

---

## 1. Background

地图编辑器主场景 `MapEditor.tscn` 已实现：加载 `world_map.yaml`、拖拽城市、增删城市、编辑名称/类型/连接、保存 YAML。本次补全三个剩余 spec 项，使编辑器行为与设计完全一致。

## 2. Goals

- 连接编辑保持双向同步，YAML 中两个城市的 `force_connections` 同时更新。
- 删除城市前弹出确认对话框，连接非空时给出额外警告。
- 保存结果（成功 / 失败 / 验证错误）通过弹窗反馈，而不是仅打印到控制台。

## 3. Non-Goals

- 不实现主菜单入口（仍为独立场景）。
- 不新增字段编辑（faction、icon_size 等继续原样写回）。
- 不改变 `MapDataManager` 的解析逻辑。
- 编辑器输出统一为 `connection_strategy: "manual"`；加载非手动策略的现有地图时，会将其运行时自动连接迁移为显式 `force_connections`，然后以手动策略保存。

## 4. Design

### 4.1 Bidirectional connections

`MapEditor._on_connection_toggled(other_id, connected)` 需要同时修改两个城市的数据：

- `connected == true`：把 `other_id` 加入当前城市的 `force_connections`；同时把当前城市 id 加入 `other_city` 的 `force_connections`（若尚未存在）。
- `connected == false`：从当前城市移除 `other_id`；同时从 `other_city` 移除当前城市 id。

实现时通过 `MapEditor._get_city_data_by_id(id)` 辅助函数安全获取其他城市字典。`PropertiesPanel.set_city` 在刷新连接列表时仍然只读取当前城市的 `force_connections`，因此复选框状态保持正确。

### 4.2 Delete confirmation

在 `MapEditor.tscn` 的 `UI` 层下新增一个 `ConfirmationDialog` 节点：

- 删除按钮触发时：
  - 若选中城市有 `force_connections`：显示 `删除城市 "X" 将同时移除它的所有连接。继续？`
  - 若无连接：显示 `确认删除城市 "X"？`
- 用户点击“确认”后再执行 `_on_delete_city` 的实际删除逻辑。
- 用户点击“取消”则关闭对话框，保持当前选中状态。
- 如果确认对话框打开期间用户切换了选中的城市，点击“确认”不会删除任何城市（避免误删）。

对话框标题统一为 `确认删除`，按钮文本保持 Godot 默认中文（“确认”/“取消”）或在代码中显式设置。

### 4.3 Save feedback popups

在 `MapEditor.tscn` 的 `UI` 层下新增一个 `AcceptDialog` 节点：

- 保存按钮触发 `_on_save` 后：
  - 若 `_validate_map()` 返回非空字符串，弹窗显示该错误。
  - 若 `MapEditorYamlWriter.write_world_map` 返回 `true`，弹窗显示 `地图已保存`。
  - 若返回 `false`，弹窗显示 `保存失败，请检查文件权限。`
- 删除现有的 `print` 反馈语句，或保留为调试日志但弹窗为主要反馈。

### 4.4 Auto-connection migration on load

编辑器输出统一使用 `"manual"` 连接策略。当加载的 YAML 使用 `"auto_with_overrides"`（或没有 `connection_strategy`）时，`MapEditor._load_map()` 会先通过 `MapDataManager` 计算运行时连接图，把每个城市的连接写入该城市的 `force_connections`，然后再将 `metadata.connection_strategy` 设为 `"manual"`。这样现有地图的连通性不会丢失，同时后续编辑完全基于显式连接。

### 4.5 Strengthened validation

保存前的 `_validate_map()` 除了重叠检查外，还检查：

- 是否存在重复的城市 ID。
- 每个 `force_connections` 中的目标 ID 都对应真实城市。
- 图是否全连通（将 `force_connections` 视为无向边进行 BFS）。
- `pos` 字段存在且为字典并包含 `x`/`y`。

任一检查失败即阻止保存并弹窗提示。

### 4.6 Atomic YAML write

`MapEditorYamlWriter.write_world_map()` 先写入 `path + ".tmp"`，确认无写入错误后通过 `DirAccess.rename_absolute` 重命名为目标文件。失败时清理临时文件，避免覆盖原始 `world_map.yaml`。

### 4.7 YAML escaping

`_escape()` 对包含 YAML 结构字符（`# : & * ! | > { } [ ] ,` 以及 `"`、反斜杠、换行、回车、制表符）的字符串进行双引号转义，防止城市名等字段破坏 YAML 结构。

## 5. Files Changed

| 文件 | 变更 |
|------|------|
| `godot/scripts/editor/MapEditor.gd` | 双向连接逻辑、删除确认、保存弹窗、加载迁移、增强验证 |
| `godot/scenes/editor/MapEditor.tscn` | 添加 `ConfirmationDialog` 与 `AcceptDialog` 节点 |
| `godot/scripts/editor/MapEditorPropertiesPanel.gd` | 添加 `set_title` 包装、类型提示 |
| `godot/scripts/editor/MapEditorYamlWriter.gd` | 原子写入、元数据保留、转义加固 |
| `godot/tests/test_map_editor_connections.gd` | 连接对称性自动化测试 |

## 6. Testing

- 在属性面板勾选 A→B，保存 YAML，确认 A 和 B 的 `force_connections` 都包含对方。
- 取消勾选，确认双方列表都已移除对方。
- 删除有连接的城市，确认弹出警告对话框；取消后城市保留。
- 删除无连接的城市，确认弹出普通确认对话框。
- 将两个城市拖到一起后保存，确认弹出重叠错误弹窗且 YAML 未被覆盖。
- 使某个城市孤立后保存，确认弹出孤立错误弹窗。
- 正常保存后，确认弹出 `地图已保存`。
