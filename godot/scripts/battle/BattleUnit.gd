class_name BattleUnit
extends Node2D

var character_data: CharacterData
var battle_position: int = 0  # 0-2: Front line, 3-5: Back line
var is_player_unit: bool = true
var current_target: BattleUnit = null

# Time bar for active time battle
var time_bar: float = 0.0
var max_time_bar: float = 100.0
var is_ready: bool = false

var character: Character = null

func _ready():
	max_time_bar = 100.0
	character = $Character

func setup(data: CharacterData, position: int, is_player: bool):
	# Ensure character node is ready
	if character == null:
		character = $Character

	character_data = data
	battle_position = position
	is_player_unit = is_player

	if character:
		character.character_data = data
		character.setup_sprite()
		character.set_state(Character.State.IDLE)
		# Note: scale flip is handled by parent BattleUnit

func update_time_bar(delta: float):
	"""Called every frame to fill time bar based on speed"""
	if is_ready or character_data.is_defeated():
		return

	# Speed determines fill rate (increased for faster battles)
	var fill_rate = character_data.speed * 50.0  # 5x faster
	time_bar += fill_rate * delta

	if time_bar >= max_time_bar:
		time_bar = max_time_bar
		is_ready = true
		enter_ready_state()

func enter_ready_state():
	"""Character is ready to act - evaluate tactics"""
	if character:
		character.set_state(Character.State.SELECTED)

func process_turn(all_enemy_units: Array, all_ally_units: Array):
	"""Process a full turn for this unit"""
	print("DEBUG BattleUnit: process_turn started for ", character_data.character_name)
	if character_data.is_defeated():
		print("DEBUG BattleUnit: ", character_data.character_name, " is defeated, returning")
		return

	# Fill time bar until ready (slower for better visibility)
	var wait_time = 0.0
	var max_wait = 2.0
	print("DEBUG BattleUnit: Waiting for time bar, is_ready=", is_ready)
	while not is_ready and wait_time < max_wait:
		update_time_bar(0.016)  # ~60fps delta
		wait_time += 0.05
		await get_tree().create_timer(0.05).timeout

	if character_data.is_defeated():
		print("DEBUG BattleUnit: ", character_data.character_name, " defeated after wait")
		return

	# Force ready if timeout
	is_ready = true
	print("DEBUG BattleUnit: ", character_data.character_name, " is ready, executing tactics")

	# Execute tactics
	await execute_tactics(all_enemy_units, all_ally_units)
	print("DEBUG BattleUnit: ", character_data.character_name, " finished tactics")

func execute_tactics(all_enemy_units: Array, all_ally_units: Array):
	"""Evaluate tactics in priority order and execute first matching one"""
	print("DEBUG: execute_tactics, tactics count: ", character_data.tactics.size())
	for i in range(character_data.tactics.size()):
		var tactic = character_data.tactics[i]
		print("DEBUG: Checking tactic ", i, " type: ", tactic.action_type)
		if tactic.is_condition_met(self, all_enemy_units, all_ally_units):
			print("DEBUG: Tactic ", i, " condition met, executing")
			await execute_action(tactic, all_enemy_units, all_ally_units)
			print("DEBUG: Tactic ", i, " executed")
			return
		else:
			print("DEBUG: Tactic ", i, " condition not met")

	# Default: Attack nearest enemy
	print("DEBUG: No tactic matched, using default attack")
	var target = find_nearest_target(all_enemy_units)
	if target:
		print("DEBUG: Attacking nearest target: ", target.character_data.character_name)
		await perform_attack(target, false)
	else:
		print("DEBUG: No target found!")

