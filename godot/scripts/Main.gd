extends Node2D

@onready var world_map = $WorldMap
@onready var battle_manager = $BattleScene
@onready var main_menu = $MainMenu

func _ready():
	# Connect start button if it exists
	var start_button = main_menu.get_node_or_null("StartButton")
	if start_button:
		start_button.pressed.connect(_start_game)

	GameManager.state_changed.connect(_on_state_changed)

	world_map.visible = false
	battle_manager.visible = false
	main_menu.visible = true

func _start_game():
	main_menu.visible = false
	GameManager.change_state(GameConstants.GameState.WORLD_MAP)
	world_map.visible = true

func _on_state_changed(new_state: GameConstants.GameState):
	match new_state:
		GameConstants.GameState.WORLD_MAP:
			world_map.visible = true
			battle_manager.visible = false
			main_menu.visible = false
		GameConstants.GameState.BATTLE_DEPLOYMENT, \
		GameConstants.GameState.BATTLE_ACTIVE:
			world_map.visible = false
			battle_manager.visible = true
			main_menu.visible = false
		GameConstants.GameState.MAIN_MENU:
			world_map.visible = false
			battle_manager.visible = false
			main_menu.visible = true
