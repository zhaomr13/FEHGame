class_name ExecutionPhaseController
extends Node2D

signal battle_started(attacker: Army, defender: Army)
signal execution_ended

var _turn_phase: int = 0  # 0 = player, 1 = enemy
var _active: bool = false

@onready var map_data: MapDataManager = $"../MapDataManager"
@onready var army_mgr: WorldMapArmyManager = $"../WorldMapArmyManager"

func start_execution_phase():
	_active = true
	_turn_phase = 0

	# Clear all plan lines when execution starts
	for army in army_mgr.player_armies:
		army.clear_plan_lines()
	for army in army_mgr.enemy_armies:
		army.clear_plan_lines()

	# Gather all planned armies (player + enemy) and move them simultaneously
	var moving_armies: Array[Army] = []
	for army in army_mgr.player_armies:
		if army.is_planned and not army.planned_path.is_empty():
			moving_armies.append(army)
	for army in army_mgr.enemy_armies:
		if army.is_planned and not army.planned_path.is_empty():
			moving_armies.append(army)

	if moving_armies.is_empty():
		_active = false
		execution_ended.emit()
		return

	# Start all movements simultaneously
	for army in moving_armies:
		var next_city = army.planned_path[0]
		army.planned_path.pop_front()
		army.current_city_id = next_city
		var city_pos = map_data.map_nodes[next_city].position
		army.start_move_animation(city_pos + Vector2(20, -20))

	# Wait for all movements to finish
	await _wait_for_all_moves(moving_armies)

	# Check encounters for all armies that moved
	var encounters: Array[Dictionary] = []
	for army in moving_armies:
		if not is_instance_valid(army):
			continue
		var encounter = _check_encounter(army)
		if encounter:
			encounters.append({"attacker": army, "defender": encounter})

	if not encounters.is_empty():
		_active = false
		# Trigger battles for encounters (sequential to avoid conflicts)
		for e in encounters:
			battle_started.emit(e.attacker, e.defender)
			await get_tree().create_timer(0.2).timeout
		return

	# Player phase done, start enemy phase
	if _turn_phase == 0:
		_turn_phase = 1
		execution_ended.emit()

func _wait_for_all_moves(armies: Array[Army]):
	var all_done = false
	while not all_done:
		all_done = true
		for army in armies:
			if is_instance_valid(army) and army.is_moving_animation:
				all_done = false
				break
		if not all_done:
			await get_tree().create_timer(0.05).timeout

func _check_encounter(army: Army) -> Army:
	if army.army_type == Army.ArmyType.PLAYER_MAIN or army.army_type == Army.ArmyType.PLAYER_SQUAD:
		for enemy in army_mgr.enemy_armies:
			if enemy.current_city_id == army.current_city_id:
				return enemy
	else:
		for player in army_mgr.player_armies:
			if player.current_city_id == army.current_city_id:
				return player
	return null

func process_enemy_turn():
	_active = true
	_turn_phase = 1

	# Clear plan lines
	for army in army_mgr.enemy_armies:
		army.clear_plan_lines()

	# Enemy AI: plan moves toward adjacent player armies
	for enemy in army_mgr.enemy_armies:
		var current_city = enemy.current_city_id
		var connections = map_data.NODE_CONFIG[current_city].connections

		for connected_id in connections:
			for player in army_mgr.player_armies:
				if player.current_city_id == connected_id:
					enemy.set_planning_move(connected_id, [connected_id])
					break

	# Gather enemies with plans
	var moving_armies: Array[Army] = []
	for enemy in army_mgr.enemy_armies:
		if enemy.is_planned and not enemy.planned_path.is_empty():
			moving_armies.append(enemy)

	if moving_armies.is_empty():
		_active = false
		return

	# Start all enemy movements simultaneously
	for enemy in moving_armies:
		var next_city = enemy.planned_path[0]
		enemy.planned_path.pop_front()
		enemy.current_city_id = next_city
		var city_pos = map_data.map_nodes[next_city].position
		enemy.start_move_animation(city_pos + Vector2(20, -20))

	# Wait for all movements to finish
	await _wait_for_all_moves(moving_armies)

	# Check encounters
	var encounters: Array[Dictionary] = []
	for army in moving_armies:
		if not is_instance_valid(army):
			continue
		var encounter = _check_encounter(army)
		if encounter:
			encounters.append({"attacker": army, "defender": encounter})

	if not encounters.is_empty():
		_active = false
		for e in encounters:
			battle_started.emit(e.attacker, e.defender)
			await get_tree().create_timer(0.2).timeout
		return

	_active = false
