class_name CharacterDatabase
extends RefCounted

const CHARACTERS_PATH := "res://data/characters.yaml"

const CLASS_MAP: Dictionary = {
    "LORD": GameConstants.CharacterClass.LORD,
    "KNIGHT": GameConstants.CharacterClass.KNIGHT,
    "FIGHTER": GameConstants.CharacterClass.FIGHTER,
    "MAGE": GameConstants.CharacterClass.MAGE,
    "ARCHER": GameConstants.CharacterClass.ARCHER
}

func load_all_characters() -> Array[CharacterData]:
    if not FileAccess.file_exists(CHARACTERS_PATH):
        push_error("角色数据库未找到：%s" % CHARACTERS_PATH)
        return []

    var yaml_text := FileAccess.get_file_as_string(CHARACTERS_PATH)
    var parser := YamlParser.new()
    var parsed: Dictionary = parser.parse(yaml_text)

    var characters: Array[CharacterData] = []
    var char_list: Array = parsed.get("characters", [])

    for char_dict in char_list:
        if not char_dict is Dictionary:
            push_warning("跳过无效的角色条目（不是字典）")
            continue
        var char_data := _create_character_from_dict(char_dict)
        if char_data != null:
            characters.append(char_data)

    return characters

func _create_character_from_dict(dict: Dictionary) -> CharacterData:
    var name: String = dict.get("name", "未命名")
    var class_str: String = dict.get("class", "LORD")
    if not CLASS_MAP.has(class_str):
        push_warning("角色 '%s' 的未知职业 '%s'，使用默认职业 LORD" % [name, class_str])
        class_str = "LORD"

    var char_data := CharacterData.new()
    char_data.character_name = name
    char_data.character_class = CLASS_MAP[class_str]
    char_data.faction = dict.get("faction", "")
    char_data.level = dict.get("level", 1)
    char_data.experience = dict.get("experience", 0)
    char_data.max_hp = dict.get("max_hp", 20)
    char_data.current_hp = char_data.max_hp
    char_data.attack = dict.get("attack", 5)
    char_data.defense = dict.get("defense", 3)
    char_data.speed = dict.get("speed", 5)
    char_data.leadership = dict.get("leadership", 5)
    char_data.weapon_type = dict.get("weapon_type", "sword")
    char_data.soldiers = dict.get("soldiers", 100)
    char_data.max_soldiers = dict.get("max_soldiers", char_data.soldiers)

    var sprite_folder: String = dict.get("sprite_folder", "")
    if sprite_folder != "":
        char_data.sprite_frames_path = "res://assets/characters/%s/" % sprite_folder
    else:
        push_warning("角色 '%s' 没有 sprite_folder" % name)
        char_data.sprite_frames_path = ""

    # Tactics: use defaults unless explicitly provided
    var tactics_array: Array = dict.get("tactics", [])
    if tactics_array.is_empty():
        char_data.setup_default_tactics()
    else:
        for tactic_dict in tactics_array:
            if tactic_dict is Dictionary:
                char_data.tactics.append(_create_tactic_from_dict(tactic_dict))
        if char_data.tactics.is_empty():
            char_data.setup_default_tactics()

    # Skills (currently empty in the original generator)
    var skills_array: Array = dict.get("skills", [])
    for skill_dict in skills_array:
        if skill_dict is Dictionary:
            char_data.skills.append(_create_skill_from_dict(skill_dict))

    return char_data

func _create_tactic_from_dict(dict: Dictionary) -> Tactic:
    var tactic := Tactic.new()
    tactic.priority = dict.get("priority", 1)
    tactic.condition_value = dict.get("condition_value", 0.5)
    tactic.use_skill = dict.get("use_skill", false)

    var condition_str: String = dict.get("condition_type", "ALWAYS")
    match condition_str:
        "ENEMY_HP_LOW": tactic.condition_type = Tactic.ConditionType.ENEMY_HP_LOW
        "SELF_HP_LOW": tactic.condition_type = Tactic.ConditionType.SELF_HP_LOW
        "ENEMY_COUNT_HIGH": tactic.condition_type = Tactic.ConditionType.ENEMY_COUNT_HIGH
        "TURN_COUNT": tactic.condition_type = Tactic.ConditionType.TURN_COUNT
        _: tactic.condition_type = Tactic.ConditionType.ALWAYS

    var target_str: String = dict.get("target_type", "NEAREST")
    match target_str:
        "LOWEST_HP": tactic.target_type = Tactic.TargetType.LOWEST_HP
        "HIGHEST_ATK": tactic.target_type = Tactic.TargetType.HIGHEST_ATK
        "RANGED_ONLY": tactic.target_type = Tactic.TargetType.RANGED_ONLY
        "MELEE_ONLY": tactic.target_type = Tactic.TargetType.MELEE_ONLY
        _: tactic.target_type = Tactic.TargetType.NEAREST

    var action_str: String = dict.get("action_type", "ATTACK")
    match action_str:
        "SKILL": tactic.action_type = Tactic.ActionType.SKILL
        "DEFEND": tactic.action_type = Tactic.ActionType.DEFEND
        "MOVE_FORWARD": tactic.action_type = Tactic.ActionType.MOVE_FORWARD
        "MOVE_BACKWARD": tactic.action_type = Tactic.ActionType.MOVE_BACKWARD
        _: tactic.action_type = Tactic.ActionType.ATTACK

    return tactic

func _create_skill_from_dict(dict: Dictionary) -> SkillData:
    var skill := SkillData.new()
    # SkillData fields are not currently used by the generator; populate common ones if present
    if dict.has("name"):
        # SkillData does not have a name field; extend if needed
        pass
    return skill
