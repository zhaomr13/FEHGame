class_name BattleUnitCombat
extends Node2D

@onready var battle_unit: BattleUnit = $".."
@onready var movement: BattleUnitMovement = $"../BattleUnitMovement"

func perform_attack(target: BattleUnit, use_skill: bool):
	var damage = calculate_damage(target, use_skill)

	var adjacent_allies = count_adjacent_allies(target)
	if adjacent_allies > 0:
		damage = int(damage * (1.5 + 0.3 * adjacent_allies))

	var ranged_weapons = ["bow", "magic"]
	var is_melee = not (battle_unit.character_data.weapon_type in ranged_weapons)

	if battle_unit.character and battle_unit.character.animated_sprite.sprite_frames:
		if is_melee:
			await movement.perform_melee_attack_sequence(target, damage)
		else:
			var anim_name = battle_unit.character.play_attack_animation()
			if anim_name != "" and battle_unit.character.animated_sprite.sprite_frames.has_animation(anim_name):
				await battle_unit.character.animated_sprite.animation_finished
			else:
				await get_tree().create_timer(0.3).timeout
			await target.take_damage(damage)
	else:
		await get_tree().create_timer(0.1).timeout
		await target.take_damage(damage)

	battle_unit.time_bar = 0.0
	battle_unit.is_ready = false
	if battle_unit.character:
		battle_unit.character.set_state(Character.State.IDLE)

func calculate_damage(target: BattleUnit, use_skill: bool) -> int:
	var base_atk = battle_unit.character_data.attack
	if use_skill:
		base_atk = int(base_atk * 1.5)

	var damage = base_atk - target.character_data.defense

	var triangle_bonus = get_weapon_triangle_bonus(battle_unit.character_data.weapon_type, target.character_data.weapon_type)
	damage = int(damage * (1.0 + triangle_bonus))

	return max(1, damage)

func get_weapon_triangle_bonus(attacker: String, defender: String) -> float:
	if attacker == "sword" and defender == "axe": return 0.2
	if attacker == "axe" and defender == "lance": return 0.2
	if attacker == "lance" and defender == "sword": return 0.2
	if attacker == "axe" and defender == "sword": return -0.2
	if attacker == "lance" and defender == "axe": return -0.2
	if attacker == "sword" and defender == "lance": return -0.2
	if attacker == "bow" and defender == "flying": return 0.3
	return 0.0

func count_adjacent_allies(target: BattleUnit) -> int:
	return 0

func take_damage(amount: int):
	if battle_unit.character_data.is_defending:
		amount = int(amount * 0.5)
		battle_unit.character_data.is_defending = false

	if battle_unit.character and battle_unit.character.animated_sprite.sprite_frames:
		await battle_unit.character.take_damage(amount)
	else:
		battle_unit.character_data.take_damage(amount)
		await get_tree().create_timer(0.1).timeout

	# Update status in BattleManager's side panel
	var battle_manager = get_parent().get_parent().get_parent() as BattleManager
	if battle_manager:
		battle_manager.status_panel.update_unit_status(battle_unit)
