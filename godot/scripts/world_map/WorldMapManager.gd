class_name WorldMapManager
extends Node2D

signal turn_ended
signal phase_changed(new_phase: int)
signal army_selected(army: Army)
signal target_selected(target_army: Army)

enum GamePhase {
	PLANNING,    # 计划阶段：玩家安排所有移动和攻击
	EXECUTION,   # 执行阶段：移动军队并处理遭遇
	BATTLE       # 战斗阶段：正在进行战斗
}

@export var current_node_id: String = "city_1"
@export var player_morale: int = 100
@export var turn_count: int = 1

# 地图数据
var map_nodes: Dictionary = {}
var connections: Dictionary = {}

# 军队系统
var player_armies: Array[Army] = []
var enemy_armies: Array[Army] = []
var selected_army: Army = null

# 拖拽攻击线
var is_dragging_plan: bool = false
var drag_start_army: Army = null

# 回合状态
var current_phase: GamePhase = GamePhase.PLANNING
var is_player_turn: bool = true
var execution_queue: Array[Army] = []
var current_faction: String = ""

# UI
var city_menu: Control = null
var squad_menu: Control = null
var planning_ui: Control = null

# 世界地图背景
const WORLD_BACKGROUNDS = {
	"world_map": "res://assets/world_map/backgrounds/world_map.png",
	"occupation": "res://assets/world_map/backgrounds/occupation_map.png",
}

# 城池配置
var NODE_CONFIG = {
	"city_1": {"name": "北方要塞", "type": GameConstants.NodeType.FORT, "pos": Vector2(400, 150), "connections": ["city_3"], "faction": "embla"},
	"city_2": {"name": "西风村", "type": GameConstants.NodeType.VILLAGE, "pos": Vector2(200, 280), "connections": ["city_3", "city_5"], "faction": ""},
	"city_3": {"name": "中央城", "type": GameConstants.NodeType.CITY, "pos": Vector2(450, 280), "connections": ["city_1", "city_2", "city_4", "city_8"], "faction": "askr"},
	"city_4": {"name": "东影城", "type": GameConstants.NodeType.CITY, "pos": Vector2(700, 280), "connections": ["city_3", "city_6"], "faction": ""},
	"city_5": {"name": "南海村", "type": GameConstants.NodeType.VILLAGE, "pos": Vector2(150, 450), "connections": ["city_2", "city_7"], "faction": ""},
	"city_6": {"name": "东北要塞", "type": GameConstants.NodeType.FORT, "pos": Vector2(850, 200), "connections": ["city_4"], "faction": ""},
	"city_7": {"name": "河湾村", "type": GameConstants.NodeType.VILLAGE, "pos": Vector2(300, 500), "connections": ["city_5", "city_8"], "faction": ""},
	"city_8": {"name": "南方城", "type": GameConstants.NodeType.CITY, "pos": Vector2(500, 480), "connections": ["city_3", "city_7", "city_9", "city_10"], "faction": "nifl"},
	"city_9": {"name": "东岛村", "type": GameConstants.NodeType.VILLAGE, "pos": Vector2(750, 500), "connections": ["city_8"], "faction": ""},
	"city_10": {"name": "帝都", "type": GameConstants.NodeType.CITY, "pos": Vector2(550, 600), "connections": ["city_8"], "faction": ""}
}

@onready var ui: CanvasLayer = $WorldMapUI
@onready var background_sprite: Sprite2D = $Background
@onready var map_nodes_container: Node2D = $MapNodes
@onready var connections_node: Node2D = $Connections
@onready var armies_container: Node2D = $Armies

func _ready():
	setup_background()
	create_map_nodes()
	draw_connections()
	setup_ui()
	setup_battle_result_handler()


func _input(event):
	# 处理拖拽攻击线
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if not event.pressed and is_dragging_plan:
				# 鼠标释放，结束拖拽
				_end_drag_selection()

func _end_drag_selection():
	is_dragging_plan = false

	# 检查是否释放在敌军上
	var target = _get_army_at_position(get_global_mouse_position())
	if target and target.army_type == Army.ArmyType.ENEMY:
		# 设置攻击计划
		if selected_army:
			selected_army.set_attack_plan(target)
			print("DEBUG: Set attack plan: ", selected_army.army_name, " -> ", target.army_name)
	elif target and target.army_type != Army.ArmyType.ENEMY:
		# 点击友军，切换选择
		_set_selected_army(target)
	# 注意：释放在空白处不做任何操作，保持当前选择

