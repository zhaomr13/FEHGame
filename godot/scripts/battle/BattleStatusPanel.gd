class_name BattleStatusPanel
extends Node2D

var player_status_entries: Dictionary = {}
var enemy_status_entries: Dictionary = {}

@onready var player_status_panel: VBoxContainer = $"../BattleUI/PlayerStatusPanel"
@onready var enemy_status_panel: VBoxContainer = $"../BattleUI/EnemyStatusPanel"

func create_unit_status_entry(unit: BattleUnit, data: CharacterData, is_player: bool):
	var entry_scene = preload("res://scenes/battle/UnitStatusEntry.tscn")
	var entry = entry_scene.instantiate()

	entry.get_node("InfoContainer/NameLabel").text = data.character_name
	entry.get_node("InfoContainer/HPLabel").text = "HP: " + str(data.current_hp) + "/" + str(data.max_hp)

	var face_path = _get_face_texture_path(data)
	if face_path != "":
		entry.get_node("FaceTexture").texture = load(face_path)

	if is_player:
		player_status_panel.add_child(entry)
		player_status_entries[unit] = entry
	else:
		enemy_status_panel.add_child(entry)
		enemy_status_entries[unit] = entry

func _get_face_texture_path(data: CharacterData) -> String:
	var folder = data.sprite_frames_path.get_base_dir()
	var face_path = folder + "/portraits/face.png"
	if FileAccess.file_exists(face_path):
		return face_path
	return ""

func update_unit_status(unit: BattleUnit):
	var entry = null
	if unit.is_player_unit and player_status_entries.has(unit):
		entry = player_status_entries[unit]
	elif not unit.is_player_unit and enemy_status_entries.has(unit):
		entry = enemy_status_entries[unit]

	if entry and is_instance_valid(entry):
		entry.get_node("InfoContainer/HPLabel").text = "HP: " + str(unit.character_data.current_hp) + "/" + str(unit.character_data.max_hp)

func cleanup_status_entries():
	for unit in player_status_entries.keys():
		var entry = player_status_entries[unit]
		if is_instance_valid(entry):
			entry.queue_free()
	player_status_entries.clear()

	for unit in enemy_status_entries.keys():
		var entry = enemy_status_entries[unit]
		if is_instance_valid(entry):
			entry.queue_free()
	enemy_status_entries.clear()
