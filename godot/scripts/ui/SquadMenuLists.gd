class_name SquadMenuLists
extends Node

signal selection_changed(source: String, index: int, character: CharacterData)

const SQUAD_PANEL_SCENE = preload("res://scenes/ui/SquadPanel.tscn")

var squad_panels: Array[SquadPanel] = []
var unassigned_list: ItemList = null

var _initialized: bool = false

@onready var squad_menu_data: SquadMenuData = $"../SquadMenuData"

func initialize_nodes():
	var panel = $"../Panel"
	if panel == null:
		return

	var vbox = panel.get_node_or_null("VBoxContainer")
	if vbox == null:
		return

	var scroll = vbox.get_node_or_null("SquadScrollContainer")
	var squad_container = null
	if scroll:
		squad_container = scroll.get_node_or_null("SquadContainer")

	if squad_container == null:
		# Fallback to the old fixed container name
		squad_container = vbox.get_node_or_null("SquadContainer")

	if squad_container:
		_create_squad_panels(squad_container)

	var unassigned_panel = vbox.get_node_or_null("UnassignedPanel")
	if unassigned_panel:
		unassigned_list = unassigned_panel.get_node_or_null("UnassignedList")
		if unassigned_list:
			unassigned_list.item_selected.connect(_on_unassigned_selected)

	_initialized = true

func _create_squad_panels(container: Control):
	# Clear any existing children in case this is re-initialized
	for child in container.get_children():
		child.queue_free()
	squad_panels.clear()

	for i in range(GameConstants.MAX_SQUADS):
		var panel = SQUAD_PANEL_SCENE.instantiate()
		container.add_child(panel)
		panel.setup(i, "Squad %d" % (i + 1))
		panel.item_selected.connect(_on_squad_selected)
		squad_panels.append(panel)

func _on_squad_selected(panel_index: int, item_index: int, character: CharacterData):
	_clear_other_selections("squad_%d" % panel_index)
	var source = "squad_%d" % panel_index
	squad_menu_data.select(source, item_index, character)
	selection_changed.emit(source, item_index, character)

func _on_unassigned_selected(index: int):
	_clear_other_selections("unassigned")
	if index >= 0 and index < squad_menu_data.unassigned.size():
		var char_data = squad_menu_data.unassigned[index]
		squad_menu_data.select("unassigned", index, char_data)
		selection_changed.emit("unassigned", index, char_data)

func _clear_other_selections(source: String):
	for panel in squad_panels:
		var panel_source = "squad_%d" % panel.panel_index
		if panel_source != source:
			panel.clear_selection()
	if source != "unassigned" and unassigned_list:
		unassigned_list.deselect_all()

func refresh_lists():
	if not _initialized:
		return

	for panel in squad_panels:
		var squad_index = panel.panel_index
		if squad_index >= 0 and squad_index < squad_menu_data.squads.size():
			panel.set_squad(squad_menu_data.squads[squad_index])
		else:
			panel.set_squad([])

	_refresh_unassigned_list()

func _refresh_unassigned_list():
	if unassigned_list == null:
		return
	unassigned_list.clear()
	for character in squad_menu_data.unassigned:
		var hp_text = "HP:%d/%d" % [character.current_hp, character.max_hp]
		unassigned_list.add_item("%s (%s)" % [character.character_name, hp_text])

func rebuild_panels():
	"""Rebuild panel array and refresh. Call after creating/disbanding squads."""
	var panel = $"../Panel"
	if panel == null:
		return
	var vbox = panel.get_node_or_null("VBoxContainer")
	if vbox == null:
		return
	var scroll = vbox.get_node_or_null("SquadScrollContainer")
	var squad_container = null
	if scroll:
		squad_container = scroll.get_node_or_null("SquadContainer")
	if squad_container == null:
		squad_container = vbox.get_node_or_null("SquadContainer")
	if squad_container:
		_create_squad_panels(squad_container)
	refresh_lists()
