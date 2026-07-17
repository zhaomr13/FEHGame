class_name CharacterData
extends Resource

@export var character_name: String = "未命名"
@export var character_class: GameConstants.CharacterClass = GameConstants.CharacterClass.LORD
@export var level: int = 1
@export var experience: int = 0

# Stats
@export var max_hp: int = 20
@export var current_hp: int = 20
@export var attack: int = 5
@export var defense: int = 3
@export var speed: int = 5
@export var leadership: int = 5

# Combat
@export var weapon_type: String = "sword"
@export var soldiers: int = 100
@export var max_soldiers: int = 100

# Skills & Tactics (Unicorn Overlord style)
@export var skills: Array[SkillData] = []
@export var tactics: Array[Tactic] = []  # 4 tactics max, priority order

# Battle state
var is_defending: bool = false

# Visual
@export var sprite_frames_path: String = ""

# Faction affiliation (askr, embla, nifl, muspell, etc.)
@export var faction: String = ""

# Save-game serialization. Single source of truth for the on-disk
# character format — SaveManager saves/loads through these.
func to_dict() -> Dictionary:
    var skill_dicts: Array = []
    for skill in skills:
        skill_dicts.append(skill.to_dict())
    var tactic_dicts: Array = []
    for tactic in tactics:
        tactic_dicts.append(tactic.to_dict())
    return {
        "name": character_name,
        "class": character_class,
        "level": level,
        "exp": experience,
        "hp": current_hp,
        "max_hp": max_hp,
        "attack": attack,
        "defense": defense,
        "speed": speed,
        "leadership": leadership,
        "weapon_type": weapon_type,
        "soldiers": soldiers,
        "max_soldiers": max_soldiers,
        "faction": faction,
        "sprite_frames_path": sprite_frames_path,
        "skills": skill_dicts,
        "tactics": tactic_dicts,
    }

static func from_dict(data: Dictionary, default_faction: String = "") -> CharacterData:
    var character := CharacterData.new()
    character.character_name = data.get("name", "Unknown")
    character.character_class = data.get("class", GameConstants.CharacterClass.LORD)
    character.level = data.get("level", 1)
    character.experience = data.get("exp", 0)
    character.current_hp = data.get("hp", 20)
    character.max_hp = data.get("max_hp", 20)
    character.attack = data.get("attack", 5)
    character.defense = data.get("defense", 3)
    character.speed = data.get("speed", 5)
    character.leadership = data.get("leadership", 5)
    character.weapon_type = data.get("weapon_type", "sword")
    character.soldiers = data.get("soldiers", 100)
    character.max_soldiers = data.get("max_soldiers", character.soldiers)
    character.faction = data.get("faction", default_faction)
    character.sprite_frames_path = data.get("sprite_frames_path", "")
    for skill_data in data.get("skills", []):
        if skill_data is Dictionary:
            character.skills.append(SkillData.from_dict(skill_data))
    for tactic_data in data.get("tactics", []):
        if tactic_data is Dictionary:
            character.tactics.append(Tactic.from_dict(tactic_data))
    if character.tactics.is_empty():
        character.setup_default_tactics()
    return character

# Default tactics for new characters
func setup_default_tactics():
    """Create default 4-slot tactics for new characters"""
    tactics.clear()

    # Slot 1: Attack low HP enemies
    var t1 = Tactic.new()
    t1.priority = 1
    t1.condition_type = Tactic.ConditionType.ENEMY_HP_LOW
    t1.condition_value = 0.3
    t1.target_type = Tactic.TargetType.LOWEST_HP
    t1.action_type = Tactic.ActionType.ATTACK
    t1.use_skill = true
    tactics.append(t1)

    # Slot 2: Defend when self HP low
    var t2 = Tactic.new()
    t2.priority = 2
    t2.condition_type = Tactic.ConditionType.SELF_HP_LOW
    t2.condition_value = 0.3
    t2.target_type = Tactic.TargetType.NEAREST
    t2.action_type = Tactic.ActionType.DEFEND
    tactics.append(t2)

    # Slot 3: Attack nearest
    var t3 = Tactic.new()
    t3.priority = 3
    t3.condition_type = Tactic.ConditionType.ALWAYS
    t3.target_type = Tactic.TargetType.NEAREST
    t3.action_type = Tactic.ActionType.ATTACK
    t3.use_skill = false
    tactics.append(t3)

    # Slot 4: Default attack
    var t4 = Tactic.new()
    t4.priority = 4
    t4.condition_type = Tactic.ConditionType.ALWAYS
    t4.target_type = Tactic.TargetType.NEAREST
    t4.action_type = Tactic.ActionType.ATTACK
    t4.use_skill = false
    tactics.append(t4)

func take_damage(amount: int):
    current_hp = max(0, current_hp - amount)
    if current_hp == 0:
        soldiers = max(0, soldiers - 10)

func heal(amount: int):
    current_hp = min(max_hp, current_hp + amount)

func is_defeated() -> bool:
    return current_hp <= 0

func gain_experience(amount: int):
    experience += amount
    if experience >= 100:
        level_up()

func level_up():
    level += 1
    experience = 0
    max_hp += 5
    current_hp = max_hp
    attack += 2
    defense += 1
    speed += 1
