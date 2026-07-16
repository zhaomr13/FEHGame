class_name ArmySelectionPopup
extends Panel

signal army_selected(army: Army)
signal cancelled

@onready var item_list: ItemList = $VBoxContainer/ItemList
@onready var cancel_button: Button = $VBoxContainer/CancelButton

var _armies: Array[Army] = []

func _ready():
	cancel_button.pressed.connect(_on_cancel)
	item_list.item_selected.connect(_on_item_selected)
	visible = false

func setup(armies: Array[Army]):
	_armies = armies
	item_list.clear()
	for army in armies:
		if not is_instance_valid(army):
			continue
		var text = "%s (%d 人)" % [army.army_name, army.squad_data.size()]
		item_list.add_item(text)

func popup_at(center_position: Vector2):
	visible = true
	position = center_position - size / 2.0

func _on_item_selected(index: int):
	if index >= 0 and index < _armies.size():
		army_selected.emit(_armies[index])
	visible = false

func _on_cancel():
	visible = false
	cancelled.emit()
