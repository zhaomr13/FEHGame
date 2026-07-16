class_name SquadPanel
extends VBoxContainer

signal item_selected(panel_index: int, item_index: int, character: CharacterData)

var panel_index: int = 0

@onready var title_label: Label = $TitleLabel
@onready var item_list: ItemList = $ItemList
@onready var count_label: Label = $CountLabel

func _ready():
	item_list.item_selected.connect(_on_item_selected)

func setup(index: int, title: String):
	panel_index = index
	if title_label:
		title_label.text = title

func set_squad(squad: Array):
	if item_list == null:
		return
	item_list.clear()
	for character in squad:
		var hp_text = "HP:%d/%d" % [character.current_hp, character.max_hp]
		var item_index = item_list.add_item("%s (%s)" % [character.character_name, hp_text])
		item_list.set_item_metadata(item_index, character)
	_update_count_label(squad.size())

func _update_count_label(count: int):
	if count_label == null:
		return
	count_label.text = "%d/%d 人" % [count, GameConstants.MAX_SQUAD_SIZE]
	if count == 0:
		count_label.modulate = Color.GRAY
	elif count >= GameConstants.MAX_SQUAD_SIZE:
		count_label.modulate = Color.RED
	else:
		count_label.modulate = Color.GREEN

func clear_selection():
	if item_list:
		item_list.deselect_all()

func get_squad_size() -> int:
	if item_list:
		return item_list.get_item_count()
	return 0

func _on_item_selected(item_index: int):
	if item_index < 0 or item_index >= item_list.get_item_count():
		return
	var character = item_list.get_item_metadata(item_index)
	if character is CharacterData:
		item_selected.emit(panel_index, item_index, character)
