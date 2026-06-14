class_name BattleTurnManager
extends Node2D

signal turn_started(turn_number: int)
signal unit_acted(unit: BattleUnit)
signal battle_finished(victory: bool)

@onready var battle_mgr: BattleManager = $".."

func start_combat_round():
	while battle_mgr.is_battle_active and battle_mgr.current_turn < battle_mgr.max_turns and battle_mgr.is_combat_running:
		battle_mgr.current_turn += 1
		turn_started.emit(battle_mgr.current_turn)

		for unit in battle_mgr.all_units:
			if not battle_mgr.is_battle_active or not battle_mgr.is_combat_running:
				return

			if not is_instance_valid(unit):
				continue
			if unit.character_data.is_defeated():
				continue

			var enemy_list = battle_mgr.enemy_units if unit.is_player_unit else battle_mgr.player_units
			await unit.process_turn(enemy_list, battle_mgr.all_units if unit.is_player_unit else battle_mgr.enemy_units)
			unit_acted.emit(unit)

			if check_victory():
				return

			await get_tree().create_timer(0.15).timeout

		await get_tree().create_timer(0.15).timeout

	if battle_mgr.is_battle_active:
		end_battle(false)

func check_victory() -> bool:
	var player_alive = battle_mgr.player_units.any(func(u): return is_instance_valid(u) and not u.character_data.is_defeated())
	var enemy_alive = battle_mgr.enemy_units.any(func(u): return is_instance_valid(u) and not u.character_data.is_defeated())

	if not enemy_alive:
		end_battle(true)
		return true
	elif not player_alive:
		end_battle(false)
		return true
	return false

func end_battle(victory: bool):
	print("[TIME] BattleTurnManager.end_battle ", Time.get_ticks_msec())
	if not battle_mgr.is_battle_active:
		return
	battle_mgr.is_battle_active = false
	battle_mgr.is_combat_running = false
	battle_finished.emit(victory)
	battle_mgr.visible = false

	battle_mgr.status_panel.cleanup_status_entries()

	await get_tree().create_timer(0.1).timeout
	GameManager.end_battle(victory)