func execute_action(tactic: Tactic, enemies: Array, allies: Array):
	"""Execute the tactic action"""
	print("DEBUG: execute_action finding target...")
	var target = tactic.find_target(self, enemies)
	if not target:
		print("DEBUG: No target found, returning")
		return
	print("DEBUG: Target found: ", target.character_data.character_name)

	print("DEBUG: Executing action type: ", tactic.action_type)
	match tactic.action_type:
		Tactic.ActionType.ATTACK, Tactic.ActionType.SKILL:
			print("DEBUG: Performing attack...")
			await perform_attack(target, tactic.use_skill)
			print("DEBUG: Attack complete")
		Tactic.ActionType.DEFEND:
			character_data.is_defending = true
			await get_tree().create_timer(0.1).timeout
		Tactic.ActionType.MOVE_FORWARD:
			if battle_position >= 3:  # Currently in back
				battle_position -= 3
			await get_tree().create_timer(0.1).timeout
		Tactic.ActionType.MOVE_BACKWARD:
			if battle_position < 3:  # Currently in front
				battle_position += 3
			await get_tree().create_timer(0.1).timeout
	print("DEBUG: execute_action complete")

func find_nearest_target(enemy_units: Array) -> BattleUnit:
	"""Find nearest valid target considering formation"""
	var valid_targets = enemy_units.filter(func(u): return not u.character_data.is_defeated())
	if valid_targets.is_empty():
		return null

	# Check if back line is protected
	var has_front_line = false
	for enemy in valid_targets:
		if enemy.battle_position < 3:  # Front line positions
			has_front_line = true
			break

	# If front line exists, can only target front line (unless ranged)
	var is_ranged = character_data.weapon_type in ["bow", "magic"]
	if has_front_line and not is_ranged:
		valid_targets = valid_targets.filter(func(u): return u.battle_position < 3)

	if valid_targets.is_empty():
		return null

	# Sort by battle position (proximity)
	valid_targets.sort_custom(func(a, b): return a.battle_position < b.battle_position)
	return valid_targets[0]

func perform_attack(target: BattleUnit, use_skill: bool):
	"""Perform attack with damage calculation"""
	print("DEBUG perform_attack: starting for target ", target.character_data.character_name)
	# Calculate base damage
	var damage = calculate_damage(target, use_skill)
	print("DEBUG perform_attack: damage calculated: ", damage)

	# Check for pincer attack
	var adjacent_allies = count_adjacent_allies(target)
	if adjacent_allies > 0:
		damage = int(damage * (1.5 + 0.3 * adjacent_allies))  # Pincer bonus

	print("DEBUG perform_attack: checking character...")

	# Check if melee (non-ranged) attacker
	var ranged_weapons = ["bow", "magic"]
	var is_melee = not (character_data.weapon_type in ranged_weapons)
	print("DEBUG: ", character_data.character_name, " weapon_type=", character_data.weapon_type, " is_melee=", is_melee)
	var original_position = position

	if character and character.animated_sprite.sprite_frames:
		print("DEBUG perform_attack: character valid, playing animation...")

		# Melee: Jump to target, attack, then return
		if is_melee:
			await _perform_melee_attack_sequence(target, damage)
		else:
			# Ranged: Stay in place and attack
			var anim_name = character.play_attack_animation()
			if anim_name != "" and character.animated_sprite.sprite_frames.has_animation(anim_name):
				await character.animated_sprite.animation_finished
			else:
				await get_tree().create_timer(0.3).timeout
			await target.take_damage(damage)
	else:
		# No character or no sprite_frames, just apply damage
		print("DEBUG perform_attack: no character/sprite_frames, waiting 0.1s")
		await get_tree().create_timer(0.1).timeout
		await target.take_damage(damage)

	print("DEBUG perform_attack: damage applied")

	# Reset time bar
	time_bar = 0.0
	is_ready = false
	if character:
		character.set_state(Character.State.IDLE)

