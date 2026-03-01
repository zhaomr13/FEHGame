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

@onready var character: Character = $Character

func _ready():
    # Time bar fills based on speed
    max_time_bar = 100.0

func setup(data: CharacterData, position: int, is_player: bool):
    character_data = data
    battle_position = position
    is_player_unit = is_player
    character.character_data = data

    if not is_player:
        character.scale.x = -1

func update_time_bar(delta: float):
    """Called every frame to fill time bar based on speed"""
    if is_ready or character_data.is_defeated():
        return

    # Speed determines fill rate
    var fill_rate = character_data.speed * 10.0  # Adjust multiplier for game feel
    time_bar += fill_rate * delta

    if time_bar >= max_time_bar:
        time_bar = max_time_bar
        is_ready = true
        enter_ready_state()

func enter_ready_state():
    """Character is ready to act - evaluate tactics"""
    character.set_state(Character.State.SELECTED)

func process_turn(all_enemy_units: Array, all_ally_units: Array):
    """Process a full turn for this unit"""
    # Fill time bar until ready
    while not is_ready and not character_data.is_defeated():
        update_time_bar(0.016)  # Approx 60fps
        await get_tree().create_timer(0.016).timeout

    if character_data.is_defeated():
        return

    # Execute tactics
    await execute_tactics(all_enemy_units, all_ally_units)

func execute_tactics(all_enemy_units: Array, all_ally_units: Array):
    """Evaluate tactics in priority order and execute first matching one"""
    for tactic in character_data.tactics:
        if tactic.is_condition_met(self, all_enemy_units, all_ally_units):
            await execute_action(tactic, all_enemy_units, all_ally_units)
            return

    # Default: Attack nearest enemy
    var target = find_nearest_target(all_enemy_units)
    if target:
        await perform_attack(target, false)

func execute_action(tactic: Tactic, enemies: Array, allies: Array):
    """Execute the tactic action"""
    var target = tactic.find_target(self, enemies)
    if not target:
        return

    match tactic.action_type:
        Tactic.ActionType.ATTACK:
            await perform_attack(target, tactic.use_skill)
        Tactic.ActionType.SKILL:
            await perform_attack(target, true)
        Tactic.ActionType.DEFEND:
            character_data.is_defending = true
            await get_tree().create_timer(0.5).timeout
        Tactic.ActionType.MOVE_FORWARD:
            if battle_position >= 3:  # Currently in back
                battle_position -= 3
                # Animate movement
        Tactic.ActionType.MOVE_BACKWARD:
            if battle_position < 3:  # Currently in front
                battle_position += 3
                # Animate movement

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
    # Calculate base damage
    var damage = calculate_damage(target, use_skill)

    # Check for pincer attack
    var adjacent_allies = count_adjacent_allies(target)
    if adjacent_allies > 0:
        damage = int(damage * (1.5 + 0.3 * adjacent_allies))  # Pincer bonus

    # Play animation
    character.play_attack_animation()

    await character.animated_sprite.animation_finished
    await target.take_damage(damage)

    # Reset time bar
    time_bar = 0.0
    is_ready = false
    character.set_state(Character.State.IDLE)

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
    if character_data.is_defending:
        amount = int(amount * 0.5)
        character_data.is_defending = false

    await character.take_damage(amount)
