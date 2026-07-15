class_name MapNode
extends Node2D

signal node_clicked(node: MapNode)

@export var node_id: String = ""
@export var node_type: GameConstants.NodeType = GameConstants.NodeType.CITY
@export var node_name: String = "Unknown"
@export var connections: Array = []
@export var is_explored: bool = false
@export var icon_size: String = "large"

var position_on_map: Vector2i
var current_faction: String = ""

@onready var sprite: Sprite2D = $Sprite2D
@onready var label: Label = $Label
@onready var area: Area2D = $Area2D

const FACTION_COLORS = {
	"askr": Color(0.2, 0.6, 1.0),
	"embla": Color(0.8, 0.2, 0.2),
	"nifl": Color(0.2, 0.8, 0.8),
	"muspell": Color(0.9, 0.5, 0.1),
	"": Color(0.5, 0.5, 0.5)  # Neutral - gray
}

const LARGE_CITY_TEXTURE = preload("res://assets/ui/large_city.png")
const SMALL_CITY_TEXTURE = preload("res://assets/ui/small_city.png")

const LARGE_CITY_SIZE = 48.0
const SMALL_CITY_SIZE = 32.0

func _ready():
	_setup_icon()
	if label:
		label.text = node_name
	update_visual()

	# Connect Area2D input event
	if area:
		area.input_event.connect(_on_area_input_event)

func _setup_icon():
	if not sprite:
		return
	match icon_size:
		"small":
			sprite.texture = SMALL_CITY_TEXTURE
			var tex_size = SMALL_CITY_TEXTURE.get_size()
			sprite.scale = Vector2(SMALL_CITY_SIZE / tex_size.x, SMALL_CITY_SIZE / tex_size.y)
		"large", _:
			sprite.texture = LARGE_CITY_TEXTURE
			var tex_size = LARGE_CITY_TEXTURE.get_size()
			sprite.scale = Vector2(LARGE_CITY_SIZE / tex_size.x, LARGE_CITY_SIZE / tex_size.y)

func _on_area_input_event(viewport, event, shape_idx):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		node_clicked.emit(self)

func set_faction_color(faction: String):
	"""Set the node color based on faction ownership"""
	current_faction = faction
	# Use call_deferred to ensure sprite is ready
	call_deferred("_apply_faction_color", faction)

func _apply_faction_color(faction: String):
	if sprite:
		var color = FACTION_COLORS.get(faction, FACTION_COLORS[""])
		sprite.modulate = color

func set_as_current():
	"""Mark this node as the current player position"""
	# Scale up to indicate current position
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(1.3, 1.3), 0.3)

func clear_current_marker():
	"""Remove current position marker"""
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.3)

func update_visual():
	if not is_explored:
		sprite.modulate = Color(0.3, 0.3, 0.3, 1.0)
		if label:
			label.visible = false
	else:
		# Use faction color if set, otherwise default gold
		if current_faction == "":
			sprite.modulate = FACTION_COLORS[""]
		if label:
			label.visible = true

func explore():
	is_explored = true
	update_visual()
