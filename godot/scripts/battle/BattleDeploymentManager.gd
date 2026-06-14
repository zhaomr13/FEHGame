class_name BattleDeploymentManager
extends Node2D

signal deployment_confirmed(player_army: Array, enemy_army: Array, formation: int)

@onready var battle_mgr: BattleManager = $".."
@onready var unit_factory: BattleUnitFactory = $"../BattleUnitFactory"
@onready var deployment_ui: CanvasLayer = $"../DeploymentUI"

func start_deployment(player_army: Array, enemy_army: Array):
	if battle_mgr.is_battle_active:
		return
	GameManager.change_state(GameConstants.GameState.BATTLE_DEPLOYMENT)
	battle_mgr.visible = true

	if deployment_ui:
		deployment_ui.visible = true

	await _play_preparation_animation(player_army, enemy_army)

	await get_tree().create_timer(0.5).timeout
	deployment_confirmed.emit(player_army, enemy_army, GameConstants.Formation.STANDARD)

func _play_preparation_animation(player_army: Array, enemy_army: Array):
	var entry_y_offset = -200
	var final_y_offset = 80
	var created_units: Array[BattleUnit] = []

	# Clear any existing units first
	for unit in battle_mgr.player_units:
		if is_instance_valid(unit):
			unit.queue_free()
	for unit in battle_mgr.enemy_units:
		if is_instance_valid(unit):
			unit.queue_free()
	battle_mgr.player_units.clear()
	battle_mgr.enemy_units.clear()
	battle_mgr.all_units.clear()

	# Create all units first (player side)
	for i in range(min(player_army.size(), 6)):
		var unit = unit_factory.create_preview_unit(player_army[i], i, true, entry_y_offset)
		if unit:
			created_units.append(unit)

	# Create all units first (enemy side)
	var actual_enemy_army = enemy_army.duplicate()
	if actual_enemy_army.is_empty():
		for i in range(3):
			actual_enemy_army.append(unit_factory.create_default_enemy(i))

	for i in range(min(actual_enemy_army.size(), 6)):
		var unit = unit_factory.create_preview_unit(actual_enemy_army[i], i, false, entry_y_offset)
		if unit:
			created_units.append(unit)

	# Animate all units simultaneously
	var tween = create_tween()
	tween.set_parallel(true)

	for unit in created_units:
		var final_pos = Vector2(unit.position.x, final_y_offset)
		tween.tween_property(unit, "position", final_pos, 0.8) \
			.set_trans(Tween.TRANS_BACK) \
			.set_ease(Tween.EASE_OUT)

	await tween.finished
	await get_tree().create_timer(0.5).timeout
