class_name SkillData
extends Resource

enum SkillType { ACTIVE, PASSIVE, LEADER }
enum TargetType { SELF, SINGLE, AOE, ALLY, ALL_ALLIES }

@export var skill_name: String = "Unknown Skill"
@export var description: String = ""
@export var skill_type: SkillType = SkillType.ACTIVE
@export var target_type: TargetType = TargetType.SINGLE
@export var power: int = 10
@export var cooldown: int = 3
@export var current_cooldown: int = 0

func calculate_damage(user: CharacterData, target: CharacterData) -> int:
    match skill_type:
        SkillType.ACTIVE:
            return max(1, user.attack * power / 10 - target.defense)
        SkillType.PASSIVE:
            return 0
        SkillType.LEADER:
            return 0
    return 0

func can_use() -> bool:
    return current_cooldown <= 0

func use():
    current_cooldown = cooldown

func update_cooldown():
    current_cooldown = max(0, current_cooldown - 1)