func _get_army_at_position(pos: Vector2) -> Army:
	# 检查位置下的军队
	for army in player_armies:
		if army.position.distance_to(pos) < 30:
			return army
	for army in enemy_armies:
		if army.position.distance_to(pos) < 30:
			return army
	return null

func setup_faction_start(faction: String, start_city: String):
	current_faction = faction
	current_node_id = start_city

	# 清除旧数据
	_clear_armies()
	map_nodes.clear()
	create_map_nodes()

	# 创建玩家军队 - 根据小队数据
	_create_player_armies_from_squads(start_city)

	# 创建敌方军队
	_create_enemy_armies(faction)

	# 初始化小队数据（如果为空）
	_initialize_squads()

	# 开始计划阶段
	_start_planning_phase()

func _clear_armies():
	for army in player_armies:
		if is_instance_valid(army):
			army.queue_free()
	player_armies.clear()

	for army in enemy_armies:
		if is_instance_valid(army):
			army.queue_free()
	enemy_armies.clear()

func _create_player_armies_from_squads(start_city: String):
	"""根据 GameManager 的小队数据创建军队"""
	var squad_index = 0

	for squad_data in GameManager.squad_data:
		if squad_data.is_empty():
			squad_index += 1
			continue

		var army = Army.new()
		army.army_id = "player_squad_%d" % squad_index
		army.army_name = "Squad %d" % (squad_index + 1) if squad_index > 0 else "Main Army"
		army.army_type = Army.ArmyType.PLAYER_MAIN if squad_index == 0 else Army.ArmyType.PLAYER_SQUAD
		army.current_city_id = start_city
		army.squad_data = _convert_squad_data(squad_data)
		army.army_clicked.connect(_on_army_clicked)
		army.move_completed.connect(_on_army_move_completed)

		armies_container.add_child(army)
		player_armies.append(army)
		_update_army_position(army)

		squad_index += 1

	# 如果没有创建任何军队，创建一个默认的
	if player_armies.is_empty():
		_create_default_player_army(start_city)

func _convert_squad_data(squad_data: Array) -> Array[CharacterData]:
	"""将小队数据转换为 CharacterData 数组"""
	var result: Array[CharacterData] = []
	for char in squad_data:
		if char is CharacterData:
			result.append(char)
	return result

func _create_default_player_army(start_city: String):
	"""创建默认玩家军队（如果没有小队数据）"""
	var main_army = Army.new()
	main_army.army_id = "player_main"
	main_army.army_name = "Main Army"
	main_army.army_type = Army.ArmyType.PLAYER_MAIN
	main_army.current_city_id = start_city
	main_army.squad_data = _get_squad_characters(0)
	main_army.army_clicked.connect(_on_army_clicked)
	main_army.move_completed.connect(_on_army_move_completed)

	armies_container.add_child(main_army)
	player_armies.append(main_army)
	_update_army_position(main_army)

func _create_enemy_armies(player_faction: String):
	# Create armies for each faction that isn't the player
	var all_factions = ["askr", "embla", "nifl", "muspell"]

	for faction in all_factions:
		if faction == player_faction:
			continue

		# Get characters belonging to this faction
		var faction_chars = GameManager.get_characters_by_faction(faction)
		if faction_chars.is_empty():
			continue

		# Find a city owned by this faction
		for city_id in NODE_CONFIG.keys():
			if NODE_CONFIG[city_id].faction == faction:
				var enemy_army = Army.new()
				enemy_army.army_id = "enemy_%s" % faction
				enemy_army.army_name = faction.capitalize()
				enemy_army.army_type = Army.ArmyType.ENEMY
				enemy_army.current_city_id = city_id
				# Use real characters from this faction
				enemy_army.squad_data = _get_faction_squad(faction, faction_chars)
				enemy_army.army_clicked.connect(_on_army_clicked)

				armies_container.add_child(enemy_army)
				enemy_armies.append(enemy_army)
				_update_army_position(enemy_army)
				break

func _get_faction_squad(faction: String, faction_chars: Array[CharacterData]) -> Array[CharacterData]:
	"""Get up to 3 characters from a faction for their army"""
	var squad: Array[CharacterData] = []
	# Take up to 3 characters from the faction
	for i in range(min(3, faction_chars.size())):
		squad.append(faction_chars[i])
	return squad

