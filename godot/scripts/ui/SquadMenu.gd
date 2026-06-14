extends Control

signal menu_closed(saved: bool)

@onready var data: SquadMenuData = $SquadMenuData
@onready var lists: SquadMenuLists = $SquadMenuLists
@onready var actions: SquadMenuActions = $SquadMenuActions

func _ready():
	visible = false
	call_deferred("_initialize")

func _initialize():
	lists.initialize_nodes()
	actions.initialize()

	lists.selection_changed.connect(_on_selection_changed)
	actions.saved.connect(_on_saved)
	actions.cancelled.connect(_on_cancelled)

func open_menu():
	data.load_squad_data()
	lists.refresh_lists()
	visible = true

func _on_selection_changed(_source: String, _index: int, _character: CharacterData):
	actions.update_character_info()

func _on_saved():
	visible = false
	menu_closed.emit(true)

func _on_cancelled():
	visible = false
	menu_closed.emit(false)

func get_active_squads() -> Array:
	return data.get_active_squads()

func get_squad_characters(squad_index: int) -> Array:
	return data.get_squad_characters(squad_index)
