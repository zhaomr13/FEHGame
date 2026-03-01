class_name BattleManager
extends Node2D

signal battle_finished(victory: bool)
signal turn_started(turn_number: int)
signal unit_acted(unit: BattleUnit)

@export var max_turns: int = 20

var player_units: Array[BattleUnit] = []
var enemy_units: Array[BattleUnit] = []
var all_units: Array[BattleUnit] = []
var current_turn: int = 0
var is_battle_active: bool = false

@onready var deployment_ui: CanvasLayer = $DeploymentUI
@onready var battle_ui: CanvasLayer = $BattleUI
@onready var background_sprite: Sprite2D = $Background
@onready var foreground_sprite: Sprite2D = $Foreground

# Available battle backgrounds
const BATTLE_BACKGROUNDS = {
    "plain": "res://assets/battle/backgrounds/plain_bg.png",
    "plain_fg": "res://assets/battle/backgrounds/plain_fg.png",
    "forest": "res://assets/battle/backgrounds/forest_bg.png",
    "forest_fg": "res://assets/battle/backgrounds/forest_fg.png",
    "inside": "res://assets/battle/backgrounds/inside_bg.png",
    "inside_fg": "res://assets/battle/backgrounds/inside_fg.png",
    "brave_attack": "res://assets/battle/backgrounds/brave_attack_bg.png",
    "brave_attack_fg": "res://assets/battle/backgrounds/brave_attack_fg.png",
    "river": "res://assets/battle/backgrounds/river_bg.png",
    "river_fg": "res://assets/battle/backgrounds/river_fg.png",
    "plain_forest": "res://assets/battle/backgrounds/plain_forest_bg.png",
    "plain_forest_fg": "res://assets/battle/backgrounds/plain_forest_fg.png"
}

func _ready():
    GameManager.battle_started.connect(_on_battle_started)
    GameManager.battle_started_with_background.connect(_on_battle_started_with_background)
    visible = false

func set_background(bg_type: String):
    """Set battle background by type (plain, forest, inside, brave_attack, river, plain_forest)"""
    var bg_path = BATTLE_BACKGROUNDS.get(bg_type, BATTLE_BACKGROUNDS["plain"])
    var fg_path = BATTLE_BACKGROUNDS.get(bg_type + "_fg", BATTLE_BACKGROUNDS["plain_fg"])

    if background_sprite:
        background_sprite.texture = load(bg_path)
    if foreground_sprite:
        foreground_sprite.texture = load(fg_path)

func _on_battle_started(player_army: Array, enemy_army: Array):
    # Use the default background if not specified
    set_background(GameManager.current_battle_background)
    start_deployment(player_army, enemy_army)

func _on_battle_started_with_background(player_army: Array, enemy_army: Array, background_type: String):
    set_background(background_type)
    start_deployment(player_army, enemy_army)

func start_deployment(player_army: Array, enemy_army: Array):
    GameManager.change_state(GameConstants.GameState.BATTLE_DEPLOYMENT)
    visible = true
    # TODO: Show deployment UI
    await get_tree().create_timer(1.0).timeout
    _on_deployment_confirmed(player_army, GameConstants.Formation.STANDARD)

func _on_deployment_confirmed(selected_units: Array[CharacterData], formation: int):
    if deployment_ui:
        deployment_ui.visible = false
    start_battle_combat(selected_units, formation)

func start_battle_combat(player_selected: Array[CharacterData], formation: int):
    GameManager.change_state(GameConstants.GameState.BATTLE_ACTIVE)

    # Clear previous units
    player_units.clear()
    enemy_units.clear()
    all_units.clear()

    for i in range(player_selected.size()):
        var unit = create_battle_unit(player_selected[i], i, true)
        player_units.append(unit)
        all_units.append(unit)

    for i in range(3):
        var enemy_data = CharacterData.new()
        enemy_data.character_name = "Enemy " + str(i+1)
        var unit = create_battle_unit(enemy_data, i, false)
        enemy_units.append(unit)
        all_units.append(unit)

    all_units.sort_custom(func(a, b): return a.character_data.speed > b.character_data.speed)

    is_battle_active = true
    current_turn = 0
    await start_combat_round()

func create_battle_unit(data: CharacterData, position: int, is_player: bool) -> BattleUnit:
    var unit_scene = preload("res://scenes/battle/BattleUnit.tscn")
    var unit = unit_scene.instantiate()
    unit.setup(data, position, is_player)
    add_child(unit)
    return unit

func start_combat_round():
    while is_battle_active and current_turn < max_turns:
        current_turn += 1
        turn_started.emit(current_turn)

        for unit in all_units:
            if unit.character_data.is_defeated():
                continue

            var enemy_list = enemy_units if unit.is_player_unit else player_units
            await unit.process_turn(enemy_list, all_units if unit.is_player_unit else enemy_units)
            unit_acted.emit(unit)

            if check_victory():
                return

            await get_tree().create_timer(0.5).timeout

        await get_tree().create_timer(1.0).timeout

    end_battle(false)

func check_victory() -> bool:
    var player_alive = player_units.any(func(u): return not u.character_data.is_defeated())
    var enemy_alive = enemy_units.any(func(u): return not u.character_data.is_defeated())

    if not enemy_alive:
        end_battle(true)
        return true
    elif not player_alive:
        end_battle(false)
        return true
    return false

func end_battle(victory: bool):
    is_battle_active = false
    battle_finished.emit(victory)
    visible = false
    GameManager.end_battle(victory)
