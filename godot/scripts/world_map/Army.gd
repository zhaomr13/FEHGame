class_name Army
extends Node2D

signal army_clicked(army: Army)
signal move_completed(army: Army)

enum ArmyType {
	PLAYER_MAIN,    # 玩家主城队伍
	PLAYER_SQUAD,   # 玩家分出的队伍
	ENEMY           # 敌方队伍
}

enum ArmyState {
	IDLE,           # 待机
	PLANNING_MOVE,  # 计划移动中
	PLANNING_ATTACK,# 计划攻击中
	MOVING,         # 正在移动
	IN_BATTLE       # 战斗中
}

var army_id: String = ""
var army_name: String = "Army"
var army_type: ArmyType = ArmyType.PLAYER_SQUAD
var state: ArmyState = ArmyState.IDLE

# 当前位置
var current_city_id: String = ""
var target_city_id: String = ""

# 队伍数据
var squad_data: Array[CharacterData] = []
var max_soldiers: int = 600  # 每队最多6人x100兵

# 移动计划
var planned_path: Array[String] = []  # 计划经过的城池ID
var is_planned: bool = false
var target_army: Army = null  # 攻击目标

# 视觉
var army_sprite: Sprite2D
var selection_indicator: Control
var label: Label
var attack_line: Line2D  # 显示攻击计划的线条
var move_line: Line2D    # 显示移动计划的线条

# 移动动画
var target_position: Vector2 = Vector2.ZERO
var is_moving_animation: bool = false
const MOVE_SPEED: float = 150.0  # 像素/秒

const ARMY_COLORS = {
	ArmyType.PLAYER_MAIN: Color(0.2, 0.8, 0.2),   # 绿色
	ArmyType.PLAYER_SQUAD: Color(0.3, 0.7, 0.3),  # 浅绿
	ArmyType.ENEMY: Color(0.9, 0.2, 0.2)          # 红色
}

func _ready():
	setup_visual()

func setup_visual():
	# 创建军队图标（使用 Panel 实现圆形）
	var circle = Panel.new()
	circle.custom_minimum_size = Vector2(32, 32)
	circle.size = Vector2(32, 32)
	circle.position = Vector2(-16, -16)  # 居中
	circle.name = "CirclePanel"

	# 添加圆形遮罩效果
	var style = StyleBoxFlat.new()
	style.bg_color = ARMY_COLORS[army_type]
	style.corner_radius_top_left = 16
	style.corner_radius_top_right = 16
	style.corner_radius_bottom_left = 16
	style.corner_radius_bottom_right = 16
	circle.add_theme_stylebox_override("panel", style)

	add_child(circle)

	# 创建标签
	label = Label.new()
	label.text = army_name
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = Vector2(-50, -40)
	label.custom_minimum_size = Vector2(100, 20)
	add_child(label)

	# 创建选择指示器（默认隐藏）
	selection_indicator = Panel.new()
	selection_indicator.custom_minimum_size = Vector2(40, 40)
	selection_indicator.size = Vector2(40, 40)
	selection_indicator.position = Vector2(-20, -20)
	selection_indicator.visible = false
	selection_indicator.z_index = -1
	var select_style = StyleBoxFlat.new()
	select_style.bg_color = Color.YELLOW
	select_style.corner_radius_top_left = 20
	select_style.corner_radius_top_right = 20
	select_style.corner_radius_bottom_left = 20
	select_style.corner_radius_bottom_right = 20
	selection_indicator.add_theme_stylebox_override("panel", select_style)
	add_child(selection_indicator)

	# 创建攻击计划线条（默认隐藏）
	attack_line = Line2D.new()
	attack_line.width = 3.0
	attack_line.default_color = Color(1, 0.5, 0.2, 0.8)  # 橙红色
	attack_line.visible = false
	attack_line.z_index = 50
	add_child(attack_line)

	# 创建移动计划线条（默认隐藏）
	move_line = Line2D.new()
	move_line.width = 3.0
	move_line.default_color = Color(0.2, 0.8, 1, 0.8)  # 浅蓝色
	move_line.visible = false
	move_line.z_index = 49
	add_child(move_line)

	# 设置输入处理 - 使用按钮来检测点击
	var btn = Button.new()
	btn.custom_minimum_size = Vector2(40, 40)
	btn.size = Vector2(40, 40)
	btn.position = Vector2(-20, -20)
	btn.flat = true
	btn.modulate = Color(1, 1, 1, 0.01)  # 几乎透明但可点击
	btn.pressed.connect(_on_button_pressed)
	add_child(btn)

