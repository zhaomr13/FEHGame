class_name MapEditorPropertiesPanel
extends Panel

signal name_changed(new_name: String)
signal type_changed(new_type: String)
signal connection_toggled(city_id: String, connected: bool)

@onready var title_label: Label = $VBox/TitleLabel
@onready var name_edit: LineEdit = $VBox/NameEdit
@onready var type_option: OptionButton = $VBox/TypeOption
@onready var connections_list: VBoxContainer = $VBox/Scroll/ConnectionsList

var _current_city_id: String = ""

func _ready():
	name_edit.text_submitted.connect(func(text: String): name_changed.emit(text))
	name_edit.focus_exited.connect(func(): name_changed.emit(name_edit.text))
	type_option.item_selected.connect(func(index: int): type_changed.emit(type_option.get_item_text(index)))

func set_city(city_data: Dictionary, all_cities: Array[Dictionary]):
	_current_city_id = city_data.get("id", "")
	set_title(city_data.get("name", ""))
	name_edit.text = city_data.get("name", "")

	var type = city_data.get("type", "city")
	for i in range(type_option.item_count):
		if type_option.get_item_text(i) == type:
			type_option.select(i)
			break

	for child in connections_list.get_children():
		child.queue_free()

	var connections: Array = city_data.get("force_connections", [])
	for other in all_cities:
		var other_id = other.get("id", "")
		if other_id == _current_city_id:
			continue
		var cb := CheckBox.new()
		cb.text = other.get("name", other_id)
		cb.button_pressed = connections.has(other_id)
		cb.toggled.connect(func(pressed: bool): connection_toggled.emit(other_id, pressed))
		connections_list.add_child(cb)

func set_title(city_name: String):
	title_label.text = "属性: %s" % city_name

func clear():
	_current_city_id = ""
	title_label.text = "属性"
	name_edit.text = ""
	for child in connections_list.get_children():
		child.queue_free()
