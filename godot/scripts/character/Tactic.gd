class_name Tactic
extends Resource

# Condition types for tactics programming
enum ConditionType {
    ALWAYS,           # No condition
    ENEMY_HP_LOW,     # Enemy HP < threshold
    SELF_HP_LOW,      # Self HP < threshold
    ENEMY_COUNT_HIGH, # Many enemies remaining
    TURN_COUNT        # Turn number threshold
}

# Target selection types
enum TargetType {
    NEAREST,          # Closest enemy
    LOWEST_HP,        # Lowest HP enemy
    HIGHEST_ATK,      # Highest attack enemy
    RANGED_ONLY,      # Only ranged enemies
    MELEE_ONLY        # Only melee enemies
}

# Action types
enum ActionType {
    ATTACK,           # Normal attack
    SKILL,            # Use skill
    DEFEND,           # Defend stance
    MOVE_FORWARD,     # Move to front line
    MOVE_BACKWARD     # Move to back line
}

@export var priority: int = 1  # 1-4, lower = higher priority
@export var condition_type: ConditionType = ConditionType.ALWAYS
@export var condition_value: float = 0.5  # For HP thresholds (0.0-1.0)
@export var target_type: TargetType = TargetType.NEAREST
@export var action_type: ActionType = ActionType.ATTACK
@export var use_skill: bool = false  # If true, use Attack2/skill animation

# Condition check - will be implemented when BattleUnit is created
func is_condition_met(self_unit, all_enemies: Array, all_allies: Array) -> bool:
    match condition_type:
        ConditionType.ALWAYS:
            return true
        ConditionType.ENEMY_HP_LOW:
            for enemy in all_enemies:
                if enemy.character_data.current_hp > 0:
                    var hp_percent = float(enemy.character_data.current_hp) / enemy.character_data.max_hp
                    if hp_percent <= condition_value:
                        return true
            return false
        ConditionType.SELF_HP_LOW:
            var hp_percent = float(self_unit.character_data.current_hp) / self_unit.character_data.max_hp
            return hp_percent <= condition_value
        ConditionType.ENEMY_COUNT_HIGH:
            var alive_enemies = all_enemies.filter(func(e): return e.character_data.current_hp > 0)
            return alive_enemies.size() >= int(condition_value * 6)  # Max 6 enemies
        ConditionType.TURN_COUNT:
            # Need reference to turn manager
            return false  # Placeholder
    return false

# Find target based on target_type - will be fully implemented when BattleUnit is created
func find_target(self_unit, enemies: Array):
    var valid_enemies = enemies.filter(func(e): return not e.character_data.is_defeated())
    if valid_enemies.is_empty():
        return null

    match target_type:
        TargetType.NEAREST:
            # Simple: sort by battle position
            valid_enemies.sort_custom(func(a, b): return a.battle_position < b.battle_position)
            return valid_enemies[0]
        TargetType.LOWEST_HP:
            valid_enemies.sort_custom(func(a, b): return a.character_data.current_hp < b.character_data.current_hp)
            return valid_enemies[0]
        TargetType.HIGHEST_ATK:
            valid_enemies.sort_custom(func(a, b): return a.character_data.attack > b.character_data.attack)
            return valid_enemies[0]
    return valid_enemies[0]
