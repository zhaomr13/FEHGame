class_name Army
extends Node2D

signal army_clicked(army: Army)
signal movement_finished(army: Army)

enum ArmyType {
	PLAYER_MAIN,
	PLAYER_SQUAD,
	ENEMY
}

enum ArmyState {
	IDLE,
	PLANNED,
	MOVING,
	IN_BATTLE
}

var army_id: String = ""
var army_name: String = "Army"
var army_type: ArmyType = ArmyType.PLAYER_SQUAD
var state: ArmyState = ArmyState.IDLE

var current_city_id: String = ""
var target_city_id: String = ""
# Between-cities tracking: when army leaves a city for another
var from_city_id: String = ""
var to_city_id: String = ""
var squad_data: Array[CharacterData] = []
var squad_index: int = -1  # Index into GameManager.squad_data, -1 if not linked

# Planned route (set during planning, executed on End Planning)
var planned_route: Array[Vector2] = []
var planned_cities: Array[String] = []

# Active route (followed during execution)
var route: Array[Vector2] = []
var route_cities: Array[String] = []
const MOVE_SPEED: float = 80.0

# Visual
var label: Label
var selection_indicator: Panel
var plan_line: Line2D

const ARMY_COLORS = {
	ArmyType.PLAYER_MAIN: Color(0.2, 0.8, 0.2),
	ArmyType.PLAYER_SQUAD: Color(0.3, 0.7, 0.3),
	ArmyType.ENEMY: Color(0.9, 0.2, 0.2)
}

func _ready():
	setup_visual()

func setup_visual():
	# Main circle with faction color
	var circle = Panel.new()
	circle.custom_minimum_size = Vector2(32, 32)
	circle.size = Vector2(32, 32)
	circle.position = Vector2(-16, -16)
	circle.name = "CirclePanel"
	var style = StyleBoxFlat.new()
	style.bg_color = ARMY_COLORS[army_type]
	style.corner_radius_top_left = 16
	style.corner_radius_top_right = 16
	style.corner_radius_bottom_left = 16
	style.corner_radius_bottom_right = 16
	circle.add_theme_stylebox_override("panel", style)
	add_child(circle)

	# Border ring to make armies more visible
	var border = Panel.new()
	border.custom_minimum_size = Vector2(36, 36)
	border.size = Vector2(36, 36)
	border.position = Vector2(-18, -18)
	border.z_index = -1
	border.name = "BorderPanel"
	var border_style = StyleBoxFlat.new()
	border_style.bg_color = Color(0, 0, 0, 0.5)
	border_style.corner_radius_top_left = 18
	border_style.corner_radius_top_right = 18
	border_style.corner_radius_bottom_left = 18
	border_style.corner_radius_bottom_right = 18
	border.add_theme_stylebox_override("panel", border_style)
	add_child(border)

	# Plan line (shows planned route during planning phase, player only)
	plan_line = Line2D.new()
	plan_line.width = 3.0
	plan_line.default_color = Color(0.2, 0.8, 1, 0.8)
	plan_line.visible = false
	plan_line.z_index = 49
	add_child(plan_line)

	# Label with army-type-specific color
	label = Label.new()
	label.text = army_name
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = Vector2(-50, -40)
	label.custom_minimum_size = Vector2(100, 20)
	if army_type == Army.ArmyType.ENEMY:
		label.modulate = Color.RED
	else:
		label.modulate = Color(0.2, 0.7, 0.2)
	add_child(label)

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

	var btn = Button.new()
	btn.custom_minimum_size = Vector2(40, 40)
	btn.size = Vector2(40, 40)
	btn.position = Vector2(-20, -20)
	btn.flat = true
	btn.modulate = Color(1, 1, 1, 0.01)
	btn.pressed.connect(_on_button_pressed)
	add_child(btn)

func _on_button_pressed():
	army_clicked.emit(self)

func set_selected(selected: bool):
	if selection_indicator:
		selection_indicator.visible = selected

func _process(delta):
	if state == ArmyState.MOVING and not route.is_empty():
		_move_along_route(delta)
	# Update plan line position (relative)
	if plan_line.visible and not planned_route.is_empty():
		_update_plan_line()

func _move_along_route(delta):
	var target = route[0]
	var distance = position.distance_to(target)

	if distance < 2:
		position = target
		route.pop_front()
		if not route_cities.is_empty():
			current_city_id = route_cities.pop_front()
		if route.is_empty():
			state = ArmyState.IDLE
			label.text = army_name
			movement_finished.emit(self)
	else:
		var direction = (target - position).normalized()
		position += direction * MOVE_SPEED * delta
		z_index = int(position.y)

func set_route(waypoints: Array[Vector2], cities: Array[String]):
	# Store as planned - don't move yet
	planned_route = waypoints.duplicate()
	planned_cities = cities.duplicate()
	target_city_id = cities.back() if not cities.is_empty() else ""
	from_city_id = current_city_id
	to_city_id = target_city_id
	state = ArmyState.PLANNED
	label.text = army_name + " →"
	_update_plan_line()

func _update_plan_line():
	if army_type == Army.ArmyType.ENEMY:
		return
	plan_line.clear_points()
	plan_line.add_point(Vector2.ZERO)
	if planned_route.size() > 0:
		plan_line.add_point(planned_route.back() - position)
	plan_line.visible = true

func execute_plan():
	# Move planned route to active route
	if planned_route.is_empty():
		return
	route = planned_route.duplicate()
	route_cities = planned_cities.duplicate()
	planned_route.clear()
	planned_cities.clear()
	plan_line.visible = false
	state = ArmyState.MOVING

func clear_plan():
	planned_route.clear()
	planned_cities.clear()
	plan_line.visible = false
	target_city_id = ""
	state = ArmyState.IDLE
	label.text = army_name

func has_plan() -> bool:
	return state == ArmyState.PLANNED

func set_position_at_city(city_position: Vector2):
	position = city_position + Vector2(20, -20)

func get_leader_name() -> String:
	if squad_data.is_empty():
		return "Unknown"
	return squad_data[0].character_name
