class_name CharacterGenerator
extends RefCounted

const INITIAL_SYLLABLES: Array[String] = [
    "阿", "贝", "塞", "迪", "艾", "菲", "格", "海", "伊", "婕",
    "凯", "莉", "梅", "诺", "欧", "普", "琪", "雷", "萨", "缇",
    "乌", "维", "希", "佐"
]

const BODY_SYLLABLES: Array[String] = [
    "尔", "方", "斯", "雷", "特", "卡", "优", "娜", "姆", "娅",
    "文", "克", "拉", "妮", "奥", "恩", "丝", "德", "罗", "万",
    "因", "雅", "露", "马", "肯", "巴", "坦", "鲁", "索", "迦"
]

const FACTIONS: Array[String] = ["askr", "embla", "nifl", "muspell"]

const SPRITE_FOLDERS: Array[String] = [
    "char_01_alm",
    "char_02_lilina",
    "char_03_dorcas",
    "char_04_abel",
    "char_05_klein",
    "char_07_lyn",
    "char_08_robin",
    "char_09_rebecca",
    "char_10_hector",
    "char_armorax",
    "char_armorsw",
    "char_beleth",
    "char_diadora",
    "char_sylvia"
]

const HP_VARIANCE: int = 3
const STAT_VARIANCE: int = 2
const SOLDIER_VARIANCE: int = 10
const LEADERSHIP_MIN: int = 3
const LEADERSHIP_MAX: int = 7

var _used_names: Dictionary = {}

const CLASS_TEMPLATES: Dictionary = {
    GameConstants.CharacterClass.LORD:    {"max_hp": 25, "attack": 8, "defense": 5, "speed": 6, "soldiers": 100, "weapon": "sword"},
    GameConstants.CharacterClass.KNIGHT:  {"max_hp": 30, "attack": 7, "defense": 8, "speed": 4, "soldiers": 120, "weapon": "lance"},
    GameConstants.CharacterClass.FIGHTER: {"max_hp": 28, "attack": 9, "defense": 4, "speed": 5, "soldiers": 100, "weapon": "axe"},
    GameConstants.CharacterClass.MAGE:    {"max_hp": 20, "attack": 10, "defense": 3, "speed": 6, "soldiers": 80,  "weapon": "magic"},
    GameConstants.CharacterClass.ARCHER:  {"max_hp": 22, "attack": 8, "defense": 4, "speed": 7, "soldiers": 90,  "weapon": "bow"}
}

const CLASS_KEYS: Array = [
    GameConstants.CharacterClass.LORD,
    GameConstants.CharacterClass.KNIGHT,
    GameConstants.CharacterClass.FIGHTER,
    GameConstants.CharacterClass.MAGE,
    GameConstants.CharacterClass.ARCHER
]

func generate_roster(count: int) -> Array[CharacterData]:
    var result: Array[CharacterData] = []
    _used_names.clear()
    var rng = RandomNumberGenerator.new()
    rng.randomize()
    for i in range(count):
        var char_data = CharacterData.new()
        char_data.character_name = _generate_unique_name()
        char_data.faction = FACTIONS[i % FACTIONS.size()]
        char_data.character_class = CLASS_KEYS[rng.randi() % CLASS_KEYS.size()]
        _apply_class_template(char_data, rng)
        char_data.sprite_frames_path = "res://assets/characters/" + SPRITE_FOLDERS[rng.randi() % SPRITE_FOLDERS.size()] + "/"
        char_data.setup_default_tactics()
        result.append(char_data)
    return result

func _apply_class_template(char_data: CharacterData, rng: RandomNumberGenerator):
    var template = CLASS_TEMPLATES[char_data.character_class]
    char_data.max_hp = template.max_hp + rng.randi_range(-HP_VARIANCE, HP_VARIANCE)
    char_data.current_hp = char_data.max_hp
    char_data.attack = template.attack + rng.randi_range(-STAT_VARIANCE, STAT_VARIANCE)
    char_data.defense = template.defense + rng.randi_range(-STAT_VARIANCE, STAT_VARIANCE)
    char_data.speed = template.speed + rng.randi_range(-STAT_VARIANCE, STAT_VARIANCE)
    char_data.soldiers = template.soldiers + rng.randi_range(-SOLDIER_VARIANCE, SOLDIER_VARIANCE)
    char_data.max_soldiers = char_data.soldiers
    char_data.weapon_type = template.weapon
    char_data.leadership = rng.randi_range(LEADERSHIP_MIN, LEADERSHIP_MAX)
    char_data.level = 1
    char_data.experience = 0

func _generate_unique_name() -> String:
    var max_attempts = 1000
    for attempt in range(max_attempts):
        var name = _generate_name()
        if not _used_names.has(name):
            _used_names[name] = true
            return name
    # Fallback with numeric suffix if collisions exhaust attempts
    var suffix = 1
    while true:
        var name = _generate_name() + str(suffix)
        if not _used_names.has(name):
            _used_names[name] = true
            return name
        suffix += 1
    return ""  # Unreachable, but satisfies GDScript static analyzer

func _generate_name() -> String:
    var rng = RandomNumberGenerator.new()
    rng.randomize()
    var pattern = rng.randi() % 3  # 0=2-syl, 1=3-syl, 2=4-syl
    var name = INITIAL_SYLLABLES[rng.randi() % INITIAL_SYLLABLES.size()]
    if pattern == 0:
        name += BODY_SYLLABLES[rng.randi() % BODY_SYLLABLES.size()]
    elif pattern == 1:
        name += BODY_SYLLABLES[rng.randi() % BODY_SYLLABLES.size()]
        name += BODY_SYLLABLES[rng.randi() % BODY_SYLLABLES.size()]
    else:
        name += BODY_SYLLABLES[rng.randi() % BODY_SYLLABLES.size()]
        name += BODY_SYLLABLES[rng.randi() % BODY_SYLLABLES.size()]
        name += BODY_SYLLABLES[rng.randi() % BODY_SYLLABLES.size()]
    return name
