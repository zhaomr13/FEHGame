class_name MapNode
extends Node2D

signal node_clicked(node: MapNode)

@export var node_id: String = ""
@export var node_type: GameConstants.NodeType = GameConstants.NodeType.CITY
@export var node_name: String = "Unknown"
@export var connections: Array = []
@export var is_explored: bool = false

var position_on_map: Vector2i
var current_faction: String = ""

@onready var sprite: Sprite2D = $Sprite2D
@onready var label: Label = $Label
@onready var area: Area2D = $Area2D

const FACTION_COLORS = {
	"askr": Color(0.2, 0.6, 1.0),
	"embla": Color(0.8, 0.2, 0.2),
	"nifl": Color(0.2, 0.8, 0.8),
	"": Color(0.9, 0.8, 0.3)  # Neutral - gold
}

func _ready():
	if label:
		label.text = node_name
	update_visual()

	# Connect Area2D input event
	if area:
		area.input_event.connect(_on_area_input_event)

func _on_area_input_event(viewport, event, shape_idx):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		node_clicked.emit(self)

func set_faction_color(faction: String):
	"""Set the node color based on faction ownership"""
	current_faction = faction
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
