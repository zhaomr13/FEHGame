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
var is_combat_running: bool = false  # Guard to prevent multiple loops

@onready var deployment_ui: CanvasLayer = $DeploymentUI
@onready var battle_ui: CanvasLayer = $BattleUI
@onready var background_sprite: Sprite2D = $Background
@onready var foreground_sprite: Sprite2D = $Foreground
@onready var player_formation: Node2D = $PlayerFormation
@onready var enemy_formation: Node2D = $EnemyFormation

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
	GameManager.battle_started_with_background.connect(_on_battle_started_with_background)
	visible = false

func set_background(bg_type: String):
	var bg_path = BATTLE_BACKGROUNDS.get(bg_type, BATTLE_BACKGROUNDS["plain"])
	var fg_path = BATTLE_BACKGROUNDS.get(bg_type + "_fg", BATTLE_BACKGROUNDS["plain_fg"])

	if background_sprite:
		background_sprite.texture = load(bg_path)
	if foreground_sprite:
		foreground_sprite.texture = load(fg_path)

func _on_battle_started_with_background(player_army: Array, enemy_army: Array, background_type: String):
	if is_battle_active:
		return
	set_background(background_type)
	start_deployment(player_army, enemy_army)

func start_deployment(player_army: Array, enemy_army: Array):
	if is_battle_active:
		return
	GameManager.change_state(GameConstants.GameState.BATTLE_DEPLOYMENT)
	visible = true
	await get_tree().create_timer(0.5).timeout
	_on_deployment_confirmed(player_army, GameConstants.Formation.STANDARD)

func _on_deployment_confirmed(selected_units: Array[CharacterData], formation: int):
	if deployment_ui:
		deployment_ui.visible = false
	start_battle_combat(selected_units, formation)

func start_battle_combat(player_selected: Array[CharacterData], formation: int):
	if is_battle_active or is_combat_running:
		return

	GameManager.change_state(GameConstants.GameState.BATTLE_ACTIVE)

	# Clear previous units
	for unit in player_units:
		if is_instance_valid(unit):
			unit.queue_free()
	for unit in enemy_units:
		if is_instance_valid(unit):
			unit.queue_free()
	player_units.clear()
	enemy_units.clear()
	all_units.clear()

	# Create player units - 3 in front row
	for i in range(min(player_selected.size(), 6)):
		var unit = create_battle_unit(player_selected[i], i, true)
		player_units.append(unit)
		all_units.append(unit)

	# Create enemy units - 3 in front row
	for i in range(3):
		var enemy_data = CharacterData.new()
		enemy_data.character_name = "Enemy " + str(i + 1)
		enemy_data.max_hp = 20 + randi() % 10
		enemy_data.current_hp = enemy_data.max_hp
		enemy_data.attack = 5 + randi() % 5
		enemy_data.defense = 3 + randi() % 3
		enemy_data.speed = 4 + randi() % 4
		enemy_data.sprite_frames_path = "res://assets/ArmorAX.png"  # Use available atlas
		enemy_data.setup_default_tactics()
		var unit = create_battle_unit(enemy_data, i, false)
		enemy_units.append(unit)
		all_units.append(unit)

	# Sort by speed (fastest first)
	all_units.sort_custom(func(a, b): return a.character_data.speed > b.character_data.speed)

	is_battle_active = true
	is_combat_running = true
	current_turn = 0

	await start_combat_round()

func create_battle_unit(data: CharacterData, position: int, is_player: bool) -> BattleUnit:
	var unit_scene = preload("res://scenes/battle/BattleUnit.tscn")
	var unit = unit_scene.instantiate()
	unit.setup(data, position, is_player)

	# Simple formation: 3 units in a row
	# Position 0, 1, 2: front row at y = 0
	var x_pos = (position % 3) * 120 - 120  # -120, 0, 120

	if is_player:
		unit.position = Vector2(x_pos, 0)
		player_formation.add_child(unit)
	else:
		unit.position = Vector2(x_pos, 0)
		unit.scale.x = -1
		enemy_formation.add_child(unit)

	return unit

func start_combat_round():
	while is_battle_active and current_turn < max_turns and is_combat_running:
		current_turn += 1
		turn_started.emit(current_turn)
		print("Battle Turn: ", current_turn)

		for unit in all_units:
			if not is_battle_active or not is_combat_running:
				return

			if not is_instance_valid(unit) or unit.character_data.is_defeated():
				continue

			var enemy_list = enemy_units if unit.is_player_unit else player_units
			await unit.process_turn(enemy_list, all_units if unit.is_player_unit else enemy_units)
			unit_acted.emit(unit)

			if check_victory():
				return

			# Short delay between actions
			await get_tree().create_timer(0.2).timeout

		# Short delay between turns
		await get_tree().create_timer(0.5).timeout

	if is_battle_active:
		print("Battle ended by turn limit")
		end_battle(false)

func check_victory() -> bool:
	var player_alive = player_units.any(func(u): return is_instance_valid(u) and not u.character_data.is_defeated())
	var enemy_alive = enemy_units.any(func(u): return is_instance_valid(u) and not u.character_data.is_defeated())

	if not enemy_alive:
		print("Victory! All enemies defeated")
		end_battle(true)
		return true
	elif not player_alive:
		print("Defeat! All player units defeated")
		end_battle(false)
		return true
	return false

func end_battle(victory: bool):
	if not is_battle_active:
		return
	is_battle_active = false
	is_combat_running = false
	battle_finished.emit(victory)
	visible = false
	GameManager.end_battle(victory)
