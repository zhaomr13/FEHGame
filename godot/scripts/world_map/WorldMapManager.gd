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

@onready var ui: CanvasLayer = $WorldMapUI
@onready var background_sprite: Sprite2D = $Background
@onready var army_mgr: WorldMapArmyManager = $WorldMapArmyManager
@onready var map_data: MapDataManager = $MapDataManager

func _ready():
	setup_background()
	map_data.create_map_nodes()
	map_data.draw_connections()
	setup_ui()
	setup_battle_result_handler()
	map_data.node_clicked.connect(_on_node_clicked)
	army_mgr.army_selected.connect(_on_army_selected_by_mgr)
	army_mgr.move_completed.connect(_on_army_move_completed)


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
	var target = army_mgr.get_army_at_position(get_global_mouse_position())
	if target and target.army_type == Army.ArmyType.ENEMY:
		# 设置攻击计划
		if army_mgr.selected_army:
			army_mgr.selected_army.set_attack_plan(target)
			print("DEBUG: Set attack plan: ", army_mgr.selected_army.army_name, " -> ", target.army_name)
	elif target and target.army_type != Army.ArmyType.ENEMY:
		# 点击友军，切换选择
		army_mgr.set_selected_army(target)
	# 注意：释放在空白处不做任何操作，保持当前选择

func setup_faction_start(faction: String, start_city: String):
	current_faction = faction
	current_node_id = start_city

	# 清除旧数据
	army_mgr.clear_armies()
	map_data.map_nodes.clear()
	map_data.create_map_nodes()

	# 创建玩家军队 - 根据小队数据
	army_mgr.create_player_armies_from_squads(start_city)

	# 创建敌方军队
	army_mgr.create_enemy_armies(faction)

	# 初始化小队数据（如果为空）
	army_mgr.initialize_squads()

	# 开始计划阶段
	_start_planning_phase()

func setup_background():
	if background_sprite and background_sprite.texture:
		var bg_size = background_sprite.texture.get_size()
		background_sprite.position = Vector2(640, 360)
		var screen_size = Vector2(1280, 720)
		var scale_factor = max(screen_size.x / bg_size.x, screen_size.y / bg_size.y)
		if scale_factor > 1:
			background_sprite.scale = Vector2(scale_factor, scale_factor)

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

	for army in army_mgr.player_armies:
		army.clear_plan()

	if planning_ui:
		planning_ui.visible = true

func _on_end_planning_pressed():
	_start_execution_phase()

func _on_clear_plans_pressed():
	for army in army_mgr.player_armies:
		army.clear_plan()

func _start_execution_phase():
	current_phase = GamePhase.EXECUTION
	phase_changed.emit(current_phase)

	if planning_ui:
		planning_ui.visible = false

	execution_queue.clear()
	for army in army_mgr.player_armies:
		if army.is_planned:
			execution_queue.append(army)
	for army in army_mgr.enemy_armies:
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
	var city_pos = map_data.map_nodes[next_city].position
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
		for enemy in army_mgr.enemy_armies:
			if enemy.current_city_id == army.current_city_id:
				return enemy
	else:
		for player in army_mgr.player_armies:
			if player.current_city_id == army.current_city_id:
				return player
	return null

func _start_battle(attacker: Army, defender: Army):
	current_phase = GamePhase.BATTLE
	phase_changed.emit(current_phase)

	var battle_bg = map_data.select_battle_background(map_data.map_nodes[attacker.current_city_id])
	GameManager.start_battle_with_background(attacker.squad_data, defender.squad_data, battle_bg)

func _end_execution_phase():
	_process_enemy_turn()

func _process_enemy_turn():
	for enemy in army_mgr.enemy_armies:
		var current_city = enemy.current_city_id
		var connections = map_data.NODE_CONFIG[current_city].connections

		for connected_id in connections:
			for player in army_mgr.player_armies:
				if player.current_city_id == connected_id:
					enemy.set_planning_move(connected_id, [connected_id])
					break

	execution_queue.clear()
	for enemy in army_mgr.enemy_armies:
		if enemy.is_planned:
			execution_queue.append(enemy)

	_execute_next_move()

