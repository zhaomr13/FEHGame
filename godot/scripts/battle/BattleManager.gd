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
@onready var player_status_panel: VBoxContainer = $BattleUI/PlayerStatusPanel
@onready var enemy_status_panel: VBoxContainer = $BattleUI/EnemyStatusPanel

# Status entries for each unit
var player_status_entries: Dictionary = {}
var enemy_status_entries: Dictionary = {}

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

	# Show deployment UI with preparation animation
	if deployment_ui:
		deployment_ui.visible = true

	# Preview units entering the battlefield
	await _play_preparation_animation(player_army, enemy_army)

	# Auto-confirm after preparation (can be replaced with actual UI confirmation)
	await get_tree().create_timer(0.5).timeout
	_on_deployment_confirmed(player_army, enemy_army, GameConstants.Formation.STANDARD)

func _play_preparation_animation(player_army: Array, enemy_army: Array):
	"""Play entry animation for units entering the battlefield - all units animate in parallel"""
	var entry_y_offset = -200  # Start above the screen
	var final_y_offset = 80    # Final position offset from formation center
	var created_units: Array[BattleUnit] = []

	# Clear any existing units first
	for unit in player_units:
		if is_instance_valid(unit):
			unit.queue_free()
	for unit in enemy_units:
		if is_instance_valid(unit):
			unit.queue_free()
	player_units.clear()
	enemy_units.clear()
	all_units.clear()

	# Create all units first (player side)
	for i in range(min(player_army.size(), 6)):
		var unit = _create_preview_unit(player_army[i], i, true, entry_y_offset)
		if unit:
			created_units.append(unit)

	# Create all units first (enemy side) - use default enemies if none provided
	var actual_enemy_army = enemy_army.duplicate()
	if actual_enemy_army.is_empty():
		# Create default enemies
		for i in range(3):
			actual_enemy_army.append(_create_default_enemy(i))

	for i in range(min(actual_enemy_army.size(), 6)):
		var unit = _create_preview_unit(actual_enemy_army[i], i, false, entry_y_offset)
		if unit:
			created_units.append(unit)

	# Animate all units simultaneously using Tweens
	var tween = create_tween()
	tween.set_parallel(true)

	for unit in created_units:
		var final_pos = Vector2(unit.position.x, final_y_offset)
		tween.tween_property(unit, "position", final_pos, 0.8) \
			.set_trans(Tween.TRANS_BACK) \
			.set_ease(Tween.EASE_OUT)

	# Wait for all animations to complete
	await tween.finished

	# Additional delay after entry animation before combat starts
	await get_tree().create_timer(0.5).timeout

func _create_preview_unit(data: CharacterData, position: int, is_player: bool, y_offset: float) -> BattleUnit:
	"""Create a unit for the preparation animation and add to battle arrays"""
	var unit_scene = preload("res://scenes/battle/BattleUnit.tscn")
	var unit = unit_scene.instantiate()

	var x_pos = (position % 3) * 120 - 120
	unit.scale = Vector2(0.5, 0.5)
	unit.position = Vector2(x_pos, y_offset)

	if is_player:
		player_formation.add_child(unit)
		player_units.append(unit)
	else:
		unit.scale.x = -0.5
		enemy_formation.add_child(unit)
		enemy_units.append(unit)

	all_units.append(unit)
	unit.setup(data, position, is_player)
	return unit

func _on_deployment_confirmed(player_units_selected: Array[CharacterData], enemy_units_selected: Array[CharacterData], formation: int):
	if deployment_ui:
		deployment_ui.visible = false
	start_battle_combat(player_units_selected, enemy_units_selected, formation)

