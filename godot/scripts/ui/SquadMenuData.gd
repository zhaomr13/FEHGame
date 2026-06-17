class_name SquadMenuData
extends Node

const MAX_SQUAD_SIZE = 6

# Optional override for tests. In production this stays null and resolves the GameManager autoload.
var game_manager: Node = null

var squads: Array = []
var unassigned: Array[CharacterData] = []

var selected_character: CharacterData = null
var selected_source: String = ""
var selected_index: int = -1

func _get_gm():
	if game_manager != null and is_instance_valid(game_manager):
		return game_manager
	var gm = Engine.get_singleton("GameManager")
	if gm == null:
		gm = get_node_or_null("/root/GameManager")
	return gm

func load_squad_data():
	var gm = _get_gm()
	if gm == null:
		push_error("SquadMenuData: GameManager not found")
		return
	squads = gm.squad_data.duplicate(true)
	unassigned = gm.unassigned_units.duplicate()

	# Pad up to MAX_SQUADS so the UI always shows the full slot range
	while squads.size() < GameConstants.MAX_SQUADS:
		squads.append([])

	var total_in_squads = 0
	for squad in squads:
		total_in_squads += squad.size()

	if total_in_squads == 0 and unassigned.size() == 0 and gm.player_army.size() > 0:
		_initialize_from_player_army()

func _initialize_from_player_army():
	squads = []
	for i in range(GameConstants.MAX_SQUADS):
		squads.append([])
	unassigned.clear()

	for character in _get_gm().player_army:
		unassigned.append(character)

func create_squad() -> int:
	if squads.size() >= GameConstants.MAX_SQUADS:
		return -1
	squads.append([])
	return squads.size() - 1

func disband_squad(squad_index: int) -> bool:
	if squad_index < 0 or squad_index >= squads.size():
		return false
	var squad = squads[squad_index]
	for character in squad:
		if not unassigned.has(character):
			unassigned.append(character)
	squad.clear()
	return true

func remove_empty_squads():
	"""Remove all empty squads, compacting indices."""
	var new_squads: Array = []
	for squad in squads:
		if squad.size() > 0:
			new_squads.append(squad)
	squads = new_squads

func move_character_to_squad(squad_index: int) -> String:
	if selected_character == null:
		return "Please select a character first!"

	if squad_index < 0 or squad_index >= squads.size():
		return "Invalid squad index!"

	if squads[squad_index].size() >= MAX_SQUAD_SIZE:
		return "Squad %d is full!" % (squad_index + 1)

	_remove_from_current()
	squads[squad_index].append(selected_character)

	selected_character = null
	selected_source = ""
	selected_index = -1

	return ""

func move_character_to_first_non_full_squad() -> String:
	if selected_character == null:
		return "Please select a character first!"

	for i in range(squads.size()):
		if squads[i].size() < MAX_SQUAD_SIZE:
			return move_character_to_squad(i)

	return "All squads are full!"

func remove_from_squad() -> String:
	if selected_character == null:
		return ""

	if selected_source == "unassigned":
		return ""

	if selected_source.begins_with("squad_"):
		var squad_index = int(selected_source.split("_")[1])
		if squad_index >= 0 and squad_index < squads.size():
			if selected_index >= 0 and selected_index < squads[squad_index].size():
				squads[squad_index].remove_at(selected_index)
				unassigned.append(selected_character)

	selected_character = null
	selected_source = ""
	selected_index = -1

	return ""

func _remove_from_current():
	match selected_source:
		"unassigned":
			if selected_index >= 0 and selected_index < unassigned.size():
				unassigned.remove_at(selected_index)
		_:
			if selected_source.begins_with("squad_"):
				var parts = selected_source.split("_")
				if parts.size() >= 2:
					var squad_index = int(parts[1])
					if squad_index >= 0 and squad_index < squads.size():
						if selected_index >= 0 and selected_index < squads[squad_index].size():
							squads[squad_index].remove_at(selected_index)

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

func get_selected_squad_index() -> int:
	"""Return the squad index of the currently selected character, or -1."""
	if selected_source.begins_with("squad_"):
		var parts = selected_source.split("_")
		if parts.size() >= 2:
			return int(parts[1])
	return -1