func _on_button_pressed():
	army_clicked.emit(self)

func set_selected(selected: bool):
	if selection_indicator:
		selection_indicator.visible = selected

func _process(delta):
	if is_moving_animation:
		var direction = (target_position - position).normalized()
		var distance = position.distance_to(target_position)
		var move_distance = MOVE_SPEED * delta

		if distance <= move_distance:
			position = target_position
			is_moving_animation = false
			_update_lines()
		else:
			position += direction * move_distance
			_update_lines()

func set_planning_move(target_city: String, path: Array[String], target_pos: Vector2 = Vector2.ZERO):
	target_city_id = target_city
	planned_path = path
	is_planned = true
	state = ArmyState.PLANNING_MOVE
	if target_pos != Vector2.ZERO:
		target_position = target_pos
		_update_move_line(target_pos)
	update_appearance()

func _update_move_line(target_pos: Vector2):
	"""更新移动目标指示线"""
	if move_line:
		move_line.clear_points()
		move_line.add_point(Vector2.ZERO)
		move_line.add_point(target_pos - position)
		move_line.visible = true

func _update_lines():
	"""更新所有连线"""
	if target_army and is_instance_valid(target_army):
		update_attack_line()
	if move_line and move_line.visible:
		# 需要重新计算移动线，但我们需要目标位置
		pass

func clear_plan():
	target_city_id = ""
	planned_path.clear()
	target_army = null
	is_planned = false
	state = ArmyState.IDLE
	if attack_line:
		attack_line.visible = false
	if move_line:
		move_line.visible = false
	update_appearance()

func set_attack_plan(target: Army):
	"""设置攻击目标"""
	target_army = target
	target_city_id = target.current_city_id
	is_planned = true
	state = ArmyState.PLANNING_ATTACK
	update_attack_line()
	update_appearance()

func update_attack_line():
	"""更新攻击目标指示线"""
	if target_army and is_instance_valid(target_army):
		attack_line.clear_points()
		attack_line.add_point(Vector2.ZERO)  # 从军队中心开始
		attack_line.add_point(target_army.position - position)  # 指向目标
		attack_line.visible = true
	else:
		attack_line.visible = false

func update_appearance():
	if is_planned:
		if state == ArmyState.PLANNING_ATTACK:
			label.text = army_name + " (攻击)"
		else:
			label.text = army_name + " (移动)"
	else:
		label.text = army_name

func start_move_animation(target_pos: Vector2):
	"""开始移动动画"""
	target_position = target_pos
	is_moving_animation = true
	state = ArmyState.MOVING
	# 隐藏计划线
	if move_line:
		move_line.visible = false

func execute_move() -> bool:
	"""执行计划的移动逻辑（由 WorldMapManager 调用）"""
	if not is_planned or planned_path.is_empty():
		return false

	# 注意：实际的移动动画由 start_move_animation 启动
	# 这个函数只更新状态

	# 如果到达最终目标，清除计划
	if planned_path.is_empty():
		is_planned = false
		state = ArmyState.IDLE
		target_city_id = ""
		if attack_line:
			attack_line.visible = false

	return true

func set_position_at_city(city_position: Vector2):
	position = city_position + Vector2(20, -20)  # 稍微偏移，避免重叠
	# 更新攻击线
	if target_army:
		update_attack_line()

func get_total_soldiers() -> int:
	var total = 0
	for char in squad_data:
		total += char.soldiers
	return total

func get_leader_name() -> String:
	if squad_data.is_empty():
		return "Unknown"
	return squad_data[0].character_name