func _get_squad_characters(squad_index: int) -> Array[CharacterData]:
	if squad_index < GameManager.squad_data.size():
		var squad: Array[CharacterData] = []
		for char in GameManager.squad_data[squad_index]:
			if char is CharacterData:
				squad.append(char)
		return squad
	return []

func _initialize_squads():
	var total_in_squads = 0
	for squad in GameManager.squad_data:
		total_in_squads += squad.size()
	if total_in_squads == 0 and GameManager.unassigned_units.size() == 0:
		GameManager.initialize_squads()

func _update_army_position(army: Army):
	if map_nodes.has(army.current_city_id):
		var city_pos = map_nodes[army.current_city_id].position
		army.set_position_at_city(city_pos)

func setup_background():
	if background_sprite and background_sprite.texture:
		var bg_size = background_sprite.texture.get_size()
		background_sprite.position = Vector2(640, 360)
		var screen_size = Vector2(1280, 720)
		var scale_factor = max(screen_size.x / bg_size.x, screen_size.y / bg_size.y)
		if scale_factor > 1:
			background_sprite.scale = Vector2(scale_factor, scale_factor)

func create_map_nodes():
	for node_id in NODE_CONFIG.keys():
		var config = NODE_CONFIG[node_id]
		var node = preload("res://scenes/world_map/MapNode.tscn").instantiate()
		node.node_id = node_id
		node.node_name = config.name
		node.node_type = config.type
		node.position = config.pos
		node.connections = config.connections
		node.set_faction_color(config.faction)
		node.node_clicked.connect(_on_node_clicked)
		map_nodes_container.add_child(node)
		map_nodes[node_id] = node

func draw_connections():
	var line_color = Color(0.8, 0.7, 0.4, 0.6)
	var line_width = 3.0

	for node_id in NODE_CONFIG.keys():
		var config = NODE_CONFIG[node_id]
		var start_pos = config.pos

		for connected_id in config.connections:
			if node_id < connected_id:
				var connected_config = NODE_CONFIG[connected_id]
				var end_pos = connected_config.pos

				var line = Line2D.new()
				line.add_point(start_pos)
				line.add_point(end_pos)
				line.default_color = line_color
				line.width = line_width
				line.antialiased = true
				connections_node.add_child(line)

func setup_ui():
	setup_city_menu()
	setup_squad_menu()
	setup_planning_ui()

func setup_city_menu():
	city_menu = preload("res://scenes/ui/CityMenu.tscn").instantiate()
	ui.add_child(city_menu)
	city_menu.city_closed.connect(_on_city_closed)
	city_menu.deploy_army.connect(_on_deploy_army)
	city_menu.open_formation.connect(_on_open_formation)
	city_menu.visible = false

func setup_squad_menu():
	if squad_menu != null:
		return
	squad_menu = preload("res://scenes/ui/SquadMenu.tscn").instantiate()
	ui.add_child(squad_menu)
	squad_menu.menu_closed.connect(_on_squad_menu_closed)
	squad_menu.visible = false

func setup_planning_ui():
	planning_ui = Control.new()
	planning_ui.name = "PlanningUI"
	planning_ui.visible = false

	var panel = Panel.new()
	panel.name = "Panel"
	panel.set_anchors_preset(Control.PRESET_TOP_WIDE)
	panel.custom_minimum_size = Vector2(0, 80)

	var hbox = HBoxContainer.new()
	hbox.name = "ButtonContainer"
	hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER

	var end_planning_btn = Button.new()
	end_planning_btn.name = "EndPlanningButton"
	end_planning_btn.text = "End Planning Phase"
	end_planning_btn.custom_minimum_size = Vector2(200, 50)
	end_planning_btn.pressed.connect(_on_end_planning_pressed)

	var cancel_plan_btn = Button.new()
	cancel_plan_btn.name = "CancelPlanButton"
	cancel_plan_btn.text = "Clear All Plans"
	cancel_plan_btn.custom_minimum_size = Vector2(150, 50)
	cancel_plan_btn.pressed.connect(_on_clear_plans_pressed)

	hbox.add_child(end_planning_btn)
	hbox.add_child(cancel_plan_btn)
	panel.add_child(hbox)
	planning_ui.add_child(panel)

	ui.add_child(planning_ui)

func _start_planning_phase():
	current_phase = GamePhase.PLANNING
	phase_changed.emit(current_phase)

	for army in player_armies:
		army.clear_plan()

	if planning_ui:
		planning_ui.visible = true

