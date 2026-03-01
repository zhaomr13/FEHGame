extends Node2D

@onready var world_map = $WorldMap
@onready var battle_manager = $BattleScene
@onready var main_menu = $MainMenu
@onready var faction_select = $FactionSelectLayer/FactionSelect

# Faction starting positions
const FACTION_START_POSITIONS = {
	"askr": "city_3",  # Askr starts at central city
	"embla": "city_1", # Embla starts at northern fort
	"nifl": "city_8"   # Nifl starts at southern city
}

var selected_faction: String = ""

func _ready():
	# Connect start button
	var start_button = main_menu.get_node_or_null("StartButton")
	if start_button:
		start_button.pressed.connect(_on_start_pressed)

	# Connect faction selection
	faction_select.faction_selected.connect(_on_faction_selected)

	# Connect back button on faction select
	var back_button = faction_select.get_node_or_null("VBoxContainer/BackButton")
	if back_button:
		back_button.pressed.connect(_on_faction_back_pressed)

	GameManager.state_changed.connect(_on_state_changed)

	# Hide all except main menu initially
	world_map.visible = false
	battle_manager.visible = false
	faction_select.visible = false
	main_menu.visible = true

func _on_start_pressed():
	main_menu.visible = false
	faction_select.visible = true

func _on_faction_back_pressed():
	faction_select.visible = false
	main_menu.visible = true

func _on_faction_selected(faction: String):
	selected_faction = faction

	# Initialize player army based on faction
	initialize_player_army(faction)

	# Set starting position based on faction
	var start_city = FACTION_START_POSITIONS.get(faction, "city_3")
	world_map.current_node_id = start_city

	faction_select.visible = false
	GameManager.change_state(GameConstants.GameState.WORLD_MAP)
	world_map.visible = true

	# Reinitialize world map with new starting position
	world_map.setup_faction_start(faction, start_city)

func initialize_player_army(faction: String):
	"""Create starting characters based on faction choice"""
	GameManager.player_army.clear()

	var starter_characters = []

	match faction:
		"askr":
			starter_characters = [
				{"name": "Sharena", "class": GameConstants.CharacterClass.KNIGHT, "weapon": "lance"},
				{"name": "Alfonse", "class": GameConstants.CharacterClass.LORD, "weapon": "sword"},
				{"name": "Anna", "class": GameConstants.CharacterClass.FIGHTER, "weapon": "axe"}
			]
		"embla":
			starter_characters = [
				{"name": "Marth", "class": GameConstants.CharacterClass.LORD, "weapon": "sword"},
				{"name": "Cain", "class": GameConstants.CharacterClass.KNIGHT, "weapon": "lance"},
				{"name": "Abel", "class": GameConstants.CharacterClass.KNIGHT, "weapon": "lance"}
			]
		"nifl":
			starter_characters = [
				{"name": "Klein", "class": GameConstants.CharacterClass.ARCHER, "weapon": "bow"},
				{"name": "Rebecca", "class": GameConstants.CharacterClass.ARCHER, "weapon": "bow"},
				{"name": "Lyn", "class": GameConstants.CharacterClass.LORD, "weapon": "sword"}
			]

	for char_data in starter_characters:
		var character = CharacterData.new()
		character.character_name = char_data.name
		character.character_class = char_data.class
		character.weapon_type = char_data.weapon
		character.setup_default_tactics()

		# Set sprite path (use appropriate character folder)
		var sprite_name = _get_sprite_name(char_data.name)
		character.sprite_frames_path = "res://assets/characters/" + sprite_name + "/Idle.png"

		GameManager.player_army.append(character)

func _get_sprite_name(char_name: String) -> String:
	"""Map character name to sprite folder"""
	match char_name:
		"Sharena": return "char_06_sharena"
		"Alfonse": return "char_01_alm"
		"Anna": return "char_07_lyn"
		"Marth": return "char_01_alm"
		"Cain": return "char_04_abel"
		"Abel": return "char_04_abel"
		"Klein": return "char_05_klein"
		"Rebecca": return "char_09_rebecca"
		"Lyn": return "char_07_lyn"
		_: return "char_01_alm"

func _on_state_changed(new_state: GameConstants.GameState):
	match new_state:
		GameConstants.GameState.WORLD_MAP:
			world_map.visible = true
			battle_manager.visible = false
			main_menu.visible = false
			faction_select.visible = false
		GameConstants.GameState.BATTLE_DEPLOYMENT, \
		GameConstants.GameState.BATTLE_ACTIVE:
			world_map.visible = false
			battle_manager.visible = true
			main_menu.visible = false
			faction_select.visible = false
		GameConstants.GameState.MAIN_MENU:
			world_map.visible = false
			battle_manager.visible = false
			main_menu.visible = true
			faction_select.visible = false
