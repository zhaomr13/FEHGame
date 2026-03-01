class_name CharacterData
extends Resource

@export var character_name: String = "Unnamed"
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
    return current_hp <= 0 and soldiers <= 0

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