func _on_end_planning_pressed():
	_start_execution_phase()

func _on_clear_plans_pressed():
	for army in player_armies:
		army.clear_plan()

func _start_execution_phase():
	current_phase = GamePhase.EXECUTION
	phase_changed.emit(current_phase)

	if planning_ui:
		planning_ui.visible = false

	execution_queue.clear()
	for army in player_armies:
		if army.is_planned:
			execution_queue.append(army)
	for army in enemy_armies:
		if army.is_planned:
			execution_queue.append(army)

	_execute_next_move()

func _execute_next_move():
	if execution_queue.is_empty():
		_end_execution_phase()
		return

	var army = execution_queue[0]
	execution_queue.pop_front()

	if not is_instance_valid(army):
		_execute_next_move()
		return

	# 检查是否还有移动路径
	if army.planned_path.is_empty():
		_execute_next_move()
		return

	# 执行移动计划
	var next_city = army.planned_path[0]
	army.planned_path.pop_front()
	army.current_city_id = next_city

	# 启动移动动画
	var city_pos = map_nodes[next_city].position
	army.start_move_animation(city_pos + Vector2(20, -20))

	# 等待动画完成
	await _wait_for_move_complete(army)

func _wait_for_move_complete(army: Army):
	"""等待军队移动动画完成"""
	while is_instance_valid(army) and army.is_moving_animation:
		await get_tree().create_timer(0.05).timeout

	if not is_instance_valid(army):
		_execute_next_move()
		return

	# 移动完成，检查遭遇
	var encounter = _check_encounter(army)
	if encounter:
		_start_battle(army, encounter)
		return

	# 继续执行计划（如果还有路径）
	if army.planned_path.size() > 0:
		execution_queue.push_front(army)

	_execute_next_move()

func _check_encounter(army: Army) -> Army:
	if army.army_type == Army.ArmyType.PLAYER_MAIN or army.army_type == Army.ArmyType.PLAYER_SQUAD:
		for enemy in enemy_armies:
			if enemy.current_city_id == army.current_city_id:
				return enemy
	else:
		for player in player_armies:
			if player.current_city_id == army.current_city_id:
				return player
	return null

func _start_battle(attacker: Army, defender: Army):
	current_phase = GamePhase.BATTLE
	phase_changed.emit(current_phase)

	var battle_bg = select_battle_background(map_nodes[attacker.current_city_id])
	GameManager.start_battle_with_background(attacker.squad_data, defender.squad_data, battle_bg)

func _end_execution_phase():
	_process_enemy_turn()

func _process_enemy_turn():
	for enemy in enemy_armies:
		var current_city = enemy.current_city_id
		var connections = NODE_CONFIG[current_city].connections

		for connected_id in connections:
			for player in player_armies:
				if player.current_city_id == connected_id:
					enemy.set_planning_move(connected_id, [connected_id])
					break

	execution_queue.clear()
	for enemy in enemy_armies:
		if enemy.is_planned:
			execution_queue.append(enemy)

	_execute_next_move()

func _on_army_clicked(army: Army):
	if current_phase != GamePhase.PLANNING:
		return

	# 只有玩家方军队可以被选中进行计划
	if army.army_type != Army.ArmyType.PLAYER_MAIN and army.army_type != Army.ArmyType.PLAYER_SQUAD:
		# 点击敌军 - 如果是已选中的玩家军队的目标，设置攻击
		if selected_army:
			selected_army.set_attack_plan(army)
			print("DEBUG: Set attack plan on enemy: ", army.army_name)
		return

	# 开始拖拽攻击线（只有玩家军队）
	_start_drag_plan(army)

func _start_drag_plan(army: Army):
	_set_selected_army(army)
	is_dragging_plan = true
	drag_start_army = army
	print("DEBUG: Started drag plan for ", army.army_name)

func _set_selected_army(army: Army):
	if selected_army and is_instance_valid(selected_army):
		selected_army.set_selected(false)

	selected_army = army
	if selected_army:
		selected_army.set_selected(true)
		army_selected.emit(selected_army)

