# Army-Squad 统一设计

## 核心目标

消除 Squad（小队）与 Army（军队）之间的概念分离。目前玩家通过 SquadMenu 编辑抽象的 Squad，然后 WorldMapManager 销毁并重建 Army。改为：**Army 即 Squad**，在城内直接管理。

## 数据模型

### 当前状态
```
player_army: Array[CharacterData]     # 全部角色
squad_data: Array[Array]              # 小队分配（角色名数组）
unassigned_units: Array[CharacterData] # 未分配
↓ WorldMapManager._create_player_armies_from_squads()
Army 节点（squad_data = 角色列表, squad_index = 索引）
```

### 目标状态
```
player_army: Array[CharacterData]     # 全部角色（不变）
unassigned_units: Array[CharacterData] # 未分配（不变）
army_data: Array[Array[CharacterData]] # 军队数据 = 旧 squad_data
↓ WorldMapManager 直接从 army_data 创建 Army
Army 节点（squad_data = 角色列表）
```

`army_data` 替代 `squad_data`，语义从"抽象小队"变成"军队配置"。保存/加载使用同样的角色 ID 匹配（后续版本可改进为 character_id）。

## 入口与界面

### 入口
城市菜单 → "编队"按钮 → 打开 **Army 管理面板**

### 界面布局
```
┌──────────────────────────────────────┐
│  [城市名] - 驻军管理                  │
├──────────┬────────────────┬─────────┤
│ 军队列表  │  选中军队角色   │  操作区   │
│ (左侧)   │  (中间)        │  (右侧)  │
│          │                │          │
│ ○ 第1队  │  Char A  [×]   │ [拆分选中]│
│ ● 第2队  │  Char B  [×]   │          │
│          │  Char C  [×]   │ [移动到▼]│
│ [+新建]  │  Char D  [×]   │  目标:   │
│          │                │  [第1队▼]│
│          │  ☐ 全选        │          │
│          │                │ [解散军队]│
├──────────┴────────────────┴─────────┤
│              [取消]  [保存]          │
└────────────────────────────────────┘
```

- **左侧**：城市内所有玩家 Army 列表 + 新建按钮（最多 10 个）。显示军队名和人数（如 "第1队 (4/6)"）。点击选中。
- **中间**：选中 Army 的角色列表，每行有 checkbox。支持全选。只显示角色名。
- **右侧**：操作按钮。拆分/移动/解散按钮在选中 Army 且有操作目标时才可按。

### 交互流程
1. 从城市菜单点击编队 → 菜单关闭，面板打开
2. 左侧显示驻军列表，默认选中第一个
3. 中间显示选中军队的角色，可多选
4. 执行操作后，列表即时刷新
5. 点击「保存」→ 同步到 GameManager 和世界地图，关闭面板
6. 点击「取消」→ 放弃所有修改，关闭面板，重新打开城市菜单

## 操作定义

### 新建军队
- 条件：当前军队数 < 10
- 行为：创建空 Army，添加到左侧列表末尾，默认选中

### 拆分选中
- 条件：选中了 ≥1 且 < 全部角色
- 行为：将选中的角色从当前 Army 分离，创建新 Army。原 Army 至少保留 1 人。

### 移动到指定军队
- 条件：选中了角色 AND 目标 Army 人数 + 选中人数 ≤ 6
- 行为：下拉选择目标 Army，将选中的角色移入。如果当前 Army 因此变空，自动解散。

### 解散军队
- 条件：当前 Army 非空
- 行为：将当前 Army 所有角色移入「未分配」。Army 从列表中移除。如果无 Army 剩余，自动新建一个空 Army。

## 数据同步（保存/关闭时）

1. 将 `army_data` 写回 `GameManager.squad_data`（保持兼容）
2. 将 `unassigned_units` 写回 `GameManager.unassigned_units`
3. **就地更新**世界地图上的 Army 节点（`squad_data` 字段），不销毁重建
4. 如果 Army 为空（0 人），从世界地图移除节点
5. 如果有新 Army（之前不存在），在世界地图创建节点
6. 保存 squad 配置文件到磁盘

## 文件变更范围

| 文件 | 变更 |
|---|---|
| `GameManager.gd` | `squad_data` 语义不变；确保 `update_squad_data` 正确同步 |
| `CityMenu.gd` | "编队"按钮连接新面板入口 |
| `ArmyManagePanel.tscn/gd` | **新增**：Army 管理面板（替代 SquadMenu） |
| `WorldMapManager.gd` | `_on_squad_menu_closed` 改为就地更新 Army 而非重建 |
| `SquadMenu.gd` 等 | 可以删除或保留作为备用 |

## 限制与约束

- 每 Army 最多 6 个角色，最多 10 个 Army
- 不能有空 Army（操作后自动清理）
- 只在城内可以编辑（进入/离开城市时 Army 不可编辑）
- 战斗中不可编辑
