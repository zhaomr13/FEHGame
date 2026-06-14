class_name ExecutionPhaseController
extends Node2D

signal battle_started(attacker: Army, defender: Army)
signal execution_ended

var execution_queue: Array[Army] = []
var _turn_phase: int = 0  # 0 = player, 1 = enemy, 2 = done
var _active: bool = false

@onready var map_data: MapDataManager = $"../MapDataManager"
@onready var army_mgr: WorldMapArmyManager = $"../WorldMapArmyManager"

func start_execution_phase():
	_active = true
	_turn_phase = 0
	execution_queue.clear()
	for army in army_mgr.player_armies:
		if army.is_planned:
			execution_queue.append(army)
	for army in army_mgr.enemy_armies:
		if army.is_planned:
			execution_queue.append(army)

	print("ExecutionPhase: starting - player armies: ", army_mgr.player_armies.size(), " enemy: ", army_mgr.enemy_armies.size(), " queue: ", execution_queue.size())
	_execute_next_move()

func _execute_next_move():
	# Guard against re-entrant calls while a move sequence is in progress
	if not _active:
		return

	if execution_queue.is_empty():
		_active = false
		if _turn_phase == 0:
			# Player turn done - signal to start enemy turn
			print("ExecutionPhase: player turn done, starting enemy turn")
			_turn_phase = 1
			execution_ended.emit()
		else:
			print("ExecutionPhase: enemy turn done")
		# Enemy turn done (_turn_phase == 1) - just stop, no more recursion
		return

	var army = execution_queue[0]
	execution_queue.pop_front()

	if not is_instance_valid(army):
		_execute_next_move()
		return

	if army.planned_path.is_empty():
		_execute_next_move()
		return

	var next_city = army.planned_path[0]
	army.planned_path.pop_front()
	army.current_city_id = next_city

	var city_pos = map_data.map_nodes[next_city].position
	army.start_move_animation(city_pos + Vector2(20, -20))

	await _wait_for_move_complete(army)

func _wait_for_move_complete(army: Army):
	while is_instance_valid(army) and army.is_moving_animation:
		await get_tree().create_timer(0.05).timeout

	if not is_instance_valid(army):
		_execute_next_move()
		return

	var encounter = _check_encounter(army)
	if encounter:
		_active = false
		battle_started.emit(army, encounter)
		return

	if army.planned_path.size() > 0:
		execution_queue.push_front(army)

	_execute_next_move()

func _check_encounter(army: Army) -> Army:
	if army.army_type == Army.ArmyType.PLAYER_MAIN or army.army_type == Army.ArmyType.PLAYER_SQUAD:
		for enemy in army_mgr.enemy_armies:
			if enemy.current_city_id == army.current_city_id:
				print("ExecutionPhase: encounter! ", army.army_name, " meets ", enemy.army_name, " at ", army.current_city_id)
				return enemy
	else:
		for player in army_mgr.player_armies:
			if player.current_city_id == army.current_city_id:
				print("ExecutionPhase: encounter! ", army.army_name, " meets ", player.army_name, " at ", army.current_city_id)
				return player
	print("ExecutionPhase: no encounter for ", army.army_name, " at ", army.current_city_id)
	return null

func process_enemy_turn():
	_active = true
	_turn_phase = 1

	for enemy in army_mgr.enemy_armies:
		var current_city = enemy.current_city_id
		var connections = map_data.NODE_CONFIG[current_city].connections

		for connected_id in connections:
			for player in army_mgr.player_armies:
				if player.current_city_id == connected_id:
					enemy.set_planning_move(connected_id, [connected_id])
					break

	execution_queue.clear()
	for enemy in army_mgr.enemy_armies:
		if enemy.is_planned:
			execution_queue.append(enemy)

	if execution_queue.is_empty():
		_active = false
		return

	_execute_next_move()
