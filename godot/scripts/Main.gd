extends Node2D

@onready var world_map = $WorldMap
@onready var battle_manager = $BattleScene
@onready var main_menu = $MainMenu
@onready var faction_select = $FactionSelectLayer/FactionSelect

# Faction starting positions
const FACTION_START_POSITIONS = {
	"askr": "city_11",    # central kingdom
	"embla": "city_01",   # northern empire
	"nifl": "city_45",    # eastern kingdom
	"muspell": "city_33"  # western frontier
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
	var start_city = FACTION_START_POSITIONS.get(faction, "city_03")
	world_map.current_node_id = start_city

	# Initialize squads (all unassigned initially)
	GameManager.initialize_squads()

	faction_select.visible = false
	GameManager.change_state(GameConstants.GameState.WORLD_MAP)
	world_map.visible = true

	# Reinitialize world map with new starting position
	world_map.setup_faction_start(faction, start_city)

func initialize_player_army(faction: String):
	"""Assign characters to player based on faction choice"""
	GameManager.current_faction = faction
	GameManager.player_army.clear()

	# Get all characters belonging to the chosen faction
	var faction_characters = GameManager.get_characters_by_faction(faction)

	# If faction has no characters (e.g., player chooses a neutral start), give them some neutrals
	if faction_characters.is_empty():
		faction_characters = GameManager.get_characters_by_faction("")

	# Assign up to 3 characters to player
	for i in range(min(3, faction_characters.size())):
		var character = faction_characters[i]
		character.faction = faction  # Ensure faction is set correctly
		GameManager.player_army.append(character)
		print("Assigned ", character.character_name, " to player faction ", faction)

	# Set up available recruits (characters from other factions that can be recruited later)
	GameManager.available_recruits.clear()
	var other_factions = GameManager.get_characters_not_in_faction(faction)
	for char in other_factions:
		if char.faction != "":  # Only faction characters can be recruited, not neutrals
			GameManager.available_recruits.append(char)

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