func _on_node_clicked(node: MapNode):
	if current_phase != GamePhase.PLANNING:
		return

	# 如果有选中军队且正在拖拽，结束拖拽
	if is_dragging_plan:
		is_dragging_plan = false
		# 检查是否点击了城池，设置移动计划
		if selected_army and selected_army.current_city_id != node.node_id:
			var can_move = _can_move_to(selected_army, node.node_id)
			if can_move:
				var path = _find_path(selected_army.current_city_id, node.node_id)
				if not path.is_empty():
					var target_pos = node.position + Vector2(20, -20)
					selected_army.set_planning_move(node.node_id, path, target_pos)
					print("DEBUG: Planned move to ", node.node_name)
			return

	if not selected_army:
		# 只有己方城池可以打开菜单
		if NODE_CONFIG[node.node_id].faction == current_faction:
			open_city_menu(node)
		else:
			print("DEBUG: Cannot interact with enemy/neutral city: ", node.node_name)
		return

	var can_move = _can_move_to(selected_army, node.node_id)
	if can_move:
		var path = _find_path(selected_army.current_city_id, node.node_id)
		if not path.is_empty():
			var target_pos = node.position + Vector2(20, -20)
			selected_army.set_planning_move(node.node_id, path, target_pos)
			print("DEBUG: Planned move to ", node.node_name)
	else:
		print("DEBUG: Cannot move to ", node.node_name)

func _can_move_to(army: Army, target_city_id: String) -> bool:
	var current_id = army.current_city_id
	if current_id == target_city_id:
		return false
	if NODE_CONFIG[current_id].connections.has(target_city_id):
		return true
	return false

func _find_path(from_id: String, to_id: String) -> Array[String]:
	if NODE_CONFIG[from_id].connections.has(to_id):
		return [to_id]
	return []

func open_city_menu(node: MapNode):
	if city_menu:
		city_menu.show_city(node.node_name, node.node_type, false)

func _on_city_closed():
	pass

func _on_open_formation():
	if squad_menu:
		squad_menu.open_menu()

func _on_squad_menu_closed(saved: bool):
	if city_menu:
		city_menu.visible = true

	if saved:
		if squad_menu:
			GameManager.update_squad_data(squad_menu.squads, squad_menu.unassigned)
		# 重新创建军队以反映小队变化
		_refresh_player_armies()

func _refresh_player_armies():
	"""重新创建玩家军队以反映小队变化"""
	var current_city = current_node_id
	if selected_army:
		current_city = selected_army.current_city_id

	_clear_armies()
	_create_player_armies_from_squads(current_city)

func _on_deploy_army():
	city_menu.visible = false
	if selected_army:
		_create_squad_from_main(selected_army)

func _create_squad_from_main(main_army: Army):
	if GameManager.squad_data.size() < 2:
		return

	var squad_index = 1
	var squad_chars = _get_squad_characters(squad_index)
	if squad_chars.is_empty():
		return

	var new_army = Army.new()
	new_army.army_id = "player_squad_%d" % player_armies.size()
	new_army.army_name = "Squad %d" % (squad_index + 1)
	new_army.army_type = Army.ArmyType.PLAYER_SQUAD
	new_army.current_city_id = main_army.current_city_id
	new_army.squad_data = squad_chars
	new_army.army_clicked.connect(_on_army_clicked)
	new_army.move_completed.connect(_on_army_move_completed)

	armies_container.add_child(new_army)
	player_armies.append(new_army)
	_update_army_position(new_army)

func setup_battle_result_handler():
	GameManager.battle_ended.connect(_on_battle_ended)

func _on_battle_ended(victory: bool):
	current_phase = GamePhase.PLANNING
	phase_changed.emit(current_phase)

	if victory and selected_army:
		var city_id = selected_army.current_city_id
		NODE_CONFIG[city_id].faction = current_faction
		if map_nodes.has(city_id):
			map_nodes[city_id].set_faction_color(current_faction)

	GameManager.change_state(GameConstants.GameState.WORLD_MAP)
	visible = true
	_start_planning_phase()

func select_battle_background(node: MapNode) -> String:
	match node.node_type:
		GameConstants.NodeType.CITY:
			return "inside"
		GameConstants.NodeType.FORT:
			return "brave_attack"
		GameConstants.NodeType.VILLAGE:
			return "plain_forest"
		_:
			var outdoor_bgs = ["plain", "forest", "river", "plain_forest"]
			return outdoor_bgs[randi() % outdoor_bgs.size()]

func _on_army_move_completed(army: Army):
	"""处理军队移动完成"""
	print("DEBUG: Army move completed: ", army.army_name)
	_update_army_position(army)
	# 检查是否需要继续执行下一个移动（在执行阶段）
	if current_phase == GamePhase.EXECUTION:
		_execute_next_move()
