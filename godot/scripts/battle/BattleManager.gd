class_name BattleManager
extends Node2D

signal battle_finished(victory: bool)

@export var max_turns: int = 20

var player_units: Array[BattleUnit] = []
var enemy_units: Array[BattleUnit] = []
var all_units: Array[BattleUnit] = []
var current_turn: int = 0
var is_battle_active: bool = false
var is_combat_running: bool = false

@onready var bg_mgr: BattleBackgroundManager = $BattleBackgroundManager
@onready var unit_factory: BattleUnitFactory = $BattleUnitFactory
@onready var deployment_mgr: BattleDeploymentManager = $BattleDeploymentManager
@onready var status_panel: BattleStatusPanel = $BattleStatusPanel
@onready var turn_mgr: BattleTurnManager = $BattleTurnManager

func _ready():
	if not bg_mgr:
		print("错误：BattleManager - 缺少 BattleBackgroundManager！")
	if not deployment_mgr:
		print("错误：BattleManager - 缺少 BattleDeploymentManager！")
	if not unit_factory:
		print("错误：BattleManager - 缺少 BattleUnitFactory！")
	if not status_panel:
		print("错误：BattleManager - 缺少 BattleStatusPanel！")
	if not turn_mgr:
		print("错误：BattleManager - 缺少 BattleTurnManager！")

	GameManager.battle_started_with_background.connect(_on_battle_started_with_background)
	deployment_mgr.deployment_confirmed.connect(_on_deployment_confirmed)
	turn_mgr.turn_started.connect(_on_turn_started)
	turn_mgr.unit_acted.connect(_on_unit_acted)
	turn_mgr.battle_finished.connect(_on_battle_finished)
	visible = false

func _on_battle_started_with_background(player_army: Array, enemy_army: Array, background_type: String):
	if is_battle_active:
		return
	bg_mgr.set_background(background_type)
	# Skip deployment animation, go straight to combat
	start_battle_combat(player_army, enemy_army, GameConstants.Formation.STANDARD)

func _on_deployment_confirmed(player_selected: Array[CharacterData], enemy_selected: Array[CharacterData], formation: int):
	start_battle_combat(player_selected, enemy_selected, formation)

func start_battle_combat(player_selected: Array[CharacterData], enemy_selected: Array[CharacterData], formation: int):
	if is_battle_active or is_combat_running:
		return

	GameManager.change_state(GameConstants.GameState.BATTLE_ACTIVE)

	# Create units
	if player_units.is_empty():
		for i in range(min(player_selected.size(), 6)):
			var unit = unit_factory.create_battle_unit(player_selected[i], i, true)
			player_units.append(unit)
			all_units.append(unit)

	if enemy_units.is_empty():
		for i in range(min(enemy_selected.size(), 6)):
			var enemy_data: CharacterData
			if enemy_selected.size() > i:
				enemy_data = enemy_selected[i]
			else:
				enemy_data = unit_factory.create_default_enemy(i)
			var unit = unit_factory.create_battle_unit(enemy_data, i, false)
			enemy_units.append(unit)
			all_units.append(unit)

	# Status panel
	for unit in player_units:
		if is_instance_valid(unit):
			status_panel.create_unit_status_entry(unit, unit.character_data, true)
	for unit in enemy_units:
		if is_instance_valid(unit):
			status_panel.create_unit_status_entry(unit, unit.character_data, false)

	all_units.sort_custom(func(a, b): return a.character_data.speed > b.character_data.speed)

	is_battle_active = true
	is_combat_running = true
	current_turn = 0

	await turn_mgr.start_combat_round()

func _on_turn_started(turn_number: int):
	pass

func _on_unit_acted(unit: BattleUnit):
	pass

func _on_battle_finished(victory: bool):
	battle_finished.emit(victory)
	_cleanup_battle_units()

func _cleanup_battle_units():
	"""Free all battle units and clear tracking arrays to prevent stale references."""
	for unit in all_units:
		if is_instance_valid(unit):
			unit.queue_free()
	player_units.clear()
	enemy_units.clear()
	all_units.clear()
	if status_panel:
		status_panel.cleanup_status_entries()
	is_battle_active = false
	is_combat_running = false
	current_turn = 0
