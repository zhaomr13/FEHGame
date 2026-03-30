extends Control

signal menu_closed(saved: bool)

# Squad data: array of 3 squads, each is an array of CharacterData
# Using untyped Array for squads due to GDScript nested array type limitations
var squads: Array = [[], [], []]
var unassigned: Array[CharacterData] = []

var selected_character: CharacterData = null
var selected_source: String = ""  # "squad1", "squad2", "squad3", "unassigned"
var selected_index: int = -1

const MAX_SQUAD_SIZE = 6

var squad1_list: ItemList = null
var squad2_list: ItemList = null
var squad3_list: ItemList = null
var unassigned_list: ItemList = null

var squad1_count: Label = null
var squad2_count: Label = null
var squad3_count: Label = null

var character_info: Label = null
var _initialized: bool = false
var _init_retries: int = 0
const MAX_INIT_RETRIES = 10

func _ready():
	visible = false

	# Defer initialization to ensure scene is fully loaded
	call_deferred("_initialize_nodes")

func _initialize_nodes():
	print("DEBUG: _initialize_nodes starting")
	# Find character info label with fallback
	var panel = $Panel
	if panel == null:
		print("ERROR: Panel not found!")
		_create_fallback_label()
		return
	print("DEBUG: Panel found")

	var vbox = panel.get_node_or_null("VBoxContainer")
	if vbox == null:
		print("ERROR: VBoxContainer not found!")
		_create_fallback_label()
		return
	print("DEBUG: VBoxContainer found")

	var squad_container = vbox.get_node_or_null("SquadContainer")
	if squad_container == null:
		print("ERROR: SquadContainer not found!")
	else:
		print("DEBUG: SquadContainer found")

	# Find squad lists and counts
	var squad1_panel = null
	if squad_container:
		squad1_panel = squad_container.get_node_or_null("Squad1Panel")
	if squad1_panel:
		squad1_list = squad1_panel.get_node_or_null("Squad1List")
		squad1_count = squad1_panel.get_node_or_null("Squad1Count")
		print("DEBUG: Squad1 nodes found: list=", squad1_list != null, ", count=", squad1_count != null)

	var squad2_panel = null
	if squad_container:
		squad2_panel = squad_container.get_node_or_null("Squad2Panel")
	if squad2_panel:
		squad2_list = squad2_panel.get_node_or_null("Squad2List")
		squad2_count = squad2_panel.get_node_or_null("Squad2Count")
		print("DEBUG: Squad2 nodes found: list=", squad2_list != null, ", count=", squad2_count != null)

	var squad3_panel = null
	if squad_container:
		squad3_panel = squad_container.get_node_or_null("Squad3Panel")
	if squad3_panel:
		squad3_list = squad3_panel.get_node_or_null("Squad3List")
		squad3_count = squad3_panel.get_node_or_null("Squad3Count")
		print("DEBUG: Squad3 nodes found: list=", squad3_list != null, ", count=", squad3_count != null)

	# Find unassigned panel
	var unassigned_panel = vbox.get_node_or_null("UnassignedPanel")
	if unassigned_panel == null:
		print("ERROR: UnassignedPanel not found!")
		_create_fallback_label()
		return
	print("DEBUG: UnassignedPanel found")

	unassigned_list = unassigned_panel.get_node_or_null("UnassignedList")
	character_info = unassigned_panel.get_node_or_null("CharacterInfoLabel")

	print("DEBUG: unassigned_list=", unassigned_list != null, ", character_info=", character_info != null)

	if character_info == null:
		print("ERROR: CharacterInfoLabel not found!")
		_create_fallback_label()
		return

	print("DEBUG: All nodes found successfully")
	_connect_signals()
	_initialized = true
	print("DEBUG: _initialize_nodes complete, _initialized=true")

func _create_fallback_label():
	print("DEBUG: Creating fallback label")
	# Create a temporary label to avoid crashes
	character_info = Label.new()
	if character_info == null:
		print("ERROR: Failed to create fallback Label!")
		return
	character_info.text = "Info panel not found"
	add_child(character_info)
	print("WARNING: Created fallback label")
	_initialized = true  # Mark as initialized (even if broken) so menu can open

