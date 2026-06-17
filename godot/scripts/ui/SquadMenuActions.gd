class_name SquadMenuActions
extends Node

signal saved
signal cancelled

var character_info: Label = null

# Optional overrides for tests. In production these stay null and resolve autoloads.
var game_manager: Node = null
var save_manager: Node = null

@onready var squad_menu_data: SquadMenuData = $"../SquadMenuData"
@onready var lists: SquadMenuLists = $"../SquadMenuLists"

func _get_gm():
	if game_manager != null and is_instance_valid(game_manager):
		return game_manager
	var gm = Engine.get_singleton("GameManager")
	if gm == null:
		gm = get_node_or_null("/root/GameManager")
	return gm

func _get_sm() -> Node:
	if save_manager != null:
		return save_manager
	return Engine.get_singleton("SaveManager")

func initialize():
	var unassigned_panel = $"../Panel/VBoxContainer/UnassignedPanel"
	if unassigned_panel:
		character_info = unassigned_panel.get_node_or_null("CharacterInfoLabel")

	# Connect button signals
	var create_btn = $"../Panel/VBoxContainer/ButtonContainer/CreateSquadButton"
	var disband_btn = $"../Panel/VBoxContainer/ButtonContainer/DisbandSquadButton"
	var move_btn = $"../Panel/VBoxContainer/ButtonContainer/MoveToSquadButton"
	var remove_btn = $"../Panel/VBoxContainer/ButtonContainer/RemoveButton"
	var save_btn = $"../Panel/VBoxContainer/ActionContainer/SaveButton"
	var cancel_btn = $"../Panel/VBoxContainer/ActionContainer/CancelButton"

	if create_btn:
		create_btn.pressed.connect(_on_create_squad)
	if disband_btn:
		disband_btn.pressed.connect(_on_disband_squad)
	if move_btn:
		move_btn.pressed.connect(_on_move_to_first_non_full_squad)
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

func _on_create_squad():
	var new_index = squad_menu_data.create_squad()
	if new_index < 0:
		_set_info_text("Cannot create more squads (max %d)" % GameConstants.MAX_SQUADS)
		return
	lists.rebuild_panels()
	_set_info_text("Created Squad %d" % (new_index + 1))

func _on_disband_squad():
	var squad_index = squad_menu_data.get_selected_squad_index()
	if squad_index < 0:
		_set_info_text("Select a character in a squad to disband it")
		return
	var result = squad_menu_data.disband_squad(squad_index)
	if not result:
		_set_info_text("Failed to disband squad")
		return
	lists.refresh_lists()
	_set_info_text("Disbanded Squad %d" % (squad_index + 1))

func _on_move_to_first_non_full_squad():
	var error = squad_menu_data.move_character_to_first_non_full_squad()
	if error != "":
		_set_info_text(error)
	else:
		lists.refresh_lists()

func _on_remove_from_squad():
	squad_menu_data.remove_from_squad()
	lists.refresh_lists()

func _on_save():
	squad_menu_data.remove_empty_squads()
	var gm = _get_gm()
	if gm:
		gm.update_squad_data(squad_menu_data.squads, squad_menu_data.unassigned)
	_get_sm().save_squads(squad_menu_data.squads, squad_menu_data.unassigned)
	$"..".visible = false
	saved.emit()

func _on_cancel():
	$"..".visible = false
	cancelled.emit()
