class_name SquadMenuData
extends Node

const MAX_SQUAD_SIZE = 6

var squads: Array = [[], [], []]
var unassigned: Array[CharacterData] = []

var selected_character: CharacterData = null
var selected_source: String = ""
var selected_index: int = -1

func load_squad_data():
	squads = GameManager.squad_data.duplicate(true)
	unassigned = GameManager.unassigned_units.duplicate()

	while squads.size() < 3:
		squads.append([])

	var total_in_squads = 0
	for squad in squads:
		total_in_squads += squad.size()

	if total_in_squads == 0 and unassigned.size() == 0 and GameManager.player_army.size() > 0:
		_initialize_from_player_army()

func _initialize_from_player_army():
	squads = [[], [], []]
	unassigned.clear()

	for character in GameManager.player_army:
		unassigned.append(character)

func move_character_to_squad(squad_index: int) -> String:
	if selected_character == null:
		return "Please select a character first!"

	if squads[squad_index].size() >= MAX_SQUAD_SIZE:
		return "Squad %d is full!" % (squad_index + 1)

	_remove_from_current()
	squads[squad_index].append(selected_character)

	selected_character = null
	selected_source = ""
	selected_index = -1

	return ""

func remove_from_squad() -> String:
	if selected_character == null:
		return ""

	if selected_source == "unassigned":
		return ""

	_remove_from_current()
	unassigned.append(selected_character)

	selected_character = null
	selected_source = ""
	selected_index = -1

	return ""

func _remove_from_current():
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

func select(source: String, index: int, character: CharacterData):
	selected_character = character
	selected_source = source
	selected_index = index

func get_active_squads() -> Array:
	var active = []
	for squad in squads:
		if squad.size() > 0:
			active.append(squad)
	return active

func get_squad_characters(squad_index: int) -> Array:
	if squad_index >= 0 and squad_index < squads.size():
		return squads[squad_index]
	return []