func _connect_signals():
	# Connect list selection signals
	if squad1_list:
		squad1_list.item_selected.connect(_on_squad1_selected)
	if squad2_list:
		squad2_list.item_selected.connect(_on_squad2_selected)
	if squad3_list:
		squad3_list.item_selected.connect(_on_squad3_selected)
	if unassigned_list:
		unassigned_list.item_selected.connect(_on_unassigned_selected)

	# Connect button signals
	var to_squad1 = $Panel/VBoxContainer/ButtonContainer/ToSquad1Button
	var to_squad2 = $Panel/VBoxContainer/ButtonContainer/ToSquad2Button
	var to_squad3 = $Panel/VBoxContainer/ButtonContainer/ToSquad3Button
	var remove_btn = $Panel/VBoxContainer/ButtonContainer/RemoveButton
	var save_btn = $Panel/VBoxContainer/ActionContainer/SaveButton
	var cancel_btn = $Panel/VBoxContainer/ActionContainer/CancelButton

	if to_squad1:
		to_squad1.pressed.connect(_on_move_to_squad1)
		print("DEBUG: To Squad 1 button connected")
	if to_squad2:
		to_squad2.pressed.connect(_on_move_to_squad2)
		print("DEBUG: To Squad 2 button connected")
	if to_squad3:
		to_squad3.pressed.connect(_on_move_to_squad3)
		print("DEBUG: To Squad 3 button connected")
	if remove_btn:
		remove_btn.pressed.connect(_on_remove_from_squad)
		print("DEBUG: Remove button connected")
	if save_btn:
		save_btn.pressed.connect(_on_save)
		print("DEBUG: Save button connected")
	if cancel_btn:
		cancel_btn.pressed.connect(_on_cancel)
		print("DEBUG: Cancel button connected")
	if squad1_list == null:
		print("ERROR: Squad1List not found!")
	if squad2_list == null:
		print("ERROR: Squad2List not found!")
	if squad3_list == null:
		print("ERROR: Squad3List not found!")
	if unassigned_list == null:
		print("ERROR: UnassignedList not found!")

func open_menu():
	print("DEBUG: open_menu called, _initialized=", _initialized)
	# If not initialized yet, wait for initialization
	if not _initialized:
		print("DEBUG: Menu not initialized yet, deferring open")
		_load_squad_data()
		visible = true
		call_deferred("_deferred_open")
	else:
		_load_squad_data()
		_refresh_lists()
		visible = true

func _deferred_open():
	"""Called after initialization is complete"""
	print("DEBUG: _deferred_open called, _initialized=", _initialized)
	if not _initialized:
		_init_retries += 1
		if _init_retries > MAX_INIT_RETRIES:
			print("ERROR: Max init retries exceeded, giving up")
			return
		print("DEBUG: Still not initialized, waiting... (retry ", _init_retries, ")")
		call_deferred("_deferred_open")
		return
	_init_retries = 0
	_refresh_lists()

func _load_squad_data():
	"""Load squad data from GameManager or initialize from player_army"""
	# Load from GameManager's current squad data
	squads = GameManager.squad_data.duplicate(true)
	unassigned = GameManager.unassigned_units.duplicate()

	# Ensure we have 3 squads
	while squads.size() < 3:
		squads.append([])

	# If squads are empty and unassigned is empty, initialize from player_army
	var total_in_squads = 0
	for squad in squads:
		total_in_squads += squad.size()

	if total_in_squads == 0 and unassigned.size() == 0 and GameManager.player_army.size() > 0:
		_initialize_from_player_army()

func _initialize_from_player_army():
	"""Initialize squads from GameManager.player_army"""
	squads = [[], [], []]
	unassigned.clear()

	# Put all characters in unassigned initially
	for character in GameManager.player_army:
		unassigned.append(character)

func _refresh_lists():
	"""Refresh all list displays"""
	print("DEBUG: _refresh_lists called")
	if not _initialized:
		print("WARNING: Menu not initialized yet, skipping refresh")
		return
	if squad1_list == null or squad2_list == null or squad3_list == null or unassigned_list == null:
		print("WARNING: Lists not initialized yet, skipping refresh")
		return
	_refresh_squad_list(squad1_list, squad1_count, squads[0], 1)
	_refresh_squad_list(squad2_list, squad2_count, squads[1], 2)
	_refresh_squad_list(squad3_list, squad3_count, squads[2], 3)
	_refresh_unassigned_list()

func _refresh_squad_list(list: ItemList, count_label: Label, squad: Array, squad_num: int):
	if list == null:
		return
	list.clear()
	for character in squad:
		var hp_text = "HP:%d/%d" % [character.current_hp, character.max_hp]
		list.add_item("%s (%s)" % [character.character_name, hp_text])

	if count_label:
		count_label.text = "%d/%d members" % [squad.size(), MAX_SQUAD_SIZE]

		# Color coding based on squad size
		if squad.size() == 0:
			count_label.modulate = Color.GRAY
		elif squad.size() >= MAX_SQUAD_SIZE:
			count_label.modulate = Color.RED
		else:
			count_label.modulate = Color.GREEN

func _refresh_unassigned_list():
	if unassigned_list == null:
		return
	unassigned_list.clear()
	for character in unassigned:
		var hp_text = "HP:%d/%d" % [character.current_hp, character.max_hp]
		unassigned_list.add_item("%s (%s)" % [character.character_name, hp_text])

func _on_squad1_selected(index: int):
	_clear_other_selections("squad1")
	print("DEBUG: Squad 1 selected index: ", index)
	if index >= 0 and index < squads[0].size():
		selected_character = squads[0][index] as CharacterData
		selected_source = "squad1"
		selected_index = index
		print("DEBUG: Selected character: ", selected_character.character_name)
		_update_character_info()

func _on_squad2_selected(index: int):
	_clear_other_selections("squad2")
	print("DEBUG: Squad 2 selected index: ", index)
	if index >= 0 and index < squads[1].size():
		selected_character = squads[1][index] as CharacterData
		selected_source = "squad2"
		selected_index = index
		print("DEBUG: Selected character: ", selected_character.character_name)
		_update_character_info()

