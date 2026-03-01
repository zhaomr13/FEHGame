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

func _ready():
    print("GameManager initialized")

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
    start_battle(player_units, enemy_units)

func end_battle(victory: bool):
    battle_ended.emit(victory)
    change_state(GameConstants.GameState.WORLD_MAP)