func _on_army_selected_by_mgr(army: Army):
	if current_phase != GamePhase.PLANNING:
		return

	# 只有玩家方军队可以被选中进行计划
	if army.army_type != Army.ArmyType.PLAYER_MAIN and army.army_type != Army.ArmyType.PLAYER_SQUAD:
		# 点击敌军 - 如果是已选中的玩家军队的目标，设置攻击
		if army_mgr.selected_army:
			army_mgr.selected_army.set_attack_plan(army)
			print("DEBUG: Set attack plan on enemy: ", army.army_name)
		return

	# 开始拖拽攻击线（只有玩家军队）
	_start_drag_plan(army)

func _start_drag_plan(army: Army):
	army_mgr.set_selected_army(army)
	is_dragging_plan = true
	drag_start_army = army
	print("DEBUG: Started drag plan for ", army.army_name)

func _on_node_clicked(node: MapNode):
	if current_phase != GamePhase.PLANNING:
		return

	# 如果有选中军队且正在拖拽，结束拖拽
	if is_dragging_plan:
		is_dragging_plan = false
		# 检查是否点击了城池，设置移动计划
		if army_mgr.selected_army and army_mgr.selected_army.current_city_id != node.node_id:
			var can_move = map_data.can_move_to(army_mgr.selected_army.current_city_id, node.node_id)
			if can_move:
				var path = map_data.find_path(army_mgr.selected_army.current_city_id, node.node_id)
				if not path.is_empty():
					var target_pos = node.position + Vector2(20, -20)
					army_mgr.selected_army.set_planning_move(node.node_id, path, target_pos)
					print("DEBUG: Planned move to ", node.node_name)
		return

	if not army_mgr.selected_army:
		# 只有己方城池可以打开菜单
		if map_data.NODE_CONFIG[node.node_id].faction == current_faction:
			open_city_menu(node)
		else:
			print("DEBUG: Cannot interact with enemy/neutral city: ", node.node_name)
		return

	var can_move = map_data.can_move_to(army_mgr.selected_army.current_city_id, node.node_id)
	if can_move:
		var path = map_data.find_path(army_mgr.selected_army.current_city_id, node.node_id)
		if not path.is_empty():
			var target_pos = node.position + Vector2(20, -20)
			army_mgr.selected_army.set_planning_move(node.node_id, path, target_pos)
			print("DEBUG: Planned move to ", node.node_name)
	else:
		print("DEBUG: Cannot move to ", node.node_name)

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
		army_mgr.refresh_player_armies(current_node_id)

func _on_deploy_army():
	city_menu.visible = false
	if army_mgr.selected_army:
		army_mgr.create_squad_from_main(army_mgr.selected_army)

func setup_battle_result_handler():
	GameManager.battle_ended.connect(_on_battle_ended)

func _on_battle_ended(victory: bool):
	current_phase = GamePhase.PLANNING
	phase_changed.emit(current_phase)

	if victory and army_mgr.selected_army:
		var city_id = army_mgr.selected_army.current_city_id
		map_data.NODE_CONFIG[city_id].faction = current_faction
		if map_data.map_nodes.has(city_id):
			map_data.map_nodes[city_id].set_faction_color(current_faction)

	GameManager.change_state(GameConstants.GameState.WORLD_MAP)
	visible = true
	_start_planning_phase()

func _on_army_move_completed(army: Army):
	"""处理军队移动完成"""
	print("DEBUG: Army move completed: ", army.army_name)
	army_mgr._update_army_position(army)
	# 检查是否需要继续执行下一个移动（在执行阶段）
	if current_phase == GamePhase.EXECUTION:
		_execute_next_move()