func _on_squad3_selected(index: int):
	_clear_other_selections("squad3")
	print("DEBUG: Squad 3 selected index: ", index)
	if index >= 0 and index < squads[2].size():
		selected_character = squads[2][index] as CharacterData
		selected_source = "squad3"
		selected_index = index
		print("DEBUG: Selected character: ", selected_character.character_name)
		_update_character_info()

func _on_unassigned_selected(index: int):
	_clear_other_selections("unassigned")
	print("DEBUG: Unassigned selected index: ", index)
	if index >= 0 and index < unassigned.size():
		selected_character = unassigned[index]
		selected_source = "unassigned"
		selected_index = index
		print("DEBUG: Selected character: ", selected_character.character_name)
		_update_character_info()
	else:
		print("DEBUG: Invalid unassigned index!")

func _clear_other_selections(source: String):
	"""Clear selection from other lists"""
	if source != "squad1" and squad1_list:
		squad1_list.deselect_all()
	if source != "squad2" and squad2_list:
		squad2_list.deselect_all()
	if source != "squad3" and squad3_list:
		squad3_list.deselect_all()
	if source != "unassigned" and unassigned_list:
		unassigned_list.deselect_all()

	# Clear previous selection if switching sources
	if selected_source != source and selected_source != "":
		selected_character = null
		selected_index = -1

func _set_info_text(text: String):
	print("DEBUG: _set_info_text called with: ", text)
	print("DEBUG: character_info is ", character_info)
	if character_info != null and is_instance_valid(character_info):
		print("DEBUG: Setting character_info.text")
		character_info.text = text
		print("DEBUG: character_info.text set successfully")
	else:
		print("WARNING: character_info is null or invalid, cannot set text: ", text)

func _update_character_info():
	if selected_character == null:
		_set_info_text("Select a character to view details")
		return

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

func _on_move_to_squad1():
	print("DEBUG: _on_move_to_squad1 called")
	_move_character_to_squad(0)

func _on_move_to_squad2():
	print("DEBUG: _on_move_to_squad2 called")
	_move_character_to_squad(1)

func _on_move_to_squad3():
	print("DEBUG: _on_move_to_squad3 called")
	_move_character_to_squad(2)

func _move_character_to_squad(squad_index: int):
	print("DEBUG: Moving character to squad ", squad_index + 1)
	print("DEBUG: Selected character: ", selected_character)
	print("DEBUG: Selected source: ", selected_source)

	if selected_character == null:
		_set_info_text("Please select a character first!")
		print("DEBUG: No character selected!")
		return

	# Check if squad is full
	if squads[squad_index].size() >= MAX_SQUAD_SIZE:
		_set_info_text("Squad %d is full!" % (squad_index + 1))
		print("DEBUG: Squad is full!")
		return

	# Remove from current location
	_remove_from_current()

	# Add to new squad
	squads[squad_index].append(selected_character)
	print("DEBUG: Character added to squad ", squad_index + 1)

	# Clear selection
	selected_character = null
	selected_source = ""
	selected_index = -1

	_refresh_lists()

func _on_remove_from_squad():
	print("DEBUG: _on_remove_from_squad called")
	if selected_character == null:
		print("DEBUG: No character selected for removal")
		return

	if selected_source == "unassigned":
		print("DEBUG: Character already unassigned")
		return  # Already unassigned

	_remove_from_current()
	unassigned.append(selected_character)
	print("DEBUG: Character moved to unassigned")

	selected_character = null
	selected_source = ""
	selected_index = -1

	_refresh_lists()

func _remove_from_current():
	"""Remove selected character from its current location"""
	match selected_source:
		"squad1":
			if selected_index < squads[0].size():
				squads[0].remove_at(selected_index)
		"squad2":
			if selected_index < squads[1].size():
				squads[1].remove_at(selected_index)
		"squad3":
			if selected_index < squads[2].size():
				squads[2].remove_at(selected_index)
		"unassigned":
			if selected_index < unassigned.size():
				unassigned.remove_at(selected_index)

func _on_save():
	"""Save squad configuration"""
	# Update GameManager with squad data
	GameManager.update_squad_data(squads, unassigned)

	# Also save to disk
	SaveManager.save_squads(squads, unassigned)

	visible = false
	menu_closed.emit(true)

func _on_cancel():
	visible = false
	menu_closed.emit(false)

func _update_player_army_order():
	"""Update GameManager.player_army to reflect squad order"""
	var new_army: Array[CharacterData] = []

	# Add characters in squad order (squad 1, 2, 3, then unassigned)
	for squad in squads:
		for character in squad:
			if character is CharacterData:
				new_army.append(character)

	for character in unassigned:
		new_army.append(character)

	GameManager.player_army = new_army

func get_active_squads() -> Array:
	"""Return squads that have at least one member"""
	var active = []
	for squad in squads:
		if squad.size() > 0:
			active.append(squad)
	return active

func get_squad_characters(squad_index: int) -> Array:
	"""Get characters in a specific squad"""
	if squad_index >= 0 and squad_index < squads.size():
		return squads[squad_index]
	return []
