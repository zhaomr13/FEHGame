class_name ExecutionPhaseController
extends Node2D

signal battle_started(attacker: Army, defender: Army)

@onready var map_data: MapDataManager = $"../MapDataManager"
@onready var army_mgr: WorldMapArmyManager = $"../WorldMapArmyManager"

func plan_ai_moves():
	# AI plans moves toward adjacent enemy armies
	for enemy in army_mgr.enemy_armies:
		enemy.clear_plan()
		var current_city = enemy.current_city_id
		var connections = map_data.NODE_CONFIG[current_city].connections

		for connected_id in connections:
			for player in army_mgr.player_armies:
				if player.current_city_id == connected_id:
					enemy.set_planning_move(connected_id, [connected_id])
					break

func start_execution_phase():
	# Clear all plan lines when execution starts
	for army in army_mgr.player_armies:
		army.clear_plan_lines()
	for army in army_mgr.enemy_armies:
		army.clear_plan_lines()

	# Gather ALL planned armies (player + enemy)
	var moving_armies: Array[Army] = []
	for army in army_mgr.player_armies:
		if army.is_planned and not army.planned_path.is_empty():
			moving_armies.append(army)
	for army in army_mgr.enemy_armies:
		if army.is_planned and not army.planned_path.is_empty():
			moving_armies.append(army)

	if moving_armies.is_empty():
		return

	# Record starting positions for midpoint encounter detection
	var start_positions: Dictionary = {}
	for army in moving_armies:
		start_positions[army] = army.current_city_id

	# Start all movements simultaneously
	for army in moving_armies:
		var next_city = army.planned_path[0]
		army.planned_path.pop_front()
		army.current_city_id = next_city
		var city_pos = map_data.map_nodes[next_city].position
		army.start_move_animation(city_pos + Vector2(20, -20))

	# Wait for all movements to finish
	await _wait_for_all_moves(moving_armies)

	# Check for midpoint encounters (armies that crossed each other)
	_check_midpoint_encounters(moving_armies, start_positions)

	# Check for city encounters (armies at same city)
	var encounters: Array[Dictionary] = []
	for army in moving_armies:
		if not is_instance_valid(army):
			continue
		var encounter = _check_encounter(army)
		if encounter:
			# Avoid duplicate encounters
			var already = false
			for e in encounters:
				if (e.attacker == army and e.defender == encounter) or \
				   (e.attacker == encounter and e.defender == army):
					already = true
					break
			if not already:
				encounters.append({"attacker": army, "defender": encounter})

	if not encounters.is_empty():
		for e in encounters:
			battle_started.emit(e.attacker, e.defender)
			await get_tree().create_timer(0.2).timeout

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

func _check_midpoint_encounters(moving_armies: Array[Army], start_positions: Dictionary):
	# Check if any two armies crossed paths (moved from A→B while another moved B→A)
	var encounters: Array[Dictionary] = []
	for i in range(moving_armies.size()):
		var a1 = moving_armies[i]
		if not is_instance_valid(a1):
			continue
		var from1 = start_positions.get(a1, "")
		var to1 = a1.current_city_id
		if from1 == "" or from1 == to1:
			continue
		if not _are_hostile(a1):
			continue

		for j in range(i + 1, moving_armies.size()):
			var a2 = moving_armies[j]
			if not is_instance_valid(a2):
				continue
			if not _are_hostile(a2):
				continue
			var from2 = start_positions.get(a2, "")
			var to2 = a2.current_city_id
			if from2 == "" or from2 == to2:
				continue

			# Check if they crossed: a1 went from1→to1, a2 went from2→to2
			# Crossing: from1 == to2 AND from2 == to1
			if from1 == to2 and from2 == to1:
				battle_started.emit(a1, a2)
				await get_tree().create_timer(0.2).timeout
				return  # Only handle one midpoint encounter per phase

func _are_hostile(army: Army) -> bool:
	return army.army_type == Army.ArmyType.PLAYER_MAIN or \
		   army.army_type == Army.ArmyType.PLAYER_SQUAD or \
		   army.army_type == Army.ArmyType.ENEMY

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