func start_battle_combat(player_selected: Array[CharacterData], enemy_selected: Array[CharacterData], formation: int):
	if is_battle_active or is_combat_running:
		return

	GameManager.change_state(GameConstants.GameState.BATTLE_ACTIVE)

	# Clear status entries (units were already created during preparation)
	_cleanup_status_entries()

	# If units weren't created in preparation, create them now
	if player_units.is_empty():
		for i in range(min(player_selected.size(), 6)):
			var unit = create_battle_unit(player_selected[i], i, true)
			player_units.append(unit)
			all_units.append(unit)

	if enemy_units.is_empty():
		for i in range(min(enemy_selected.size(), 6)):
			var enemy_data: CharacterData
			if enemy_selected.size() > i:
				enemy_data = enemy_selected[i]
			else:
				enemy_data = _create_default_enemy(i)
			var unit = create_battle_unit(enemy_data, i, false)
			enemy_units.append(unit)
			all_units.append(unit)

	# Clear status panels
	for entry in player_status_entries.values():
		if is_instance_valid(entry):
			entry.queue_free()
	for entry in enemy_status_entries.values():
		if is_instance_valid(entry):
			entry.queue_free()
	player_status_entries.clear()
	enemy_status_entries.clear()

	# Create status entries for existing units
	for unit in player_units:
		if is_instance_valid(unit):
			_create_unit_status_entry(unit, unit.character_data, true)
	for unit in enemy_units:
		if is_instance_valid(unit):
			_create_unit_status_entry(unit, unit.character_data, false)

	# Sort by speed (fastest first)
	all_units.sort_custom(func(a, b): return a.character_data.speed > b.character_data.speed)

	is_battle_active = true
	is_combat_running = true
	current_turn = 0

	await start_combat_round()

func _create_default_enemy(index: int) -> CharacterData:
	"""Generate a default enemy character with weapon type based on sprite"""
	var enemy_data = CharacterData.new()
	enemy_data.character_name = "Enemy " + str(index + 1)
	enemy_data.max_hp = 20 + randi() % 10
	enemy_data.current_hp = enemy_data.max_hp
	enemy_data.attack = 5 + randi() % 5
	enemy_data.defense = 3 + randi() % 3
	enemy_data.speed = 4 + randi() % 4

	# Define available enemy sprites with their weapon types based on folder name
	var enemy_options = [
		{"sprite": "char_01_alm", "weapon": "sword"},
		{"sprite": "char_02_lilina", "weapon": "magic"},
		{"sprite": "char_03_dorcas", "weapon": "axe"},
		{"sprite": "char_04_abel", "weapon": "lance"},
		{"sprite": "char_05_klein", "weapon": "bow"},
		{"sprite": "char_07_lyn", "weapon": "sword"},
		{"sprite": "char_08_robin", "weapon": "sword"},
		{"sprite": "char_09_rebecca", "weapon": "bow"},
		{"sprite": "char_10_hector", "weapon": "axe"},
		{"sprite": "char_armorax", "weapon": "axe"},
		{"sprite": "char_armorsw", "weapon": "sword"},
		{"sprite": "char_beleth", "weapon": "sword"},
		{"sprite": "char_diadora", "weapon": "magic"},
		{"sprite": "char_sylvia", "weapon": "sword"}
	]

	var selected = enemy_options[randi() % enemy_options.size()]
	enemy_data.weapon_type = selected.weapon
	enemy_data.sprite_frames_path = "res://assets/characters/" + selected.sprite + "/Idle.png"
	enemy_data.setup_default_tactics()
	return enemy_data

func create_battle_unit(data: CharacterData, position: int, is_player: bool) -> BattleUnit:
	var unit_scene = preload("res://scenes/battle/BattleUnit.tscn")
	var unit = unit_scene.instantiate()

	# Add to scene first so _ready() is called
	# Simple formation: 3 units in a row
	# Position 0, 1, 2: front row at y = 0
	var x_pos = (position % 3) * 120 - 120  # -120, 0, 120

	# Scale down sprites to fit better in battle field
	unit.scale = Vector2(0.5, 0.5)

	# Position units lower on the formation (y=80 instead of y=0)
	var y_pos = 80

	if is_player:
		unit.position = Vector2(x_pos, y_pos)
		player_formation.add_child(unit)
	else:
		unit.position = Vector2(x_pos, y_pos)
		unit.scale.x = -0.5  # Negative X to flip, 0.5 for size
		enemy_formation.add_child(unit)

	# Setup after adding to scene so _ready() has been called
	unit.setup(data, position, is_player)

	# Create status entry for this unit
	_create_unit_status_entry(unit, data, is_player)

	return unit

