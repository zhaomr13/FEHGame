class_name MapNode
extends Node2D

signal node_clicked(node: MapNode)

@export var node_id: String = ""
@export var node_type: GameConstants.NodeType = GameConstants.NodeType.CITY
@export var node_name: String = "Unknown"
@export var connections: Array = []
@export var is_explored: bool = false

var position_on_map: Vector2i

@onready var sprite: Sprite2D = $Sprite2D
@onready var label: Label = $Label

func _ready():
    if label:
        label.text = node_name
    update_visual()

func update_visual():
    if not is_explored:
        sprite.modulate = Color(0.3, 0.3, 0.3, 1.0)
        if label:
            label.visible = false
    else:
        sprite.modulate = Color.WHITE
        if label:
            label.visible = true

func _input_event(viewport, event, shape_idx):
    if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        node_clicked.emit(self)

func explore():
    is_explored = true
    update_visual()
