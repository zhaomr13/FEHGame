class_name Army
extends Node2D

signal army_clicked(army: Army)

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

# Route following (like sanguoqunying2)
var route: Array[Vector2] = []
var route_cities: Array[String] = []
const MOVE_SPEED: float = 80.0

# Visual
var sprite: Sprite2D
var label: Label
var selection_indicator: Sprite2D

static var army_texture: Texture2D = null

func _ready():
	setup_visual()

func setup_visual():
	if army_texture == null:
		army_texture = load("res://assets/sanguo/army.png")

	sprite = Sprite2D.new()
	sprite.texture = army_texture
	sprite.region_enabled = true
	sprite.region_rect = Rect2(0, 0, 32, 32)
	sprite.scale = Vector2(1.5, 1.5)
	sprite.position = Vector2(-24, -48)
	sprite.z_index = 5
	add_child(sprite)

	if army_type == Army.ArmyType.ENEMY:
		sprite.modulate = Color(1.0, 0.5, 0.5)

	label = Label.new()
	label.text = army_name
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = Vector2(-50, -55)
	label.custom_minimum_size = Vector2(100, 20)
	label.z_index = 10
	add_child(label)

	selection_indicator = Sprite2D.new()
	selection_indicator.texture = army_texture
	selection_indicator.region_enabled = true
	selection_indicator.region_rect = Rect2(0, 0, 32, 32)
	selection_indicator.scale = Vector2(1.8, 1.8)
	selection_indicator.position = Vector2(-28, -52)
	selection_indicator.modulate = Color.YELLOW
	selection_indicator.visible = false
	selection_indicator.z_index = 4
	add_child(selection_indicator)

	var btn = Button.new()
	btn.custom_minimum_size = Vector2(48, 48)
	btn.size = Vector2(48, 48)
	btn.position = Vector2(-24, -48)
	btn.flat = true
	btn.modulate = Color(1, 1, 1, 0.01)
	btn.z_index = 100
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
		position = target
		route.pop_front()
		if not route_cities.is_empty():
			current_city_id = route_cities.pop_front()

		if route.is_empty():
			state = ArmyState.IDLE
			label.text = army_name
	else:
		var direction = (target - position).normalized()
		position += direction * MOVE_SPEED * delta
		z_index = int(position.y)

func set_route(waypoints: Array[Vector2], cities: Array[String]):
	route = waypoints.duplicate()
	route_cities = cities.duplicate()
	target_city_id = cities.back() if not cities.is_empty() else ""
	state = ArmyState.MOVING
	label.text = army_name + " →"

func set_position_at_city(city_position: Vector2):
	position = city_position + Vector2(20, -20)

func get_leader_name() -> String:
	if squad_data.is_empty():
		return "Unknown"
	return squad_data[0].character_name
