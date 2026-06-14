class_name BattleUnitFactory
extends Node2D

@onready var battle_mgr: BattleManager = $".."
@onready var player_formation: Node2D = $"../PlayerFormation"
@onready var enemy_formation: Node2D = $"../EnemyFormation"

func create_preview_unit(data: CharacterData, position: int, is_player: bool, y_offset: float) -> BattleUnit:
	var unit_scene = preload("res://scenes/battle/BattleUnit.tscn")
	var unit = unit_scene.instantiate()

	var x_pos = (position % 3) * 120 - 120
	unit.scale = Vector2(0.5, 0.5)
	unit.position = Vector2(x_pos, y_offset)

	if is_player:
		player_formation.add_child(unit)
		battle_mgr.player_units.append(unit)
	else:
		unit.scale.x = -0.5
		enemy_formation.add_child(unit)
		battle_mgr.enemy_units.append(unit)

	battle_mgr.all_units.append(unit)
	unit.setup(data, position, is_player)
	return unit

func create_battle_unit(data: CharacterData, position: int, is_player: bool) -> BattleUnit:
	var unit_scene = preload("res://scenes/battle/BattleUnit.tscn")
	var unit = unit_scene.instantiate()

	var x_pos = (position % 3) * 120 - 120
	var y_pos = 80

	unit.scale = Vector2(0.5, 0.5)

	if is_player:
		unit.position = Vector2(x_pos, y_pos)
		player_formation.add_child(unit)
	else:
		unit.position = Vector2(x_pos, y_pos)
		unit.scale.x = -0.5
		enemy_formation.add_child(unit)

	unit.setup(data, position, is_player)

	battle_mgr.status_panel.create_unit_status_entry(unit, data, is_player)

	return unit

func create_default_enemy(index: int) -> CharacterData:
	var enemy_data = CharacterData.new()
	enemy_data.character_name = "Enemy " + str(index + 1)
	enemy_data.max_hp = 20 + randi() % 10
	enemy_data.current_hp = enemy_data.max_hp
	enemy_data.attack = 5 + randi() % 5
	enemy_data.defense = 3 + randi() % 3
	enemy_data.speed = 4 + randi() % 4

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
