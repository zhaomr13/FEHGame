extends Node

const SAVE_PATH = "user://savegame.json"
const SQUAD_SAVE_PATH = "user://squads.json"
const SQUAD_SAVE_VERSION = 2

# Optional override for tests or alternative game managers.
var game_manager: Node = null

func _get_gm() -> Node:
	if game_manager != null:
		return game_manager
	return Engine.get_singleton("GameManager")

func save_game():
	var save_data = {
		"chapter": _get_gm().current_chapter,
		"gold": _get_gm().player_gold,
		"player_army": []
	}

	for character in _get_gm().player_army:
		save_data["player_army"].append({
			"name": character.character_name,
			"class": character.character_class,
			"level": character.level,
			"exp": character.experience,
			"hp": character.current_hp,
			"max_hp": character.max_hp,
			"attack": character.attack,
			"defense": character.defense,
			"speed": character.speed,
			"soldiers": character.soldiers
		})

	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(save_data))
	file.close()
	print("Game saved to ", SAVE_PATH)

func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		print("No save file found")
		return false

	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	var json_string = file.get_as_text()
	file.close()

	var json = JSON.new()
	var error = json.parse(json_string)
	if error != OK:
		print("JSON parse error: ", json.get_error_message())
		return false

	var save_data = json.data
	_get_gm().current_chapter = save_data.get("chapter", 1)
	_get_gm().player_gold = save_data.get("gold", 1000)

	# Restore player army from save data
	_get_gm().player_army.clear()
	var army_data = save_data.get("player_army", [])
	for char_data in army_data:
		var character = CharacterData.new()
		character.character_name = char_data.get("name", "Unknown")
		character.character_class = char_data.get("class", GameConstants.CharacterClass.LORD)
		character.level = char_data.get("level", 1)
		character.experience = char_data.get("exp", 0)
		character.current_hp = char_data.get("hp", 20)
		character.max_hp = char_data.get("max_hp", 20)
		character.attack = char_data.get("attack", 5)
		character.defense = char_data.get("defense", 3)
		character.speed = char_data.get("speed", 5)
		character.soldiers = char_data.get("soldiers", 100)
		character.setup_default_tactics()
		_get_gm().player_army.append(character)

	# Load squad configuration
	if has_saved_squads():
		_get_gm().squad_data = load_squads()
		_get_gm().unassigned_units = load_unassigned()
	else:
		_get_gm().initialize_squads()

	print("Game loaded from ", SAVE_PATH)
	return true

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

# Squad save/load functions
func save_squads(squads: Array, unassigned: Array[CharacterData]):
	"""Save squad configuration to file"""
	var squad_names: Array = []
	for squad in squads:
		var names: Array = []
		for character in squad:
			names.append(character.character_name)
		squad_names.append(names)

	var unassigned_names: Array = []
	for character in unassigned:
		unassigned_names.append(character.character_name)

	var squad_save = {
		"version": SQUAD_SAVE_VERSION,
		"squads": squad_names,
		"unassigned": unassigned_names
	}

	var file = FileAccess.open(SQUAD_SAVE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(squad_save))
	file.close()
	print("Squad configuration saved")

func load_squads() -> Array:
	"""Load squad configuration from file"""
	var result: Array = []
	var squad_save = _load_squad_save_data()
	if squad_save == null:
		return _pad_squads(result)

	var saved_squads = squad_save.get("squads", [])
	var character_lookup = _build_character_lookup()

	if _is_legacy_format(squad_save):
		# Legacy v1: fixed 3 squads
		for i in range(3):
			var squad: Array = []
			var squad_names = saved_squads[i] if i < saved_squads.size() else []
			for name in squad_names:
				if character_lookup.has(name):
					squad.append(character_lookup[name])
			result.append(squad)
	else:
		# v2: dynamic squads
		for squad_names in saved_squads:
			var squad: Array = []
			for name in squad_names:
				if character_lookup.has(name):
					squad.append(character_lookup[name])
			result.append(squad)

	return _pad_squads(result)

func load_unassigned() -> Array[CharacterData]:
	"""Load unassigned characters from file"""
	var result: Array[CharacterData] = []
	var squad_save = _load_squad_save_data()
	if squad_save == null:
		return result

	var character_lookup = _build_character_lookup()
	var unassigned_names = squad_save.get("unassigned", [])
	for name in unassigned_names:
		if character_lookup.has(name):
			result.append(character_lookup[name])

	return result

func has_saved_squads() -> bool:
	"""Check if squad configuration exists"""
	return FileAccess.file_exists(SQUAD_SAVE_PATH)

func _load_squad_save_data() -> Variant:
	"""Load and parse squad save file. Returns null on failure."""
	if not FileAccess.file_exists(SQUAD_SAVE_PATH):
		return null

	var file = FileAccess.open(SQUAD_SAVE_PATH, FileAccess.READ)
	var json_string = file.get_as_text()
	file.close()

	var json = JSON.new()
	var error = json.parse(json_string)
	if error != OK:
		print("Squad JSON parse error: ", json.get_error_message())
		return null

	if json.data is Dictionary:
		return json.data
	return null

func _build_character_lookup() -> Dictionary:
	"""Build a name -> CharacterData lookup from player_army."""
	var character_lookup = {}
	for character in _get_gm().player_army:
		character_lookup[character.character_name] = character
	return character_lookup

func _is_legacy_format(squad_save: Dictionary) -> bool:
	"""Return true if the save uses the legacy v1 fixed 3-squad format."""
	var version = squad_save.get("version", 1)
	return version < 2

func _pad_squads(squads: Array) -> Array:
	"""Pad squad array up to MAX_SQUADS with empty squads for UI consistency."""
	while squads.size() < GameConstants.MAX_SQUADS:
		squads.append([])
	return squads
