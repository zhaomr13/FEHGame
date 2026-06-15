class_name BattleUnitTactics
extends Node2D

@onready var battle_unit: BattleUnit = $".."
@onready var combat: BattleUnitCombat = $"../BattleUnitCombat"

func execute_tactics(all_enemy_units: Array, all_ally_units: Array):
	for i in range(battle_unit.character_data.tactics.size()):
		var tactic = battle_unit.character_data.tactics[i]
		if tactic.is_condition_met(battle_unit, all_enemy_units, all_ally_units):
			await execute_action(tactic, all_enemy_units, all_ally_units)
			return

	# Default: Attack nearest enemy
	var target = find_nearest_target(all_enemy_units)
	if target:
		await combat.perform_attack(target, false)

func execute_action(tactic: Tactic, enemies: Array, allies: Array):
	var target = tactic.find_target(battle_unit, enemies)
	if not target:
		return

	match tactic.action_type:
		Tactic.ActionType.ATTACK, Tactic.ActionType.SKILL:
			await combat.perform_attack(target, tactic.use_skill)
		Tactic.ActionType.DEFEND:
			battle_unit.character_data.is_defending = true
			await get_tree().create_timer(0.05 / 4.0).timeout
		Tactic.ActionType.MOVE_FORWARD:
			if battle_unit.battle_position >= 3:
				battle_unit.battle_position -= 3
			await get_tree().create_timer(0.05 / 4.0).timeout
		Tactic.ActionType.MOVE_BACKWARD:
			if battle_unit.battle_position < 3:
				battle_unit.battle_position += 3
			await get_tree().create_timer(0.05 / 4.0).timeout

func find_nearest_target(enemy_units: Array) -> BattleUnit:
	var valid_targets = enemy_units.filter(func(u): return not u.character_data.is_defeated())
	if valid_targets.is_empty():
		return null

	var has_front_line = false
	for enemy in valid_targets:
		if enemy.battle_position < 3:
			has_front_line = true
			break

	var is_ranged = battle_unit.character_data.weapon_type in ["bow", "magic"]
	if has_front_line and not is_ranged:
		valid_targets = valid_targets.filter(func(u): return u.battle_position < 3)

	if valid_targets.is_empty():
		return null

	valid_targets.sort_custom(func(a, b): return a.battle_position < b.battle_position)
	return valid_targets[0]
