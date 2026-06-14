class_name ExecutionPhaseController
extends Node2D

signal battle_started(attacker: Army, defender: Army)

@onready var map_data: MapDataManager = $"../MapDataManager"
@onready var army_mgr: WorldMapArmyManager = $"../WorldMapArmyManager"

func plan_ai_moves():
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
	# Clear all plan lines
	for army in army_mgr.player_armies:
		army.clear_plan_lines()
	for army in army_mgr.enemy_armies:
		army.clear_plan_lines()

	# Gather ALL planned armies
	var all_planned: Array[Army] = []
	for army in army_mgr.player_armies:
		if army.is_planned and not army.target_city_id.is_empty():
			all_planned.append(army)
	for army in army_mgr.enemy_armies:
		if army.is_planned and not army.target_city_id.is_empty():
			all_planned.append(army)

	if all_planned.is_empty():
		return

	# Record start positions
	var start_positions: Dictionary = {}
	for army in all_planned:
		start_positions[army] = army.current_city_id

	# Find midpoint crossing pairs
	var crossing_pairs = _find_midpoint_crossings(all_planned, start_positions)
	var crossing_armies: Array[Army] = []

	# Resolve midpoint encounters: move armies to midpoint, then battle
	for pair in crossing_pairs:
		crossing_armies.append(pair.a)
		crossing_armies.append(pair.b)

		var mid_pos = _get_midpoint(pair.a.target_city_id, pair.b.target_city_id)
		# Move both armies toward the midpoint simultaneously
		pair.a.start_move_animation(mid_pos)
		pair.b.start_move_animation(mid_pos)

		# Wait until both armies reach the midpoint
		while is_instance_valid(pair.a) and is_instance_valid(pair.b) and \
			  (pair.a.is_moving_animation or pair.b.is_moving_animation):
			await get_tree().create_timer(0.05).timeout

		# Both reached midpoint — trigger battle
		if is_instance_valid(pair.a) and is_instance_valid(pair.b):
			battle_started.emit(pair.a, pair.b)
			await get_tree().create_timer(0.3).timeout

	# Non-crossing armies move to their destination cities
	var moving_armies: Array[Army] = []
	for army in all_planned:
		if not army in crossing_armies and is_instance_valid(army):
			moving_armies.append(army)

	for army in moving_armies:
		var dest = army.target_city_id
		if dest != "" and map_data.map_nodes.has(dest):
			if not army.planned_path.is_empty():
				army.planned_path.pop_front()
			army.current_city_id = dest
			var city_pos = map_data.map_nodes[dest].position
			army.start_move_animation(city_pos + Vector2(20, -20))

	if not moving_armies.is_empty():
		await _wait_for_all_moves(moving_armies)

		# City encounters after movement
		for army in moving_armies:
			if not is_instance_valid(army):
				continue
			var encounter = _check_encounter(army)
			if encounter:
				battle_started.emit(army, encounter)
				await get_tree().create_timer(0.2).timeout

func _get_midpoint(city_a: String, city_b: String) -> Vector2:
	var pos_a = map_data.map_nodes[city_a].position if map_data.map_nodes.has(city_a) else Vector2.ZERO
	var pos_b = map_data.map_nodes[city_b].position if map_data.map_nodes.has(city_b) else Vector2.ZERO
	return (pos_a + pos_b) / 2.0

func _find_midpoint_crossings(armies: Array[Army], start_positions: Dictionary) -> Array:
	var pairs: Array = []
	for i in range(armies.size()):
		var a1 = armies[i]
		if not is_instance_valid(a1):
			continue
		var from1 = start_positions.get(a1, "")
		var to1 = a1.target_city_id
		if from1 == "" or to1 == "" or from1 == to1:
			continue
		if not _are_hostile(a1):
			continue

		for j in range(i + 1, armies.size()):
			var a2 = armies[j]
			if not is_instance_valid(a2):
				continue
			if not _are_hostile(a2):
				continue
			var from2 = start_positions.get(a2, "")
			var to2 = a2.target_city_id
			if from2 == "" or to2 == "" or from2 == to2:
				continue

			# Crossing: a1 goes from1→to1, a2 goes from2→to2
			if from1 == to2 and from2 == to1:
				pairs.append({"a": a1, "b": a2})

	return pairs

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
