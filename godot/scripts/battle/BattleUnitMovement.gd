class_name BattleUnitMovement
extends Node2D

@onready var battle_unit: BattleUnit = $".."

func perform_melee_attack_sequence(target: BattleUnit, damage: int):
	var original_global_pos = battle_unit.global_position
	var target_global_pos = target.global_position

	var stop_distance = 180.0
	var approach_direction = 1.0 if target_global_pos.x > original_global_pos.x else -1.0
	var jump_target_global = Vector2(target_global_pos.x - stop_distance * approach_direction, target_global_pos.y)

	if battle_unit.character.animated_sprite.sprite_frames.has_animation("Jump"):
		battle_unit.character.animated_sprite.play("Jump")
	else:
		battle_unit.character.set_state(Character.State.MOVING)

	var jump_tween = battle_unit.create_tween()
	jump_tween.set_trans(Tween.TRANS_QUAD)
	jump_tween.set_ease(Tween.EASE_OUT)
	jump_tween.tween_property(battle_unit, "global_position", jump_target_global, 0.3 / 4.0)
	await jump_tween.finished

	var anim_name = battle_unit.character.play_attack_animation()
	if anim_name != "" and battle_unit.character.animated_sprite.sprite_frames.has_animation(anim_name):
		await battle_unit.character.animated_sprite.animation_finished
	else:
		await get_tree().create_timer(0.15 / 4.0).timeout

	await target.take_damage(damage)

	await get_tree().create_timer(0.05 / 4.0).timeout

	var return_tween = battle_unit.create_tween()
	return_tween.set_trans(Tween.TRANS_LINEAR)
	return_tween.set_ease(Tween.EASE_IN_OUT)
	return_tween.tween_property(battle_unit, "global_position", original_global_pos, 0.3 / 4.0)
	await return_tween.finished