func _create_unit_status_entry(unit: BattleUnit, data: CharacterData, is_player: bool):
	var entry_scene = preload("res://scenes/battle/UnitStatusEntry.tscn")
	var entry = entry_scene.instantiate()

	# Set name and HP
	entry.get_node("InfoContainer/NameLabel").text = data.character_name
	entry.get_node("InfoContainer/HPLabel").text = "HP: " + str(data.current_hp) + "/" + str(data.max_hp)

	# Load face texture
	var face_path = _get_face_texture_path(data)
	if face_path != "":
		entry.get_node("FaceTexture").texture = load(face_path)

	# Add to appropriate panel
	if is_player:
		player_status_panel.add_child(entry)
		player_status_entries[unit] = entry
	else:
		enemy_status_panel.add_child(entry)
		enemy_status_entries[unit] = entry

func _get_face_texture_path(data: CharacterData) -> String:
	# Extract character folder from sprite_frames_path
	var folder = data.sprite_frames_path.get_base_dir()
	var face_path = folder + "/portraits/face.png"
	if FileAccess.file_exists(face_path):
		return face_path
	return ""

func update_unit_status(unit: BattleUnit):
	"""Update the status display for a unit"""
	var entry = null
	if unit.is_player_unit and player_status_entries.has(unit):
		entry = player_status_entries[unit]
	elif not unit.is_player_unit and enemy_status_entries.has(unit):
		entry = enemy_status_entries[unit]

	if entry and is_instance_valid(entry):
		entry.get_node("InfoContainer/HPLabel").text = "HP: " + str(unit.character_data.current_hp) + "/" + str(unit.character_data.max_hp)

func start_combat_round():
	print("DEBUG: Starting combat round, units count: ", all_units.size())
	while is_battle_active and current_turn < max_turns and is_combat_running:
		current_turn += 1
		turn_started.emit(current_turn)
		print("Battle Turn: ", current_turn)

		for unit in all_units:
			if not is_battle_active or not is_combat_running:
				print("DEBUG: Battle no longer active, exiting turn loop")
				return

			if not is_instance_valid(unit):
				print("DEBUG: Unit invalid, skipping")
				continue
			if unit.character_data.is_defeated():
				print("DEBUG: Unit ", unit.character_data.character_name, " defeated, skipping")
				continue

			print("DEBUG: Processing turn for ", unit.character_data.character_name)
			var enemy_list = enemy_units if unit.is_player_unit else player_units
			await unit.process_turn(enemy_list, all_units if unit.is_player_unit else enemy_units)
			print("DEBUG: Finished turn for ", unit.character_data.character_name)
			unit_acted.emit(unit)

			if check_victory():
				print("DEBUG: Victory checked, battle ending")
				return

			# Delay between actions for visibility
			await get_tree().create_timer(0.5).timeout

		# Delay between turns
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

	# Cleanup status entries
	_cleanup_status_entries()

	# Small delay to ensure cleanup before state change
	await get_tree().create_timer(0.1).timeout
	GameManager.end_battle(victory)

func _cleanup_status_entries():
	"""Remove all status panel entries"""
	# Clear player status entries
	for unit in player_status_entries.keys():
		var entry = player_status_entries[unit]
		if is_instance_valid(entry):
			entry.queue_free()
	player_status_entries.clear()

	# Clear enemy status entries
	for unit in enemy_status_entries.keys():
		var entry = enemy_status_entries[unit]
		if is_instance_valid(entry):
			entry.queue_free()
	enemy_status_entries.clear()
