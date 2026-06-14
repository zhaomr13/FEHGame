extends Node

signal state_changed(new_state: GameConstants.GameState)
signal battle_started(player_units: Array, enemy_units: Array)
signal battle_started_with_background(player_units: Array, enemy_units: Array, background_type: String)
signal battle_ended(victory: bool)

var current_state: GameConstants.GameState = GameConstants.GameState.MAIN_MENU
var player_army: Array[CharacterData] = []
var current_chapter: int = 1
var player_gold: int = 1000
var current_battle_background: String = "plain"
var current_faction: String = ""

# Squad system: 3 squads max, 6 characters per squad
# squad_data[0] = squad 1, squad_data[1] = squad 2, squad_data[2] = squad 3
var squad_data: Array = [[], [], []]
var unassigned_units: Array[CharacterData] = []

func _ready():
	print("GameManager initialized")

func recruit_character(character: CharacterData):
	"""Recruit a character to player's army"""
	if not player_army.has(character):
		character.faction = current_faction if current_faction else "askr"
		player_army.append(character)
		CharacterDatabase.available_recruits.erase(character)

func change_state(new_state: GameConstants.GameState):
	current_state = new_state
	state_changed.emit(new_state)
	print("State changed to: ", GameConstants.GameState.keys()[new_state])

func start_battle(player_units: Array, enemy_units: Array):
	battle_started.emit(player_units, enemy_units)
	change_state(GameConstants.GameState.BATTLE_DEPLOYMENT)

func start_battle_with_background(player_units: Array, enemy_units: Array, background_type: String):
	current_battle_background = background_type
	battle_started_with_background.emit(player_units, enemy_units, background_type)
	change_state(GameConstants.GameState.BATTLE_DEPLOYMENT)

func end_battle(victory: bool):
	battle_ended.emit(victory)
	change_state(GameConstants.GameState.WORLD_MAP)

# Squad management functions
func initialize_squads():
	"""Initialize squads from player_army - all unassigned"""
	squad_data = [[], [], []]
	unassigned_units = []
	for character in player_army:
		unassigned_units.append(character)

func get_active_squads() -> Array:
	"""Return list of squads that have members"""
	var active = []
	for squad in squad_data:
		if squad.size() > 0:
			active.append(squad)
	return active

func get_squad(squad_index: int) -> Array:
	"""Get a specific squad by index (0-2)"""
	if squad_index >= 0 and squad_index < squad_data.size():
		return squad_data[squad_index]
	return []

func update_squad_data(squads: Array, unassigned: Array[CharacterData]):
	"""Update squad configuration from SquadMenu"""
	squad_data = squads
	unassigned_units = unassigned

	# Rebuild player_army in order (squad 1, 2, 3, unassigned)
	var new_army: Array[CharacterData] = []
	for squad in squad_data:
		for character in squad:
			new_army.append(character)
	for character in unassigned_units:
		new_army.append(character)
	player_army = new_army
