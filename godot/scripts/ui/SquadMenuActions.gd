class_name SquadMenuActions
extends Node

signal saved
signal cancelled

var character_info: Label = null

@onready var squad_menu_data: SquadMenuData = $"../SquadMenuData"
@onready var lists: SquadMenuLists = $"../SquadMenuLists"

func initialize():
	var unassigned_panel = $"../Panel/VBoxContainer/UnassignedPanel"
	if unassigned_panel:
		character_info = unassigned_panel.get_node_or_null("CharacterInfoLabel")

	# Connect button signals
	var to_squad1 = $"../Panel/VBoxContainer/ButtonContainer/ToSquad1Button"
	var to_squad2 = $"../Panel/VBoxContainer/ButtonContainer/ToSquad2Button"
	var to_squad3 = $"../Panel/VBoxContainer/ButtonContainer/ToSquad3Button"
	var remove_btn = $"../Panel/VBoxContainer/ButtonContainer/RemoveButton"
	var save_btn = $"../Panel/VBoxContainer/ActionContainer/SaveButton"
	var cancel_btn = $"../Panel/VBoxContainer/ActionContainer/CancelButton"

	if to_squad1:
		to_squad1.pressed.connect(_on_move_to_squad1)
	if to_squad2:
		to_squad2.pressed.connect(_on_move_to_squad2)
	if to_squad3:
		to_squad3.pressed.connect(_on_move_to_squad3)
	if remove_btn:
		remove_btn.pressed.connect(_on_remove_from_squad)
	if save_btn:
		save_btn.pressed.connect(_on_save)
	if cancel_btn:
		cancel_btn.pressed.connect(_on_cancel)

func update_character_info():
	if squad_menu_data.selected_character == null:
		_set_info_text("Select a character to view details")
		return

	var selected_character = squad_menu_data.selected_character
	var info = "[b]%s[/b] Lv.%d %s\n" % [
		selected_character.character_name,
		selected_character.level,
		GameConstants.CharacterClass.keys()[selected_character.character_class]
	]
	info += "HP: %d/%d | ATK: %d | DEF: %d | SPD: %d\n" % [
		selected_character.current_hp,
		selected_character.max_hp,
		selected_character.attack,
		selected_character.defense,
		selected_character.speed
	]
	info += "Soldiers: %d/%d | Weapon: %s" % [
		selected_character.soldiers,
		selected_character.max_soldiers,
		selected_character.weapon_type
	]
	_set_info_text(info)

func _set_info_text(text: String):
	if character_info != null and is_instance_valid(character_info):
		character_info.text = text

func _on_move_to_squad1():
	_move_and_refresh(0)

func _on_move_to_squad2():
	_move_and_refresh(1)

func _on_move_to_squad3():
	_move_and_refresh(2)

func _move_and_refresh(squad_index: int):
	var error = squad_menu_data.move_character_to_squad(squad_index)
	if error != "":
		_set_info_text(error)
	else:
		lists.refresh_lists()

func _on_remove_from_squad():
	squad_menu_data.remove_from_squad()
	lists.refresh_lists()

func _on_save():
	GameManager.update_squad_data(squad_menu_data.squads, squad_menu_data.unassigned)
	SaveManager.save_squads(squad_menu_data.squads, squad_menu_data.unassigned)
	$"..".visible = false
	saved.emit()

func _on_cancel():
	$"..".visible = false
	cancelled.emit()
