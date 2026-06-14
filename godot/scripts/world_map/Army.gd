class_name Army
extends Node2D

signal army_clicked(army: Army)
signal encounter_detected(army: Army, target: Army)

enum ArmyType {
	PLAYER_MAIN,
	PLAYER_SQUAD,
	ENEMY
}

enum ArmyState {
	IDLE,
	MOVING,
	IN_BATTLE
}

var army_id: String = ""
var army_name: String = "Army"
var army_type: ArmyType = ArmyType.PLAYER_SQUAD
var state: ArmyState = ArmyState.IDLE

var current_city_id: String = ""
var target_city_id: String = ""

var squad_data: Array[CharacterData] = []
var king: int = -1  # faction ID, like sanguoqunying2's king system

# Route following (like sanguoqunying2)
var route: Array[Vector2] = []
var route_cities: Array[String] = []  # city IDs corresponding to route points
const MOVE_SPEED: float = 100.0

# Visual
var army_sprite: Sprite2D
var selection_indicator: Control
var label: Label

const ARMY_COLORS = {
	ArmyType.PLAYER_MAIN: Color(0.2, 0.8, 0.2),
	ArmyType.PLAYER_SQUAD: Color(0.3, 0.7, 0.3),
	ArmyType.ENEMY: Color(0.9, 0.2, 0.2)
}

func _ready():
	setup_visual()

func setup_visual():
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

	label = Label.new()
	label.text = army_name
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = Vector2(-50, -40)
	label.custom_minimum_size = Vector2(100, 20)
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

func _move_along_route(delta):
	var target = route[0]
	var distance = position.distance_to(target)

	if distance < 2:
		# Reached waypoint
		position = target
		route.pop_front()
		if not route_cities.is_empty():
			current_city_id = route_cities.pop_front()

		if route.is_empty():
			# Arrived at destination
			state = ArmyState.IDLE
			label.text = army_name
	else:
		var direction = (target - position).normalized()
		position += direction * MOVE_SPEED * delta
		# Z-sorting based on Y position (like sanguoqunying2)
		z_index = int(position.y)

func set_route(waypoints: Array[Vector2], cities: Array[String]):
	route = waypoints.duplicate()
	route_cities = cities.duplicate()
	target_city_id = cities.back() if not cities.is_empty() else ""
	state = ArmyState.MOVING
	label.text = army_name + " →"

func get_encounter_position() -> Vector2:
	return position

func set_position_at_city(city_position: Vector2):
	position = city_position + Vector2(20, -20)

func get_total_soldiers() -> int:
	var total = 0
	for char in squad_data:
		total += char.soldiers
	return total

func get_leader_name() -> String:
	if squad_data.is_empty():
		return "Unknown"
	return squad_data[0].character_name
