class_name SquadMenuLists
extends Node

signal selection_changed(source: String, index: int, character: CharacterData)

var squad1_list: ItemList = null
var squad2_list: ItemList = null
var squad3_list: ItemList = null
var unassigned_list: ItemList = null

var squad1_count: Label = null
var squad2_count: Label = null
var squad3_count: Label = null

var _initialized: bool = false

@onready var squad_menu_data: SquadMenuData = $"../SquadMenuData"

func initialize_nodes():
	var panel = $"../Panel"
	if panel == null:
		return

	var vbox = panel.get_node_or_null("VBoxContainer")
	if vbox == null:
		return

	var squad_container = vbox.get_node_or_null("SquadContainer")

	var squad1_panel = null
	if squad_container:
		squad1_panel = squad_container.get_node_or_null("Squad1Panel")
	if squad1_panel:
		squad1_list = squad1_panel.get_node_or_null("Squad1List")
		squad1_count = squad1_panel.get_node_or_null("Squad1Count")

	var squad2_panel = null
	if squad_container:
		squad2_panel = squad_container.get_node_or_null("Squad2Panel")
	if squad2_panel:
		squad2_list = squad2_panel.get_node_or_null("Squad2List")
		squad2_count = squad2_panel.get_node_or_null("Squad2Count")

	var squad3_panel = null
	if squad_container:
		squad3_panel = squad_container.get_node_or_null("Squad3Panel")
	if squad3_panel:
		squad3_list = squad3_panel.get_node_or_null("Squad3List")
		squad3_count = squad3_panel.get_node_or_null("Squad3Count")

	var unassigned_panel = vbox.get_node_or_null("UnassignedPanel")
	if unassigned_panel:
		unassigned_list = unassigned_panel.get_node_or_null("UnassignedList")

	_connect_signals()
	_initialized = true

func _connect_signals():
	if squad1_list:
		squad1_list.item_selected.connect(func(i): _on_squad_selected("squad1", 0, i))
	if squad2_list:
		squad2_list.item_selected.connect(func(i): _on_squad_selected("squad2", 1, i))
	if squad3_list:
		squad3_list.item_selected.connect(func(i): _on_squad_selected("squad3", 2, i))
	if unassigned_list:
		unassigned_list.item_selected.connect(func(i): _on_unassigned_selected(i))

func _on_squad_selected(source: String, squad_idx: int, index: int):
	_clear_other_selections(source)
	if index >= 0 and index < squad_menu_data.squads[squad_idx].size():
		var char_data = squad_menu_data.squads[squad_idx][index]
		squad_menu_data.select(source, index, char_data)
		selection_changed.emit(source, index, char_data)

func _on_unassigned_selected(index: int):
	_clear_other_selections("unassigned")
	if index >= 0 and index < squad_menu_data.unassigned.size():
		var char_data = squad_menu_data.unassigned[index]
		squad_menu_data.select("unassigned", index, char_data)
		selection_changed.emit("unassigned", index, char_data)

func _clear_other_selections(source: String):
	if source != "squad1" and squad1_list:
		squad1_list.deselect_all()
	if source != "squad2" and squad2_list:
		squad2_list.deselect_all()
	if source != "squad3" and squad3_list:
		squad3_list.deselect_all()
	if source != "unassigned" and unassigned_list:
		unassigned_list.deselect_all()

func refresh_lists():
	if not _initialized:
		return
	if squad1_list == null:
		return
	_refresh_squad_list(squad1_list, squad1_count, squad_menu_data.squads[0])
	_refresh_squad_list(squad2_list, squad2_count, squad_menu_data.squads[1])
	_refresh_squad_list(squad3_list, squad3_count, squad_menu_data.squads[2])
	_refresh_unassigned_list()

func _refresh_squad_list(list: ItemList, count_label: Label, squad: Array):
	if list == null:
		return
	list.clear()
	for character in squad:
		var hp_text = "HP:%d/%d" % [character.current_hp, character.max_hp]
		list.add_item("%s (%s)" % [character.character_name, hp_text])

	if count_label:
		count_label.text = "%d/%d members" % [squad.size(), SquadMenuData.MAX_SQUAD_SIZE]

		if squad.size() == 0:
			count_label.modulate = Color.GRAY
		elif squad.size() >= SquadMenuData.MAX_SQUAD_SIZE:
			count_label.modulate = Color.RED
		else:
			count_label.modulate = Color.GREEN

func _refresh_unassigned_list():
	if unassigned_list == null:
		return
	unassigned_list.clear()
	for character in squad_menu_data.unassigned:
		var hp_text = "HP:%d/%d" % [character.current_hp, character.max_hp]
		unassigned_list.add_item("%s (%s)" % [character.character_name, hp_text])
