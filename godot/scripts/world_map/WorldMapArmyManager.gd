class_name WorldMapArmyManager
extends Node2D

signal army_selected(army: Army)
signal enemy_targeted(attacker: Army, target: Army)
signal move_completed(army: Army)

var player_armies: Array[Army] = []
var enemy_armies: Array[Army] = []
var selected_army: Army = null

@onready var armies_container: Node2D = $"../Armies"
@onready var map_data: MapDataManager = $"../MapDataManager"

func clear_armies():
	for army in player_armies:
		if is_instance_valid(army):
			army.queue_free()
	player_armies.clear()

	for army in enemy_armies:
		if is_instance_valid(army):
			army.queue_free()
	enemy_armies.clear()

func create_player_armies_from_squads(start_city: String):
	var squad_index = 0

	for squad_data in GameManager.squad_data:
		if squad_data.is_empty():
			squad_index += 1
			continue

		var army = Army.new()
		army.army_id = "player_squad_%d" % squad_index
		army.army_name = "Squad %d" % (squad_index + 1) if squad_index > 0 else "Main Army"
		army.army_type = Army.ArmyType.PLAYER_MAIN if squad_index == 0 else Army.ArmyType.PLAYER_SQUAD
		army.current_city_id = start_city
		army.squad_data = _convert_squad_data(squad_data)
		army.army_clicked.connect(_on_army_clicked)
		army.move_completed.connect(_on_move_completed)

		armies_container.add_child(army)
		player_armies.append(army)
		_update_army_position(army)

		squad_index += 1

	if player_armies.is_empty():
		_create_default_player_army(start_city)

func _convert_squad_data(squad_data: Array) -> Array[CharacterData]:
	var result: Array[CharacterData] = []
	for char in squad_data:
		if char is CharacterData:
			result.append(char)
	return result

func _create_default_player_army(start_city: String):
	var main_army = Army.new()
	main_army.army_id = "player_main"
	main_army.army_name = "Main Army"
	main_army.army_type = Army.ArmyType.PLAYER_MAIN
	main_army.current_city_id = start_city
	main_army.squad_data = _get_squad_characters(0)
	main_army.army_clicked.connect(_on_army_clicked)
	main_army.move_completed.connect(_on_move_completed)

	armies_container.add_child(main_army)
	player_armies.append(main_army)
	_update_army_position(main_army)

func create_enemy_armies(player_faction: String):
	var all_factions = ["askr", "embla", "nifl", "muspell"]

	for faction in all_factions:
		if faction == player_faction:
			continue

		var faction_chars = CharacterDatabase.get_characters_by_faction(faction)
		if faction_chars.is_empty():
			continue

		for city_id in map_data.NODE_CONFIG.keys():
			if map_data.NODE_CONFIG[city_id].faction == faction:
				var enemy_army = Army.new()
				enemy_army.army_id = "enemy_%s" % faction
				enemy_army.army_name = faction.capitalize()
				enemy_army.army_type = Army.ArmyType.ENEMY
				enemy_army.current_city_id = city_id
				enemy_army.squad_data = _get_faction_squad(faction_chars)
				enemy_army.army_clicked.connect(_on_army_clicked)

				armies_container.add_child(enemy_army)
				enemy_armies.append(enemy_army)
				_update_army_position(enemy_army)
				break

func _get_faction_squad(faction_chars: Array[CharacterData]) -> Array[CharacterData]:
	var squad: Array[CharacterData] = []
	for i in range(min(3, faction_chars.size())):
		squad.append(faction_chars[i])
	return squad

func _get_squad_characters(squad_index: int) -> Array[CharacterData]:
	if squad_index < GameManager.squad_data.size():
		var squad: Array[CharacterData] = []
		for char in GameManager.squad_data[squad_index]:
			if char is CharacterData:
				squad.append(char)
		return squad
	return []

func initialize_squads():
	var total_in_squads = 0
	for squad in GameManager.squad_data:
		total_in_squads += squad.size()
	if total_in_squads == 0 and GameManager.unassigned_units.size() == 0:
		GameManager.initialize_squads()

func _update_army_position(army: Army):
	if map_data.map_nodes.has(army.current_city_id):
		var city_pos = map_data.map_nodes[army.current_city_id].position
		army.set_position_at_city(city_pos)

func get_army_at_position(pos: Vector2) -> Army:
	for army in player_armies:
		if army.position.distance_to(pos) < 30:
			return army
	for army in enemy_armies:
		if army.position.distance_to(pos) < 30:
			return army
	return null

func set_selected_army(army: Army):
	if selected_army and is_instance_valid(selected_army):
		selected_army.set_selected(false)

	selected_army = army
	if selected_army:
		selected_army.set_selected(true)
		army_selected.emit(selected_army)

func refresh_player_armies(fallback_city: String):
	if selected_army:
		fallback_city = selected_army.current_city_id

	clear_armies()
	create_player_armies_from_squads(fallback_city)

func create_squad_from_main(main_army: Army):
	if GameManager.squad_data.size() < 2:
		return

	var squad_index = 1
	var squad_chars = _get_squad_characters(squad_index)
	if squad_chars.is_empty():
		return

	var new_army = Army.new()
	new_army.army_id = "player_squad_%d" % player_armies.size()
	new_army.army_name = "Squad %d" % (squad_index + 1)
	new_army.army_type = Army.ArmyType.PLAYER_SQUAD
	new_army.current_city_id = main_army.current_city_id
	new_army.squad_data = squad_chars
	new_army.army_clicked.connect(_on_army_clicked)
	new_army.move_completed.connect(_on_move_completed)

	armies_container.add_child(new_army)
	player_armies.append(new_army)
	_update_army_position(new_army)

func _on_army_clicked(army: Army):
	army_selected.emit(army)

func _on_move_completed(army: Army):
	move_completed.emit(army)
