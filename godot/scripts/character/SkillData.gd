class_name SkillData
extends Resource

enum SkillType { ACTIVE, PASSIVE, LEADER }
enum TargetType { SELF, SINGLE, AOE, ALLY, ALL_ALLIES }

@export var skill_name: String = "未知技能"
@export var description: String = ""
@export var skill_type: SkillType = SkillType.ACTIVE
@export var target_type: TargetType = TargetType.SINGLE
@export var power: int = 10
@export var cooldown: int = 3
@export var current_cooldown: int = 0

func to_dict() -> Dictionary:
	return {
		"skill_name": skill_name,
		"description": description,
		"skill_type": skill_type,
		"target_type": target_type,
		"power": power,
		"cooldown": cooldown,
		"current_cooldown": current_cooldown,
	}

static func from_dict(data: Dictionary) -> SkillData:
	var skill := SkillData.new()
	skill.skill_name = data.get("skill_name", "Unknown Skill")
	skill.description = data.get("description", "")
	skill.skill_type = data.get("skill_type", SkillType.ACTIVE)
	skill.target_type = data.get("target_type", TargetType.SINGLE)
	skill.power = data.get("power", 10)
	skill.cooldown = data.get("cooldown", 3)
	skill.current_cooldown = data.get("current_cooldown", 0)
	return skill

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