func _perform_melee_attack_sequence(target: BattleUnit, damage: int):
	"""Melee attack: Jump to target, attack, then return to original position"""
	var original_global_pos = global_position

	# Get target's global position to handle different parent nodes
	var target_global_pos = target.global_position

	# Determine which side to approach from based on relative positions
	# Player units (facing right) should stop to the left of enemy
	# Enemy units (facing left) should stop to the right of player
	var stop_distance = 90.0  # Stop 90 pixels in front of target (further for melee)

	# Calculate approach direction: if target is to the right, approach from left
	var approach_direction = 1.0 if target_global_pos.x > original_global_pos.x else -1.0
	var jump_target_global = Vector2(target_global_pos.x - stop_distance * approach_direction, target_global_pos.y)

	# Play Jump animation if available
	if character.animated_sprite.sprite_frames.has_animation("Jump"):
		character.animated_sprite.play("Jump")
	else:
		character.set_state(Character.State.MOVING)

	# Jump toward target using global_position (handles different parents correctly)
	var jump_tween = create_tween()
	jump_tween.set_trans(Tween.TRANS_QUAD)
	jump_tween.set_ease(Tween.EASE_OUT)
	jump_tween.tween_property(self, "global_position", jump_target_global, 0.3)
	await jump_tween.finished

	# Play attack animation
	var anim_name = character.play_attack_animation()
	if anim_name != "" and character.animated_sprite.sprite_frames.has_animation(anim_name):
		await character.animated_sprite.animation_finished
	else:
		await get_tree().create_timer(0.3).timeout

	# Apply damage while at target position
	await target.take_damage(damage)

	# Small pause before returning
	await get_tree().create_timer(0.1).timeout

	# Return to original position using tween (not jump animation)
	var return_tween = create_tween()
	return_tween.set_trans(Tween.TRANS_LINEAR)
	return_tween.set_ease(Tween.EASE_IN_OUT)
	return_tween.tween_property(self, "global_position", original_global_pos, 0.3)
	await return_tween.finished

func calculate_damage(target: BattleUnit, use_skill: bool) -> int:
	"""Calculate damage with weapon triangle"""
	var base_atk = character_data.attack
	if use_skill:
		base_atk = int(base_atk * 1.5)

	var damage = base_atk - target.character_data.defense

	# Weapon triangle bonus
	var triangle_bonus = get_weapon_triangle_bonus(character_data.weapon_type, target.character_data.weapon_type)
	damage = int(damage * (1.0 + triangle_bonus))

	return max(1, damage)

func get_weapon_triangle_bonus(attacker: String, defender: String) -> float:
	"""Return damage modifier for weapon triangle"""
	# Sword > Axe > Lance > Sword
	if attacker == "sword" and defender == "axe": return 0.2
	if attacker == "axe" and defender == "lance": return 0.2
	if attacker == "lance" and defender == "sword": return 0.2
	if attacker == "axe" and defender == "sword": return -0.2
	if attacker == "lance" and defender == "axe": return -0.2
	if attacker == "sword" and defender == "lance": return -0.2
	# Bow strong vs Flying
	if attacker == "bow" and defender == "flying": return 0.3
	return 0.0

func count_adjacent_allies(target: BattleUnit) -> int:
	"""Count how many allies are adjacent to target for pincer bonus"""
	# Simplified: check battle_position adjacency
	# In real implementation, check formation adjacency
	return 0  # Placeholder

func take_damage(amount: int):
	"""Take damage with defense bonus"""
	print("DEBUG BattleUnit.take_damage: ", character_data.character_name, " taking ", amount, " damage")
	if character_data.is_defending:
		amount = int(amount * 0.5)
		character_data.is_defending = false

	if character and character.animated_sprite.sprite_frames:
		print("DEBUG BattleUnit.take_damage: calling character.take_damage")
		await character.take_damage(amount)
		print("DEBUG BattleUnit.take_damage: character.take_damage complete")
	else:
		# Fallback if no character visual
		print("DEBUG BattleUnit.take_damage: fallback, no character/sprite")
		character_data.take_damage(amount)
		await get_tree().create_timer(0.1).timeout

	# Update status in BattleManager's side panel
	var battle_manager = get_parent().get_parent() as BattleManager
	if battle_manager:
		battle_manager.update_unit_status(self)

	print("DEBUG BattleUnit.take_damage: complete")
