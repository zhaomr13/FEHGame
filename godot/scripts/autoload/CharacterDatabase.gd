class_name CharacterDatabase
extends Node

var all_characters: Array[CharacterData] = []
var available_recruits: Array[CharacterData] = []

func _ready():
	_initialize_all_characters()

func _initialize_all_characters():
	all_characters.clear()

	# Askr Kingdom characters
	_create_character("Sharena", GameConstants.CharacterClass.KNIGHT, "askr", "lance", "char_02_lilina")
	_create_character("Alfonse", GameConstants.CharacterClass.LORD, "askr", "sword", "char_01_alm")
	_create_character("Anna", GameConstants.CharacterClass.FIGHTER, "askr", "axe", "char_08_robin")

	# Embla Empire characters
	_create_character("Veronica", GameConstants.CharacterClass.MAGE, "embla", "magic", "char_02_lilina")
	_create_character("Bruno", GameConstants.CharacterClass.LORD, "embla", "sword", "char_01_alm")
	_create_character("Loki", GameConstants.CharacterClass.ARCHER, "embla", "bow", "char_09_rebecca")

	# Nifl Kingdom characters
	_create_character("Gunnthra", GameConstants.CharacterClass.MAGE, "nifl", "magic", "char_02_lilina")
	_create_character("Hrid", GameConstants.CharacterClass.LORD, "nifl", "sword", "char_01_alm")
	_create_character("Ylgr", GameConstants.CharacterClass.FIGHTER, "nifl", "axe", "char_03_dorcas")

	# Muspell characters
	_create_character("Laevatein", GameConstants.CharacterClass.KNIGHT, "muspell", "sword", "char_10_hector")
	_create_character("Laegjarn", GameConstants.CharacterClass.KNIGHT, "muspell", "lance", "char_04_abel")
	_create_character("Helbindi", GameConstants.CharacterClass.FIGHTER, "muspell", "axe", "char_03_dorcas")

	# Neutral/Independent characters
	_create_character("Klein", GameConstants.CharacterClass.ARCHER, "", "bow", "char_05_klein")
	_create_character("Rebecca", GameConstants.CharacterClass.ARCHER, "", "bow", "char_09_rebecca")
	_create_character("Lyn", GameConstants.CharacterClass.LORD, "", "sword", "char_07_lyn")

func _create_character(name: String, char_class: GameConstants.CharacterClass, faction: String, weapon: String, sprite_folder: String):
	var char_data = CharacterData.new()
	char_data.character_name = name
	char_data.character_class = char_class
	char_data.faction = faction
	char_data.weapon_type = weapon
	char_data.sprite_frames_path = "res://assets/characters/" + sprite_folder + "/"
	char_data.setup_default_tactics()

	match char_class:
		GameConstants.CharacterClass.LORD:
			char_data.max_hp = 25
			char_data.attack = 8
			char_data.defense = 5
			char_data.speed = 6
		GameConstants.CharacterClass.KNIGHT:
			char_data.max_hp = 30
			char_data.attack = 7
			char_data.defense = 8
			char_data.speed = 4
		GameConstants.CharacterClass.FIGHTER:
			char_data.max_hp = 28
			char_data.attack = 9
			char_data.defense = 4
			char_data.speed = 5
		GameConstants.CharacterClass.MAGE:
			char_data.max_hp = 20
			char_data.attack = 10
			char_data.defense = 3
			char_data.speed = 6
		GameConstants.CharacterClass.ARCHER:
			char_data.max_hp = 22
			char_data.attack = 8
			char_data.defense = 4
			char_data.speed = 7

	char_data.current_hp = char_data.max_hp
	all_characters.append(char_data)

func get_characters_by_faction(faction: String) -> Array[CharacterData]:
	var result: Array[CharacterData] = []
	for char in all_characters:
		if char.faction == faction:
			result.append(char)
	return result

func get_characters_not_in_faction(faction: String) -> Array[CharacterData]:
	var result: Array[CharacterData] = []
	for char in all_characters:
		if char.faction != faction:
			result.append(char)
	return result
